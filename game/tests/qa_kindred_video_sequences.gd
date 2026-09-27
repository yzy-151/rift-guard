extends SceneTree

const MainScene = preload("res://main.tscn")
const SIM_FPS := 24.0
const CAPTURE_EVERY := 1
const OUTPUT_ROOT := "res://../outputs/boss-video-import/kindred/"
var capture_index := 0
const BossAudio = preload("res://scripts/boss_audio_profile.gd")
var audio_events: Array[Dictionary] = []
var skill_ranges: Array[Dictionary] = []
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



func _initialize() -> void:
	call_deferred("_run")

func _assert_true(value: bool, message: String) -> void:
	if not value:
		push_error("KINDRED ASSERT: " + message)
		quit(1)

func _capture(game: Node) -> bool:
	game.hud.boss_skill_warning_panel.hide()
	game.battle.queue_redraw()
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
	var directory := ProjectSettings.globalize_path(OUTPUT_ROOT + "frames")
	DirAccess.make_dir_recursive_absolute(directory)
	var result := image.save_png(directory.path_join("frame-%04d.png" % capture_index)) == OK
	capture_index += 1
	return result

func _record_skill(game: Node, boss: Dictionary, move: String, tail: float) -> bool:
	var start_index := capture_index
	game.battle.effects.clear()
	game.sim.enemy_projectiles.clear()
	game.sim.enemy_hazards.clear()
	game.sim.drain_events()
	game.sim._start_kindred_warning(boss, move)
	boss.special_pending = true
	boss.special_move = move
	game.hud.announce_boss_skill_warning(str(boss.special_move_name), float(boss.special_warning_total), int(boss.boss_phase))
	var frames := ceili((float(boss.special_warning_total) + tail) * SIM_FPS)
	for frame in frames:
		record_time = start_index / 12.0 + frame / SIM_FPS
		var dt := 1.0 / SIM_FPS
		if bool(boss.special_pending):
			boss.special_warning = float(boss.special_warning) - dt
			if float(boss.special_warning) <= 0.0:
				boss.special_pending = false
				game.sim._execute_kindred_special(boss, move)
		else:
			game.sim._enemy_projectile_tick(dt)
			game.sim._enemy_hazard_tick(dt)
		_accept_events(game)
		game.battle.advance(dt)
		game.refresh()
		if frame % CAPTURE_EVERY == 0 and not await _capture(game):
			return false
	skill_ranges.append({"id":move,"start":start_index,"end":capture_index})
	return true

func _record_respite(game: Node, boss: Dictionary) -> bool:
	var start_index := capture_index
	record_time = start_index / 12.0
	# Isolate the passive for review; reinforcement gameplay is covered separately.
	boss.galio_summoned = true
	boss.pos = Vector2(810, 355)
	game.sim.enemy_projectiles.clear()
	game.sim.enemy_hazards.clear()
	game.battle.effects.clear()
	game.sim.drain_events()
	game.sim.heroes[0].pos = Vector2(boss.pos) + Vector2(-80.0, 0.0)
	game.sim.heroes[0].target = game.sim.heroes[0].pos
	boss.kindred_respite_used = false
	boss.kindred_respite_active = false
	boss.hp = 2.0
	boss.shield = 0.0
	for hero: Dictionary in game.sim.heroes:
		hero.hp = 180.0
		hero.max_hp = 1000.0
	game.sim.apply_hit(boss, 999999.0, "pyro", 0)
	_assert_true(bool(boss.kindred_respite_active), "passive did not activate")
	_assert_true(is_equal_approx(float(boss.hp), 1.0), "boss was not clamped to 1 HP")
	game.sim.damage_hero(0, 999999.0)
	_assert_true(is_equal_approx(float(game.sim.heroes[0].hp), 1.0), "hero inside respite was not protected")
	_accept_events(game)
	game.hud.announce_boss_skill_warning("羊灵生息", 5.0, 3)
	var frames := ceili(6.15 * SIM_FPS)
	for frame in frames:
		record_time = start_index / 12.0 + frame / SIM_FPS
		var dt := 1.0 / SIM_FPS
		game.sim._tick_kindred_respite(boss, dt)
		_accept_events(game)
		game.battle.advance(dt)
		game.refresh()
		if frame % CAPTURE_EVERY == 0 and not await _capture(game):
			return false
	_assert_true(not bool(boss.kindred_respite_active), "passive did not finish")
	_assert_true(float(boss.hp) >= float(boss.max_hp) * 0.49, "boss did not heal 50 percent")
	_assert_true(float(game.sim.heroes[0].hp) >= 500.0, "protected hero did not heal 50 percent")
	skill_ranges.append({"id":"kindred_respite","start":start_index,"end":capture_index})
	return true

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
	game.sim.reset_stage("stage_03", squad, 7303)
	_assert_true(str(game.sim.stage_runtime.definition.get("boss_id", "")) == "boss_03", "stage_03 does not use boss_03")
	game.sim.start()
	game.sim.terrain_features.clear()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var hero_positions: Array[Vector2] = [Vector2(705, 350), Vector2(530, 275), Vector2(600, 435)]
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = hero_positions[index]
		hero.target = hero.pos
		hero.hp = 10000.0
		hero.max_hp = 10000.0
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(930, 355), "boss_03")
	boss.hp = float(boss.max_hp) * 0.30
	boss.damage = 165.0
	boss.boss_phase = 3
	boss.attack_timer = 999.0
	boss.special_timer = 999.0
	game.sim.drain_events()
	for spec in [["kindred_dance", 1.55], ["kindred_wolf", 6.1], ["kindred_dread", 1.80], ["kindred_hunt", 2.40]]:
		if not await _record_skill(game, boss, str(spec[0]), float(spec[1])):
			quit(1)
			return
	if not await _record_respite(game, boss):
		quit(1)
		return
	_save_manifest()
	print("KINDRED FOCUS PASS frames=%d" % capture_index)
	quit(0)
