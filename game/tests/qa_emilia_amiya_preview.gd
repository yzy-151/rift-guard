extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node, folder: String, index: int) -> bool:
	RenderingServer.force_draw()
	await process_frame
	var image: Image = game.get_viewport().get_texture().get_image()
	if image == null:
		return false
	var directory := ProjectSettings.globalize_path("res://../outputs/" + folder)
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
	for character_id in ["hero_08", "hero_06"]:
		var squad: Array[String] = [character_id]
		game.sim.reset_stage("stage_02", squad, 5031)
		game.sim.start()
		game.battle.effects.clear()
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
		var folder := "emilia-skills-preview" if character_id == "hero_08" else "amiya-skills-preview"
		for ultimate in [false, true]:
			if ultimate:
				hero.energy = hero.max_energy
				if not game.sim.activate_hero_ultimate(0, target):
					push_error(character_id + " E failed to cast")
					quit(1)
					return
			else:
				if not game.sim.activate_hero_skill(0, target):
					push_error(character_id + " Q failed to cast")
					quit(1)
					return
			game.battle.accept_events(game.sim.drain_events())
			var offset := 18 if ultimate else 0
			for frame in 4:
				game.battle.advance(1.0 / 15.0)
				if not await _capture(game, folder, offset + frame):
					quit(1)
					return
			var hp_before: float = enemy.hp
			var caster_hp_before: float = hero.hp
			var caster_attack_before: float = hero.damage
			game.sim._pending_impact_tick(1.0)
			game.battle.accept_events(game.sim.drain_events())
			if enemy.hp >= hp_before:
				push_error(character_id + " Q/E dealt no damage")
				quit(1)
				return
			if character_id == "hero_08" and ultimate and not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("visual", "")) == "emilia_forest"):
				push_error("Emilia forest zone missing")
				quit(1)
				return
			if character_id == "hero_06" and ultimate and not (hero.hp < caster_hp_before and hero.damage > caster_attack_before):
				push_error("Amiya Chimera self-cost or attack buff missing")
				quit(1)
				return
			for frame in 14:
				game.battle.advance(1.0 / 15.0)
				if not await _capture(game, folder, offset + frame + 4):
					quit(1)
					return
			game.sim.skill_effects.clear()
			game.battle.effects.clear()
	print("EMILIA/AMIYA PREVIEW: four dedicated skills, damage, forest zone, Chimera self-cost/buff checked")
	quit(0)
