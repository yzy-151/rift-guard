extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V50 PASS: " + message)
	else:
		failures += 1
		push_error("V50 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.35).timeout
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		expect(false, "capture image is available")
		return
	if image.get_size() != Vector2i(1920, 1080):
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path("res://../docs/v50-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	expect(image.save_png(directory.path_join(name + ".png")) == OK, "1920x1080 validation capture written: " + name)

func _feature(sim, id: String) -> Dictionary:
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("id", "")) == id:
			return feature
	return {}

func run(game) -> void:
	var database = game.sim.database
	for character_id: String in ["traveler", "hero_01", "hero_02", "hero_06"]:
		var actual_name := str(database.characters[character_id].name)
		var related: Array = database.cards.filter(func(card: Dictionary) -> bool: return str(card.get("character_id", "")) == character_id)
		expect(not related.is_empty(), actual_name + " has linked reward cards")
		for card: Dictionary in related:
			expect(str(card.get("character_name", "")) == actual_name, str(card.id) + " resolves the live character name")
			expect(str(card.get("description", "")).begins_with(actual_name), str(card.id) + " description no longer keeps a legacy name")

	var campaign_squad: Array[String] = ["traveler", "hero_01", "hero_02"]
	game.sim.reset_stage("stage_01", campaign_squad, 5001)
	for hero: Dictionary in game.sim.heroes:
		var character: Dictionary = database.characters.get(str(hero.character_id), {})
		var asset: Dictionary = database.assets.get(str(character.get("asset_key", "")), {})
		var portrait: Texture2D = game.hud.portrait_texture(hero, game.sim)
		expect(portrait != null and str(portrait.resource_path) == str(asset.get("portrait", "")), str(hero.name) + " HUD portrait uses the asset manifest")
	var amiya_hero := {"character_id":"hero_06", "tile":Vector2.ZERO}
	var amiya_asset: Dictionary = database.assets.get(str(database.characters.hero_06.asset_key), {})
	var amiya_portrait: Texture2D = game.hud.portrait_texture(amiya_hero, game.sim)
	expect(amiya_portrait != null and str(amiya_portrait.resource_path) == str(amiya_asset.get("portrait", "")), "阿米娅 HUD portrait uses the asset manifest")
	expect(game.hud.hero_hp_bars.all(func(bar: ProgressBar) -> bool: return bar.size.x <= 96.0), "bottom HUD health bars are compact")
	expect(game.hud.hero_energy_bars.all(func(bar: ProgressBar) -> bool: return bar.size.x <= 96.0), "bottom HUD energy bars are compact")
	expect(game.hud.UI_LAYOUT.battle_right_shell_rect.position.y >= 580.0, "party command deck moved from the right edge to the bottom")
	expect(game.hud.UI_LAYOUT.battle_hero_card_gap.x > 0.0 and game.hud.UI_LAYOUT.battle_hero_card_gap.y == 0.0, "three character cards are laid out horizontally")
	expect(game.hud.UI_LAYOUT.battle_playfield_rect.size.x >= 1240.0, "battle map uses nearly the full screen width")
	expect(int(ProjectSettings.get_setting("display/window/size/window_width_override")) == 1920 and int(ProjectSettings.get_setting("display/window/size/window_height_override")) == 1080, "desktop output is fixed to 1920x1080")

	var endless_squad: Array[String] = ["traveler", "hero_01", "hero_02"]
	game.sim.reset_stage("stage_endless", endless_squad, 5002)
	game.sim.start()
	game.selected_id = 0
	game.battle.camera_center = game.sim.ENDLESS_ARENA.get_center()
	expect(game.sim.heroes.all(func(hero: Dictionary) -> bool: return not game.sim._terrain_blocks(hero.pos, 17.0)), "endless party spawns outside every wall and door")
	var walls: Array = game.sim.terrain_features.filter(func(feature: Dictionary) -> bool: return str(feature.get("type", "")) == "blocked")
	var doors: Array = game.sim.terrain_features.filter(func(feature: Dictionary) -> bool: return str(feature.get("type", "")) == "door")
	var junctions: Array = game.sim.terrain_features.filter(func(feature: Dictionary) -> bool: return str(feature.get("type", "")) == "junction")
	expect(walls.size() >= 12, "endless arena contains a wall network")
	expect(doors.size() == 4, "endless arena contains four independent breakable doors")
	expect(junctions.any(func(feature: Dictionary) -> bool: return str(feature.get("layout", "")) == "t"), "endless arena contains a T junction")
	expect(junctions.any(func(feature: Dictionary) -> bool: return str(feature.get("layout", "")) == "cross"), "endless arena contains a cross junction")
	expect(junctions.any(func(feature: Dictionary) -> bool: return str(feature.get("layout", "")) == "dual"), "endless arena contains a two-way junction")

	var west_wall := _feature(game.sim, "endless_west_wall_upper")
	var start := Vector2(500, 500)
	var finish := Vector2(800, 500)
	expect(not west_wall.is_empty() and game.sim.terrain_line_blocked(start, finish, 17.0), "wall blocks movement and ground attack lines")
	var moved: Vector2 = game.sim._move_with_terrain(start, finish, 300.0, 17.0)
	expect(not game.sim._terrain_blocks(moved, 17.0) and (moved.x < 583.0 or moved.y < 313.0 or moved.y > 657.0), "ground movement cannot jump through a wall")

	var west_gate := _feature(game.sim, "endless_west_gate")
	var gate_center: Vector2 = west_gate.area.get_center()
	expect(game.sim._terrain_blocks(gate_center), "closed door blocks passage")
	for strike in 3:
		game.sim.damage_terrain_shortcuts(gate_center, 90.0, 240.0)
	expect(float(west_gate.hp) <= 0.0 and not game.sim._terrain_blocks(gate_center), "three skill-strength hits destroy a 720 HP door and open the passage")

	game.sim.enemies.clear()
	game.sim.heroes[0].pos = finish
	game.sim.heroes[0].target = finish
	var ground: Dictionary = game.sim.spawn_enemy(start, "ranged")
	ground.attack_range = 500.0
	ground.attack_timer = 0.0
	game.sim._enemy_tick(0.016)
	expect(not bool(ground.get("attack_pending", false)), "ground ranged enemy cannot target through a wall")
	game.sim.enemies.clear()
	var flyer: Dictionary = game.sim.spawn_enemy(start, "flyer")
	flyer.attack_range = 500.0
	flyer.attack_timer = 0.0
	game.sim._enemy_tick(0.016)
	expect(bool(flyer.get("attack_pending", false)), "flying enemy ignores wall line of sight")

	await capture(game, "endless-junctions-bottom-hud")
	print("V50 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
