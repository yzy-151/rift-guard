extends SceneTree

const MainScene = preload("res://main.tscn")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("GALIO RUNTIME PASS: " + message)
	else:
		failures += 1
		push_error("GALIO RUNTIME FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	check(["galio_entrance", "galio_punch", "galio_winds", "galio_durand"].all(
		func(skill_id: String) -> bool:
			return game.boss_skill_sounds.has(skill_id) and game.boss_skill_sounds[skill_id].stream != null
	), "four Galio moves own playable audio mappings")
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	game.sim.reset_stage("stage_03", squad, 92275)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var kindred: Dictionary = game.sim.spawn_enemy(Vector2(900, 330), "boss_03")
	var galio: Dictionary = game.sim.spawn_enemy(Vector2(1020, 390), "boss_galio")
	kindred.shield = float(kindred.max_hp) * 0.3
	galio.shield = float(galio.max_shield)
	galio.galio_revealed = false
	game.hud.refresh_boss(game.sim)
	check(not game.hud.boss_secondary_hp_bar.visible and "DUAL TARGET" not in game.hud.boss_name_label.text, "Galio health bar stays hidden before landing")
	galio.galio_revealed = true
	game.hud.refresh_boss(game.sim)
	check(game.hud.boss_secondary_hp_bar.visible, "dual-boss HUD exposes the second health bar after landing")
	check(game.hud.boss_hp_bar.size.x < game.hud.UI_LAYOUT.battle_boss_bar_rect.size.x and game.hud.boss_secondary_hp_bar.size.x == game.hud.boss_hp_bar.size.x, "dual-boss health bars split the available width evenly")
	check(game.hud.boss_shield_bar.visible and game.hud.boss_secondary_shield_bar.visible, "both active boss shields remain visible")
	check("DUAL TARGET" in game.hud.boss_name_label.text and "K " in game.hud.boss_hp_label.text and "G " in game.hud.boss_hp_label.text, "dual-boss labels identify both targets")
	print("GALIO RUNTIME QA COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
