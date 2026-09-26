extends SceneTree

const MainScene = preload("res://main.tscn")
const SIM_FPS := 24.0
const CAPTURE_EVERY := 2
const OUTPUT_ROOT := "res://../outputs/galio-boss-showcase-v3-audio/"

var capture_index := 0
const BossAudio = preload("res://scripts/boss_audio_profile.gd")
var audio_events: Array[Dictionary] = []
var record_time := 0.0

func _accept_events(game: Node) -> void:
	var batch: Array[Dictionary] = game.sim.drain_events()
	for event: Dictionary in batch:
		var profile := BossAudio.describe(event)
		if not profile.is_empty():
			profile["time"] = record_time
			audio_events.append(profile)
	game.battle.accept_events(batch)

func _save_manifest() -> void:
	var file := FileAccess.open(OUTPUT_ROOT + "audio-events.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(audio_events))
	file.close()
	file = FileAccess.open(OUTPUT_ROOT + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(skill_ranges))
	file.close()


var skill_ranges: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node) -> bool:
	# Keep the gameplay recording readable; titles are added to the exported GIFs.
	game.hud.boss_skill_warning_panel.hide()
	game.battle.queue_redraw()
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	image.resize(1024, 576, Image.INTERPOLATE_LANCZOS)
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
	if move == "galio_entrance":
		kindred.pos = Vector2(820, 390)
	elif move == "galio_durand":
		for index in game.sim.heroes.size():
			game.sim.heroes[index].pos = Vector2(790 + index * 58, 360 + index * 38)
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
	var start_index := capture_index
	for frame in frames:
		record_time = start_index / 12.0 + frame / SIM_FPS
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
		_accept_events(game)
		game.battle.advance(dt)
		game.refresh()
		if frame % CAPTURE_EVERY == 0 and not await _capture(game):
			return false
	skill_ranges.append({"id":move,"start":start_index,"end":capture_index})
	print("GALIO GIF FRAMES: %s resolved=%s start=%d end=%d" % [move, resolved, start_index, capture_index])
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
	for spec in [["galio_entrance", 2.10], ["galio_punch", 1.45], ["galio_winds", 6.20], ["galio_durand", 1.90]]:
		if not await _record_skill(game, galio, kindred, str(spec[0]), float(spec[1])):
			quit(1)
			return
	_save_manifest()
	var manifest := FileAccess.open(OUTPUT_ROOT + "manifest.json", FileAccess.WRITE)
	manifest.store_string(JSON.stringify(skill_ranges))
	manifest.close()
	print("GALIO GIF CAPTURE COMPLETE frames=%d" % capture_index)
	quit(0)
