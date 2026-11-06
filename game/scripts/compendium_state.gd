extends RefCounted

const SaveMigrator = preload("res://scripts/save_migrator.gd")
const AchievementCatalog = preload("res://scripts/achievement_catalog.gd")

var save_path: String
var unlocked_characters: Dictionary = {"traveler": true}
var story_recruits: Dictionary = {}
var legacy_gwen_unlock := false
var discovered_cards: Dictionary = {}
var encountered_enemies: Dictionary = {}
var cleared_stages: Dictionary = {}
var stage_records: Dictionary = {}
var build_history: Array[Dictionary] = []
var unlocked_achievements: Dictionary = {}
var achievement_stats: Dictionary = {
	"runs": 0,
	"wins": 0,
	"total_kills": 0,
	"total_damage": 0.0,
	"endless_damage": 0.0,
	"boss_kills": 0,
	"best_endless_time": 0.0,
}

func _init(path: String = "user://compendium-story-v3.json") -> void:
	save_path = path
	load_progress()

func observe(sim) -> void:
	var changed := false
	for hero: Dictionary in sim.heroes:
		# A character being on the battlefield does not make a guest a recruit.
		if bool(hero.get("temporary_assist", false)):
			continue
		if str(hero.get("character_id", "")) == "hero_13" and not has_gwen_recruitment():
			continue
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
		if str(id) == "hero_13" and not has_gwen_recruitment():
			continue
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

