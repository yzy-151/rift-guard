extends SceneTree

const MAIN = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error("HOME QA: " + label)

func _wait_for(test: Callable, frames: int = 1200) -> bool:
	for index in frames:
		if test.call():
			return true
		await process_frame
	return false

func _finish_scene(game, expected_success: bool) -> void:
	var rounds := 0
	while game.story.active and rounds < 32:
		rounds += 1
		if game.story.has_choices():
			var options: Array = game.story.current().choices
			var chosen := -1
			for index in options.size():
				var option: Dictionary = options[index]
				if bool(option.get("home_success", not expected_success)) == expected_success or (expected_success and option.has("follow_up")):
					chosen = index
					break
			check(chosen >= 0, "matching home choice exists")
			if chosen < 0:
				break
			game.dialogue.line_ended = true
			game.dialogue.choose_option(chosen)
		else:
			game.dialogue.advance()
		await process_frame
	check(rounds < 32, "multi-round home dialogue terminates")
	check(bool(game.pending_home_outcome.get("success", not expected_success)) == expected_success, "chosen result is recorded")
	var waiting: bool = await _wait_for(func() -> bool: return game.dialogue.animation_waiting)
	check(waiting, "outcome animation waits for player acknowledgement")
	if waiting:
		game.dialogue.acknowledge_animation()
	var returned: bool = await _wait_for(func() -> bool: return game.home_panel.is_open() and not game.home_panel.busy and not game.dialogue.animation_waiting)
	check(returned, "outcome transition returns to home")

