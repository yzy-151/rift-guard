extends SceneTree

const MainScene = preload("res://main.tscn")
const OUTPUT = "res://../outputs/stage1-redesign/"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	game.story.reset()
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	var stage_id := "stage_02" if "--stage-02" in OS.get_cmdline_user_args() else "stage_01"
	var depth_rows := "--depth-rows" in OS.get_cmdline_user_args()
	var combat_frames := "--combat-frames" in OS.get_cmdline_user_args()
	var pad_demo := "--pad-demo" in OS.get_cmdline_user_args()
	game.sim.reset_stage(stage_id, squad, 9317)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var hero_points := [Vector2(380, 455), Vector2(505, 410), Vector2(560, 285)] if pad_demo else [Vector2(410, 335), Vector2(505, 410), Vector2(560, 285)]
	for index in mini(game.sim.heroes.size(), hero_points.size()):
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = hero_points[index]
		hero.target = hero.pos
	if depth_rows:
		for index in range(1, game.sim.heroes.size()):
			game.sim.heroes[index].deployed = false
	else:
		for enemy_spec in [["grunt", Vector2(830, 260)], ["grunt", Vector2(940, 420)], ["ranged", Vector2(1030, 335)], ["grunt", Vector2(780, 485)]]:
			game.sim.spawn_enemy(enemy_spec[1], enemy_spec[0])
	game.sim.drain_events()
	game.hud.get_child(0).show()
	game.selected_id = 0
	game.refresh()
	game.battle.advance(0.1)
	for index in 4:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	if combat_frames:
		var frames_folder := folder.path_join("combat_frames")
		DirAccess.make_dir_recursive_absolute(frames_folder)
		game.selected_id = -1
		for frame in 40:
			game.sim.tick(0.125)
			game.battle.advance(0.125)
			game.refresh()
			await process_frame
			RenderingServer.force_draw()
			await process_frame
			var frame_file := frames_folder.path_join("frame_%03d.png" % frame)
			if game.get_viewport().get_texture().get_image().save_png(frame_file) != OK:
				push_error("stage 1 combat frame failed: " + frame_file)
				quit(1)
				return
		print("STAGE1_COMBAT_FRAMES_OK ", frames_folder)
		quit(0)
		return
	if depth_rows:
		for row in [{"name": "top", "y": 230.0}, {"name": "middle", "y": 360.0}, {"name": "bottom", "y": 500.0}]:
			var hero: Dictionary = game.sim.heroes[0]
			hero.pos = Vector2(860.0, float(row.y))
			hero.target = hero.pos
			game.sim.attack_geometry_cache.clear()
			game.refresh()
			game.battle.queue_redraw()
			for index in 3:
				await process_frame
			RenderingServer.force_draw()
			await process_frame
			var row_file := folder.path_join("depth_%s.png" % row.name)
			if game.get_viewport().get_texture().get_image().save_png(row_file) != OK:
				push_error("stage 1 depth screenshot failed: " + row_file)
				quit(1)
				return
			print("STAGE1_DEPTH_SCREENSHOT_OK ", row_file)
		quit(0)
		return
	var name := "pad_demo.png" if pad_demo else ("stage_02_projection.png" if stage_id == "stage_02" else ("after.png" if "--after" in OS.get_cmdline_user_args() else "before.png"))
	var saved := game.get_viewport().get_texture().get_image().save_png(folder.path_join(name))
	if saved != OK:
		push_error("stage 1 screenshot failed")
		quit(1)
		return
	print("STAGE1_SCREENSHOT_OK ", folder.path_join(name))
	quit(0)
