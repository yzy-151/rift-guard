extends SceneTree

const MAIN = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.mode_select_panel.close()
	var capture_animation := OS.get_environment("COMIC_QA_CAPTURE") == "1"
	if capture_animation:
		Engine.time_scale = 0.2
	game.dialogue.play_comic_panel("res://assets/story_comics/roxy_departure.png", "你刚把‘魔族’喊出口，就意识到自己说错了话。\n你追到门边，只听见渐远的脚步声。")
	var waiting := false
	var frames_dir := ProjectSettings.globalize_path("res://../outputs/comic-entrance-frames")
	if capture_animation and DisplayServer.get_name() != "headless":
		DirAccess.make_dir_recursive_absolute(frames_dir)
	for frame in 240:
		await process_frame
		if capture_animation and DisplayServer.get_name() != "headless" and frame < 180 and frame % 3 == 0:
			RenderingServer.force_draw()
			game.get_viewport().get_texture().get_image().save_png(frames_dir.path_join("frame_%03d.png" % frame))
		if game.dialogue.animation_waiting:
			waiting = true
			break
	if waiting and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		var screenshot := ProjectSettings.globalize_path("res://../outputs/roxy-comic-in-game.png")
		if game.get_viewport().get_texture().get_image().save_png(screenshot) != OK:
			waiting = false
	Engine.time_scale = 1.0
	if waiting:
		game.dialogue.acknowledge_animation()
	for frame in 35:
		await process_frame
	game.queue_free()
	await process_frame
	print("ROXY COMIC: ", "PASS" if waiting else "FAIL")
	quit(0 if waiting else 1)
