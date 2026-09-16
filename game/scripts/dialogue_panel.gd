extends CanvasLayer
signal finished
signal choice_committed(choice: Dictionary)
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
var choice_frames: Array[NinePatchRect] = []
var letters: float = 0.0
var auto_mode: bool = false
var auto_timer: float = 0.0
var last_portrait: String = "muelsyse"
var cue_sound: AudioStreamPlayer
var background_texture: TextureRect
var transition_bar: ColorRect
var transition_texture: TextureRect
var transition_time: float = 0.0
var line_ended: bool = false
var end_sound: AudioStreamPlayer
var dialogue_highlight: AudioStreamPlayer
var dialogue_confirm: AudioStreamPlayer

func build(ui, story) -> void:
	hud = ui
	director = story
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = hud.get_child(0).theme
	add_child(root)
	var backdrop := Backdrop.new()
	root.add_child(backdrop)
	background_texture = TextureRect.new()
	background_texture.texture = UI_SKIN.dialogue_background
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
	shade.color = Color(0.025, 0.008, 0.018, 0.52)
	root.add_child(shade)
	var top_stage_scrim := ColorRect.new()
	top_stage_scrim.position = UI_LAYOUT.dialogue_top_scrim_rect.position
	top_stage_scrim.size = UI_LAYOUT.dialogue_top_scrim_rect.size
	top_stage_scrim.color = Color(0.006, 0.004, 0.018, 0.94)
	top_stage_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_stage_scrim)
	partner = art(UI_LAYOUT.dialogue_partner_rect)
	partner.modulate = Color(0.36, 0.28, 0.34, 0.8)
	portrait = art(UI_LAYOUT.dialogue_portrait_rect)
	var lower_stage_scrim := ColorRect.new()
	lower_stage_scrim.position = UI_LAYOUT.dialogue_lower_scrim_rect.position
	lower_stage_scrim.size = UI_LAYOUT.dialogue_lower_scrim_rect.size
	lower_stage_scrim.color = Color(0.012, 0.006, 0.022, 0.94)
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
	var speaker_rule := ColorRect.new()
	speaker_rule.position = Vector2(562, 499)
	speaker_rule.size = Vector2(156, 2)
	speaker_rule.color = Color("#d66769")
	speaker_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(speaker_rule)
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
		var choice_frame := NinePatchRect.new()
		choice_frame.texture = UI_SKIN.choice_frame_gray
		choice_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		choice_frame.patch_margin_left = 112
		choice_frame.patch_margin_right = 112
		choice_frame.patch_margin_top = 26
		choice_frame.patch_margin_bottom = 26
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
	advance_button = action(UI_LAYOUT.dialogue_advance_rect, "继续  [Enter]", advance)
	auto_button = action(UI_LAYOUT.dialogue_auto_rect, "自动：关", func():
		auto_mode = not auto_mode
		auto_timer = 0.0
		auto_button.text = "自动：开" if auto_mode else "自动：关")
	history_button = action(UI_LAYOUT.dialogue_history_rect, "历史  [H]", toggle_history)
	skip_button = action(UI_LAYOUT.dialogue_skip_rect, "跳过本段 [Esc]", skip)
	hud.bind(advance_button, "dialog_continue")
	hud.bind(auto_button, "dialog_auto")
	hud.bind(history_button, "dialog_history")
	hud.bind(skip_button, "dialog_skip")
	advance_button.position = UI_LAYOUT.dialogue_advance_rect.position
	advance_button.size = UI_LAYOUT.dialogue_advance_rect.size
	auto_button.position = UI_LAYOUT.dialogue_auto_rect.position
	auto_button.size = UI_LAYOUT.dialogue_auto_rect.size
	history_button.position = UI_LAYOUT.dialogue_history_rect.position
	history_button.size = UI_LAYOUT.dialogue_history_rect.size
	skip_button.position = UI_LAYOUT.dialogue_skip_rect.position
	skip_button.size = UI_LAYOUT.dialogue_skip_rect.size
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
	progress.position = Vector2(440, 548)
	progress.size = Vector2(400, 18)
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
	progress.text = ("" if director.has_choices() else "战场已暂停   ·   %02d / %02d" % [director.index + 1, director.lines.size()])
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
	advance_button.disabled = has_choices
	auto_button.disabled = has_choices
	advance_button.visible = not has_choices
	auto_button.visible = not has_choices
	history_button.visible = not has_choices
	skip_button.visible = not has_choices
func _reveal_choices() -> void:
	if not director.has_choices() or history_panel.visible:
		return
	progress.position = Vector2(440, 548)
	progress.size = Vector2(400, 18)
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
		item.scale = Vector2(0.94, 0.94)
		item.modulate = Color(1, 1, 1, 0)
		item.show()
		item.disabled = false
		item.focus_mode = Control.FOCUS_ALL
		var reveal := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		reveal.tween_property(item, "position", home, 0.28).set_delay(i * 0.085)
		reveal.tween_property(item, "scale", Vector2.ONE, 0.24).set_delay(i * 0.085)
		reveal.tween_property(item, "modulate", Color.WHITE, 0.14).set_delay(i * 0.085)
	if not options.is_empty():
		choice_buttons[0].grab_focus()
		_set_choice_focus(0)

func _set_choice_focus(index: int) -> void:
	for i in choice_frames.size():
		var selected := i == index
		choice_frames[i].texture = UI_SKIN.choice_frame_red if selected else UI_SKIN.choice_frame_gray
		choice_frames[i].modulate = Color.WHITE if selected else Color(0.72, 0.62, 0.66, 0.86)
		choice_buttons[i].add_theme_color_override("font_color", Color("#fff4eb") if selected else Color("#a99199"))
		choice_buttons[i].add_theme_color_override("font_focus_color", Color("#fff4eb") if selected else Color("#a99199"))
		choice_buttons[i].add_theme_color_override("font_hover_color", Color("#fff4eb") if selected else Color("#a99199"))
		choice_buttons[i].add_theme_color_override("font_shadow_color", Color(0.02, 0.0, 0.01, 0.95))
		choice_buttons[i].add_theme_constant_override("shadow_offset_y", 2)

func choose_option(choice_index: int) -> void:
	if not line_ended or history_panel.visible:
		return
	var options: Array = director.current().get("choices", [])
	if choice_index < 0 or choice_index >= options.size():
		return
	var chosen: Dictionary = options[choice_index].duplicate(true)
	if director.choose(choice_index):
		choice_committed.emit(chosen)
		show_line()

func activate_choice_at(point: Vector2) -> bool:
	if not root.visible or history_panel.visible:
		return false
	for item in choice_buttons:
		if item.visible and not item.disabled and item.get_global_rect().has_point(point):
			choose_option(choice_buttons.find(item))
			return true
	return false

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
	item.texture = config.texture(alias) if alias != "" else null
	item.position = at
	item.size = dimensions * factor
	item.flip_h = flipped
