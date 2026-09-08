extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V5 PASS: " + message)
	else:
		failures += 1
		push_error("V5 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v5-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func close_dialogue(game) -> void:
	game.story.skip()
	game.dialogue.root.hide()
	game.hud.get_child(0).show()
	game.story.reset()

func prepare_battle(game, element: String) -> void:
	if game.sim.state == "ready":
		game.sim.start()
	game.sim.state = "running"
	game.sim.run_state.traveler_element = element
	game.sim.heroes[0].element = element
	game.sim.traveler_skill_cooldown = 0.0
	game.sim.enemies.clear()
	game.sim.projectiles.clear()
	game.sim.skill_effects.clear()
	game.sim.geo_constructs.clear()
	var roster := ["grunt", "runner", "armored", "flyer", "ranged", "buffer", "shielded"]
	for i in roster.size():
		game.sim.spawn_enemy(Vector2(690 + (i % 4) * 92, 286 + (i / 4) * 130), roster[i])

func cast_and_capture(game, element: String, point: Vector2, name: String) -> void:
	prepare_battle(game, element)
	var activated: bool = game.sim.activate_traveler_skill(point)
	game.process_events()
	expect(activated, "%s skill activates" % element)
	expect(game.sim.traveler_skill_cooldown > 0.0, "%s skill enters cooldown" % element)
	await capture(game, name)

func run(game) -> void:
	expect(game.hud.HT_BUTTON != null and game.hud.HT_PANEL != null, "HUD loads Helltaker UI textures")
	await capture(game, "01-helltaker-title")
	game.preview_scene("mode1_opening")
	for i in 38:
		await game.get_tree().process_frame
	expect(game.story.active, "Helltaker-style story scene opens")
	expect(game.dialogue.background_texture.texture != null, "story scene uses Helltaker background")
	await capture(game, "02-helltaker-dialogue")
	close_dialogue(game)
	await cast_and_capture(game, "none", Vector2(715, 360), "03-sword-wave")
	await cast_and_capture(game, "pyro", Vector2(790, 360), "04-pyro-burst")
	await cast_and_capture(game, "electro", Vector2(790, 360), "05-electro-chain")
	prepare_battle(game, "anemo")
	expect(game.sim.activate_traveler_skill(Vector2(730, 360)), "anemo tornado activates")
	game.sim._skill_effect_tick(0.45)
	game.process_events()
	expect(not game.sim.skill_effects.is_empty(), "anemo tornado persists and moves")
	await capture(game, "06-anemo-tornado")
	prepare_battle(game, "hydro")
	game.sim.heroes[0].hp = 80.0
	expect(game.sim.activate_traveler_skill(Vector2(760, 360)), "hydro field activates")
	game.process_events()
	expect(game.sim.heroes[0].hp > 80.0, "hydro skill heals the squad")
	await capture(game, "07-hydro-field")
	prepare_battle(game, "cryo")
	expect(game.sim.activate_traveler_skill(Vector2(790, 360)), "cryo field activates")
	game.process_events()
	expect(game.sim.enemies.any(func(e): return e.slow_timer > 0.0), "cryo skill slows enemies")
	await capture(game, "08-cryo-field")
	prepare_battle(game, "geo")
	expect(game.sim.activate_traveler_skill(Vector2(620, 360)), "geo construct deploys")
	game.process_events()
	expect(game.sim.geo_constructs.size() == 1, "geo construct is destructible terrain")
	await capture(game, "09-geo-construct")
	game.restart()
	game.sim.start()
	game.sim.grant_xp(40)
	expect(game.sim.state == "reward" and game.sim.rewards.offered.size() == 3, "Helltaker card screen keeps three-choice reward")
	await capture(game, "10-helltaker-reward")
	print("V5 UI TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
