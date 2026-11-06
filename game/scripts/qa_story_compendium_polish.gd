extends SceneTree

var app
var failures: Array[String] = []
var events: Array[Dictionary] = []
var assertions := 0
const OUTPUT := "res://../qa/story_compendium_20261005"
const AUDIO := "res://assets/helltaker/audio/"
var output_directory := OUTPUT

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	assertions += 1
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
		Input.parse_input_event(motion.duplicate())
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

func release_focus() -> void:
	var focus := root.gui_get_focus_owner()
	if focus != null: focus.release_focus()

func audio_event(kind: String, path: String, gain: float) -> void:
	var players: Dictionary = {
		"portrait_continue": app.dialogue.portrait_continue_sound,
		"comic_flip": app.dialogue.comic_page_sound,
		"comic_arrival": app.dialogue.comic_sound,
		"choice_confirm": app.dialogue.dialogue_confirm,
		"ui_click": app.dialogue.page_click_sound,
		"choice_hover": app.dialogue.choice_highlight_sound,
		"stage_transition": app.dialogue.transition_sound,
	}
	var player: AudioStreamPlayer = players[kind]
	events.append({"kind": kind, "file": path, "gain_db": gain, "bus": player.bus,
		"playing": player.playing, "time_ms": Time.get_ticks_msec()})

func expect_event(since: int, kind: String, file: String, gain: float, label: String) -> void:
	var filtered: Array = events.slice(since).filter(func(item): return item.kind == kind)
	check(filtered.size() == 1, label + " plays exactly one sound")
	if filtered.is_empty(): return
	var event: Dictionary = filtered[0]
	check(event.kind == kind and event.file == AUDIO + file and is_equal_approx(event.gain_db, gain), label + " uses master's exact WAV and gain")
	check(event.playing and event.bus == "SFX", label + " starts a real SFX player")

func begin_plain() -> void:
	app.story.reset()
	app.story.begin("qa_master_audio")
	app.dialogue.display()
	await create_timer(0.25).timeout

func begin_choice() -> void:
	app.story.reset()
	app.story.begin("qa_master_audio_choice")
	app.dialogue.display()
	await create_timer(0.25).timeout

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output_directory.path_join(name + ".png")) == OK, "capture " + name)