func evaluate_achievements(sim, database) -> Array[String]:
	var record: Dictionary = sim.export_build_record()
	var heroes: Array = record.get("characters", [])
	var total_damage := 0.0
	var skill_uses := 0
	var ultimate_uses := 0
	var active_damage: Array[float] = []
	var max_energy := 0.0
	for hero: Dictionary in heroes:
		var damage := float(hero.get("damage", 0.0))
		total_damage += damage
		skill_uses += int(hero.get("skills", 0))
		ultimate_uses += int(hero.get("ultimates", 0))
		max_energy = maxf(max_energy, float(hero.get("max_energy", 0.0)))
		if damage > 0.0:
			active_damage.append(damage)
	achievement_stats["runs"] = int(achievement_stats.get("runs", 0)) + 1
	achievement_stats["total_kills"] = int(achievement_stats.get("total_kills", 0)) + int(record.get("kills", 0))
	achievement_stats["total_damage"] = float(achievement_stats.get("total_damage", 0.0)) + total_damage
	achievement_stats["boss_kills"] = int(achievement_stats.get("boss_kills", 0)) + int(record.get("boss_kills", 0))
	if sim.state == "won":
		achievement_stats["wins"] = int(achievement_stats.get("wins", 0)) + 1
	if sim.endless_mode:
		achievement_stats["endless_damage"] = float(achievement_stats.get("endless_damage", 0.0)) + total_damage
		achievement_stats["best_endless_time"] = maxf(float(achievement_stats.get("best_endless_time", 0.0)), float(record.get("elapsed", 0.0)))

	var current_cards: Dictionary = record.get("buff_levels", {})
	var current_rarities: Dictionary = {}
	var current_legendary := 0
	var discovered_legendary := 0
	for card: Dictionary in database.cards:
		var card_id := str(card.get("id", ""))
		var rarity := str(card.get("rarity", "common"))
		if current_cards.has(card_id):
			current_rarities[rarity] = true
			current_legendary += int(rarity == "legendary")
		if discovered_cards.has(card_id) and rarity == "legendary":
			discovered_legendary += 1
	var ready_characters := 0
	var unlocked_ready := 0
	for character_id: String in database.characters:
		if bool(database.characters[character_id].get("content_ready", false)):
			ready_characters += 1
			unlocked_ready += int(unlocked_characters.has(character_id))
	var boss_total := 0
	var boss_seen := 0
	for boss_id: Variant in database.boss_patterns.keys():
		boss_total += 1
		boss_seen += int(encountered_enemies.has(str(boss_id)))
	var max_hero_damage := 0.0
	for damage: float in active_damage:
		max_hero_damage = maxf(max_hero_damage, damage)
	var balanced_team := active_damage.size() >= 3 and total_damage > 0.0
	if balanced_team:
		for damage: float in active_damage:
			if damage / total_damage < 0.20:
				balanced_team = false
				break

	var won_normal: bool = sim.state == "won" and not sim.endless_mode
	var conditions := {
		"first_watch": won_normal,
		"damage_king": float(achievement_stats.endless_damage) >= 9999999.0,
		"card_master": discovered_cards.size() >= database.cards.size(),
		"perfect_guard": won_normal and int(sim.base_hp) >= 12,
		"last_crystal": won_normal and int(sim.base_hp) == 1,
		"hundred_slayer": int(record.get("kills", 0)) >= 100,
		"thousand_army": sim.endless_mode and int(record.get("kills", 0)) >= 1000,
		"night_watch": sim.endless_mode and float(record.get("elapsed", 0.0)) >= 900.0,
		"five_crowns": int(achievement_stats.boss_kills) >= 5,
		"full_squad": active_damage.size() >= 3,
		"skill_storm": skill_uses >= 50,
		"ultimate_finale": ultimate_uses >= 20,
		"crystal_overclock": int(record.get("crystal_level", 1)) >= 20,
		"stack_ten": int(record.get("highest_stack", 0)) >= 10,
		"four_rarities": current_rarities.size() >= 4,
		"legend_collector": discovered_legendary >= 15,
		"roster_complete": ready_characters > 0 and unlocked_ready >= ready_characters,
		"eight_fronts": cleared_stages.size() >= 8,
		"boss_archive": boss_total > 0 and boss_seen >= boss_total,
		"war_archive": build_history.size() >= 20,
		"speed_clear": won_normal and float(record.get("elapsed", 99999.0)) <= 240.0,
		"endless_marathon": sim.endless_mode and float(record.get("elapsed", 0.0)) >= 1800.0,
		"million_firepower": total_damage >= 1000000.0,
		"cold_start": won_normal and float(record.get("luck", 1.0)) <= 0.05,
		"energy_overflow": max_energy >= 300.0,
		"solo_army": total_damage >= 500000.0 and max_hero_damage / maxf(1.0, total_damage) >= 0.80,
		"balanced_team": balanced_team,
		"thirty_buffs": current_cards.size() >= 30,
		"five_legends": current_legendary >= 5,
		"true_guardian": won_normal and str(record.get("stage_id", "")) == "stage_08",
	}
	var unlocked_now: Array[String] = []
	for item: Dictionary in AchievementCatalog.ITEMS:
		var id := str(item.id)
		if bool(conditions.get(id, false)) and not unlocked_achievements.has(id):
			unlocked_achievements[id] = {"unlocked_at": Time.get_datetime_string_from_system()}
			unlocked_now.append(id)
	save_progress()
	return unlocked_now

func achievement_progress(id: String, database) -> String:
	if unlocked_achievements.has(id):
		return "已完成"
	match id:
		"damage_king": return "%s / 9,999,999" % _number_text(int(achievement_stats.get("endless_damage", 0.0)))
		"card_master": return "%d / %d" % [discovered_cards.size(), database.cards.size()]
		"five_crowns": return "%d / 5" % int(achievement_stats.get("boss_kills", 0))
		"roster_complete":
			var ready := 0
			var known := 0
			for character_id: String in database.characters:
				if bool(database.characters[character_id].get("content_ready", false)):
					ready += 1
					known += int(unlocked_characters.has(character_id))
			return "%d / %d" % [known, ready]
		"eight_fronts": return "%d / 8" % mini(8, cleared_stages.size())
		"war_archive": return "%d / 20" % build_history.size()
		_: return "未完成"

func unlock_character(character_id: String) -> bool:
	if character_id == "hero_13" and not has_gwen_recruitment():
		return false
	var changed := _mark(unlocked_characters, character_id)
	if changed:
		save_progress()
	return changed

func has_gwen_recruitment() -> bool:
	return str(story_recruits.get("hero_13", "")) == "mode1_won"

func can_select_character(character_id: String) -> bool:
	return unlocked_characters.has(character_id) and (character_id != "hero_13" or has_gwen_recruitment())

