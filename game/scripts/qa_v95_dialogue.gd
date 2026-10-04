extends RefCounted

var game
var tree: SceneTree
var output := ""
var phase := "after"
var failures: Array[String] = []
var checks := 0
var observations: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	print("V95 DIALOGUE %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures.append(message)

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	game.get_viewport().push_input(motion, true)
	await tree.process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		game.get_viewport().push_input(event, true)
		await tree.process_frame

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		game.get_viewport().push_input(event, true)
		await tree.process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output.path_join(phase + "-" + name + ".png"))

func wait_for(condition: Callable, timeout: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		if bool(condition.call()): return true
		await tree.create_timer(0.025).timeout
	return false

func assert_plain_dialogue(label: String) -> void:
	check(game.dialogue.root.find_child("dialog_frame", true, false) == null, label + ": skull and empty dialogue frame are absent")
	var decorations := 0
	for button: Button in game.dialogue.choice_buttons:
		for child: Node in button.get_children():
			if child is TextureRect or child is NinePatchRect: decorations += 1
	check(decorations == game.dialogue.choice_buttons.size(), label + ": original two-choice frame textures are retained")
	check(game.dialogue.body.is_visible_in_tree() and not game.dialogue.body.text.is_empty(), label + ": original dialogue text remains visible")
	check(game.dialogue.portrait.is_visible_in_tree() and game.dialogue.portrait.texture != null, label + ": original character portrait remains visible")
	check(not game.dialogue.name_label.text.is_empty(), label + ": original speaker remains named")
	if not game.story.has_choices():
		check(game.dialogue.choice_buttons.all(func(button: Button) -> bool: return not button.visible), label + ": ordinary line shows no empty choice controls")

func snapshot(label: String) -> void:
	var frame: Node = game.dialogue.root.find_child("dialog_frame", true, false)
	var row := {"label": label, "story": game.story.key, "speaker": game.dialogue.name_label.text,
		"line": game.story.index, "choices": game.story.current().get("choices", []).size(),
		"empty_frame": frame != null, "frame_texture": frame.texture.resource_path if frame is NinePatchRect and frame.texture != null else "",
		"workbook_frame": game.content.ui.get("dialog_frame", {}),
		"workbook_frame_asset": game.content.assets.get(str(game.content.ui.get("dialog_frame", {}).get("asset", "")), ""),
		"choice_texts": game.dialogue.choice_buttons.map(func(button: Button) -> String: return button.text)}
	observations.append(row)
	print("V95 OBSERVATION: " + JSON.stringify(row))

func advance_to_choices() -> bool:
	for step in 20:
		if not game.story.active: return false
		if game.story.has_choices():
			return await wait_for(func() -> bool: return game.dialogue.choice_buttons[0].visible and not game.dialogue.choice_buttons[0].disabled)
		await click(Vector2(640, 530))
		await tree.create_timer(0.18).timeout
	return false

func finish_home() -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		if game.home_panel.is_open() and not game.home_panel.busy and not game.story.active and not game.dialogue.root.visible: return true
		if game.dialogue.animation_waiting:
			await key(KEY_ENTER)
		elif game.story.active and not game.dialogue.comic_playing and not game.dialogue.death_playing:
			if game.story.has_choices() and game.dialogue.choice_buttons[0].visible:
				await key(KEY_1)
			else:
				await click(Vector2(640, 530))
		await tree.create_timer(0.06).timeout
	return false

func test_amiya_home() -> void:
	game.compendium.unlock_character("hero_06")
	await click(game.mode_select_panel.continue_button.get_global_rect().get_center())
	check(game.home_panel.is_open(), "native main menu opens original home")
	game.home_panel.refresh_residents()
	var amiya: Dictionary = {}
	for npc: Dictionary in game.home_panel.npcs:
		if str(npc.id) == "hero_06": amiya = npc
	check(not amiya.is_empty(), "unlocked Amiya exists on original home map")
	if amiya.is_empty(): return
	game.home_panel.player_pos = Vector2(amiya.pos) + Vector2(0, 8)
	game.home_panel._update_camera()
	seed(9506)
	game.last_home_scene.erase("hero_06")
	await key(KEY_F)
	check(game.story.active and game.story.key.begins_with("home_hero_06_"), "native F opens Amiya's authored interaction")
	await tree.create_timer(0.7).timeout
	snapshot("amiya-original-line")
	assert_plain_dialogue("Amiya ordinary line")
	await capture("amiya-line")
	check(await advance_to_choices(), "native pointer advances Amiya story to actual choices")
	await tree.create_timer(0.4).timeout
	snapshot("amiya-choices")
	assert_plain_dialogue("Amiya actual choices")
	check(game.dialogue.choice_buttons.all(func(button: Button) -> bool: return button.visible and not button.text.is_empty()), "authored choice controls contain readable option text")
	check(game.dialogue.choice_frames[0].texture == game.dialogue.UI_SKIN.choice_frame_red and game.dialogue.choice_frames[1].texture == game.dialogue.UI_SKIN.choice_frame_gray, "original selected red and idle gray choice frames are restored")
	await capture("amiya-choices")
	var choices_before: int = game.story.choice_history.size()
	await key(KEY_TAB)
	check(game.get_viewport().gui_get_focus_owner() == game.dialogue.choice_buttons[1], "native Tab moves focus to second actual option")
	check(game.dialogue.choice_frames[1].texture == game.dialogue.UI_SKIN.choice_frame_red and game.dialogue.choice_frames[0].texture == game.dialogue.UI_SKIN.choice_frame_gray, "restored choice frames follow keyboard focus")
	await key(KEY_TAB)
	await key(KEY_1)
	check(game.story.choice_history.size() == choices_before + 1, "native number key commits one authored home choice")
	await tree.create_timer(0.3).timeout
	assert_plain_dialogue("Amiya response")
	check(game.dialogue.choice_buttons.all(func(button: Button) -> bool: return not button.visible), "response removes choices instead of leaving an empty option frame")
	await capture("amiya-response")
	check(await finish_home(), "home dialogue and original animation acknowledgement return control to home")
	check(not game.dialogue.animation_waiting and not game.dialogue.death_playing, "home interaction leaves no pending animation gate")
	await key(KEY_ESCAPE)
	check(game.mode_select_panel.is_open(), "native Escape returns home to main menu")

func test_campaign_dialogue() -> void:
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01", squad, 9501)
	game.story.reset()
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	game.primary()
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if game.story.active and not game.campaign_prelude_active and not game.dialogue.comic_playing: break
		if game.dialogue.animation_waiting: await click(Vector2(640, 680))
		await tree.create_timer(0.04).timeout
	check(game.story.active and game.story.key == "mode1_opening", "original campaign comics lead to authored opening dialogue")
	await tree.create_timer(0.3).timeout
	assert_plain_dialogue("campaign opening")
	await capture("campaign-opening")
	check(await advance_to_choices(), "native pointer advances campaign opening to actual choices")
	await tree.create_timer(0.3).timeout
	var before: int = game.story.choice_history.size()
	await click(game.dialogue.choice_buttons[0].get_global_rect().get_center())
	check(game.story.choice_history.size() == before + 1, "native pointer commits one authored campaign choice")
	deadline = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if game.sim.state == "running" and not game.story.active and not game.campaign_prelude_active and not game.squad_panel.is_open(): break
		if game.dialogue.animation_waiting: await key(KEY_SPACE)
		elif game.squad_panel.is_open() and game.campaign_recruit_reselect: await click(game.squad_panel.confirm_button.get_global_rect().get_center())
		elif game.story.active and not game.campaign_prelude_active and not game.dialogue.comic_playing:
			if game.story.has_choices() and game.dialogue.choice_buttons[0].visible: await key(KEY_1)
			else: await click(Vector2(640, 530))
		await tree.create_timer(0.05).timeout
	check(game.sim.state == "running" and not game.dialogue.animation_waiting, "original campaign success and stage transitions start battle without hanging")
	game.return_to_main_menu()

func run(owner_game) -> int:
	game = owner_game
	tree = game.get_tree()
	game.test_mode = false
	game.set_physics_process(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-phase="): phase = arg.trim_prefix("--qa-phase=")
	if not output.is_absolute_path(): return 2
	DirAccess.make_dir_recursive_absolute(output)
	check(game.qa_storage_path.begins_with(output), "native dialogue validation uses isolated QA save")
	if game.dialogue == null or game.dialogue.root == null:
		check(false, "actual game dialogue initialized successfully")
		return 2
	for frame in 5: await tree.process_frame
	await test_amiya_home()
	await test_campaign_dialogue()
	check(checks >= 39, "all expected home and campaign dialogue branches executed")
	var file := FileAccess.open(output.path_join("dialogue-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "observations": observations}, "\t"))
	print("V95 DIALOGUE COMPLETE: %d checks, %d failures" % [checks, failures.size()])
	return 0 if failures.is_empty() else 1
