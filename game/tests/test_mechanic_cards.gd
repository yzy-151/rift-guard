extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func _card(sim, id: String) -> Dictionary:
	return sim.database.cards.filter(func(card): return card.id == id)[0]

func _initialize() -> void:
	var sim = Sim.new(811, true)
	var run = sim.run_state
	for id in ["mechanic_twin_arc", "mechanic_piercing_edge", "mechanic_chain_arc", "mechanic_blast_core", "mechanic_rapid_echo"]:
		var card: Dictionary = _card(sim, id)
		assert(sim.card_pool.apply_card(card, run))
		sim.apply_v2_card_effect(card)
	assert(sim.heroes[0].projectile_count == 2)
	assert(sim.heroes[0].pierce == 1)
	assert(sim.heroes[0].chain_count == 1)
	assert(sim.heroes[0].blast_radius == 18.0)
	assert(sim.heroes[0].echo_ratio > 0.34)
	var support: Dictionary = _card(sim, "support_red_moon")
	for layer in 3:
		assert(sim.card_pool.apply_card(support, run))
		sim.apply_v2_card_effect(support)
	assert(sim.supports.support_barrage.stacks == 3)
	assert(sim.supports.support_barrage.interval < 8.0)
	var reinforcement: Dictionary = _card(sim, "reinforcement_pyro")
	assert(sim.card_pool.apply_card(reinforcement, run))
	sim.apply_v2_card_effect(reinforcement)
	assert(sim.heroes.size() == 2)
	assert(run.squad == ["traveler"])
	assert(not sim.card_pool.eligible(reinforcement, run))
	sim.state = "running"
	var target: Dictionary = sim.spawn_enemy(Vector2(850, 360), "armored")
	var before: float = target.hp
	sim.supports.support_barrage.timer = 0.0
	sim.tick(0.01)
	assert(target.hp < before)
	assert(sim.events.any(func(event): return event.kind == "barrage"))
	print("MECHANIC CARDS PASSED")
	quit()
