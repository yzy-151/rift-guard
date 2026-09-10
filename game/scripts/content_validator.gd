extends RefCounted

static func validate(database) -> Array[String]:
	var errors: Array[String] = []
	if database.animation_profiles.size() != database.characters.size():
		errors.append("animation profile count must match character count")
	for id: String in database.characters:
		var character: Dictionary = database.characters[id]
		if not database.animation_profiles.has(str(character.get("animation_profile", ""))):
			errors.append("missing animation profile: " + id)
		if character.get("passive", {}).is_empty():
			errors.append("missing passive: " + id)
		for key: String in ["active_skill", "ultimate"]:
			var ability: Dictionary = character.get(key, {})
			var message := preload("res://scripts/combat_timeline.gd").validate(ability)
			if not message.is_empty(): errors.append("%s %s: %s" % [id, key, message])
	if database.stage_templates.size() < 8:
		errors.append("at least eight stage templates are required")
	if database.boss_patterns.size() < 6:
		errors.append("six boss patterns are required")
	for id: String in database.boss_patterns:
		if database.boss_patterns[id].get("phases", []).size() != 3:
			errors.append("boss requires three phases: " + id)
	return errors
