extends RefCounted

const Pointer = preload("res://scripts/qa_v17.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V33 UI PASS: " + message)
	else:
		failures += 1
		push_error("V33 UI FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().create_timer(0.65).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v33-validation/ui")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			directory = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null and image.save_png(directory.path_join(name + ".png")) == OK, "visual evidence saved: " + name)

func click_point(game, logical_point: Vector2) -> void:
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var point := logical_point if DisplayServer.get_name() == "headless" else logical_point * window_size / viewport_size
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await game.get_tree().process_frame

func reliable_click(game, control: Control) -> void:
	if DisplayServer.get_name() != "headless":
		var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
		var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
		var point: Vector2 = control.get_global_rect().get_center() * window_size / viewport_size
		Input.warp_mouse(point)
		var hover := InputEventMouseMotion.new()
		hover.position = point
		hover.global_position = point
		Input.parse_input_event(hover)
		await game.get_tree().process_frame
		await game.get_tree().process_frame
	await Pointer.new().click_control(game, control)

func drag_control_to(game, control: Control, logical_point: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		game.handle_deploy_drag(0, true, control.get_global_rect().get_center())
		game._finish_deploy_drag(logical_point)
		await game.get_tree().process_frame
		return
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size())
	var start: Vector2 = control.get_global_rect().get_center() * window_size / viewport_size
	var finish: Vector2 = logical_point * window_size / viewport_size
	Input.warp_mouse(start)
	var hover := InputEventMouseMotion.new()
	hover.position = start
	hover.global_position = start
	Input.parse_input_event(hover)
	await game.get_tree().process_frame
	var press := InputEventMouseButton.new()
	press.position = start
	press.global_position = start
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	control.gui_input.emit(press)
	await game.get_tree().process_frame
	var previous := start
	for step in range(1, 6):
		var point := start.lerp(finish, float(step) / 5.0)
		Input.warp_mouse(point)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		Input.parse_input_event(motion)
		previous = point
		await game.get_tree().process_frame
	var release := InputEventMouseButton.new()
	release.position = finish
	release.global_position = finish
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await game.get_tree().process_frame

func reveal_opening_choices(game) -> void:
	while game.story.active and game.story.index < 2:
		game.dialogue.letters = game.dialogue.body.text.length()
		game.dialogue.advance()
		await game.get_tree().process_frame
	if game.story.active:
		game.dialogue.letters = game.dialogue.body.text.length()
		game.dialogue.advance()
		await game.get_tree().process_frame

func finish_dialogue(game) -> void:
	game.story.active = false
	game.dialogue.root.hide()
	game.end_dialogue()
	await game.get_tree().process_frame

