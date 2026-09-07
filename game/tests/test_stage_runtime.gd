extends SceneTree

const Runtime = preload("res://scripts/stages/stage_runtime.gd")

func _initialize() -> void:
	var events: Array[Dictionary] = []
	var definition := {
		"duration_seconds": 330.0,
		"boss_at_seconds": 270.0,
		"boss_id": "boss_01",
		"waves": [{"at": 0.0, "enemy_id": "grunt", "count": 2, "interval": 1.0, "route_id": "main"}]
	}
	var stage = Runtime.new(definition)
	for frame in 329 * 60:
		events.append_array(stage.tick(1.0 / 60.0))
	assert(events.filter(func(event): return event.kind == "spawn").size() == 2)
	assert(events.filter(func(event): return event.kind == "boss_wave").size() == 1)
	assert(not stage.time_complete)
	for frame in 61:
		events.append_array(stage.tick(1.0 / 60.0))
	assert(stage.elapsed >= 330.0 and stage.time_complete)
	assert(events.filter(func(event): return event.kind == "boss_wave").size() == 1)
	print("STAGE RUNTIME PASSED")
	quit()
