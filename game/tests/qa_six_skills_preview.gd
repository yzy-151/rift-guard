extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _capture(game: Node, folder: String, index: int) -> bool:
	RenderingServer.force_draw()
	await process_frame
	var shot: Image = game.get_viewport().get_texture().get_image()
	if shot == null:
		return false
	var destination := ProjectSettings.globalize_path("res://../outputs/" + folder)
	DirAccess.make_dir_recursive_absolute(destination)
	return shot.save_png(destination.path_join("frame-%02d.png" % index)) == OK

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
	var cases: Array[Dictionary] = [
		{"id":"hero_10","folder":"fengjin-skills-preview"},
		{"id":"hero_13","folder":"gwen-skills-preview"},
		{"id":"hero_03","folder":"furina-skills-preview"},
	]
	for item: Dictionary in cases:
		var character_id := str(item.id)
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
		var target := Vector2(600.0, 370.0) if character_id in ["hero_10", "hero_03"] else Vector2(765.0, 370.0)
		var enemy: Dictionary = game.sim.spawn_enemy(target, "grunt")
		enemy.hp = 100000.0
		enemy.max_hp = 100000.0
		game.sim.drain_events()
		game.battle.effects.clear()
		game.refresh()
		var buffs: Array = game.sim.terrain_features.filter(func(feature: Dictionary) -> bool: return str(feature.get("type", "")) in ["high_ground", "attack_ground"])
		if buffs.is_empty():
			push_error("Buff cells absent")
			quit(1)
			return
		for feature: Dictionary in buffs:
			for cell: Rect2 in feature.get("grid_cells", []):
				if cell.size != game.sim.GRID_CELL_SIZE:
					push_error("Buff art not one grid cell: " + str(feature.get("id", "")))
					quit(1)
					return
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
			var visual_prefix: String = {"hero_10":"fengjin_", "hero_13":"gwen_", "hero_03":"furina_"}[character_id]
			var visual: String = visual_prefix + str(ability.kind)
			if not game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == visual + "_cast"):
				push_error("Missing cast: " + visual)
				quit(1)
				return
			var folder := str(item.folder)
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
			if character_id == "hero_10" and not ultimate:
				if not game.sim.skill_effects.any(func(effect: Dictionary) -> bool: return str(effect.kind) == "wind_cut_rows"):
					push_error("Wind rows missing")
					quit(1)
					return
			if character_id == "hero_10" and ultimate and not game.sim.skill_effects.any(func(effect: Dictionary) -> bool: return str(effect.get("visual", "")) == "fengjin_breeze"):
				push_error("Fengjin healing zone missing")
				quit(1)
				return
			if character_id == "hero_13" and not ultimate and float(ally.get("invulnerable_timer", 0.0)) < 4.9:
				push_error("Gwen shelter missing")
				quit(1)
				return
			if character_id == "hero_13" and ultimate:
				var needle_zone: Array = game.sim.skill_effects.filter(func(effect: Dictionary) -> bool: return str(effect.get("visual", "")) == "gwen_needles")
				if needle_zone.is_empty() or absf(float(needle_zone[0].pulse) - 0.52) > 0.01 or int(needle_zone[0].remaining) != 12:
					push_error("Gwen eight-pin expansion timing missing")
					quit(1)
					return
			if character_id == "hero_03" and not ultimate and not game.sim.orbitals.any(func(orbital: Dictionary) -> bool: return str(orbital.get("visual", "")) == "salon"):
				push_error("Furina salon companions missing")
				quit(1)
				return
			if character_id == "hero_03" and ultimate:
				if not game.sim.skill_effects.any(func(effect: Dictionary) -> bool: return str(effect.get("visual", "")) == "furina_fanfare") or ally.hp <= ally_hp:
					push_error("Furina E healing or water stage missing")
					quit(1)
					return
			for frame in 14:
				if character_id == "hero_10" and not ultimate and frame in [0, 3, 6]:
					game.sim._skill_effect_tick(0.01 if frame == 0 else 1.0)
					game.battle.accept_events(game.sim.drain_events())
				elif character_id == "hero_13" and ultimate:
					game.sim._skill_effect_tick(0.105)
					game.battle.accept_events(game.sim.drain_events())
				elif character_id == "hero_10" and ultimate and frame == 0:
					game.sim._skill_effect_tick(0.9)
					game.battle.accept_events(game.sim.drain_events())
				game.battle.advance(1.0 / 15.0)
				if not await _capture(game, folder, offset + frame + 4):
					quit(1)
					return
			if character_id == "hero_10" and not ultimate and enemy.hp >= enemy_hp - 3.0:
				push_error("Fengjin three hits missing")
				quit(1)
				return
			if character_id == "hero_10" and ultimate and ally.hp <= ally_hp:
				push_error("Fengjin healing missing")
				quit(1)
				return
			if character_id == "hero_13" and ultimate and enemy.hp >= enemy_hp:
				push_error("Gwen needle damage missing")
				quit(1)
				return
			game.battle.effects.clear()
			game.sim.skill_effects.clear()
			game.sim.orbitals.clear()
	var wind_squad: Array[String] = ["hero_10", "traveler"]
	game.sim.reset_stage("stage_02", wind_squad, 6103)
	game.sim.start()
	game.sim.terrain_features.clear()
	var wind_caster: Dictionary = game.sim.heroes[0]
	wind_caster.deployed = true
	wind_caster.pos = Vector2(500.0, 375.0)
	var wind_enemy: Dictionary = game.sim.spawn_enemy(Vector2(600.0, 375.0), "grunt")
	wind_enemy.hp = 100000.0
	wind_enemy.max_hp = 100000.0
	if not game.sim.activate_hero_skill(0, wind_caster.pos):
		push_error("Wind skill did not cast in isolated check")
		quit(1)
		return
	game.sim._pending_impact_tick(1.0)
	var previous_hp: float = wind_enemy.hp
	for strike in 3:
		game.sim._skill_effect_tick(0.01 if strike == 0 else 1.0)
		var expected_x: float = 600.0 + float(strike + 1) * game.sim.GRID_CELL_SIZE.x
		if wind_enemy.hp >= previous_hp or absf(wind_enemy.pos.x - expected_x) > 0.1:
			push_error("Wind strike %d failed damage or one-cell push" % [strike + 1])
			quit(1)
			return
		previous_hp = wind_enemy.hp
	wind_enemy.pos = Vector2(600.0, 375.0)
	game.sim.terrain_features.append({"type":"blocked","area":Rect2(700.0, 350.0, 60.0, 50.0)})
	game.sim._push_enemy_grid_cells(wind_enemy, wind_caster.pos, 3)
	if wind_enemy.pos.x > 660.1 or game.sim._terrain_blocks(wind_enemy.pos, 12.0):
		push_error("Wind push crossed a wall")
		quit(1)
		return
	print("SIX SKILL PREVIEW PASS: wind three hits and one-cell wall-safe pushes, Gwen eight-pin expansion, Furina Q/E, one-cell buffs")
	quit(0)
