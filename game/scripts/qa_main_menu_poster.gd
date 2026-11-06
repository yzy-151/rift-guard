extends SceneTree

var app
var failures: Array[String] = []
var quit_clicked := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func mouse(point: Vector2, button: int = 0, pressed: bool = false) -> void:
	point = root.get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	if button == 0: return
	var click := InputEventMouseButton.new()
	click.position = point
	click.global_position = point
	click.button_index = button
	click.pressed = pressed
	Input.parse_input_event(click)
	await process_frame

func click_menu(id: String) -> void:
	var center: Vector2 = app.mode_select_panel.buttons[id].get_global_rect().get_center()
	await mouse(center, MOUSE_BUTTON_LEFT, true)
	await mouse(center, MOUSE_BUTTON_LEFT, false)

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.set_process(false)
	var panel = app.mode_select_panel
	check(panel.is_open() and panel.buttons.size() == 7, "poster menu has seven real actions")
	check(panel.continue_button.disabled, "missing checkpoint disables Continue")
	var hover_button: Button = panel.buttons.home
	await mouse(hover_button.get_global_rect().get_center())
	check(hover_button.has_focus() and panel.tags.home.focused, "real mouse hover focuses and highlights HOME")
	panel.buttons.rift_watch.grab_focus()
	await key(KEY_DOWN)
	check(panel.buttons.endless_survival.has_focus(), "keyboard skips unavailable Continue")
	if DisplayServer.get_name() != "headless":
		await mouse(Vector2(621, 663))
		panel.buttons.rift_watch.grab_focus()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://../qa/story_polish")
		root.get_texture().get_image().save_png("res://../qa/story_polish/01_main_menu.png")
	await click_menu("rift_watch")
	check(app.stage_select_panel.is_open() and not panel.is_open(), "NEW GAME enters stage selection")
	app.return_to_main_menu()
	await click_menu("settings")
	check(app.settings_panel.is_open() and not panel.is_open(), "SETTINGS enters the settings interface")
	app.settings_panel.close()
	await create_timer(0.5).timeout
	check(panel.is_open(), "closing settings returns to poster menu")
	await click_menu("archive")
	check(app.compendium_panel.is_open() and not panel.is_open(), "GALLERY enters the character compendium")
	app.compendium_panel.close()
	await process_frame
	check(panel.is_open(), "closing gallery returns to poster menu")
	await click_menu("home")
	check(app.home_panel.is_open() and not panel.is_open(), "HOME enters the home map")
	app.return_to_main_menu()
	await click_menu("endless_survival")
	check(app.squad_panel.is_open() or app.stage_select_panel.is_open(), "ENDLESS enters the existing endless preparation flow")
	app.return_to_main_menu()
	var traveler_squad: Array[String] = ["traveler"]
	app.sim.reset_stage("stage_01", traveler_squad, 397)
	var snapshot: Dictionary = preload("res://scripts/campaign_checkpoint.gd").snapshot(app.sim, "battle")
	check(app.checkpoint_store.save_checkpoint(snapshot, app.sim.database), "isolated QA campaign checkpoint can be saved")
	app.open_mode_menu()
	check(not panel.continue_button.disabled, "valid checkpoint enables Continue")
	panel.continue_button.grab_focus()
	await key(KEY_ENTER)
	check(app.sim.state == "running" and not panel.is_open(), "ENTER on Continue restores the actual saved battle")
	app.return_to_main_menu()
	for connection: Dictionary in panel.quit_requested.get_connections(): panel.quit_requested.disconnect(connection.callable)
	panel.quit_requested.connect(func(): quit_clicked = true)
	await click_menu("quit")
	check(quit_clicked, "EXIT has an explicit action")
	print("MAIN MENU POSTER QA: %d failures" % failures.size())
	app.queue_free()
	await process_frame
	app = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
