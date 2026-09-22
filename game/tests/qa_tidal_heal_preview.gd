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
	var directory := ProjectSettings.globalize_path("res://../outputs/tidal-heal-preview")
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
	var squad: Array[String] = ["traveler", "hero_04"]
	game.sim.reset_stage("stage_02", squad, 3174)
	game.sim.start()
	for index in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[index]
		hero.deployed = true
		hero.pos = Vector2(420.0 + index * 300.0, 360.0 + index * 55.0)
		hero.target = hero.pos
		hero.hp = maxf(1.0, hero.max_hp - 100.0)
	game.sim.base_hp = 3
	game.sim.drain_events()
	game.sim.supports = {"support_heal":{"stacks":1,"timer":0.65,"power":24.0,"interval":10.0,"radius":100.0}}
	game.refresh()
	for frame in 10:
		game.sim.supports["support_heal"].timer = 0.64 - frame / 15.0
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame):
			quit(1)
			return
	var before_hp: Array[float] = []
	for hero: Dictionary in game.sim.heroes:
		before_hp.append(float(hero.hp))
	var before_base: int = game.sim.base_hp
	game.sim._trigger_support("support_heal", game.sim.supports["support_heal"])
	var events: Array[Dictionary] = game.sim.drain_events()
	game.battle.accept_events(events)
	game.sim.supports["support_heal"].timer = 10.0
	if not events.any(func(event: Dictionary) -> bool: return event.kind == "support_heal" and event.hero_ids.size() == 2):
		push_error("Tidal heal visual event misses healed deployed heroes")
		quit(1)
		return
	if game.sim.base_hp != before_base + 9:
		push_error("Tidal heal did not repair the base")
		quit(1)
		return
	for index in game.sim.heroes.size():
		if float(game.sim.heroes[index].hp) < before_hp[index] + 23.9:
			push_error("Tidal heal did not heal a deployed hero")
			quit(1)
			return
	for frame in 22:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame + 10):
			quit(1)
			return
	print("TIDAL HEAL PREVIEW: saved 32 frames; hero and base heal checked")
	quit(0)
