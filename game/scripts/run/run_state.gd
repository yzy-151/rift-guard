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

func reset_for_stage(next_stage_id: String) -> void:
	stage_id = next_stage_id
	traveler_element = "none"
	traveler_secondary_element = "none"
	buff_levels.clear()
	crystal_level = 1
	crystal_xp = 0
	pending_level_ups = 0
	legendary_count = 0
	mythic_count = 0
	luck = 0.0
