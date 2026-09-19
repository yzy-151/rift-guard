extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(391, true)
	sim.reset_stage("stage_endless", ["traveler"], 391)
	var failures: Array[String] = []
	for phase in range(5):
		var pool: Array[String] = sim._endless_enemy_pool(phase)
		if phase < 3 and ("shielded" in pool or "hilichurl_brute" in pool):
			failures.append("heavy monster appears before boss three")
		if phase == 0 and ("buffer" in pool or "charger" in pool or "armored" in pool):
			failures.append("midgame monster appears in opening pool")
		if phase >= 3 and ("shielded" not in pool or "hilichurl_brute" not in pool):
			failures.append("heavy monsters absent after boss three")
	for number in range(1, 6):
		var expected_health: Array[float] = [1.0, 3.0, 5.0, 20.0, 50.0]
		var expected_damage: Array[float] = [1.0, 10.0, 20.0, 30.0, 100.0]
		var actual: Vector2 = sim._endless_boss_multipliers(number)
		if not is_equal_approx(actual.x, expected_health[number - 1]) or not is_equal_approx(actual.y, expected_damage[number - 1]):
			failures.append("boss %d multiplier mismatch" % number)
	sim.endless_boss_index = 2
	sim.elapsed = 280.0
	var before_level := sim._endless_enemy_level(sim._endless_tier())
	sim.endless_boss_index = 4
	sim.elapsed = 520.0
	var after_level := sim._endless_enemy_level(sim._endless_tier())
	if after_level <= before_level:
		failures.append("enemy level does not rise across bosses")
	var enemy: Dictionary = sim.spawn_enemy(Vector2(150, 300), "shielded")
	var base_hp: float = enemy.hp
	var base_damage: float = enemy.damage
	sim._apply_endless_scaling(enemy, sim._endless_tier())
	var scales: Dictionary = sim._endless_enemy_scales(sim._endless_tier())
	if not is_equal_approx(enemy.hp, base_hp * float(scales.health) * 10.0):
		failures.append("late shielded HP lacks 10x elite multiplier")
	if not is_equal_approx(enemy.damage, base_damage * float(scales.damage) * 50.0):
		failures.append("late shielded attack lacks 50x elite multiplier")
	if int(enemy.get("level", 0)) != after_level:
		failures.append("elite has no visible level")
	for phase in range(4):
		sim.enemies.clear()
		sim.enemy_lookup.clear()
		sim.endless_boss_index = phase
		sim.endless_next_boss_at = 90.0 + phase * 105.0
		sim.elapsed = sim.endless_next_boss_at
		sim._spawn_endless_boss_if_due()
		if sim.endless_boss_index != phase + 1 or sim.enemies.size() != 1:
			failures.append("boss %d did not spawn" % (phase + 1))
			continue
		var boss: Dictionary = sim.enemies[0]
		var baseline: Dictionary = Catalog.ENEMIES[str(boss.kind)]
		if float(boss.hp) < float(baseline.hp) * sim._endless_boss_multipliers(phase + 1).x:
			failures.append("boss %d HP not scaled" % (phase + 1))
		if int(boss.get("level", 0)) <= 0:
			failures.append("boss %d has no level" % (phase + 1))
	if failures.is_empty():
		print("ENDLESS CURVE PASS: staged roster, five boss multipliers, elite and enemy levels")
	else:
		for failure: String in failures:
			push_error(failure)
		print("ENDLESS CURVE FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
