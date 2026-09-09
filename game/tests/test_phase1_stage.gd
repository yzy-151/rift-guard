extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func _initialize() -> void:
	var sim = Sim.new(707, true)
	sim.start()
	var choices := 0
	var element_chosen := false
	for frame in 22500:
		if sim.state == "reward":
			var choice := 0
			if not element_chosen:
				for i in sim.rewards.offered.size():
					if sim.rewards.offered[i].effect == "assign_traveler_element":
						choice = i
						element_chosen = true
						break
			assert(sim.choose_reward(choice))
			choices += 1
		elif sim.state in ["running", "between"]:
			if sim.traveler_skill_cooldown <= 0.0 and not sim.enemies.is_empty():
				sim.activate_traveler_skill(sim.enemies[0].pos)
			var traveler: Dictionary = sim.heroes[0]
			traveler.max_hp = 999999.0
			traveler.hp = 999999.0
			traveler.damage = 900.0
			traveler.rate = 12.0
			traveler.range = 1000.0
			traveler.block = 100
			traveler.cleave = true
			sim.base_hp = 100
			sim.tick(1.0 / 30.0)
			sim.drain_events()
		elif sim.state in ["won", "lost"]:
			break
	assert(sim.state == "won")
	assert(sim.stage_runtime.elapsed >= 330.0)
	assert(sim.stage_runtime.boss_emitted)
	assert(choices >= 8 and choices <= 12)
	assert(element_chosen and sim.run_state.traveler_element != "none")
	var squad_before: Array[String] = sim.run_state.squad.duplicate()
	sim.reset_stage("stage_01", squad_before, 707)
	assert(sim.run_state.traveler_element == "none")
	assert(sim.run_state.buff_levels.is_empty())
	assert(sim.run_state.pending_level_ups == 0)
	assert(sim.enemies.is_empty() and sim.projectiles.is_empty())
	print("PHASE 1 STAGE PASSED: duration=%.2f choices=%d" % [330.0, choices])
	quit()
