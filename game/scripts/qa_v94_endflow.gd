extends RefCounted

# Native viewport dispatch is essential: direct _input calls or pressed.emit()
# bypass the modal input ordering that deadlocked V93 endings.
const Progress = preload("res://scripts/compendium_state.gd")
var output := ""
var case_filter := "all"
var game
var tree: SceneTree
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var checks := 0
var menu_opens := 0
var squad_opens := 0
var acknowledgements := 0
var narrative_choices := 0
var watched_failures: Dictionary = {}
var active_case := ""
var captured: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	print("V94 ENDFLOW %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok: failures.append(message)

func watch() -> void:
	var forbidden := ""
	if game.achievement_popup.is_open(): forbidden = "earned achievements never open a blocking popup"
	elif game.sim.state in ["won", "lost", "stage_exit"] and game.hud.modal_card.is_visible_in_tree():
		forbidden = "legacy result card stays hidden throughout endings"
	if not forbidden.is_empty() and not watched_failures.has(forbidden):
		watched_failures[forbidden] = true
		check(false, forbidden)

func snapshot(label: String) -> void:
	var row := {"label": label, "state": game.sim.state, "stage": game.sim.current_stage_id,
		"story_active": game.story.active, "story_key": game.story.key,
		"prelude": game.campaign_prelude_active, "animation_waiting": game.dialogue.animation_waiting,
		"death_playing": game.dialogue.death_playing, "achievement_popup": game.achievement_popup.is_open(),
		"old_result_card": game.hud.modal_card.is_visible_in_tree(),
		"mode_menu": game.mode_select_panel.is_open(), "squad": game.squad_panel.is_open(),
		"pending_stage": game.pending_stage_id, "menu_opens": menu_opens,
		"squad_opens": squad_opens, "acknowledgements": acknowledgements,
		"narrative_choices": narrative_choices, "saved_runs": game.compendium.achievement_stats.runs}
	observations.append(row)
	print("V94 OBSERVATION: " + JSON.stringify(row))

func key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		game.get_viewport().push_input(event, true)
		await tree.process_frame
		watch()

func click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
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
		watch()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func wait_for(condition: Callable, timeout: float = 12.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		watch()
		if bool(condition.call()): return true
		await tree.create_timer(0.025).timeout
	return false

func drive_narrative(endpoint: Callable, fast_exit: bool = false, timeout: float = 24.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000)
	while Time.get_ticks_msec() < deadline:
		watch()
		if bool(endpoint.call()): return true
		if game.achievement_popup.is_open(): return false
		if game.dialogue.animation_waiting:
			acknowledgements += 1
			if game.dialogue.success_texture.visible and not captured.has(active_case + "-success"):
				captured[active_case + "-success"] = true
				await capture(active_case + "-success")
			await click(Vector2(640, 680))
		elif game.squad_panel.is_open() and game.campaign_recruit_reselect:
			await click(game.squad_panel.confirm_button.get_global_rect().get_center())
		elif game.story.active and not game.campaign_prelude_active and not game.dialogue.comic_playing and not game.dialogue.death_playing:
			if game.story.has_choices() and game.dialogue.line_ended:
				var before: int = game.story.choice_history.size()
				await key(KEY_1)
				if game.story.choice_history.size() > before: narrative_choices += 1
			else:
				await click(Vector2(640, 360))
		elif fast_exit and game.sim.state == "stage_exit" and not game.story.active and not game.campaign_prelude_active:
			if not captured.has(active_case + "-field-exit"):
				captured[active_case + "-field-exit"] = true
				await capture(active_case + "-field-exit")
			await key(KEY_ENTER)
		await tree.create_timer(0.04).timeout
	return false

func prepare_stage(stage_id: String, seed: int) -> void:
	# Setup alone is direct; transitions and user-facing actions use real input.
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.story.reset()
	game.dialogue.root.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_02", "hero_06"]
	game.sim.reset_stage(stage_id, squad, seed)
	game.sim.start()
	game.stage_result_recorded = false
	game.loss_transition_shown = false
	game.sim.kills = 100
	game.hud.signature = ""
	game.refresh()
	await tree.process_frame

func assert_saved_achievement(id: String, label: String) -> void:
	check(game.compendium.unlocked_achievements.has(id), label + ": achievement still awarded")
	var restored := Progress.new(game.compendium.save_path)
	check(restored.unlocked_achievements.has(id), label + ": achievement persisted to isolated save")

func test_loss(stage_id: String, input_key: Key, label: String) -> void:
	active_case = label
	await prepare_stage(stage_id, 9401)
	var runs_before: int = game.compendium.achievement_stats.runs
	var opens_before := menu_opens
	var squad_before := squad_opens
	if game.sim.endless_mode:
		for hero: Dictionary in game.sim.heroes: hero.hp = 0
	else:
		game.sim.base_hp = 0
	game._physics_process(0.016)
	check(game.sim.state == "lost", label + ": real simulation detects terminal loss")
	check(await wait_for(func() -> bool: return game.dialogue.animation_waiting), label + ": original death animation reaches acknowledgement")
	snapshot(label + "-before-ack")
	await capture(label + "-death")
	if input_key == KEY_NONE:
		await click(Vector2(640, 680))
	else:
		await key(input_key)
	check(await wait_for(func() -> bool: return game.mode_select_panel.is_open(), 3.0), label + ": one native acknowledgement returns to menu")
	await tree.create_timer(0.35).timeout
	snapshot(label + "-after-ack")
	check(menu_opens == opens_before + 1 and squad_opens == squad_before, label + ": menu opens exactly once without squad transition")
	check(not game.dialogue.animation_waiting and not game.dialogue.death_playing and not game.campaign_prelude_active, label + ": no animation or input gate remains waiting")
	check(not game.loss_transition_active and not game.campaign_result_active, label + ": completion releases terminal-state guards")
	check(not game.achievement_popup.is_open(), label + ": no earned-achievement popup")
	check(game.compendium.achievement_stats.runs == runs_before + 1, label + ": result recorded exactly once")
	assert_saved_achievement("hundred_slayer", label)

func test_native_reentry() -> void:
	active_case = "native-reentry"
	await click(game.mode_select_panel.buttons.rift_watch.get_global_rect().get_center())
	check(game.stage_select_panel.is_open(), "native reentry: main menu opens campaign stage selector")
	await click(game.stage_select_panel.buttons.stage_01.get_global_rect().get_center())
	check(game.squad_panel.is_open(), "native reentry: stage selector opens squad")
	await click(game.squad_panel.confirm_button.get_global_rect().get_center())
	check(await drive_narrative(func() -> bool: return game.sim.state == "running" and not game.story.active and not game.campaign_prelude_active and not game.squad_panel.is_open()), "native reentry: next run starts through squad and original opening narrative")
	check(not game.loss_transition_shown, "native reentry: loss acknowledgement is rearmed")

func seed_win() -> void:
	var runtime = game.sim.stage_runtime
	runtime.elapsed = float(runtime.definition.duration_seconds)
	runtime.boss_emitted = true
	runtime.boss_telegraph_emitted = true
	for index in runtime.wave_cursors.size():
		runtime.wave_cursors[index] = int(runtime.definition.waves[index].count)
		runtime.telegraph_emitted[index] = true
	game.sim.pending_stage_spawns.clear()
	game.sim.pending_troop_spawns.clear()
	game.sim.enemies.clear()
	game.sim.projectiles.clear()
	game._physics_process(0.016)

func test_win(stage_id: String, final_win: bool, story_condition: String = "") -> void:
	var label := ("final-win" if final_win else "stage-win") + ("-" + story_condition if not story_condition.is_empty() else "")
	active_case = label
	await prepare_stage(stage_id, 9408 if final_win else 9402)
	var victory_key := "mode1_final_won" if final_win else "mode1_won"
	var backup: Array = game.story.stories[victory_key].duplicate(true)
	if story_condition == "seen": game.story.seen[victory_key] = true
	elif story_condition == "missing": game.story.stories.erase(victory_key)
	var runs_before: int = game.compendium.achievement_stats.runs
	var opens_before := menu_opens
	var squad_before := squad_opens
	var choices_before := narrative_choices
	seed_win()
	check(game.sim.state == "won", label + ": actual scheduler produces win")
	for repeated_tick in 3: game._physics_process(0.016)
	if not story_condition.is_empty():
		await key(KEY_ENTER)
		await key(KEY_ENTER)
	var endpoint := func() -> bool: return game.mode_select_panel.is_open() if final_win else game.squad_panel.is_open()
	check(await drive_narrative(endpoint, not final_win), label + ": native comics, successful choice and animation complete")
	await tree.create_timer(0.35).timeout
	snapshot(label + "-completed")
	await capture(label + "-completed")
	if story_condition.is_empty():
		check(narrative_choices > choices_before, label + ": authored success choice is followed without skipping narrative")
	else:
		check(narrative_choices == choices_before, label + ": unavailable narrative uses completion fallback")
	if final_win:
		check(menu_opens == opens_before + 1 and squad_opens == squad_before, label + ": final campaign returns to menu exactly once")
	else:
		check(squad_opens == squad_before + 1 and menu_opens == opens_before, label + ": next-stage squad opens exactly once")
		check(game.pending_stage_id == "stage_02" and game.sim.state == "stage_exit", label + ": field exit leads to correct next stage")
	check(not game.dialogue.animation_waiting and not game.campaign_prelude_active, label + ": no unfinished animation acknowledgement")
	check(not game.loss_transition_active and not game.campaign_result_active, label + ": completion releases terminal-state guards")
	check(not game.achievement_popup.is_open() and not game.hud.modal_card.is_visible_in_tree(), label + ": both unwanted result popups remain absent")
	check(game.compendium.achievement_stats.runs == runs_before + 1, label + ": result saved exactly once")
	assert_saved_achievement("first_watch", label)
	assert_saved_achievement("hundred_slayer", label)
	game.story.stories[victory_key] = backup

func run(owner_game) -> int:
	game = owner_game
	tree = game.get_tree()
	game.test_mode = false
	game.set_physics_process(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-case="): case_filter = arg.trim_prefix("--qa-case=")
	if not output.is_absolute_path():
		printerr("V94 ENDFLOW requires absolute --qa-output")
		return 2
	DirAccess.make_dir_recursive_absolute(output)
	check(game.qa_storage_path.begins_with(output), "saves stay isolated beneath --qa-output")
	check(not game.test_mode, "real production ending animations remain enabled")
	game.mode_select_panel.root.visibility_changed.connect(func() -> void:
		if game.mode_select_panel.is_open(): menu_opens += 1)
	game.squad_panel.root.visibility_changed.connect(func() -> void:
		if game.squad_panel.is_open(): squad_opens += 1)
	for frame in 4: await tree.process_frame
	if case_filter in ["all", "loss"]:
		await test_loss("stage_03", KEY_NONE, "campaign-loss-click")
		if failures.is_empty():
			await test_native_reentry()
			await test_loss("stage_01", KEY_ENTER, "repeated-loss-enter")
	if case_filter in ["all", "endless"]: await test_loss("stage_endless", KEY_SPACE, "endless-loss-space")
	if case_filter in ["all", "stage"]: await test_win("stage_01", false)
	if case_filter in ["all", "final"]: await test_win("stage_08", true)
	if case_filter in ["all", "fallback"]:
		await test_win("stage_01", false, "seen")
		await test_win("stage_01", false, "missing")
		await test_win("stage_08", true, "seen")
		await test_win("stage_08", true, "missing")
	var file := FileAccess.open(output.path_join("endflow-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "observations": observations}, "\t"))
	print("V94 ENDFLOW COMPLETE: %d checks, %d failures" % [checks, failures.size()])
	return 0 if failures.is_empty() else 1