func _run() -> void:
	var game = MAIN.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.open()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		var entry_path := ProjectSettings.globalize_path("res://../outputs/home-mode-entry.png")
		check(game.get_viewport().get_texture().get_image().save_png(entry_path) == OK, "home entry screenshot")
	check(game.mode_select_panel.continue_button.text.find("基地") >= 0, "mode menu checkpoint becomes home entry")
	check(str(game.story.stories["opening"][0].speaker) == "你", "rewritten campaign wins over legacy workbook rows")
	game.mode_select_panel.continue_button.pressed.emit()
	await process_frame
	check(game.home_panel.is_open(), "home entry opens from mode menu")
	check(game.home_panel.npcs.size() >= 5, "unlocked, ready characters appear in home")
	check(game.home_panel.map.position.x == 0.0, "home starts at first of two screens")
	var start_x: float = game.home_panel.player_pos.x
	var move_press := InputEventKey.new()
	move_press.keycode = KEY_D
	move_press.pressed = true
	Input.parse_input_event(move_press)
	for index in 8:
		await process_frame
	var move_release := InputEventKey.new()
	move_release.keycode = KEY_D
	move_release.pressed = false
	Input.parse_input_event(move_release)
	check(game.home_panel.player_pos.x > start_x, "D key moves player across home map")
	game.home_panel.player_pos = Vector2(2360, 535)
	game.home_panel._update_camera()
	check(is_equal_approx(game.home_panel.camera_x, 1280.0), "camera reaches second screen")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		var right_path := ProjectSettings.globalize_path("res://../outputs/home-preview-right.png")
		check(game.get_viewport().get_texture().get_image().save_png(right_path) == OK, "second-screen screenshot")
	game.home_panel.player_pos = game.home_panel.npcs[0].pos + Vector2(-68, 40)
	game.home_panel._update_camera()
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		await process_frame
		var path := ProjectSettings.globalize_path("res://../outputs/home-preview.png")
		check(game.get_viewport().get_texture().get_image().save_png(path) == OK, "home screenshot")
	var interact := InputEventKey.new()
	interact.keycode = KEY_F
	interact.pressed = true
	game.home_panel.handle_input(interact)
	check(game.story.active and game.story.key.begins_with("home_"), "F starts random character dialogue")
	if DisplayServer.get_name() != "headless":
		for frame in 45:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var dialogue_path := ProjectSettings.globalize_path("res://../outputs/home-dialogue-preview.png")
		check(game.get_viewport().get_texture().get_image().save_png(dialogue_path) == OK, "home dialogue screenshot")
	await _finish_scene(game, true)
	game.home_panel.player_pos = game.home_panel.npcs[0].pos
	game.home_panel.handle_input(interact)
	check(game.story.active, "same resident remains interactable")
	await _finish_scene(game, false)
	for id: String in game.sim.database.characters:
		for index in 5:
			var key := "home_%s_%d" % [id, index]
			check(game.story.stories.has(key), "story present: " + key)
			if game.story.stories.has(key):
				var options: Array = game.story.stories[key][-1].choices
				check(options.size() == 2 and options.any(func(option: Dictionary) -> bool: return not bool(option.get("home_success", true)) and not str(option.get("home_reason", "")).is_empty()), "story has explained failure: " + key)
	game.home_panel.player_pos = Vector2(100, 480)
	game.home_panel.handle_input(interact)
	check(game.stage_select_panel.is_open() and not game.home_panel.is_open(), "stage terminal opens mission select")
	game.stage_select_panel.close()
	game.stage_select_panel.cancelled.emit()
	check(game.home_panel.is_open(), "return from mission select restores home")
	game.home_panel.player_pos = Vector2(1220, 480)
	game.home_panel.handle_input(interact)
	check(game.compendium_panel.is_open(), "archive terminal opens compendium")
	game.compendium_panel.close()
	check(game.home_panel.is_open(), "closing compendium restores home")
	game.home_panel.player_pos = Vector2(2240, 480)
	game.home_panel.handle_input(interact)
	check(game.settings_panel.is_open(), "control terminal opens settings")
	game.settings_panel.close()
	check(await _wait_for(func() -> bool: return game.home_panel.is_open()), "closing settings restores home")
	for character_id: String in game.sim.database.characters:
		game.story.reset()
		var deep_key := "home_%s_0" % character_id
		check(game.story.begin(deep_key), "deep scene starts: " + deep_key)
		var guard := 0
		while game.story.active and not game.story.has_choices() and guard < 10:
			guard += 1
			game.story.advance()
		check(game.story.has_choices(), "first choice appears: " + deep_key)
		var first: Array = game.story.current().get("choices", [])
		var good := 0 if first[0].has("follow_up") else 1
		check(game.story.choose(good), "first deep choice accepted: " + deep_key)
		guard = 0
		while game.story.active and not game.story.has_choices() and guard < 10:
			guard += 1
			game.story.advance()
		check(game.story.has_choices(), "second choice appears: " + deep_key)
		var final_result := false
		guard = 0
		while game.story.active and guard < 10:
			guard += 1
			if game.story.has_choices():
				var options: Array = game.story.current().choices
				var success_index := 0
				for option_index in options.size():
					if bool(options[option_index].get("home_success", false)) or options[option_index].has("follow_up"):
						success_index = option_index
						break
				final_result = bool(options[success_index].get("home_success", false)) or options[success_index].has("follow_up")
				game.story.choose(success_index)
			else:
				game.story.advance()
		check(final_result and game.story.choice_history.size() >= 2, "deep route concludes successfully: " + deep_key)
	if DisplayServer.get_name() != "headless":
		game.home_panel.close()
		game.story.reset()
		check(game.story.begin("mode1_opening"), "campaign preview scene starts")
		game.dialogue.display()
		for frame in 45:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var campaign_path := ProjectSettings.globalize_path("res://../outputs/home-campaign-preview.png")
		check(game.get_viewport().get_texture().get_image().save_png(campaign_path) == OK, "campaign dialogue screenshot")
		game.dialogue.root.hide()
		game.story.reset()
		check(game.story.begin("home_hero_03_0"), "deep choice preview scene starts")
		game.dialogue.display()
		while game.story.active and not game.story.has_choices():
			game.story.advance()
		game.dialogue.show_line()
		for frame in 45:
			await process_frame
		RenderingServer.force_draw()
		await process_frame
		var choice_path := ProjectSettings.globalize_path("res://../outputs/home-choice-preview.png")
		check(game.get_viewport().get_texture().get_image().save_png(choice_path) == OK, "multi-round choice screenshot")
		game.dialogue.root.hide()
		game.story.reset()
	game.queue_free()
	await process_frame
	print("HOME QA COMPLETE: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
