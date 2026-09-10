extends RefCounted

var save_path: String
var unlocked_characters: Dictionary = {"traveler": true}
var discovered_cards: Dictionary = {}
var encountered_enemies: Dictionary = {}
var cleared_stages: Dictionary = {}
var stage_records: Dictionary = {}
var build_history: Array[Dictionary] = []

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

func record_result(stage_id: String, kills: int, base_hp: int, best_streak: int) -> void:
	var previous: Dictionary = stage_records.get(stage_id, {})
	stage_records[stage_id] = {
		"best_kills": maxi(kills, int(previous.get("best_kills", 0))),
		"best_base_hp": maxi(base_hp, int(previous.get("best_base_hp", 0))),
		"best_streak": maxi(best_streak, int(previous.get("best_streak", 0))),
	}
	save_progress()

func record_build(sim) -> void:
	var record: Dictionary = sim.export_build_record()
	record["recorded_at"] = Time.get_datetime_string_from_system()
	build_history.push_front(record)
	if build_history.size() > 20:
		build_history.resize(20)
	save_progress()

func unlock_character(character_id: String) -> bool:
	var changed := _mark(unlocked_characters, character_id)
	if changed:
		save_progress()
	return changed

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
		"stage_records": stage_records,
		"build_history": build_history,
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
	if data.get("stage_records", {}) is Dictionary:
		stage_records = data.get("stage_records", {}).duplicate(true)
	if data.get("build_history", []) is Array:
		build_history.assign(data.get("build_history", []))
	unlocked_characters["traveler"] = true

func _load_set(target: Dictionary, values: Array) -> void:
	for value: Variant in values:
		target[str(value)] = true
