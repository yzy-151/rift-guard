extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const Database = preload("res://scripts/content/game_database.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("V17 PASS: " if ok else "V17 FAIL: ") + message)

func make_endless(seed: int):
	var sim = Sim.new(seed, true)
	sim.reset_stage("stage_endless", ["traveler"], seed)
	sim.start()
	sim.enemies.clear()
	sim.events.clear()
	return sim

func _initialize() -> void:
	var boss_ids := ["boss_01", "boss_02", "boss_03", "boss_04", "boss_05", "boss_06"]
	var styles: Dictionary = {}
	for boss_id: String in boss_ids:
		check(Catalog.ENEMIES.has(boss_id), "%s exists in the enemy catalog" % boss_id)
		styles[str(Catalog.ENEMIES[boss_id].get("boss_style", ""))] = true
	check(styles.size() == 6, "six bosses use six distinct combat styles")

	var phase_sim = make_endless(1701)
	for boss_id: String in boss_ids:
		phase_sim.enemies.clear()
		var boss: Dictionary = phase_sim.spawn_enemy(Vector2(1800, 720), boss_id)
		boss.hp = boss.max_hp * 0.69
		phase_sim._update_boss_phase(boss)
		check(boss.boss_phase == 2, "%s enters phase two below seventy percent" % boss_id)
		boss.hp = boss.max_hp * 0.34
		phase_sim._update_boss_phase(boss)
		check(boss.boss_phase == 3, "%s enters phase three below thirty-five percent" % boss_id)

	var expected_events := {
		"boss_01": "boss_pulse", "boss_02": "boss_summon", "boss_03": "knockback",
		"boss_04": "enemy_guard", "boss_05": "enemy_shot", "boss_06": "enemy_heal"
	}
	for boss_id: String in boss_ids:
		var special_sim = make_endless(1800 + boss_ids.find(boss_id))
		var boss: Dictionary = special_sim.spawn_enemy(special_sim.heroes[0].pos + Vector2(260, 0), boss_id)
		boss.boss_phase = 3
		special_sim._execute_boss_special(boss)
		var expected: String = expected_events[boss_id]
		check(special_sim.events.any(func(event: Dictionary) -> bool: return event.kind == expected), "%s phase skill emits %s" % [boss_id, expected])

	var schedule_sim = make_endless(1901)
	schedule_sim.elapsed = 90.0
	schedule_sim.endless_spawn_timer = 99.0
	schedule_sim._endless_spawn_tick(0.0)
	check(schedule_sim.enemies.any(func(enemy: Dictionary) -> bool: return enemy.kind == "boss_01"), "first endless boss arrives at ninety seconds")
	check(schedule_sim.endless_next_boss_at == 195.0, "endless bosses repeat every one hundred five seconds")

	var density_sim = make_endless(1902)
	density_sim.endless_spawn_timer = 0.0
	density_sim._endless_spawn_tick(0.0)
	check(density_sim.enemies.size() >= 2, "endless starts with at least two enemies per spawn pulse")
	density_sim.run_state.crystal_level = 10
	var mid_threshold := density_sim.endless_next_threshold()
	density_sim.run_state.crystal_level = 25
	check(density_sim.endless_next_threshold() > mid_threshold * 6, "late endless card choices slow down sharply")

	var db = Database.new()
	check(float(db.stages.stage_01.enemy_health_multiplier) >= 1.10 and float(db.stages.stage_03.enemy_health_multiplier) >= 0.60, "campaign enemy health rises above V16 values")
	var thresholds: Array = db.stages.stage_01.xp_thresholds
	check(int(thresholds[-1]) > int(thresholds[0]) * 200, "campaign late card choices use a steep cumulative XP curve")

	print("V17 BOSS AND DIFFICULTY TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)