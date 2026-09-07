extends RefCounted

var save_path: String
var unlocked_characters: Dictionary = {"traveler": true}
var discovered_cards: Dictionary = {}
var encountered_enemies: Dictionary = {}
var cleared_stages: Dictionary = {}

func _init(path: String = "user://compendium.json") -> void:
	save_path = path
	load_progress()

func observe(sim) -> void:
	var changed := false
	for hero: Dictionary in sim.heroes:
		changed = _mark(unlocked_characters, str(hero.get("character_id", ""))) or changed
	for id: Variant in sim.run_state.buff_levels:
		changed = _mark(discovered_cards, str(id)) or changed
	for enemy: Dictionary in sim.enemies:
		changed = _mark(encountered_enemies, str(enemy.get("kind", ""))) or changed
	if changed:
		save_progress()

func clear_stage(stage_id: String, unlocks: Array) -> void:
	var changed := _mark(cleared_stages, stage_id)
	for id: Variant in unlocks:
		changed = _mark(unlocked_characters, str(id)) or changed
	if changed:
		save_progress()

func _mark(collection: Dictionary, id: String) -> bool:
	if id.is_empty() or collection.has(id):
		return false
	collection[id] = true
	return true

func save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"unlocked_characters": unlocked_characters.keys(),
		"discovered_cards": discovered_cards.keys(),
		"encountered_enemies": encountered_enemies.keys(),
		"cleared_stages": cleared_stages.keys(),
	}, "\t"))

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	_load_set(unlocked_characters, data.get("unlocked_characters", []))
	_load_set(discovered_cards, data.get("discovered_cards", []))
	_load_set(encountered_enemies, data.get("encountered_enemies", []))
	_load_set(cleared_stages, data.get("cleared_stages", []))
	unlocked_characters["traveler"] = true

func _load_set(target: Dictionary, values: Array) -> void:
	for value: Variant in values:
		target[str(value)] = true
