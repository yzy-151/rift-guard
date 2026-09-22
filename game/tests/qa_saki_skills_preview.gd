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
	var directory := ProjectSettings.globalize_path("res://../outputs/saki-skills-preview")
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
	var squad: Array[String] = ["hero_07"]
	game.sim.reset_stage("stage_02", squad, 4721)
	game.sim.start()
	var hero: Dictionary = game.sim.heroes[0]
	hero.deployed = true
	hero.pos = Vector2(500.0, 375.0)
	hero.target = hero.pos
	var target := Vector2(770.0, 365.0)
	var enemy: Dictionary = game.sim.spawn_enemy(target, "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = 100000.0
	game.sim.drain_events()
	game.refresh()
	for ultimate in [false, true]:
		if ultimate:
			hero.energy = hero.max_energy
			if not game.sim.activate_hero_ultimate(0, target):
				push_error("Saki E failed to cast")
				quit(1)
				return
		else:
			if not game.sim.activate_hero_skill(0, target):
				push_error("Saki Q failed to cast")
				quit(1)
				return
		game.battle.accept_events(game.sim.drain_events())
		var offset := 18 if ultimate else 0
		for frame in 4:
			game.battle.advance(1.0 / 15.0)
			if not await _capture(game, offset + frame):
				quit(1)
				return
		var hp_before: float = enemy.hp
		game.sim._pending_impact_tick(1.0)
		game.battle.accept_events(game.sim.drain_events())
		var expected_visual := "saki_score_e" if ultimate else "saki_score_q"
		if enemy.hp >= hp_before or not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("visual", "")) == expected_visual):
			push_error("Saki skill damage or its matching persistent zone is missing: " + expected_visual)
			quit(1)
			return
		for frame in 14:
			game.battle.advance(1.0 / 15.0)
			if not await _capture(game, offset + frame + 4):
				quit(1)
				return
		game.sim.skill_effects.clear()
		game.battle.effects.clear()
	print("SAKI SKILL PREVIEW: Q and E damage, themed zones, and 36 frames checked")
	quit(0)

