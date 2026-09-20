extends CanvasLayer
signal finished
signal choice_committed(choice: Dictionary)
signal animation_confirmed
signal fatal_choice_confirmed
const Backdrop = preload("res://scripts/dialogue_backdrop.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const PORTRAITS = {
	"saria": preload("res://assets/portraits/saria.png"),
	"saria-soft": preload("res://assets/portraits/saria-soft.png"),
	"jessica": preload("res://assets/portraits/jessica.png"),
	"muelsyse": preload("res://assets/portraits/muelsyse.png")
}
var config
var director
var hud
var root: Control
var portrait: TextureRect
var dialogue_box: NinePatchRect
var partner: TextureRect
var name_label: Label
var body: RichTextLabel
var progress: Label
var history_panel: Panel
var history_text: RichTextLabel
var advance_button: Button
var auto_button: Button
var history_button: Button
var skip_button: Button
var controls: Array[Button] = []
var choice_buttons: Array[Button] = []
var choice_frames: Array[TextureRect] = []
## 选中态放大 + 亮色，未选中态缩小 + 暗色（参考 Helltaker 选项框）
const CHOICE_SELECTED_SCALE := 1.06
const CHOICE_IDLE_SCALE := 0.94
const CHOICE_SELECTED_FONT_SIZE := 20
const CHOICE_IDLE_FONT_SIZE := 17
const DEATH_FRAME_SECONDS := 0.17
const SUCCESS_FRAME_SECONDS := 0.11
const DEEP_BLUE := Color("#02021b")
const DEATH_FRAMES: Array[Texture2D] = [
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0001.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0002.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0003.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0004.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0005.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0006.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0007.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0008.png"),
	preload("res://assets/helltaker/dialogue_death/dialogueDeathExport0009.png"),
]
var letters: float = 0.0
var auto_mode: bool = false
var auto_timer: float = 0.0
var last_portrait: String = "muelsyse"
var cue_sound: AudioStreamPlayer
var background_texture: TextureRect
var transition_bar: ColorRect
var transition_texture: TextureRect
var success_texture: TextureRect
var transition_time: float = 0.0
var line_ended: bool = false
var end_sound: AudioStreamPlayer
var dialogue_highlight: AudioStreamPlayer
var dialogue_confirm: AudioStreamPlayer
var death_sound: AudioStreamPlayer
var success_sound: AudioStreamPlayer
var death_overlay: ColorRect
var death_texture: TextureRect
var death_reason_label: Label
var death_playing := false
var animation_waiting := false
var animation_click_gate: Button
var booper: TextureRect
var booper_elapsed := 0.0
func build(ui, story) -> void:
	hud = ui
	director = story
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = hud.get_child(0).theme
	add_child(root)
	var dark_to_blue_shader := Shader.new()
	dark_to_blue_shader.code = "shader_type canvas_item;\nvoid fragment() { vec4 pixel = texture(TEXTURE, UV) * COLOR; if (pixel.a > 0.01 && max(max(pixel.r, pixel.g), pixel.b) < 0.10) { pixel.rgb = max(pixel.rgb, vec3(0.008, 0.008, 0.106)); } COLOR = pixel; }"
	var dark_to_blue := ShaderMaterial.new()
	dark_to_blue.shader = dark_to_blue_shader
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	background_texture = TextureRect.new()
	background_texture.texture = UI_SKIN.dialogue_background
	background_texture.material = dark_to_blue
	background_texture.position = UI_LAYOUT.dialogue_background_rect.position
	background_texture.size = UI_LAYOUT.dialogue_background_rect.size
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_texture.show()
	root.add_child(background_texture)
	hud.bind(background_texture, "dialog_background")
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.018, 0.065, 0.52)
	root.add_child(shade)
	var top_stage_scrim := ColorRect.new()
	top_stage_scrim.position = UI_LAYOUT.dialogue_top_scrim_rect.position
	top_stage_scrim.size = UI_LAYOUT.dialogue_top_scrim_rect.size
	top_stage_scrim.color = DEEP_BLUE
	top_stage_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_stage_scrim)
	partner = art(UI_LAYOUT.dialogue_partner_rect)
	partner.modulate = Color(0.36, 0.28, 0.34, 0.8)
	portrait = art(UI_LAYOUT.dialogue_portrait_rect)
	var lower_stage_scrim := ColorRect.new()
	lower_stage_scrim.position = UI_LAYOUT.dialogue_lower_scrim_rect.position
	lower_stage_scrim.size = UI_LAYOUT.dialogue_lower_scrim_rect.size
	lower_stage_scrim.color = DEEP_BLUE
	lower_stage_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(lower_stage_scrim)
	var stage_rule := ColorRect.new()
	stage_rule.position = UI_LAYOUT.dialogue_stage_rule_rect.position
	stage_rule.size = UI_LAYOUT.dialogue_stage_rule_rect.size
	stage_rule.color = Color("#c75a66")
	stage_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stage_rule)
	dialogue_box = NinePatchRect.new()
	dialogue_box.texture = UI_SKIN.dialogue_box
	dialogue_box.material = dark_to_blue
	dialogue_box.position = UI_LAYOUT.dialogue_box_rect.position
	dialogue_box.size = UI_LAYOUT.dialogue_box_rect.size
	dialogue_box.patch_margin_left = 115
	dialogue_box.patch_margin_right = 115
	dialogue_box.patch_margin_top = 36
	dialogue_box.patch_margin_bottom = 36
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_box)
	hud.bind(dialogue_box, "dialog_frame")
	dialogue_box.position = UI_LAYOUT.dialogue_box_rect.position
	dialogue_box.size = UI_LAYOUT.dialogue_box_rect.size
	name_label = hud.label(root, UI_LAYOUT.dialogue_name_rect.position, UI_LAYOUT.dialogue_name_rect.size, "", 24, Color("#f0b4ae"))
	body = RichTextLabel.new()
	body.position = UI_LAYOUT.dialogue_body_rect.position
	body.size = UI_LAYOUT.dialogue_body_rect.size
	body.add_theme_font_size_override("normal_font_size", 20)
	body.add_theme_color_override("default_color", Color("#f5ece4"))
	body.scroll_following = true
	root.add_child(body)
	hud.bind(name_label, "dialog_name")
	hud.bind(body, "dialog_body")
	name_label.position = UI_LAYOUT.dialogue_name_rect.position
	name_label.size = UI_LAYOUT.dialogue_name_rect.size
	body.position = UI_LAYOUT.dialogue_body_rect.position
	body.size = UI_LAYOUT.dialogue_body_rect.size
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress = hud.label(root, UI_LAYOUT.dialogue_progress_rect.position, UI_LAYOUT.dialogue_progress_rect.size, "", 11, Color("#b9a2a9"))
	booper = TextureRect.new()
	booper.position = Vector2(614, 592)
	booper.modulate = Color("#dc344f")
	booper.size = Vector2(52, 30)
	booper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	booper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	booper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(booper)
	for i in 2:
		var choice_button := action(UI_LAYOUT.dialogue_choice_rects[i], "", choose_option.bind(i))
		choice_button.add_theme_font_size_override("font_size", 18)
		choice_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		choice_button.add_theme_color_override("font_color", Color("#b8a3aa"))
		choice_button.add_theme_color_override("font_focus_color", Color("#fff4eb"))
		choice_button.add_theme_color_override("font_hover_color", Color("#fff4eb"))
		var empty_style := StyleBoxEmpty.new()
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			choice_button.add_theme_stylebox_override(state, empty_style)
		var choice_frame := TextureRect.new()
		choice_frame.texture = UI_SKIN.choice_frame_gray
		choice_frame.material = dark_to_blue
		choice_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		choice_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		choice_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		choice_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		choice_frame.show_behind_parent = true
		choice_button.add_child(choice_frame)
		choice_button.move_child(choice_frame, 0)
		choice_frames.append(choice_frame)
		choice_button.focus_entered.connect(_set_choice_focus.bind(i))
		choice_button.mouse_entered.connect(func(): choice_button.grab_focus())
		choice_button.set_meta("home_position", choice_button.position)
		choice_button.hide()
		choice_button.disabled = true
		choice_button.focus_mode = Control.FOCUS_NONE
		choice_buttons.append(choice_button)
	advance_button = action(UI_LAYOUT.dialogue_advance_rect, "", advance)
	advance_button.hide()
	auto_button = action(Rect2(1178, 666, 34, 30), "A", func():
		auto_mode = not auto_mode
		auto_timer = 0.0
		auto_button.text = "A+" if auto_mode else "A")
	history_button = action(Rect2(1138, 666, 34, 30), "≡", toggle_history)
	skip_button = action(Rect2(1098, 666, 34, 30), "»", skip)
	hud.bind(advance_button, "dialog_continue")
	hud.bind(auto_button, "dialog_auto")
	hud.bind(history_button, "dialog_history")
	hud.bind(skip_button, "dialog_skip")
	advance_button.text = ""
	advance_button.position = Vector2(-200, -200)
	advance_button.size = Vector2(1, 1)
	advance_button.hide()
	auto_button.text = "A"
	auto_button.position = Vector2(1190, 675)
	auto_button.size = Vector2(34, 30)
	history_button.text = "≡"
	history_button.position = Vector2(1148, 675)
	history_button.size = Vector2(34, 30)
	skip_button.text = "»"
	skip_button.position = Vector2(1106, 675)
	skip_button.size = Vector2(34, 30)
	for i in controls.size():
		controls[i].focus_next = controls[(i + 1) % controls.size()].get_path()
		controls[i].focus_previous = controls[(i + controls.size() - 1) % controls.size()].get_path()
	history_panel = hud.panel(root, UI_LAYOUT.dialogue_history_panel_rect, Color("#241b25"), Color("#bb626b"))
	hud.label(history_panel, Vector2(28, 20), Vector2(600, 35), "对话记录 · H / Esc 返回", 22, Color("#f0b4ae"))
	history_text = RichTextLabel.new()
	history_text.focus_mode = Control.FOCUS_ALL
	history_text.position = Vector2(28, 70)
	history_text.size = Vector2(844, 370)
	history_text.add_theme_font_size_override("normal_font_size", 18)
	history_panel.add_child(history_text)
	history_panel.hide()
	transition_bar = ColorRect.new()
	transition_bar.position = Vector2(-1280, 482)
	transition_bar.size = Vector2(1280, 8)
	transition_bar.color = Color("#e0525d")
	transition_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(transition_bar)
	transition_texture = TextureRect.new()
	transition_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	transition_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_texture.hide()
	root.add_child(transition_texture)
	success_texture = TextureRect.new()
	success_texture.position = Vector2(390, 566)
	success_texture.size = Vector2(500, 91)
	success_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	success_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	success_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	success_texture.hide()
	root.add_child(success_texture)
	death_overlay = ColorRect.new()
	death_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	death_overlay.color = DEEP_BLUE
	death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(death_overlay)
	death_texture = TextureRect.new()
	death_texture.position = Vector2(0, 90)
	death_texture.size = Vector2(1280, 392)
	death_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	death_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	death_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	death_overlay.add_child(death_texture)
	death_reason_label = hud.label(death_overlay, Vector2(170, 500), Vector2(940, 112), "", 22, Color("#f5e8df"))
	death_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_reason_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	death_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	death_reason_label.add_theme_color_override("font_shadow_color", Color("#8e1f37"))
	death_reason_label.add_theme_constant_override("shadow_offset_y", 3)
	death_overlay.hide()
	animation_click_gate = Button.new()
	animation_click_gate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	animation_click_gate.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		animation_click_gate.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	animation_click_gate.pressed.connect(acknowledge_animation)
	root.add_child(animation_click_gate)
	var click_hint: Label = hud.label(animation_click_gate, Vector2(510, 672), Vector2(260, 28), "点击屏幕继续", 13, Color("#e5dfe9"))
	click_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	click_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	animation_click_gate.hide()
	root.hide()
	cue_sound = AudioStreamPlayer.new()
	cue_sound.stream = preload("res://assets/helltaker/audio/dialogue_start_01.wav")
	cue_sound.bus = "SFX"
	cue_sound.volume_db = -15.0
	cue_sound.max_polyphony = 2
	add_child(cue_sound)
	end_sound = AudioStreamPlayer.new()
	end_sound.stream = preload("res://assets/helltaker/audio/dialogue_text_end_01.wav")
	end_sound.bus = "SFX"
	end_sound.volume_db = -13.0
	add_child(end_sound)
	dialogue_highlight = AudioStreamPlayer.new()
	dialogue_highlight.stream = preload("res://assets/helltaker/audio/button_dialogue_highlight_01.wav")
	dialogue_highlight.bus = "SFX"
	dialogue_highlight.volume_db = -11.0
	add_child(dialogue_highlight)
	dialogue_confirm = AudioStreamPlayer.new()
	dialogue_confirm.stream = preload("res://assets/helltaker/audio/button_dialogue_confirm_01.wav")
	dialogue_confirm.bus = "SFX"
	dialogue_confirm.volume_db = -10.0
	add_child(dialogue_confirm)
	death_sound = AudioStreamPlayer.new()
	death_sound.stream = preload("res://assets/helltaker/audio/player_death_01.wav")
	death_sound.bus = "SFX"
	add_child(death_sound)
	success_sound = AudioStreamPlayer.new()
	success_sound.stream = preload("res://assets/helltaker/audio/dialogue_success_01.wav")
	success_sound.bus = "SFX"
	add_child(success_sound)

