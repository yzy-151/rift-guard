extends CanvasLayer

signal chosen(mode_id: String)
signal settings_requested
signal continue_requested
signal home_requested
signal archive_requested
signal quit_requested

const WHITE := Color("#fff9f1")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const Art = preload("res://scripts/main_menu_art.gd")
const Tag = preload("res://scripts/main_menu_tag.gd")
const CHINESE = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const MOTION = preload("res://scripts/poster_motion.gd")

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
var art: Control
var portrait: TextureRect
var brand: Label
var tags: Dictionary = {}
var focus_order: Array[String] = ["rift_watch", "continue", "endless_survival", "archive", "home", "settings", "quit"]

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 60
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	art = Art.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(art)
	portrait = TextureRect.new()
	portrait.name = "MenuPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = UI_SKIN.mode_portrait
	portrait.position = UI_LAYOUT.mode_portrait_rect.position
	portrait.size = UI_LAYOUT.mode_portrait_rect.size
	root.add_child(portrait)
	brand = hud.label(root, UI_LAYOUT.mode_header_rect.position, UI_LAYOUT.mode_header_rect.size, "裂隙守望", 40, WHITE)
	brand.add_theme_font_override("font", CHINESE)
	brand.add_theme_color_override("font_outline_color", Color.BLACK)
	brand.add_theme_constant_override("outline_size", 8)
	brand.rotation = -0.07
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_tag("rift_watch", UI_LAYOUT.mode_campaign_rect, "开始游戏", "NEW GAME", -0.10)
	_build_tag("continue", UI_LAYOUT.mode_continue_rect, "继续游戏", "CONTINUE", -0.08)
	_build_tag("endless_survival", UI_LAYOUT.mode_endless_rect, "无尽模式", "ENDLESS", -0.07)
	_build_tag("archive", UI_LAYOUT.mode_archive_rect, "角色图鉴", "GALLERY", 0.11)
	_build_tag("home", UI_LAYOUT.mode_home_rect, "回到家园", "HOME", 0.09)
	_build_tag("settings", UI_LAYOUT.mode_settings_rect, "系统设置", "SETTINGS", 0.08)
	_build_tag("quit", UI_LAYOUT.mode_quit_rect, "退出", "EXIT", 0.05)
	settings_button = buttons.settings
	continue_button = buttons["continue"]
	checkpoint_title = hud.label(root, UI_LAYOUT.mode_checkpoint_rect.position, Vector2(510, UI_LAYOUT.mode_checkpoint_rect.size.y), "", 13, WHITE)
	checkpoint_detail = hud.label(root, UI_LAYOUT.mode_checkpoint_rect.position + Vector2(620, 0), Vector2(532, UI_LAYOUT.mode_checkpoint_rect.size.y), "轻触选择 / 横屏游玩 / 系统返回键暂停" if OS.get_name() == "Android" else "方向键选择 / ENTER 确认 / F10 设置", 12, Color("#b8b3bd"))
	checkpoint_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for label in [checkpoint_title, checkpoint_detail]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_sound = _audio("res://assets/helltaker/audio/button_chapter_highlight_01.wav", -1.0)
	confirm_sound = _audio("res://assets/helltaker/audio/button_menu_confirm_01.wav", 0.0)
	_update_focus_neighbors()
	root.hide()

func _build_tag(id: String, rect: Rect2, caption: String, english: String, tilt: float) -> void:
	var item: Button = hud.button(root, rect, "", false)
	item.name = "Menu_" + id
	item.set_meta("dialogue_sound", true)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		item.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	item.tooltip_text = caption
	var tag := Tag.new()
	tag.caption = caption
	tag.english = english
	tag.tilt = tilt
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item.add_child(tag)
	buttons[id] = item
	tags[id] = tag
	item.mouse_entered.connect(func():
		if item.disabled: return
		_play(select_sound)
		item.grab_focus())
	item.focus_entered.connect(_focus_mode.bind(id))
	item.pressed.connect(_activate.bind(id))

func _activate(id: String) -> void:
	if not is_open() or not buttons.has(id) or buttons[id].disabled: return
	_play(confirm_sound)
	match id:
		"rift_watch", "endless_survival": close(); chosen.emit(id)
		"continue": continue_requested.emit()
		"archive": archive_requested.emit()
		"home": home_requested.emit()
		"settings": settings_requested.emit()
		"quit": quit_requested.emit()

func _focus_mode(id: String) -> void:
	for key: String in tags:
		tags[key].focused = key == id
		tags[key].queue_redraw()

func _update_focus_neighbors() -> void:
	var usable: Array[String] = []
	for id: String in focus_order:
		if not buttons[id].disabled: usable.append(id)
	for index in usable.size():
		var item: Button = buttons[usable[index]]
		var previous: Button = buttons[usable[posmod(index - 1, usable.size())]]
		var next: Button = buttons[usable[(index + 1) % usable.size()]]
		item.focus_previous = item.get_path_to(previous)
		item.focus_next = item.get_path_to(next)
		item.focus_neighbor_top = item.get_path_to(previous)
		item.focus_neighbor_bottom = item.get_path_to(next)
		item.focus_neighbor_left = item.get_path_to(previous)
		item.focus_neighbor_right = item.get_path_to(next)

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
	for id: String in focus_order:
		var item: Button = buttons[id]
		if not item.disabled and item.get_global_rect().has_point(point):
			_activate(id)
			return true
	return false

func update_checkpoint(result: Dictionary, database) -> void:
	var can_resume: bool = bool(result.get("ok", false)) and result.get("snapshot", {}) is Dictionary and not result.get("snapshot", {}).is_empty()
	continue_button.disabled = not can_resume
	tags["continue"].available = can_resume
	tags["continue"].queue_redraw()
	if can_resume:
		var snapshot: Dictionary = result.snapshot
		var stage_id := str(snapshot.get("stage_id", ""))
		var stage: Dictionary = database.stages.get(stage_id, {})
		checkpoint_title.text = "继续：%s  /  自动存档已就绪" % str(stage.get("name", "未完成的远征"))
		continue_button.tooltip_text = checkpoint_title.text
	else:
		checkpoint_title.text = "开始新的冒险后，将自动记录进度。"
		continue_button.tooltip_text = "暂无存档，先从「开始游戏」出发。"
	_update_focus_neighbors()

func open() -> void:
	root.show()
	var items: Array[Dictionary] = [
		{"node": art, "offset": Vector2.ZERO},
		{"node": portrait, "offset": Vector2(0, 54), "delay": 0.04, "scale": 0.96},
		{"node": brand, "offset": Vector2(-48, 0)},
		{"node": checkpoint_title, "offset": Vector2(0, 12), "delay": 0.15},
		{"node": checkpoint_detail, "offset": Vector2(0, 12), "delay": 0.15}
	]
	for index in focus_order.size():
		var id: String = focus_order[index]
		items.append({"node": buttons[id], "offset": Vector2(-92 if index < 3 else 92, 0), "delay": (index if index < 3 else index - 3) * 0.04, "scale": 0.98})
	MOTION.enter(self, items, hud.reduced)
	buttons["rift_watch"].grab_focus()

func close() -> void:
	MOTION.reset(self)
	root.hide()
func is_open() -> bool: return root != null and root.visible
