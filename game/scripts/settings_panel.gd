extends CanvasLayer

signal setting_changed(key: String, value: Variant)
signal closed
signal workshop_requested

const WHITE := Color("#f6eeea")
const MUTED := Color("#b49ba2")
const ACCENT := Color("#ed5d6f")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const SETTINGS_FRAME = preload("res://assets/ui/rift_v2/components/mode_card_red.png")

var hud
var root: Control
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var reduced_button: Button
var close_button: Button
var workshop_button: Button
var syncing := false

func build(owner_hud) -> void:
	hud = owner_hud
	layer = 95
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = owner_hud.get_child(0).theme
	add_child(root)
	var background := TextureRect.new()
	background.texture = UI_SKIN.settings_background
	background.position = UI_LAYOUT.settings_background_rect.position
	background.size = UI_LAYOUT.settings_background_rect.size
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.modulate = Color(0.34, 0.22, 0.27, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.025, 0.012, 0.025, 0.90)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(veil)
	var frame: Panel = owner_hud.panel(root, UI_LAYOUT.settings_frame_rect, Color(0.04, 0.018, 0.032, 0.96), Color(0, 0, 0, 0))
	var frame_skin := TextureRect.new()
	frame_skin.texture = SETTINGS_FRAME
	frame_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_skin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame_skin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_skin.modulate = Color(0.78, 0.76, 0.78, 0.92)
	frame_skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(frame_skin)
	frame.move_child(frame_skin, 0)
	var content := Control.new()
	content.position = Vector2(70, 22)
	content.size = Vector2(760, 487)
	frame.add_child(content)
	owner_hud.label(content, Vector2(48, 32), Vector2(650, 20), "S E T T I N G S   /   系 统 设 置", 12, ACCENT)
	owner_hud.label(content, Vector2(48, 65), Vector2(650, 44), "调整游戏体验", 31, WHITE)
	owner_hud.label(content, Vector2(50, 111), Vector2(650, 26), "F10 随时打开 · Esc 返回", 13, MUTED)
	_add_slider(content, "master", "总音量", 0)
	_add_slider(content, "music", "背景音乐", 1)
	_add_slider(content, "sfx", "音效与界面反馈", 2)
	reduced_button = owner_hud.button(content, UI_LAYOUT.settings_reduced_rect, "战斗反馈", false)
	reduced_button.pressed.connect(func():
		if syncing: return
		var enabled := not bool(reduced_button.get_meta("enabled", false))
		reduced_button.set_meta("enabled", enabled)
		reduced_button.text = "低特效：开" if enabled else "低特效：关"
		setting_changed.emit("reduced_effects", enabled))
	close_button = owner_hud.button(content, UI_LAYOUT.settings_close_rect, "保存并返回   [Esc]", true)
	close_button.pressed.connect(close)
	workshop_button = owner_hud.button(content, Rect2(48, 393, 664, 40), "示范工坊   /   自由摆放角色、怪物与卡牌", false)
	workshop_button.pressed.connect(func(): workshop_requested.emit())
	root.hide()

func _add_slider(parent: Node, key: String, title: String, index: int) -> void:
	var y := UI_LAYOUT.settings_slider_origin.y + index * UI_LAYOUT.settings_slider_gap.y
	hud.label(parent, Vector2(48, y), Vector2(200, 28), title, 16, WHITE)
	var slider := HSlider.new()
	slider.position = Vector2(UI_LAYOUT.settings_slider_track_rect.position.x, y + UI_LAYOUT.settings_slider_track_rect.position.y)
	slider.size = UI_LAYOUT.settings_slider_track_rect.size
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value_changed.connect(func(value: float):
		if syncing: return
		value_labels[key].text = "%d%%" % roundi(value)
		setting_changed.emit(key, value / 100.0))
	parent.add_child(slider)
	sliders[key] = slider
	var value_label: Label = hud.label(parent, Vector2(UI_LAYOUT.settings_slider_value_rect.position.x, y + UI_LAYOUT.settings_slider_value_rect.position.y), UI_LAYOUT.settings_slider_value_rect.size, "", 15, ACCENT)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_labels[key] = value_label

func open(settings: Dictionary) -> void:
	syncing = true
	for key: String in sliders:
		var value := clampf(float(settings.get(key, 1.0)), 0.0, 1.0) * 100.0
		sliders[key].value = value
		value_labels[key].text = "%d%%" % roundi(value)
	var reduced := bool(settings.get("reduced_effects", false))
	reduced_button.set_meta("enabled", reduced)
	reduced_button.text = "低特效：开" if reduced else "低特效：关"
	syncing = false
	root.modulate = Color(1, 1, 1, 0)
	root.show()
	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate", Color.WHITE, 0.16)
	close_button.grab_focus()

func close() -> void:
	if not is_open():
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(root, "modulate", Color(1, 1, 1, 0), 0.12)
	tween.tween_callback(func():
		root.hide()
		root.modulate = Color.WHITE
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