func art(rect: Rect2) -> TextureRect:
	var item := TextureRect.new()
	item.position = rect.position
	item.size = rect.size
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(item)
	return item

func action(rect: Rect2, text: String, callback: Callable) -> Button:
	var item: Button = hud.button(root, rect, text, false)
	item.set_meta("dialogue_sound", true)
	item.pressed.connect(callback)
	item.mouse_entered.connect(func():
		if dialogue_highlight != null:
			dialogue_highlight.stop()
			dialogue_highlight.play())
	item.pressed.connect(func():
		if dialogue_confirm != null:
			dialogue_confirm.stop()
			dialogue_confirm.play())
	controls.append(item)
	return item

func display() -> void:
	for item in controls:
		item.disabled = false
		item.focus_mode = Control.FOCUS_ALL
	for item in choice_buttons:
		item.hide()
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
	history_panel.hide()
	root.modulate = Color(1, 1, 1, 0)
	root.show()
	transition_time = 0.52
	transition_texture.show()
	var opening := create_tween()
	opening.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	opening.tween_property(root, "modulate", Color.WHITE, 0.13)
	transition_bar.position.x = -1280.0
	var wipe := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	wipe.tween_property(transition_bar, "position:x", 1280.0, 0.34)
	show_line()
	advance_button.grab_focus()

