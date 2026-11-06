extends CanvasLayer

signal setting_changed(key: String, value: Variant)
signal closed
signal workshop_requested
signal quit_requested

const WHITE := Color("#fff8ec")
const MUTED := Color("#c3beb7")
const ACCENT := Color("#dc244c")
const POSTER = preload("res://scripts/poster_surface.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const MOTION = preload("res://scripts/poster_motion.gd")

var hud
var root: Control
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var reduced_button: Button
var close_button: Button
var workshop_button: Button
var fullscreen_button: Button
var quit_button: Button
var portrait: TextureRect
var title_label: Label
var heading_label: Label
var syncing := false
var entrance_items: Array[Dictionary] = []
var closing_tween: Tween

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 95
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.020, 0.020, 0.027, 0.97)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var frame := POSTER.new()
	frame.position = UI_LAYOUT.settings_frame_rect.position
	frame.size = UI_LAYOUT.settings_frame_rect.size
	frame.side_title = true
	frame.title_rect = UI_LAYOUT.settings_header_rect
	root.add_child(frame)
	entrance_items.append({"node": frame, "offset": Vector2(0, 18), "scale": 0.985})
	var header: Rect2 = UI_LAYOUT.settings_header_rect
	title_label = owner_hud.label(frame, header.position, Vector2(header.size.x, 128), "系统\n设置", 60, WHITE)
	title_label.add_theme_font_override("font", POSTER.TYPE)
	title_label.add_theme_color_override("font_outline_color", POSTER.INK)
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.rotation = deg_to_rad(-5)
	var english: Label = owner_hud.label(frame, header.position + Vector2(4, 153), Vector2(header.size.x, 74), "SETUP", 64, WHITE)
	english.add_theme_font_override("font", POSTER.DISPLAY)
	english.rotation = deg_to_rad(-5)
	var portrait_slot := Panel.new()
	portrait_slot.position = UI_LAYOUT.settings_portrait_rect.position
	portrait_slot.size = UI_LAYOUT.settings_portrait_rect.size
	portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_frame := StyleBoxFlat.new()
	portrait_frame.bg_color = POSTER.INK
	portrait_frame.border_color = WHITE
	portrait_frame.set_border_width_all(3)
	portrait_slot.add_theme_stylebox_override("panel", portrait_frame)
	frame.add_child(portrait_slot)
	portrait = TextureRect.new()
	portrait.name = "SettingsPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.texture = UI_SKIN.settings_portrait
	portrait.position = UI_LAYOUT.settings_portrait_rect.position + Vector2(5, 5)
	portrait.size = UI_LAYOUT.settings_portrait_rect.size - Vector2(10, 10)
	frame.add_child(portrait)
	entrance_items.append({"node": portrait_slot, "offset": Vector2(-32, 0), "delay": 0.04})
	entrance_items.append({"node": portrait, "offset": Vector2(-32, 0), "delay": 0.04})
	entrance_items.append({"node": title_label, "offset": Vector2(-44, 0)})
	entrance_items.append({"node": english, "offset": Vector2(-44, 0)})
	heading_label = owner_hud.label(frame, Vector2(UI_LAYOUT.settings_slider_origin.x, 35), Vector2(710, 42), "滑动变阻器", 28, WHITE)
	heading_label.add_theme_font_override("font", POSTER.TYPE)
	_add_slider(frame, "master", "总音量 / MASTER", 0)
	_add_slider(frame, "music", "背景音乐 / MUSIC", 1)
	_add_slider(frame, "sfx", "音效与界面反馈 / SFX", 2)
	fullscreen_button = owner_hud.button(frame, UI_LAYOUT.settings_fullscreen_rect, "全屏", false)
	POSTER.style_button(fullscreen_button, false, 21)
	fullscreen_button.pressed.connect(func():
		if syncing: return
		var enabled := not bool(fullscreen_button.get_meta("enabled", false))
		sync_fullscreen(enabled)
		setting_changed.emit("fullscreen", enabled))
	reduced_button = owner_hud.button(frame, UI_LAYOUT.settings_reduced_rect, "战斗反馈", false)
	POSTER.style_button(reduced_button, false, 21)
	reduced_button.pressed.connect(func():
		if syncing: return
		var enabled := not bool(reduced_button.get_meta("enabled", false))
		reduced_button.set_meta("enabled", enabled)
		reduced_button.text = "低特效：开" if enabled else "低特效：关"
		setting_changed.emit("reduced_effects", enabled))
	close_button = owner_hud.button(frame, UI_LAYOUT.settings_close_rect, "保存并返回  [Esc]", true)
	POSTER.style_button(close_button, true, 21)
	close_button.pressed.connect(close)
	workshop_button = owner_hud.button(frame, UI_LAYOUT.settings_workshop_rect, "示范工坊  /  自由摆放角色、怪物与卡牌", false)
	POSTER.style_button(workshop_button, false, 22)
	workshop_button.pressed.connect(func(): workshop_requested.emit())
	quit_button = owner_hud.button(frame, UI_LAYOUT.settings_quit_rect, "退出游戏 / EXIT", false)
	POSTER.style_button(quit_button, false, 21)
	quit_button.pressed.connect(func(): quit_requested.emit())
	for index in [fullscreen_button, reduced_button, workshop_button, quit_button, close_button].size():
		var item: Button = [fullscreen_button, reduced_button, workshop_button, quit_button, close_button][index]
		entrance_items.append({"node": item, "offset": Vector2(0, 22), "delay": 0.12 + index * 0.02})
	root.hide()

