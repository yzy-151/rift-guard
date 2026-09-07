extends RefCounted

const ELEMENTS := ["anemo", "electro", "pyro", "hydro", "geo", "cryo"]

var cards: Array[Dictionary] = []
var offered: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _init(source_cards: Array[Dictionary], seed_value: int = 0) -> void:
	cards.assign(source_cards)
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	rng.seed = seed_value

func eligible(card: Dictionary, run) -> bool:
	if card.get("target", "global") == "character" and str(card.get("character_id", "")) not in run.squad:
		return false
	if int(run.buff_levels.get(card.id, 0)) >= int(card.get("max_stacks", 1)):
		return false
	if card.get("rarity", "common") == "legendary" and run.legendary_count >= 2:
		return false
	if card.get("effect", "") == "assign_traveler_element":
		return run.traveler_element == "none"
	var required_element: String = str(card.get("requires_element", ""))
	if not required_element.is_empty() and required_element != run.traveler_element:
		return false
	for required_id: String in card.get("requires", []):
		if not run.buff_levels.has(required_id):
			return false
	for excluded_id: String in card.get("excludes", []):
		if run.buff_levels.has(excluded_id):
			return false
	return true

func draw_three(run) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for card: Dictionary in cards:
		if eligible(card, run):
			candidates.append(card)
	offered.clear()
	if run.crystal_level == 2 and run.traveler_element == "none":
		var element_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if card.get("effect", "") == "assign_traveler_element":
				element_cards.append(card)
		if not element_cards.is_empty():
			var guaranteed: Dictionary = _take_weighted(element_cards)
			offered.append(guaranteed.duplicate(true))
			candidates.erase(guaranteed)
	while offered.size() < 3 and not candidates.is_empty():
		var selected: Dictionary = _take_weighted(candidates)
		offered.append(selected.duplicate(true))
		candidates.erase(selected)
	return offered.duplicate(true)

func _take_weighted(pool: Array[Dictionary]) -> Dictionary:
	var total := 0
	for card: Dictionary in pool:
		total += maxi(1, int(card.get("weight", 1)))
	var roll := rng.randi_range(1, total)
	for card: Dictionary in pool:
		roll -= maxi(1, int(card.get("weight", 1)))
		if roll <= 0:
			return card
	return pool.back()

func apply_element(run, element: String) -> bool:
	if element not in ELEMENTS:
		return false
	if run.traveler_element != "none" and run.traveler_element != element:
		return false
	run.traveler_element = element
	return true

func apply_card(card: Dictionary, run) -> bool:
	if not eligible(card, run):
		return false
	if card.get("effect", "") == "assign_traveler_element" and not apply_element(run, str(card.value)):
		return false
	run.buff_levels[card.id] = int(run.buff_levels.get(card.id, 0)) + 1
	if card.get("rarity", "common") == "legendary":
		run.legendary_count += 1
	offered.clear()
	return true
