extends CanvasLayer

const Catalog = preload("res://scripts/combat_catalog.gd")
signal chosen(stage_id: String)
signal cancelled

const WHITE := Color("#f8efe8")
const MUTED := Color("#aa969e")
const ACCENT := Color("#ff5066")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const BUFF_GRAY = preload("res://assets/ui/rift_v2/components/buff_card_gray.png")
const BUFF_RED = preload("res://assets/ui/rift_v2/components/buff_card_red.png")
const ENDLESS_SKIN = preload("res://assets/ui/rift_v2/components/mission_endless.png")
const HEADER_BUTTON = preload("res://assets/ui/rift_v2/components/mission_header.png")

var root: Control
var buttons: Dictionary = {}
var card_panels: Dictionary = {}
var card_frames: Dictionary = {}
var status_labels: Dictionary = {}
var stage_previews: Dictionary = {}
var lock_labels: Dictionary = {}
var roster_label: Label
var database
var progress
var hud
var back_button: Button
var select_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud; database = game_database; progress = state; layer = 44
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.theme = owner_hud.get_child(0).theme; add_child(root)
	var background := ColorRect.new(); background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); background.color = Color("#08070b"); root.add_child(background)
	var upper_glow := ColorRect.new(); upper_glow.position = Vector2(0, 0); upper_glow.size = Vector2(1280, 145); upper_glow.color = Color(0.20, 0.018, 0.045, 0.28); root.add_child(upper_glow)
	owner_hud.label(root, Vector2(48, 25), Vector2(680, 18), "M I S S I O N   /   裂 隙 选 择", 12, ACCENT)
	owner_hud.label(root, Vector2(46, 48), Vector2(720, 48), "三章试玩 · 选择作战区域", 35, WHITE)
	var rule := ColorRect.new(); rule.position = Vector2(46, 106); rule.size = Vector2(456, 3); rule.color = ACCENT; root.add_child(rule)
	owner_hud.label(root, UI_LAYOUT.mission_release_notice_rect.position, UI_LAYOUT.mission_release_notice_rect.size, "本次开放第 1—3 关 · 后续章节暂未开放\n通关后，可携带队伍与卡牌转入无尽模式。", 17, MUTED)
	roster_label = owner_hud.label(root, UI_LAYOUT.mission_roster_rect.position, UI_LAYOUT.mission_roster_rect.size, "", 16, WHITE)
	roster_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back_button = _textured_button(Rect2(1030, 50, 196, 52), "←  返回", false)
	back_button.pressed.connect(func(): _play(confirm_sound); close(); cancelled.emit())
	var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])
	for i in ids.size(): _build_stage_card(i, str(ids[i]), database.stages[str(ids[i])])
	select_sound = AudioStreamPlayer.new(); select_sound.stream = preload("res://assets/helltaker/audio/button_chapter_highlight_01.wav"); select_sound.bus = "SFX"; select_sound.volume_db = -7; add_child(select_sound)
	confirm_sound = AudioStreamPlayer.new(); confirm_sound.stream = preload("res://assets/helltaker/audio/button_chapter_confirm_01.wav"); confirm_sound.bus = "SFX"; confirm_sound.volume_db = -4; add_child(confirm_sound)
	root.hide()

