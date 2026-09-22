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
	for character_id in ["hero_10", "hero_13"]:
		var squad: Array[String] = [character_id, "traveler"]
		game.sim.reset_stage("stage_02", squad, 6103)
		game.sim.start()
		var caster: Dictionary = game.sim.heroes[0]
		var ally: Dictionary = game.sim.heroes[1]
		caster.deployed = true
		caster.pos = Vector2(500.0, 375.0)
		caster.target = caster.pos
		ally.deployed = true
		ally.pos = Vector2(650.0, 370.0)
		ally.target = ally.pos
		ally.hp = ally.max_hp - 150.0
		var target := Vector2(600.0, 370.0) if character_id == "hero_10" else Vector2(765.0, 370.0)
		var enemy: Dictionary = game.sim.spawn_enemy(target, "grunt")
		enemy.hp = 100000.0
		enemy.max_hp = 100000.0
		game.sim.drain_events()
		game.battle.effects.clear()
		game.refresh()
		for ultimate in [false, true]:
			var ability: Dictionary = caster.ultimate if ultimate else caster.active_skill
			var center: Vector2 = caster.pos if str(ability.get("targeting", "")) == "self" else target
			if ultimate:
				caster.energy = caster.max_energy
				if not game.sim.activate_hero_ultimate(0, center):
					push_error(character_id + " E cast failed")
					quit(1)
					return
			else:
				if not game.sim.activate_hero_skill(0, center):
					push_error(character_id + " Q cast failed")
					quit(1)
					return
			game.battle.accept_events(game.sim.drain_events())
			var visual := "fengjin_" if character_id == "hero_10" else "gwen_"
			visual += str(ability.kind)
			if not game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == visual + "_cast"):
				push_error("Missing cast: " + visual)
				quit(1)
				return
			var folder := "fengjin-skills-preview" if character_id == "hero_10" else "gwen-skills-preview"
			var offset := 18 if ultimate else 0
			for frame in 4:
				game.battle.advance(1.0 / 15.0)
				if not await _capture(game, folder, offset + frame):
					quit(1)
					return
			var enemy_hp: float = enemy.hp
			var ally_hp: float = ally.hp
			game.sim._pending_impact_tick(1.0)
			game.battle.accept_events(game.sim.drain_events())
			if not game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == visual + "_impact"):
				push_error("Missing impact: " + visual)
				quit(1)
				return
			if character_id == "hero_10":
				if ultimate:
					if not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("visual", "")) == "fengjin_breeze"):
						push_error("Fengjin E zone missing")
						quit(1)
						return
					game.sim._skill_effect_tick(0.9)
					if ally.hp <= ally_hp:
						push_error("Fengjin E did not heal ally")
						quit(1)
						return
				else:
					for strike in 3:
						game.sim._skill_effect_tick(0.01 if strike == 0 else 1.0)
						game.battle.accept_events(game.sim.drain_events())
					if enemy.hp >= enemy_hp:
						push_error("Fengjin Q did not damage enemy")
						quit(1)
						return
			else:
				if ultimate:
					if not game.sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("visual", "")) == "gwen_needles"):
						push_error("Gwen E zone missing")
						quit(1)
						return
				elif float(ally.get("invulnerable_timer", 0.0)) < 4.9:
					push_error("Gwen Q did not protect ally")
					quit(1)
					return
			for frame in 14:
				if character_id == "hero_13" and ultimate:
					game.sim._skill_effect_tick(0.105)
					game.battle.accept_events(game.sim.drain_events())
				game.battle.advance(1.0 / 15.0)
				if not await _capture(game, folder, offset + frame + 4):
					quit(1)
					return
			if character_id == "hero_13" and ultimate and enemy.hp >= enemy_hp:
				push_error("Gwen E did not damage enemy")
				quit(1)
				return
			game.battle.effects.clear()
			game.sim.skill_effects.clear()
	print("FENGJIN/GWEN PREVIEW PASS: four casts, impacts and gameplay effects; 36 frames each")
	quit(0)