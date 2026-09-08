extends RefCounted

const ELEMENTS := ["anemo", "electro", "pyro", "hydro", "geo", "cryo"]

var cards: Array[Dictionary] = []
var offered: Array[Dictionary] = []
var history: Array[String] = []
var levels: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init(source_cards: Array[Dictionary], seed_value: int = 0) -> void:
	cards.assign(source_cards)
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	rng.seed = seed_value

func eligible(card: Dictionary, run) -> bool:
	if card.get("target", "global") == "character" and not _character_is_present(str(card.get("character_id", "")), run):
		return false
	if card.get("effect", "") == "assign_traveler_element":
		return run.traveler_element == "none"
	if card.get("effect", "") == "deploy_reinforcement":
		return run.squad.size() + _reinforcement_count(run) < run.MAX_SQUAD_SIZE and int(run.buff_levels.get(card.id, 0)) == 0
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

func _character_is_present(character_id: String, run) -> bool:
	if character_id in run.squad:
		return true
	for card: Dictionary in cards:
		if card.get("effect", "") == "deploy_reinforcement" and str(card.get("value", "")) == character_id and int(run.buff_levels.get(card.id, 0)) > 0:
			return true
	return false

func _reinforcement_count(run) -> int:
	var count := 0
	for card: Dictionary in cards:
		if card.get("effect", "") == "deploy_reinforcement" and int(run.buff_levels.get(card.id, 0)) > 0:
			count += 1
	return count

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
	if run.crystal_level % 3 == 0:
		var mechanic_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if bool(card.get("mechanic", false)):
				mechanic_cards.append(card)
		if not mechanic_cards.is_empty():
			var guaranteed_mechanic: Dictionary = _take_weighted(mechanic_cards)
			offered.append(guaranteed_mechanic.duplicate(true))
			candidates.erase(guaranteed_mechanic)
	while offered.size() < 3 and not candidates.is_empty():
		var selected: Dictionary = _take_weighted(candidates)
		offered.append(selected.duplicate(true))
		candidates.erase(selected)
	return offered.duplicate(true)

func draw(sim) -> void:
	draw_three(sim.run_state)

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

func take(index: int, sim) -> bool:
	if index < 0 or index >= offered.size():
		return false
	var card: Dictionary = offered[index]
	if not apply_card(card, sim.run_state):
		return false
	levels = sim.run_state.buff_levels
	history.append(str(card.get("name", card.id)))
	sim.apply_v2_card_effect(card)
	return true

func preview(card: Dictionary, sim) -> String:
	var value: Variant = card.get("value", 0)
	match str(card.get("effect", "")):
		"assign_traveler_element": return "旅行者本关获得%s元素" % sim.element_name(str(value))
		"attack_multiplier": return "攻击力 +%d%%" % roundi(float(value) * 100.0)
		"health_multiplier": return "最大生命 +%d%%" % roundi(float(value) * 100.0)
		"attack_rate_multiplier": return "攻击速度 +%d%%" % roundi(float(value) * 100.0)
		"range_flat": return "攻击范围 +%d" % int(value)
		"armor_flat": return "防御 +%d" % int(value)
		"move_speed_flat": return "移动速度 +%d" % int(value)
		"squad_attack_multiplier": return "全队攻击 +%d%%" % roundi(float(value) * 100.0)
		"squad_health_multiplier": return "全队最大生命 +%d%%" % roundi(float(value) * 100.0)
		"squad_rate_multiplier": return "全队攻击速度 +%d%%" % roundi(float(value) * 100.0)
		"projectile_count_add": return "每次攻击弹道 +%d" % int(value)
		"pierce_add": return "贯穿次数 +%d" % int(value)
		"chain_add": return "连锁目标 +%d" % int(value)
		"blast_add": return "爆炸半径 +%d" % int(value)
		"echo_add": return "追击伤害 +%d%%" % roundi(float(value) * 100.0)
		"skill_power_add": return "旅行者战技威力 +%d%%" % roundi(float(value) * 100.0)
		"skill_cooldown_add": return "旅行者战技冷却 -%d%%" % roundi(float(value) * 100.0)
		"skill_area_add": return "旅行者战技范围 +%d%%" % roundi(float(value) * 100.0)
		"skill_duration_add": return "旅行者持续战技时间 +%d%%" % roundi(float(value) * 100.0)
		"reaction_damage_add": return "元素反应伤害 +%d%%" % roundi(float(value) * 100.0)
		"reaction_radius_add": return "元素反应范围 +%d" % int(value)
		"support_barrage", "support_crossfire", "support_heal", "support_finale": return "自动支援已接入，可重复强化"
		"deploy_reinforcement": return "立即增加1名场上角色"
		"execute_threshold_add": return "处决线 +%d%%" % roundi(float(value) * 100.0)
		"death_burst_add": return "死亡爆破 +%d%%最大生命" % roundi(float(value) * 100.0)
		"elite_damage_add": return "精英伤害 +%d%%" % roundi(float(value) * 100.0)
		"kill_frenzy_add": return "每10击杀攻速成长 +%d%%" % roundi(float(value) * 100.0)
	return str(card.get("description", "获得强化"))
