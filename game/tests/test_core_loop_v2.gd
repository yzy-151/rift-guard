extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func _initialize() -> void:
	var sim = Sim.new(303, true)
	assert(sim.v2_mode)
	assert(sim.heroes.size() == 1)
	assert(sim.heroes[0].character_id == "traveler")
	assert(sim.heroes[0].element == "")
	sim.start()
	assert(sim.state == "running")
	var grunt: Dictionary = sim.spawn_enemy(Vector2(900, 360), "grunt")
	var armored: Dictionary = sim.spawn_enemy(Vector2(900, 360), "armored")
	sim.apply_hit(grunt, 10000.0, "")
	sim.apply_hit(armored, 10000.0, "")
	assert(sim.team_xp == 30 and sim.state == "running")
	var second_armored: Dictionary = sim.spawn_enemy(Vector2(900, 360), "armored")
	sim.apply_hit(second_armored, 10000.0, "")
	assert(sim.team_xp == 50 and sim.team_level == 2)
	assert(sim.state == "reward" and sim.rewards.offered.size() == 3)
	assert(sim.rewards.offered.any(func(card): return card.effect == "assign_traveler_element"))
	var element_index := -1
	for i in sim.rewards.offered.size():
		if sim.rewards.offered[i].effect == "assign_traveler_element":
			element_index = i
			break
	assert(sim.choose_reward(element_index))
	assert(sim.run_state.traveler_element != "none")
	assert(sim.heroes[0].element == sim.run_state.traveler_element)
	sim.grant_xp(200)
	assert(sim.run_state.pending_level_ups >= 2 and sim.state == "reward")
	var retained_squad: Array[String] = sim.run_state.squad.duplicate()
	sim.restart_current_stage()
	assert(sim.run_state.squad == retained_squad)
	assert(sim.run_state.traveler_element == "none")
	assert(sim.run_state.buff_levels.is_empty())
	assert(sim.team_xp == 0 and sim.team_level == 1)
	assert(sim.enemies.is_empty() and sim.projectiles.is_empty())
	print("CORE LOOP V2 PASSED")
	quit()
