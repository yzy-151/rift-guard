extends CanvasLayer

signal confirmed(squad: Array[String])

const Preview = preload("res://scripts/character_breath_preview.gd")
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
var previews: Dictionary = {}
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
	veil.color = Color(0.025, 0.012, 0.02, 0.90)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, Rect2(48, 24, 1184, 672), Color("#171119"), Color("#9f4f60"))
	owner_hud.bind(frame, "squad_frame")
	owner_hud.ornament(frame, Rect2(-16, -16, 1216, 704))
	owner_hud.label(frame, Vector2(30, 18), Vector2(650, 18), "P A R T Y   /   裂 隙 编 队", 11, ACCENT)
	title = owner_hud.label(frame, Vector2(30, 40), Vector2(720, 36), "选择下一关出战角色", 27, WHITE)
	owner_hud.bind(title, "squad_title")
	subtitle = owner_hud.label(frame, Vector2(30, 78), Vector2(900, 22), "旅行者固定出战 · 最多选择三名角色", 13, MUTED)
	owner_hud.bind(subtitle, "squad_subtitle")
	count_label = owner_hud.label(frame, Vector2(910, 50), Vector2(236, 28), "", 16, ACCENT)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var order: Array[String] = []
	for id: String in database.characters:
		order.append(id)
	for i in order.size():
		_build_character_card(frame, order[i], i)
	confirm_button = owner_hud.button(frame, Rect2(324, 548, 536, 52), "确认编队并进入下一关   →", true)
	owner_hud.bind(confirm_button, "squad_confirm")
	confirm_button.add_theme_font_size_override("font_size", 17)
	confirm_button.pressed.connect(confirm)
	owner_hud.label(frame, Vector2(30, 622), Vector2(1124, 20), "◆ 点击角色卡加入或移出编队    ◆ 悬停可查看完整战斗数值    ◆ 解锁状态永久保留", 11, MUTED)
	root.hide()

func _build_character_card(frame: Control, id: String, index: int) -> void:
	var data: Dictionary = database.characters[id]
	var col := index % 4
	var row := index / 4
	var card_rect := Rect2(30 + col * 285, 112 + row * 140, 270, 126)
	var button: Button = hud.button(frame, card_rect, "", true)
	hud.bind(button, "squad_character_%d" % (index + 1))
	button.name = "Squad_" + id
	button.clip_contents = true
	button.pressed.connect(toggle.bind(id))
	buttons[id] = button
	var element := str(data.element)
	var color: Color = ELEMENT_COLORS.get(element, WHITE)
	var preview = Preview.new()
	preview.position = Vector2(10, 15)
	preview.size = Vector2(88, 98)
	button.add_child(preview)
	var asset: Dictionary = database.assets.get(str(data.asset_key), {})
	preview.configure(id, asset, color, not progress.unlocked_characters.has(id))
	previews[id] = preview
	var badge := Panel.new()
	badge.position = Vector2(108, 14)
	badge.size = Vector2(35, 24)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(color, 0.17)
	badge_style.border_color = Color(color, 0.72)
	badge_style.set_border_width_all(1)
	badge_style.corner_radius_top_left = 4
	badge_style.corner_radius_top_right = 4
	badge_style.corner_radius_bottom_left = 4
	badge_style.corner_radius_bottom_right = 4
	badge.add_theme_stylebox_override("panel", badge_style)
	button.add_child(badge)
	var glyph: Label = hud.label(badge, Vector2.ZERO, badge.size, _element_glyph(element), 13, color)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.label(button, Vector2(151, 13), Vector2(108, 26), str(data.name), 18, color)
	var divider := ColorRect.new()
	divider.position = Vector2(108, 45)
	divider.size = Vector2(148, 1)
	divider.color = Color(color, 0.30)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(divider)
	hud.label(button, Vector2(108, 53), Vector2(150, 20), str(data.role), 11, WHITE)
	hud.label(button, Vector2(108, 75), Vector2(150, 17), _element_name(element), 10, MUTED)
	var state_label: Label = hud.label(button, Vector2(108, 98), Vector2(148, 17), "", 10, ACCENT)
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	state_labels[id] = state_label
	button.tooltip_text = "%s / %s\n生命 %d  攻击 %d  护甲 %d\n射程 %d  攻速 %.2f/s  移速 %d  阻挡 %d" % [data.name, data.role, int(data.max_hp), int(data.attack), int(data.armor), int(data.attack_range), float(data.attack_rate), int(data.move_speed), int(data.block)]

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
	subtitle.text = "新角色已解锁：%s" % _names(newly_unlocked) if not newly_unlocked.is_empty() else "旅行者固定出战 · 最多选择三名角色"
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
	count_label.text = "出战  %d / 3" % selected.size()
	confirm_button.disabled = selected.is_empty() or selected.size() > 3
	for id: String in buttons:
		var button: Button = buttons[id]
		var known: bool = progress.unlocked_characters.has(id)
		button.disabled = not known
		button.modulate = Color.WHITE if id in selected else (Color("#c7afb7") if known else Color("#4b3c43"))
		var state_label: Label = state_labels[id]
		state_label.text = "◆ 出战中" if id in selected else ("＋ 加入队伍" if known else "LOCKED / 未解锁")
		state_label.add_theme_color_override("font_color", ACCENT if id in selected else (WHITE if known else MUTED))
		var preview = previews[id]
		preview.set_locked(not known)

func _names(ids: Array) -> String:
	var result: Array[String] = []
	for value: Variant in ids:
		var id := str(value)
		if database.characters.has(id):
			result.append(str(database.characters[id].name))
	return "、".join(result)

func _element_name(element: String) -> String:
	return {"none": "无元素", "anemo": "风元素", "electro": "雷元素", "pyro": "火元素", "hydro": "水元素", "geo": "岩元素", "cryo": "冰元素"}.get(element, element)

func _element_glyph(element: String) -> String:
	return {"none": "无", "anemo": "风", "electro": "雷", "pyro": "火", "hydro": "水", "geo": "岩", "cryo": "冰"}.get(element, "?")