func _add_slider(parent: Node, key: String, title: String, index: int) -> void:
	var origin: Vector2 = UI_LAYOUT.settings_slider_origin + index * UI_LAYOUT.settings_slider_gap
	var row := Panel.new()
	row.position = origin - Vector2(16, 11)
	row.size = Vector2(UI_LAYOUT.settings_slider_track_rect.size.x + 32, 98)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel", POSTER.paper_style())
	parent.add_child(row)
	entrance_items.append({"node": row, "offset": Vector2(55, 0), "delay": 0.04 + index * 0.055})
	var local_origin := Vector2(16, 11)
	var name: Label = hud.label(row, local_origin, Vector2(590, 34), title, 22, POSTER.INK)
	name.add_theme_font_override("font", POSTER.TYPE)
	var slider := HSlider.new()
	slider.position = local_origin + UI_LAYOUT.settings_slider_track_rect.position
	slider.size = UI_LAYOUT.settings_slider_track_rect.size
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = POSTER.INK
	track.set_content_margin_all(0)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	slider.add_theme_stylebox_override("slider", track)
	var filled := track.duplicate()
	filled.bg_color = ACCENT
	slider.add_theme_stylebox_override("grabber_area", filled)
	slider.add_theme_stylebox_override("grabber_area_highlight", filled)
	for state in ["grabber", "grabber_highlight", "grabber_disabled"]:
		var grip := GradientTexture2D.new()
		grip.width = 18
		grip.height = 28
		grip.gradient = Gradient.new()
		grip.gradient.colors = PackedColorArray([POSTER.YELLOW, POSTER.YELLOW])
		slider.add_theme_icon_override(state, grip)
	slider.value_changed.connect(func(value: float):
		if syncing: return
		value_labels[key].text = "%d%%" % roundi(value)
		setting_changed.emit(key, value / 100.0))
	row.add_child(slider)
	sliders[key] = slider
	var value_label: Label = hud.label(row, local_origin + UI_LAYOUT.settings_slider_value_rect.position, UI_LAYOUT.settings_slider_value_rect.size, "", 30, ACCENT)
	value_label.add_theme_font_override("font", POSTER.TYPE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_labels[key] = value_label

func open(settings: Dictionary) -> void:
	if closing_tween != null and closing_tween.is_valid(): closing_tween.kill()
	closing_tween = null
	syncing = true
	for key: String in sliders:
		var value := clampf(float(settings.get(key, 1.0)), 0.0, 1.0) * 100.0
		sliders[key].value = value
		value_labels[key].text = "%d%%" % roundi(value)
	var reduced := bool(settings.get("reduced_effects", false))
	reduced_button.set_meta("enabled", reduced)
	reduced_button.text = "低特效：开" if reduced else "低特效：关"
	var fullscreen := bool(settings.get("fullscreen", false))
	sync_fullscreen(fullscreen)
	syncing = false
	root.modulate = Color.WHITE
	root.show()
	MOTION.enter(self, entrance_items, reduced)
	close_button.grab_focus()

func sync_fullscreen(enabled: bool) -> void:
	if fullscreen_button == null: return
	if OS.get_name() == "Android":
		fullscreen_button.disabled = true
		fullscreen_button.text = "手机横屏 · 全屏显示"
		fullscreen_button.tooltip_text = "从屏幕边缘滑动可呼出系统导航"
		return
	fullscreen_button.set_meta("enabled", enabled)
	fullscreen_button.text = "全屏：开 [F11]" if enabled else "全屏：关 [F11]"
	fullscreen_button.tooltip_text = "F11 随时切换全屏与窗口模式"

func close() -> void:
	if not is_open():
		return
	if closing_tween != null and closing_tween.is_valid(): return
	MOTION.reset(self)
	closing_tween = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	closing_tween.tween_property(root, "modulate", Color(1, 1, 1, 0), 0.12)
	closing_tween.tween_callback(func():
		root.hide()
		root.modulate = Color.WHITE
		closing_tween = null
		closed.emit())

func _reset_defaults() -> void:
	var defaults := {"master": 0.82, "music": 0.46, "sfx": 0.90, "fullscreen": false, "reduced_effects": false}
	for key: String in defaults:
		setting_changed.emit(key, defaults[key])
	open(defaults)

func handle_input(event: InputEvent) -> bool:
	if not is_open():
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_F10]:
		close()
		return true
	return false

func is_open() -> bool:
	return root != null and root.visible
