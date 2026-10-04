extends RefCounted
## Simulation-owned areas, phase clocks and resources. Rendering reads this state.
const TYPES := ["relay", "spring", "wind_lane", "hazard_lane"]

static func create(type: String, id: String, area: Rect2, facing: Vector2 = Vector2.RIGHT, options: Dictionary = {}) -> Dictionary:
	var feature := {"id":id, "type":type, "label":"", "area":area, "base_area":area,
		"effect_area":area, "activation_area":area, "facing":facing.normalized(), "element":"",
		"phase":"active", "phase_progress":0.0, "charge":0.0, "timer":0.0, "cooldown":0.0, "clock":0.0}
	match type:
		"relay":
			feature.merge({"label":"回响电极", "element":"electro", "phase":"idle", "activation_area":area.grow(34.0),
				"charge_duration":2.4, "warning_duration":0.85, "active_duration":0.22, "cooldown":8.0, "power":70.0}, true)
			var length := float(options.get("length", 360.0))
			var center := area.get_center()
			if absf(facing.x) >= absf(facing.y):
				feature.effect_area = Rect2(area.end.x if facing.x >= 0.0 else area.position.x - length, center.y - 26.0, length, 52.0)
			else:
				feature.effect_area = Rect2(center.x - 26.0, area.end.y if facing.y >= 0.0 else area.position.y - length, 52.0, length)
		"spring":
			feature.merge({"label":"回生泉台", "element":"hydro", "phase":"ready", "effect_area":area.grow(30.0),
				"capacity":80.0, "reservoir":80.0, "regen_interval":4.0, "regen_timer":4.0, "regen_amount":8.0,
				"pulse_interval":2.0, "pulse_timer":0.0, "heal_amount":14.0, "energy_amount":6.0}, true)
		"wind_lane":
			feature.merge({"label":"顺风引道", "element":"anemo", "speed_scale":1.35}, true)
		"hazard_lane":
			feature.merge({"label":"裂隙焰道", "element":"pyro", "phase":"cooldown", "timer":3.5, "cooldown":7.0,
				"warning_duration":1.3, "active_duration":1.2, "pulse_interval":0.4, "pulse_timer":0.0, "power":18.0, "hero_power":6.0}, true)
	feature.merge(options, true)
	return feature

static func tick(sim, dt: float) -> void:
	if sim.state != "running" or dt <= 0.0: return
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("type", "")) not in TYPES: continue
		feature.clock = float(feature.get("clock", 0.0)) + dt
		match str(feature.type):
			"relay": _relay(sim, feature, dt)
			"spring": _spring(sim, feature, dt)
			"hazard_lane": _hazard(sim, feature, dt)

static func movement_scale(sim, point: Vector2, direction: Vector2, actor: Dictionary, team: String) -> float:
	if direction.length_squared() < 0.0001: return 1.0
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("type", "")) != "wind_lane" or not Rect2(feature.effect_area).has_point(point): continue
		if direction.normalized().dot(Vector2(feature.facing)) <= 0.5: continue
		# Per-unit feedback is bounded; the lane never adds a separate displacement.
		var until: Dictionary = actor.get("terrain_wind_feedback", {})
		var key := str(feature.id)
		if sim.state == "running" and float(until.get(key, -1.0)) <= float(feature.clock):
			_event(sim, feature, "pulse", 1, 0.35, point)
			sim.events[-1].team = team
			sim.events[-1].unit_id = int(actor.get("id", -1))
			until[key] = float(feature.clock) + 1.5
			actor.terrain_wind_feedback = until
		return float(feature.speed_scale)
	return 1.0

static func _event(sim, feature: Dictionary, phase: String, value: int = 0, life: float = 0.35, point: Vector2 = Vector2.INF) -> void:
	sim.events.append({"kind":"terrain_react", "terrain_id":feature.id, "type":feature.type, "phase":phase,
		"pos":Rect2(feature.effect_area).get_center() if point == Vector2.INF else point,
		"area":feature.effect_area, "element":feature.element, "value":value, "life":life, "source_name":feature.label})

static func _phase(sim, feature: Dictionary, phase: String, duration: float, affected: int = 0) -> void:
	feature.phase = phase; feature.timer = duration; feature.phase_progress = 0.0
	_event(sim, feature, phase, affected, duration)

static func _relay(sim, feature: Dictionary, dt: float) -> void:
	if str(feature.phase) in ["idle", "charging"]:
		var held: bool = sim.heroes.any(func(h: Dictionary) -> bool:
			return bool(h.get("deployed", false)) and float(h.hp) > 0.0 and Rect2(feature.activation_area).has_point(h.pos))
		if not held:
			feature.phase = "idle"; feature.charge = 0.0; feature.phase_progress = 0.0; feature.timer = 0.0
			return
		feature.phase = "charging"
		feature.charge = minf(1.0, float(feature.charge) + dt / float(feature.charge_duration))
		feature.phase_progress = feature.charge
		feature.timer = (1.0 - float(feature.charge)) * float(feature.charge_duration)
		if float(feature.charge) >= 1.0 - 0.00001:
			feature.charge = 1.0
			_phase(sim, feature, "warning", float(feature.warning_duration))
		return
	feature.timer = maxf(0.0, float(feature.timer) - dt)
	var duration := float(feature.cooldown)
	if feature.phase == "warning": duration = float(feature.warning_duration)
	elif feature.phase == "active": duration = float(feature.active_duration)
	feature.phase_progress = clampf(1.0 - float(feature.timer) / maxf(0.001, duration), 0.0, 1.0)
	if float(feature.timer) > 0.00001: return
	match str(feature.phase):
		"warning":
			var affected := _damage_enemies(sim, feature)
			_phase(sim, feature, "active", float(feature.active_duration), affected)
		"active": _phase(sim, feature, "cooldown", float(feature.cooldown))
		"cooldown":
			feature.phase = "idle"; feature.charge = 0.0; feature.phase_progress = 0.0

