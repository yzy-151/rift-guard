extends CanvasLayer

signal chosen(mode_id: String)
signal settings_requested
signal continue_requested

const WHITE := Color("#f7eee7")
const MUTED := Color("#a99199")
const ACCENT := Color("#ff4f66")
const DARK := Color("#09070b")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var root: Control
var hud
var buttons: Dictionary = {}
var card_panels: Dictionary = {}
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
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color("#08060c")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(backdrop)
	_add_red_horizon()
	owner_hud.label(root, Vector2(76, 34), Vector2(720, 18), "R I F T   G U A R D   /   作 战 模 式", 12, ACCENT)
	owner_hud.label(root, Vector2(74, 56), Vector2(760, 48), "选择游戏模式", 37, WHITE)
	var rule := ColorRect.new()
	rule.position = Vector2(74, 113)
	rule.size = Vector2(480, 3)
	rule.color = ACCENT
	root.add_child(rule)
	owner_hud.label(root, Vector2(74, 124), Vector2(760, 20), "不同模式使用独立规则与地图，强化均可无限叠加。", 12, MUTED)
	settings_button = _command_button(Rect2(1030, 54, 180, 46), "⚙  设置  F10")
	settings_button.pressed.connect(func(): settings_requested.emit())
	_build_mode_card(Rect2(70, 176, 548, 330), "rift_watch", "01", "裂隙守望", "多角色路线防守", "八关剧情战役 · 折线路径 · 固定 Boss\n守卫水晶，并在每关重建卡牌构筑", "进入关卡选择", "res://assets/ui/rift_v2/stage_thumbnails/stage_03.png", true)
	_build_mode_card(Rect2(662, 176, 548, 330), "endless_survival", "∞", "无尽生存", "四屏追击生存", "四边刷怪 · 无限升级 · 动态地形\n操纵旅行者移动，同行者跟随攻击", "立即进入荒原", "res://assets/ui/rift_v2/stage_thumbnails/stage_08.png", false)
	_build_checkpoint()
	root.hide()

func _add_red_horizon() -> void:
	var glow := ColorRect.new()
	glow.position = Vector2(0, 154)
	glow.size = Vector2(1280, 370)
	glow.color = Color(0.24, 0.018, 0.055, 0.30)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(glow)
	for i in 11:
		var shard := ColorRect.new()
		shard.position = Vector2(i * 132 - 26, 205 + (i % 3) * 34)
		shard.size = Vector2(94, 280 - (i % 4) * 32)
		shard.rotation = deg_to_rad(-8 + (i % 3) * 7)
		shard.color = Color(0.16, 0.018, 0.035, 0.38)
		shard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shard)

