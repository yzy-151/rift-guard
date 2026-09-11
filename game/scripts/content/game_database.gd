extends RefCounted

var characters: Dictionary = {}
var cards: Array[Dictionary] = []
var stages: Dictionary = {}
var modes: Dictionary = {}
var assets: Dictionary = {}
var relics: Dictionary = {}
var campaign_map: Dictionary = {}
var enemy_affixes: Dictionary = {}
var animation_profiles: Dictionary = {}
var boss_patterns: Dictionary = {}
var stage_templates: Dictionary = {}
var vfx_profiles: Dictionary = {}
var combat_contracts: Dictionary = {}
var enemy_visuals: Dictionary = {}
var vfx_themes: Dictionary = {}
var enemy_families: Dictionary = {}
var team_resonances: Dictionary = {}
var asset_readiness: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
	characters = _by_id(_read_array("res://data/v2/characters.json"), "character")
	cards.assign(_read_array("res://data/v2/cards.json"))
	cards.append_array(_read_array("res://data/v2/mechanic_cards.json"))
	stages = _by_id(_read_array("res://data/v2/stages.json"), "stage")
	modes = _by_id(_read_array("res://data/v2/modes.json"), "mode")
	assets = _read_dictionary("res://data/v2/asset_manifest.json")
	relics = _by_id(_read_array("res://data/v2/relics.json"), "relic")
	campaign_map = _read_dictionary("res://data/v2/campaign_map.json")
	enemy_affixes = _by_id(_read_array("res://data/v2/enemy_affixes.json"), "enemy affix")
	animation_profiles = _by_id(_read_array("res://data/v2/animation_profiles.json"), "animation profile")
	boss_patterns = _by_id(_read_array("res://data/v2/boss_patterns.json"), "boss pattern")
	stage_templates = _by_id(_read_array("res://data/v2/stage_templates.json"), "stage template")
	vfx_profiles = _by_id(_read_array("res://data/v2/vfx_profiles.json"), "VFX profile")
	combat_contracts = _by_id(_read_array("res://data/v2/combat_contracts.json"), "combat contract")
	enemy_visuals = _by_id(_read_array("res://data/v2/enemy_visuals.json"), "enemy visual")
	vfx_themes = _by_id(_read_array("res://data/v2/vfx_themes.json"), "VFX theme")
	enemy_families = _by_id(_read_array("res://data/v2/enemy_families.json"), "enemy family")
	team_resonances = _by_id(_read_array("res://data/v2/team_resonances.json"), "team resonance")
	_validate()
	errors.append_array(preload("res://scripts/content_validator.gd").validate(self))
	asset_readiness = preload("res://scripts/asset_readiness.gd").scan(self)
	if not errors.is_empty():
		var reporter = preload("res://scripts/error_reporter.gd").new()
		for message: String in errors: reporter.record("content",message)
		reporter.flush()

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing file: " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		errors.append("invalid json: " + path)
	return parsed

func _read_array(path: String) -> Array:
	var parsed: Variant = _read_json(path)
	if parsed is Array:
		return parsed
	if parsed != null:
		errors.append("expected array: " + path)
	return []

func _read_dictionary(path: String) -> Dictionary:
	var parsed: Variant = _read_json(path)
	if parsed is Dictionary:
		return parsed
	if parsed != null:
		errors.append("expected dictionary: " + path)
	return {}

func _by_id(rows: Array, label: String) -> Dictionary:
	var result: Dictionary = {}
	for value: Variant in rows:
		if not value is Dictionary:
			errors.append("invalid %s row" % label)
			continue
		var row: Dictionary = value
		var id: String = str(row.get("id", ""))
		if id.is_empty() or result.has(id):
			errors.append("invalid or duplicate %s id: %s" % [label, id])
		else:
			result[id] = row
	return result

func _validate() -> void:
	var elements := ["none", "anemo", "electro", "pyro", "hydro", "geo", "cryo"]
	var card_ids: Dictionary = {}
	for required_theme: String in ["neutral","anemo","electro","pyro","hydro","geo","cryo","vaporize","melt","overload","electro_charged","freeze","swirl","crystallize","superconduct"]:
		if not vfx_themes.has(required_theme):
			errors.append("missing VFX theme: " + required_theme)
	if team_resonances.size() < 12:
		errors.append("at least twelve team resonances are required")
	if enemy_families.size() < 12:
		errors.append("at least twelve enemy families are required")
	for id: String in characters:
		var character: Dictionary = characters[id]
		if str(character.get("element", "")) not in elements:
			errors.append("invalid character element: " + id)
		if not assets.has(str(character.get("asset_key", ""))):
			errors.append("missing character asset key: " + id)
		for ability_key: String in ["active_skill", "ultimate"]:
			var ability: Dictionary = character.get(ability_key, {})
			if str(ability.get("name", "")).is_empty() or str(ability.get("kind", "")).is_empty():
				errors.append("missing %s definition: %s" % [ability_key, id])
	for card: Dictionary in cards:
		var card_id: String = str(card.get("id", ""))
		if card_id.is_empty() or card_ids.has(card_id):
			errors.append("invalid or duplicate card id: " + card_id)
		card_ids[card_id] = true
		if card.get("target", "global") == "character" and not characters.has(str(card.get("character_id", ""))):
			errors.append("card target missing: " + card_id)
		if card.get("rarity", "") not in ["common", "rare", "epic", "legendary", "mythic"]:
			errors.append("invalid rarity: " + card_id)
		if card.get("tags", []).is_empty():
			errors.append("card has no gameplay tags: " + card_id)
	if campaign_map.get("chapters", []).is_empty():
		errors.append("campaign map has no chapters")
	for id: String in stages:
		var stage: Dictionary = stages[id]
		if float(stage.get("duration_seconds", 0.0)) < 300.0:
			errors.append("stage shorter than five minutes: " + id)
		for character_id: String in stage.get("starting_squad", []):
			if not characters.has(character_id):
				errors.append("stage squad character missing: " + character_id)
	for id: String in modes:
		var mode: Dictionary = modes[id]
		if int(mode.get("max_squad_size", 0)) != 3:
			errors.append("mode squad size must be three: " + id)
		for stage_id: String in mode.get("stage_ids", []):
			if not stages.has(stage_id):
				errors.append("mode stage missing: " + stage_id)
