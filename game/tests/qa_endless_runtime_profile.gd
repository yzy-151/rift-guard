extends SceneTree

const SAMPLE_FRAMES := 90

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 60
	var game = load("res://main.tscn").instantiate()
	root.add_child(game)
	for i in 8:
		await process_frame
	game.test_mode = true
	game.muted = true
	game.choose_stage("stage_endless")
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	game.squad_panel.root.hide()
	game.confirm_next_squad(squad)
	game.sim.endless_spawn_timer = 99999.0
	game.sim.endless_next_boss_at = 99999.0
	for hero: Dictionary in game.sim.heroes:
		hero.attack_timer = 0.0
		hero.invulnerable_timer = 99999.0
	for i in 20:
		await process_frame
	print("ENDLESS PROFILE STATE state=%s elapsed=%.2f overlays=%s" % [game.sim.state, game.sim.elapsed, game.squad_panel.is_open()])
	await _measure(game, "empty-visible", 0, true)
	await _measure(game, "empty-hidden", 0, false)
	await _measure(game, "early-visible", 18, true)
	await _measure(game, "early-hidden", 18, false)
	await _measure(game, "late-visible", 96, true)
	await _measure(game, "late-hidden", 96, false)
	await _measure(game, "center-early-visible", 18, true, true)
	await _measure(game, "center-late-visible", 96, true, true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../docs/endless-performance-after.png")
	game.set_physics_process(false)
	await _microbench(game)
	await _central_microbench(game)
	_verify_adaptive_budget()
	quit()

func _measure(game: Node, label: String, count: int, show_battle: bool, near_center: bool = false) -> void:
	game.battle.visible = show_battle
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	for i in count:
		var point: Vector2 = game.sim.ENDLESS_ARENA.get_center() + Vector2((i % 12 - 6) * 18.0, (i / 12 - 4) * 18.0) if near_center else game.sim._endless_edge_point(i % 4, 0.25 + fposmod(i * 0.17, 0.5)).move_toward(game.sim.ENDLESS_ARENA.get_center(), 36.0)
		var enemy: Dictionary = game.sim.spawn_enemy(point, "armored")
		if not enemy.is_empty():
			enemy.hp = 100000000.0
			enemy.max_hp = enemy.hp
			enemy.damage = 0.0
	for i in 12:
		await process_frame
	var wall_total := 0.0
	var wall_max := 0.0
	var process_total := 0.0
	var physics_total := 0.0
	var draw_total := 0.0
	var frame_start := Time.get_ticks_usec()
	for i in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var wall_ms := float(now - frame_start) / 1000.0
		frame_start = now
		wall_total += wall_ms
		wall_max = maxf(wall_max, wall_ms)
		process_total += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draw_total += float(root.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME))
	print("ENDLESS PROFILE %s enemies=%d wall=%.2fms max=%.2fms process=%.2fms physics=%.2fms draws=%.0f elapsed=%.1fs ram=%.1fMiB vram=%.1fMiB" % [label, game.sim.enemies.size(), wall_total / SAMPLE_FRAMES, wall_max, process_total / SAMPLE_FRAMES, physics_total / SAMPLE_FRAMES, draw_total / SAMPLE_FRAMES, game.sim.elapsed, Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])

func _microbench(game: Node) -> void:
	for count in [18, 96]:
		game.sim.enemies.clear()
		game.sim.enemy_lookup.clear()
		for i in count:
			var point: Vector2 = game.sim._endless_edge_point(i % 4, 0.25 + fposmod(i * 0.17, 0.5)).move_toward(game.sim.ENDLESS_ARENA.get_center(), 36.0)
			var enemy: Dictionary = game.sim.spawn_enemy(point, "armored")
			if not enemy.is_empty():
				enemy.hp = 100000000.0
				enemy.damage = 0.0
		var t := Time.get_ticks_usec()
		for i in 120:
			game.sim._enemy_tick(1.0 / 60.0)
		print("ENDLESS MICRO enemies=%d enemy_tick=%.2fms" % [count, float(Time.get_ticks_usec() - t) / 120000.0])
		t = Time.get_ticks_usec()
		for i in 60:
			game.sim._rebuild_endless_navigation_fields()
		print("ENDLESS MICRO enemies=%d nav_rebuild=%.2fms" % [count, float(Time.get_ticks_usec() - t) / 60000.0])
		t = Time.get_ticks_usec()
		for i in 120:
			game.hud.refresh(game.sim, game.selected_id)
		print("ENDLESS MICRO enemies=%d hud_refresh=%.2fms" % [count, float(Time.get_ticks_usec() - t) / 120000.0])
		t = Time.get_ticks_usec()
		for i in 120:
			game.sim.tick(1.0 / 60.0)
		print("ENDLESS MICRO enemies=%d sim_tick=%.2fms shots=%d projectiles=%d" % [count, float(Time.get_ticks_usec() - t) / 120000.0, game.sim.shots_fired, game.sim.projectiles.size()])
		t = Time.get_ticks_usec()
		for i in 120:
			game.sim._terrain_tick(1.0 / 60.0)
		print("ENDLESS MICRO enemies=%d terrain_tick=%.2fms" % [count, float(Time.get_ticks_usec() - t) / 120000.0])
		t = Time.get_ticks_usec()
		for i in 120:
			game.compendium.observe(game.sim)
		print("ENDLESS MICRO enemies=%d compendium=%.2fms" % [count, float(Time.get_ticks_usec() - t) / 120000.0])
func _verify_adaptive_budget() -> void:
	var budget = load("res://scripts/performance_budget.gd" ).new()
	for i in 60:
		budget.observe_render_frame(30.0)
		budget.sample(16.67, 18, 0)
	assert(budget.quality_scale < 1.0, "Frame-time overload did not reduce effects" )
	for i in 90:
		budget.observe_render_frame(16.67)
		budget.sample(16.67, 18, 0)
	assert(budget.quality_scale == 1.0, "Effects did not recover after normal frame times" )
	print("ENDLESS BUDGET render-frame overload degrades and recovers" )

func _central_microbench(game: Node) -> void:
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	for i in 96:
		var point: Vector2 = game.sim.ENDLESS_ARENA.get_center() + Vector2((i % 12 - 6) * 18.0, (i / 12 - 4) * 18.0)
		var enemy: Dictionary = game.sim.spawn_enemy(point, "armored")
		if not enemy.is_empty():
			enemy.hp = 100000000.0
			enemy.damage = 0.0
	var t := Time.get_ticks_usec()
	for i in 120:
		game.sim._enemy_tick(1.0 / 60.0)
	print("ENDLESS CENTRAL MICRO enemy_tick=%.2fms" % [float(Time.get_ticks_usec() - t) / 120000.0])
	t = Time.get_ticks_usec()
	for i in 120:
		game.sim.tick(1.0 / 60.0)
	print("ENDLESS CENTRAL MICRO sim_tick=%.2fms" % [float(Time.get_ticks_usec() - t) / 120000.0])