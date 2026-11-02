extends RefCounted
## Reproducible experiment configurations, never campaign checkpoints.
## Slot numbers are 1..3. Only load_slot's successful result owns a new Session;
## callers swap it into the view after ok, leaving their old Session untouched on error.
const Session = preload("res://scripts/workshop_session.gd")
const Database = preload("res://scripts/content/game_database.gd")
const Layouts = preload("res://scripts/classic_endless_layouts.gd")
const SCHEMA_VERSION := 2
const SLOT_COUNT := 3
const MAX_FILE_BYTES := 262144
const MAX_HEROES := 64
const MAX_ENEMIES := 256
const MAX_CARDS := 1024
const SPEEDS := [0.25, 0.5, 1.0, 2.0]
const FLAGS := ["auto_attack", "enemy_action", "invulnerable", "infinite_energy"]
var directory: String
var _database
var _cards: Dictionary = {}
var _capture_error := ""

func _init(storage_directory: String = "user://workshop_scenarios") -> void:
	directory = storage_directory

func slot_path(slot: int) -> String:
	if not _valid_slot(slot): return ""
	var paths := _generation_paths(slot)
	return paths[0] if not paths.is_empty() else directory.path_join("slot_%d_%020d_0000000000000000.json" % [slot, 0])

func _generation(path: String) -> int:
	return path.get_file().split("_")[2].to_int()

func _generation_paths(slot: int) -> Array[String]:
	var paths: Array[String] = []
	if not _valid_slot(slot) or not DirAccess.dir_exists_absolute(directory): return paths
	var pattern := RegEx.new()
	pattern.compile("^slot_%d_[0-9]{20}_[0-9a-f]{16}\\.json$" % slot)
	for file_name: String in DirAccess.get_files_at(directory):
		if pattern.search(file_name) != null and _generation(file_name) >= 0 and _generation(file_name) < 1000000000:
			paths.append(directory.path_join(file_name))
	paths.sort()
	paths.reverse()
	return paths

func _valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT

func _fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}

func _catalog() -> void:
	if _database != null: return
	_database = Database.new()
	for card: Dictionary in _database.cards: _cards[str(card.id)] = card

func _capture_fail(message: String) -> Dictionary:
	_capture_error = message
	return {}

func capture(session) -> Dictionary:
	# Only stable catalog identifiers are persisted, never mutated runtime cards.
	_capture_error = ""
	if not session is Session: return _capture_fail("当前工坊会话无效，无法保存。")
	var heroes_by_id: Dictionary = {}
	for hero: Dictionary in session.sim.heroes:
		heroes_by_id[int(hero.id)] = hero
	var cards: Array[Dictionary] = []
	if session.cards_applied.size() > MAX_CARDS: return _capture_fail("卡牌记录过多，最多保存 %d 条。" % MAX_CARDS)
	for entry: Dictionary in session.cards_applied:
		if not entry.get("hero_id") is int or not heroes_by_id.has(entry.hero_id):
			return _capture_fail("卡牌记录缺少对应角色，未保存场景。")
		if not entry.get("card") is Dictionary or not entry.card.get("id") is String:
			return _capture_fail("卡牌记录无效，未保存场景。")
		if not entry.get("roster") is Array:
			return _capture_fail("旧临时构筑缺少加卡时的角色名册，请重置构筑后重新加卡再保存。")
		var character_id := str(heroes_by_id[entry.hero_id].character_id)
		cards.append({"hero_character_id":character_id, "card_id":entry.card.id, "roster":entry.roster.duplicate(true)})
	var heroes: Array[Dictionary] = []
	for hero: Dictionary in session.sim.heroes:
		var point: Vector2 = hero.pos
		heroes.append({"character_id":str(hero.character_id), "position":[point.x, point.y], "deployed":bool(hero.deployed)})
	var enemies: Array[Dictionary] = []
	for enemy: Dictionary in session.sim.enemies:
		if float(enemy.hp) <= 0.0: continue
		var point: Vector2 = enemy.pos
		enemies.append({"kind":str(enemy.kind), "position":[point.x, point.y]})
	var settings := {"speed":session.speed}
	for flag: String in FLAGS: settings[flag] = session.get(flag)
	var data := {"format":"rift_guard_workshop", "schema_version":SCHEMA_VERSION,
		"stage_id":session.stage_id, "layout_id":session.layout_id,
		"heroes":heroes, "enemies":enemies, "cards_applied":cards, "settings":settings}
	var error := _validate(data)
	if not error.is_empty(): return _capture_fail(error)
	return data

