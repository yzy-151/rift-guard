extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V15 PASS: " + message)
	else:
		failures += 1
		push_error("V15 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.7).timeout
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v15-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func click_control(game, control: Control) -> void:
	var logical_point := control.get_global_rect().get_center()
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var point: Vector2 = logical_point * window_size / viewport_size
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await game.get_tree().process_frame

func run(game) -> void:
	game.compendium.unlocked_characters.erase("hero_08")
	game.open_mode_menu()
	await game.get_tree().process_frame
	expect(game.mode_select_panel.is_open(), "mode menu is visible")
	await click_control(game, game.mode_select_panel.buttons["rift_watch"])
	expect(game.stage_select_panel.is_open(), "real pointer click opens campaign stage selection")
	expect(not game.stage_select_panel.buttons["stage_01"].disabled, "stage one is enabled")
	await click_control(game, game.stage_select_panel.buttons["stage_01"])
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_01", "real pointer click opens stage one squad selection")
	await click_control(game, game.squad_panel.confirm_button)
	expect(game.sim.current_stage_id == "stage_01" and game.story.active, "real pointer click enters campaign opening dialogue")

	while game.story.index < 2:
		game.dialogue.letters = game.dialogue.body.text.length()
		game.dialogue.advance()
		await game.get_tree().process_frame
	game.dialogue.letters = game.dialogue.body.text.length()
	game.dialogue.advance()
	await game.get_tree().process_frame
	expect(game.dialogue.choice_buttons[0].visible and game.dialogue.choice_buttons[1].visible, "opening dialogue presents two Helltaker-style replies")
	await capture(game, "01-dialogue-choice")
	await click_control(game, game.dialogue.choice_buttons[1])
	expect(game.compendium.unlocked_characters.has("hero_08"), "second reply permanently unlocks hidden character Bailu")
	expect("白露" in str(game.story.current().get("text", "")), "hidden-character reply leads to its own result line")

	game.story.active = false
	game.dialogue.root.hide()
	game.end_dialogue()
	expect(game.sim.state == "running", "campaign starts after branched dialogue")
	await capture(game, "02-campaign-running")

	var BranchStory = preload("res://scripts/dialogue_director.gd")
	var branch = BranchStory.new()
	expect(branch.begin("mode1_opening"), "branch fixture starts")
	branch.advance()
	branch.advance()
	var first_choice: Dictionary = branch.current().choices[0]
	expect(branch.choose(0) and first_choice.effect.type == "luck" and "幸运值" in branch.current().text, "first reply produces the luck result branch")

	game.return_to_main_menu()
	await game.get_tree().process_frame
	await click_control(game, game.mode_select_panel.buttons["endless_survival"])
	expect(game.sim.current_stage_id == "stage_endless" and game.sim.state == "running", "real pointer click enters endless gameplay")
	await capture(game, "03-endless-running")

	print("V15 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
