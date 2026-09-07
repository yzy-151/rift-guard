extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const PRIORITY := {
	"assign_traveler_element": 100,
	"attack_multiplier": 90,
	"attack_rate_multiplier": 85,
	"special_upgrade": 80,
	"health_multiplier": 70,
	"armor_flat": 65,
	"range_flat": 40,
	"move_speed_flat": 10
}

func _initialize() -> void:
	var sim = Sim.new(909, true)
	sim.start()
	var choices := 0
	for frame in 15000:
		if sim.state == "reward":
			var best := 0
			var score := -1
			for i in sim.rewards.offered.size():
				var value: int = PRIORITY.get(sim.rewards.offered[i].effect, 20)
				if value > score:
					score = value
					best = i
			assert(sim.choose_reward(best))
			choices += 1
		elif sim.state == "running":
			sim.tick(1.0 / 30.0)
			sim.drain_events()
		elif sim.state in ["won", "lost"]:
			break
	print("STAGE BALANCE RESULT: state=%s base=%d choices=%d kills=%d elapsed=%.2f" % [sim.state, sim.base_hp, choices, sim.kills, sim.elapsed])
	assert(sim.state == "won", "fixed strong build must clear stage one")
	assert(sim.base_hp > 0)
	assert(choices >= 12)
	print("STAGE BALANCE PASSED: base=%d choices=%d kills=%d" % [sim.base_hp, choices, sim.kills])
	quit()