func _build_mode_card(rect: Rect2, id: String, number: String, title: String, subtitle: String, description: String, action_text: String, image_path: String, active: bool) -> void:
	var item: Button = hud.button(root, rect, "", active)
	item.name = "Mode_" + id
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons[id] = item
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _card_style(active, false))
	item.add_child(panel)
	card_panels[id] = panel
	var preview := TextureRect.new()
	preview.texture = load(image_path)
	preview.position = Vector2(5, 5)
	preview.size = Vector2(rect.size.x - 10, rect.size.y - 10)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.modulate = Color(0.72, 0.55, 0.58, 0.45 if active else 0.28)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview)
	var shade := ColorRect.new()
	shade.position = Vector2(5, 5)
	shade.size = preview.size
	shade.color = Color(0.02, 0.006, 0.014, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)
	var accent_bar := ColorRect.new()
	accent_bar.position = Vector2(0, 0)
	accent_bar.size = Vector2(8, rect.size.y)
	accent_bar.color = ACCENT if active else Color("#5e5861")
	panel.add_child(accent_bar)
	hud.label(item, Vector2(32, 28), Vector2(120, 60), number, 48, ACCENT if active else Color("#80777f"))
	hud.label(item, Vector2(34, 112), Vector2(470, 44), title, 31, WHITE)
	hud.label(item, Vector2(34, 158), Vector2(470, 26), subtitle, 16, ACCENT if active else Color("#b899a0"))
	var copy: Label = hud.label(item, Vector2(34, 204), Vector2(470, 58), description, 13, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action := Panel.new()
	action.position = Vector2(34, 274)
	action.size = Vector2(350, 40)
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.add_theme_stylebox_override("panel", _action_style(active))
	item.add_child(action)
	var action_label: Label = hud.label(action, Vector2(18, 7), Vector2(312, 25), action_text + "   →", 15, WHITE)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	item.focus_entered.connect(_focus_mode.bind(id))
	item.mouse_entered.connect(func(): item.grab_focus())
	item.pressed.connect(func(): root.hide(); chosen.emit(id))

func _build_checkpoint() -> void:
	var panel := Panel.new()
	panel.position = Vector2(70, 544)
	panel.size = Vector2(1140, 126)
	panel.add_theme_stylebox_override("panel", _checkpoint_style())
	root.add_child(panel)
	var glyph: Label = hud.label(panel, Vector2(22, 30), Vector2(42, 48), "♆", 32, ACCENT)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkpoint_title = hud.label(panel, Vector2(78, 18), Vector2(720, 28), "远征检查点", 19, WHITE)
	checkpoint_detail = hud.label(panel, Vector2(78, 50), Vector2(740, 48), "", 11, MUTED)
	checkpoint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_button = _command_button(Rect2(862, 580, 310, 54), "继续远征   →")
	continue_button.pressed.connect(func(): continue_requested.emit())

func _command_button(rect: Rect2, text_value: String) -> Button:
	var item: Button = hud.button(root, rect, text_value, false)
	item.add_theme_font_size_override("font_size", 15)
	item.add_theme_stylebox_override("normal", _button_style(Color("#20151c"), Color("#96505f")))
	item.add_theme_stylebox_override("hover", _button_style(Color("#41131f"), ACCENT))
	item.add_theme_stylebox_override("pressed", _button_style(Color("#5b1726"), Color("#ff8495")))
	item.add_theme_stylebox_override("focus", _button_style(Color("#41131f"), ACCENT))
	return item

func _card_style(active: bool, focused: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("#100b11")
	box.border_color = ACCENT if focused or active else Color("#655e66")
	box.set_border_width_all(3 if focused else 2)
	box.corner_radius_top_left = 6; box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6; box.corner_radius_bottom_right = 6
	box.shadow_color = Color(ACCENT, 0.20 if focused else 0.06)
	box.shadow_size = 9 if focused else 3
	return box

func _action_style(active: bool) -> StyleBoxFlat:
	return _button_style(Color("#4e111f") if active else Color("#171319"), ACCENT if active else Color("#6d656e"))

func _checkpoint_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.035, 0.018, 0.028, 0.98)
	box.border_color = Color("#9b4658")
	box.set_border_width_all(1)
	box.border_width_left = 5
	return box

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = 4; box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4; box.corner_radius_bottom_right = 4
	box.content_margin_left = 16; box.content_margin_right = 16
	return box

func _focus_mode(id: String) -> void:
	for mode_id: String in card_panels:
		var focused := mode_id == id
		card_panels[mode_id].add_theme_stylebox_override("panel", _card_style(mode_id == "rift_watch", focused))
		buttons[mode_id].modulate = Color.WHITE if focused else Color(0.82, 0.79, 0.82, 0.96)

func activate_at(point: Vector2) -> bool:
	if not is_open(): return false
	if continue_button != null and not continue_button.disabled and continue_button.get_global_rect().has_point(point): continue_requested.emit(); return true
	if settings_button != null and settings_button.get_global_rect().has_point(point): settings_requested.emit(); return true
	for id: String in buttons:
		var item: Button = buttons[id]
		if not item.disabled and item.get_global_rect().has_point(point): item.pressed.emit(); return true
	return false

func update_checkpoint(result: Dictionary, database) -> void:
	continue_button.disabled = not bool(result.get("ok", false))
	checkpoint_title.text = "远征检查点"
	checkpoint_detail.text = str(result.get("message", "尚无远征检查点。"))
	if continue_button.disabled: return
	var data: Dictionary = result.snapshot
	var names: Array[String] = []
	for id: String in data.run.squad: names.append(str(database.characters.get(id, {}).get("name", id)))
	var location: String = {"briefing":"开战前剧情", "battle":"关卡起点", "route":"裂隙路线", "event":"待选事件", "cleared":"通关后整备"}.get(str(data.phase), "裂隙路线")
	checkpoint_title.text = "%s · %s · ◇ %d" % [str(database.stages.get(str(data.stage_id), {}).get("name", data.stage_id)), location, int(data.run.rift_shards)]
	checkpoint_detail.text = "%s  /  %s\n%s" % [" · ".join(names), str(data.saved_at).replace("T", " "), str(result.message)]

func open() -> void:
	root.show()
	for id: String in buttons: buttons[id].disabled = false
	buttons["rift_watch"].grab_focus()
func close() -> void: root.hide()
func is_open() -> bool: return root != null and root.visible

