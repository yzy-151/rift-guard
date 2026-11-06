extends SceneTree

var failures: Array[String] = []
var app

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = pressed
		event.button_mask = button if pressed else 0
		root.push_input(event, true)
		await process_frame

func key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func open_point(panel, offset: int = 0) -> Vector2:
	var candidates: Array[Vector2] = []
	for y in range(250, 560, 70):
		for x in range(530, 1040, 70):
			var point := Vector2(x, y)
			var screen: Vector2 = panel.battle.get_global_transform() * panel.battle.world_to_screen(point)
			if panel.session.legal(point, 35.0) and not panel.over_ui(screen): candidates.append(point)
	return candidates[mini(offset, candidates.size() - 1)] if not candidates.is_empty() else Vector2(-100, -100)

func screen_point(panel, point: Vector2) -> Vector2:
	return panel.battle.get_global_transform() * panel.battle.world_to_screen(point)

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_physics_process(false)
	app.set_process(false)
	app.return_to_main_menu()
	app.open_settings()
	await process_frame
	await click(app.settings_panel.workshop_button.get_global_rect().get_center())
	check(app.workshop != null, "real settings button opens workshop")
	if app.workshop == null:
		quit(1); return
	var panel = app.workshop
	await click(panel.buttons.pause.get_global_rect().get_center())
	check(panel.session.paused, "real pause button freezes workshop time")
	await click(panel.buttons.auto.get_global_rect().get_center())
	await click(panel.buttons.enemy_action.get_global_rect().get_center())
	check(not panel.session.auto_attack and not panel.session.enemy_action, "real combat toggle buttons remain clickable")
	var hero_point := open_point(panel)
	check(hero_point.x > 0.0, "find unobstructed battlefield position outside UI")
	await click(panel.buttons.hero.get_global_rect().get_center())
	check(panel.placement_kind == "hero", "real placement button arms hero cursor")
	await click(screen_point(panel, hero_point))
	check(bool(panel.session.sim.heroes[0].deployed), "battlefield mouse event deploys hero")
	check(Vector2(panel.session.sim.heroes[0].pos).distance_to(hero_point) < 0.1, "hero click uses correct projected world coordinate")
	check(panel.placement_kind.is_empty(), "successful hero placement exits cursor mode")
	await click(panel.buttons.enemy.get_global_rect().get_center())
	check(panel.placement_kind == "enemy", "real placement button arms monster cursor")
	await click(screen_point(panel, open_point(panel, 2)))
	await click(screen_point(panel, open_point(panel, 3)))
	check(panel.session.sim.enemies.size() == 2, "battlefield mouse events allow repeated monster placement")
	if "--qa-workshop-visual" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://../qa/story_review_20261005")
		DirAccess.make_dir_recursive_absolute(output)
		root.get_texture().get_image().save_png(output.path_join("workshop_mouse_placement.png"))
	await click(screen_point(panel, open_point(panel, 4)), MOUSE_BUTTON_RIGHT)
	check(panel.placement_kind.is_empty(), "right click cancels placement")
	await click(screen_point(panel, hero_point))
	check(panel.session.selected_kind == "hero", "battlefield click selects placed hero")
	await key(KEY_Q)
	check(panel.aiming == "skill", "workshop receives Q key for selected hero")
	await click(screen_point(panel, open_point(panel, 5)), MOUSE_BUTTON_RIGHT)
	check(panel.aiming.is_empty(), "right click cancels skill targeting")
	var move_point := open_point(panel, 6)
	await click(screen_point(panel, move_point), MOUSE_BUTTON_RIGHT)
	check(Vector2(panel.session.sim.heroes[0].target).distance_to(move_point) < 0.1, "right click issues hero movement")
	await key(KEY_TAB)
	check(not panel.drawer.visible, "Tab key collapses workshop tools")
	await key(KEY_TAB)
	check(panel.drawer.visible, "Tab key restores workshop tools")
	await click(panel.buttons.exit.get_global_rect().get_center())
	check(app.workshop == null and app.settings_panel.is_open(), "real return button restores settings")
	await click(app.settings_panel.workshop_button.get_global_rect().get_center())
	await key(KEY_ESCAPE)
	check(app.workshop == null and app.settings_panel.is_open(), "Escape restores settings from workshop")
	print("WORKSHOP INPUT QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
