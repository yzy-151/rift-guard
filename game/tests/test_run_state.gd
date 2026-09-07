extends SceneTree

const RunState = preload("res://scripts/run/run_state.gd")

func _initialize() -> void:
	var run = RunState.new()
	assert(run.set_squad(["traveler", "hero_02", "hero_03"]))
	assert(not run.set_squad(["traveler", "hero_02", "hero_03", "hero_04"]))
	assert(not run.set_squad(["traveler", "traveler"]))
	run.traveler_element = "hydro"
	run.buff_levels["traveler_attack_common_1"] = 3
	run.crystal_level = 8
	run.crystal_xp = 510
	run.pending_level_ups = 2
	run.legendary_count = 1
	run.reset_for_stage("stage_02")
	assert(run.stage_id == "stage_02")
	assert(run.traveler_element == "none")
	assert(run.buff_levels.is_empty())
	assert(run.crystal_level == 1 and run.crystal_xp == 0)
	assert(run.pending_level_ups == 0 and run.legendary_count == 0)
	assert(run.squad == ["traveler", "hero_02", "hero_03"])
	print("RUN STATE PASSED")
	quit()