func save_slot(slot: int, session) -> Dictionary:
	if not _valid_slot(slot): return _fail("场景槽编号必须为 1 至 3。")
	var data := capture(session)
	if data.is_empty(): return _fail(_capture_error)
	# Check positions against fresh terrain as well: a destroyed wall is not saved.
	var rebuilt := _restore(data)
	if not rebuilt.ok: return rebuilt
	var previous_paths := _generation_paths(slot)
	var generation := 1 if previous_paths.is_empty() else _generation(previous_paths[0]) + 1
	if generation >= 1000000000: return _fail("场景存档代数已达到上限。")
	var encoded := JSON.stringify({"slot_id":slot, "generation":generation, "config":data}, "\t")
	if encoded.to_utf8_buffer().size() > MAX_FILE_BYTES: return _fail("场景文件超过 256 KiB，未保存。")
	var absolute_dir := ProjectSettings.globalize_path(directory)
	var ancestor := absolute_dir
	while not ancestor.is_empty() and not DirAccess.dir_exists_absolute(ancestor):
		if FileAccess.file_exists(ancestor): return _fail("工坊场景目录被同名文件占用，原槽位未改动。")
		var parent := ancestor.get_base_dir()
		if parent == ancestor: break
		ancestor = parent
	if DirAccess.make_dir_recursive_absolute(absolute_dir) != OK:
		return _fail("无法创建工坊场景目录，请检查目录权限。")
	# Windows rename_absolute removes an existing destination before MoveFileW.
	# A new, random, immutable generation name means no previous save is a target.
	var token := "%08x%08x" % [randi(), randi()]
	var destination := absolute_dir.path_join("slot_%d_%020d_%s.json" % [slot, generation, token])
	while FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination):
		token = "%08x%08x" % [randi(), randi()]
		destination = absolute_dir.path_join("slot_%d_%020d_%s.json" % [slot, generation, token])
	var temporary := destination + ".tmp_%d_%d" % [Time.get_ticks_usec(), randi()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return _fail("无法写入工坊场景临时文件，原槽位未改动。")
	file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("场景写入失败，原槽位未改动。")
	if _replace_file(temporary, destination) != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("无法提交场景新存档，原槽位未改动。")
	# A crash before rename leaves only an ignored temp. A crash after rename has
	# a complete flushed new generation; pruning is never on the commit path.
	var fallback := ""
	for path: String in previous_paths:
		var old := _read_path(path, slot)
		if old.ok and _restore(old.data).ok:
			fallback = path
			break
	for path: String in previous_paths:
		if path != fallback: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return {"ok":true, "error":""}

func _replace_file(temporary: String, destination: String) -> Error:
	if FileAccess.file_exists(destination) or DirAccess.dir_exists_absolute(destination): return ERR_ALREADY_EXISTS
	return DirAccess.rename_absolute(temporary, destination)

func _read_slot(slot: int) -> Dictionary:
	if not _valid_slot(slot): return _fail("场景槽编号必须为 1 至 3。")
	var paths := _generation_paths(slot)
	if paths.is_empty(): return _fail("此场景槽为空，请先保存。")
	var latest_error := ""
	for path: String in paths:
		var result := _read_path(path, slot)
		if result.ok:
			var rebuilt := _restore(result.data)
			if rebuilt.ok:
				result.session = rebuilt.session
				result.warning = "最新存档无法载入，可恢复上一份完整场景：" + latest_error if not latest_error.is_empty() else ""
				return result
			result = rebuilt
		if latest_error.is_empty(): latest_error = str(result.error)
	return _fail(latest_error)

func _read_path(path: String, slot: int) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return _fail("无法读取场景文件，请检查目录权限。")
	var length := file.get_length()
	if length <= 0 or length > MAX_FILE_BYTES:
		file.close()
		return _fail("场景文件为空或超过 256 KiB，无法载入。")
	var text := file.get_as_text()
	var read_error := file.get_error()
	file.close()
	if read_error != OK and read_error != ERR_FILE_EOF: return _fail("读取场景文件失败。")
	var parser := JSON.new()
	if parser.parse(text) != OK: return _fail("场景文件 JSON 已损坏，无法载入。")
	if not parser.data is Dictionary or not _exact_keys(parser.data, ["slot_id", "generation", "config"]): return _fail("场景存档封装无效。")
	var envelope: Dictionary = parser.data
	if not _number(envelope.slot_id) or float(envelope.slot_id) != slot or not _number(envelope.generation) or float(envelope.generation) != _generation(path): return _fail("场景槽号或存档代数不匹配。")
	var error := _validate(envelope.config)
	if not error.is_empty(): return _fail(error)
	return {"ok":true, "error":"", "data":envelope.config}

func load_slot(slot: int) -> Dictionary:
	var result := _read_slot(slot)
	if not result.ok: return result
	return {"ok":true, "error":"", "session":result.session, "warning":result.warning}

func slot_info(slot: int) -> Dictionary:
	var result := _read_slot(slot)
	var occupied := not _generation_paths(slot).is_empty()
	if not result.ok:
		return {"occupied":occupied, "summary":"损坏 / 无法读取" if occupied else "空场景槽", "error":result.error if occupied or not _valid_slot(slot) else ""}
	var data: Dictionary = result.data
	var deployed := 0
	for hero: Dictionary in data.heroes:
		if hero.deployed: deployed += 1
	var map_name := str(_database.stages[data.stage_id].get("name", data.stage_id))
	if data.stage_id == "stage_endless":
		for layout: Dictionary in Layouts.OPTIONS:
			if layout.id == data.layout_id: map_name = "无尽 · " + str(layout.name)
	var summary := "%s · %d 角色 / %d 敌人 / %d 卡" % [map_name, deployed, data.enemies.size(), data.cards_applied.size()]
	if not str(result.warning).is_empty(): summary += " · " + str(result.warning)
	return {"occupied":true, "summary":summary, "error":"", "warning":result.warning}

func _exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size(): return false
	for key: String in expected:
		if not value.has(key): return false
	return true

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1]) and absf(float(value[0])) <= 10000.0 and absf(float(value[1])) <= 10000.0

