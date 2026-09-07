extends SceneTree

const Progression = preload("res://scripts/rewards/crystal_progression.gd")

func _initialize() -> void:
	var run = {"crystal_level": 1, "crystal_xp": 0, "pending_level_ups": 0}
	var progression = Progression.new([40, 90, 150])
	progression.grant(run, 155)
	assert(run.crystal_level == 4)
	assert(run.crystal_xp == 155)
	assert(run.pending_level_ups == 3)
	assert(progression.consume_choice(run))
	assert(run.pending_level_ups == 2)
	progression.grant(run, -50)
	assert(run.crystal_xp == 155)
	print("CRYSTAL PROGRESSION PASSED")
	quit()
