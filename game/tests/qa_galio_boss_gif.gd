extends SceneTree

const MainScene = preload("res://main.tscn")
const SIM_FPS := 24.0
const CAPTURE_EVERY := 2
const OUTPUT_ROOT := "res://../outputs/galio-boss-showcase-v1/"

var capture_index := 0

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node) -> bool:
	game.battle.queue_redraw()
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	image.resize(768, 432, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path(OUTPUT_ROOT + "frames")
	DirAccess.make_dir_recursive_absolute(directory)
	var result := image.save_png(directory.path_join("frame-%04d.png" % capture_index)) == OK
	capture_index += 1
	return result

func _reset_actors(game: Node, galio: Dictionary, kindred: Dictionary) -> void:
	var positions: Array[Vector2] = [Vector2(600, 350), Vector2(515, 265), Vector2(555, 455)]
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = positions[index]
		hero.target = hero.pos
		hero.hp = 12000.0
		hero.max_hp = 12000.0
		hero.invulnerable_timer = 0.0
	galio.pos = Vector2(960, 350)
	galio.hp = float(galio.max_hp) * 0.28
	galio.shield = 0.0
	galio.boss_phase = 3
	galio.attack_timer = 999.0
	galio.special_timer = 999.0
	kindred.pos = Vector2(1060, 235)
	kindred.hp = float(kindred.max_hp) * 0.09
	kindred.shield = float(kindred.max_hp) * 0.30
	kindred.attack_timer = 999.0
	kindred.special_timer = 999.0

func _record_skill(game: Node, galio: Dictionary, kindred: Dictionary, move: String, tail: float) -> bool:
	_reset_actors(game, galio, kindred)
	game.battle.effects.clear()
	game.sim.enemy_projectiles.clear()
	game.sim.enemy_hazards.clear()
	game.sim.drain_events()
	galio.galio_revealed = move != "galio_entrance"
	galio.galio_takeoff_pos = Vector2(galio.pos)
	game.sim._start_galio_warning(galio, move)
	galio.special_pending = true
	galio.special_move = move
	game.hud.announce_boss_skill_warning(str(galio.special_move_name), float(galio.special_warning_total), 3)
	var frames := ceili((float(galio.special_warning_total) + tail) * SIM_FPS)
	var resolved := false
	for frame in frames:
		var dt := 1.0 / SIM_FPS
		if bool(galio.special_pending):
			galio.special_warning = float(galio.special_warning) - dt
			if float(galio.special_warning) <= 0.0:
				galio.special_pending = false
				game.sim._execute_galio_special(galio, move)
				resolved = true
		else:
			game.sim._enemy_projectile_tick(dt)
			game.sim._enemy_hazard_tick(dt)
		game.battle.accept_events(game.sim.drain_events())
		game.battle.advance(dt)
		game.refresh()
		if frame % CAPTURE_EVERY == 0 and not await _capture(game):
			return false
	print("GALIO GIF FRAMES: %s resolved=%s" % [move, resolved])
	return resolved

func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	game.sim.reset_stage("stage_03", squad, 92276)
	game.sim.start()
	game.sim.terrain_features.clear()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var kindred: Dictionary = game.sim.spawn_enemy(Vector2(1060, 235), "boss_03")
	var galio: Dictionary = game.sim.spawn_enemy(Vector2(960, 350), "boss_galio")
	game.sim.drain_events()
	for spec in [["galio_entrance", 2.10], ["galio_punch", 1.45], ["galio_winds", 2.65], ["galio_durand", 1.90]]:
		if not await _record_skill(game, galio, kindred, str(spec[0]), float(spec[1])):
			quit(1)
			return
	print("GALIO GIF CAPTURE COMPLETE frames=%d" % capture_index)
	quit(0)
