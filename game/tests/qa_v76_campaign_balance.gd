extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var sim = Sim.new(7601, true)
	sim.reset_stage("stage_01", ["traveler"], 7601)

	var cards: Dictionary = {}
	for card: Dictionary in sim.database.cards:
		cards[str(card.get("id", ""))] = card
	var expected_values := {
		"single_speed_common": 0.2,
		"single_speed_legendary": 1.2,
		"global_speed_1": 0.2,
		"global_speed_legendary": 1.2,
		"v75_multishot_training": 1.0,
		"v75_expanded_magazine": 2.0,
		"v75_armor_piercing_round": 1.0,
		"mechanic_twin_arc": 1.0,
		"mechanic_prism_fan": 2.0,
		"mechanic_piercing_edge": 1.0,
		"v75_triple_loading": 3.0,
		"v75_piercing_barrage": 2.0,
		"lethal_tempo": 0.12,
	}
	for card_id: String in expected_values:
		if not cards.has(card_id) or not is_equal_approx(float(cards[card_id].get("value", -1.0)), float(expected_values[card_id])):
			failures.append("card balance mismatch: %s" % card_id)

	sim.wave = 1
	var early := sim.spawn_enemy(Vector2(1120, 270), "grunt")
	sim.wave = 10
	var late := sim.spawn_enemy(Vector2(1120, 360), "grunt")
	var expected_hp_ratio := pow(Sim.CAMPAIGN_MINION_HEALTH_GROWTH, 9)
	var expected_damage_ratio := pow(Sim.CAMPAIGN_MINION_DAMAGE_GROWTH, 9)
	if int(early.get("level", 0)) != 1 or int(late.get("level", 0)) != 10:
		failures.append("campaign enemy level does not follow wave")
	if not is_equal_approx(float(late.hp) / float(early.hp), expected_hp_ratio):
		failures.append("campaign minion HP curve mismatch")
	if not is_equal_approx(float(late.damage) / float(early.damage), expected_damage_ratio):
		failures.append("campaign minion damage curve mismatch")

	sim.wave = 15
	var boss := sim.spawn_enemy(Vector2(1120, 450), "boss_01")
	var stage_health := float(sim.stage_runtime.definition.get("enemy_health_multiplier", 1.0))
	var stage_boss_health := float(sim.stage_runtime.definition.get("boss_health_multiplier", 1.0))
	var stage_damage := float(sim.stage_runtime.definition.get("enemy_damage_multiplier", 1.0))
	var boss_base: Dictionary = Catalog.ENEMIES["boss_01"]
	var expected_boss_hp := float(boss_base.hp) * 1.40 * 3.0 * Sim.CAMPAIGN_BOSS_HEALTH_MULTIPLIER * stage_health * stage_boss_health
	var expected_boss_damage := float(boss_base.damage) * Sim.CAMPAIGN_BOSS_DAMAGE_MULTIPLIER * stage_damage
	if not is_equal_approx(float(boss.hp), expected_boss_hp):
		failures.append("campaign boss HP is not strengthened by 2.5x")
	if not is_equal_approx(float(boss.damage), expected_boss_damage):
		failures.append("campaign boss damage is not strengthened by 2.5x")

	if failures.is_empty():
		print("V76 CAMPAIGN BALANCE PASS")
	else:
		for failure: String in failures:
			push_error(failure)
		print("V76 CAMPAIGN BALANCE FAIL: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