func _build_stage_card(index: int, id: String, stage: Dictionary) -> void:
	var col := index % 4; var row := int(index / 4)
	var rect := Rect2(Vector2(150 + col * 335, 210 + row * 310), Vector2(278, 258))
	var item: Button = hud.button(root, rect, "", index == 0); item.name = "Stage_%02d" % (index + 1)
	item.scale = Vector2(1.15, 1.15)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons[id] = item
	var panel := Panel.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); item.add_child(panel); card_panels[id] = panel
	var frame := TextureRect.new(); frame.position = Vector2(10, 0); frame.size = Vector2(258, 258); frame.texture = BUFF_RED if index == 0 else BUFF_GRAY; frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(frame); card_frames[id] = frame
	var preview_clip := Control.new(); preview_clip.position = Vector2(34, 49); preview_clip.size = Vector2(210, 88); preview_clip.clip_contents = true; preview_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(preview_clip)
	var preview_number := int(str(stage.get("visual_stage_id", id)).trim_prefix("stage_"))
	var preview := TextureRect.new(); preview.texture = load("res://assets/ui/stage_thumbnails_v60/battle_%02d.png" % preview_number); preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED; preview.mouse_filter = Control.MOUSE_FILTER_IGNORE; preview_clip.add_child(preview); stage_previews[id] = preview
	var number: Label = hud.label(panel, Vector2(34, 18), Vector2(32, 24), "%02d" % (index + 1), 14, ACCENT if index == 0 else MUTED)
	hud.label(panel, Vector2(68, 18), Vector2(176, 24), str(stage.name), 14, WHITE)
	var boss: Dictionary = Catalog.ENEMIES.get(str(stage.boss_id), {})
	hud.label(panel, Vector2(34, 145), Vector2(210, 18), "◷ %d:%02d  ·  %s" % [int(stage.duration_seconds) / 60, int(stage.duration_seconds) % 60, boss.get("name", stage.boss_id)], 9, MUTED)
	var status: Label = hud.label(panel, Vector2(34, 168), Vector2(210, 38), "", 9, WHITE); status_labels[id] = status
	var action: Label = hud.label(panel, Vector2(34, 218), Vector2(210, 18), "出发剧情   →", 11, ACCENT); action.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var lock: Label = hud.label(panel, Vector2(34, 72), Vector2(210, 44), "🔒  LOCKED", 18, ACCENT); lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER; lock.hide(); lock_labels[id] = lock
	item.focus_entered.connect(_focus_stage.bind(id)); item.mouse_entered.connect(func(): item.grab_focus(); _play(select_sound)); item.pressed.connect(select.bind(id))

func _build_endless() -> void:
	var id := "stage_endless"
	var item: Button = hud.button(root, Rect2(48, 640, 1180, 72), "", true)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]: item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	buttons[id] = item
	var panel := Panel.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new()); item.add_child(panel); card_panels[id] = panel
	var frame := TextureRect.new(); frame.position = Vector2(140, 0); frame.size = Vector2(900, 72); frame.texture = ENDLESS_SKIN; frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; frame.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(frame); card_frames[id] = frame
	var mode_copy: Label = hud.label(panel, Vector2(250, 19), Vector2(570, 30), "四屏追击 · 动态地形 · 旅行者升级 · 无限构筑", 16, WHITE)
	mode_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var enter: Label = hud.label(panel, Vector2(858, 18), Vector2(150, 32), "进入荒原  →", 16, WHITE); enter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	item.focus_entered.connect(_focus_stage.bind(id)); item.mouse_entered.connect(func(): item.grab_focus(); _play(select_sound)); item.pressed.connect(select.bind(id))

