extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V77 ENDLESS PASS: " + message)
	else:
		failures += 1
		push_error("V77 ENDLESS FAIL: " + message)

func run(game) -> void:
	var original_unlocks: Dictionary = game.compendium.unlocked_characters.duplicate(true)
	for id: String in ["traveler", "hero_01", "hero_03"]:
		game.compendium.unlocked_characters[id] = true
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	game.sim.run_state.set_squad(squad)
	var previous_stage: String = str(game.sim.current_stage_id)
	game.choose_stage("stage_endless")
	expect(game.squad_panel.is_open(), "endless mode opens squad selection before combat")
	expect(game.sim.current_stage_id == previous_stage, "endless combat waits for squad confirmation")
	expect(game.squad_panel.title.text == "\u65e0\u5c3d\u751f\u5b58\uff1a\u9009\u62e9\u51fa\u6218\u89d2\u8272", "endless squad selection has a dedicated heading")
	game.confirm_next_squad(squad)
	expect(game.sim.endless_mode and game.sim.heroes.size() == 3, "confirmed endless squad contains three heroes")
	expect(game.sim.heroes.all(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false))), "all three endless heroes deploy at the initial stage")

	for hero: Dictionary in game.sim.heroes:
		hero.pos = Vector2(1280, 720)
		hero.target = hero.pos
		hero.hp = 1000000.0
		hero.max_hp = 1000000.0
		hero.block = 0
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.endless_spawn_timer = 9999.0
	game.sim.endless_next_boss_at = 9999.0
	game.sim.troop_convoy_timer = 9999.0
	var walker: Dictionary = game.sim.spawn_enemy(Vector2(900, 220), "grunt")
	walker.speed = 110.0
	walker.damage = 120.0
	walker.hp = 1000000.0
	walker.max_hp = 1000000.0
	var initial_distance := Vector2(walker.pos).distance_to(game.sim.heroes[0].pos)
	for frame in 600:
		game.sim._enemy_tick(1.0 / 30.0)
	var final_distance := Vector2(walker.pos).distance_to(game.sim.heroes[0].pos)
	print("V77 NAV TRACE: start %.1f final %.1f pos=%s" % [initial_distance, final_distance, str(walker.pos)])
	expect(final_distance < initial_distance - 300.0, "ground enemy routes around the north wall toward a hero")
	expect(game.sim._terrain_blocker_at(Vector2(walker.pos), 12.0).is_empty(), "navigation never places the enemy inside a wall")

	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.elapsed = 900.0
	game.sim.endless_boss_index = 5
	var kinds := ["grunt", "runner", "buffer", "ranged", "armored", "charger", "shielded", "hilichurl_brute", "warder"]
	for index in game.sim._endless_active_cap():
		var side: int = index % 4
		var ratio: float = 0.08 + fposmod(float(index) * 0.173, 0.84)
		var point: Vector2 = game.sim._endless_edge_point(side, ratio).move_toward(game.sim.ENDLESS_ARENA.get_center(), 36.0)
		var kind: String = "buffer" if index < 3 else str(kinds[(index + 1) % kinds.size()])
		var enemy: Dictionary = game.sim.spawn_enemy(point, kind)
		enemy.hp = maxf(enemy.hp, 1000000.0)
		enemy.max_hp = enemy.hp
	for index in game.sim.MAX_ENDLESS_ENEMY_PROJECTILES + 30:
		game.sim._queue_enemy_projectile({"pos":Vector2(100,100),"target_id":0,"damage":0.0,"speed":0.0,"life":30.0})
	for index in game.sim.MAX_ENDLESS_ENEMY_HAZARDS + 20:
		game.sim._queue_enemy_hazard({"kind":"load_probe","pos":Vector2(200,200),"radius":10.0,"life":30.0})
	expect(game.sim.enemies.size() <= 96, "late endless active population is bounded at 96")
	expect(game.sim.enemy_projectiles.size() == game.sim.MAX_ENDLESS_ENEMY_PROJECTILES, "enemy projectile accumulation is capped")
	expect(game.sim.enemy_hazards.size() == game.sim.MAX_ENDLESS_ENEMY_HAZARDS, "persistent enemy hazards are capped")
	game.sim.state = "running"
	game.sim.endless_spawn_timer = 9999.0
	game.sim.endless_next_boss_at = 9999.0
	game.sim.troop_convoy_timer = 9999.0
	var started := Time.get_ticks_usec()
	for frame in 120:
		game.sim.tick(1.0 / 60.0)
		game.sim.drain_events()
	var elapsed_usec := Time.get_ticks_usec() - started
	var average_ms := float(elapsed_usec) / 120000.0
	expect(average_ms < 16.0, "full late-endless simulation stays below 16 ms/frame (%.2f ms)" % average_ms)

	game.compendium_panel.open("achievements")
	await game.get_tree().process_frame
	var rows: Array[Node] = game.compendium_panel.list.get_children()
	var first_row: HBoxContainer = rows[0] if not rows.is_empty() else null
	expect(first_row != null and first_row.get_child_count() == 4, "achievement wall uses four cards per row")
	if first_row != null and first_row.get_child_count() > 0:
		var tile: Control = first_row.get_child(0)
		expect(tile.custom_minimum_size == Vector2(264, 158), "achievement card matches squad-card proportions")
		expect(tile.get_child_count() > 0 and tile.get_child(0) is TextureRect, "achievement card uses the same proportional frame treatment")
	game.compendium_panel.close()
	game.compendium.unlocked_characters = original_unlocks

	print("V77 ENDLESS QA COMPLETE: %d checks, %d failures; full benchmark %.2f ms/frame" % [checks, failures, average_ms])
	game.get_tree().quit(failures)
