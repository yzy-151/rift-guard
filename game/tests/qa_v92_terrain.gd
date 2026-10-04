extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const TYPES = ["relay", "spring", "wind_lane", "hazard_lane"]
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func _initialize() -> void: call_deferred("run")

func arena():
	var s = Sim.new(9201, true)
	s.reset_stage("stage_01", ["traveler", "hero_04", "hero_08"], 9201)
	s.terrain_features.clear(); s.enemies.clear(); s.enemy_lookup.clear(); s.events.clear()
	s.state = "running"; s.crystal_shield = 0.0
	for h: Dictionary in s.heroes:
		h.deployed = true; h.pos = Vector2(450, 360); h.target = h.pos
		h.max_hp = 1000.0; h.hp = 1000.0; h.armor = 0.0; h.energy = 0.0
		h.attack_timer = 999.0; h.heal_timer = 999.0
	return s

func fixture(type: String, id: String = "fixture") -> Dictionary:
	var area := Rect2(400, 320, 100, 80)
	return {"id":id, "type":type, "label":"测试机关", "area":area, "base_area":area,
		"effect_area":Rect2(500, 334, 360, 52) if type == "relay" else area,
		"activation_area":area.grow(34), "facing":Vector2.RIGHT,
		"element":"electro" if type == "relay" else ("pyro" if type == "hazard_lane" else "hydro"),
		"phase":"idle" if type == "relay" else ("cooldown" if type == "hazard_lane" else ("ready" if type == "spring" else "active")),
		"phase_progress":0.0, "charge":0.0, "timer":0.0, "clock":0.0,
		"charge_duration":2.4, "warning_duration":0.85 if type == "relay" else 1.3,
		"active_duration":0.22 if type == "relay" else 1.2, "cooldown":8.0 if type == "relay" else 7.0,
		"power":70.0 if type == "relay" else 18.0, "hero_power":6.0,
		"pulse_interval":2.0 if type == "spring" else 0.4, "pulse_timer":0.0,
		"capacity":80.0, "reservoir":80.0, "regen_interval":4.0, "regen_amount":8.0, "regen_timer":4.0,
		"heal_amount":14.0, "energy_amount":6.0, "speed_scale":1.35}

func enemy(s, point: Vector2) -> Dictionary:
	var e: Dictionary = s.spawn_enemy(point, "grunt")
	e.pos = point; e.hp = 10000.0; e.max_hp = e.hp; e.armor = 0.0; e.speed = 0.0
	e.damage = 0.0; e.special_timer = 999.0; e.tactic_cooldown = 999.0
	return e

func step(s, duration: float) -> void:
	var remaining := duration
	while remaining > 0.00001:
		var dt := minf(0.05, remaining)
		s._terrain_tick(dt)
		remaining -= dt

func terrain_events(s, id: String, phase: String = "") -> Array:
	return s.events.filter(func(e: Dictionary) -> bool:
		return e.get("kind", "") == "terrain_react" and e.get("terrain_id", "") == id and (phase.is_empty() or e.get("phase", "") == phase))

func test_relay() -> void:
	var s = arena(); var f := fixture("relay"); s.terrain_features.append(f)
	var h: Dictionary = s.heroes[0]
	for ally: Dictionary in s.heroes: ally.deployed = false
	var inside := enemy(s, Vector2(630, 360)); var outside := enemy(s, Vector2(850, 390))
	step(s, 3.0)
	check(f.phase == "idle" and f.charge == 0.0 and inside.hp == 10000.0, "relay requires a living deployed hero to charge")
	h.deployed = true; h.hp = 0.0; step(s, 1.0)
	check(f.charge == 0.0, "downed hero cannot charge relay")
	h.hp = 1000.0; step(s, 1.0)
	check(f.charge > 0.3 and f.phase == "charging", "relay gains charge while hero holds its activation area")
	h.pos = Vector2(200, 360); step(s, 0.1)
	check(f.charge == 0.0 and f.phase == "idle", "leaving relay before full charge cancels incomplete charge")
	h.pos = Vector2(450, 360); step(s, 2.45)
	check(f.phase == "warning" and inside.hp == 10000.0, "charged relay visibly warns before doing damage")
	inside.aura = "hydro"; inside.aura_timer = 10.0
	step(s, 0.86)
	check(inside.hp < 10000.0 and s.reactions > 0, "relay electro line deals actual damage and triggers existing elemental reactions")
	check(outside.hp == 10000.0, "relay uses effect rectangle instead of a radial hit")
	check(not terrain_events(s, f.id, "active").is_empty(), "relay activation uses shared terrain_react feedback")
	var activations := terrain_events(s, f.id, "active")
	check(not activations.is_empty() and int(activations[0].value) == 1, "relay feedback reports its actual directly affected target count")
	var after: float = inside.hp; step(s, 0.5)
	check(f.phase == "cooldown" and inside.hp == after, "relay damages once and enters its own cooldown")
	var second := fixture("relay", "second"); second.area = Rect2(400, 440, 100, 80); second.activation_area = second.area
	s.terrain_features.append(second); h.pos = Vector2(450, 480); step(s, 1.0)
	check(second.charge > 0.3 and f.phase == "cooldown", "relay instances charge and cool down independently")

