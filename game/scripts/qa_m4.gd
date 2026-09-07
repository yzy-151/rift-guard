extends RefCounted
var game
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("M4 PASS: " if ok else "M4 FAIL: ") + message)
func key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	Input.parse_input_event(event)
	await game.get_tree().process_frame

func click(point: Vector2, button: int) -> void:
	point = point * Vector2(game.get_window().size) / Vector2(1280, 720)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await game.get_tree().process_frame

func capture(main, name: String) -> void:
	await main.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result: int = main.get_viewport().get_texture().get_image().save_png("user://m4-" + name + ".png")
	check(result == OK, "screenshot " + name)

func run(main) -> void:
	game = main
	var projection = preload("res://scripts/stage_projection.gd")
	var max_error: float = 0.0
	for x in range(40, 1241, 100):
		for y in range(140, 581, 40):
			var point := Vector2(x, y)
			max_error = maxf(max_error, point.distance_to(projection.unproject(projection.project(point))))
	check(max_error < 0.001, "projection inverse matches world coordinates")
	check(main.sim.MOVE_AREA.size == Vector2(475, 320), "deployment area enlarged to 475 x 320")
	await capture(main, "title")
	main.test_mode = false
	await key(KEY_ENTER)
	main.test_mode = true
	check(main.story.active and main.story.key == "opening", "Enter opens story before battle")
	var before: float = main.sim.elapsed
	for i in 100:
		main._physics_process(1.0 / 60.0)
	check(main.sim.elapsed == before and main.sim.wave == 0, "opening freezes combat")
	var target: Vector2 = main.sim.heroes[0].target
	await click(Vector2(520, 380), MOUSE_BUTTON_RIGHT)
	await key(KEY_2)
	await key(KEY_R)
	check(main.sim.heroes[0].target == target and main.selected_id == 0 and main.story.active, "story blocks movement selection and restart")
	var line_before: int = main.story.index
	await click(Vector2(1040, 660), MOUSE_BUTTON_LEFT)
	check(main.story.index == line_before and main.dialogue.letters >= main.dialogue.body.text.length(), "mouse first click reveals current line")
	await click(Vector2(1040, 660), MOUSE_BUTTON_LEFT)
	check(main.story.index == line_before + 1, "mouse next click advances one line")
	main.dialogue.letters = 1000
	await main.get_tree().process_frame
	await capture(main, "dialogue")
	await key(KEY_H)
	check(main.dialogue.history_panel.visible, "history opens")
	await click(Vector2(550, 660), MOUSE_BUTTON_LEFT)
	check(main.story.active and main.dialogue.history_panel.visible, "history disables underlying skip action")
	await key(KEY_ESCAPE)
	check(not main.dialogue.history_panel.visible and main.story.active, "Esc closes history without skipping story")
	for i in 7:
		await key(KEY_TAB)
		check(main.dialogue.controls.has(main.get_viewport().gui_get_focus_owner()), "dialogue focus trapped %d" % i)
	await key(KEY_ESCAPE)
	check(not main.story.active and main.sim.state == "running", "skip opening starts battle")
	check(main.story.history.size() == 4, "skip records unseen lines in history")
	main.sim.reset(303)
	main.story.reset()
	main.story.seen.opening = true
	main.sim.start()
	main.refresh()
	await key(KEY_2)
	check(main.selected_id == 1, "battle selection hotkeys restored")
	await click(projection.project(main.sim.heroes[0].pos) + Vector2(0, -18), MOUSE_BUTTON_LEFT)
	check(main.selected_id == 0, "projected sprite click selects guard")
	await key(KEY_2)
	var destination := Vector2(625, 495)
	await click(projection.project(destination), MOUSE_BUTTON_RIGHT)
	check(main.sim.heroes[1].target.distance_to(destination) < 0.01, "right click inverse projection commands world destination")
	# Restore deterministic default formation after validating movement.
	main.sim.reset(303)
	main.sim.start()
	for i in 900:
		main._physics_process(1.0 / 60.0)
		main.battle.advance(1.0 / 60.0)
	await capture(main, "battle")
	await key(KEY_SPACE)
	check(main.sim.state == "paused", "tactical pause still works")
	await key(KEY_SPACE)
	check(main.sim.state == "running", "tactical resume works")
	var scenes: Array[String] = []
	var rewards: int = 0
	for frame in 60000:
		main._physics_process(1.0 / 60.0)
		if main.story.active:
			var scene: String = main.story.key
			scenes.append(scene)
			var time: float = main.sim.elapsed
			main._physics_process(2.0)
			main.choose_reward(0)
			check(main.sim.elapsed == time and main.story.active, "story " + scene + " freezes and blocks reward")
			main.dialogue.skip()
			if scene in ["won", "lost"]:
				break
			check(main.sim.state == "reward" and main.hud.reward_panel.visible, "story returns to reward " + scene)
			main.choose_reward(0)
			rewards += 1
	check(rewards == 4 and scenes == ["node1", "node2", "node3", "node4", "won"], "all interludes and victory reached exactly once")
	check(main.sim.state == "won", "five-node defense wins")
	main.check_story()
	check(not main.story.active, "ending does not replay every tick")
	await capture(main, "victory")
	main.restart()
	check(main.story.seen.is_empty() and main.story.history.is_empty() and main.sim.state == "ready", "restart clears story and combat")
	main.sim.start()
	main.sim.base_hp = 0
	main._physics_process(1.0 / 60.0)
	check(main.story.active and main.story.key == "lost", "defeat story starts")
	main.dialogue.skip()
	check(main.sim.state == "lost" and not main.story.active, "defeat story returns to result")
	main.restart()
	main.begin_dialogue("opening", "start")
	main.dialogue.auto_mode = true
	for i in 4:
		main.dialogue._process(10.0)
	check(not main.story.active and main.sim.state == "running", "auto playback finishes and resumes battle")
	main.restart()
	main.begin_dialogue("opening", "start")
	main.dialogue.toggle_history()
	main.dialogue.skip()
	main.begin_dialogue("node1")
	check(main.dialogue.controls.all(func(item: Button) -> bool: return not item.disabled and item.focus_mode == Control.FOCUS_ALL), "new scene restores controls after history close")
	check(main.get_viewport().gui_get_focus_owner() == main.dialogue.advance_button, "new scene regains keyboard focus")
	main.dialogue.skip()
	main.restart()
	main.begin_dialogue("opening", "start")
	main.dialogue.letters = 1000
	for dimensions in [Vector2i(960, 540), Vector2i(1600, 900)]:
		main.get_window().size = dimensions
		await main.get_tree().process_frame
		await capture(main, "%dx%d" % [dimensions.x, dimensions.y])
	main.dialogue.skip()
	for attempt in 3:
		main.restart()
		main.begin_dialogue("opening", "start")
		check(main.story.active and main.story.lines.size() == 4, "opening data survives replay %d" % attempt)
		main.dialogue.skip()
	print("M4 UI TESTS: %d checks; %d failures" % [checks, failures])
	main.get_tree().quit(0 if failures == 0 else 1)
