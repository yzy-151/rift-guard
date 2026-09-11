extends RefCounted

const MAX_SQUAD_SIZE := 3

var stage_id := ""
var mode_id := "rift_watch"
var squad: Array[String] = ["traveler"]
var traveler_element := "none"
var traveler_secondary_element := "none"
var buff_levels: Dictionary = {}
var crystal_level := 1
var crystal_xp := 0
var pending_level_ups := 0
var legendary_count := 0
var mythic_count := 0
var luck: float = 0.0
var equipped_relics: Dictionary = {}
var tag_counts: Dictionary = {}
var relationships: Dictionary = {}
var story_flags: Dictionary = {}
var current_node := "c1_combat_1"
var completed_nodes: Array[String] = []
var rift_shards := 0
var campaign_perks: Dictionary = {}
var resolved_nodes: Dictionary = {}
var rewarded_stages: Dictionary = {}
var active_resonances: Array[String] = []

func set_squad(ids: Array[String]) -> bool:
	if ids.is_empty() or ids.size() > MAX_SQUAD_SIZE:
		return false
	var seen: Dictionary = {}
	for id: String in ids:
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	squad = ids.duplicate()
	return true

func reset_run_meta() -> void:
	equipped_relics.clear()
	relationships.clear()
	story_flags.clear()
	current_node = "c1_combat_1"
	completed_nodes.clear()
	rift_shards = 0
	campaign_perks.clear()
	resolved_nodes.clear()
	rewarded_stages.clear()
	active_resonances.clear()

func reset_for_stage(next_stage_id: String) -> void:
	stage_id = next_stage_id
	traveler_element = "none"
	traveler_secondary_element = "none"
	buff_levels.clear()
	tag_counts.clear()
	crystal_level = 1
	crystal_xp = 0
	pending_level_ups = 0
	legendary_count = 0
	mythic_count = 0
	luck = 0.0

func grant_stage_reward(completed_stage_id: String, kills: int, remaining_base_hp: int, boss: bool = false) -> int:
	if rewarded_stages.has(completed_stage_id):
		return 0
	var amount := 24 + mini(45, maxi(0, kills) / 3) + maxi(0, remaining_base_hp) / 5 + (30 if boss else 0)
	rewarded_stages[completed_stage_id] = amount
	rift_shards += amount
	return amount

func spend_shards(amount: int) -> bool:
	if amount < 0 or rift_shards < amount:
		return false
	rift_shards -= amount
	return true

func add_campaign_perk(perk_id: String, amount: int = 1) -> int:
	campaign_perks[perk_id] = int(campaign_perks.get(perk_id, 0)) + amount
	return int(campaign_perks[perk_id])

func grant_relic(relic_id: String) -> bool:
	if relic_id.is_empty() or equipped_relics.has(relic_id):
		return false
	equipped_relics[relic_id] = true
	return true

func rebuild_tags(cards: Array[Dictionary]) -> void:
	tag_counts.clear()
	for card: Dictionary in cards:
		var level := int(buff_levels.get(str(card.get("id", "")), 0))
		if level <= 0:
			continue
		for tag: Variant in card.get("tags", []):
			var key := str(tag)
			tag_counts[key] = int(tag_counts.get(key, 0)) + level

func add_relationship(character_id: String, amount: int) -> int:
	relationships[character_id] = int(relationships.get(character_id, 0)) + amount
	return int(relationships[character_id])

func set_story_flag(flag: String, value: bool = true) -> void:
	if not flag.is_empty():
		story_flags[flag] = value

func select_campaign_node(node_id: String) -> void:
	if not current_node.is_empty() and current_node not in completed_nodes:
		completed_nodes.append(current_node)
	current_node = node_id

func export_build() -> Dictionary:
	return {
		"stage_id": stage_id, "mode_id": mode_id, "squad": squad.duplicate(),
		"buff_levels": buff_levels.duplicate(true), "relics": equipped_relics.keys(),
		"tag_counts": tag_counts.duplicate(true), "relationships": relationships.duplicate(true),
		"story_flags": story_flags.duplicate(true), "node": current_node,
		"rift_shards": rift_shards, "campaign_perks": campaign_perks.duplicate(true),
		"resolved_nodes": resolved_nodes.duplicate(true), "active_resonances": active_resonances.duplicate()
	}
