extends RefCounted
## Provenance is data: a neutral announcement is never presented as actor audio.
const MANIFEST := "res://assets/audio_v91/manifest.json"
var manifest: Dictionary = {}

func _init() -> void:
	if FileAccess.file_exists(MANIFEST):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary:
			manifest = parsed

func resolve(character_id: String, slot: String) -> Dictionary:
	var profile: Dictionary = manifest.get("characters", {}).get(character_id, {})
	var key: String = str(profile.get("slots", {}).get(slot, "neutral_" + slot))
	var clip: Dictionary = manifest.get("assets", {}).get(key, {}).duplicate(true)
	if clip.is_empty():
		return {}
	clip["voice_id"] = key
	clip["character_id"] = character_id
	clip["slot"] = slot
	return clip
