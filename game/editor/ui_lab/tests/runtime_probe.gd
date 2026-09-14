extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var expected_x := 0.0
	var expected_texture := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--choice-x="):
			expected_x = float(argument.trim_prefix("--choice-x="))
		elif argument.begins_with("--texture="):
			expected_texture = argument.trim_prefix("--texture=")
	var hud = load("res://scripts/battle_hud.gd").new()
	root.add_child(hud)
	await process_frame
	var dialogue = load("res://scripts/dialogue_panel.gd").new()
	root.add_child(dialogue)
	dialogue.build(hud, null)
	await process_frame
	var rect_ok: bool = is_equal_approx(dialogue.choice_buttons[0].position.x, expected_x)
	var texture_ok: bool = dialogue.choice_frames[0].texture != null and dialogue.choice_frames[0].texture.resource_path == expected_texture
	print("PROBE choice_x=%.1f expected=%.1f texture=%s expected_texture=%s" % [dialogue.choice_buttons[0].position.x, expected_x, dialogue.choice_frames[0].texture.resource_path, expected_texture])
	quit(0 if rect_ok and texture_ok else 1)