func _validate(value: Variant) -> String:
	if not value is Dictionary: return "场景内容必须为 JSON 对象。"
	var data: Dictionary = value
	if not _exact_keys(data, ["format", "schema_version", "stage_id", "layout_id", "heroes", "enemies", "cards_applied", "settings"]): return "场景字段缺失或包含不支持的内容。"
	if not data.format is String or data.format != "rift_guard_workshop" or not _number(data.schema_version) or float(data.schema_version) != SCHEMA_VERSION: return "不支持此场景格式版本。"
	if not data.stage_id is String or not data.layout_id is String: return "场景地图编号格式错误。"
	_catalog()
	if not _database.errors.is_empty(): return "当前游戏目录数据有误，无法重建场景。"
	if not _database.stages.has(data.stage_id): return "场景引用了不存在的地图。"
	if not Layouts.valid(data.layout_id) or (data.stage_id != "stage_endless" and data.layout_id != "blood_gate"): return "场景地图布局无效。"
	if not data.heroes is Array or data.heroes.size() > MAX_HEROES: return "角色列表无效或超过 %d 个。" % MAX_HEROES
	if not data.enemies is Array or data.enemies.size() > MAX_ENEMIES: return "敌人列表无效或超过 %d 个。" % MAX_ENEMIES
	if not data.cards_applied is Array or data.cards_applied.size() > MAX_CARDS: return "卡牌列表无效或超过 %d 条。" % MAX_CARDS
	if not data.settings is Dictionary or not _exact_keys(data.settings, ["speed", "auto_attack", "enemy_action", "invulnerable", "infinite_energy"]): return "场景控制设置不完整。"
	for flag: String in FLAGS:
		if not data.settings[flag] is bool: return "场景控制开关必须为布尔值。"
	if not _number(data.settings.speed) or not float(data.settings.speed) in SPEEDS: return "场景倍率必须为 0.25、0.5、1 或 2。"
	var hero_ids: Dictionary = {}
	for row: Variant in data.heroes:
		if not row is Dictionary or not _exact_keys(row, ["character_id", "position", "deployed"]): return "角色记录格式错误。"
		if not row.character_id is String or not _database.characters.has(row.character_id): return "场景引用了不存在的角色。"
		if hero_ids.has(row.character_id): return "场景中存在重复角色。"
		if not row.deployed is bool or not _position(row.position): return "角色位置或部署状态无效。"
		hero_ids[row.character_id] = hero_ids.size()
	if data.heroes.is_empty() or str(data.heroes[0].character_id) != "traveler": return "场景必须保留旅行者的初始角色名册。"
	for row: Variant in data.enemies:
		if not row is Dictionary or not _exact_keys(row, ["kind", "position"]): return "敌人记录格式错误。"
		if not row.kind is String or not Session.Catalog.ENEMIES.has(row.kind): return "场景引用了不存在的敌人。"
		if not _position(row.position): return "敌人位置必须为有限数值坐标。"
	var previous_count := 1
	for row: Variant in data.cards_applied:
		if not row is Dictionary or not _exact_keys(row, ["hero_character_id", "card_id", "roster"]): return "卡牌记录缺少加卡名册或包含不支持的内容。"
		if not row.hero_character_id is String or not hero_ids.has(row.hero_character_id): return "卡牌缺少对应的场景角色。"
		if not row.card_id is String or not _cards.has(row.card_id): return "场景引用了不存在的卡牌。"
		if not row.roster is Array or row.roster.size() < previous_count or row.roster.size() > data.heroes.size(): return "卡牌角色名册数量或创建时序无效。"
		var target_deployed := false
		for index in row.roster.size():
			var member: Variant = row.roster[index]
			if not member is Dictionary or not _exact_keys(member, ["character_id", "deployed"]): return "卡牌角色名册格式错误。"
			if not member.character_id is String or not member.deployed is bool: return "卡牌角色名册编号或部署状态无效。"
			if member.character_id != str(data.heroes[index].character_id): return "卡牌名册必须按实际创建顺序引用唯一角色。"
			if member.character_id == row.hero_character_id: target_deployed = member.deployed
		if not target_deployed: return "加卡时对应角色必须已创建并部署。"
		previous_count = row.roster.size()
		var effect := str(_cards[row.card_id].get("effect", ""))
		if effect == "deploy_reinforcement": return "增援卡不可重放，请直接放置对应角色。"
		if effect in ["assign_traveler_element", "dual_element_mythic"] and row.hero_character_id != "traveler": return "旅行者元素卡必须对应旅行者。"
	return ""

