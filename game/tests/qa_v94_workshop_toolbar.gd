extends SceneTree
## The V93 regression uses keyboard transport; this covers the redesigned mouse controls.

var game
var failures: Array[String] = []
var checks := 0
var output := ""
var capture_size := Vector2i.ZERO
var last_capture_size := Vector2i.ZERO

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-size="):
			var dimensions := arg.trim_prefix("--qa-size=").split("x")
			if dimensions.size() == 2: capture_size = Vector2i(int(dimensions[0]), int(dimensions[1]))
	if not output.is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(45.0).timeout.connect(func(): printerr("FAIL: toolbar QA timeout"); quit(2))
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures.append(description); printerr("FAIL: " + description)

func click(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate(); event.pressed = false
	root.push_input(event, true)
	await process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	last_capture_size = image.get_size()
	if capture_size != Vector2i.ZERO: check(last_capture_size == capture_size, name + " GPU capture has the requested exact size")
	image.save_png(output.path_join(name + ".png"))

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.test_mode = true
	# Godot fits its initial desktop window inside the OS work area. Set the
	# requested render size after startup; captures come directly from the GPU.
	if DisplayServer.get_name() != "headless" and capture_size != Vector2i.ZERO:
		await create_timer(0.3).timeout
		root.mode = Window.MODE_WINDOWED
		root.borderless = true
		await process_frame
		root.size = capture_size
		await create_timer(0.15).timeout
	for i in 3: await process_frame
	var key := InputEventKey.new()
	key.keycode = KEY_F10; key.pressed = true
	root.push_input(key, true)
	key = key.duplicate(); key.pressed = false
	root.push_input(key, true)
	await create_timer(0.2).timeout
	await click(game.settings_panel.workshop_button)
	check(game.workshop != null, "settings mouse entry opens independent workshop")
	if game.workshop == null: quit(1); return
	var workshop = game.workshop
	var session = workshop.session
	var controls: Array[Control] = []
	for id: String in ["pause", "step", "speed", "recover", "clear_enemies", "clear", "reset", "exit"]:
		var control: Control = workshop.buttons[id]
		check(workshop.toolbar.get_global_rect().encloses(control.get_global_rect()), id + " remains inside the top rail")
		check(workshop.over_ui(control.get_global_rect().get_center()), id + " cannot place a battlefield unit")
		for previous: Control in controls:
			check(not previous.get_global_rect().intersects(control.get_global_rect()), id + " does not overlap another action")
		controls.append(control)
	var probe := Vector2.ZERO
	for y in range(170, 551, 50):
		for x in range(480, 1191, 60):
			if probe == Vector2.ZERO and session.legal(Vector2(x, y), 60.0): probe = Vector2(x, y)
	check(session.place_hero(str(workshop.hero_picker.get_item_metadata(0)), probe), "reset probe places a real hero")
	check(session.place_enemy(str(workshop.enemy_picker.get_item_metadata(0)), probe + Vector2(5, 0)), "reset probe places a real enemy")
	workshop.refresh()
	await capture("toolbar-running")
	await click(workshop.buttons.pause)
	check(session.paused and workshop.pause_button.text == "继续", "pause mouse click freezes session and changes action text")
	var time: float = session.sim.elapsed
	await create_timer(0.05).timeout
	check(is_equal_approx(time, session.sim.elapsed), "paused mouse action freezes independent battle time")
	await click(workshop.buttons.step)
	check(session.paused and is_equal_approx(session.sim.elapsed, time + 1.0 / 60.0), "frame mouse action advances exactly one fixed frame")
	await capture("toolbar-paused")
	await click(workshop.buttons.pause)
	check(not session.paused and workshop.pause_button.text == "暂停", "continue mouse action resumes workshop")
	await click(workshop.buttons.pause)
	await click(workshop.buttons.reset)
	check(session.sim.heroes.all(func(hero: Dictionary): return not bool(hero.deployed)) and session.sim.enemies.is_empty(), "reset mouse action clears real units")
	check(is_zero_approx(session.sim.elapsed) and workshop.battle.effects.is_empty(), "reset mouse action clears time and paused effects")
	await click(workshop.buttons.exit)
	for i in 3: await process_frame
	check(game.workshop == null and game.settings_panel.is_open(), "exit mouse action returns to settings and frees workshop")
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "renderer":DisplayServer.get_name(), "capture_width":last_capture_size.x, "capture_height":last_capture_size.y}, "\t"))
	print("V94 WORKSHOP TOOLBAR: %d checks, %d failures" % [checks, failures.size()])
	await game._quit_after_audio_cleanup(0 if failures.is_empty() else 1)