func show_line() -> void:
	var line: Dictionary = director.current()
	if line.is_empty():
		return
	if config != null and config.loaded:
		set_picture(portrait, line.get("portrait", ""), Vector2(line.get("x", 115), line.get("y", 75)), Vector2(520, 665), line.get("scale", 1.0), line.get("flip", false))
		set_picture(partner, line.get("partner", ""), Vector2(line.get("partner_x", 685), line.get("partner_y", 80)), Vector2(490, 650), line.get("partner_scale", 1.0), line.get("partner_flip", false))
		var highlight: String = line.get("highlight", "main")
		portrait.modulate = Color(0.36, 0.28, 0.34, 0.8) if highlight == "partner" else Color.WHITE
		partner.modulate = Color(0.36, 0.28, 0.34, 0.8) if highlight == "main" else Color.WHITE
	else:
		portrait.show()
		partner.show()
		portrait.position = Vector2(115, 75)
		portrait.size = Vector2(520, 665)
		portrait.flip_h = false
		partner.position = Vector2(685, 80)
		partner.size = Vector2(490, 650)
		partner.flip_h = false
		portrait.modulate = Color.WHITE
		partner.modulate = Color(0.36, 0.28, 0.34, 0.8)
		partner.texture = PORTRAITS.get(last_portrait, PORTRAITS.muelsyse)
		if last_portrait == line.portrait:
			partner.texture = PORTRAITS.jessica if line.portrait != "jessica" else PORTRAITS.saria
		portrait.texture = PORTRAITS.get(line.portrait, PORTRAITS.saria)
	var highlight_mode: String = str(line.get("highlight", "main"))
	var active_art: TextureRect = partner if highlight_mode == "partner" else portrait
	var inactive_art: TextureRect = portrait if highlight_mode == "partner" else partner
	inactive_art.hide()
	active_art.show()
	active_art.position = UI_LAYOUT.dialogue_portrait_rect.position
	active_art.size = UI_LAYOUT.dialogue_portrait_rect.size
	active_art.modulate = Color.WHITE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_portrait = line.portrait
	name_label.text = "◆  %s  ◆" % str(line.speaker)
	dialogue_box.modulate = Color(1, 1, 1, 0)
	name_label.modulate = Color.WHITE
	progress.position = UI_LAYOUT.dialogue_progress_rect.position
	progress.size = UI_LAYOUT.dialogue_progress_rect.size
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.modulate = Color.WHITE
	body.show()
	body.bbcode_enabled = true
	body.text = "[center]%s[/center]" % str(line.text)
	body.visible_characters = -1
	body.modulate = Color(1, 1, 1, 0)
	letters = float(body.get_total_character_count())
	line_ended = true
	auto_timer = 0.0
	_configure_choices(line)
	progress.text = ""
	booper.visible = not director.has_choices()
	_animate_line_entrance(str(line.get("highlight", "main")))
	_reveal_choices_after_pop(director.index)
	if cue_sound != null:
		cue_sound.pitch_scale = 0.98 + float(director.index % 3) * 0.035
		cue_sound.play()