func _restore(data: Dictionary) -> Dictionary:
	# _read_slot/capture fully validate shape before any catalog lookup or cast here.
	var fresh = Session.new()
	fresh.change_map(data.stage_id, data.layout_id)
	var runtime_ids := {"traveler":0}
	var final_heroes: Dictionary = {}
	for row: Dictionary in data.heroes: final_heroes[row.character_id] = row
	for row: Dictionary in data.cards_applied:
		var roster_error := _sync_roster(fresh, row.roster, final_heroes, runtime_ids)
		if not roster_error.is_empty(): return _fail(roster_error)
		fresh.selected_kind = "hero"
		fresh.selected_id = runtime_ids[row.hero_character_id]
		if not fresh.apply_card(_cards[row.card_id]): return _fail("卡牌无法按当前规则重放，场景未载入。")
	var final_error := _sync_roster(fresh, data.heroes, final_heroes, runtime_ids)
	if not final_error.is_empty(): return _fail(final_error)
	for row: Dictionary in data.enemies:
		var point := Vector2(float(row.position[0]), float(row.position[1]))
		if not fresh.place_enemy(row.kind, point): return _fail("敌人位置越界或被当前地图地形阻挡，场景未载入。")
	for flag: String in FLAGS: fresh.set(flag, data.settings[flag])
	fresh.speed = float(data.settings.speed)
	fresh.clear_effects(false)
	fresh.recover()
	fresh._sync_flags()
	fresh.sim.elapsed = 0.0
	fresh.paused = true
	fresh.selected_kind = ""
	fresh.selected_id = -1
	fresh.message = "场景配置已载入并暂停：单位已恢复，时间归零；不恢复弹道、计时与伤害。"
	return {"ok":true, "error":"", "session":fresh}

func _sync_roster(fresh, roster: Array, final_heroes: Dictionary, runtime_ids: Dictionary) -> String:
	for member: Dictionary in roster:
		var row: Dictionary = final_heroes[member.character_id]
		var point := Vector2(float(row.position[0]), float(row.position[1]))
		if not fresh.legal(point): return "角色位置越界或被当前地图地形阻挡，场景未载入。"
		if not runtime_ids.has(member.character_id):
			if not fresh.place_hero(member.character_id, point): return "无法重建场景角色。"
			runtime_ids[member.character_id] = fresh.selected_id
		var hero: Dictionary = fresh.sim.heroes[runtime_ids[member.character_id]]
		hero.pos = point
		hero.target = point
		hero.moving = false
		# Do not transiently deploy a dormant hero: active orbital synergies differ.
		if member.deployed and not hero.deployed:
			if not fresh.place_hero(member.character_id, point): return "无法恢复角色部署状态。"
		elif not member.deployed and hero.deployed:
			fresh.selected_kind = "hero"
			fresh.selected_id = runtime_ids[member.character_id]
			fresh.remove_selected()
	return ""
