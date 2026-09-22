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
	var directory := ProjectSettings.globalize_path("res://../outputs/crossfire-preview")
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
	var squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_02", squad, 3174)
	game.sim.start()
	game.sim.heroes[0].deployed = true
	game.sim.heroes[0].pos = Vector2(410, 380)
	game.sim.heroes[0].target = Vector2(410, 380)
	var positions: Array[Vector2] = [Vector2(785, 370), Vector2(840, 385), Vector2(805, 480), Vector2(1000, 425)]
	for position: Vector2 in positions:
		var enemy: Dictionary = game.sim.spawn_enemy(position, "grunt")
		enemy.pos = position
		enemy.hp = 10000.0
		enemy.max_hp = 10000.0
	game.sim.drain_events()
	game.sim.supports = {"support_crossfire":{"stacks":1,"timer":0.85,"power":42.0,"interval":12.0,"radius":100.0}}
	game.refresh()
	for frame in 13:
		game.sim.supports["support_crossfire"].timer = 0.84 - frame / 15.0
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame):
			quit(1)
			return
	game.sim._trigger_support("support_crossfire", game.sim.supports["support_crossfire"])
	var events: Array[Dictionary] = game.sim.drain_events()
	game.battle.accept_events(events)
	game.sim.supports["support_crossfire"].timer = 12.0
	if not events.any(func(event: Dictionary) -> bool: return event.kind == "crossfire" and is_equal_approx(float(event.lane_half_width), 58.0)):
		push_error("Crossfire visual event misses its actual lane width")
		quit(1)
		return
	if not (game.sim.enemies[0].hp < 10000.0 and game.sim.enemies[1].hp < 10000.0 and is_equal_approx(float(game.sim.enemies[2].hp), 10000.0) and game.sim.enemies[3].hp < 10000.0):
		push_error("Crossfire damage does not match its warning lane")
		quit(1)
		return
	for frame in 18:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame + 13):
			quit(1)
			return
	print("CROSSFIRE PREVIEW: saved 31 frames; lane damage checked")
	quit(0)
