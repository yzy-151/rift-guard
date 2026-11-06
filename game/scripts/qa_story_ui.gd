extends SceneTree

var app
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " + label if condition else "FAIL " + label)
	if not condition: failures.append(label)

func click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
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

func settle_line() -> void:
	app.dialogue.letters = app.dialogue.body.get_total_character_count()
	app.dialogue.body.visible_characters = -1
	app.dialogue.line_ended = true
	app.dialogue._reveal_choices()
	await create_timer(0.3).timeout

func _run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_physics_process(false)
	app.set_process(false)
	app.mode_select_panel.close()
	app.story.begin("mode1_opening")
	var portrait_path: String = app.story.current().get("portrait", "")
	app.story.reset()
	app.story.stories["qa_story_ui"] = [
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "先别急着翻案，台词已经记在小本本上了。"},
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "开水已备好，你要怎么回答？", "choices": [
			{"text": "认真接过水杯", "response": "很好，今天先从烧水开始。"},
			{"text": "给水杯颁个奖", "response": "它并没有报名，但它获奖了。"}]}
	]
	app.story.begin("qa_story_ui")
	app.dialogue.display()
	await settle_line()
	var clicks: int = app.dialogue.ui_click_count
	await click(app.dialogue.advance_button.get_global_rect().get_center())
	check(app.dialogue.ui_click_count == clicks + 1 and app.story.index == 1, "real dialogue confirm advances with exactly one page sound")
	await settle_line()
	await click(app.dialogue.history_button.get_global_rect().get_center())
	check(app.dialogue.history_panel.visible, "real history button works during a two-choice scene")
	var index: int = app.story.index
	await create_timer(0.3).timeout
	await click(app.dialogue.history_panel.return_button.get_global_rect().get_center())
	check(not app.dialogue.history_panel.visible and app.story.index == index, "real return button restores same dialogue without advancing")
	check(app.dialogue.choice_buttons[0].visible and not app.dialogue.choice_buttons[0].disabled, "return restores both choices")
	var choices: int = app.dialogue.ui_choice_click_count
	await click(app.dialogue.choice_buttons[0].get_global_rect().get_center())
	check(app.dialogue.ui_choice_click_count == choices + 1 and app.story.index == 2, "real mouse choice plays exactly one crisp confirmation")
	check(app.story.history.any(func(row): return row.get("speaker", "") == "你的选择"), "history includes selected branch text")
	await settle_line()
	await key(KEY_H)
	check(app.dialogue.history_panel.visible, "H opens history")
	await key(KEY_ESCAPE)
	check(not app.dialogue.history_panel.visible and app.story.index == 2, "Escape returns without skipping story")
	await key(KEY_H)
	await key(KEY_H)
	check(not app.dialogue.history_panel.visible, "H also returns")
	app.story.reset()
	app.story.begin("qa_story_ui")
	app.story.advance()
	app.dialogue.display()
	await settle_line()
	choices = app.dialogue.ui_choice_click_count
	await key(KEY_2)
	check(app.dialogue.ui_choice_click_count == choices + 1 and app.story.index == 2, "keyboard choice shares crisp confirmation without double sound")
	check(app.dialogue.page_click_sound.volume_db >= -2.0 and app.dialogue.dialogue_confirm.volume_db >= -1.0, "page and choice sounds have audible levels")
	check(app.dialogue.comic_sound.volume_db >= -3.0 and app.dialogue.transition_sound.volume_db >= -3.0, "comic and transition cues have raised levels")
	check(app.dialogue.success_sound.stream.resource_path.ends_with("story_success.wav") and app.dialogue.death_sound.stream.resource_path.ends_with("story_failure.wav"), "result animations use compressed story cues")
	for i in 10:
		app.story.history.append({"speaker": "芙宁娜", "text": "台词有证，嘴硬无效。先把水烧开，再研究水杯为什么能获奖。".repeat(3)})
	app.dialogue.toggle_history()
	await create_timer(0.4).timeout
	var history = app.dialogue.history_panel
	check(history.row_count == app.story.history.size() and history.scroll.get_v_scroll_bar().max_value > history.scroll.size.y, "long history creates scrollable wrapped cards")
	for row in history.entries.get_children():
		check(row.size.x <= history.scroll.size.x + 0.1, "history card stays inside scroll width")
	if DisplayServer.get_name() != "headless":
		history.scroll.scroll_vertical = 0
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../qa/story_review_20261005/history_redesign.png")
	app.dialogue.close_history()
	app.story.reset()
	var comics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
	app.dialogue.play_comic_panel(str(comics.mode1_opening[0].image), "像往常一样从床上醒来。")
	await process_frame
	await process_frame
	check(app.dialogue.comic_sound.playing, "comic reveal actually starts its audio player")
	var deadline: int = Time.get_ticks_msec() + 3000
	while not app.dialogue.animation_waiting and Time.get_ticks_msec() < deadline: await process_frame
	clicks = app.dialogue.ui_click_count
	await click(Vector2(640, 600))
	check(app.dialogue.ui_click_count == clicks + 1, "comic acknowledgement plays one page sound")
	await create_timer(0.4).timeout
	app.dialogue.play_stage_transition()
	await process_frame
	check(app.dialogue.transition_sound.playing, "stage transition actually starts its audio player")
	await create_timer(0.7).timeout
	print("STORY UI QA: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
