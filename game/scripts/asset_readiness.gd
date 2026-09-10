extends RefCounted

const REQUIRED_SLOTS := ["portrait", "idle", "move", "attack", "hurt", "skill", "down"]
const PLACEHOLDER_MARKERS := ["tiny-dungeon", "jessica.png"]

static func scan(database) -> Dictionary:
	var entries: Array[Dictionary] = []
	var playable := 0
	var final_ready := 0
	for character_id: String in database.characters:
		var character: Dictionary = database.characters[character_id]
		var asset_key := str(character.get("asset_key", ""))
		var manifest: Dictionary = database.assets.get(asset_key, {})
		var missing: Array[String] = []
		var placeholders: Array[String] = []
		for slot: String in REQUIRED_SLOTS:
			var path := str(manifest.get(slot, ""))
			if path.is_empty() or not _asset_exists(path):
				missing.append(slot)
			elif PLACEHOLDER_MARKERS.any(func(marker: String)->bool: return marker in path):
				placeholders.append(slot)
		var is_playable := missing.is_empty()
		var is_final := is_playable and placeholders.is_empty()
		if is_playable:
			playable += 1
		if is_final:
			final_ready += 1
		entries.append({"id":character_id,"name":str(character.name),"asset_key":asset_key,"playable":is_playable,"final_ready":is_final,"missing":missing,"placeholders":placeholders})
	return {"characters":entries,"playable":playable,"final_ready":final_ready,"total":database.characters.size()}

static func _asset_exists(path: String) -> bool:
	# Imported resources are remapped inside release PCK files, so ResourceLoader
	# must participate in the check instead of relying only on raw file access.
	return FileAccess.file_exists(path) or ResourceLoader.exists(path)
static func markdown(report: Dictionary) -> String:
	var lines: Array[String] = ["# V26 角色素材就绪度", "", "| 角色 | 可运行 | 最终素材 | 缺失槽位 | 占位槽位 |", "|---|---|---|---|---|"]
	for row: Dictionary in report.get("characters", []):
		lines.append("| %s | %s | %s | %s | %s |" % [row.name, "是" if row.playable else "否", "是" if row.final_ready else "否", "、".join(row.missing) if not row.missing.is_empty() else "—", "、".join(row.placeholders) if not row.placeholders.is_empty() else "—"])
	lines.append("")
	lines.append("当前 %d/%d 名角色具备可运行素材，%d/%d 名角色已达到无占位素材状态。" % [int(report.playable), int(report.total), int(report.final_ready), int(report.total)])
	return "\n".join(lines) + "\n"
