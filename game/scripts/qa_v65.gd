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
		if stage_number == 1:
			continue
		var occupied := {}
		for feature: Dictionary in game.sim.terrain_features:
			if str(feature.get("type", "")) not in ["blocked", "trap", "high_ground", "low_ground", "attack_ground"]:
				continue
			for cell: Rect2 in feature.get("grid_cells", []):
				var key := _cell_key(cell)
				if occupied.has(key):
					overlap_count += 1
				else:
					occupied[key] = str(feature.get("id", feature.get("type", "")))
	expect(stages_without_spawns.is_empty(), "all eight campaign stages emit their scheduled enemies")
	expect(stages_without_movement.is_empty(), "all eight campaign stages advance enemies from spawn")
	expect(overlap_count == 0, "all campaign terrain decals have unique grid cells")
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
	hero.deployed = true
	hero.pos = Vector2(640, 420)
	hero.target = hero.pos
	hero.moving = false
	hero.attack_timer = 0.0
	var target: Dictionary = game.sim.spawn_enemy(Vector2(760, 420), "grunt")
	target.speed = 0.0
	game.sim.events.clear()
	game.sim._hero_tick()
	var shot_events: Array = game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "shot")
	expect(not shot_events.is_empty(), "hero attack emits a shot event")
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