func wait_for_confirmation() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not app.dialogue.animation_waiting and Time.get_ticks_msec() < deadline:
		await process_frame
	check(app.dialogue.animation_waiting, "comic reaches its real confirmation gate")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):
			var requested_output := argument.trim_prefix("--qa-output=").replace("\\", "/")
			if not requested_output.is_absolute_path() or requested_output.begins_with("res://") or requested_output.begins_with("user://"):
				push_error("--qa-output requires an absolute filesystem directory")
				quit(2)
				return
			output_directory = requested_output
	var output_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	if output_error != OK:
		push_error("Cannot create QA output directory: " + output_directory)
		quit(2)
		return
	create_timer(45.0).timeout.connect(func(): push_error("STORY/COMPENDIUM QA timeout"); quit(2))
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.set_process(false)
	app.set_physics_process(false)
	app.mode_select_panel.close()
	app.story.begin("mode1_opening")
	var portrait_path: String = app.story.current().get("portrait", "")
	app.story.reset()
	app.story.stories["qa_master_audio"] = [
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "先把水烧开，别把音效也煮沸了。"},
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "继续一句，只响一次。"},
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "自动翻页安静一点。"}]
	app.story.stories["qa_master_audio_choice"] = [
		{"speaker": "芙宁娜", "portrait": portrait_path, "text": "清脆的二选一，要哪杯水？", "choices": [
			{"text": "开水", "response": "开水已收到。"},
			{"text": "获奖开水", "response": "水杯获奖了。"}]}]
	app.dialogue.story_audio_played.connect(audio_event)
	var sfx_bus := AudioServer.get_bus_index("SFX")
	var limiter_found := false
	for index in AudioServer.get_bus_effect_count(sfx_bus):
		if AudioServer.get_bus_effect(sfx_bus, index) is AudioEffectLimiter:
			limiter_found = true
	check(sfx_bus >= 0 and limiter_found, "SFX bus retains its existing limiter")
	await begin_plain()
	check(events.is_empty() and not app.dialogue.comic_sound.playing and not app.dialogue.comic_page_sound.playing, "portrait display has no automatic comic arrival/end cue")
	var before := events.size()
	await click(Vector2(640, 580))
	expect_event(before, "portrait_continue", "button_dialogue_confirm_01.wav", 2.5, "portrait mouse continuation")
	check(app.story.index == 1, "actual mouse advances the portrait line")
	await create_timer(0.25).timeout
	check(events.size() == before + 1, "new portrait line adds no delayed second cue")
	await begin_plain()
	app.dialogue.letters = 2
	app.dialogue.body.visible_characters = 2
	app.dialogue.line_ended = false
	before = events.size()
	await click(Vector2(640, 580))
	expect_event(before, "portrait_continue", "button_dialogue_confirm_01.wav", 2.5, "typing reveal mouse click")
	check(app.story.index == 0 and app.dialogue.line_ended and app.dialogue.body.visible_characters == -1, "typing reveal shows the text without skipping a line")
	release_focus()
	before = events.size()
	await key(KEY_ENTER)
	expect_event(before, "portrait_continue", "button_dialogue_confirm_01.wav", 2.5, "portrait Enter continuation")
	check(app.story.index == 1, "actual Enter advances the portrait line")
	app.dialogue.letters = 2
	app.dialogue.body.visible_characters = 2
	app.dialogue.line_ended = false
	before = events.size()
	await key(KEY_SPACE)
	expect_event(before, "portrait_continue", "button_dialogue_confirm_01.wav", 2.5, "typing reveal Space")
	check(app.story.index == 1 and app.dialogue.line_ended, "Space reveals text without skipping")
	app.dialogue.auto_mode = true
	app.dialogue.auto_timer = 1.99
	before = events.size()
	await create_timer(0.05).timeout
	check(app.story.index == 2 and events.size() == before, "automatic portrait continuation creates no fake click sound")
	app.dialogue.auto_mode = false
	await begin_choice()
	var hover_point: Vector2 = root.get_screen_transform() * app.dialogue.choice_buttons[1].get_global_rect().get_center()
	var hover_event := InputEventMouseMotion.new()
	hover_event.position = hover_point
	hover_event.global_position = hover_point
	before = events.size()
	Input.parse_input_event(hover_event)
	await process_frame
	expect_event(before, "choice_hover", "button_dialogue_highlight_01.wav", 5.0, "mouse two-choice hover")
	check(events.size() == before + 1 and app.dialogue.choice_buttons[1].has_focus(), "mouse hover highlights a branch and adds no duplicate generic sound")
	app.dialogue.choice_buttons[0].grab_focus()
	expect_event(before + 1, "choice_hover", "button_dialogue_highlight_01.wav", 5.0, "keyboard branch focus")
	before = events.size()
	await click(Vector2(640, 260))
	check(events.size() == before and app.story.index == 0, "background click cannot confirm a two-choice branch or play a false cue")
	await click(app.dialogue.choice_buttons[0].get_global_rect().get_center())
	expect_event(before, "choice_confirm", "button_dialogue_confirm_01.wav", 2.5, "mouse two-choice confirmation")
	await begin_choice()
	before = events.size()
	await key(KEY_2)
	expect_event(before, "choice_confirm", "button_dialogue_confirm_01.wav", 2.5, "keyboard two-choice confirmation")
	await begin_choice()
	app.dialogue.choice_buttons[0].grab_focus()
	before = events.size()
	await key(KEY_ENTER)
	expect_event(before, "choice_confirm", "button_dialogue_confirm_01.wav", 2.5, "focused two-choice Enter confirmation")
	await begin_plain()
	var original_bus_gain := AudioServer.get_bus_volume_db(sfx_bus)
	AudioServer.set_bus_volume_db(sfx_bus, -36.0)
	before = events.size()
	await click(Vector2(640, 580))
	check(events.size() == before + 1 and is_equal_approx(AudioServer.get_bus_volume_db(sfx_bus), -36.0), "portrait cue respects the user's SFX bus gain")
	AudioServer.set_bus_volume_db(sfx_bus, original_bus_gain)
	app.story.reset()
	var comics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
	var image: String = comics.mode1_opening[0].image
	before = events.size()
	app.dialogue.play_comic_panel(image, "master，图片出现和翻页各有自己的声音。")
	await process_frame
	await process_frame
	expect_event(before, "comic_arrival", "dialogue_start_01.wav", -2.0, "comic arrival")
	check(not app.dialogue.comic_page_sound.playing, "comic arrival does not automatically play its flip sound")
	await wait_for_confirmation()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output_directory.path_join("comic_sound_mapping.png"))
	before = events.size()
	await click(Vector2(640, 600))
	expect_event(before, "comic_flip", "dialogue_text_end_01.wav", 7.0, "comic mouse flip")
	check(not app.dialogue.comic_sound.playing and not app.dialogue.animation_waiting, "comic flip stops arrival audio and consumes the gate")
	app.dialogue.acknowledge_animation()
	check(events.size() == before + 1, "repeated acknowledgement cannot replay the flip sound")
	await create_timer(0.4).timeout
	before = events.size()
	app.dialogue.play_comic_panel(image, "master，再确认键盘翻页。")
	await process_frame
	await process_frame
	expect_event(before, "comic_arrival", "dialogue_start_01.wav", -2.0, "next comic arrival")
	check(not app.dialogue.comic_page_sound.playing, "next comic arrival stops the previous flip cue")
	await wait_for_confirmation()
	before = events.size()
	await key(KEY_ENTER)
	expect_event(before, "comic_flip", "dialogue_text_end_01.wav", 7.0, "comic Enter flip")
	await create_timer(0.4).timeout
	app.dialogue.play_comic_panel(image, "master，空格也应当只播图片翻页声。")
	await wait_for_confirmation()
	before = events.size()
	await key(KEY_SPACE)
	expect_event(before, "comic_flip", "dialogue_text_end_01.wav", 7.0, "comic Space flip")
	await create_timer(0.4).timeout
	check(app.dialogue.page_click_sound.stream.resource_path.ends_with("story_ui/page_click.wav") and app.dialogue.transition_sound.stream.resource_path.ends_with("helltaker/audio/dialogue_start_01.wav"), "general UI clicks retain their old sound and stage animation uses master's start WAV")
	before = events.size()
	app.dialogue.play_stage_transition()
	expect_event(before, "stage_transition", "dialogue_start_01.wav", -2.0, "stage animation")
	await create_timer(0.7).timeout
	app.story.reset()
	app.dialogue.root.hide()
	app.mode_select_panel.open()
	var archive = app.compendium_panel
	for tab_button: Button in archive.tabs:
		tab_button.button_down.connect(func(): print("TAB DOWN " + tab_button.text))
		tab_button.button_up.connect(func(): print("TAB UP " + tab_button.text))
		tab_button.pressed.connect(func(): print("TAB PRESS " + tab_button.text))
	app.open_menu_archive()
	await process_frame
	check(archive.is_open() and archive.tabs.size() == 5 and archive.list.get_child_count() == app.sim.database.characters.size(), "comic archive retains all five tabs and complete character catalogue")
	var character_row: Button = archive.list.get_child(0)
	check(character_row.get_meta("archive_known") and character_row.custom_minimum_size.y == 150 and character_row.get_node("ArchivePreview").size.y >= 115, "character row uses a large real portrait and readable tall paper strip")
	await click(character_row.get_global_rect().get_center())
	check(archive.detail_overlay.visible and archive.detail_frame.find_child("ArchivePreview", true, false) != null, "real character click opens large portrait detail")
	await capture("characters_detail")
	await key(KEY_ESCAPE)
	check(archive.is_open() and not archive.detail_overlay.visible, "first Escape returns from character detail to the same list")
	await capture("characters")
	for card: Dictionary in app.sim.database.cards: app.compendium.discovered_cards[str(card.id)] = true
	await click(archive.tabs[1].get_global_rect().get_center())
	await process_frame
	check(archive.active_tab == "cards" and archive.list.get_child_count() == app.sim.database.cards.size(), "real card tab shows every discovered card")
	await capture("cards")
	await click(archive.list.get_child(0).get_global_rect().get_center())
	check(archive.detail_overlay.visible, "real card click opens full readable description and stack limit")
	await capture("cards_detail")
	await click(archive.detail_return.get_global_rect().get_center())
	check(not archive.detail_overlay.visible and archive.active_tab == "cards", "detail Return button restores card list without changing the tab")
	var wheel_point: Vector2 = root.get_screen_transform() * (archive.scroll.get_global_rect().get_center())
	for index in 6:
		var wheel := InputEventMouseButton.new()
		wheel.position = wheel_point
		wheel.global_position = wheel_point
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await process_frame
		wheel = wheel.duplicate()
		wheel.pressed = false
		Input.parse_input_event(wheel)
		await process_frame
	check(archive.scroll.scroll_vertical > 0, "real wheel scroll keeps long card catalogue accessible")
	for enemy_id: String in preload("res://scripts/combat_catalog.gd").ENEMIES: app.compendium.encountered_enemies[enemy_id] = true
	await click(archive.tabs[2].get_global_rect().get_center())
	await process_frame
	print("ARCHIVE enemy tab=" + archive.active_tab + " scroll=" + str(archive.scroll.scroll_vertical) + " detail=" + str(archive.detail_overlay.visible))
	check(archive.active_tab == "enemies" and archive.scroll.scroll_vertical == 0, "enemy tab resets scrolling to its own list")
	await capture("enemies")
	await click(archive.list.get_child(0).get_global_rect().get_center())
	check(archive.detail_overlay.visible, "real enemy click opens combat dossier")
	await capture("enemies_detail")
	await key(KEY_ESCAPE)
	await click(archive.tabs[3].get_global_rect().get_center())
	check(archive.active_tab == "achievements" and archive.list.get_child_count() > 0, "achievement wall remains functional in comic style")
	await capture("achievements")
	await click(archive.tabs[4].get_global_rect().get_center())
	check(archive.active_tab == "builds" and archive.list.get_child_count() >= 1, "build history retains an informative empty state")
	await capture("builds")
	await key(KEY_ESCAPE)
	check(not archive.is_open() and app.mode_select_panel.is_open(), "archive closes back to its underlying menu")
	var report := {"graphical": DisplayServer.get_name() != "headless", "input": "Input.parse_input_event mouse/keyboard", "assertions": assertions, "failures": failures, "events": events}
	var output := FileAccess.open(output_directory.path_join("validation.json"), FileAccess.WRITE)
	if output == null:
		push_error("Cannot write QA report: " + output_directory)
		quit(2)
		return
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print("STORY AND COMPENDIUM QA: %d assertions, %d failures" % [assertions, failures.size()])
	app.queue_free()
	await process_frame
	app = null
	await process_frame
	quit(0 if failures.is_empty() else 1)
