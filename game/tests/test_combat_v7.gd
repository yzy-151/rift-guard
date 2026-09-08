extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("V7 COMBAT PASS: " if ok else "V7 COMBAT FAIL: ") + message)

func card(id: String, effect: String, character_id: String) -> Dictionary:
	return {"id": id, "effect": effect, "target": "character", "character_id": character_id, "value": true}

func _initialize() -> void:
	var Sim = preload("res://scripts/combat_simulation.gd")
	var hydro_squad: Array[String] = ["traveler", "hero_03", "hero_04"]
	var sim = Sim.new(808, true)
	sim.reset_stage("stage_03", hydro_squad, 808)
	sim.heroes[0].hp -= 80.0
	sim.heroes[1].heal_timer = 0.0
	sim._hero_tick()
	check(sim.heroes[0].hp > sim.heroes[0].max_hp - 80.0, "Furina heals with normalized hydro element")
	var old_heal: float = sim.heroes[1].heal_power
	sim.apply_v2_card_effect(card("furina_special", "special_upgrade", "hero_03"))
	check(sim.heroes[1].heal_power == old_heal + 18.0, "Furina epic card improves healing")
	sim.apply_v2_card_effect(card("keqing_signature", "signature_upgrade", "hero_04"))
	check(sim.heroes[2].chain_count == 4, "Keqing legendary card creates four-target chain lightning")

	var burst_squad: Array[String] = ["traveler", "hero_02", "hero_05"]
	sim.reset_stage("stage_03", burst_squad, 809)
	sim.apply_v2_card_effect(card("yoimiya_signature", "signature_upgrade", "hero_02"))
	sim.apply_v2_card_effect(card("ganyu_signature", "signature_upgrade", "hero_05"))
	check(sim.heroes[1].projectile_count == 3 and sim.heroes[1].blast_radius >= 82.0, "Yoimiya legendary card adds explosive multishot")
	check(sim.heroes[2].blast_radius >= 125.0, "Ganyu legendary card creates large frost bursts")

	sim.state = "running"
	sim.enemies.clear()
	for i in 10:
		var enemy: Dictionary = sim.spawn_enemy(Vector2(760 + i, 360), "runner")
		enemy.hp = 1.0
		sim.apply_hit(enemy, 999.0, "")
	check(sim.kill_streak == 10 and sim.best_streak == 10, "ten rapid kills build a persistent combat streak")
	check(sim.events.any(func(event): return event.kind == "kill_streak" and int(event.value) == 10), "streak milestone emits a visual impact event")
	sim.tick(2.6)
	check(sim.kill_streak == 0, "streak expires after its combat window")
	print("V7 COMBAT TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