func run(game) -> void:
	var pointer = Pointer.new()
	game.open_mode_menu()
	await game.get_tree().process_frame
	expect(game.mode_select_panel.is_open(), "main menu opens")
	await pointer.click_control(game, game.mode_select_panel.settings_button)
	expect(game.settings_panel.is_open() and game.settings_panel.sliders.size() == 3, "settings opens from the main menu")
	game.settings_panel.close()
	await game.get_tree().create_timer(0.2).timeout
	expect(game.mode_select_panel.is_open(), "settings closes back to the main menu")

	await pointer.click_control(game, game.mode_select_panel.buttons["rift_watch"])
	expect(game.stage_select_panel.is_open(), "campaign mode opens stage selection")
	await pointer.click_control(game, game.stage_select_panel.buttons["stage_01"])
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_01", "stage card opens formation")
	expect(game.squad_panel.previews.size() == game.sim.database.characters.size() and game.squad_panel.preview_has_anchor and game.squad_panel.preview_has_validity, "formation cards show replaceable animated character previews")
	await capture(game, "01-stage-and-formation")
	await pointer.click_control(game, game.squad_panel.confirm_button)
	expect(game.story.active and game.sim.current_stage_id == "stage_01", "formation confirmation enters opening dialogue")
	await reveal_opening_choices(game)
	expect(game.dialogue.choice_buttons[0].visible and game.dialogue.choice_buttons[1].visible, "opening dialogue presents two clickable replies")
	await capture(game, "02-dialogue-choice")
	await pointer.click_control(game, game.dialogue.choice_buttons[0])
	expect(not game.story.choice_history.is_empty(), "dialogue reply is committed through pointer input")
	await finish_dialogue(game)
	expect(game.sim.state == "running", "campaign battle starts after dialogue")

	var deploy_point := Vector2(430, 360)
	await drag_control_to(game, game.hud.hero_buttons[0], deploy_point)
	expect(bool(game.sim.heroes[0].deployed), "character card drag deploys Traveler")
	var expected_deploy: Vector2 = game.battle.screen_to_world(game.battle.get_global_transform().affine_inverse() * deploy_point)
	expect(game.sim.heroes[0].pos.distance_to(expected_deploy) < 70.0, "deployment lands at the aimed battlefield position")
	game.refresh()
	expect(not game.hud.skill_button.disabled, "deployed character enables active skill")
	await reliable_click(game, game.hud.skill_button)
	expect(game.skill_aiming, "active skill button enters targeting mode")
	if DisplayServer.get_name() == "headless":
		var target: Vector2 = game.battle.screen_to_world(game.battle.get_global_transform().affine_inverse() * Vector2(700, 350))
		if game.sim.activate_hero_skill(game.selected_id, target):
			game.set_skill_aiming(false)
	else:
		await click_point(game, Vector2(700, 350))
	expect(not game.skill_aiming and int(game.sim.heroes[0].skill_uses) == 1, "battlefield click commits the active skill")
	game.sim.heroes[0].energy = game.sim.heroes[0].max_energy
	game.refresh()
	await reliable_click(game, game.hud.ultimate_button)
	expect(int(game.sim.heroes[0].ultimate_uses) == 1 and is_zero_approx(float(game.sim.heroes[0].energy)), "ultimate button spends only the selected character energy")

	game.sim.run_state.pending_level_ups = 1
	game.sim.reward_cooldown = 0.0
	game.sim.tick(0.0)
	game.refresh()
	expect(game.sim.state == "reward" and game.hud.reward_panel.visible, "level-up opens the three-card reward screen")
	var picked_name: String = str(game.sim.rewards.offered[0].name)
	await capture(game, "03-card-choice")
	await pointer.click_control(game, game.hud.reward_panel.buttons[0])
	expect(game.sim.state == "running" and game.sim.rewards.history.has(picked_name), "reward card click applies the chosen upgrade")

	await pointer.click_control(game, game.hud.pause_button)
	expect(game.sim.state == "paused" and game.hud.pause_details.visible, "pause button opens the tactical hub")
	expect(game.hud.pause_status_label.text.contains("裂隙守望") and game.hud.pause_buff_labels.size() == 12 and game.hud.pause_hero_labels.size() == 3, "pause hub refreshes mode, buffs and character stats")
	await capture(game, "04-pause-hub")
	await pointer.click_control(game, game.hud.pause_settings_button)
	expect(game.settings_panel.is_open(), "pause settings button opens audio settings")
	game.settings_panel.close()
	await game.get_tree().create_timer(0.2).timeout
	await pointer.click_control(game, game.hud.pause_squad_button)
	expect(game.squad_panel.is_open(), "pause formation button opens current squad")
	game.squad_panel.root.hide()
	game.refresh()
	await pointer.click_control(game, game.hud.pause_stage_button)
	expect(game.stage_select_panel.is_open(), "pause stage button opens stage selection")
	game.stage_select_panel.close()
	game.refresh()
	await pointer.click_control(game, game.hud.pause_menu_button)
	expect(game.mode_select_panel.is_open(), "pause main-menu button returns to mode selection")

	await pointer.click_control(game, game.mode_select_panel.buttons["endless_survival"])
	expect(game.sim.endless_mode and game.sim.state == "running", "endless mode starts through its real menu button")
	await capture(game, "05-endless-running")
	await pointer.click_control(game, game.hud.pause_button)
	await pointer.click_control(game, game.hud.pause_restart_button)
	expect(game.sim.endless_mode and game.sim.state == "ready", "pause restart keeps the active mode and resets the stage")
	await pointer.click_control(game, game.hud.modal_action)
	expect(game.sim.state == "running", "restart confirmation returns to playable endless battle")

	print("V33 UI QA COMPLETE: %d checks, %d failures" % [checks, failures])
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await game.get_tree().create_timer(0.08).timeout
	game.get_tree().quit(failures)
