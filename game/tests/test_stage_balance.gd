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
	var first: Dictionary = simulate("stage_01", ["traveler"], 909)
	assert(first.state == "won", "fixed strong build must clear stage one")
	assert(first.base_hp > 0 and first.choices >= 12)
	var second: Dictionary = simulate("stage_02", ["traveler", "hero_02"], 910)
	assert(second.state == "won", "fixed strong build must clear stage two")
	assert(second.base_hp > 0 and second.choices >= 12)
	print("STAGE BALANCE PASSED: stage1 base=%d kills=%d; stage2 base=%d kills=%d" % [first.base_hp, first.kills, second.base_hp, second.kills])
	quit()

func simulate(stage_id: String, squad: Array[String], seed_value: int) -> Dictionary:
	var sim = Sim.new(seed_value, true)
	if stage_id != "stage_01":
		sim.reset_stage(stage_id, squad, seed_value)
	sim.start()
	var choices := 0
	var leak_damage := 0
	var leak_count := 0
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
			for event: Dictionary in sim.drain_events():
				if event.kind == "leak":
					leak_damage += int(event.value)
					leak_count += 1
		elif sim.state in ["won", "lost"]:
			break
	print("STAGE BALANCE RESULT: stage=%s state=%s base=%d choices=%d kills=%d elapsed=%.2f leaks=%d leak_damage=%d" % [stage_id, sim.state, sim.base_hp, choices, sim.kills, sim.elapsed, leak_count, leak_damage])
	return {"state": sim.state, "base_hp": sim.base_hp, "choices": choices, "kills": sim.kills}
