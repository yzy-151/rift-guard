extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node, name: String) -> void:
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	var directory := ProjectSettings.globalize_path("res://../outputs/red-moon-preview")
	DirAccess.make_dir_recursive_absolute(directory)
	if image == null or image.save_png(directory.path_join(name + ".png")) != OK:
		push_error("Could not capture red moon preview: " + name)

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
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_02", squad, 7194)
	game.sim.start()
	game.sim.heroes[0].deployed = true
	game.sim.heroes[0].pos = Vector2(410, 380)
	game.sim.heroes[0].target = Vector2(410, 380)
	var positions: Array[Vector2] = [Vector2(785, 370), Vector2(840, 365), Vector2(805, 425), Vector2(880, 415)]
	for position: Vector2 in positions:
		var enemy: Dictionary = game.sim.spawn_enemy(position, "grunt")
		enemy.pos = position
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
	game.sim.drain_events()
	game.sim.supports = {"support_barrage":{"stacks":1,"timer":1.35,"power":70.0,"interval":8.0,"radius":105.0}}
	game.refresh()
	for frame in 20:
		game.sim.supports["support_barrage"].timer = 1.34 - frame / 15.0
		game.battle.advance(1.0 / 15.0)
		await _capture(game, "frame-%02d" % frame)
	game.sim._trigger_support("support_barrage", game.sim.supports["support_barrage"])
	var events: Array[Dictionary] = game.sim.drain_events()
	game.battle.accept_events(events)
	game.sim.supports["support_barrage"].timer = 8.0
	if not events.any(func(event: Dictionary) -> bool: return event.kind == "barrage" and is_equal_approx(float(event.radius), 105.0)):
		push_error("Red moon barrage event does not carry card radius")
		quit(1)
		return
	if not (game.sim.enemies[0].hp < 10000.0 and game.sim.enemies[1].hp < 10000.0 and is_equal_approx(float(game.sim.enemies[2].hp), 10000.0) and is_equal_approx(float(game.sim.enemies[3].hp), 10000.0)):
		push_error("Red moon damage does not match its projected ellipse")
		quit(1)
		return
	for frame in 24:
		game.battle.advance(1.0 / 15.0)
		await _capture(game, "frame-%02d" % (frame + 20))
	game.sim._trigger_support("support_barrage", game.sim.supports["support_barrage"])
	game.battle.accept_events(game.sim.drain_events())
	game.battle.advance(0.35)
	game.battle.reduced_effects = true
	await _capture(game, "reduced-effects")
	print("RED MOON PREVIEW: saved 44 frames and reduced-effects frame")
	quit(0)
