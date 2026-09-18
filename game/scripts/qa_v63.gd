extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
var checks := 0
var failures := 0
var output_dir := ""

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V63 PASS: " + message)
	else:
		failures += 1
		push_error("V63 FAIL: " + message)

func capture(game, name: String) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.12).timeout
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, name + " frame available")
	if image == null: return
	if image.get_size() != Vector2i(1920, 1080): image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	expect(image.save_png(output_dir.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	output_dir = ProjectSettings.globalize_path("res://../docs/v63-validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	expect(float(Catalog.ENEMIES.shielded.damage) >= 110.0 and float(Catalog.ENEMIES.armored.damage) >= 50.0, "large melee damage increased")
	for boss_id in ["boss_01", "boss_02", "boss_03", "boss_04", "boss_05", "boss_06"]:
		expect(float(Catalog.ENEMIES[boss_id].damage) >= 110.0, boss_id + " boss damage increased")
	var allowed := ["grunt", "ranged", "buffer", "armored", "shielded", "slime_pyro", "slime_electro", "slime_anemo", "slime_hydro", "slime_cryo"]
	var stage_one: Dictionary = game.sim.database.stages.stage_01
	expect(str(stage_one.boss_id) == "boss_02", "Mondstadt boss is slime king")
	for wave: Dictionary in stage_one.waves:
		expect(str(wave.enemy_id) in allowed, "Mondstadt wave uses regional roster")
	for stage_id: String in game.sim.database.stages:
		if stage_id == "stage_01" or stage_id == "stage_endless": continue
		for terrain: Dictionary in game.sim.database.stages[stage_id].get("terrain", []):
			expect(str(terrain.get("type", "")) not in ["moving_platform", "one_way", "shortcut"], stage_id + " uses wall/door terrain")
	var hero_07: Dictionary = game.sim.database.characters.hero_07
	expect(str(hero_07.element) == "pyro" and str(hero_07.active_skill.element) == "pyro" and str(hero_07.ultimate.element) == "pyro", "Toyokawa Sakiko is fully pyro")
	for id: String in game.sim.database.characters:
		var ultimate: Dictionary = game.sim.database.characters[id].ultimate
		expect(float(ultimate.energy_cost) >= 130.0 and float(ultimate.cooldown) >= 40.0, id + " ultimate cost and cooldown increased")
	var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
	game.sim.reset_stage("stage_02", squad, 6301)
	for hero: Dictionary in game.sim.heroes: hero.deployed = true
	var blocker: Dictionary = game.sim.terrain_features.filter(func(f: Dictionary) -> bool: return game.sim._feature_blocks(f))[0]
	game.sim.heroes[0].pos = blocker.area.get_center()
	game.sim.heroes[0].target = blocker.area.get_center()
	game.sim._move_hero_with_terrain(game.sim.heroes[0], 0.016)
	expect(not game.sim._terrain_blocks(game.sim.heroes[0].pos, 17.0), "hero recovers from blocked position")
	expect(game.stage_select_panel.buttons.size() == 8, "stage select has no endless footer card")
	expect(game.hud.pause_squad_button.text.contains("图鉴") and not game.hud.pause_stage_button.visible, "pause replaces squad and stage with compendium")
	game.hud.get_child(0).hide(); game.mode_select_panel.open(); await capture(game, "01-mode-select")
	game.mode_select_panel.close(); game.settings_panel.open({"master":0.82,"music":0.46,"sfx":0.90,"fullscreen":false,"reduced_effects":false}); await capture(game, "02-settings"); game.settings_panel.root.hide()
	game.stage_select_panel.open(); await capture(game, "03-stage-select")
	game.stage_select_panel.close(); game.squad_panel.open("stage_02", squad, []); await capture(game, "04-squad"); game.squad_panel.root.hide()
	game.hud.get_child(0).show(); game.sim.start(); game.sim.state = "running"; game.selected_id = 0
	game.sim.supports = {
		"support_barrage": {"timer": 12.8, "interval": 18.0, "power": 220.0, "radius": 9999.0, "stacks": 2},
		"support_heal": {"timer": 7.4, "interval": 14.0, "power": 90.0, "radius": 9999.0, "stacks": 1},
		"support_finale": {"timer": 21.2, "interval": 24.0, "power": 300.0, "radius": 9999.0, "stacks": 1},
	}
	var preview_cards: Array = []
	for rarity: String in ["legendary", "epic", "rare", "common"]:
		for card: Dictionary in game.sim.database.cards:
			if str(card.get("rarity", "common")) == rarity and preview_cards.size() < 15:
				preview_cards.append(card)
	for i in mini(15, preview_cards.size()):
		game.sim.run_state.buff_levels[str(preview_cards[i].id)] = 1 + (i % 5)
	game.hud.signature = ""; game.refresh(); game.hud.overlay.hide(); await capture(game, "05-battle-hud")
	game.sim.state = "paused"; game.hud.signature = ""; game.refresh(); game.hud.overlay.show(); game.hud.modal_card.hide(); game.hud.pause_details.show(); game.hud.refresh_pause_details(game.sim); await capture(game, "06-pause")
	print("V63 QA COMPLETE: %d checks, %d failures -> %s" % [checks, failures, output_dir])
	game.get_tree().quit(failures)
