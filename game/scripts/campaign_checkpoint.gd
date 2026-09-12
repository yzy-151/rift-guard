extends RefCounted

const VERSION := 33
const MAX_BYTES := 262144
const PERKS := ["fortify", "charged_start", "elemental_focus"]

var path: String
var last_message := ""

func _init(base_path: String = "user://campaign-checkpoint") -> void:
	path = base_path

static func nodes(database) -> Dictionary:
	var result: Dictionary = {}
	for chapter: Dictionary in database.campaign_map.get("chapters", []):
		for node: Dictionary in chapter.get("nodes", []):
			result[str(node.id)] = node
	return result

static func snapshot(sim, phase: String) -> Dictionary:
	var state = sim.run_state
	return {
		"version": VERSION, "stage_id": sim.current_stage_id, "seed": sim.run_seed,
		"phase": phase, "saved_at": Time.get_datetime_string_from_system(),
		"starting_luck": state.luck if phase == "battle" else 0.0,
		"settlement": {"kills": sim.kills, "base_hp": sim.base_hp, "base_max_hp": sim.base_max_hp, "best_streak": sim.best_streak, "reactions": sim.reactions} if phase == "cleared" else {},
		"run": {
			"squad": state.squad.duplicate(), "node": state.current_node,
			"completed_nodes": state.completed_nodes.duplicate(), "rift_shards": state.rift_shards,
			"campaign_perks": state.campaign_perks.duplicate(true), "campaign_luck": state.campaign_luck,
			"relics": state.equipped_relics.keys(), "relationships": state.relationships.duplicate(true),
			"story_flags": state.story_flags.duplicate(true), "resolved_nodes": state.resolved_nodes.duplicate(true),
			"rewarded_stages": state.rewarded_stages.duplicate(true)
		}
	}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= minimum and float(value) <= maximum

static func _ids(values: Variant, known: Dictionary, maximum: int) -> bool:
	if not values is Array or values.size() > maximum:
		return false
	var seen: Dictionary = {}
	for id: Variant in values:
		if not id is String or not known.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true

static func validate(data: Variant, database) -> String:
	if not data is Dictionary or not _integer(data.get("version"), VERSION, VERSION):
		return "检查点版本不兼容。"
	var stages: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])
	if not data.get("stage_id") is String or data.stage_id not in stages:
		return "检查点关卡不存在。"
	if not _integer(data.get("seed"), 0, 2147483647) or data.get("phase") not in ["briefing", "battle", "route", "event", "cleared"]:
		return "检查点恢复位置无效。"
	if not data.get("saved_at") is String or data.saved_at.length() > 64 or not data.get("run") is Dictionary:
		return "检查点结构无效。"
	if not data.get("settlement") is Dictionary:
		return "检查点结算摘要无效。"
	if data.phase == "cleared":
		for field: String in ["kills", "base_hp", "base_max_hp", "best_streak", "reactions"]:
			if not _integer(data.settlement.get(field), 0, 100000000):
				return "检查点结算统计无效。"
		if int(data.settlement.base_max_hp) <= 0 or int(data.settlement.base_hp) > int(data.settlement.base_max_hp):
			return "检查点结算生命无效。"
	var starting_luck: Variant = data.get("starting_luck")
	if not (starting_luck is int or starting_luck is float) or not is_finite(float(starting_luck)) or float(starting_luck) < 0.0 or float(starting_luck) > 100.0:
		return "检查点起始幸运无效。"
	var state: Dictionary = data.run
	var known_nodes := nodes(database)
	if not _ids(state.get("squad"), database.characters, 3) or state.squad.is_empty():
		return "检查点编队无效。"
	if not state.get("node") is String or not known_nodes.has(state.node) or not _ids(state.get("completed_nodes"), known_nodes, known_nodes.size()):
		return "检查点路线无效。"
	if data.phase == "event" and (str(known_nodes[state.node].get("type", "")) not in ["shop", "rest", "recruit", "hidden"]):
		return "检查点事件类型无效。"
	if not _ids(state.get("relics"), database.relics, database.relics.size()) or not _integer(state.get("rift_shards"), 0, 100000000):
		return "检查点资源无效。"
	var luck: Variant = state.get("campaign_luck")
	if not (luck is int or luck is float) or not is_finite(float(luck)) or float(luck) < 0.0 or float(luck) > 100.0:
		return "检查点幸运无效。"
	for field: String in ["campaign_perks", "relationships", "story_flags", "resolved_nodes", "rewarded_stages"]:
		if not state.get(field) is Dictionary or state[field].size() > 256:
			return "检查点字段无效：" + field
		for id: Variant in state[field]:
			if not id is String or id.is_empty() or id.length() > 128:
				return "检查点键名无效。"
			var value: Variant = state[field][id]
			match field:
				"campaign_perks":
					if id not in PERKS or not _integer(value, 0, 1000): return "检查点远征增益无效。"
				"relationships":
					if not database.characters.has(id) or not _integer(value, -10000, 10000): return "检查点关系值无效。"
				"story_flags":
					if not value is bool: return "检查点剧情标志无效。"
				"resolved_nodes":
					if not known_nodes.has(id) or not value is String or value.is_empty() or value.length() > 128: return "检查点节点结算无效。"
				"rewarded_stages":
					if id not in stages or not _integer(value, 0, 100000000): return "检查点关卡结算无效。"
	return ""

