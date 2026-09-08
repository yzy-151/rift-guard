extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func make_sim():
	var sim = Sim.new(606, true)
	sim.start()
	sim.enemies.clear()
	sim.events.clear()
	return sim

func _card(sim, id: String) -> Dictionary:
	return sim.database.cards.filter(func(card): return card.id == id)[0]

func _initialize() -> void:
	var sim = make_sim()
	var forward: Dictionary = sim.spawn_enemy(Vector2(900, 360), "armored")
	sim.apply_hit(forward, 1.0, "pyro")
	var hydro_damage: float = sim.apply_hit(forward, 100.0, "hydro")
	var reverse: Dictionary = sim.spawn_enemy(Vector2(930, 360), "armored")
	sim.apply_hit(reverse, 1.0, "hydro")
	var pyro_damage: float = sim.apply_hit(reverse, 100.0, "pyro")
	assert(hydro_damage > pyro_damage * 1.30, "hydro on pyro must use the stronger vaporize direction")

	var frozen: Dictionary = sim.spawn_enemy(Vector2(1000, 450), "armored")
	sim.apply_hit(frozen, 1.0, "hydro")
	sim.apply_hit(frozen, 1.0, "cryo")
	var frozen_x: float = frozen.pos.x
	sim.tick(0.5)
	assert(frozen.frozen_timer > 0.0 and is_equal_approx(frozen.pos.x, frozen_x), "freeze fully stops ground enemies")
	var health_before_shatter: float = frozen.hp
	sim.apply_hit(frozen, 60.0, "")
	assert(frozen.hp < health_before_shatter and frozen.frozen_timer == 0.0, "physical damage shatters frozen enemies")

	var crystal: Dictionary = sim.spawn_enemy(Vector2(850, 270), "grunt")
	sim.apply_hit(crystal, 1.0, "pyro")
	sim.apply_hit(crystal, 40.0, "geo")
	assert(sim.crystal_shield > 0.0, "crystallize grants a shared squad shield")
	var hero_hp: float = sim.heroes[0].hp
	sim.damage_hero(0, 20.0)
	assert(sim.heroes[0].hp == hero_hp, "crystal shield absorbs hero damage first")

	var swirl_main: Dictionary = sim.spawn_enemy(Vector2(760, 360), "grunt")
	var swirl_near: Dictionary = sim.spawn_enemy(Vector2(820, 360), "grunt")
	sim.apply_hit(swirl_main, 1.0, "pyro")
	sim.apply_hit(swirl_main, 20.0, "anemo")
	assert(swirl_near.aura == "pyro" or swirl_near.hp < swirl_near.max_hp, "swirl spreads the absorbed element nearby")

	var healer: Dictionary = sim.spawn_enemy(Vector2(920, 360), "healer")
	var wounded: Dictionary = sim.spawn_enemy(Vector2(950, 360), "armored")
	wounded.hp -= 70.0
	healer.special_timer = 0.0
	var wounded_before: float = wounded.hp
	sim.tick(0.01)
	assert(wounded.hp > wounded_before, "healer restores nearby enemies")
	var warder: Dictionary = sim.spawn_enemy(Vector2(930, 360), "warder")
	warder.special_timer = 0.0
	sim.tick(0.01)
	assert(wounded.shield > 0.0, "warder grants nearby enemies shields")
	var splitter: Dictionary = sim.spawn_enemy(Vector2(870, 360), "splitter")
	var count_before: int = sim.enemies.size()
	sim.apply_hit(splitter, 100000.0, "")
	assert(sim.enemies.size() == count_before + 2, "splitter releases two runners on death")

	var run = sim.run_state
	run.traveler_element = "pyro"
	var power: Dictionary = _card(sim, "pyro_skill_power_add")
	assert(sim.card_pool.eligible(power, run), "matching elemental skill card is eligible")
	for stack in 4:
		assert(sim.card_pool.apply_card(power, run))
		sim.apply_v2_card_effect(power)
	assert(sim.skill_power_bonus > 0.70 and run.buff_levels[power.id] == 4, "elemental cards stack without a layer cap")
	assert(not sim.card_pool.eligible(_card(sim, "hydro_skill_power_add"), run), "other element cards stay out of the locked pool")
	assert(sim.database.cards.size() >= 150, "card pool supports a full five-minute build")
	print("COMBAT V6 PASSED: reactions, enemy roles, and %d cards" % sim.database.cards.size())
	quit()
