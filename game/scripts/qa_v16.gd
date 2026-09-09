extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V16 PASS: " + message)
	else:
		failures += 1
		push_error("V16 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.55).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v16-validation")
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

func reveal_choices(game) -> void:
	game.dialogue.letters = game.dialogue.body.text.length()
	game.dialogue.advance()
	await game.get_tree().process_frame
	await game.get_tree().process_frame

func run(game) -> void:
	game.open_mode_menu()
	await game.get_tree().process_frame
	expect(game.sim.database.characters.size() == 12, "roster contains twelve data-driven characters")
	expect(game.sim.database.cards.any(func(card: Dictionary) -> bool: return card.get("character_id", "") == "hero_12"), "new characters have selectable upgrade cards")
	expect(game.audio_director.music_player.stream != null and game.audio_director.music_player.playing, "Helltaker music is packaged and playing at runtime")

	await click_control(game, game.mode_select_panel.settings_button)
	expect(game.settings_panel.is_open(), "main-menu settings button opens the settings screen")
	expect(game.settings_panel.sliders.size() == 3, "settings expose master, music and sound-effect volume sliders")
		
	await capture(game, "01-settings")
	var original_music := float(game.audio_director.values.music)
	game.settings_panel.sliders.music.value = 37
	await game.get_tree().process_frame
	expect(is_equal_approx(float(game.audio_director.values.music), 0.37), "music slider updates the Music bus")
	game.apply_setting("music", original_music)
	game.settings_panel.close()
	await game.get_tree().create_timer(0.18).timeout
	expect(game.mode_select_panel.is_open(), "closing settings returns to the mode menu")

	await click_control(game, game.mode_select_panel.buttons["rift_watch"])
	await click_control(game, game.stage_select_panel.buttons["stage_01"])
	await click_control(game, game.squad_panel.confirm_button)
	expect(game.story.active, "campaign starts through real pointer clicks")
	while game.story.index < 2:
		game.dialogue.letters = game.dialogue.body.text.length()
		game.dialogue.advance()
		await game.get_tree().process_frame
	await reveal_choices(game)
	expect(game.dialogue.choice_buttons[0].visible and game.dialogue.choice_buttons[0].position.x < 100.0, "dialogue choices use the Helltaker left response column")
	await capture(game, "02-helltaker-dialogue")
	await click_control(game, game.dialogue.choice_buttons[0])
	game.story.active = false
	game.dialogue.root.hide()
	game.end_dialogue()
	expect(game.sim.state == "running", "campaign remains playable after a dialogue choice")

	game.sim.run_state.traveler_element = "geo"
	game.sim.run_state.buff_levels = {"traveler_attack_common": 3}
	game.sim.run_state.crystal_level = 6
	game.sim.heroes[0].element = "geo"
	game.sim.heroes[0].damage = 123.0
	expect(game.begin_dialogue("mode1_won", "stage_exit"), "post-clear inheritance dialogue starts")
	await reveal_choices(game)
	await click_control(game, game.dialogue.choice_buttons[1])
	expect(game.story_resume == "inherit_endless", "second post-clear reply selects inherited endless mode")
	game.story.active = false
	game.dialogue.root.hide()
	game.end_dialogue()
	expect(game.sim.endless_mode and game.sim.state == "running", "dialogue branch enters endless gameplay")
	expect(game.sim.run_state.crystal_level == 6 and int(game.sim.run_state.buff_levels.get("traveler_attack_common", 0)) == 3 and is_equal_approx(float(game.sim.heroes[0].damage), 123.0), "team, levels and combat stats survive the mode transfer")
	var distant_target := Vector2(2050, 1080)
	game.sim.traveler_skill_cooldown = 0.0
	expect(game.sim.activate_traveler_skill(distant_target), "Geo skill activates at a distant endless coordinate")
	var construct: Dictionary = game.sim.geo_constructs.back()
	expect(construct.pos.distance_to(distant_target) < 1.0, "Geo construct stays at the aimed endless world position")
	game.sim.enemies.clear()
	game.sim.elapsed = 70.0
	game.sim.endless_spawn_timer = 0.0
	game.sim._endless_spawn_tick(0.1)
	expect(not game.sim.enemies.any(func(enemy: Dictionary) -> bool: return enemy.get("kind", "") == "ranged"), "early endless tiers suppress ranged enemies until the build develops")
	await capture(game, "03-inherited-endless")

	print("V16 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)