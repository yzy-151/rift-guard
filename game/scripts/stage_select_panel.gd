extends CanvasLayer

const Catalog = preload("res://scripts/combat_catalog.gd")

signal chosen(stage_id: String)

const WHITE := Color("#f8efe8")
const MUTED := Color("#b5a4aa")
const ACCENT := Color("#ff5066")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")

var root: Control
var buttons: Dictionary = {}
var stage_frames: Dictionary = {}
var status_labels: Dictionary = {}
var stage_previews: Dictionary = {}
var stage_preview_borders: Dictionary = {}
var stage_backs: Dictionary = {}
var lock_labels: Dictionary = {}
var database
var progress
var hud

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud
	database = game_database
	progress = state
	layer = 44
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = UI_SKIN.mission_background
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.color = Color(0.018, 0.009, 0.016, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var header := ColorRect.new()
	header.position = UI_LAYOUT.mission_header_rect.position
	header.size = UI_LAYOUT.mission_header_rect.size
	header.color = Color(0.012, 0.01, 0.014, 0.92)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)
	owner_hud.label(root, Vector2(52, 30), Vector2(680, 18), "M I S S I O N   /   裂 隙 选 择", 12, ACCENT)
	owner_hud.label(root, Vector2(50, 53), Vector2(720, 53), "选择作战区域", 36, WHITE)
	var rule := ColorRect.new()
	rule.position = Vector2(50, 109)
	rule.size = Vector2(456, 3)
	rule.color = ACCENT
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rule)
	owner_hud.label(root, Vector2(50, 118), Vector2(920, 18), "通关前一关后解锁下一关  ·  选择后进入编队", 11, MUTED)
	var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])
	for i in ids.size():
		_build_stage_card(i, str(ids[i]), database.stages[str(ids[i])])
	var endless: Dictionary = database.modes.get("endless_survival", {})
	var endless_id := str(endless.get("starting_stage_id", "stage_endless"))
	var endless_button: Button = owner_hud.button(root, UI_LAYOUT.mission_endless_rect, "", true)
	var endless_empty := StyleBoxEmpty.new()
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		endless_button.add_theme_stylebox_override(style_state, endless_empty)
	var endless_frame := NinePatchRect.new()
	endless_frame.texture = UI_SKIN.mission_endless
	endless_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	endless_frame.patch_margin_left = 86
	endless_frame.patch_margin_right = 86
	endless_frame.patch_margin_top = 28
	endless_frame.patch_margin_bottom = 28
	endless_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	endless_button.add_child(endless_frame)
	endless_button.name = "stage_endless"
	endless_button.pressed.connect(select.bind(endless_id))
	buttons[endless_id] = endless_button
	owner_hud.label(endless_button, Vector2(28, 8), Vector2(110, 42), "∞", 34, ACCENT)
	owner_hud.label(endless_button, Vector2(140, 11), Vector2(340, 30), "无尽生存 / 猩红荒原", 20, WHITE)
	owner_hud.label(endless_button, Vector2(430, 16), Vector2(endless_button.size.x - 560, 22), "四屏地图 · 四边追击 · 旅行者升级 · 无限构筑", 12, MUTED)
	owner_hud.label(endless_button, Vector2(endless_button.size.x - 112, 14), Vector2(90, 26), "进入  →", 14, WHITE)
	root.hide()

