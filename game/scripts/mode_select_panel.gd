extends CanvasLayer

signal chosen(mode_id: String)
signal settings_requested
signal continue_requested

const WHITE := Color("#f8efe8")
const MUTED := Color("#b6a1aa")
const ACCENT := Color("#ff5368")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")

var root: Control
var hud
var buttons: Dictionary = {}
var mode_frames: Dictionary = {}
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
	_add_background(UI_SKIN.mode_background)
	var header_plate := ColorRect.new()
	header_plate.position = UI_LAYOUT.mode_header_rect.position
	header_plate.size = UI_LAYOUT.mode_header_rect.size
	header_plate.color = Color(0.015, 0.012, 0.018, 0.94)
	header_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_plate)
	owner_hud.label(root, Vector2(82, 38), Vector2(700, 20), "R I F T   G U A R D   /   作 战 模 式", 13, ACCENT)
	owner_hud.label(root, Vector2(80, 62), Vector2(760, 58), "选择游戏模式", 39, WHITE)
	var header_rule := ColorRect.new()
	header_rule.position = Vector2(80, 126)
	header_rule.size = Vector2(470, 3)
	header_rule.color = ACCENT
	header_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header_rule)
	owner_hud.label(root, Vector2(80, 136), Vector2(760, 20), "不同模式使用独立地图规则，强化均可无限叠加。", 12, MUTED)
	settings_button = owner_hud.button(root, UI_LAYOUT.mode_settings_rect, "⚙   设置   [F10]", false)
	settings_button.add_theme_font_size_override("font_size", 16)
	settings_button.pressed.connect(func(): settings_requested.emit())
	_build_mode_card(UI_LAYOUT.mode_campaign_rect, "rift_watch", "01", "裂隙守望", "多角色路线防守", "八关剧情战役  ·  折线路径  ·  固定 Boss\n守卫水晶，并在每关重建卡牌构筑", "进入关卡选择", "res://assets/ui/rift_v2/stage_thumbnails/stage_03.png", true)
	_build_mode_card(UI_LAYOUT.mode_endless_rect, "endless_survival", "∞", "无尽生存", "四屏追击生存", "无固定波次  ·  四边刷怪  ·  无限升级\n操纵旅行者移动，同行者跟随攻击", "立即进入荒原", "res://assets/ui/rift_v2/stage_thumbnails/stage_08.png", false)
	var checkpoint_frame: Panel = owner_hud.panel(root, UI_LAYOUT.mode_checkpoint_rect, Color(0.025, 0.018, 0.028, 0.96), Color("#d94459"))
	var checkpoint_ornament: NinePatchRect = owner_hud.ornament(checkpoint_frame, Rect2(-7, -7, 1158, 140))
	checkpoint_ornament.modulate = Color("#df4057")
	checkpoint_title = owner_hud.label(checkpoint_frame, Vector2(72, 17), Vector2(780, 25), "继续远征", 18, WHITE)
	checkpoint_detail = owner_hud.label(checkpoint_frame, Vector2(72, 49), Vector2(780, 42), "", 11, MUTED)
	checkpoint_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owner_hud.label(checkpoint_frame, Vector2(72, 96), Vector2(760, 17), "战斗从本关起点重开，节点进度保留。", 10, Color("#7f6f77"))
	owner_hud.label(checkpoint_frame, Vector2(24, 28), Vector2(38, 48), "♆", 34, ACCENT)
	continue_button = owner_hud.button(checkpoint_frame, Rect2(885, 31, 226, 58), "继续远征   →", true)
	continue_button.add_theme_font_size_override("font_size", 17)
	continue_button.pressed.connect(func(): continue_requested.emit())
	root.hide()

func _add_background(texture: Texture2D) -> void:
	var background := TextureRect.new()
	background.texture = texture
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.006, 0.012, 0.48)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)

func _build_mode_card(rect: Rect2, id: String, number: String, title: String, subtitle: String, description: String, action_text: String, image_path: String, active: bool) -> void:
	var item: Button = hud.button(root, rect, "", active)
	buttons[id] = item
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, empty_style)
	item.focus_entered.connect(_focus_mode.bind(id))
	item.mouse_entered.connect(func(): item.grab_focus())
	item.pressed.connect(func():
		root.hide()
		chosen.emit(id))
	var preview := TextureRect.new()
	preview.texture = load(image_path)
	preview.position = UI_LAYOUT.mode_card_preview_rect.position
	preview.size = UI_LAYOUT.mode_card_preview_rect.size
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	preview.modulate = Color(0.82, 0.78, 0.80, 0.86) if active else Color(0.52, 0.49, 0.54, 0.72)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(preview)
	var shade := ColorRect.new()
	shade.position = UI_LAYOUT.mode_card_preview_rect.position
	shade.size = UI_LAYOUT.mode_card_preview_rect.size
	shade.color = Color(0.018, 0.012, 0.020, 0.54 if active else 0.68)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(shade)
	var card_frame := NinePatchRect.new()
	card_frame.texture = UI_SKIN.mode_card_red if active else UI_SKIN.mode_card_gray
	card_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_frame.patch_margin_left = 72
	card_frame.patch_margin_right = 72
	card_frame.patch_margin_top = 54
	card_frame.patch_margin_bottom = 54
	card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(card_frame)
	item.move_child(card_frame, 0)
	mode_frames[id] = card_frame
	hud.label(item, Vector2(34, 26), Vector2(140, 68), number, 49, ACCENT if active else Color("#8a8087"))
	hud.label(item, UI_LAYOUT.mode_card_title_rect.position, UI_LAYOUT.mode_card_title_rect.size, title, 31, WHITE)
	hud.label(item, UI_LAYOUT.mode_card_subtitle_rect.position, UI_LAYOUT.mode_card_subtitle_rect.size, subtitle, 16, ACCENT if active else Color("#d6949d"))
	var copy: Label = hud.label(item, UI_LAYOUT.mode_card_description_rect.position, UI_LAYOUT.mode_card_description_rect.size, description, 13, MUTED)
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var action_plate := ColorRect.new()
	action_plate.position = UI_LAYOUT.mode_card_action_rect.position
	action_plate.size = UI_LAYOUT.mode_card_action_rect.size
	action_plate.color = Color(0.34, 0.045, 0.085, 0.82) if active else Color(0.10, 0.09, 0.12, 0.86)
	action_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(action_plate)
	hud.label(item, UI_LAYOUT.mode_card_action_rect.position + Vector2(24, 7), UI_LAYOUT.mode_card_action_rect.size - Vector2(30, 12), action_text + "   →", 15, WHITE)

func _focus_mode(id: String) -> void:
	for mode_id: String in mode_frames:
		mode_frames[mode_id].texture = UI_SKIN.mode_card_red if mode_id == id else UI_SKIN.mode_card_gray
		buttons[mode_id].modulate = Color.WHITE if mode_id == id else Color(0.78, 0.75, 0.78, 0.94)

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
