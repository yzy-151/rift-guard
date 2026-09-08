extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("SKILL PASS: " if ok else "SKILL FAIL: ") + message)

func make_sim(element: String):
	var sim = Sim.new(700, true)
	sim.start()
	sim.heroes[0].element = "" if element == "none" else element
	sim.run_state.traveler_element = element
	sim.enemies.clear()
	sim.events.clear()
	return sim

func _initialize() -> void:
	var no_element = make_sim("none")
	var sword_enemy: Dictionary = no_element.spawn_enemy(Vector2(720, 360), "grunt")
	var sword_x: float = sword_enemy.pos.x
	check(no_element.activate_traveler_skill(Vector2(720, 360)), "no-element sword wave casts")
	check(sword_enemy.hp < sword_enemy.max_hp and sword_enemy.pos.x > sword_x, "sword wave damages and knocks back")
	check(not no_element.activate_traveler_skill(Vector2(720, 360)), "cooldown blocks repeated cast")

	var anemo = make_sim("anemo")
	var wind_enemy: Dictionary = anemo.spawn_enemy(Vector2(720, 360), "grunt")
	var wind_x: float = wind_enemy.pos.x
	check(anemo.activate_traveler_skill(Vector2(720, 360)) and anemo.skill_effects.size() == 1, "anemo creates persistent tornado")
	anemo.tick(0.45)
	check(wind_enemy.hp < wind_enemy.max_hp and wind_enemy.pos.x > wind_x, "tornado damages and pushes enemies away")

	var electro = make_sim("electro")
	for i in 10:
		electro.spawn_enemy(Vector2(650 + i * 18, 340 + (i % 2) * 35), "grunt")
	check(electro.activate_traveler_skill(Vector2(720, 360)), "electro chain skill casts")
	check(electro.enemies.filter(func(e: Dictionary) -> bool: return e.hp < e.max_hp).size() == 8, "electro strikes up to eight targets")

	var pyro = make_sim("pyro")
	var fire_near: Dictionary = pyro.spawn_enemy(Vector2(720, 360), "armored")
	var fire_far: Dictionary = pyro.spawn_enemy(Vector2(1060, 360), "armored")
	pyro.activate_traveler_skill(Vector2(720, 360))
	check(fire_near.hp < fire_near.max_hp and fire_far.hp == fire_far.max_hp, "pyro burst respects impact radius")

	var hydro = make_sim("hydro")
	hydro.heroes[0].hp = 120.0
	hydro.base_hp = 70
	hydro.activate_traveler_skill(Vector2(720, 360))
	check(hydro.heroes[0].hp > 120.0 and hydro.base_hp == 82, "hydro heals squad and repairs base")
	check(hydro.skill_effects[0].kind == "hydro_field", "hydro leaves an application field")

	var geo = make_sim("geo")
	geo.activate_traveler_skill(Vector2(720, 360))
	check(geo.geo_constructs.size() == 1 and geo.geo_constructs[0].hp == 620.0, "geo places a destructible construct")
	geo.damage_construct(1, 700.0)
	check(geo.geo_constructs[0].hp == 0.0, "enemy damage can break geo construct")

	var cryo = make_sim("cryo")
	var ice_enemy: Dictionary = cryo.spawn_enemy(Vector2(720, 360), "shielded")
	cryo.activate_traveler_skill(Vector2(720, 360))
	check(ice_enemy.slow_timer >= 5.0 and cryo.skill_effects[0].kind == "cryo_field", "cryo creates a long freeze field")

	print("TRAVELER SKILL TESTS: %d checks; %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