func _read_slot(slot: int, database) -> Dictionary:
	var slot_path := path + ".%d.json" % slot
	if not FileAccess.file_exists(slot_path):
		return {}
	var file := FileAccess.open(slot_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {}
	var parser := JSON.new()
	var parsed := parser.parse(file.get_as_text())
	file.close()
	if parsed != OK:
		return {}
	var envelope: Variant = parser.data
	if not envelope is Dictionary or not _integer(envelope.get("sequence"), 1, 2147483647) or not envelope.get("payload") is String or not envelope.get("sha256") is String:
		return {}
	if envelope.payload.sha256_text() != envelope.sha256:
		return {}
	if parser.parse(envelope.payload) != OK:
		return {}
	var data: Variant = parser.data
	if not validate(data, database).is_empty():
		return {}
	return {"snapshot": data, "sequence": int(envelope.sequence), "slot": slot}

func load_checkpoint(database) -> Dictionary:
	var best: Dictionary = {}
	var invalid := false
	for slot in 2:
		var candidate := _read_slot(slot, database)
		if candidate.is_empty():
			invalid = invalid or FileAccess.file_exists(path + ".%d.json" % slot)
		elif best.is_empty() or int(candidate.sequence) > int(best.sequence):
			best = candidate
	if best.is_empty():
		last_message = "远征检查点无法读取，可开始新远征。" if invalid else "尚无远征检查点。"
		return {"ok": false, "message": last_message}
	last_message = "检查点异常，已恢复上一份有效记录。" if invalid else "已保存远征检查点。"
	best["ok"] = true
	best["recovered"] = invalid
	best["message"] = last_message
	return best

func save_checkpoint(data: Dictionary, database) -> bool:
	last_message = validate(data, database)
	if not last_message.is_empty():
		return false
	var previous := load_checkpoint(database)
	var slot := 1 - int(previous.slot) if bool(previous.ok) else 0
	var sequence := int(previous.sequence) + 1 if bool(previous.ok) else 1
	var payload := JSON.stringify(data)
	var serialized := JSON.stringify({"sequence": sequence, "payload": payload, "sha256": payload.sha256_text()})
	if serialized.to_utf8_buffer().size() > MAX_BYTES:
		last_message = "远征检查点过大，未保存。"
		return false
	# Write only the older slot: a partial write leaves the latest valid slot intact.
	var file := FileAccess.open(path + ".%d.json" % slot, FileAccess.WRITE)
	if file == null:
		last_message = "远征检查点保存失败，请检查可用空间与目录权限。"
		return false
	file.store_string(serialized)
	file.flush()
	var write_error := file.get_error()
	file.close()
	var verified := _read_slot(slot, database)
	if write_error != OK or verified.is_empty() or int(verified.sequence) != sequence:
		last_message = "远征检查点校验失败，上一份有效记录仍可用。"
		return false
	last_message = "已保存远征检查点。"
	return true

static func restore(data: Dictionary, sim) -> bool:
	if not validate(data, sim.database).is_empty():
		return false
	var stored: Dictionary = data.run
	var state = sim.run_state
	state.reset_run_meta()
	state.mode_id = "rift_watch"
	state.current_node = stored.node
	state.completed_nodes.assign(stored.completed_nodes)
	state.rift_shards = int(stored.rift_shards)
	state.campaign_perks = stored.campaign_perks.duplicate(true)
	state.campaign_luck = float(stored.campaign_luck)
	state.relationships = stored.relationships.duplicate(true)
	state.story_flags = stored.story_flags.duplicate(true)
	state.resolved_nodes = stored.resolved_nodes.duplicate(true)
	state.rewarded_stages = stored.rewarded_stages.duplicate(true)
	for id: String in stored.relics:
		state.grant_relic(id)
	var squad: Array[String] = []
	squad.assign(stored.squad)
	sim.reset_stage(str(data.stage_id), squad, int(data.seed))
	if data.phase == "battle":
		state.luck = float(data.starting_luck)
	elif data.phase == "cleared":
		sim.kills = int(data.settlement.kills)
		sim.base_hp = int(data.settlement.base_hp)
		sim.base_max_hp = int(data.settlement.base_max_hp)
		sim.best_streak = int(data.settlement.best_streak)
		sim.reactions = int(data.settlement.reactions)
	return true