func test_spring() -> void:
	var s = arena(); var f := fixture("spring"); s.terrain_features.append(f)
	var h: Dictionary = s.heroes[0]
	for ally: Dictionary in s.heroes: ally.energy = ally.max_energy
	step(s, 2.2)
	check(f.reservoir == f.capacity and terrain_events(s, f.id).is_empty(), "full heroes consume no spring water and cause no repeated feedback")
	h.hp = 960.0; h.energy = 0.0; s.heroes[1].deployed = false; s.heroes[1].hp = 500.0; s.heroes[2].hp = 0.0
	step(s, 2.05)
	check(h.hp == 974.0 and h.energy == 6.0, "spring restores real health and ultimate energy")
	check(s.heroes[1].hp == 500.0 and s.heroes[2].hp == 0.0, "spring ignores undeployed and downed heroes")
	check(f.reservoir < f.capacity, "spring pays actual recovery from a shared finite reservoir")
	check(s.events.any(func(e: Dictionary) -> bool: return e.get("kind", "") == "heal" and int(e.get("value", 0)) > 0), "spring emits existing positive healing feedback")
	f.reservoir = 3.0; f.regen_timer = 4.0; f.pulse_timer = 0.0; h.hp = 900.0; h.energy = 0.0
	step(s, 0.05)
	check(h.hp == 903.0 and h.energy == 0.0 and f.reservoir == 0.0, "spring cannot restore more than its remaining resource")
	check(f.phase == "depleted", "spent spring exposes a depleted state")
	h.deployed = false; step(s, 4.0)
	check(f.reservoir == 8.0 and f.phase == "ready", "spring replenishes only a bounded amount after its recovery interval")
	step(s, 80.0)
	check(f.reservoir == 80.0, "spring replenishment never exceeds capacity")

func test_hazard() -> void:
	var s = arena(); var f := fixture("hazard_lane"); s.terrain_features.append(f)
	var h: Dictionary = s.heroes[0]; var inside := enemy(s, Vector2(450, 360)); var outside := enemy(s, Vector2(510, 360))
	s.heroes[1].pos = Vector2(510, 360); s.heroes[2].deployed = false
	step(s, 1.0)
	check(f.phase == "warning" and h.hp == 1000.0 and inside.hp == 10000.0, "hazard has a harmless readable warning before eruption")
	step(s, 0.4)
	check(f.phase == "active" and h.hp < 1000.0 and inside.hp < 10000.0, "hazard eruption damages both teams")
	check(outside.hp == 10000.0 and s.heroes[1].hp == 1000.0 and s.heroes[2].hp == 1000.0, "hazard rectangle excludes outside and undeployed units")
	check(str(inside.aura) == "pyro" and s.last_incoming_hit.source_name == f.label, "hazard records elemental aura and a named damage source")
	step(s, 1.3); var health: float = h.hp
	check(f.phase == "cooldown", "hazard short active window finishes in cooldown")
	step(s, 3.0)
	check(h.hp == health, "hazard cooldown is safe and does not continue ticking damage")
	var pulses := terrain_events(s, f.id, "pulse")
	check(pulses.size() == 3, "hazard has exactly three bounded pulses per eruption")
	check(not pulses.is_empty() and pulses[0].area == f.effect_area, "hazard feedback and hit detection share exact area")

