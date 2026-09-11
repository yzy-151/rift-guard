extends RefCounted

static func resolve(definitions: Dictionary, run_state, heroes: Array[Dictionary]) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for resonance: Dictionary in definitions.values():
		if _matches_all(resonance.get("conditions", []), run_state, heroes):
			candidates.append(resonance.duplicate(true))
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	var active: Array[Dictionary] = []
	var used_groups: Dictionary = {}
	for resonance: Dictionary in candidates:
		var group: String = str(resonance.get("exclusive_group", ""))
		if not group.is_empty() and used_groups.has(group):
			continue
		if not group.is_empty():
			used_groups[group] = str(resonance.id)
		active.append(resonance)
	return active

static func _matches_all(conditions: Array, run_state, heroes: Array[Dictionary]) -> bool:
	for value: Variant in conditions:
		if not value is Dictionary or not _matches(value, run_state, heroes):
			return false
	return true

static func _matches(condition: Dictionary, run_state, heroes: Array[Dictionary]) -> bool:
	match str(condition.get("type", "")):
		"element_count":
			return _count_element(heroes, str(condition.get("element", ""))) >= int(condition.get("count", 1))
		"distinct_elements":
			return _distinct_elements(heroes).size() >= int(condition.get("count", 1))
		"characters":
			var present: Dictionary = {}
			for hero: Dictionary in heroes:
				present[str(hero.get("character_id", ""))] = true
			for id: Variant in condition.get("ids", []):
				if not present.has(str(id)):
					return false
			return true
		"relationship":
			return int(run_state.relationships.get(str(condition.get("character_id", "")), 0)) >= int(condition.get("min", 1))
		"role_contains":
			var count: int = 0
			for hero: Dictionary in heroes:
				if str(hero.get("role", "")).contains(str(condition.get("value", ""))):
					count += 1
			return count >= int(condition.get("count", 1))
		"squad_size":
			return heroes.size() >= int(condition.get("count", 1))
	return false

static func _count_element(heroes: Array[Dictionary], element: String) -> int:
	var count: int = 0
	for hero: Dictionary in heroes:
		if str(hero.get("element", "")) == element:
			count += 1
	return count

static func _distinct_elements(heroes: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	for hero: Dictionary in heroes:
		for key: String in [str(hero.get("element", "")), str(hero.get("secondary_element", ""))]:
			if not key.is_empty() and key != "none":
				result[key] = true
	return result