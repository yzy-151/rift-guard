extends SceneTree

const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")

func _initialize() -> void:
	var db = Database.new()
	var run = RunState.new()
	assert(run.set_squad(["traveler"]))
	run.crystal_level = 2
	var pool = CardPool.new(db.cards, 42)
	var first: Array[Dictionary] = pool.draw_three(run)
	assert(first.size() == 3)
	assert(first.any(func(card): return card.effect == "assign_traveler_element"))
	assert(first.all(func(card): return card.get("target", "global") == "global" or card.character_id == "traveler"))
	assert(pool.apply_card(first.filter(func(card): return card.effect == "assign_traveler_element")[0], run))
	var chosen_element: String = run.traveler_element
	assert(chosen_element in ["anemo", "electro", "pyro", "hydro", "geo", "cryo"])
	for seed_value in 100:
		pool.reseed(seed_value)
		var offer: Array[Dictionary] = pool.draw_three(run)
		assert(offer.size() == 3)
		var unique_ids: Dictionary = {}
		for card: Dictionary in offer:
			unique_ids[card.id] = true
		assert(unique_ids.size() == 3)
		assert(offer.all(func(card): return card.get("effect", "") != "assign_traveler_element"))
		assert(offer.all(func(card): return card.get("target", "global") == "global" or card.character_id == "traveler"))
		assert(offer.all(func(card): return card.get("requires_element", chosen_element) == chosen_element))
	assert(not pool.apply_element(run, "geo" if chosen_element != "geo" else "pyro"))
	print("CARD POOL V2 PASSED")
	quit()
