extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V65 PASS: " + message)
	else:
		failures += 1
		push_error("V65 FAIL: " + message)

func _tick_for(sim, seconds: float, step: float = 0.05) -> void:
	for _i in ceili(seconds / step):
		sim.tick(step)

func _cell_key(cell: Rect2) -> String:
	return "%d:%d" % [roundi(cell.position.x), roundi(cell.position.y)]

func run(game) -> void:
	var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
	var overlap_count := 0
	var route_wall_overlaps: Array[String] = []
	var terrain_layout_signatures := {}
	var stages_without_spawns: Array[int] = []
	var stages_without_movement: Array[int] = []
	for stage_number in range(1, 9):
		game.sim.reset_stage("stage_%02d" % stage_number, squad, 6500 + stage_number)
		game.sim.start()
		_tick_for(game.sim, 8.0)
		if game.sim.enemies.is_empty():
			stages_without_spawns.append(stage_number)
		else:
			var campaign_enemy: Dictionary = game.sim.enemies[0]
			var campaign_start: Vector2 = campaign_enemy.pos
			_tick_for(game.sim, 1.5)
			if campaign_enemy.pos.distance_to(campaign_start) <= 8.0:
				stages_without_movement.append(stage_number)
		for route_id: String in game.sim.stage_runtime.definition.get("routes", {}):
			var route_points: Array[Vector2] = game.sim.stage_route(route_id)
			for route_index in range(maxi(0, route_points.size() - 1)):
				var route_blocker: Dictionary = game.sim._terrain_blocker_on_segment(route_points[route_index], route_points[route_index + 1], 18.0)
				if not route_blocker.is_empty():
					route_wall_overlaps.append("%s/%s/%s" % [game.sim.current_stage_id, route_id, str(route_blocker.get("id", "blocked"))])
		if stage_number == 1:
			continue
		var occupied := {}
		var layout_parts: Array[String] = []
		for feature: Dictionary in game.sim.terrain_features:
			if str(feature.get("type", "")) not in ["blocked", "trap", "high_ground", "low_ground", "attack_ground"]:
				continue
			for cell: Rect2 in feature.get("grid_cells", []):
				var key := _cell_key(cell)
				layout_parts.append("%s@%s" % [str(feature.get("type", "")), key])
				if occupied.has(key):
					overlap_count += 1
				else:
					occupied[key] = str(feature.get("id", feature.get("type", "")))
		layout_parts.sort()
		terrain_layout_signatures["|".join(layout_parts)] = true
	expect(stages_without_spawns.is_empty(), "all eight campaign stages emit their scheduled enemies")
	expect(stages_without_movement.is_empty(), "all eight campaign stages advance enemies from spawn")
	expect(overlap_count == 0, "all campaign terrain decals have unique grid cells")
	expect(route_wall_overlaps.is_empty(), "campaign routes never cross blocking walls" if route_wall_overlaps.is_empty() else "campaign route blockers: %s" % [", ".join(route_wall_overlaps)])
	expect(terrain_layout_signatures.size() == 7, "stages 02-08 use seven distinct terrain layouts")
	game.sim.reset_stage("stage_endless", squad, 6502)
	game.sim.start()
	_tick_for(game.sim, 0.4)
	expect(not game.sim.enemies.is_empty(), "endless mode spawns enemies")
	if not game.sim.enemies.is_empty():
		var endless_enemy: Dictionary = game.sim.enemies[0]
		var endless_start: Vector2 = endless_enemy.pos
		_tick_for(game.sim, 2.0)
		expect(endless_enemy.pos.distance_to(endless_start) > 8.0, "endless enemy advances toward the party")
	game.sim.reset_stage("stage_01", squad, 6503)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var hero: Dictionary = game.sim.heroes[1]
	for hero_index in game.sim.heroes.size():
		var squad_hero: Dictionary = game.sim.heroes[hero_index]
		squad_hero.deployed = true
		squad_hero.pos = Vector2(640, 390 + hero_index * 30)
		squad_hero.target = Vector2(920, 390 + hero_index * 30)
		squad_hero.moving = true
		squad_hero.attack_timer = 0.0
	var target: Dictionary = game.sim.spawn_enemy(Vector2(760, 420), "grunt")
	target.speed = 0.0
	game.sim.events.clear()
	game.sim._hero_tick()
	var shot_events: Array = game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "shot")
	var attacking_heroes := {}
	for shot: Dictionary in shot_events:
		attacking_heroes[int(shot.get("hero_id", -1))] = true
	expect(attacking_heroes.size() == game.sim.heroes.size(), "every moving squad member attacks an enemy inside attack range")
	expect(not game.sim.projectiles.is_empty(), "ranged hero attack creates a projectile")
	if not game.sim.projectiles.is_empty():
		var projectile_start: Vector2 = game.sim.projectiles[0].pos
		game.sim._projectile_tick(0.05)
		expect(game.sim.projectiles.is_empty() or game.sim.projectiles[0].pos.distance_to(projectile_start) > 1.0, "hero projectile advances visibly before impact")
	game.battle.effects.clear()
	game.battle.accept_events(game.sim.drain_events())
	expect(not game.battle.effects.is_empty(), "battle view accepts attack VFX events")
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var flyer: Dictionary = game.sim.spawn_enemy(Vector2(1000, 180), "flyer")
	flyer.route_points = [flyer.pos, Vector2(200, 500)]
	flyer.route_index = 1
	flyer.speed = 120.0
	var flyer_start: Vector2 = flyer.pos
	game.sim._enemy_tick(0.1)
	var flyer_delta: Vector2 = flyer.pos - flyer_start
	expect(absf(flyer_delta.x) > 1.0 and absf(flyer_delta.y) > 1.0, "flying enemy travels directly toward the final destination")
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	for squad_hero: Dictionary in game.sim.heroes:
		squad_hero.deployed = squad_hero == hero
	var archer: Dictionary = game.sim.spawn_enemy(Vector2(360, 420), "ranged")
	archer.speed = 0.0
	archer.attack_timer = 0.0
	hero.pos = Vector2(760, 420)
	game.sim.events.clear()
	game.sim._enemy_tick(0.1)
	expect(not bool(archer.get("attack_pending", false)), "hilichurl archer does not acquire a target outside attack range")
	hero.pos = Vector2(520, 420)
	archer.attack_timer = 0.0
	game.sim._enemy_tick(0.1)
	expect(bool(archer.get("attack_pending", false)), "hilichurl archer acquires a target inside attack range")
	game.sim.events.clear()
	game.sim._resolve_enemy_warning(archer)
	var enemy_shots: Array = game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "enemy_shot")
	expect(not enemy_shots.is_empty(), "hilichurl archer emits its attack projectile VFX inside range")
	game.battle.effects.clear()
	game.battle.accept_events(game.sim.drain_events())
	expect(game.battle.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "enemy_shot"), "battle view accepts enemy projectile VFX")
	archer.attack_timer = 0.0
	hero.pos = Vector2(520, 420)
	game.sim._enemy_tick(0.1)
	hero.pos = Vector2(900, 420)
	game.sim.events.clear()
	game.sim._resolve_enemy_warning(archer)
	enemy_shots = game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "enemy_shot")
	expect(enemy_shots.is_empty(), "hilichurl archer cannot resolve a shot beyond attack range")
	print("V65 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
