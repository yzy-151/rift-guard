extends RefCounted

var definition: Dictionary
var elapsed := 0.0
var time_complete := false
var boss_emitted := false
var all_spawns_emitted := false
var wave_cursors: Array[int] = []
var telegraph_emitted: Array[bool] = []
var boss_telegraph_emitted := false
var arena_events: Array[Dictionary] = []

func _init(stage_definition: Dictionary) -> void:
	definition = stage_definition.duplicate(true)
	wave_cursors.resize(definition.get("waves", []).size())
	wave_cursors.fill(0)
	telegraph_emitted.resize(definition.get("waves", []).size())
	telegraph_emitted.fill(false)

func tick(dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	elapsed += maxf(dt, 0.0)
	for event: Dictionary in arena_events:
		event.life = maxf(0.0, float(event.get("life", 0.0)) - maxf(dt, 0.0))
	arena_events = arena_events.filter(func(event: Dictionary) -> bool: return float(event.get("life", 0.0)) > 0.0)
	var waves: Array = definition.get("waves", [])
	for i in waves.size():
		var wave: Dictionary = waves[i]
		var count: int = int(wave.get("count", 0))
		var interval: float = maxf(0.01, float(wave.get("interval", 1.0)))
		var wave_at := float(wave.get("at", 0.0))
		if not telegraph_emitted[i] and elapsed >= maxf(0.0, wave_at - 3.2):
			telegraph_emitted[i] = true
			events.append({"kind": "route_warning", "route_id": str(wave.get("route_id", "main")), "enemy_id": str(wave.get("enemy_id", "grunt")), "count": count, "flying": str(wave.get("enemy_id", "")) == "flyer", "lead_time": maxf(0.25, wave_at - elapsed)})
		while wave_cursors[i] < count and elapsed >= float(wave.get("at", 0.0)) + wave_cursors[i] * interval:
			events.append({
				"kind": "spawn",
				"enemy_id": str(wave.get("enemy_id", "grunt")),
				"route_id": str(wave.get("route_id", "main")),
				"wave": i + 1,
				"sequence": wave_cursors[i]
			})
			wave_cursors[i] += 1
	var boss_at := float(definition.get("boss_at_seconds", INF))
	if not boss_telegraph_emitted and elapsed >= boss_at - 4.5:
		boss_telegraph_emitted = true
		events.append({"kind": "route_warning", "route_id": str(definition.get("boss_route_id", "main")), "enemy_id": str(definition.get("boss_id", "boss_01")), "count": 1, "flying": false, "lead_time": 4.5, "boss": true})
	if not boss_emitted and elapsed >= boss_at:
		boss_emitted = true
		events.append({
			"kind": "boss_wave",
			"enemy_id": str(definition.get("boss_id", "boss_01")),
			"route_id": str(definition.get("boss_route_id", "main"))
		})
	all_spawns_emitted = boss_emitted
	for i in waves.size():
		all_spawns_emitted = all_spawns_emitted and wave_cursors[i] >= int(waves[i].get("count", 0))
	time_complete = elapsed + 0.0001 >= float(definition.get("duration_seconds", 300.0))
	return events

func apply_arena_event(event_definition: Dictionary, source: Vector2 = Vector2(640, 360)) -> Dictionary:
	var event := event_definition.duplicate(true)
	var duration := maxf(0.5, float(event.get("duration", 6.0)))
	event["life"] = duration
	event["total"] = duration
	event["source"] = source
	arena_events.append(event)
	return event

func remaining_seconds() -> float:
	return maxf(0.0, float(definition.get("duration_seconds", 300.0)) - elapsed)
