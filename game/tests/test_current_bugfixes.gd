extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const StageRuntime = preload("res://scripts/stages/stage_runtime.gd")
const MainScene = preload("res://main.tscn")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("CURRENT BUGFIX PASS: " + message)
	else:
		failures += 1
		push_error("CURRENT BUGFIX FAIL: " + message)

func _wait_for(predicate: Callable, frames: int = 1200) -> bool:
	for frame in frames:
		if predicate.call():
			return true
		await process_frame
	return false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var spawn_sim = Sim.new(4401, true)
	spawn_sim.start()
	spawn_sim.terrain_features.clear()
	spawn_sim.enemies.clear()
	spawn_sim.enemy_lookup.clear()
	for index in spawn_sim.performance_budget.MAX_ENEMIES:
		spawn_sim.spawn_enemy(Vector2(1040.0, 360.0), "grunt")
	spawn_sim.stage_runtime = StageRuntime.new({
		"duration_seconds": 10.0,
		"boss_at_seconds": 999.0,
		"boss_id": "boss_01",
		"waves": [{"at": 0.0, "enemy_id": "runner", "count": 1, "interval": 1.0, "route_id": "main"}]
	})
	spawn_sim._stage_spawn_tick(0.1)
	check(spawn_sim.pending_stage_spawns.size() == 1, "capacity-limited stage spawn is queued instead of discarded")
	var removed: Dictionary = spawn_sim.enemies.pop_back()
	spawn_sim.enemy_lookup.erase(int(removed.id))
	spawn_sim._stage_spawn_tick(0.1)
	check(spawn_sim.pending_stage_spawns.is_empty(), "queued stage spawn retries after capacity is available")
	check(spawn_sim.enemies.any(func(enemy: Dictionary) -> bool: return str(enemy.kind) == "runner"), "retried stage spawn creates the warned monster")

	var follow_sim = Sim.new(4402, true)
	follow_sim.terrain_features.clear()
	check(follow_sim._add_reinforcement("hero_01"), "second test hero added")
	check(follow_sim._add_reinforcement("hero_02"), "third test hero added")
	var positions := [Vector2(220.0, 360.0), Vector2(760.0, 330.0), Vector2(430.0, 450.0)]
	for index in follow_sim.heroes.size():
		follow_sim.heroes[index].deployed = true
		follow_sim.heroes[index].pos = positions[index]
		follow_sim.heroes[index].target = positions[index]
	follow_sim.set_formation_mode("follow")
	check(follow_sim.set_follow_leader(1), "clicked non-traveler becomes follow leader")
	follow_sim.elapsed = 2.0
	follow_sim._update_follow_targets(0.1)
	check(follow_sim.follow_leader_id == 1, "follow mode stores selected leader")
	check(Vector2(follow_sim.heroes[1].target).is_equal_approx(positions[1]), "selected leader keeps its own movement target")
	check(Vector2(follow_sim.heroes[0].target).distance_to(positions[1]) < 160.0, "traveler follows selected non-traveler")
	check(Vector2(follow_sim.heroes[2].target).distance_to(positions[1]) < 160.0, "other character follows selected non-traveler")
	follow_sim.heroes[1].hp = 0.0
	follow_sim._update_follow_targets(0.1)
	check(follow_sim.follow_leader_id == 0, "dead leader falls back to a living deployed character")

	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.mode_select_panel.close()
	game.stage_select_panel.close()
	game.squad_panel.root.hide()
	var stage_three_squad: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_03", stage_three_squad, 4403)
	game.sim.state = "lost"
	game.loss_transition_shown = true
	game.test_mode = false
	game._play_loss_transition()
	var waits_for_confirmation: bool = await _wait_for(func() -> bool: return game.dialogue.animation_waiting)
	check(waits_for_confirmation, "stage 3 failure reaches an interactive confirmation gate")
	if waits_for_confirmation:
		var confirm := InputEventKey.new()
		confirm.keycode = KEY_ENTER
		confirm.pressed = true
		Input.parse_input_event(confirm)
	var returned_to_menu: bool = await _wait_for(func() -> bool: return game.mode_select_panel.is_open() and game.sim.state == "ready")
	check(returned_to_menu, "stage 3 failure confirmation returns to the main mode menu")
	game.queue_free()
	await process_frame
	print("CURRENT BUGFIX COMPLETE: %d failures" % failures)
	quit(0 if failures == 0 else 1)
