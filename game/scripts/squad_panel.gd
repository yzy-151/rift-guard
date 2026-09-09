extends CanvasLayer

signal confirmed(squad: Array[String])

const WHITE := Color("#f3e9df")
const MUTED := Color("#9a858e")
const ACCENT := Color("#e7a0a4")
const ELEMENT_COLORS := {
	"none": Color("#e9d7ad"), "anemo": Color("#63e6c0"), "electro": Color("#bf83ff"),
	"pyro": Color("#ff745c"), "hydro": Color("#5ab8ff"), "geo": Color("#e8b94d"), "cryo": Color("#9de7f2")
}

var root: Control
var title: Label
var subtitle: Label
var count_label: Label
var confirm_button: Button
var buttons: Dictionary = {}
var state_labels: Dictionary = {}
var database
var progress
var hud
var selected: Array[String] = []
var next_stage_id := ""

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	progress = state
	layer = 45
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = preload("res://assets/helltaker/backgrounds/chapterBG0008.png")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	owner_hud.bind(background, "squad_background")
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.012, 0.02, 0.88)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, Rect2(72, 42, 1136, 636), Color("#171119"), Color("#9f4f60"))
	owner_hud.bind(frame, "squad_frame")
	owner_hud.ornament(frame, Rect2(-18, -18, 1172, 672))
	owner_hud.label(frame, Vector2(36, 22), Vector2(600, 20), "P A R T Y   /   裂 隙 编 队", 12, ACCENT)
	title = owner_hud.label(frame, Vector2(36, 50), Vector2(700, 42), "选择下一关出战角色", 30, WHITE)
	owner_hud.bind(title, "squad_title")
	subtitle = owner_hud.label(frame, Vector2(36, 94), Vector2(900, 24), "旅行者必须出战 · 点击已解锁角色加入或移出队伍", 14, MUTED)
	owner_hud.bind(subtitle, "squad_subtitle")
	count_label = owner_hud.label(frame, Vector2(820, 62), Vector2(270, 28), "", 16, ACCENT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var order: Array[String] = []
	for id: String in database.characters:
		order.append(id)
	for i in order.size():
		var id := order[i]
		var data: Dictionary = database.characters[id]
		var col := i % 4
		var row := i / 4
		var button: Button = owner_hud.button(frame, Rect2(36 + col * 268, 130 + row * 118, 250, 106), "", true)
		owner_hud.bind(button, "squad_character_%d" % (i + 1))
		button.name = "Squad_" + id
		button.pressed.connect(toggle.bind(id))
		buttons[id] = button
		owner_hud.label(button, Vector2(16, 8), Vector2(218, 28), str(data.name), 18, ELEMENT_COLORS.get(str(data.element), WHITE))
		var state_label: Label = owner_hud.label(button, Vector2(164, 10), Vector2(70, 22), "", 10, ACCENT)
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_labels[id] = state_label
		owner_hud.label(button, Vector2(16, 38), Vector2(218, 20), "%s · %s" % [_element_name(str(data.element)), data.role], 11, WHITE)
		owner_hud.label(button, Vector2(16, 64), Vector2(218, 34), "ATK %d  ·  射程 %d\n攻速 %.2f/s  ·  阻挡 %d" % [int(data.attack), int(data.attack_range), float(data.attack_rate), int(data.block)], 10, MUTED)
	confirm_button = owner_hud.button(frame, Rect2(308, 500, 520, 54), "确认编队并进入下一关   →", true)
	owner_hud.bind(confirm_button, "squad_confirm")
	confirm_button.add_theme_font_size_override("font_size", 18)
	confirm_button.pressed.connect(confirm)
	owner_hud.label(frame, Vector2(36, 580), Vector2(1064, 22), "已解锁角色永久保留 · 本关卡牌与元素将在下一关重置", 12, MUTED)
	root.hide()

func open(stage_id: String, current_squad: Array[String], newly_unlocked: Array = []) -> void:
	next_stage_id = stage_id
	var unlocked_changed := false
	for value: Variant in newly_unlocked:
		var unlocked_id := str(value)
		if not unlocked_id.is_empty() and not progress.unlocked_characters.has(unlocked_id):
			progress.unlocked_characters[unlocked_id] = true
			unlocked_changed = true
	if unlocked_changed:
		progress.save_progress()
	selected = ["traveler"]
	for id: String in current_squad:
		if id != "traveler" and progress.unlocked_characters.has(id) and selected.size() < 3:
			selected.append(id)
	var stage: Dictionary = database.stages.get(stage_id, {})
	title.text = "下一关：%s" % stage.get("name", stage_id)
	subtitle.text = "新角色已解锁：%s" % _names(newly_unlocked) if not newly_unlocked.is_empty() else "旅行者必须出战 · 点击已解锁角色加入或移出队伍"
	_refresh()
	root.show()
	confirm_button.grab_focus()

func toggle(id: String) -> void:
	if not progress.unlocked_characters.has(id) or id == "traveler":
		return
	if id in selected:
		selected.erase(id)
	elif selected.size() < 3:
		selected.append(id)
	_refresh()

func confirm() -> void:
	if selected.is_empty() or selected.size() > 3 or "traveler" not in selected:
		return
	root.hide()
	confirmed.emit(selected.duplicate())

func activate_at(point: Vector2) -> bool:
	if not is_open():
		return false
	if not confirm_button.disabled and confirm_button.get_global_rect().has_point(point):
		confirm()
		return true
	for id: String in buttons:
		var item: Button = buttons[id]
		if not item.disabled and item.visible and item.get_global_rect().has_point(point):
			toggle(id)
			return true
	return false

func is_open() -> bool:
	return root != null and root.visible

func _refresh() -> void:
	count_label.text = "出战 %d / 3" % selected.size()
	confirm_button.disabled = selected.is_empty() or selected.size() > 3
	for id: String in buttons:
		var button: Button = buttons[id]
		var known: bool = progress.unlocked_characters.has(id)
		button.disabled = not known
		button.modulate = Color.WHITE if id in selected else (Color("#c7afb7") if known else Color("#352c31"))
		button.tooltip_text = "已选择" if id in selected else ("点击加入编队" if known else "随剧情通关后解锁")
		var state_label: Label = state_labels[id]
		state_label.text = "◆ 出战" if id in selected else ("可选择" if known else "未解锁")
		state_label.add_theme_color_override("font_color", ACCENT if id in selected else (WHITE if known else MUTED))

func _names(ids: Array) -> String:
	var result: Array[String] = []
	for value: Variant in ids:
		var id := str(value)
		if database.characters.has(id):
			result.append(str(database.characters[id].name))
	return "、".join(result)

func _element_name(element: String) -> String:
	return {"none": "无元素", "anemo": "风元素", "electro": "雷元素", "pyro": "火元素", "hydro": "水元素", "geo": "岩元素", "cryo": "冰元素"}.get(element, element)
