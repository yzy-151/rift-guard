extends RefCounted
func run(main) -> void:
	await main.get_tree().process_frame
	await main.get_tree().process_frame
	var valid: bool = main.content.loaded
	main.test_mode = false
	main.primary()
	valid = valid and main.story.active
	if main.story.active:
		var line: Dictionary = main.story.current()
		valid = valid and line.speaker == "测试编剧" and line.text == "Excel 自动加载验证"
		valid = valid and main.dialogue.portrait.flip_h and main.dialogue.portrait.position == Vector2(900, 100)
		valid = valid and main.dialogue.portrait.size.distance_to(Vector2(312, 399)) < 0.01
		valid = valid and not main.dialogue.partner.visible and main.dialogue.advance_button.text == "测试继续"
		var frame: NinePatchRect = main.dialogue.root.get_node("dialog_frame")
		valid = valid and frame.position == Vector2(60, 450) and frame.size == Vector2(1000, 240)
		main.dialogue.letters = 1000
		await main.get_tree().process_frame
		await RenderingServer.frame_post_draw
		main.get_viewport().get_texture().get_image().save_png("user://m5-excel-modified.png")
		main.dialogue.skip()
	valid = valid and main.sim.state == "running"
	print("EXCEL WINDOW INTEGRATION: " + ("PASS" if valid else "FAIL"))
	main.get_tree().quit(0 if valid else 1)
