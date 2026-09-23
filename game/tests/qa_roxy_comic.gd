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
	game.dialogue.play_comic_panel("res://assets/story_comics/roxy_departure.png", "你刚把‘魔族’喊出口，就意识到自己说错了话。\n你追到门边，只听见渐远的脚步声。")
	var waiting := false
	for frame in 90:
		await process_frame
		if game.dialogue.animation_waiting:
			waiting = true
			break
	if waiting and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		var screenshot := ProjectSettings.globalize_path("res://../outputs/roxy-comic-in-game.png")
		if game.get_viewport().get_texture().get_image().save_png(screenshot) != OK:
			waiting = false
	if waiting:
		game.dialogue.acknowledge_animation()
	for frame in 35:
		await process_frame
	game.queue_free()
	await process_frame
	print("ROXY COMIC: ", "PASS" if waiting else "FAIL")
	quit(0 if waiting else 1)