func _build_stage_card(index: int, id: String, stage: Dictionary) -> void:
	var column := index % 4
	var row := int(index / 4)
	var rect := Rect2(UI_LAYOUT.mission_grid_origin + Vector2(column * (UI_LAYOUT.mission_card_size.x + UI_LAYOUT.mission_card_gap.x), row * (UI_LAYOUT.mission_card_size.y + UI_LAYOUT.mission_card_gap.y)), UI_LAYOUT.mission_card_size)
	var item: Button = hud.button(root, rect, "", index == 0)
	var card_surface := StyleBoxFlat.new()
	card_surface.bg_color = Color("#0d090d")
	card_surface.corner_radius_top_left = 5
	card_surface.corner_radius_top_right = 5
	card_surface.corner_radius_bottom_left = 5
	card_surface.corner_radius_bottom_right = 5
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(style_state, card_surface)
	item.name = "stage_card_%d" % (index + 1)
	item.pressed.connect(select.bind(id))
	buttons[id] = item
	var card_back := ColorRect.new()
	card_back.position = Vector2.ZERO
	card_back.size = rect.size
	card_back.color = Color(0.085, 0.018, 0.030, 1.0) if index == 0 else Color(0.025, 0.018, 0.026, 1.0)
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(card_back)
	stage_backs[id] = card_back
	var card_frame := NinePatchRect.new()
	card_frame.texture = UI_SKIN.mission_card_red if index == 0 else UI_SKIN.mission_card_gray
	card_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_frame.patch_margin_left = 46
	card_frame.patch_margin_right = 46
	card_frame.patch_margin_top = 42
	card_frame.patch_margin_bottom = 42
	card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(card_frame)
	stage_frames[id] = card_frame
	item.focus_entered.connect(_focus_stage.bind(id))
	item.mouse_entered.connect(func(): item.grab_focus())
	hud.label(item, Vector2(15, 8), Vector2(rect.size.x - 54, 27), "%02d   %s" % [index + 1, stage.name], 15, WHITE)
	hud.label(item, Vector2(rect.size.x - 38, 7), Vector2(22, 28), "♆", 19, ACCENT)
	var preview_back := ColorRect.new()
	preview_back.position = UI_LAYOUT.mission_preview_rect.position - Vector2(0, 1)
	preview_back.size = UI_LAYOUT.mission_preview_rect.size + Vector2(0, 3)
	preview_back.color = Color(0.015, 0.008, 0.016, 1.0)
	preview_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(preview_back)
	var preview := TextureRect.new()
	preview.texture = load("res://assets/ui/rift_v2/stage_thumbnails/stage_%02d.png" % (index + 1))
	# Configure expansion before assigning the rect so the source texture minimum size cannot enlarge the thumbnail.
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.position = UI_LAYOUT.mission_preview_rect.position
	preview.size = UI_LAYOUT.mission_preview_rect.size
	preview.clip_contents = true
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.modulate = Color(0.82, 0.74, 0.77, 0.88)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(preview)
	stage_previews[id] = preview
	var preview_border := Panel.new()
	preview_border.position = Vector2(13, 39)
	preview_border.size = Vector2(rect.size.x - 26, 74)
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = Color("#71505a")
	border_style.set_border_width_all(1)
	preview_border.add_theme_stylebox_override("panel", border_style)
	preview_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(preview_border)
	stage_preview_borders[id] = preview_border
	var preview_shade := ColorRect.new()
	preview_shade.position = preview.position
	preview_shade.size = preview.size
	preview_shade.color = Color(0.02, 0.005, 0.018, 0.12)
	preview_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(preview_shade)
	var lock_stamp: Label = hud.label(item, Vector2(14, 53), Vector2(rect.size.x - 28, 48), "🔒  LOCKED", 20, Color("#ff586d"))
	lock_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lock_stamp.add_theme_color_override("font_shadow_color", Color("#150b11"))
	lock_stamp.add_theme_constant_override("shadow_offset_x", 2)
	lock_stamp.add_theme_constant_override("shadow_offset_y", 2)
	lock_stamp.hide()
	lock_labels[id] = lock_stamp
	var boss: Dictionary = Catalog.ENEMIES.get(str(stage.boss_id), {})
	hud.label(item, Vector2(15, 123), Vector2(rect.size.x - 30, 19), "◷  %d分%02d秒  ·  %s" % [int(stage.duration_seconds) / 60, int(stage.duration_seconds) % 60, boss.get("name", stage.boss_id)], 10, MUTED)
	var record: Label = hud.label(item, UI_LAYOUT.mission_status_rect.position, UI_LAYOUT.mission_status_rect.size, "", 9, WHITE)
	status_labels[id] = record
	hud.label(item, UI_LAYOUT.mission_action_rect.position, UI_LAYOUT.mission_action_rect.size, "进入编队   →", 11, ACCENT)

