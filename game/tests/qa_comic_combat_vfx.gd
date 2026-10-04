extends SceneTree
const MainScene = preload("res://main.tscn")
var capture_dir := ""
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			capture_dir = argument.trim_prefix("--capture-dir=")
			DirAccess.make_dir_recursive_absolute(capture_dir)
	call_deferred("run")

func check(value: bool, note: String) -> void:
	checks += 1
	if not value:
		failures.append(note)
		push_error("COMIC VFX: " + note)

func capture(game: Node, filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.battle.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var result: Image = game.get_viewport().get_texture().get_image()
	if not capture_dir.is_empty():
		check(result.save_png(capture_dir.path_join(filename + ".png")) == OK, "capture " + filename)

func check_frozen_landings(game: Node) -> void:
	var source: Dictionary = game.sim.spawn_enemy(Vector2(1050, 340), "boss_02")
	source.special_pending = false
	source.frozen_timer = 3.0
	game.sim.enemy_hazards.clear()
	var first := {"kind":"slime_bounce_impact", "source_id":int(source.id), "pos":Vector2(810,350), "radius":72.0, "delay":0.18, "life":0.34, "damage":1.0}
	var second := {"kind":"slime_court_final", "source_id":int(source.id), "pos":Vector2(940,440), "radius":90.0, "delay":0.36, "life":0.55, "damage":1.0}
	game.sim.enemy_hazards.append(first)
	game.sim.enemy_hazards.append(second)
	for frame in 84:
		source.frozen_timer = 3.0 - float(frame) / 30.0
		game.sim._enemy_hazard_tick(1.0 / 30.0)
		game.battle.advance(1.0 / 30.0)
	check(is_equal_approx(first.delay, 0.18) and is_equal_approx(second.delay, 0.36), "frozen source retains real delayed landings")
	check(not game.battle.effects.any(func(effect: Dictionary) -> bool: return str(effect.kind) in ["slime_bounce", "slime_court"]), "landing warning survives absent or expired cast effect")
	var warning: Dictionary = game.battle.pending_slime_hazard_telegraph(first)
	check(not warning.is_empty() and is_equal_approx(float(warning.remaining), 0.18), "bounce live warning persists after 2.8 frozen seconds")
	check(warning.pos == first.pos and is_equal_approx(float(warning.radius), float(first.radius)), "warning uses authoritative landing footprint")
	check(not game.battle.pending_slime_hazard_telegraph(second).is_empty(), "court final shares persistent pending warning")
	await capture(game, "frozen-live-landings")
	source.frozen_timer = 0.0
	for frame in 3:
		game.sim._enemy_hazard_tick(0.2)
	check(bool(first.get("triggered", false)) and bool(second.get("triggered", false)), "both delayed landings release after thaw")
	check(game.battle.pending_slime_hazard_telegraph(first).is_empty() and game.battle.pending_slime_hazard_telegraph(second).is_empty(), "released hazards stop showing pending warnings")

func run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_02", squad, 247)
	game.sim.start()
	game.sim.heroes[0].deployed = true
	game.sim.heroes[0].element = "electro"
	game.sim.heroes[0].pos = Vector2(460, 390)
	game.sim.heroes[0].target = Vector2(460, 390)
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	for world in [Vector2(670, 390), Vector2(850, 270), Vector2(980, 440)]:
		var enemy: Dictionary = game.sim.spawn_enemy(world, "grunt")
		enemy.pos = world
		if world.x > 900:
			enemy.special_pending = true
			enemy.special_warning = 0.45
			enemy.special_warning_total = 1.3
			enemy.special_warning_radius = 65.0
			enemy.special_warning_positions = [world]
			enemy.special_warning_shape = "circle"
	game.sim.drain_events()
	game.battle.reset_transients()
	game.battle.effects.clear()
	var events: Array[Dictionary] = [
		{"kind":"route_spawn", "pos":Vector2(1120, 350), "route_id":"comic_test"},
		{"kind":"death", "pos":Vector2(810, 410), "size":55.0, "enemy_kind":"runner", "color":"#ff4060"},
		{"kind":"critical", "pos":Vector2(665, 390), "value":235, "element":"electro"},
		{"kind":"roxy_thunder", "pos":Vector2(850, 270), "targets":[Vector2(850, 270), Vector2(720, 260)]},
		{"kind":"traveler_fx_arc", "pos":Vector2(670,390), "source":Vector2(460,390), "element":"electro", "delay":0.8},
		{"kind":"enemy_volatile", "pos":Vector2(890,490), "value":30}]
	game.battle.accept_events(events)
	game.sim.enemy_projectiles.append({"kind":"arrow", "pos":Vector2(650, 330), "velocity":Vector2(-420, 40), "source_id":99})
	game.sim.enemy_projectiles.append({"kind":"anemo_orb", "pos":Vector2(610, 440), "velocity":Vector2(-320, -30), "source_id":100})
	game.sim.enemy_projectiles.append({"kind":"rift_orb", "pos":Vector2(950, 330), "velocity":Vector2(-190, 50), "source_id":101, "enraged":true})
	game.sim.projectiles.append({"visual_id":555, "pos":Vector2(570, 360), "source_id":0, "target_id":0, "element":"hydro", "style":"tidal_orb"})
	game.battle.advance(0.12)
	game.refresh()
	await capture(game, "comic-impact")
	game.battle.advance(0.17)
	await capture(game, "comic-expansion")
	game.sim.heroes[0].pos = Vector2(450,180)
	game.sim.heroes[0].target = Vector2(450,180)
	game.battle.shake_trauma = 0.9
	game.battle.advance(0.01)
	await capture(game, "comic-top-boundary")
	if DisplayServer.get_name() != "headless":
		var boundary_image: Image = game.get_viewport().get_texture().get_image()
		var gutter_color: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
		var actual := boundary_image.get_pixel(450,56)
		check(absf(actual.r - gutter_color.r) < 0.01 and absf(actual.g - gutter_color.g) < 0.01 and absf(actual.b - gutter_color.b) < 0.01, "upper sprite overflow masked during shake")
	await check_frozen_landings(game)
	check(game.battle.consume_hitstop_request() > 0.0, "impact requests bounded hitstop")
	check(game.battle.consume_hitstop_request() == 0.0, "hitstop is consumed exactly once")
	var thunder_batch: Array[Dictionary] = []
	for i in 500:
		thunder_batch.append({"kind":"roxy_thunder", "pos":Vector2(500,300), "targets":[Vector2(550,300)]})
	game.battle.accept_events(thunder_batch)
	check(game.battle.effects.size() <= game.sim.performance_budget.effect_cap(), "early-continue boss/element events obey batch hard cap")
	for i in 2000:
		game.battle.comic_vfx.accept(game.battle, {"kind":"death", "pos":Vector2(300 + i % 800, 250 + i % 300), "size":48.0})
	check(game.battle.comic_vfx.accents.size() <= 72, "accent hard cap")
	game.battle.reduced_effects = true
	game.battle.comic_vfx.accept(game.battle, {"kind":"critical", "pos":Vector2(500,300)})
	check(game.battle.comic_vfx.accents.size() <= 28, "reduced accent cap")
	game.battle.comic_vfx.advance(1.0)
	check(game.battle.comic_vfx.accents.is_empty(), "expired accents released")
	check(game.battle.comic_vfx.pool.live_count() == 0, "pool has no leaked active objects")
	game.battle.reset_transients()
	check(game.battle.consume_hitstop_request() == 0.0, "stage reset clears pending hitstop")
	print("COMIC VFX QA: %d checks; %d failures; reused=%d; available=%d" % [checks, failures.size(), game.battle.comic_vfx.pool.reused, game.battle.comic_vfx.pool.available.size()])
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	quit(0 if failures.is_empty() else 1)
