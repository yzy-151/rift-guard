extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V19 PASS: " + message)
	else:
		failures += 1
		push_error("V19 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.22).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v19-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01", squad, 1919)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.events.clear()
	var traveler: Dictionary = game.sim.heroes[0]
	traveler.element = "pyro"
	traveler.pos = Vector2(420, 370)
	traveler.target = traveler.pos
	var target: Dictionary = game.sim.spawn_enemy(Vector2(570, 370), "grunt")
	target.hp *= 10.0
	target.max_hp = target.hp
	game.sim._hero_tick()
	expect(game.sim.events.any(func(event: Dictionary) -> bool: return event.kind == "slash" and event.get("element", "") == "pyro"), "melee attacks emit directional elemental slash events")
	expect(float(traveler.facing) > 0.0, "traveler faces the target when attacking")
	game.battle.accept_events(game.sim.drain_events())
	var showcase: Array[Dictionary] = [
		{"kind": "skill_pyro", "pos": Vector2(665, 330)},
		{"kind": "slash", "pos": Vector2(590, 400), "angle": -0.18, "element": "pyro", "critical": true},
		{"kind": "hit", "pos": Vector2(590, 400), "value": 428, "element": "pyro"},
	]
	game.battle.accept_events(showcase)
	expect(game.battle.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "skill_pyro" and is_equal_approx(float(effect.total), 1.05)), "element skills keep a long readable visual lifetime")
	expect(game.battle.effects.any(func(effect: Dictionary) -> bool: return effect.kind == "slash" and is_equal_approx(float(effect.total), 0.42)), "melee slash timing uses the dedicated fast impact window")
	await capture(game, "01-pyro-melee-skill-vfx")

	game.battle.effects.clear()
	var elements := ["none", "anemo", "electro", "hydro", "geo", "cryo"]
	var positions := [Vector2(330, 290), Vector2(600, 290), Vector2(870, 290), Vector2(330, 470), Vector2(600, 470), Vector2(870, 470)]
	var skill_events: Array[Dictionary] = []
	for index in elements.size():
		skill_events.append({"kind": "skill_" + elements[index], "pos": positions[index]})
	game.battle.accept_events(skill_events)
	expect(game.battle.effects.filter(func(effect: Dictionary) -> bool: return str(effect.kind).begins_with("skill_")).size() == 6, "six non-pyro skill families can render together")
	await capture(game, "02-seven-element-vfx-language")

	traveler.pos = Vector2(600, 360)
	game.sim.command_move(0, Vector2(410, 360))
	expect(float(traveler.facing) < 0.0, "hero faces left when commanded left")
	game.sim.command_move(0, Vector2(780, 360))
	expect(float(traveler.facing) > 0.0, "hero faces right when commanded right")
	game.sim.reset_stage("stage_endless", squad, 1920)
	game.sim.start()
	game.sim.enemies.clear()
	game.sim.heroes[0].pos = game.sim.ENDLESS_ARENA.get_center()
	var left_enemy: Dictionary = game.sim.spawn_enemy(game.sim.heroes[0].pos + Vector2(-260, 0), "grunt")
	game.sim._enemy_tick(0.05)
	expect(float(left_enemy.facing) > 0.0, "enemy faces right while pursuing from the left edge")
	var right_enemy: Dictionary = game.sim.spawn_enemy(game.sim.heroes[0].pos + Vector2(260, 0), "runner")
	game.sim._enemy_tick(0.05)
	expect(float(right_enemy.facing) < 0.0, "enemy faces left while pursuing from the right edge")

	for id: String in game.sim.database.characters:
		game.compendium.unlocked_characters[id] = true
	game.squad_panel.open("stage_02", squad, [])
	expect(game.squad_panel.buttons.size() == 12, "squad screen contains twelve independent character cards")
	expect(game.squad_panel.previews.size() == 12, "every character card contains a breathing preview")
	expect(int(game.squad_panel.previews["traveler"].atlas_frames) == 48, "traveler card plays the 48-frame breathing atlas")
	expect(int(game.squad_panel.previews["hero_03"].atlas_frames) == 8, "Furina card plays the available breathing atlas")
	var card_list: Array = game.squad_panel.buttons.values()
	var overlapping := false
	for a in card_list.size():
		for b in range(a + 1, card_list.size()):
			if card_list[a].get_global_rect().intersects(card_list[b].get_global_rect()):
				overlapping = true
	expect(not overlapping, "character cards do not overlap")
	game.squad_panel.toggle("hero_02")
	game.squad_panel.toggle("hero_03")
	expect(game.squad_panel.selected == ["traveler", "hero_02", "hero_03"], "selection remains clickable and respects the three-character limit")
	await capture(game, "03-character-selection-cards")

	print("V19 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