func _animate_line_entrance(highlight: String) -> void:
	var main_target: Vector2 = portrait.position
	var partner_target: Vector2 = partner.position
	var main_tint: Color = portrait.modulate
	var partner_tint: Color = partner.modulate
	portrait.pivot_offset = portrait.size * 0.5
	partner.pivot_offset = partner.size * 0.5
	portrait.position = main_target + Vector2(56, 52)
	partner.position = partner_target + Vector2(-42, 36)
	portrait.scale = Vector2(0.86, 0.86)
	partner.scale = Vector2(0.91, 0.91)
	portrait.rotation = deg_to_rad(2.8)
	partner.rotation = deg_to_rad(-1.8)
	portrait.modulate = Color(main_tint.r, main_tint.g, main_tint.b, 0.0)
	partner.modulate = Color(partner_tint.r, partner_tint.g, partner_tint.b, 0.0)
	dialogue_box.position.x = -940.0
	body.pivot_offset = body.size * 0.5
	body.scale = Vector2(1.055, 1.055)
	var entrance := create_tween().set_parallel(true)
	entrance.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entrance.tween_property(portrait, "position", main_target, 0.34)
	entrance.tween_property(partner, "position", partner_target, 0.30)
	entrance.tween_property(portrait, "scale", Vector2.ONE, 0.32)
	entrance.tween_property(partner, "scale", Vector2.ONE, 0.28)
	entrance.tween_property(portrait, "rotation", 0.0, 0.30)
	entrance.tween_property(partner, "rotation", 0.0, 0.28)
	entrance.tween_property(portrait, "modulate", main_tint, 0.16)
	entrance.tween_property(partner, "modulate", partner_tint, 0.16)
	entrance.set_trans(Tween.TRANS_EXPO)
	entrance.tween_property(dialogue_box, "position:x", 250.0, 0.22)
	entrance.tween_property(body, "modulate", Color.WHITE, 0.13).set_delay(0.10)
	entrance.tween_property(body, "scale", Vector2.ONE, 0.20).set_delay(0.08)
	if highlight == "main":
		portrait.position.x -= 16.0
	else:
		partner.position.x += 16.0

