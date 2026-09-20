extends SceneTree

const MainScene = preload("res://main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _shot(game: Node, label: String) -> void:
	game.battle.queue_redraw()
	RenderingServer.force_draw()
	await process_frame
	var path := ProjectSettings.globalize_path("res://../outputs/columbia-wind-traveler-preview")
	DirAccess.make_dir_recursive_absolute(path)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(path.path_join(label + ".png"))

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
	var first_squad: Array[String] = ["hero_01", "traveler"]
	game.sim.reset_stage("stage_02", first_squad, 7201)
	game.sim.start()
	var col: Dictionary = game.sim.heroes[0]
	var ally: Dictionary = game.sim.heroes[1]
	col.deployed = true
	col.pos = Vector2(520.0, 360.0)
	col.hp = col.max_hp - 160.0
	ally.deployed = true
	ally.pos = Vector2(850.0, 360.0)
	var enemy: Dictionary = game.sim.spawn_enemy(Vector2(610.0, 360.0), "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	game.sim.drain_events()
	game.battle.effects.clear()
	assert(col.name == "哥伦比亚" and col.element == "hydro")
	game.selected_id = 0
	game.toggle_skill_aiming()
	assert(not game.skill_aiming and not game.sim.pending_impacts.is_empty())
	assert(game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == "columbia_tide_ring_cast"))
	game.sim._pending_impact_tick(1.0)
	game.battle.accept_events(game.sim.drain_events())
	assert(game.sim.skill_effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == "columbia_tide_ring"))
	var hp_before: float = enemy.hp
	var healed_before: float = col.hp
	game.sim._skill_effect_tick(0.1)
	game.battle.accept_events(game.sim.drain_events())
	assert(enemy.hp < hp_before and col.hp > healed_before)
	game.battle.advance(0.3)
	game.refresh()
	await _shot(game, "columbia-q")
	game.sim.skill_effects.clear()
	game.battle.effects.clear()
	var col_attack: float = col.damage
	var ally_attack: float = ally.damage
	col.energy = col.max_energy
	game.activate_selected_ultimate()
	assert(not game.ultimate_aiming and not game.sim.pending_impacts.is_empty())
	game.sim._pending_impact_tick(1.0)
	game.battle.accept_events(game.sim.drain_events())
	assert(absf(col.damage - col_attack * 2.0) < 0.01)
	assert(absf(ally.damage - ally_attack - col_attack) < 0.01)
	assert(game.sim.skill_effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == "columbia_attack_blessing"))
	game.battle.advance(0.65)
	game.refresh()
	await _shot(game, "columbia-e-transit")
	game.battle.advance(1.5)
	game.refresh()
	await _shot(game, "columbia-e-arrival")
	game.sim._skill_effect_tick(25.1)
	assert(absf(col.damage - col_attack) < 0.01 and absf(ally.damage - ally_attack) < 0.01)
	var wind_squad: Array[String] = ["hero_10", "traveler"]
	game.sim.reset_stage("stage_02", wind_squad, 7202)
	game.sim.start()
	game.sim.terrain_features.clear()
	var wind: Dictionary = game.sim.heroes[0]
	wind.deployed = true
	wind.pos = Vector2(500.0, 360.0)
	var row_enemies: Array[Dictionary] = []
	for row_y in [320.0, 360.0, 400.0]:
		var row_enemy: Dictionary = game.sim.spawn_enemy(Vector2(1000.0, row_y), "grunt")
		row_enemy.hp = 100000.0
		row_enemy.max_hp = row_enemy.hp
		row_enemies.append(row_enemy)
	game.sim.drain_events()
	game.battle.effects.clear()
	assert(game.sim.activate_hero_skill(0, wind.pos))
	game.battle.accept_events(game.sim.drain_events())
	game.sim._pending_impact_tick(1.0)
	game.battle.accept_events(game.sim.drain_events())
	for pulse in 3:
		var before: Array[float] = []
		for row_enemy: Dictionary in row_enemies:
			before.append(float(row_enemy.hp))
		game.sim._skill_effect_tick(0.01 if pulse == 0 else 1.0)
		var wind_events: Array = game.sim.drain_events().filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "fengjin_wind_row")
		assert(wind_events.size() == 1)
		assert(int(wind_events[0].row_index) == pulse + 4)
		game.battle.accept_events(wind_events)
		for row_index in 3:
			var row_enemy: Dictionary = row_enemies[row_index]
			assert((row_enemy.hp < before[row_index]) == (row_index == pulse))
			assert(absf(row_enemy.pos.x - (1060.0 if row_index <= pulse else 1000.0)) < 0.1)
		game.battle.advance(0.13)
		game.refresh()
		await _shot(game, "fengjin-q-%d" % pulse)
	for element in ["none", "electro", "pyro", "hydro", "geo", "cryo"]:
		var traveler_squad: Array[String] = ["traveler"]
		game.sim.reset_stage("stage_02", traveler_squad, 7300)
		game.sim.start()
		var traveler: Dictionary = game.sim.heroes[0]
		traveler.deployed = true
		traveler.pos = Vector2(500.0, 360.0)
		traveler.element = element
		var target := Vector2(730.0, 350.0)
		var victim: Dictionary = game.sim.spawn_enemy(Vector2(760.0, 350.0), "grunt")
		victim.hp = 100000.0
		victim.max_hp = victim.hp
		game.sim.drain_events()
		game.battle.effects.clear()
		assert(game.sim.activate_hero_skill(0, target))
		game.battle.accept_events(game.sim.drain_events())
		assert(game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == "traveler_" + element + "_cast"))
		game.sim._pending_impact_tick(1.0)
		game.battle.accept_events(game.sim.drain_events())
		assert(game.battle.effects.any(func(fx: Dictionary) -> bool: return str(fx.kind) == "traveler_" + element + "_impact"))
		game.battle.advance(0.28)
		game.refresh()
		await _shot(game, "traveler-" + element)
	print("COL/WIND/TRAVELER PASS: 10s self water ring damage + heal, 25s reversible attack buff, three sequential full-width wind rows with 1-cell push, six traveler visuals")
	quit(0)