func reject_gwen_recruitment() -> void:
	if has_gwen_recruitment():
		return
	legacy_gwen_unlock = false
	unlocked_characters.erase("hero_13")
	save_progress()

func record_story_recruit(character_id: String, scene_key: String) -> bool:
	if character_id.is_empty() or scene_key.is_empty():
		return false
	if character_id == "hero_13" and scene_key != "mode1_won":
		return false
	var changed := str(story_recruits.get(character_id, "")) != scene_key
	story_recruits[character_id] = scene_key
	changed = _mark(unlocked_characters, character_id) or changed
	if changed:
		save_progress()
	return changed

func restore_story_recruitment(snapshot: Dictionary) -> void:
	var flags: Dictionary = snapshot.get("run", {}).get("story_flags", {})
	var proven := bool(flags.get("gwen_recruited", false))
	# Older builds did not store the receipt. They saved first-stage "cleared"
	# only after the successful greeting; a first-stage battle is not evidence.
	if legacy_gwen_unlock and not flags.has("gwen_recruited"):
		var stage_id := str(snapshot.get("stage_id", ""))
		proven = proven or (stage_id == "stage_01" and str(snapshot.get("phase", "")) == "cleared")
		proven = proven or (stage_id.begins_with("stage_") and stage_id.trim_prefix("stage_").is_valid_int() and int(stage_id.trim_prefix("stage_")) >= 2)
	if proven:
		record_story_recruit("hero_13", "mode1_won")

func _mark(collection: Dictionary, id: String) -> bool:
	if id.is_empty() or collection.has(id):
		return false
	collection[id] = true
	return true

func _number_text(value: int) -> String:
	var raw := str(value)
	var output := ""
	for index in raw.length():
		if index > 0 and (raw.length() - index) % 3 == 0:
			output += ","
		output += raw[index]
	return output

func save_progress() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"save_version": SaveMigrator.CURRENT_VERSION,
		"unlocked_characters": unlocked_characters.keys(),
		"story_recruit_revision": 1,
		"story_recruits": story_recruits,
		"legacy_gwen_unlock": legacy_gwen_unlock,
		"discovered_cards": discovered_cards.keys(),
		"encountered_enemies": encountered_enemies.keys(),
		"cleared_stages": cleared_stages.keys(),
		"stage_records": stage_records,
		"build_history": build_history,
		"unlocked_achievements": unlocked_achievements,
		"achievement_stats": achievement_stats,
	}, "\t"))

func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not data is Dictionary:
		return
	data = SaveMigrator.migrate(data)
	_load_set(unlocked_characters, data.get("unlocked_characters", []))
	_load_set(discovered_cards, data.get("discovered_cards", []))
	_load_set(encountered_enemies, data.get("encountered_enemies", []))
	_load_set(cleared_stages, data.get("cleared_stages", []))
	if data.get("stage_records", {}) is Dictionary:
		stage_records = data.get("stage_records", {}).duplicate(true)
	if data.get("build_history", []) is Array:
		build_history.assign(data.get("build_history", []))
	if data.get("unlocked_achievements", {}) is Dictionary:
		unlocked_achievements = data.get("unlocked_achievements", {}).duplicate(true)
	if data.get("achievement_stats", {}) is Dictionary:
		achievement_stats.merge(data.get("achievement_stats", {}), true)
	unlocked_characters["traveler"] = true
	if data.get("story_recruits", {}) is Dictionary:
		story_recruits = data.get("story_recruits", {}).duplicate(true)
	legacy_gwen_unlock = bool(data.get("legacy_gwen_unlock", false))
	if not data.has("story_recruit_revision"):
		legacy_gwen_unlock = unlocked_characters.has("hero_13")
		# Preserve old completed recruitment, but repair the guest-only unlock.
		if legacy_gwen_unlock and cleared_stages.has("stage_01"):
			story_recruits["hero_13"] = "mode1_won"
	if not has_gwen_recruitment():
		unlocked_characters.erase("hero_13")
	elif not unlocked_characters.has("hero_13"):
		unlocked_characters["hero_13"] = true

func _load_set(target: Dictionary, values: Array) -> void:
	for value: Variant in values:
		target[str(value)] = true
