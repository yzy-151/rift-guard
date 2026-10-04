extends SceneTree

var game
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); printerr("FAIL " + message)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.story.reset()
	game.dialogue.root.hide()
	var available := false
	for property: Dictionary in game.battle.get_property_list():
		if property.name == "static_stage": available = true
	check(available, "static stage commands are retained outside the moving-unit draw pass")
	if available:
		var squad: Array[String] = ["traveler"]
		for stage: String in ["stage_02", "stage_endless"]:
			game.sim.reset_stage(stage, squad, 9505)
			game.battle.sim = game.sim
			game.battle.static_stage.sync_from(game.battle)
			var first: int = game.battle.static_stage.rebuild_count
			for frame in 30:
				game.battle.clock += 0.016
				game.sim._terrain_tick(0.016)
				game.battle.camera_center += Vector2(0.1, 0.05)
				game.battle.static_stage.sync_from(game.battle)
			check(game.battle.static_stage.rebuild_count == first, stage + " camera/time updates reuse static commands")
			var wall: Dictionary = {}
			for feature: Dictionary in game.sim.terrain_features:
				if str(feature.type) == "blocked": wall = feature; break
			check(not wall.is_empty(), stage + " has authored static terrain")
			if not wall.is_empty():
				wall.area = Rect2(wall.area).grow(2)
				game.battle.static_stage.sync_from(game.battle)
				check(game.battle.static_stage.rebuild_count == first + 1, stage + " geometry edits invalidate the cache")
			check(game.battle.static_stage.dynamic_features.any(func(f: Dictionary) -> bool: return str(f.type) in ["relay", "spring", "wind_lane", "hazard_lane"]), stage + " animated devices stay in the live draw pass")
		if DisplayServer.get_name() != "headless" and output.is_absolute_path():
			DirAccess.make_dir_recursive_absolute(output)
			for stage: String in ["stage_01", "stage_02", "stage_03", "stage_04", "stage_05", "stage_06", "stage_07", "stage_08", "stage_endless"]:
				game.sim.reset_stage(stage, squad, 9505)
				game.battle.reset_transients()
				game.battle.camera_center = game.sim.heroes[0].pos
				game.battle.clock = 1.25
				for cached: bool in [false, true]:
					game.battle.cached_stage_enabled = cached
					game.battle.queue_redraw()
					for f in 4: await process_frame
					await RenderingServer.frame_post_draw
					game.get_viewport().get_texture().get_image().save_png(output.path_join(stage + ("-cached.png" if cached else "-original.png")))
	print("V95 STAGE CACHE failures=%d" % failures.size())
	game._stop_scene_audio(game)
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
