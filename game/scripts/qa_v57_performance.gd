extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V57 PERF PASS: " + message)
	else:
		failures += 1
		push_error("V57 PERF FAIL: " + message)

func run(game) -> void:
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.sim.reset_stage("stage_endless", squad, 5702)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.hp = 1000000.0
		hero.max_hp = 1000000.0
		hero.deployed = true
	game.sim.elapsed = 0.0
	var early_cap: int = game.sim._endless_active_cap()
	var early_low_cap: int = game.sim._endless_low_tier_cap()
	var early_scales: Dictionary = game.sim._endless_enemy_scales(game.sim._endless_tier())
	game.sim.elapsed = 600.0
	var late_cap: int = game.sim._endless_active_cap()
	var late_low_cap: int = game.sim._endless_low_tier_cap()
	var late_scales: Dictionary = game.sim._endless_enemy_scales(game.sim._endless_tier())
	expect(early_cap < late_cap and late_cap <= 96, "active population budget grows from %d to %d without exceeding 96" % [early_cap, late_cap])
	expect(late_low_cap < early_low_cap, "late low-tier budget shrinks from %d to %d" % [early_low_cap, late_low_cap])
	expect(float(early_scales.health) <= 1.0 and float(late_scales.health) > 4.0, "health scaling separates early and late threats")
	expect(float(early_scales.damage) <= 1.0 and float(late_scales.damage) > 2.0, "damage scaling separates early and late threats")
	expect(game.sim.performance_budget.MAX_ENEMIES == 112 and game.sim.performance_budget.MAX_EFFECTS == 180, "simulation and cosmetic budgets are aligned")

	game.sim.enemies.clear()
	game.sim.elapsed = 600.0
	var kinds := ["grunt", "runner", "slime_pyro", "armored", "charger", "shielded", "warder"]
	for index in 120:
		var angle := float(index) * TAU / 120.0
		var radius := 430.0 + float(index % 5) * 46.0
		var kind: String = "buffer" if index < 3 else str(kinds[index % kinds.size()])
		var enemy: Dictionary = game.sim.spawn_enemy(game.sim.ENDLESS_ARENA.get_center() + Vector2.from_angle(angle) * radius, kind)
		game.sim._apply_endless_scaling(enemy, game.sim._endless_tier())
	var view_size := Vector2(1248, 490)
	game.sim.set_active_view_rect(Rect2(game.sim.heroes[0].pos - view_size * 0.5, view_size))
	game.sim.enemy_support_scan_timer = 0.0
	var start_usec := Time.get_ticks_usec()
	for frame in 120:
		game.sim.elapsed += 1.0 / 60.0
		game.sim._enemy_tick(1.0 / 60.0)
	var elapsed_usec := Time.get_ticks_usec() - start_usec
	var average_ms := float(elapsed_usec) / 120000.0
	expect(game.sim.enemy_support_scan_timer > 0.0, "support aura scan is throttled instead of running every frame")
	expect(elapsed_usec < 3000000, "120-enemy CPU benchmark completes in %.2f ms/frame" % average_ms)

	game.battle.camera_center = game.sim.heroes[0].pos
	expect(game.battle._render_point_visible(game.sim.heroes[0].pos, 0.0), "camera-center actors remain visible")
	expect(not game.battle._render_point_visible(game.sim.ENDLESS_ARENA.position, 0.0), "off-screen actors are culled from rendering")
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.endless_next_boss_at = 9999.0
	game.sim.endless_spawn_timer = 0.0
	while game.sim.enemies.size() < game.sim._endless_active_cap():
		var index: int = game.sim.enemies.size()
		game.sim.spawn_enemy(game.sim._endless_edge_point(index % 4, 0.25 + fposmod(index * 0.17, 0.5)), "armored")
	var count_before: int = game.sim.enemies.size()
	game.sim._endless_spawn_tick(0.2)
	expect(game.sim.enemies.size() == count_before, "spawn budget prevents population overflow at %d actors" % count_before)

	print("V57 PERF QA COMPLETE: %d checks, %d failures; benchmark %.2f ms/frame" % [checks, failures, average_ms])
	game.get_tree().quit(failures)
