extends RefCounted

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("V11 PASS: " if ok else "V11 FAIL: ") + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.refresh()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v11-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	sim.reset_stage("stage_01", solo, 1101)
	var routes: Dictionary = sim.stage_routes()
	expect(routes.size() >= 3, "configured stage exposes at least three routes")
	var starts: Dictionary = {}
	for route_id: String in routes:
		var route: Array = routes[route_id]
		if not route.is_empty():
			starts[str(route[0])] = true
	expect(starts.size() >= 3, "routes use distinct entry points")
	var routed: Dictionary = sim.spawn_on_route("grunt", "upper")
	var before: Vector2 = routed.pos
	sim.state = "running"
	sim._enemy_tick(0.5)
	expect(routed.pos != before and int(routed.route_index) >= 1, "enemy advances along configured waypoint route")
	sim.spawn_on_route("runner", "main")
	sim.spawn_on_route("flyer", "lower")
	await capture(game, "00-multi-route-battle")
	game.stage_select_panel.open()
	await capture(game, "00b-mode-and-stage-select")
	game.stage_select_panel.close()

	sim.run_state.pending_level_ups = 1
	sim.reward_cooldown = 5.0
	sim.tick(1.0)
	expect(sim.state == "running", "queued card does not interrupt during reward cooldown")
	sim.reward_cooldown = 0.0
	sim.tick(0.01)
	expect(sim.state == "reward" and sim.rewards.offered.size() == 3, "queued reward opens after cooldown")

	sim.reset_stage("stage_01", solo, 3303)
	sim.start()
	var choices := 0
	for step in 12000:
		if sim.state == "reward":
			var pick := 0
			for i in sim.rewards.offered.size():
				var effect := str(sim.rewards.offered[i].get("effect", ""))
				if effect in ["assign_traveler_element", "deploy_reinforcement", "projectile_count_add", "squad_attack_multiplier"]:
					pick = i
					break
			sim.choose_reward(pick)
			choices += 1
		if sim.state == "running" and sim.traveler_skill_cooldown <= 0.0 and sim.run_state.traveler_element != "" and not sim.enemies.is_empty():
			var skill_target: Dictionary = {}
			for enemy: Dictionary in sim.enemies:
				if enemy.hp > 0.0 and (skill_target.is_empty() or enemy.pos.x < skill_target.pos.x):
					skill_target = enemy
			if not skill_target.is_empty():
				sim.activate_traveler_skill(skill_target.pos)
		if sim.state in ["won", "lost"]:
			break
		sim.tick(0.05)
	expect(sim.state == "won", "five-minute route stage remains winnable after route and speed rebalance")
	expect(choices >= 8, "stage one supplies a substantial spaced card build")

	sim.reset_stage("stage_endless", solo, 2202)
	sim.start()
	expect(sim.endless_mode and sim.heroes[0].pos.distance_to(sim.ENDLESS_ARENA.get_center()) < 1.0, "endless starts Traveler at large-arena center")
	sim.command_move(0, Vector2(-9999, 9999))
	expect(sim.ENDLESS_ARENA.has_point(sim.heroes[0].target) or sim.heroes[0].target.is_equal_approx(Vector2(sim.ENDLESS_ARENA.position.x, sim.ENDLESS_ARENA.end.y)), "endless movement clamps to arena")
	var edge_ids: Dictionary = {}
	for step in 80:
		sim.tick(0.25)
		for event: Dictionary in sim.drain_events():
			if event.kind == "route_spawn":
				edge_ids[str(event.route_id)] = true
	expect(edge_ids.size() == 4, "endless enemies spawn from all four map edges")
	var chase_enemy: Dictionary = {}
	for enemy: Dictionary in sim.enemies:
		if enemy.hp > 0:
			chase_enemy = enemy
			break
	if not chase_enemy.is_empty():
		var distance_before: float = chase_enemy.pos.distance_to(sim.heroes[0].pos)
		sim._enemy_tick(0.2)
		expect(chase_enemy.pos.distance_to(sim.heroes[0].pos) < distance_before, "endless enemy chases Traveler")
	else:
		expect(false, "endless enemy remains available for chase check")

	var old_level: int = sim.run_state.crystal_level
	sim.grant_xp(sim.endless_next_threshold() + 10)
	expect(sim.run_state.crystal_level > old_level and sim.run_state.pending_level_ups > 0, "endless Traveler levels and queues card choices")
	sim.state = "running"
	sim.run_state.pending_level_ups = 0
	expect(sim._add_reinforcement("hero_02"), "endless reinforcement joins the field")
	var follower: Dictionary = sim.heroes[1]
	follower.pos = sim.heroes[0].pos + Vector2(45, 0)
	follower.target = sim.heroes[0].pos + Vector2(180, 0)
	follower.moving = true
	follower.attack_timer = 0.0
	var target: Dictionary = sim.spawn_enemy(follower.pos + Vector2(75, 0), "grunt")
	var shots_before: int = sim.shots_fired
	sim._hero_tick()
	expect(sim.shots_fired > shots_before and target.hp > 0, "follower attacks while moving")
	sim.heroes[0].pos = sim.ENDLESS_ARENA.get_center()
	sim.heroes[0].target = sim.heroes[0].pos
	for i in range(1, sim.heroes.size()):
		sim.heroes[i].pos = sim.heroes[0].pos + Vector2(-92, (i - 1) * 92 - 46)
		sim.heroes[i].target = sim.heroes[i].pos
	for i in 16:
		var angle := float(i) * TAU / 16.0
		sim.spawn_enemy(sim.heroes[0].pos + Vector2.from_angle(angle) * (250.0 + (i % 3) * 72.0), ["grunt", "runner", "ranged", "armored"][i % 4])
	game.battle.camera_center = sim.heroes[0].pos
	await capture(game, "01-endless-arena")
	sim.run_state.buff_levels["mechanic_twin_arc"] = 2
	sim.run_state.buff_levels["support_crossfire"] = 1
	sim.run_state.buff_levels["squad_attack_rare"] = 3
	sim.state = "paused"
	await capture(game, "02-pause-build-and-stats")
	sim.reset_stage("stage_01", solo, 4404)
	sim.begin_stage_exit()
	game.battle.begin_stage_exit("hero_02", "宵宫", "pyro")
	await game.get_tree().create_timer(0.72).timeout
	await capture(game, "03-stage-door-unlock")

	print("V11 TESTS: %d checks; %d failures" % [checks, failures])
	var tree = game.get_tree()
	game.queue_free()
	await tree.process_frame
	tree.quit(0 if failures == 0 else 1)
