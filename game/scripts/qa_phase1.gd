extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("PHASE 1 PASS: " + message)
	else:
		failures += 1
		push_error("PHASE 1 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/phase-1-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	expect(game.sim.v2_mode, "production uses configured core loop")
	expect(game.sim.heroes.size() == 1 and game.sim.heroes[0].character_id == "traveler", "stage one starts with Traveler only")
	expect(game.sim.run_state.traveler_element == "none", "Traveler begins without an element")
	expect(float(game.sim.database.stages.stage_01.duration_seconds) >= 300.0, "stage duration is at least five minutes")
	game.primary()
	expect(game.sim.state == "running", "start action begins configured stage")
	await capture(game, "battle-start")
	game.sim.grant_xp(int(game.sim.database.stages.stage_01.xp_thresholds[0]))
	game.refresh()
	await game.get_tree().process_frame
	expect(game.sim.state == "reward", "crystal level pauses battle for reward")
	expect(game.sim.rewards.offered.size() == 3, "reward screen contains exactly three cards")
	await capture(game, "first-reward")
	for dimensions in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		if DisplayServer.get_name() != "headless":
			DisplayServer.window_set_size(dimensions)
			await game.get_tree().process_frame
			await capture(game, "reward-%dx%d" % [dimensions.x, dimensions.y])
		expect(game.hud.reward_panel.visible and game.sim.rewards.offered.size() == 3, "reward layout remains active at %dx%d" % [dimensions.x, dimensions.y])
	var element_index := -1
	for i in game.sim.rewards.offered.size():
		if game.sim.rewards.offered[i].effect == "assign_traveler_element":
			element_index = i
			break
	expect(element_index >= 0, "first reward guarantees an element card")
	game.choose_reward(element_index)
	expect(game.sim.run_state.traveler_element != "none", "element card locks Traveler element")
	var chosen_element: String = game.sim.run_state.traveler_element
	for seed_value in 50:
		game.sim.card_pool.reseed(seed_value)
		var offer: Array[Dictionary] = game.sim.card_pool.draw_three(game.sim.run_state)
		expect(offer.all(func(card): return card.get("effect", "") != "assign_traveler_element"), "locked element removes assignment cards seed %d" % seed_value)
	game.sim.grant_xp(300)
	expect(game.sim.run_state.pending_level_ups >= 2, "XP overflow queues multiple rewards")
	var squad_before: Array[String] = game.sim.run_state.squad.duplicate()
	game.restart()
	expect(game.sim.run_state.squad == squad_before, "restart preserves selected squad")
	expect(game.sim.run_state.traveler_element == "none", "restart clears Traveler element")
	expect(game.sim.run_state.buff_levels.is_empty(), "restart clears all stage buffs")
	expect(game.sim.team_xp == 0 and game.sim.team_level == 1, "restart clears crystal progress")
	expect(game.sim.enemies.is_empty() and game.sim.projectiles.is_empty(), "restart clears battle objects")
	print("PHASE 1 UI TESTS: %d checks; %d failures; chosen=%s" % [checks, failures, chosen_element])
	game.get_tree().quit(0 if failures == 0 else 1)
