extends CanvasLayer

signal chosen(mode_id: String)
signal settings_requested
signal continue_requested

const WHITE := Color("#f3e9df")
const MUTED := Color("#ad929b")
const ACCENT := Color("#f07482")

var root: Control
var hud
var buttons: Dictionary = {}
var settings_button: Button
var continue_button: Button
var checkpoint_title: Label
var checkpoint_detail: Label

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0001.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.01, 0.025, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	owner_hud.label(root, Vector2(78, 52), Vector2(760, 22), "R I F T   G U A R D   /   作 战 模 式", 12, ACCENT)
	owner_hud.label(root, Vector2(78, 82), Vector2(760, 52), "选择游戏模式", 36, WHITE)
	owner_hud.label(root, Vector2(80, 140), Vector2(920, 24), "不同模式使用独立地图规则，强化均可无限叠加。", 13, MUTED)
	_build_mode_card(Rect2(80, 205, 535, 320), "rift_watch", "01", "裂隙守望", "多角色路线防守", "八关剧情战役  ·  折线路径  ·  固定Boss\n守卫水晶并在每关重建卡牌构筑", "进入关卡选择")
	_build_mode_card(Rect2(665, 205, 535, 320), "endless_survival", "∞", "无尽生存", "四屏追击生存", "无固定波次  ·  四边刷怪  ·  无限升级\n操纵旅行者移动，同行者跟随攻击", "立即进入荒原")
	var checkpoint_frame: Panel = owner_hud.panel(root, Rect2(80, 551, 1120, 128), Color("#1c1420"), Color("#885064"))
	checkpoint_title = owner_hud.label(checkpoint_frame, Vector2(24, 15), Vector2(850, 26), "继续远征", 18, WHITE)
	checkpoint_detail = owner_hud.label(checkpoint_frame, Vector2(24, 48), Vector2(850, 40), "", 12, MUTED)
	checkpoint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_hud.label(checkpoint_frame, Vector2(24, 98), Vector2(1040, 20), "战斗从本关起点重开；节点进度保留。新远征将在编队确认后更新检查点。", 11, MUTED)
	continue_button = owner_hud.button(checkpoint_frame, Rect2(908, 29, 188, 52), "继续远征   →", true)
	continue_button.pressed.connect(func(): continue_requested.emit())
	settings_button = owner_hud.button(root, Rect2(1000, 106, 200, 44), "设置   [F10]", false)
	settings_button.pressed.connect(func(): settings_requested.emit())
	root.hide()

func _build_mode_card(rect: Rect2, id: String, number: String, name: String, subtitle: String, description: String, action: String) -> void:
	var button: Button = hud.button(root, rect, "", true)
	buttons[id] = button
	button.pressed.connect(func():
		root.hide()
		chosen.emit(id))
	hud.label(button, Vector2(30, 26), Vector2(120, 68), number, 48, ACCENT)
	hud.label(button, Vector2(30, 112), Vector2(460, 44), name, 30, WHITE)
	hud.label(button, Vector2(30, 164), Vector2(460, 28), subtitle, 16, ACCENT)
	var copy: Label = hud.label(button, Vector2(30, 204), Vector2(460, 56), description, 13, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.label(button, Vector2(30, 273), Vector2(460, 28), action + "   →", 14, WHITE)

func activate_at(point: Vector2) -> bool:
	if not is_open():
		return false
	if continue_button != null and not continue_button.disabled and continue_button.get_global_rect().has_point(point):
		continue_requested.emit()
		return true
	if settings_button != null and settings_button.visible and settings_button.get_global_rect().has_point(point):
		settings_requested.emit()
		return true
	for id: String in buttons:
		var item: Button = buttons[id]
		if not item.disabled and item.visible and item.get_global_rect().has_point(point):
			item.pressed.emit()
			return true
	return false

func update_checkpoint(result: Dictionary, database) -> void:
	continue_button.disabled = not bool(result.get("ok", false))
	checkpoint_title.text = "继续远征" if not continue_button.disabled else "远征检查点"
	checkpoint_detail.text = str(result.get("message", "尚无远征检查点。"))
	if continue_button.disabled:
		return
	var data: Dictionary = result.snapshot
	var names: Array[String] = []
	for id: String in data.run.squad:
		names.append(str(database.characters.get(id, {}).get("name", id)))
	var location: String = {"briefing":"开战前剧情", "battle":"关卡起点", "route":"裂隙路线", "event":"待选事件", "cleared":"通关后整备"}.get(str(data.phase), "裂隙路线")
	checkpoint_title.text = "%s · %s · ◇ %d" % [str(database.stages.get(str(data.stage_id), {}).get("name", data.stage_id)), location, int(data.run.rift_shards)]
	checkpoint_detail.text = "%s  /  %s\n%s" % [" · ".join(names), str(data.saved_at).replace("T", " "), str(result.message)]

func open() -> void:
	root.show()
	for id: String in buttons:
		buttons[id].disabled = false
	buttons["rift_watch"].grab_focus()

func close() -> void:
	root.hide()

func is_open() -> bool:
	return root != null and root.visible
