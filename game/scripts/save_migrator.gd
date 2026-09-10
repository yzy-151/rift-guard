extends RefCounted

const CURRENT_VERSION := 25

static func migrate(source: Dictionary) -> Dictionary:
	var data := source.duplicate(true)
	var version := int(data.get("save_version", 0))
	if version < 20:
		data["build_history"] = data.get("build_history", [])
		data["unlocked_relics"] = data.get("unlocked_relics", [])
	if version < 23:
		data["completed_stage_ids"] = data.get("completed_stage_ids", [])
		data["boss_records"] = data.get("boss_records", {})
	if version < 25:
		data["animation_settings"] = data.get("animation_settings", {"flash":1.0,"shake":1.0,"effects":1.0})
		data["content_revision"] = "v25"
	data["save_version"] = CURRENT_VERSION
	return data
