extends CanvasLayer

signal confirmed(squad: Array[String])

const Preview = preload("res://scripts/character_breath_preview.gd")
const WHITE := Color("#f3e9df")
const MUTED := Color("#9a858e")
const ACCENT := Color("#e7a0a4")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const BAR_TEXTURE = preload("res://assets/ui/custom/bar_hell_dim.png")
const CARD_BORDER_IDLE := Color(0.42, 0.24, 0.29, 0.9)
const CARD_BORDER_HOVER := Color(0.87, 0.32, 0.34, 1.0)
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
var card_selection_rules: Dictionary = {}
var grid_scroll: ScrollContainer
var grid_host: Control
var database
var progress
var hud
var selected: Array[String] = []
var next_stage_id := ""
var preview_has_anchor := true
var preview_has_validity := true

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
	background.texture = UI_SKIN.squad_background
	background.position = UI_LAYOUT.squad_background_rect.position
	background.size = UI_LAYOUT.squad_background_rect.size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	owner_hud.bind(background, "squad_background")
	var veil := ColorRect.new()
	veil.color = Color(0.025, 0.012, 0.02, 0.76)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, UI_LAYOUT.squad_frame_rect, Color(0.075, 0.035, 0.055, 0.94), Color("#9f4f60"))
	owner_hud.bind(frame, "squad_frame")
	# 横向装饰条是 24:1 的素材，只有横着用才不变形；整块面板套九宫格会把端点装饰拉成长箭头
	_divider(frame, Rect2(30, 98, 1124, 46), Color.WHITE)
	_divider(frame, Rect2(30, 606, 1124, 46), Color.WHITE)
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
	grid_scroll = ScrollContainer.new()
	grid_scroll.position = UI_LAYOUT.squad_grid_view_rect.position
	grid_scroll.size = UI_LAYOUT.squad_grid_view_rect.size
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	grid_scroll.clip_contents = true
	frame.add_child(grid_scroll)
	owner_hud.bind(grid_scroll, "squad_grid_view")
	grid_host = Control.new()
	var row_count := ceili(float(order.size()) / 4.0)
	grid_host.custom_minimum_size = Vector2(UI_LAYOUT.squad_grid_view_rect.size.x, row_count * UI_LAYOUT.squad_card_size.y + maxi(0, row_count - 1) * UI_LAYOUT.squad_card_gap.y)
	grid_scroll.add_child(grid_host)
	for i in order.size():
		_build_character_card(grid_host, order[i], i)
	confirm_button = owner_hud.button(frame, UI_LAYOUT.squad_confirm_rect, "确认编队并进入下一关   →", true)
	owner_hud.bind(confirm_button, "squad_confirm")
	confirm_button.add_theme_font_size_override("font_size", 17)
	var confirm_empty := StyleBoxEmpty.new()
	for button_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		confirm_button.add_theme_stylebox_override(button_state, confirm_empty)
	var confirm_frame := TextureRect.new()
	confirm_frame.texture = UI_SKIN.choice_frame_gray
	confirm_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	confirm_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	confirm_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	confirm_frame.show_behind_parent = true
	confirm_button.add_child(confirm_frame)
	confirm_button.move_child(confirm_frame, 0)
	confirm_button.mouse_entered.connect(func(): confirm_frame.texture = UI_SKIN.choice_frame_red)
	confirm_button.mouse_exited.connect(func(): confirm_frame.texture = UI_SKIN.choice_frame_gray)
	confirm_button.focus_entered.connect(func(): confirm_frame.texture = UI_SKIN.choice_frame_red)
	confirm_button.focus_exited.connect(func(): confirm_frame.texture = UI_SKIN.choice_frame_gray)
	confirm_button.pressed.connect(confirm)
	owner_hud.label(frame, UI_LAYOUT.squad_footer_rect.position, UI_LAYOUT.squad_footer_rect.size, "◆ 点击角色卡加入或移出编队    ◆ 悬停可查看完整战斗数值    ◆ 解锁状态永久保留", 11, MUTED)
	root.hide()

func _build_character_card(frame: Control, id: String, index: int) -> void:
	var data: Dictionary = database.characters[id]
	var col := index % 4
	var row := index / 4
	var card_rect := Rect2(Vector2(col * (UI_LAYOUT.squad_card_size.x + UI_LAYOUT.squad_card_gap.x), row * (UI_LAYOUT.squad_card_size.y + UI_LAYOUT.squad_card_gap.y)), UI_LAYOUT.squad_card_size)
	var button: Button = hud.button(frame, card_rect, "", true)
	hud.bind(button, "squad_character_%d" % (index + 1))
	button.position = card_rect.position
	button.size = card_rect.size
	button.name = "Squad_" + id
	button.clip_contents = true
	button.pressed.connect(toggle.bind(id))
	buttons[id] = button
	button.add_theme_stylebox_override("normal", _card_style(CARD_BORDER_IDLE))
	button.add_theme_stylebox_override("hover", _card_style(CARD_BORDER_HOVER))
	button.add_theme_stylebox_override("pressed", _card_style(CARD_BORDER_HOVER))
	button.add_theme_stylebox_override("focus", _card_style(CARD_BORDER_HOVER))
	var selected_rule := ColorRect.new()
	selected_rule.position = Vector2(2, UI_LAYOUT.squad_card_size.y - 5)
	selected_rule.size = Vector2(UI_LAYOUT.squad_card_size.x - 4, 3)
	selected_rule.color = Color("#df5157")
	selected_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_rule.visible = false
	button.add_child(selected_rule)
	card_selection_rules[id] = selected_rule
	var element := str(data.element)
	var color: Color = ELEMENT_COLORS.get(element, WHITE)
	var preview = Preview.new()
	preview.position = UI_LAYOUT.squad_preview_rect.position
	preview.size = UI_LAYOUT.squad_preview_rect.size
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
		var selected_rule: ColorRect = card_selection_rules[id]
		selected_rule.visible = id in selected
		var border := CARD_BORDER_HOVER if id in selected else (CARD_BORDER_IDLE if known else Color(0.24, 0.17, 0.20, 0.85))
		button.add_theme_stylebox_override("normal", _card_style(border))
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

## 角色卡边框：2px 直角描边，出战时换亮红。
func _card_style(border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.105, 0.055, 0.075, 0.94)
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = 2
	box.corner_radius_top_right = 2
	box.corner_radius_bottom_left = 2
	box.corner_radius_bottom_right = 2
	return box

## 横向装饰条始终等比例显示，避免端点和线条被横向扯宽。
func _divider(parent: Node, rect: Rect2, tint: Color) -> TextureRect:
	var bar := TextureRect.new()
	bar.texture = BAR_TEXTURE
	bar.position = rect.position
	bar.size = rect.size
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bar.modulate = tint
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar
## 用选项框素材做按钮/卡片的九宫格样式（端点装饰落在 100px 边距内）。
func _ornate_style(texture: Texture2D) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = texture
	box.texture_margin_left = 100.0
	box.texture_margin_right = 100.0
	box.texture_margin_top = 22.0
	box.texture_margin_bottom = 22.0
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


