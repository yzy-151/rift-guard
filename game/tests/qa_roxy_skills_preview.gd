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
	var directory := ProjectSettings.globalize_path("res://../outputs/roxy-skills-preview")
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
	var squad: Array[String] = ["hero_04", "traveler"]
	game.sim.reset_stage("stage_02", squad, 6103)
	game.sim.start()
	var roxy: Dictionary = game.sim.heroes[0]
	var ally: Dictionary = game.sim.heroes[1]
	roxy.deployed = true
	roxy.pos = Vector2(500.0, 375.0)
	roxy.target = roxy.pos
	ally.deployed = true
	ally.pos = Vector2(765.0, 370.0)
	ally.target = ally.pos
	ally.hp = ally.max_hp - 150.0
	var target := Vector2(765.0, 370.0)
	var enemy: Dictionary = game.sim.spawn_enemy(target, "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	game.sim.drain_events()
	game.refresh()
	for ultimate in [false, true]:
		if ultimate:
			roxy.energy = roxy.max_energy
			if not game.sim.activate_hero_ultimate(0, target):
				push_error("Roxy E failed to cast")
				quit(1)
				return
		else:
			if not game.sim.activate_hero_skill(0, target):
				push_error("Roxy Q failed to cast")
				quit(1)
				return
		game.battle.accept_events(game.sim.drain_events())
		var expected := "roxy_storm_field" if ultimate else "roxy_healing_surge"
		if not game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == expected + "_cast"):
			push_error("Roxy dedicated cast visual missing: " + expected)
			quit(1)
			return
		var offset := 18 if ultimate else 0
		for frame in 4:
			game.battle.advance(1.0 / 15.0)
			if not await _capture(game, offset + frame):
				quit(1)
				return
		var before: float = enemy.hp if ultimate else ally.hp
		game.sim._pending_impact_tick(1.0)
		game.battle.accept_events(game.sim.drain_events())
		if (ultimate and enemy.hp >= before) or (not ultimate and ally.hp <= before):
			push_error("Roxy E damage or Q healing missing")
			quit(1)
			return
		if not game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == expected + "_impact"):
			push_error("Roxy dedicated impact visual missing: " + expected)
			quit(1)
			return
		if ultimate and not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("visual", "")) == "roxy_storm"):
			push_error("Roxy storm zone missing")
			quit(1)
			return
		for frame in 14:
			game.battle.advance(1.0 / 15.0)
			if not await _capture(game, offset + frame + 4):
				quit(1)
				return
		game.battle.effects.clear()
	if not game.sim.skill_effects.is_empty():
		game.sim.skill_effects[0].life = 1.08
		for frame in 8:
			game.sim._skill_effect_tick(0.13)
			game.battle.advance(0.13)
			if not await _capture(game, 36 + frame):
				quit(1)
				return
	print("ROXY SKILL PREVIEW: Q heals, E damages and makes storm zone; 44 frames include fade-out")
	quit(0)
