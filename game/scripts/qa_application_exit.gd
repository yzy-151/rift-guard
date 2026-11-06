extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.set_physics_process(false)
	var button: Button
	if "--qa-settings-exit-test" in OS.get_cmdline_user_args():
		app.open_settings()
		await create_timer(0.25).timeout
		button = app.settings_panel.quit_button
	else:
		button = app.mode_select_panel.buttons["quit"]
	if not button.is_visible_in_tree() or button.disabled:
		push_error("Exit control is unavailable")
		quit(1)
		return
	create_timer(3.0).timeout.connect(_exit_timeout)
	print("APPLICATION EXIT QA: clicking actual exit control with production handler attached")
	var point: Vector2 = root.get_screen_transform() * button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.global_position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(click)
	# Main-menu input requests exit on press; settings requests it on release.
	# Return before shutdown instead of suspending this QA coroutine on a frame that may never arrive.

func _exit_timeout() -> void:
	push_error("Exit click did not close the actual application")
	quit(1)