static func _spring(sim, feature: Dictionary, dt: float) -> void:
	feature.regen_timer = float(feature.regen_timer) - dt
	while float(feature.regen_timer) <= 0.0:
		feature.regen_timer += float(feature.regen_interval)
		feature.reservoir = minf(float(feature.capacity), float(feature.reservoir) + float(feature.regen_amount))
	feature.pulse_timer = maxf(0.0, float(feature.pulse_timer) - dt)
	var affected := 0
	if float(feature.pulse_timer) <= 0.00001 and float(feature.reservoir) > 0.0:
		for h: Dictionary in sim.heroes:
			if not bool(h.get("deployed", false)) or float(h.hp) <= 0.0 or not Rect2(feature.effect_area).has_point(h.pos): continue
			var healed := minf(minf(maxf(0.0, float(h.max_hp) - float(h.hp)), float(feature.heal_amount)), float(feature.reservoir))
			h.hp += healed; feature.reservoir -= healed
			var energy := minf(minf(maxf(0.0, float(h.max_energy) - float(h.energy)), float(feature.energy_amount)), float(feature.reservoir))
			h.energy += energy; feature.reservoir -= energy
			if healed > 0.0:
				sim.events.append({"kind":"heal", "pos":h.pos, "value":ceili(healed), "hero_id":h.id, "terrain_id":feature.id})
			if energy > 0.0:
				h.max_energy_seen = maxf(float(h.get("max_energy_seen", 0.0)), float(h.energy))
				sim.events.append({"kind":"energy", "pos":h.pos, "value":ceili(energy), "hero_id":h.id, "terrain_id":feature.id})
			if healed + energy > 0.0: affected += 1
		feature.pulse_timer = float(feature.pulse_interval)
	if affected > 0: _event(sim, feature, "pulse", affected, 0.45)
	var next_phase := "depleted" if float(feature.reservoir) <= 0.00001 else "ready"
	if next_phase != str(feature.phase):
		feature.phase = next_phase
		_event(sim, feature, next_phase, 0, 0.35)
	feature.phase_progress = clampf(float(feature.reservoir) / float(feature.capacity), 0.0, 1.0)
	feature.timer = float(feature.regen_timer) if feature.phase == "depleted" else float(feature.pulse_timer)

static func _hazard(sim, feature: Dictionary, dt: float) -> void:
	feature.timer = maxf(0.0, float(feature.timer) - dt)
	var duration := float(feature.cooldown)
	if feature.phase == "warning": duration = float(feature.warning_duration)
	elif feature.phase == "active": duration = float(feature.active_duration)
	feature.phase_progress = clampf(1.0 - float(feature.timer) / maxf(0.001, duration), 0.0, 1.0)
	if feature.phase == "active":
		# End the window before considering a pulse exactly on its end boundary.
		if float(feature.timer) <= 0.00001:
			_phase(sim, feature, "cooldown", float(feature.cooldown))
			return
		feature.pulse_timer = float(feature.pulse_timer) - dt
		if float(feature.pulse_timer) <= 0.00001:
			_hazard_pulse(sim, feature)
			feature.pulse_timer += float(feature.pulse_interval)
	elif float(feature.timer) <= 0.00001:
		if feature.phase == "cooldown":
			_phase(sim, feature, "warning", float(feature.warning_duration))
		else:
			_phase(sim, feature, "active", float(feature.active_duration))
			feature.pulse_timer = float(feature.pulse_interval)
			_hazard_pulse(sim, feature)

static func _damage_enemies(sim, feature: Dictionary) -> int:
	var count := 0
	var previous_source: int = sim.damage_source_override
	sim.damage_source_override = -1
	for e: Dictionary in sim.enemies.duplicate():
		if float(e.hp) <= 0.0 or not Rect2(feature.effect_area).has_point(e.pos): continue
		var old_hp := float(e.hp); var old_shield := float(e.get("shield", 0.0))
		sim.apply_hit(e, float(feature.power), str(feature.element))
		if float(e.hp) < old_hp or float(e.get("shield", 0.0)) < old_shield:
			e.last_damage_source = {"terrain_id":feature.id, "source_name":feature.label, "element":feature.element}
			count += 1
	sim.damage_source_override = previous_source
	return count

static func _hazard_pulse(sim, feature: Dictionary) -> void:
	var count := _damage_enemies(sim, feature)
	for h: Dictionary in sim.heroes:
		if not bool(h.get("deployed", false)) or float(h.hp) <= 0.0 or not Rect2(feature.effect_area).has_point(h.pos): continue
		var old_hp := float(h.hp); var old_shield: float = sim.crystal_shield
		sim.damage_hero(int(h.id), float(feature.hero_power), {"source_name":feature.label, "source_skill":"焰道喷发", "terrain_id":feature.id, "element":feature.element})
		if float(h.hp) < old_hp or sim.crystal_shield < old_shield: count += 1
	_event(sim, feature, "pulse", count, float(feature.pulse_interval))