func _reveal_choices_after_pop(expected_index: int) -> void:
	await get_tree().create_timer(0.16).timeout
	if root != null and root.visible and director.active and director.index == expected_index:
		if end_sound != null:
			end_sound.play()
		_reveal_choices()

func _process(dt: float) -> void:
	if root == null or not root.visible or history_panel.visible:
		return
	booper_elapsed += dt
	if booper != null and booper.visible:
		var booper_frame := posmod(floori(booper_elapsed * 20.0), 28) + 1
		booper.texture = load("res://assets/helltaker/dialogue_booper/booper%04d.png" % booper_frame)
	if transition_time > 0.0:
		transition_time = maxf(0.0, transition_time - dt)
		var frame := clampi(28 - floori(transition_time / 0.52 * 28.0), 0, 28)
		transition_texture.texture = load("res://assets/helltaker/transitions/transition%04d.png" % (frame + 2))
		if transition_time <= 0.0:
			transition_texture.hide()
	if line_ended and auto_mode and not director.has_choices():
		auto_timer += dt
		if auto_timer > 2.0:
			advance()
func _configure_choices(line: Dictionary) -> void:
	var options: Array = line.get("choices", [])
	for i in choice_buttons.size():
		var item: Button = choice_buttons[i]
		item.hide()
		item.disabled = true
		item.focus_mode = Control.FOCUS_NONE
		if i < options.size():
			item.text = str(options[i].get("text", ""))
	var has_choices := not options.is_empty()
	advance_button.disabled = true
	advance_button.visible = false
	auto_button.disabled = has_choices
	auto_button.visible = not has_choices
	history_button.visible = not has_choices
	skip_button.visible = not has_choices and not director.key.begins_with("home_")
	booper.visible = not has_choices