func _focus_stage(id: String) -> void:
	for stage_id: String in stage_frames:
		var unlocked := _is_unlocked(stage_id)
		var focused := stage_id == id and unlocked
		stage_frames[stage_id].texture = UI_SKIN.mission_card_red if focused else (UI_SKIN.mission_card_gray if unlocked else UI_SKIN.mission_card_locked)
		buttons[stage_id].modulate = Color.WHITE if focused else Color(0.82, 0.79, 0.82, 0.96)
		if stage_previews.has(stage_id):
			stage_previews[stage_id].modulate = Color.WHITE if focused else (Color(0.66, 0.61, 0.65, 0.78) if unlocked else Color(0.34, 0.33, 0.36, 0.55))
		if stage_preview_borders.has(stage_id):
			var border: StyleBoxFlat = stage_preview_borders[stage_id].get_theme_stylebox("panel")
			border.border_color = ACCENT if focused else Color("#71505a")
			border.set_border_width_all(2 if focused else 1)
		if stage_backs.has(stage_id):
			stage_backs[stage_id].color = Color(0.085, 0.018, 0.030, 1.0) if focused else Color(0.025, 0.018, 0.026, 1.0)

func activate_at(point: Vector2) -> bool:
	if not is_open():
		return false
	for id: String in buttons:
		var item: Button = buttons[id]
		if not item.disabled and item.visible and item.get_global_rect().has_point(point):
			select(id)
			return true
	return false

func open() -> void:
	_refresh()
	root.show()
	for id: String in buttons:
		if not buttons[id].disabled:
			buttons[id].grab_focus()
			break

func close() -> void:
	root.hide()

func is_open() -> bool:
	return root != null and root.visible

func select(id: String) -> void:
	if not _is_unlocked(id):
		return
	root.hide()
	chosen.emit(id)

func _is_unlocked(id: String) -> bool:
	if id == "stage_endless":
		return true
	var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])
	var index := ids.find(id)
	return index == 0 or (index > 0 and progress.cleared_stages.has(str(ids[index - 1])))

func _refresh() -> void:
	for id: String in buttons:
		var unlocked := _is_unlocked(id)
		var item: Button = buttons[id]
		item.disabled = not unlocked
		item.modulate = Color.WHITE if unlocked else Color(0.44, 0.42, 0.46, 0.90)
		item.self_modulate = Color.WHITE
		if stage_frames.has(id):
			stage_frames[id].texture = UI_SKIN.mission_card_gray if unlocked else UI_SKIN.mission_card_locked
		if stage_previews.has(id):
			stage_previews[id].modulate = Color(0.76, 0.70, 0.74, 0.86) if unlocked else Color(0.34, 0.33, 0.36, 0.55)
		if stage_backs.has(id):
			stage_backs[id].color = Color(0.025, 0.018, 0.026, 1.0)
		if lock_labels.has(id):
			lock_labels[id].visible = not unlocked
		if not status_labels.has(id):
			continue
		var record: Dictionary = progress.stage_records.get(id, {})
		var status: Label = status_labels[id]
		if not unlocked:
			status.text = "🔒 档案封锁\n先通关前一作战区域"
		elif record.is_empty():
			status.text = "▶ 尚未通关\n最佳记录：--"
		else:
			status.text = "★ 已通关   ·   最高击退 %d\n盾 最高基地 %d%%   ·   连杀 %d" % [int(record.get("best_kills", 0)), int(record.get("best_base_hp", 0)), int(record.get("best_streak", 0))]
