extends SceneTree

var app
var failures: Array[String] = []
var output_dir := ""
var changed: Array[String] = []
var quit_clicked := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output_dir = arg.trim_prefix("--qa-output=")
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func click(point: Vector2) -> void:
	point = root.get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame

func capture(name: String) -> void:
	if output_dir.is_empty() or DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(output_dir)
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_dir.path_join(name + ".png")) == OK, "capture " + name)

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_physics_process(false)
	app.set_process(false)
	await click(app.mode_select_panel.buttons.settings.get_global_rect().get_center())
	var settings = app.settings_panel
	check(settings.is_open(), "main menu opens redesigned settings through real mouse input")
	settings.setting_changed.connect(func(setting_key: String, _value: Variant): changed.append(setting_key))
	settings.open({"master": 0.29, "music": 1.0, "sfx": 1.0, "reduced_effects": false})
	check(changed.is_empty() and settings.value_labels.master.text == "29%", "opening preserves supplied volume and emits no setting mutation")
	check(settings.heading_label.text == "滑动变阻器" and settings.title_label.text == "系统\n设置", "right-hand settings heading uses master's exact wording and retains the left title")
	check(settings.portrait.texture != null and settings.portrait.texture.get_width() == 1256 and settings.portrait.is_visible_in_tree(), "the supplied transparent Kaltsit portrait is loaded and visible")
	await capture("03_settings_poster")
	var slider: HSlider = settings.sliders.sfx
	await click(slider.get_global_rect().position + Vector2(slider.size.x * 0.63, slider.size.y * 0.5))
	check(changed.has("sfx") and slider.value > 50 and slider.value < 75 and settings.value_labels.sfx.text == "%d%%" % roundi(slider.value), "real slider input updates value and existing persistence signal")
	await click(settings.reduced_button.get_global_rect().get_center())
	check(changed.has("reduced_effects") and settings.reduced_button.text == "低特效：开", "real low-effects toggle keeps existing setting behavior")
	await click(settings.fullscreen_button.get_global_rect().get_center())
	await create_timer(0.4).timeout
	check(changed.has("fullscreen") and bool(app.audio_director.values.fullscreen) and settings.fullscreen_button.text.begins_with("全屏：开"), "real fullscreen button updates saved display setting")
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "fullscreen button changes the actual native window")
	await click(settings.fullscreen_button.get_global_rect().get_center())
	await create_timer(0.4).timeout
	check(not bool(app.audio_director.values.fullscreen) and settings.fullscreen_button.text.begins_with("全屏：关"), "second fullscreen click returns to windowed mode")
	var signal_count := changed.size()
	await key(KEY_F11)
	await create_timer(0.4).timeout
	check(bool(app.audio_director.values.fullscreen) and bool(settings.fullscreen_button.get_meta("enabled")) and changed.size() == signal_count, "F11 synchronizes fullscreen button without emitting a second setting change")
	await key(KEY_F11)
	await create_timer(0.4).timeout
	check(not bool(app.audio_director.values.fullscreen) and not bool(settings.fullscreen_button.get_meta("enabled")), "second F11 returns to windowed mode and synchronizes the button")
	check(not settings.quit_requested.get_connections().is_empty(), "settings Exit has a main application connection")
	for connection: Dictionary in settings.quit_requested.get_connections(): settings.quit_requested.disconnect(connection.callable)
	settings.quit_requested.connect(func(): quit_clicked = true)
	await click(settings.quit_button.get_global_rect().get_center())
	check(quit_clicked and app.mode_select_panel.buttons.has("quit"), "real settings Exit action works and main menu Exit remains")
	await click(settings.workshop_button.get_global_rect().get_center())
	check(app.workshop != null, "new workshop entry opens the independent workshop")
	await key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	check(app.workshop == null and settings.is_open(), "Escape from workshop restores redesigned settings")
	await key(KEY_ESCAPE)
	await create_timer(0.3).timeout
	check(not settings.is_open() and app.mode_select_panel.is_open(), "Escape saves and returns to main menu")
	app.mode_select_panel.close()
	app.hud.show()
	app.hud.get_child(0).show()
	app.battle.show()
	var squad: Array[String] = ["traveler", "hero_03", "hero_13"]
	app.sim.reset_stage("stage_01", squad, 20261005)
	app.sim.start()
	app.sim.elapsed = 66
	app.sim.kills = 9
	for index in 6:
		var card: Dictionary = app.sim.database.cards[index]
		app.sim.run_state.buff_levels[str(card.id)] = index % 3 + 1
	app.toggle_pause()
	check(app.hud.pause_details.visible and app.sim.state == "paused", "existing pause flow opens the new poster panel")
	check(not app.hud.pause_status_label.text.contains("PERF") and app.hud.pause_status_label.text.contains("水晶"), "pause status keeps useful combat information")
	var layout = preload("res://data/ui_layout_profile.tres")
	check(layout.battle_pause_status_rect.position.y - layout.battle_pause_header_rect.end.y >= 16, "pause status keeps breathing room under the red title banner")
	check(app.hud.pause_details.size.y - app.hud.pause_continue_button.get_rect().end.y >= 28, "Continue button leaves a clear bottom margin inside the border")
	check(app.hud.pause_details.get_children().any(func(node): return node is Label and node.text == "这里没有战败CG"), "pause uses master's corrected CG wording")
	await capture("02_pause_poster")
	for card: Dictionary in app.sim.database.cards:
		app.sim.run_state.buff_levels[str(card.id)] = 1
	while app.sim.heroes.size() < 6:
		app.sim.heroes.append(app.sim.heroes[0].duplicate(true))
	app.hud.refresh_pause_details(app.sim)
	await create_timer(0.15).timeout
	check(app.hud.pause_buff_labels.size() >= app.sim.run_state.buff_levels.size(), "all buffs get rows instead of truncating after twelve")
	check(app.hud.pause_hero_labels.size() == 6 and app.hud.pause_hero_labels[5].text.contains("旅行者"), "late-game squads get complete scrollable stats")
	check(app.hud.pause_buff_scroll.get_v_scroll_bar().max_value > app.hud.pause_buff_scroll.size.y and app.hud.pause_hero_scroll.get_v_scroll_bar().max_value > app.hud.pause_hero_scroll.size.y, "long build and squad lists actually scroll")
	# This fixture expands only the pause stats; restore the real three-slot battle HUD before action tests.
	app.sim.heroes.resize(3)
	app.hud.refresh_pause_details(app.sim)
	await click(app.hud.pause_restart_button.get_global_rect().get_center())
	check(app.hud.restart_dialog.visible and app.sim.state == "paused", "real Restart still requires explicit confirmation")
	# ConfirmationDialog lives in a separate native window; exercise its existing cancel signal.
	app.hud.restart_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not app.hud.restart_dialog.visible and app.sim.state == "paused", "confirmation cancel preserves the current battle")
	await click(app.hud.pause_settings_button.get_global_rect().get_center())
	check(settings.is_open() and app.sim.state == "paused", "pause Settings works without resuming battle")
	await click(settings.close_button.get_global_rect().get_center())
	await create_timer(0.3).timeout
	check(not settings.is_open() and app.hud.pause_details.visible, "settings return restores the pause panel")
	await click(app.hud.pause_continue_button.get_global_rect().get_center())
	check(app.sim.state == "running" and not app.hud.pause_details.is_visible_in_tree(), "real Continue resumes combat")
	print("POSTER PANELS QA: %d failures" % failures.size())
	app.queue_free()
	await process_frame
	app = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