func _reveal_choices() -> void:
	if not director.has_choices() or history_panel.visible:
		return
	progress.position = UI_LAYOUT.dialogue_progress_rect.position
	progress.size = UI_LAYOUT.dialogue_progress_rect.size
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.modulate = Color("#f0b4ae")
	var dim_dialogue := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	dim_dialogue.tween_property(dialogue_box, "modulate", Color(1, 1, 1, 0.0), 0.16)
	dim_dialogue.tween_property(name_label, "modulate", Color.WHITE, 0.16)
	dim_dialogue.tween_property(body, "modulate", Color.WHITE, 0.16)
	dim_dialogue.tween_property(progress, "modulate", Color(1, 1, 1, 0.95), 0.16)
	var options: Array = director.current().get("choices", [])
	for i in mini(choice_buttons.size(), options.size()):
		var item: Button = choice_buttons[i]
		var home: Vector2 = item.get_meta("home_position", item.position)
		item.pivot_offset = item.size * 0.5
		item.position = home + Vector2(-220, 0)
		item.scale = _choice_scale(false)
		item.modulate = Color(1, 1, 1, 0)
		item.show()
		item.disabled = false
		item.focus_mode = Control.FOCUS_ALL
		var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(item, "position", home, 0.28).set_delay(i * 0.085)
		reveal.tween_property(item, "modulate", Color.WHITE, 0.14).set_delay(i * 0.085)
	if not options.is_empty():
		choice_buttons[0].grab_focus()
		_set_choice_focus(0)

## 选中：亮色描边 + 放大 + 字号更大；未选中：暗色描边 + 缩小 + 字号更小。
func _choice_scale(selected: bool) -> Vector2:
	var value := CHOICE_SELECTED_SCALE if selected else CHOICE_IDLE_SCALE
	return Vector2(value, value)

func _set_choice_focus(index: int) -> void:
	for i in choice_frames.size():
		var selected := i == index
		choice_frames[i].texture = UI_SKIN.choice_frame_red if selected else UI_SKIN.choice_frame_gray
		choice_frames[i].modulate = Color.WHITE if selected else Color(0.88, 0.84, 0.86, 0.95)
		var button: Button = choice_buttons[i]
		button.add_theme_font_size_override("font_size", CHOICE_SELECTED_FONT_SIZE if selected else CHOICE_IDLE_FONT_SIZE)
		button.add_theme_color_override("font_color", Color("#fff6ef") if selected else Color("#9a8b93"))
		button.add_theme_color_override("font_focus_color", Color("#fff6ef") if selected else Color("#9a8b93"))
		button.add_theme_color_override("font_hover_color", Color("#fff6ef") if selected else Color("#b7a5ad"))
		button.add_theme_color_override("font_shadow_color", Color(0.02, 0.0, 0.01, 0.95))
		button.add_theme_constant_override("shadow_offset_y", 2)
		var target := _choice_scale(selected)
		if button.visible and not button.scale.is_equal_approx(target):
			create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).tween_property(button, "scale", target, 0.12)

func choose_option(choice_index: int) -> void:
	if not line_ended or history_panel.visible or death_playing:
		return
	var options: Array = director.current().get("choices", [])
	if choice_index < 0 or choice_index >= options.size():
		return
	var chosen: Dictionary = options[choice_index].duplicate(true)
	var death_reason := str(chosen.get("death_reason", ""))
	if not death_reason.is_empty():
		await _play_choice_death(death_reason)
		return
	if director.choose(choice_index):
		choice_committed.emit(chosen)
		show_line()