func _card_style(unlocked: bool, focused: bool, locked: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color = Color("#100b11") if unlocked else Color("#0b0a0c"); box.border_color = ACCENT if focused else (Color("#746971") if unlocked else Color("#352f35")); box.set_border_width_all(3 if focused else 2); box.corner_radius_top_left = 5; box.corner_radius_top_right = 5; box.corner_radius_bottom_left = 5; box.corner_radius_bottom_right = 5; box.shadow_color = Color(ACCENT, 0.20 if focused else 0.04); box.shadow_size = 8 if focused else 2; return box

func _textured_button(rect: Rect2, text_value: String, primary: bool) -> Button:
	var item: Button = hud.button(root, rect, "", false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var skin := TextureRect.new()
	skin.texture = HEADER_BUTTON
	skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.modulate = Color.WHITE if primary else Color(0.58,0.55,0.59,0.88)
	item.add_child(skin); item.move_child(skin,0)
	var caption: Label = hud.label(item, Vector2.ZERO, rect.size, text_value, 15, WHITE)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.mouse_entered.connect(func(): _play(select_sound); skin.modulate = Color.WHITE)
	item.mouse_exited.connect(func(): skin.modulate = Color.WHITE if primary else Color(0.58,0.55,0.59,0.88))
	return item

func _set_nine_patch(node: NinePatchRect, margin: int) -> void:
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		node.set_patch_margin(side, margin)

func _button(rect: Rect2, text_value: String, primary: bool) -> Button:
	var item: Button = hud.button(root, rect, text_value, primary); item.add_theme_font_size_override("font_size", 14); item.add_theme_stylebox_override("normal", _button_style(Color("#181218"), Color("#80505b"))); item.add_theme_stylebox_override("hover", _button_style(Color("#3b121d"), ACCENT)); item.add_theme_stylebox_override("focus", _button_style(Color("#3b121d"), ACCENT)); return item
func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color = fill; box.border_color = border; box.set_border_width_all(2); box.corner_radius_top_left = 4; box.corner_radius_top_right = 4; box.corner_radius_bottom_left = 4; box.corner_radius_bottom_right = 4; return box
func _play(player: AudioStreamPlayer) -> void:
	if player != null: player.stop(); player.play()

func _focus_stage(id: String) -> void:
	var roster: Array[String] = []
	_collect_roster(database.stages.get(id,{}),roster)
	if id == "stage_03" and not roster.has("正义巨像·加里奥"):roster.append(str(Catalog.ENEMIES.get("boss_galio",{}).get("name","加里奥")))
	if roster.has(str(Catalog.ENEMIES.get("troop_cannon",{}).get("name",""))):
		for member in ["troop_melee","troop_ranged"]:
			var troop_name := str(Catalog.ENEMIES.get(member,{}).get("name",member))
			if not roster.has(troop_name):roster.append(troop_name)
	roster_label.text = "本关敌人：" + " / ".join(roster)
	for stage_id: String in card_panels:
		var unlocked := _is_unlocked(stage_id); var focused := stage_id == id and unlocked
		card_frames[stage_id].texture = (ENDLESS_SKIN if stage_id == "stage_endless" else (BUFF_RED if focused else BUFF_GRAY))
		buttons[stage_id].modulate = Color.WHITE if focused else (Color(0.82,0.79,0.82,1) if unlocked else Color(0.36,0.34,0.36,1))

func activate_at(point: Vector2) -> bool:
	if not is_open(): return false
	if back_button.get_global_rect().has_point(point): _play(confirm_sound); close(); cancelled.emit(); return true
	for id: String in buttons:
		var item: Button = buttons[id]
		if not item.disabled and item.get_global_rect().has_point(point): select(id); return true
	return false
func open() -> void:
	_refresh(); root.show()
	for id: String in buttons:
		if not buttons[id].disabled: buttons[id].grab_focus(); break
func close() -> void: root.hide()
func is_open() -> bool: return root != null and root.visible
func select(id: String) -> void:
	if not _is_unlocked(id): return
	_play(confirm_sound); root.hide(); chosen.emit(id)
func _is_unlocked(id: String) -> bool:
	if id == "stage_endless": return true
	var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", []); var index := ids.find(id)
	return index == 0 or (index > 0 and progress.cleared_stages.has(str(ids[index - 1])))
func _refresh() -> void:
	for id: String in buttons:
		var unlocked := _is_unlocked(id); buttons[id].disabled = not unlocked; buttons[id].modulate = Color.WHITE if unlocked else Color(0.42,0.39,0.42,1)
		card_frames[id].texture = ENDLESS_SKIN if id == "stage_endless" else BUFF_GRAY
		if lock_labels.has(id): lock_labels[id].visible = not unlocked
		if not status_labels.has(id): continue
		var record: Dictionary = progress.stage_records.get(id, {}); var status: Label = status_labels[id]
		if not unlocked: status.text = "档案封锁 · 先通关前一区域"
		elif record.is_empty(): status.text = "尚未通关 · 最佳记录 --"
		else: status.text = "已通关 · 击退 %d · 基地 %d%%" % [int(record.get("best_kills",0)),int(record.get("best_base_hp",0))]



func _collect_roster(value: Variant, result: Array[String]) -> void:
	if value is Dictionary:
		for key in value:
			if str(key) in ["enemy","enemy_id","kind","boss_id","fodder_pool","enemies","waves","routes","groups","spawns","segments","wave_plan"] or value[key] is Array or value[key] is Dictionary:
				_collect_roster(value[key],result)
	elif value is Array:
		for item in value:_collect_roster(item,result)
	elif value is String and Catalog.ENEMIES.has(value):
		var name := str(Catalog.ENEMIES[value].name)
		if not result.has(name):result.append(name)
