extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Book = preload("res://scripts/reward_book.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func grant(sim, card_id: String) -> bool:
	sim.state = "reward"
	for card: Dictionary in Book.CARDS:
		if card.id == card_id:
			sim.rewards.offered.assign([card.duplicate(true)])
			return sim.choose_reward(0)
	return false

func active_sim():
	var sim = Sim.new(1)
	sim.state = "running"
	sim.wave = 1
	sim.spawn_remaining = 1
	sim.spawn_timer = 999.0
	for hero: Dictionary in sim.heroes: hero.attack_timer = 999.0
	return sim

func _initialize() -> void:
	var sim = Sim.new(1)
	check(not sim.v2_mode and sim.run_state == null, "legacy has no v2 run state")
	check(sim.base_hp == 100 and sim.base_max_hp == 100, "legacy base matches RewardBook repair ceiling")
	check(grant(sim, "alchemy"), "legacy two-argument take accepts actual card")
	check(sim.state == "between" and is_equal_approx(sim.vapor_multiplier, 1.75), "legacy card modifies real multiplier once")
	check(not sim.choose_reward(0), "legacy repeated choice cannot grant twice")
	var enemy: Dictionary = sim.spawn_enemy(Vector2(900, 360))
	sim.apply_hit(enemy, 1.0, "water")
	var vapor_damage: float = sim.apply_hit(enemy, 20.0, "fire")
	check(is_equal_approx(vapor_damage, 35.0 * 100.0 / (100.0 + enemy.armor)), "legacy alchemy real damage includes current armor")
	print("LEGACY_VAPOR damage=%s armor=%s multiplier=%s" % [vapor_damage, enemy.armor, sim.vapor_multiplier])
	sim = active_sim()
	check(grant(sim, "burst"), "legacy burst card grants")
	sim.state = "running"
	enemy = sim.spawn_enemy(Vector2(470, 295))
	var neighbor: Dictionary = sim.spawn_enemy(Vector2(485, 295))
	var distant: Dictionary = sim.spawn_enemy(Vector2(800, 295))
	sim.projectiles.append({"pos": enemy.pos + Vector2(0, -12), "target_id": enemy.id, "damage": 20.0, "element": "fire", "source_id": 1, "splash": true, "slow": false})
	sim.tick(0.01)
	var splash_damage: float = neighbor.max_hp - neighbor.hp
	check(is_equal_approx(splash_damage, 10.0 * 100.0 / (100.0 + neighbor.armor)), "legacy burst real neighbor damage includes current armor")
	check(distant.hp == distant.max_hp and neighbor.aura == "", "legacy burst neither hits distant enemy nor attaches recursive aura")
	print("LEGACY_BURST neighbor_damage=%s armor=%s" % [splash_damage, neighbor.armor])
	sim = active_sim()
	check(grant(sim, "sweep"), "legacy sweep card grants")
	sim.state = "running"
	sim.heroes[0].attack_timer = 0.0
	enemy = sim.spawn_enemy(Vector2(555, 360))
	neighbor = sim.spawn_enemy(Vector2(575, 360))
	sim.tick(0.01)
	check(sim.shots_fired == 1 and not sim.pending_impacts.is_empty(), "legacy attack safely schedules its animation impact without run_state")
	check(enemy.hp == enemy.max_hp, "legacy attack honors animation hit delay")
	print("LEGACY_SWEEP pending=%s after_01=%s" % [sim.pending_impacts, neighbor.max_hp - neighbor.hp])
	for index in 80: sim.tick(0.01)
	check(enemy.hp < enemy.max_hp and neighbor.hp < neighbor.max_hp, "legacy cleave damages primary and nearby enemy at actual hit frame")
	sim = Sim.new(1)
	sim.base_hp = 65
	check(grant(sim, "repair") and sim.base_hp == 95, "legacy repair restores actual 30 HP")
	sim.reset(1)
	check(sim.base_hp == 100 and sim.base_max_hp == 100 and sim.rewards.history.is_empty(), "legacy reset clears progression at legacy repair ceiling")
	var v2 = Sim.new(1, true)
	v2.reset_stage("stage_01")
	check(v2.v2_mode and v2.base_hp == 12 and v2.base_max_hp == 12, "v2 stage HP remains unchanged at 12")
	var report := {"checks": checks, "failures": failures, "failure_count": failures.size()}
	var file := FileAccess.open("res://../qa/performance-20261006/legacy-compatibility-correctness.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