func _play_choice_death(reason: String) -> void:
	death_playing = true
	for item in choice_buttons:
		item.disabled = true
	death_reason_label.text = "死亡原因\n" + reason
	death_reason_label.modulate = Color(1, 1, 1, 0)
	death_reason_label.scale = Vector2(1.08, 1.08)
	death_reason_label.pivot_offset = death_reason_label.size * 0.5
	death_overlay.modulate = Color(1, 1, 1, 0)
	death_overlay.show()
	var fade_in := create_tween()
	fade_in.tween_property(death_overlay, "modulate:a", 1.0, 0.12)
	await fade_in.finished
	for frame in DEATH_FRAMES:
		death_texture.texture = frame
		await get_tree().create_timer(DEATH_FRAME_SECONDS).timeout
	var reason_pop := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	reason_pop.tween_property(death_reason_label, "modulate:a", 1.0, 0.12)
	reason_pop.tween_property(death_reason_label, "scale", Vector2.ONE, 0.20)
	await reason_pop.finished
	await _await_animation_click()
	var fade_out := create_tween()
	fade_out.tween_property(death_overlay, "modulate:a", 0.0, 0.20)
	await fade_out.finished
	death_overlay.hide()
	death_playing = false
	fatal_choice_confirmed.emit()

func activate_choice_at(point: Vector2) -> bool:
	if not root.visible or history_panel.visible or death_playing:
		return false
	for item in choice_buttons:
		if item.visible and not item.disabled and item.get_global_rect().has_point(point):
			choose_option(choice_buttons.find(item))
			return true
	if director.has_choices():
		return true
	if skip_button.visible and skip_button.get_global_rect().has_point(point):
		skip()
		return true
	if history_button.visible and history_button.get_global_rect().has_point(point):
		toggle_history()
		return true
	if auto_button.visible and auto_button.get_global_rect().has_point(point):
		auto_mode = not auto_mode
		auto_button.text = "A+" if auto_mode else "A"
		return true
	advance()
	return true

func advance() -> void:
	if not director.active or history_panel.visible:
		return
	if letters < body.get_total_character_count():
		letters = body.get_total_character_count()
		body.visible_characters = -1
		if not line_ended:
			line_ended = true
			end_sound.play()
		_reveal_choices()
		return
	if director.has_choices():
		_reveal_choices()
		return
	if director.advance():
		body.visible_characters = -1
		body.modulate = Color(1, 1, 1, 0)
		show_line()
	else:
		close()

func skip() -> void:
	if director.key.begins_with("home_"):
		return
	director.skip()
	close()

func close() -> void:
	history_panel.hide()
	var closing := create_tween()
	closing.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	closing.tween_property(root, "modulate", Color(1, 1, 1, 0), 0.12)
	closing.tween_callback(func():
		root.hide()
		root.modulate = Color.WHITE
		finished.emit())

func toggle_history() -> void:
	history_panel.visible = not history_panel.visible
	if history_panel.visible:
		history_text.text = ""
		for row in director.history:
			history_text.text += row.speaker + "：\n" + row.text + "\n\n"
		for item in controls:
			item.disabled = item != history_button
			item.focus_mode = Control.FOCUS_ALL if item == history_button else Control.FOCUS_NONE
		history_button.grab_focus()
	else:
		for item in controls:
			item.disabled = false
			item.focus_mode = Control.FOCUS_ALL
		_configure_choices(director.current())
		if director.has_choices() and line_ended:
			_reveal_choices()
		else:
			advance_button.grab_focus()

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1 and choice_buttons[0].visible:
			choose_option(0)
		elif event.keycode == KEY_2 and choice_buttons[1].visible:
			choose_option(1)
		elif event.keycode == KEY_H:
			toggle_history()
		elif event.keycode == KEY_ESCAPE:
			if history_panel.visible:
				toggle_history()
			else:
				skip()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and history_panel.visible:
			toggle_history()
		elif event.keycode in [KEY_ENTER, KEY_SPACE] and not history_panel.visible:
			var focus = get_viewport().gui_get_focus_owner()
			if focus == advance_button or focus == null:
				advance()
			elif focus is Button:
				focus.pressed.emit()
		elif event.keycode == KEY_TAB and not history_panel.visible:
			var current: int = controls.find(get_viewport().gui_get_focus_owner())
			var direction: int = -1 if event.shift_pressed else 1
			controls[posmod(current + direction, controls.size())].grab_focus()

func set_picture(item: TextureRect, alias: String, at: Vector2, dimensions: Vector2, factor: float, flipped: bool) -> void:
	item.visible = alias != ""
	item.texture = load(alias) as Texture2D if alias.begins_with("res://assets/") and ResourceLoader.exists(alias) else (config.texture(alias) if alias != "" else null)
	item.position = at
	item.size = dimensions * factor
	item.flip_h = flipped









