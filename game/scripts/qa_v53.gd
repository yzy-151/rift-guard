extends RefCounted

const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V53 PASS: " + message)
	else:
		failures += 1
		push_error("V53 FAIL: " + message)

func run(game) -> void:
	expect(UI_LAYOUT.battle_timeline_rect.size.x <= 360.0, "wave forecast is a compact top badge")
	expect(UI_LAYOUT.battle_boss_bar_rect.size.y >= 12.0 and UI_LAYOUT.battle_boss_bar_rect.size.y <= 16.0, "boss bar is thicker but still compact")
	expect(UI_LAYOUT.battle_hero_hp_bar_size.x <= 72.0, "party health bars fit inside cards")
	expect(UI_LAYOUT.battle_hero_energy_bar_size.x <= 72.0, "party energy bars fit inside cards")
	expect(game.hud.hero_hp_bars[0].size.x <= 72.0, "party health bar runtime width is enforced after parenting")
	expect(game.hud.hero_energy_bars[0].size.x <= 72.0, "party energy bar runtime width is enforced after parenting")

	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	game.dialogue.hide()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	game.sim.reset_stage("stage_08", squad, 5301)
	game.sim.start()
	for hero: Dictionary in game.sim.heroes:
		hero.deployed = true
		hero.moving = false
	game.sim.enemies.clear()
	game.sim.events.clear()
	var hero: Dictionary = game.sim.heroes[0]
	var melee: Dictionary = game.sim.spawn_enemy(hero.pos + Vector2(28, 0), "grunt")
	game.sim.events.clear()
	game.sim._begin_enemy_warning(melee, hero)
	expect(game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "enemy_warning").is_empty(), "melee attacks keep windup without area telegraph")
	var ranged: Dictionary = game.sim.spawn_enemy(hero.pos + Vector2(210, 0), "ranged")
	game.sim.events.clear()
	game.sim._begin_enemy_warning(ranged, hero)
	expect(game.sim.events.filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "enemy_warning").size() == 1, "ranged attacks retain readable area telegraph")
	expect(float(ranged.get("attack_range", 999.0)) <= 235.0, "hilichurl archer range is reduced")

	game.sim.recent_spawn_kinds.clear()
	var balanced: Array[String] = []
	for i in 6:
		balanced.append(game.sim._balanced_spawn_kind("ranged"))
	var triple_stack := false
	for i in range(2, balanced.size()):
		triple_stack = triple_stack or (balanced[i] == balanced[i - 1] and balanced[i] == balanced[i - 2])
	expect(not triple_stack, "spawn composer prevents triple specialist stacks")

	var door := {"type": "door", "area": Rect2(600, 250, 48, 150), "hp": 60.0, "max_hp": 60.0}
	game.sim.terrain_features.clear()
	game.sim.terrain_features.append(door)
	melee.attack_timer = 0.0
	melee.damage = 20.0
	game.sim._attack_terrain_door(melee, door)
	expect(float(door.hp) == 40.0, "ground enemies attack closed doors instead of piling forever")

	game.sim.enemies.clear()
	for i in 60:
		game.sim.spawn_enemy(Vector2(800 + i, 360), "grunt")
	game.sim.events.clear()
	game.battle.effects.clear()
	var dense_events: Array[Dictionary] = [
		{"kind": "hit", "pos": Vector2(800, 360), "value": 10},
		{"kind": "hit", "pos": Vector2(830, 370), "value": 12}
	]
	game.battle.accept_events(dense_events)
	expect(game.battle.effects.size() == 1, "dense nearby impacts coalesce into one visual while simulation damage remains independent")

	game.sim.reset_stage("stage_08", squad, 5302)
	game.sim.start()
	for index in game.sim.heroes.size():
		game.sim.heroes[index].deployed = true
		game.sim.heroes[index].pos = Vector2(260 + index * 120, 350 + index * 35)
	game.refresh()
	game.battle.advance(0.0)
	await game.get_tree().create_timer(0.18).timeout
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var directory := ProjectSettings.globalize_path("res://../docs/v53-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var forecast_image: Image = game.get_viewport().get_texture().get_image()
	if forecast_image != null:
		if forecast_image.get_size() != Vector2i(1920, 1080):
			forecast_image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		expect(forecast_image.save_png(directory.path_join("battle-compact-forecast.png")) == OK, "compact wave forecast capture written")
	var boss: Dictionary = game.sim.spawn_enemy(Vector2(910, 350), "boss_04")
	boss.boss_phase = 2
	boss.hp = boss.max_hp * 0.72
	game.refresh()
	game.battle.advance(0.0)
	game.hud.announce_boss(str(boss.name))
	await game.get_tree().create_timer(0.20).timeout
	expect(game.hud.boss_alert_frame.visible and game.hud.boss_scene_tint.color.a > 0.0, "boss arrival uses framed alert and scene tint")
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null, "visual validation image is available")
	if image != null:
		if image.get_size() != Vector2i(1920, 1080):
			image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		DirAccess.make_dir_recursive_absolute(directory)
		expect(image.save_png(directory.path_join("battle-boss-hud.png")) == OK, "1920x1080 battle and boss HUD capture written")
	await game.get_tree().create_timer(1.30).timeout
	game.dialogue.show()
	expect(game.begin_dialogue("mode1_opening"), "dialogue validation scene opened")
	await game.get_tree().create_timer(0.22).timeout
	game.dialogue.advance()
	game.dialogue.advance()
	for frame in 90:
		await game.get_tree().process_frame
		if not game.dialogue.transition_texture.visible:
			break
	expect(not game.dialogue.transition_texture.visible, "dialogue transition clears before choice capture")
	expect(game.dialogue.body.visible_characters == -1, "dialogue text appears immediately without typewriter")
	expect(game.dialogue.choice_buttons.filter(func(item: Button) -> bool: return item.visible).size() == 2, "dialogue choices retain framed two-option layout")
	RenderingServer.force_draw()
	await game.get_tree().process_frame
	var dialogue_image: Image = game.get_viewport().get_texture().get_image()
	if dialogue_image != null:
		if dialogue_image.get_size() != Vector2i(1920, 1080):
			dialogue_image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
		expect(dialogue_image.save_png(directory.path_join("dialogue-instant-choice.png")) == OK, "dialogue choice capture written")
	print("V53 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
