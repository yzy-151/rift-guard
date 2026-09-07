extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const Book = preload("res://scripts/reward_book.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, text: String) -> void:
	checks += 1
	if ok: print("PASS: " + text)
	else:
		failures += 1
		push_error("FAIL: " + text)

func grant(s, id: String) -> bool:
	s.state = "reward"
	for card in Book.CARDS:
		if card.id == id:
			s.rewards.offered.assign([card.duplicate(true)])
			return s.choose_reward(0)
	return false

func ids(s) -> Array:
	return s.rewards.offered.map(func(c: Dictionary): return c.id)

func _initialize() -> void:
	check(Book.CARDS.size() == 18, "eighteen primary upgrades")
	var s = Sim.new(42)
	var valid: bool = true
	for seed_value in 100:
		s = Sim.new(seed_value)
		s.rewards.draw(s)
		var chosen: Array = ids(s)
		valid = valid and chosen.size() == 3 and chosen[0] != chosen[1] and chosen[0] != chosen[2] and chosen[1] != chosen[2] and not chosen.has("repair")
		for card in s.rewards.offered:
			valid = valid and s.rewards.eligible(card, s)
	check(valid, "100 seeds produce three unique eligible rewards without full-HP repair")
	var recovery: Dictionary = Book.CARDS.filter(func(card: Dictionary) -> bool: return card.id == "recovery")[0]
	s.wave = 3
	check(s.rewards.eligible(recovery, s), "regroup healing remains useful at node three")
	s.wave = 4
	check(not s.rewards.eligible(recovery, s), "last reward excludes future regroup healing")
	var last_valid: bool = true
	for value in 100:
		s = Sim.new(value)
		s.wave = 4
		s.rewards.draw(s)
		last_valid = last_valid and not ids(s).has("recovery")
	check(last_valid, "100 final-node draws contain no ineffective regroup card")
	var a = Sim.new(123)
	var b = Sim.new(123)
	a.rewards.draw(a)
	for i in 500: randf()
	b.rewards.draw(b)
	check(ids(a) == ids(b), "dedicated seeded reward stream ignores other RNG")
	s = Sim.new(4)
	for card in Book.CARDS: s.rewards.levels[card.id] = card.max
	s.rewards.draw(s)
	check(ids(s).all(func(id): return str(id).begins_with("reserve_")) and ids(s).size() == 3, "exhausted main pool gets three distinct fallback upgrades")
	var fallback_before: float = s.heroes[0].damage
	s.state = "reward"
	var fallback_index: int = ids(s).find("reserve_attack")
	check(s.choose_reward(fallback_index) and s.heroes[0].damage == fallback_before + 3, "fallback has a real effect")
	s = Sim.new(9)
	s.start()
	s.spawn_remaining = 0
	s.heroes[0].hp = 0
	s.tick(0.01)
	check(s.state == "reward" and s.rewards.offered.size() == 3 and s.heroes[0].hp == 140, "clear node restores squad then opens rewards")
	var before: Array = [s.elapsed, s.heroes[1].attack_timer, s.heroes[1].pos, s.wave]
	s.tick(30)
	s.command_move(1, Vector2(500, 500))
	s.toggle_pause()
	check(before == [s.elapsed, s.heroes[1].attack_timer, s.heroes[1].pos, s.wave] and s.state == "reward", "reward state freezes time, movement and cannot be skipped by pause")
	check(not s.choose_reward(-1) and not s.choose_reward(3) and s.rewards.offered.size() == 3, "invalid choice leaves offer intact")
	check(s.choose_reward(0) and s.state == "between", "valid reward resumes through regroup")
	var count: int = s.rewards.history.size()
	check(not s.choose_reward(0) and s.rewards.history.size() == count, "double choice cannot grant twice")
	s = Sim.new(1)
	grant(s, "bulwark")
	check(s.heroes[0].block == 3, "bulwark changes block capacity")
	s.rewards.draw(s)
	check(not ids(s).has("bulwark"), "capped upgrade removed from subsequent offers")
	s = Sim.new(1)
	grant(s, "alchemy")
	s.start()
	var e = s.spawn_enemy(Vector2(900, 360))
	s.apply_hit(e, 1, "water")
	check(is_equal_approx(s.apply_hit(e, 20, "fire"), 35), "alchemy increases actual vaporize damage")
	s = Sim.new(1)
	grant(s, "burst")
	s.state = "running"
	s.wave = 1
	s.spawn_remaining = 1
	s.spawn_timer = 999
	for h in s.heroes: h.attack_timer = 999
	e = s.spawn_enemy(Vector2(600, 295))
	var neighbor = s.spawn_enemy(Vector2(615, 295))
	var distant = s.spawn_enemy(Vector2(800, 295))
	s.projectiles.append({"pos": e.pos + Vector2(0, -12), "target_id": e.id, "damage": 20.0, "element": "fire", "source_id": 1, "splash": true, "slow": false})
	s.tick(0.01)
	check(is_equal_approx(neighbor.hp, neighbor.max_hp - 10) and distant.hp == distant.max_hp and neighbor.aura == "", "burst hits only nearby others and does not recursively attach fire")
	s = Sim.new(1)
	grant(s, "sweep")
	s.state = "running"
	s.wave = 1
	s.spawn_remaining = 1
	s.spawn_timer = 999
	for h in s.heroes: h.attack_timer = 999
	s.heroes[0].attack_timer = 0
	e = s.spawn_enemy(Vector2(555, 360))
	neighbor = s.spawn_enemy(Vector2(575, 360))
	s.tick(0.01)
	check(neighbor.hp < neighbor.max_hp and e.hp < e.max_hp, "cleave changes melee into area damage")
	s = Sim.new(1)
	grant(s, "chill")
	s.state = "running"
	s.wave = 1
	s.spawn_remaining = 1
	s.spawn_timer = 999
	for h in s.heroes: h.attack_timer = 999
	e = s.spawn_enemy(Vector2(800, 450), "runner")
	s.projectiles.append({"pos": e.pos + Vector2(0, -12), "target_id": e.id, "damage": 1.0, "element": "water", "source_id": 2, "splash": false, "slow": true})
	s.tick(0.01)
	var x: float = e.pos.x
	s.tick(0.1)
	check(is_equal_approx(x - e.pos.x, e.speed * 0.7 * 0.1), "water upgrade slows movement by 30 percent")
	s = Sim.new(1)
	grant(s, "mend")
	grant(s, "prayer")
	check(s.heal_amount == 32 and is_equal_approx(s.heal_interval, 2.1), "healing upgrades alter amount and interval")
	s.base_hp = 65
	grant(s, "repair")
	check(s.base_hp == 95, "repair restores base without exceeding cap")
	s = Sim.new(1)
	grant(s, "ember")
	var boosted: float = s.heroes[1].damage
	s.grant_xp(10000)
	check(s.team_level == 5 and is_equal_approx(s.heroes[1].damage, boosted + 32 * 0.08 * 4), "shared levels cap at five and add initial-stat growth without multiplying buffs")
	s.reset(1)
	check(s.team_level == 1 and s.team_xp == 0 and s.rewards.history.is_empty() and s.heroes[1].damage == 32 and s.vapor_multiplier == 1.5, "new run clears upgrades and progression")
	print("ALL %d REWARD TESTS PASSED" % checks if failures == 0 else "%d REWARD TESTS FAILED" % failures)
	quit(0 if failures == 0 else 1)