func play_death_transition(reason: String = "") -> void:
	if death_playing:
		return
	var root_was_visible := root.visible
	death_playing = true
	death_reason_label.text = reason
	death_reason_label.visible = not reason.is_empty()
	death_reason_label.modulate = Color(1, 1, 1, 0)
	death_overlay.modulate = Color(1, 1, 1, 0)
	root.show()
	death_overlay.show()
	if death_sound != null:
		death_sound.stop()
		death_sound.play()
	var fade_in := create_tween()
	fade_in.tween_property(death_overlay, "modulate:a", 1.0, 0.10)
	await fade_in.finished
	for frame in DEATH_FRAMES:
		death_texture.texture = frame
		await get_tree().create_timer(DEATH_FRAME_SECONDS).timeout
	if not reason.is_empty():
		var reveal := create_tween()
		reveal.tween_property(death_reason_label, "modulate:a", 1.0, 0.12)
		await reveal.finished
	await _await_animation_click()
	var fade_out := create_tween()
	fade_out.tween_property(death_overlay, "modulate:a", 0.0, 0.18)
	await fade_out.finished
	death_overlay.hide()
	death_reason_label.visible = true
	death_playing = false
	if not root_was_visible:
		root.hide()

func play_stage_transition() -> void:
	var root_was_visible := root.visible
	transition_time = 0.0
	root.show()
	transition_texture.show()
	if cue_sound != null:
		cue_sound.stop()
		cue_sound.play()
	for frame_index in range(2, 31):
		transition_texture.texture = load("res://assets/helltaker/transitions/transition%04d.png" % frame_index)
		await get_tree().create_timer(0.018).timeout
	transition_texture.hide()
	if not root_was_visible:
		root.hide()

func play_success_animation() -> void:
	var root_was_visible := root.visible
	var visible_choices: Array[bool] = []
	for choice_button in choice_buttons:
		visible_choices.append(choice_button.visible)
		choice_button.hide()
	root.show()
	success_texture.show()
	if success_sound != null:
		success_sound.stop()
		success_sound.play()
	for frame_index in range(1, 10):
		success_texture.texture = load("res://assets/helltaker/dialogue_success/success%04d.png" % frame_index)
		await get_tree().create_timer(SUCCESS_FRAME_SECONDS).timeout
	# 0009 是动作模糊帧，播放完后停在清晰的 0008 等待确认。
	success_texture.texture = load("res://assets/helltaker/dialogue_success/success0008.png")
	await _await_animation_click()
	success_texture.hide()
	for index in choice_buttons.size():
		choice_buttons[index].visible = visible_choices[index]
	if not root_was_visible:
		root.hide()

func acknowledge_animation() -> void:
	if animation_waiting:
		animation_confirmed.emit()

func _await_animation_click() -> void:
	animation_waiting = true
	animation_click_gate.show()
	await animation_confirmed
	animation_click_gate.hide()
	animation_waiting = false

func play_angry_departure(character_id: String) -> void:
	root.show()
	root.modulate = Color.WHITE
	portrait.hide()
	dialogue_box.hide()
	body.hide()
	name_label.hide()
	progress.hide()
	booper.hide()
	var sequences = preload("res://scripts/character_sequence_library.gd").new()
	var atlas: Texture2D = sequences.texture(character_id, "run")
	if atlas != null:
		var runner := TextureRect.new()
		var frames := AtlasTexture.new()
		frames.atlas = atlas
		runner.texture = frames
		runner.position = Vector2(940, 320)
		runner.size = Vector2(220, 220)
		runner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		runner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		runner.flip_h = true
		runner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(runner)
		runner.move_to_front()
		var departure := create_tween().set_trans(Tween.TRANS_LINEAR)
		departure.tween_property(runner, "position:x", -runner.size.x - 20.0, 1.05)
		for index in range(25):
			frames.region = sequences.source_rect(character_id, "run", index % sequences.frame_count(character_id, "run"))
			await get_tree().create_timer(0.042).timeout
		if departure.is_running():
			await departure.finished
		runner.free()
	else:
		portrait.show()
		var departure := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		departure.tween_property(portrait, "position:x", -portrait.size.x - 80.0, 0.75)
		await departure.finished
	portrait.hide()
	dialogue_box.show()
	body.show()
	name_label.show()
	progress.show()
	root.hide()
