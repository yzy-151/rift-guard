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
	var directory := ProjectSettings.globalize_path("res://../outputs/skill-ellipse-preview")
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
	var squad: Array[String] = ["hero_02"]
	game.sim.reset_stage("stage_02", squad, 3881)
	game.sim.start()
	var hero: Dictionary = game.sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(500.0, 380.0)
	hero.target = hero.pos
	hero.energy = hero.max_energy
	var inside: Dictionary = game.sim.spawn_enemy(Vector2(835.0, 380.0), "grunt")
	var outside: Dictionary = game.sim.spawn_enemy(Vector2(740.0, 480.0), "grunt")
	inside.hp = 10000.0
	inside.max_hp = 10000.0
	outside.hp = 10000.0
	outside.max_hp = 10000.0
	game.sim.drain_events()
	game.refresh()
	if not game.sim.activate_hero_ultimate(0, Vector2(740.0, 380.0)):
		push_error("Area ultimate could not cast")
		quit(1)
		return
	game.battle.accept_events(game.sim.drain_events())
	for frame in 7:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame):
			quit(1)
			return
	game.sim._pending_impact_tick(0.70)
	game.battle.accept_events(game.sim.drain_events())
	if not (inside.hp < 10000.0 and is_equal_approx(float(outside.hp), 10000.0)):
		push_error("Area damage differs from ellipse shown in the preview")
		quit(1)
		return
	if not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return zone.kind == "anemo_domain"):
		push_error("Area skill zone was not created")
		quit(1)
		return
	var before_pulse: float = inside.hp
	game.sim._skill_effect_tick(0.85)
	game.battle.accept_events(game.sim.drain_events())
	if not (inside.hp < before_pulse and is_equal_approx(float(outside.hp), 10000.0)):
		push_error("Persistent skill zone damage differs from its ellipse")
		quit(1)
		return
	for frame in 14:
		game.battle.advance(1.0 / 15.0)
		if not await _capture(game, frame + 7):
			quit(1)
			return
	print("SKILL ELLIPSE PREVIEW: saved 21 frames; inner and outer enemy checked")
	quit(0)
