extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")
const CardEffects = preload("res://scripts/rewards/combat_card_effects.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("GALIO PASS: " + message)
	else:
		failures += 1
		push_error("GALIO FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(92274, true)
	sim.reset_stage("stage_03", ["traveler", "hero_01", "hero_04"], 92274)
	sim.start()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	for index in sim.heroes.size():
		var hero: Dictionary = sim.heroes[index]
		hero.deployed = true
		hero.pos = Vector2(440.0 + index * 90.0, 320.0 + index * 55.0)
		hero.target = hero.pos
		hero.hp = 10000.0
		hero.max_hp = 10000.0
	check(Catalog.ENEMIES.has("boss_galio"), "Galio catalog entry exists")
	check(sim.database.boss_patterns.has("boss_galio"), "Galio owns a data-driven move pattern")
	var kindred: Dictionary = sim.spawn_enemy(Vector2(930, 355), "boss_03")
	kindred.shield = 0.0
	kindred.hp = float(kindred.max_hp) * 0.099
	sim._enemy_tick(0.02)
	var galios: Array = sim.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.get("kind", "")) == "boss_galio")
	check(galios.size() == 1, "Kindred at ten percent summons Galio once")
	check(float(kindred.shield) >= float(kindred.max_hp) * 0.299, "Hero's Entrance shields Kindred for thirty percent")
	if not galios.is_empty():
		var galio: Dictionary = galios[0]
		check(float(galio.hp) > 0.0 and int(galio.id) != int(kindred.id), "Galio has independent health and identity")
		check(not bool(galio.get("galio_revealed", true)), "Galio stays hidden during the surprise entrance")
		check(Vector2(galio.galio_target).distance_to(Vector2(kindred.pos)) < 150.0, "Hero Entrance lands beside Kindred")
		check(float(galio.special_warning_radius) >= 500.0, "Hero Entrance shockwave radius is doubled")
		for move in ["galio_entrance", "galio_punch", "galio_winds", "galio_durand"]:
			sim.enemy_projectiles.clear()
			sim.enemy_hazards.clear()
			sim.drain_events()
			sim._start_galio_warning(galio, move)
			sim._execute_galio_special(galio, move)
			check(sim.drain_events().any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == move), "Galio resolves " + move)
			if move == "galio_entrance":
				check(bool(galio.get("galio_revealed", false)), "Galio becomes visible only after landing")
			if move == "galio_winds":
				check(float(galio.special_warning_radius) <= 175.0 and not sim.enemy_hazards.is_empty() and float(sim.enemy_hazards[0].get("delay", 0.0)) > 0.0, "Winds of War travels before creating its smaller vortex")
		galio.hp = 0.0
		kindred.hp = 1.0
		check(sim.enemies.any(func(enemy: Dictionary) -> bool: return float(enemy.get("hp", 0.0)) > 0.0 and str(enemy.get("kind", "")).begins_with("boss_")), "stage remains gated while either boss lives")
	check(not sim.deployment_slot_unlocked(2), "third slot remains locked at level five")
	sim.run_state.crystal_level = 6
	check(sim.deployment_slot_unlocked(2), "third slot unlocks at level six")
	var base_thresholds: Array = [65,140,235,350,500,690,930,1300,1900,2850,4250,6300,9300,13700,20000]
	check(sim.crystal.thresholds[5] == roundi(base_thresholds[5] * 0.8) and sim.crystal.thresholds[9] == roundi(base_thresholds[9] * 0.65), "campaign XP curve drops twenty then thirty-five percent")
	sim.run_state.buff_levels["solo_leveling"] = 2
	var xp_before := int(sim.run_state.crystal_xp)
	sim.grant_xp(5)
	check(int(sim.run_state.crystal_xp) - xp_before == 45, "Solo Leveling triples XP per stack")
	var hero := {"id":0,"hp":100.0,"max_hp":100.0,"rate":1.0,"base_rate":1.0}
	CardEffects.apply_to_hero(hero, "heartsteel")
	CardEffects.on_target(hero, {"id":9922})
	check(is_equal_approx(float(hero.max_hp), 104.0), "Heartsteel grants four max health")
	check(is_equal_approx(float(Catalog.ENEMIES.boss_01.damage), 375.0), "Rift Lord base damage is tripled")
	print("GALIO QA COMPLETE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
