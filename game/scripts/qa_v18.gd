extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V18 PASS: " + message)
	else:
		failures += 1
		push_error("V18 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.6).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v18-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.mode_select_panel.close()
	var traveler_squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01", traveler_squad, 1818)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.events.clear()
	game.sim.heroes[0].element = "pyro"
	game.sim.heroes[0].pos = Vector2(455, 365)
	game.sim.heroes[0].target = game.sim.heroes[0].pos
	var enemy_a: Dictionary = game.sim.spawn_enemy(Vector2(745, 330), "grunt")
	var enemy_b: Dictionary = game.sim.spawn_enemy(Vector2(805, 402), "runner")
	var enemy_c: Dictionary = game.sim.spawn_enemy(Vector2(910, 355), "charger")
	for enemy in [enemy_a, enemy_b, enemy_c]:
		enemy.hp *= 4.0
		enemy.max_hp = enemy.hp
	game.battle.projectile_trails.clear()
	for index in 5:
		var projectile := {"visual_id": 900 + index, "pos": Vector2(505 + index * 38, 350 + index * 9), "target_id": enemy_a.id, "element": ["pyro", "hydro", "electro", "cryo", "anemo"][index], "source_id": 0, "critical": index == 2}
		game.sim.projectiles.append(projectile)
		game.battle.projectile_trails[900 + index] = [projectile.pos - Vector2(105, 18), projectile.pos - Vector2(68, 12), projectile.pos - Vector2(32, 6), projectile.pos]
	var preview_events: Array[Dictionary] = [
		{"kind": "shot", "pos": game.sim.heroes[0].pos, "hero_id": 0},
		{"kind": "hit", "pos": enemy_a.pos + Vector2(0, -18), "value": 248, "element": "pyro"},
		{"kind": "critical", "pos": enemy_b.pos + Vector2(0, -18), "value": 516},
	]
	game.battle.accept_events(preview_events)
	game.refresh()
	expect(game.battle.traveler_idle_atlas != null and game.battle.traveler_attack_atlas != null, "traveler high-resolution atlases are loaded")
	expect(game.battle.hilichurl_run_atlas != null, "monster run atlas is loaded")
	expect(game.battle.hero_attack_visuals.has(0), "shot event starts traveler attack recovery animation")
	expect(game.battle.projectile_trails.size() == 5, "five independent projectile trails are retained")
	expect(game.battle.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS, "battle art uses smooth non-pixel filtering")
	await capture(game, "01-traveler-monster-projectile-vfx")

	game.sim.reset_stage("stage_endless", traveler_squad, 1819)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.heroes[0].pos = game.sim.ENDLESS_ARENA.get_center()
	game.battle.camera_center = game.sim.heroes[0].pos
	for i in 12:
		game.sim.spawn_enemy(game.sim.heroes[0].pos + Vector2.from_angle(i * TAU / 12.0) * (220 + i * 12), "grunt" if i % 3 else "runner")
	game.refresh()
	expect(game.sim.endless_mode and game.sim.enemies.size() == 12, "beautified endless arena renders a surrounding animated enemy group")
	await capture(game, "02-endless-arena-animation-density")

	print("V18 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
