extends SceneTree

const MainScene = preload("res://main.tscn")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, description: String) -> void:
	if not value:
		failures.append(description)
		push_error("VIDEO VFX FAIL: " + description)

func screenshot(game: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if name.begins_with("wind-live-") or name.begins_with("fire-live-"):
		image.resize(960, 540)
	var directory := ProjectSettings.globalize_path("res://../outputs/vfx-preview")
	DirAccess.make_dir_recursive_absolute(directory)
	check(image != null and image.save_png(directory.path_join(name + ".png")) == OK, name)

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
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_02", squad, 2409)
	game.sim.start()
	game.sim.heroes[0].deployed = true
	game.sim.heroes[0].element = "anemo"
	game.sim.heroes[0].pos = Vector2(390, 365)
	game.sim.heroes[0].target = Vector2(390, 365)
	game.refresh()
	await screenshot(game, "vfx-baseline")
	check(game.sim.activate_traveler_skill(Vector2(680, 365)), "wind skill activates")
	check(game.sim.skill_effects.size() == 1, "wind zone exists")
	var wind_monsters: Array[Dictionary] = []
	for position: Vector2 in [Vector2(690, 360), Vector2(750, 355), Vector2(810, 380)]:
		var monster: Dictionary = game.sim.spawn_enemy(position, "grunt")
		monster.pos = position
		monster.hp = 10000.0
		monster.max_hp = 10000.0
		wind_monsters.append(monster)
	var wind_start: Vector2 = game.sim.skill_effects[0].pos
	for frame in 46:
		game.sim._skill_effect_tick(1.0 / 12.0)
		game.battle.accept_events(game.sim.drain_events())
		game.battle.advance(1.0 / 12.0)
		await screenshot(game, "wind-live-%02d" % frame)
	check(is_equal_approx(game.sim.skill_effects[0].pos.x - wind_start.x, 26.0 * 46.0 / 12.0), "wind hitbox moves right at reduced speed")
	check(wind_monsters.any(func(monster: Dictionary) -> bool: return monster.hp < monster.max_hp and monster.pos.x > 690.0), "tornado actually damages and moves monsters")
	game.sim.skill_effects.clear()
	game.sim.enemies.clear()
	game.sim.enemy_lookup.clear()
	game.sim.drain_events()
	game.battle.advance(0.1)
	var support_card: Dictionary = {}
	for card: Dictionary in game.sim.database.cards:
		if str(card.get("id", "")) == "evolve_fireball":
			support_card = card
			break
	check(not support_card.is_empty() and support_card.get("name", "") == "天动万象" and "支援" in support_card.get("tags", []), "card is named and classified as off-field support")
	game.sim.run_state.buff_levels["evolve_fireball"] = 1
	game.sim.apply_v2_card_effect(support_card)
	check(game.sim.fireball_level == 1, "taking support card enables periodic skyfall")
	game.sim.meteor_timer = 0.0
	var enemy: Dictionary = game.sim.spawn_enemy(Vector2(830, 365), "grunt")
	var nearby: Dictionary = game.sim.spawn_enemy(Vector2(1000, 365), "grunt")
	var distant: Dictionary = game.sim.spawn_enemy(Vector2(1080, 365), "grunt")
	enemy.pos = Vector2(830, 365)
	nearby.pos = Vector2(1000, 365)
	distant.pos = Vector2(1080, 365)
	var near_hp := float(nearby.hp)
	var far_hp := float(distant.hp)
	await screenshot(game, "fireball-before")
	game.sim._evolution_tick(0.01)
	check(game.sim.pending_impacts.size() == 1, "off-field card schedules one skyfall")
	var fall_events: Array[Dictionary] = game.sim.drain_events()
	check(fall_events.any(func(event: Dictionary) -> bool: return event.get("kind", "") == "fireball_fall"), "skyfall starts before damage")
	game.battle.accept_events(fall_events)
	for frame in 28:
		game.sim._pending_impact_tick(1.0 / 12.0)
		var batch: Array[Dictionary] = game.sim.drain_events()
		game.battle.accept_events(batch)
		game.battle.advance(1.0 / 12.0)
		await screenshot(game, "fire-live-%02d" % frame)
		if frame == 4:
			check(is_equal_approx(float(nearby.hp), near_hp), "skyfall does not damage before landing")
	check(float(nearby.hp) < near_hp and is_equal_approx(float(distant.hp), far_hp), "support fireball damages only monsters in its radius")
	check(not game.battle.effects.any(func(effect: Dictionary) -> bool: return str(effect.get("kind", "")) == "fireball_impact"), "impact ends after the shortened 33-frame animation")
	print("VIDEO VFX QA COMPLETE: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

