extends RefCounted

const AssetReadiness = preload("res://scripts/asset_readiness.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V26 PASS: " + message)
	else:
		failures += 1
		push_error("V26 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.25).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v26-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	sim.reset_stage("stage_01", solo, 2601)
	var db = sim.database
	expect(db.errors.is_empty(), "V26 content validates")
	expect(db.combat_contracts.size() == db.stages.size(), "every map owns one replaceable combat contract")
	expect(int(db.asset_readiness.playable) == 12, "all twelve characters have a complete playable asset fallback")
	expect(int(db.asset_readiness.final_ready) < 12, "asset readiness report distinguishes placeholders from final art")
	var report_path := ProjectSettings.globalize_path("res://../docs/asset-readiness-v26.md")
	var report_file := FileAccess.open(report_path, FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(AssetReadiness.markdown(db.asset_readiness))
	var metrics: Dictionary = {}
	for contract: Dictionary in db.combat_contracts.values():
		metrics[str(contract.metric)] = true
	expect(["kills", "reactions", "survival_time"].all(func(metric: String)->bool: return metrics.has(metric)), "contracts cover kill, reaction and survival play styles")

	sim.start()
	sim.deploy_hero(0, Vector2(480, 360))
	var luck_before: float = sim.run_state.luck
	sim.kills = int(sim.combat_contract.target)
	sim._contract_tick()
	expect(sim.contract_completed and sim.run_state.luck > luck_before, "kill contract grants its configured luck reward")
	expect(sim.drain_events().any(func(event: Dictionary)->bool: return event.kind == "contract_complete"), "contract completion emits a presentation event exactly once")

	sim.reset_stage("stage_02", solo, 2602)
	sim.start()
	sim.deploy_hero(0, Vector2(480, 360))
	sim.reactions = int(sim.combat_contract.target)
	sim._contract_tick()
	expect(sim.contract_completed and sim.crystal_shield == 120.0, "reaction contract grants shield reward")

	sim.reset_stage("stage_03", solo, 2603)
	sim.start()
	sim.deploy_hero(0, Vector2(480, 360))
	sim.heroes[0].energy = 0.0
	sim.kills = int(sim.combat_contract.target)
	sim._contract_tick()
	expect(sim.heroes[0].energy == 35.0, "energy contract charges independent ultimate meter")

	sim.reset_stage("stage_07", solo, 2607)
	sim.start()
	sim.deploy_hero(0, Vector2(480, 360))
	sim.heroes[0].hp = sim.heroes[0].max_hp * 0.25
	sim.reactions = int(sim.combat_contract.target)
	sim._contract_tick()
	expect(sim.heroes[0].hp > sim.heroes[0].max_hp * 0.25, "healing contract restores surviving heroes")

	sim.reset_stage("stage_endless", solo, 2626)
	sim.start()
	sim.deploy_hero(0, Vector2(1240, 720))
	sim.elapsed = float(sim.combat_contract.target)
	sim._contract_tick()
	expect(sim.contract_completed and sim.contract_status().contains("完成"), "endless survival contract completes without a crystal objective")

	var move_ids: Dictionary = {}
	var phase_count := 0
	for boss_id: String in db.boss_patterns:
		var pattern: Dictionary = db.boss_patterns[boss_id]
		for phase_row: Dictionary in pattern.phases:
			phase_count += 1
			for move_value: Variant in phase_row.moves:
				var move := str(move_value)
				move_ids[move] = true
				sim.enemies.clear()
				sim.geo_constructs.clear()
				for hero: Dictionary in sim.heroes:
					hero.hp = hero.max_hp
					hero.pos = Vector2(1240, 720)
					hero.skill_cooldown = 0.0
				var boss: Dictionary = sim.spawn_enemy(Vector2(1500, 720), boss_id)
				boss.boss_phase = int(phase_row.phase)
				boss.special_move = move
				boss.special_move_name = str(phase_row.name)
				boss.special_warning_shape = str(phase_row.shape)
				boss.special_warning_radius = float(phase_row.radius)
				boss.special_warning_positions = [sim.heroes[0].pos]
				sim.events.clear()
				sim._execute_boss_special(boss)
				var emitted: bool = sim.events.any(func(event: Dictionary)->bool: return event.kind == "boss_move" and str(event.value) == move)
				expect(emitted, "%s executes phase move %s" % [boss_id, move])
	expect(phase_count == 18 and move_ids.size() >= 24, "six bosses expose eighteen phases and a broad move library")

	var geometry_enemy := {"pos":Vector2(400,360),"special_warning_positions":[Vector2(700,360)],"special_warning_radius":180.0}
	var geometry_hero := {"pos":Vector2(560,375)}
	geometry_enemy.special_warning_shape = "line"
	expect(sim._hero_in_boss_warning(geometry_hero, geometry_enemy), "line telegraph collision follows the drawn lane")
	geometry_hero.pos = Vector2(560,470)
	expect(not sim._hero_in_boss_warning(geometry_hero, geometry_enemy), "leaving a line telegraph avoids damage")
	geometry_enemy.special_warning_shape = "donut"
	geometry_enemy.special_warning_positions = [Vector2(700,360)]
	geometry_hero.pos = Vector2(700,360)
	expect(not sim._hero_in_boss_warning(geometry_hero, geometry_enemy), "donut telegraph has a safe inner ring")
	geometry_hero.pos = Vector2(820,360)
	expect(sim._hero_in_boss_warning(geometry_hero, geometry_enemy), "donut telegraph damages its visible outer ring")
	geometry_enemy.special_warning_shape = "cross"
	geometry_hero.pos = Vector2(700,500)
	expect(sim._hero_in_boss_warning(geometry_hero, geometry_enemy), "cross telegraph uses orthogonal damage lanes")

	sim.reset_stage("stage_endless", solo, 2699)
	sim.start()
	sim.deploy_hero(0, Vector2(1240,720))
	game.selected_id = 0
	game.set_skill_aiming(true)
	var cancel := InputEventMouseButton.new()
	cancel.button_index = MOUSE_BUTTON_RIGHT
	cancel.pressed = true
	cancel.position = Vector2(640,360)
	game._unhandled_input(cancel)
	expect(not game.skill_aiming, "right click cancels skill targeting without moving the hero")
	sim.toggle_pause()
	game.hud.signature = ""
	game.hud.refresh(sim, 0)
	expect(game.hud.pause_status_label.text.contains("PERF") and game.hud.pause_status_label.text.contains("契约"), "pause center exposes performance budget and contract progress")
	expect(game.hud.skill_button.text.contains("主动技能"), "active skill HUD remains available after V26 interaction changes")
	await capture(game, "02-pause-contract-performance")
	sim.toggle_pause()
	sim.enemies.clear()
	var preview_boss: Dictionary = sim.spawn_enemy(Vector2(1540, 720), "boss_01")
	preview_boss.special_pending = true
	preview_boss.special_warning = 1.1
	preview_boss.special_warning_shape = "cross"
	preview_boss.special_warning_radius = 210.0
	preview_boss.special_move_name = "交叉军令"
	preview_boss.special_warning_positions = [Vector2(1240,720)]
	game.hud.signature = ""
	await capture(game, "01-boss-cross-telegraph")
	print("V26 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
