extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS " + message if ok else "FAIL " + message)
	if not ok: failures += 1

func _run() -> void:
	var skin = ResourceLoader.load("res://data/ui_skin_profile.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(skin.mode_portrait != null, "freshly loaded skin retains the configured character texture")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.set_physics_process(false)
	app.set_process(false)
	var portrait: TextureRect
	for child in app.mode_select_panel.root.get_children():
		if child is TextureRect: portrait = child
	check(portrait != null and portrait.texture != null, "actual main menu has a character texture")
	check(portrait != null and portrait.is_visible_in_tree() and portrait.get_global_rect().intersects(Rect2(0, 0, 1280, 720)), "character is visible inside menu viewport")
	if portrait != null and portrait.texture != null:
		check(portrait.texture.get_width() > 100 and portrait.texture.get_height() > 100, "configured character image contains usable pixels")
	var art = app.mode_select_panel.art
	if art.has_method("pattern_stride"):
		var text_width: float = art.DISPLAY.get_string_size("RIFT GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, art.UI_LAYOUT.mode_pattern_font_size).x
		check(art.pattern_stride() >= text_width + 24.0, "repeated English has a measured gap and cannot overlap")
	else:
		check(false, "repeated English has a measured gap and cannot overlap")
	if DisplayServer.get_name() != "headless":
		var neutral_motion := InputEventMouseMotion.new()
		neutral_motion.position = root.get_screen_transform() * Vector2(640, 650)
		neutral_motion.global_position = neutral_motion.position
		Input.parse_input_event(neutral_motion)
		app.mode_select_panel.buttons["rift_watch"].grab_focus()
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--qa-output="):
				var directory := arg.trim_prefix("--qa-output=")
				DirAccess.make_dir_recursive_absolute(directory)
				root.get_texture().get_image().save_png(directory.path_join("main_menu_fixed.png"))
	print("MENU VISUAL QA: %d failures" % failures)
	quit(0 if failures == 0 else 1)