func test_wind() -> void:
	var s = arena(); var f := fixture("wind_lane"); f.area = Rect2(300, 250, 600, 220); f.effect_area = f.area; s.terrain_features.append(f)
	var h: Dictionary = s.heroes[0]; h.pos = Vector2(450, 360); h.target = Vector2(800, 360); h.speed = 100.0
	s._move_hero_with_terrain(h, 0.1)
	check(is_equal_approx(h.pos.x, 463.5), "wind increases actual aligned hero movement by 35 percent")
	h.pos = Vector2(450, 360); h.target = Vector2(300, 360); s._move_hero_with_terrain(h, 0.1)
	check(is_equal_approx(h.pos.x, 440.0), "wind does not force or accelerate movement against its direction")
	h.pos = Vector2(450, 360); h.target = h.pos; s._move_hero_with_terrain(h, 1.0)
	check(h.pos == h.target, "wind never displaces a stationary defender")
	s.terrain_features.append({"type":"blocked", "area":Rect2(520, 290, 70, 140)})
	h.target = Vector2(800, 360)
	var clear := true
	for frame in 100:
		s._move_hero_with_terrain(h, 0.05)
		clear = clear and not s._terrain_blocks(h.pos, 17.0) and s._movement_bounds().has_point(h.pos)
	check(clear, "wind movement preserves wall collision and arena bounds")
	s = arena(); f = fixture("wind_lane"); f.area = Rect2(300, 200, 700, 300); f.effect_area = f.area; f.facing = Vector2.LEFT; s.terrain_features.append(f)
	for ally: Dictionary in s.heroes: ally.deployed = false
	var e := enemy(s, Vector2(700, 360)); e.speed = 100.0; e.route_points = [Vector2(900,360),Vector2(100,360)]; e.route_index = 1
	s._enemy_tick(0.1)
	check(is_equal_approx(e.pos.x, 686.5) and is_equal_approx(e.pos.y, 360.0), "wind assists grounded enemies without changing their road")
	s = arena(); f = fixture("wind_lane"); f.area = Rect2(300, 200, 700, 300); f.effect_area = f.area; f.facing = Vector2.LEFT; s.terrain_features.append(f)
	h = s.heroes[0]; h.hp = 100000.0; h.max_hp = h.hp; h.pos = Vector2(550,360); h.target = h.pos
	s.heroes[1].deployed = false; s.heroes[2].deployed = false
	var crowd: Array[Dictionary] = []
	for index in 8:
		e = enemy(s, Vector2(800+index*7,330+index*7)); e.speed = 100.0; e.damage = 10.0
		e.route_points = [Vector2(1050,360),Vector2(100,360)]; e.route_index = 1
		crowd.append(e)
	var worst_backstep:=0.0
	for frame in 260:
		var before:Array[Vector2]=[]
		for unit:Dictionary in crowd:before.append(unit.pos)
		for ally: Dictionary in s.heroes: ally.blocked = 0
		s._enemy_tick(0.05)
		for i in crowd.size():worst_backstep=maxf(worst_backstep,float(crowd[i].pos.x)-before[i].x)
	var closest_hero := INF; var closest_enemy := INF
	for a in crowd.size():
		closest_hero = minf(closest_hero, Vector2(crowd[a].pos).distance_to(h.pos))
		for b in range(a+1, crowd.size()): closest_enemy = minf(closest_enemy, Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	check(closest_hero >= 59.0 and closest_enemy >= 6.9 and worst_backstep<0.01, "wind-assisted overlapping spawn crowd holds hero spacing without compression or backward walking")
	check(h.hp < 100000.0, "wind-assisted melee front rank still lands actual attacks")
	for i in crowd.size():crowd[i].pos=Vector2(650+i*48,360);crowd[i].route_returning=false
	for frame in 260:
		for ally:Dictionary in s.heroes:ally.blocked=0
		s._enemy_tick(0.05)
	closest_enemy=INF
	for a in crowd.size():
		for b in range(a+1,crowd.size()):closest_enemy=minf(closest_enemy,Vector2(crowd[a].pos).distance_to(crowd[b].pos))
	check(closest_enemy>=38,"wind-assisted normally separated crowd retains full body spacing")

func test_lifecycle_and_layouts() -> void:
	var s = arena(); var relay := fixture("relay"); var spring := fixture("spring"); spring.reservoir = 0.0
	s.terrain_features.append_array([relay, spring, fixture("hazard_lane")])
	for state: String in ["paused", "reward", "ready", "won", "lost", "between", "stage_exit"]:
		s.state = state; s.wave_timer = 999.0
		var before: Array = s.terrain_features.duplicate(true)
		s.tick(0.5)
		check(s.terrain_features == before, state + " freezes functional terrain timers and resources")
	var all_types := {}; var campaign_counts: Array[int] = []
	for index in range(1, 9):
		s.reset_stage("stage_%02d" % index, ["traveler"], 9201)
		var features: Array = s.terrain_features.filter(func(f: Dictionary) -> bool: return f.type in TYPES)
		campaign_counts.append(features.size())
		check(not features.is_empty(), "campaign %d includes functional terrain" % index)
		var old_count: int = s.terrain_features.filter(func(f: Dictionary) -> bool: return f.type not in TYPES).size()
		check(old_count > 5, "campaign %d preserves original map features" % index)
		for f: Dictionary in features:
			all_types[f.type] = true
			check(not s._feature_blocks(f) and s.MOVE_AREA.encloses(f.area) and s.MOVE_AREA.encloses(f.effect_area), "%s stays nonblocking and inside its map" % f.id)
			var clear := true
			for blocker: Dictionary in s.terrain_features:
				if not s._feature_blocks(blocker): continue
				clear = clear and not s._feature_collision_rect(blocker).grow(18.0).intersects(f.area) and not s._feature_collision_rect(blocker).intersects(f.effect_area)
			check(clear, "%s pedestal and effect clear old walls and doors" % f.id)
			check(f.has("phase_progress") and f.has("activation_area") and f.has("facing"), "%s exposes render contract" % f.id)
	check(campaign_counts[0] == 1 and campaign_counts[-1] >= 4 and all_types.size() == 4, "campaign introduces the four mechanics gradually")
	for id: String in ["blood_gate", "frost_isles", "wind_cross"]:
		s.select_endless_layout(id); s.reset_stage("stage_endless", ["traveler"], 9201)
		var features: Array = s.terrain_features.filter(func(f: Dictionary) -> bool: return f.type in TYPES)
		check(features.size() >= 4, "endless %s includes meaningful functional terrain" % id)
		var clear := true
		for f: Dictionary in features:
			clear = clear and s.ENDLESS_ARENA.encloses(f.effect_area) and s.ENDLESS_ARENA.encloses(f.area)
			for blocker: Dictionary in s.terrain_features:
				if s._feature_blocks(blocker): clear = clear and not s._feature_collision_rect(blocker).grow(18.0).intersects(f.area) and not s._feature_collision_rect(blocker).intersects(f.effect_area)
		check(clear, "endless %s effect regions clear walls and map edges" % id)
		var spring_features: Array = features.filter(func(f: Dictionary) -> bool: return f.type == "spring")
		if not spring_features.is_empty():
			var f: Dictionary = spring_features[0]; var h: Dictionary = s.heroes[0]
			h.pos = f.effect_area.get_center(); h.hp = h.max_hp - 30.0; h.energy = 0.0
			s.state = "running"; var before: float = h.hp; step(s, 2.1)
			check(h.hp > before and h.energy > 0.0, "endless %s ticks real terrain despite legacy early return" % id)
			s.reset_stage("stage_endless", ["traveler"], 9201)
			check(s.terrain_features.filter(func(f: Dictionary) -> bool: return f.type == "spring").all(func(f: Dictionary) -> bool: return f.reservoir == f.capacity), "endless %s reset restores independent resource state" % id)
	for option: Dictionary in s.endless_layout_options():
		check(option.preview_regions.filter(func(f: Dictionary) -> bool: return f.type in TYPES).size() >= 4, "%s preview includes functional terrain in its actual map positions" % option.id)
	s.reset_stage("stage_01", ["traveler"], 9201)
	check(s.terrain_features.filter(func(f: Dictionary) -> bool: return f.type in TYPES).size() == 1 and not s.endless_mode, "campaign reset clears endless-only functional features")

func run() -> void:
	test_relay(); test_spring(); test_hazard(); test_wind(); test_lifecycle_and_layouts()
	print("V92 TERRAIN: checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
