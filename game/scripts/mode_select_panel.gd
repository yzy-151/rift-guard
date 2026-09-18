extends CanvasLayer

signal chosen(mode_id: String)
signal settings_requested
signal continue_requested

const WHITE := Color("#f7eee7")
const MUTED := Color("#a99199")
const ACCENT := Color("#ff4f66")
const DARK := Color("#09070b")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const MODE_GRAY = preload("res://assets/ui/rift_v2/components/mode_card_gray.png")
const MODE_RED = preload("res://assets/ui/rift_v2/components/mode_card_red.png")
const CHECKPOINT_SKIN = preload("res://assets/ui/rift_v2/components/mode_checkpoint.png")
const SMALL_BUTTON = preload("res://assets/ui/rift_v2/components/button_small.png")
const SETTINGS_SKIN = preload("res://assets/ui/rift_v2/components/mission_header.png")
const CONTINUE_GLYPH = preload("res://assets/ui/rift_v2/components/ritCode0001.png")

var root: Control
var hud
var buttons: Dictionary = {}
var card_panels: Dictionary = {}
var action_skins: Dictionary = {}
var settings_button: Button
var continue_button: Button
var checkpoint_title: Label
var checkpoint_detail: Label
var select_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer

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
	settings_button = _textured_button(root, Rect2(1026, 50, 196, 52), SETTINGS_SKIN, "⚙  设置  F10", false)
	settings_button.pressed.connect(func(): _play(confirm_sound); settings_requested.emit())
	_build_mode_card(Rect2(64, 176, 560, 330), "rift_watch", "01", "裂隙守望", "多角色路线防守", "八关剧情战役 · 折线路径 · 固定 Boss\n守卫水晶，并在每关重建卡牌构筑", "进入关卡选择", "res://assets/ui/rift_v2/stage_thumbnails/stage_03.png", true)
	_build_mode_card(Rect2(656, 176, 560, 330), "endless_survival", "∞", "无尽生存", "四屏追击生存", "四边刷怪 · 无限升级 · 动态地形\n操纵旅行者移动，同行者跟随攻击", "立即进入荒原", "res://assets/ui/rift_v2/stage_thumbnails/stage_08.png", false)
	_build_checkpoint()
	select_sound = _audio("res://assets/helltaker/audio/button_chapter_highlight_01.wav", -7.0)
	confirm_sound = _audio("res://assets/helltaker/audio/button_menu_confirm_01.wav", -4.0)
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
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	item.add_child(panel)
	var preview := TextureRect.new()
	preview.texture = load(image_path)
	preview.position = Vector2(28, 24)
	preview.size = Vector2(rect.size.x - 56, rect.size.y - 48)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.modulate = Color(0.72, 0.55, 0.58, 0.45 if active else 0.28)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(preview)
	var shade := ColorRect.new()
	shade.position = preview.position
	shade.size = preview.size
	shade.color = Color(0.02, 0.006, 0.014, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(shade)
	var frame_skin := TextureRect.new()
	frame_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_skin.texture = MODE_RED if active else MODE_GRAY
	frame_skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_skin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(frame_skin)
	card_panels[id] = frame_skin
	hud.label(item, Vector2(48, 32), Vector2(120, 58), number, 46, ACCENT if active else Color("#80777f"))
	hud.label(item, Vector2(48, 108), Vector2(456, 42), title, 30, WHITE)
	hud.label(item, Vector2(48, 151), Vector2(456, 25), subtitle, 15, ACCENT if active else Color("#b899a0"))
	var copy: Label = hud.label(item, Vector2(48, 191), Vector2(456, 50), description, 13, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_label: Label = hud.label(item, Vector2(70, 248), Vector2(260, 30), action_text + "  →", 14, WHITE)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_skins[id] = action_label
	item.focus_entered.connect(_focus_mode.bind(id))
	item.mouse_entered.connect(func(): _play(select_sound); item.grab_focus())
	item.pressed.connect(func(): _play(confirm_sound); root.hide(); chosen.emit(id))

func _build_checkpoint() -> void:
	var panel := TextureRect.new()
	panel.position = Vector2(70, 544)
	panel.size = Vector2(1140, 147)
	panel.texture = CHECKPOINT_SKIN
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(panel)
	checkpoint_title = hud.label(panel, Vector2(96, 32), Vector2(650, 28), "远征检查点", 19, WHITE)
	checkpoint_detail = hud.label(panel, Vector2(96, 64), Vector2(650, 46), "", 11, MUTED)
	checkpoint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continue_button = hud.button(panel, Rect2(790, 39, 265, 66), "载入检查点  →", false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		continue_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	continue_button.add_theme_font_size_override("font_size", 16)
	continue_button.mouse_entered.connect(func(): _play(select_sound); continue_button.modulate = Color.WHITE)
	continue_button.mouse_exited.connect(func(): continue_button.modulate = Color(0.76, 0.72, 0.76, 0.92))
	continue_button.modulate = Color(0.76, 0.72, 0.76, 0.92)
	continue_button.pressed.connect(func(): _play(confirm_sound); continue_requested.emit())

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
		card_panels[mode_id].texture = MODE_RED if focused else MODE_GRAY
		buttons[mode_id].modulate = Color.WHITE if focused else Color(0.72, 0.70, 0.73, 0.94)
		action_skins[mode_id].modulate = Color.WHITE if focused else Color(0.58, 0.55, 0.59, 0.88)

func _textured_button(parent: Control, rect: Rect2, texture: Texture2D, text_value: String, bright: bool) -> Button:
	var item: Button = hud.button(parent, rect, "", false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var skin := TextureRect.new()
	skin.texture = texture
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.modulate = Color("#ff526a") if bright else Color(0.78, 0.74, 0.79, 0.94)
	item.add_child(skin)
	item.move_child(skin, 0)
	if not text_value.is_empty():
		var caption: Label = hud.label(item, Vector2.ZERO, rect.size, text_value, 15, WHITE)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.mouse_entered.connect(func(): _play(select_sound); skin.modulate = Color.WHITE)
	item.mouse_exited.connect(func(): skin.modulate = Color("#ff526a") if bright else Color(0.78, 0.74, 0.79, 0.94))
	return item

func _set_nine_patch(node: NinePatchRect, margin: int) -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		node.set_patch_margin(side, margin)

func _audio(path: String, gain: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = "SFX"
	player.volume_db = gain
	add_child(player)
	return player

func _play(player: AudioStreamPlayer) -> void:
	if player != null:
		player.stop()
		player.play()

func activate_at(point: Vector2) -> bool:
	if not is_open(): return false
	if continue_button != null and not continue_button.disabled and continue_button.get_global_rect().has_point(point): _play(confirm_sound); continue_requested.emit(); return true
	if settings_button != null and settings_button.get_global_rect().has_point(point): _play(confirm_sound); settings_requested.emit(); return true
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

