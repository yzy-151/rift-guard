extends RefCounted

const Catalog = preload("res://scripts/combat_catalog.gd")
var checks := 0
var failures := 0
var output_dir := ""

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("V64 PASS: " + message)
	else:
		failures += 1
		push_error("V64 FAIL: " + message)

func capture(game, name: String) -> void:
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(0.12).timeout
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, name + " frame available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080): image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		expect(image.save_png(output_dir.path_join(name + ".png")) == OK, name + " screenshot written")

func run(game) -> void:
	output_dir = ProjectSettings.globalize_path("res://../docs/v64-validation")
	DirAccess.make_dir_recursive_absolute(output_dir)
	game.settings_panel.open({"master":0.82,"music":0.46,"sfx":0.90,"fullscreen":false,"reduced_effects":false})
	var texts: Array[String] = []
	for node in game.settings_panel.root.find_children("*", "Button", true, false): texts.append(str(node.text))
	expect(texts.size() == 2 and not texts.any(func(t: String) -> bool: return "全屏" in t or "恢复默认" in t), "settings keeps only two requested controls")
	expect(game.settings_panel.reduced_button.position.y == 344.0 and game.settings_panel.close_button.position.y == 344.0, "remaining settings controls occupy the former upper row")
	expect(game.hud.skill_button.clip_contents and game.hud.ultimate_button.clip_contents and game.hud.buff_panel.clip_contents, "ability and buff artwork is clipped to its UI region")
	expect(game.hud.skill_icon.size == Vector2(32, 32) and game.hud.ultimate_icon.size == Vector2(32, 32), "Q and E icons use compact fixed bounds")
	await capture(game, "01-settings")
	game.settings_panel.root.hide()
	var squad: Array[String] = ["traveler", "hero_01", "hero_07"]
	game.sim.reset_stage("stage_02", squad, 6401)
	var route: Array[Vector2] = game.sim.stage_route("main")
	var orthogonal: bool = route.size() > 2
	for i in range(1, route.size()):
		orthogonal = orthogonal and (is_equal_approx(route[i - 1].x, route[i].x) or is_equal_approx(route[i - 1].y, route[i].y))
		expect(fposmod(route[i].x - 70.0, 60.0) < 0.01 and fposmod(route[i].y - 160.0, 40.0) < 0.01, "route point %d is at grid center" % i)
	expect(orthogonal, "campaign route is horizontal/vertical only")
	var terrain_types: Array[String] = []
	var grid_aligned := true
	for feature: Dictionary in game.sim.terrain_features:
		terrain_types.append(str(feature.type))
		for cell: Rect2 in feature.get("grid_cells", []):
			grid_aligned = grid_aligned and cell.size == Vector2(60, 40) and fposmod(cell.position.x - 40.0, 60.0) < 0.01 and fposmod(cell.position.y - 140.0, 40.0) < 0.01
	expect(grid_aligned, "normal-stage terrain decals occupy exact 11-by-20 grid cells")
	expect(not terrain_types.any(func(k: String) -> bool: return k in ["door", "shortcut", "one_way", "moving_platform", "conveyor", "mechanism"]), "obsolete normal-stage objects removed")
	expect("attack_ground" in terrain_types and "high_ground" in terrain_types and "low_ground" in terrain_types and "trap" in terrain_types and "blocked" in terrain_types, "five tile mechanics are present")
	var spawned: Dictionary = game.sim.spawn_enemy(Vector2(1150, 360), "grunt")
	var expected_hp := float(Catalog.ENEMIES.grunt.hp) * 1.40 * float(game.sim.stage_runtime.definition.enemy_health_multiplier)
	expect(is_equal_approx(float(spawned.max_hp), expected_hp), "all enemy base health increased by 40 percent")
	var high: Dictionary = game.sim.terrain_features.filter(func(f: Dictionary) -> bool: return str(f.type) == "high_ground")[0]
	var low: Dictionary = game.sim.terrain_features.filter(func(f: Dictionary) -> bool: return str(f.type) == "low_ground")[0]
	var attack: Dictionary = game.sim.terrain_features.filter(func(f: Dictionary) -> bool: return str(f.type) == "attack_ground")[0]
	expect(game.sim.terrain_movement_scale(low.area.get_center()) < 1.0, "low-ground tile slows units")
	expect(game.sim.terrain_attack_scale(attack.area.get_center()) > 1.0, "attack tile increases attack")
	game.sim.heroes[0].pos = Vector2(100, 200); game.sim.heroes[0].deployed = true
	var baseline_range: float = game.sim.attack_range_screen_radii(game.sim.heroes[0]).x
	game.sim.heroes[0].pos = high.area.get_center()
	expect(game.sim.attack_range_screen_radii(game.sim.heroes[0]).x > baseline_range, "high-ground tile increases range")
	game.sim.start(); game.sim.state = "running"
	for hero: Dictionary in game.sim.heroes: hero.deployed = true
	game.sim.supports = {"support_barrage":{"timer":12.8,"interval":18.0,"power":220.0,"radius":9999.0,"stacks":2},"support_heal":{"timer":7.4,"interval":14.0,"power":90.0,"radius":9999.0,"stacks":1}}
	for i in mini(15, game.sim.database.cards.size()): game.sim.run_state.buff_levels[str(game.sim.database.cards[i].id)] = 1 + i % 5
	game.hud.signature = ""; game.refresh(); game.hud.overlay.hide()
	await capture(game, "02-battle-hud")
	print("V64 QA COMPLETE: %d checks, %d failures -> %s" % [checks, failures, output_dir])
	game.get_tree().quit(failures)
