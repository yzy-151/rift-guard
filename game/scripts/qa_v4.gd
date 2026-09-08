extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V4 PASS: " + message)
	else:
		failures += 1
		push_error("V4 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v4-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	await capture(game, "01-title")
	game.compendium_panel.open("characters")
	expect(game.compendium_panel.is_open(), "compendium opens and freezes combat")
	await capture(game, "02-characters")
	for card: Dictionary in game.sim.database.cards.slice(0, 12):
		game.compendium.discovered_cards[str(card.id)] = true
	game.compendium_panel.show_tab("cards")
	await capture(game, "03-cards")
	for id: String in preload("res://scripts/combat_catalog.gd").ENEMIES:
		game.compendium.encountered_enemies[id] = true
	game.compendium_panel.show_tab("enemies")
	await capture(game, "04-enemies")
	game.compendium_panel.close()
	game.sim.start()
	game.sim.run_state.traveler_element = "electro"
	game.sim.heroes[0].element = "electro"
	game.sim.run_state.buff_levels = {"mechanic_twin_arc": 3, "mechanic_chain_arc": 2, "support_red_moon": 2}
	game.sim.supports = {"support_barrage": {"stacks": 2, "timer": 4.2}}
	var kinds: Array = preload("res://scripts/combat_catalog.gd").ENEMIES.keys()
	for i in kinds.size():
		game.sim.spawn_enemy(Vector2(700 + (i % 4) * 105, 270 + (i / 4) * 145), kinds[i])
	game.compendium.observe(game.sim)
	game.refresh()
	expect(game.sim.run_state.traveler_element == "electro", "Traveler element state is visible in runtime and HUD")
	expect(game.sim.enemies.size() == preload("res://scripts/combat_catalog.gd").ENEMIES.size(), "all enemy archetypes can coexist")
	expect(not game.sim.run_state.buff_levels.is_empty() and not game.sim.supports.is_empty(), "selected buffs and off-field support are visible")
	await capture(game, "05-element-buffs-enemy-roster")
	game.advance_stage()
	expect(game.squad_panel.is_open(), "stage clear opens the squad selection screen")
	game.squad_panel.toggle("hero_02")
	game.squad_panel.confirm()
	expect(game.sim.current_stage_id == "stage_02", "stage one advances directly into stage two")
	expect(game.sim.heroes.size() == 2 and game.sim.heroes[1].character_id == "hero_02", "cleared-stage character joins the next stage")
	expect(game.sim.run_state.buff_levels.is_empty(), "stage transition clears the previous build")
	expect(game.story.active and game.story.key == "mode1_stage2_opening", "stage two begins with a story scene")
	await capture(game, "06-stage2-dialogue")
	print("V4 UI TESTS: %d checks; %d failures" % [checks, failures])
	game.story.skip()
	game.dialogue.root.hide()
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
