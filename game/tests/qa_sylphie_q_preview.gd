extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node, index: int) -> bool:
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	var directory := ProjectSettings.globalize_path("res://../outputs/sylphie-q-preview")
	DirAccess.make_dir_recursive_absolute(directory)
	return image.save_png(directory.path_join("frame-%02d.png" % index)) == OK

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
	var squad: Array[String] = ["hero_02", "traveler", "hero_03"]
	game.sim.reset_stage("stage_02", squad, 2718)
	game.sim.start()
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = [Vector2(515.0, 380.0), Vector2(610.0, 403.0), Vector2(525.0, 480.0)][index]
		hero.target = hero.pos
		hero.hp = hero.max_hp - 100.0
	game.sim.drain_events()
	game.refresh()
	var before_hp: Array[float] = []
	var before_speed: Array[float] = []
	for hero: Dictionary in game.sim.heroes:
		before_hp.append(float(hero.hp))
		before_speed.append(float(hero.speed))
	if not game.sim.activate_hero_skill(0, Vector2(1100.0, 540.0)):
		push_error("Sylphie Q could not cast")
		quit(1)
		return
	game.battle.accept_events(game.sim.drain_events())
	for frame in 5:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame):
			quit(1)
			return
	game.sim._pending_impact_tick(0.35)
	var events: Array[Dictionary] = game.sim.drain_events()
	game.battle.accept_events(events)
	if not events.any(func(event: Dictionary) -> bool: return event.kind == "skill_impact" and event.ability_kind == "heal_gust" and Vector2(event.pos).distance_to(game.sim.heroes[0].pos) < 0.1):
		push_error("Sylphie Q effect did not originate at her feet")
		quit(1)
		return
	for index in game.sim.heroes.size():
		var healed := float(game.sim.heroes[index].hp) > before_hp[index]
		if healed != (index < 2) or float(game.sim.heroes[index].speed) <= before_speed[index]:
			push_error("Sylphie Q healing did not match its ellipse or team speed effect")
			quit(1)
			return
	for frame in 20:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame + 5):
			quit(1)
			return
	print("SYLPHIE Q PREVIEW: saved 25 frames; heal, speed, and origin checked")
	quit(0)
