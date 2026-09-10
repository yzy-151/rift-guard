extends CanvasLayer

signal node_chosen(node_id: String)
signal closed

const TYPE_NAMES := {
	"combat": "战斗", "story": "剧情", "elite": "精英", "shop": "商店",
	"rest": "休整", "recruit": "招募", "hidden": "隐藏", "boss": "首领"
}
const TYPE_COLORS := {
	"combat": Color("#e59aa4"), "story": Color("#bc91d9"), "elite": Color("#f0b45f"),
	"shop": Color("#6fd6bd"), "rest": Color("#80b9e8"), "recruit": Color("#f09bbf"),
	"hidden": Color("#8f78bb"), "boss": Color("#ff536a")
}

var root: Control
var hud
var database
var run_state
var buttons: Dictionary = {}
var node_rows: Dictionary = {}
var title: Label
var detail: Label

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	run_state = state
	layer = 45
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/helltaker/backgrounds/chapterBG0008.png")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	root.add_child(backdrop)
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.012, 0.022, 0.87)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var frame: Panel = hud.panel(root, Rect2(62, 40, 1156, 640), Color("#171119"), Color("#a34c60"))
	hud.ornament(frame, Rect2(-18, -18, 1192, 676))
	hud.label(frame, Vector2(34, 20), Vector2(600, 20), "R O U T E   /   裂 隙 路 线", 11, Color("#e3a2a5"))
	title = hud.label(frame, Vector2(34, 48), Vector2(720, 40), "裂隙序章 · 分支路线", 29, Color("#f3e9df"))
	detail = hud.label(frame, Vector2(34, 92), Vector2(1080, 42), "", 12, Color("#b9a6ad"))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close_button: Button = hud.button(frame, Rect2(1025, 28, 92, 42), "关闭", false)
	close_button.pressed.connect(close)
	_build_nodes(frame)
	root.hide()

func _build_nodes(frame: Control) -> void:
	var chapters: Array = database.campaign_map.get("chapters", [])
	if chapters.is_empty():
		return
	var nodes: Array = chapters[0].get("nodes", [])
	var positions := [
		Vector2(78, 235), Vector2(302, 150), Vector2(302, 330), Vector2(530, 120),
		Vector2(530, 360), Vector2(756, 235), Vector2(756, 410), Vector2(970, 235)
	]
	for i in nodes.size():
		var node: Dictionary = nodes[i]
		var id := str(node.id)
		node_rows[id] = node
		var kind := str(node.get("type", "combat"))
		var button: Button = hud.button(frame, Rect2(positions[i], Vector2(154, 78)), "%s\n%s" % [TYPE_NAMES.get(kind, kind), _node_label(node)], false)
		button.add_theme_color_override("font_color", TYPE_COLORS.get(kind, Color.WHITE))
		button.add_theme_color_override("font_disabled_color", TYPE_COLORS.get(kind, Color.WHITE).darkened(0.20))
		button.mouse_entered.connect(_show_detail.bind(id))
		button.pressed.connect(_choose.bind(id))
		buttons[id] = button
	for node: Dictionary in nodes:
		var from := str(node.id)
		for next_id: Variant in node.get("next", []):
			if buttons.has(from) and buttons.has(str(next_id)):
				var connector := Line2D.new()
				connector.width = 2.0
				connector.default_color = Color(0.72, 0.33, 0.40, 0.45)
				connector.points = PackedVector2Array([buttons[from].position + buttons[from].size * 0.5, buttons[str(next_id)].position + buttons[str(next_id)].size * 0.5])
				connector.z_index = 0
				frame.add_child(connector)
				frame.move_child(connector, 0)

func _node_label(node: Dictionary) -> String:
	if node.has("stage_id"):
		return str(database.stages.get(str(node.stage_id), {}).get("name", node.stage_id))
	if node.has("unlock"):
		return "解锁 " + str(database.characters.get(str(node.unlock), {}).get("name", "角色"))
	return {"story":"命运抉择", "shop":"补给交换", "rest":"恢复整备"}.get(str(node.get("type","")), "未知节点")

func open() -> void:
	refresh()
	root.show()

func close() -> void:
	root.hide()
	closed.emit()

func is_open() -> bool:
	return root != null and root.visible

func refresh() -> void:
	var current := str(run_state.current_node)
	var allowed: Array = node_rows.get(current, {}).get("next", [])
	if current not in run_state.completed_nodes:
		allowed.append(current)
	for id: String in buttons:
		var button: Button = buttons[id]
		var completed: bool = id in run_state.completed_nodes
		var available: bool = id in allowed
		button.disabled = false
		button.set_meta("route_available", available)
		button.modulate = Color("#c5b8bd") if not available else (Color("#8ee8c4") if completed else Color.WHITE)
	detail.text = "当前位置：%s  ·  可前往节点会高亮；剧情选择、关系值与隐藏角色会改变后续路线。" % _node_label(node_rows.get(current, {}))

func _show_detail(id: String) -> void:
	var node: Dictionary = node_rows.get(id, {})
	detail.text = "%s / %s  ·  %s" % [TYPE_NAMES.get(str(node.get("type","")), "节点"), _node_label(node), "已完成" if id in run_state.completed_nodes else ("可进入" if bool(buttons[id].get_meta("route_available", false)) else "路线尚未解锁")]

func _choose(id: String) -> void:
	if not buttons.has(id) or not bool(buttons[id].get_meta("route_available", false)):
		return
	node_chosen.emit(id)
