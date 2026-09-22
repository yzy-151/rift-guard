extends RefCounted

var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("V74 PASS: ", label)
	else:
		failures += 1
		push_error("V74 FAIL: " + label)

func run(game) -> void:
	var sim = game.sim
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	sim.reset_stage("stage_01", squad, 7401)
	sim.start()
	sim.toggle_pause()
	game.refresh()
	var help_button: Button = game.hud.pause_help_button
	check(help_button != null and help_button.text == "help", "pause menu exposes the discreet help text button")
	check(help_button.get_theme_stylebox("normal") is StyleBoxEmpty and help_button.get_theme_font("font") == game.hud.DISPLAY_FONT, "help uses an unframed Leigai text treatment")
	var pending_before := int(sim.run_state.pending_level_ups)
	var history_before: int = sim.rewards.history.size()
	help_button.pressed.emit()
	await game.get_tree().process_frame
	check(sim.state == "reward" and sim.rewards.offered.size() == 3 and game.hud.reward_panel.visible, "help opens one regular three-card draw")
	game.choose_reward(0, 0)
	await game.get_tree().process_frame
	check(sim.state == "paused", "debug card choice returns to the pause menu")
	check(int(sim.run_state.pending_level_ups) == pending_before and sim.rewards.history.size() == history_before + 1, "debug draw grants one card without consuming a level-up choice")
	print("V74 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.audio_director.music_player.stop()
	await game.get_tree().process_frame
	game.get_tree().quit(failures)
