extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("KINDRED: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	game.sim.reset_stage("stage_03", squad, 7303)
	check(str(game.sim.stage_runtime.definition.get("boss_id", "")) == "boss_03", "stage_03 boss mapping")
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	var positions: Array[Vector2] = [Vector2(720,350),Vector2(540,280),Vector2(610,430)]
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = positions[index]
		hero.target = hero.pos
		hero.hp = 1000.0
		hero.max_hp = 1000.0
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(930,355),"boss_03")
	boss.shield = 0.0
	boss.boss_phase = 3
	game.sim.drain_events()
	game.sim._start_kindred_warning(boss,"kindred_dance")
	game.sim._execute_kindred_special(boss,"kindred_dance")
	check(game.sim.enemy_projectiles.size() == 12, "dance four-arrow volleys against three heroes")
	game.sim.enemy_projectiles.clear()
	game.sim._start_kindred_warning(boss,"kindred_wolf")
	game.sim._execute_kindred_special(boss,"kindred_wolf")
	check(game.sim.enemy_hazards.any(func(h: Dictionary) -> bool: return str(h.kind) == "kindred_wolf_zone"), "wolf zone")
	game.sim.enemy_hazards.clear()
	game.sim._start_kindred_warning(boss,"kindred_dread")
	game.sim._execute_kindred_special(boss,"kindred_dread")
	check(game.sim.enemy_projectiles.size() == 3, "dread triple shot")
	game.sim.enemy_projectiles.clear()
	game.sim._start_kindred_warning(boss,"kindred_hunt")
	game.sim._execute_kindred_special(boss,"kindred_hunt")
	check(game.sim.enemy_projectiles.size() >= 28, "hunt pressure volley")
	game.sim.enemy_projectiles.clear()
	game.sim.heroes[0].pos = Vector2(boss.pos) + Vector2(-80.0, 0.0)
	game.sim.heroes[0].target = game.sim.heroes[0].pos
	boss.kindred_respite_used = false
	boss.kindred_respite_active = false
	boss.hp = 2.0
	game.sim.apply_hit(boss,999999.0,"pyro",0)
	check(bool(boss.kindred_respite_active),"respite activates")
	check(is_equal_approx(float(boss.hp),1.0),"boss stays at one")
	game.sim.damage_hero(0,999999.0)
	check(is_equal_approx(float(game.sim.heroes[0].hp),1.0),"hero cannot die in respite")
	game.sim._tick_kindred_respite(boss,5.1)
	check(not bool(boss.kindred_respite_active),"respite ends")
	check(float(boss.hp)>=float(boss.max_hp)*0.49,"boss heals 50 percent")
	check(float(game.sim.heroes[0].hp)>=500.0,"hero heals 50 percent")
	var boss_style: StyleBoxFlat = game.hud.boss_panel.get_theme_stylebox("panel")
	var warning_style: StyleBoxFlat = game.hud.boss_skill_warning_panel.get_theme_stylebox("panel")
	check(boss_style.bg_color.a < 0.85,"boss bar background is translucent")
	check(warning_style.bg_color.a < 0.85,"skill warning background is translucent")
	check(game.hud.boss_skill_warning_title.get_theme_font_size("font_size") >= 26,"skill warning uses large font")
	if failures.is_empty():
		print("KINDRED LOGIC PASS: stage+4 skills+respite+HUD")
		quit(0)
	else:
		print("KINDRED LOGIC FAILURES: ", failures)
		quit(1)
