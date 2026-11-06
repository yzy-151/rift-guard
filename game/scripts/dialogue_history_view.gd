extends Panel

signal return_requested

const DISPLAY = preload("res://assets/fonts/Leigai.ttf")
const BODY = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const RED := Color("#dc244c")
const INK := Color("#0e0d12")
const PAPER := Color("#f6f1e9")
const YELLOW := Color("#ffd05c")

var portrait: TextureRect
var return_button: Button
var scroll: ScrollContainer
var entries: VBoxContainer
var count_label: Label
var headline: Label
var speaker_label: Label
var return_anchor := Vector2.ZERO
var open_tween: Tween
var row_count := 0

func build(ui, layout) -> void:
	theme = ui.get_child(0).theme
	position = layout.dialogue_history_panel_rect.position
	size = layout.dialogue_history_panel_rect.size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	headline = _label(layout.dialogue_history_banner_rect, "刚才\n说啥？", 56, PAPER)
	headline.rotation = deg_to_rad(-5.0)
	headline.add_theme_color_override("font_outline_color", INK)
	headline.add_theme_constant_override("outline_size", 12)
	portrait = TextureRect.new()
	portrait.position = layout.dialogue_history_portrait_rect.position
	portrait.size = layout.dialogue_history_portrait_rect.size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	move_child(portrait, 0)
	speaker_label = _label(Rect2(28, size.y - 71, 330, 44), "台词有证，嘴硬无效。", 21, YELLOW)
	speaker_label.rotation = deg_to_rad(-3)
	_label(Rect2(layout.dialogue_history_scroll_rect.position.x, 25, 360, 42), "对话历史 / LOG", 28, PAPER)
	count_label = _label(Rect2(size.x - 192, 34, 156, 32), "", 18, YELLOW)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scroll = ScrollContainer.new()
	scroll.position = layout.dialogue_history_scroll_rect.position
	scroll.size = layout.dialogue_history_scroll_rect.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scroll)
	entries = VBoxContainer.new()
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.add_theme_constant_override("separation", 14)
	scroll.add_child(entries)
	return_button = Button.new()
	return_button.position = layout.dialogue_history_return_rect.position
	return_anchor = return_button.position
	return_button.size = layout.dialogue_history_return_rect.size
	return_button.text = "← 返回对话  [Esc]"
	return_button.add_theme_font_override("font", DISPLAY)
	return_button.add_theme_font_size_override("font_size", 23)
	return_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = YELLOW if state in ["hover", "focus"] else PAPER
		style.border_color = INK
		style.set_border_width_all(4)
		style.shadow_color = RED
		style.shadow_size = 0
		style.shadow_offset = Vector2(-6, 6)
		return_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		return_button.add_theme_color_override(state, INK)
	return_button.pressed.connect(func(): return_requested.emit())
	return_button.mouse_entered.connect(func():
		create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(return_button, "position", return_anchor + Vector2(-6, -3), 0.14))
	return_button.mouse_exited.connect(func():
		create_tween().tween_property(return_button, "position", return_anchor, 0.12))
	add_child(return_button)
	_label(Rect2(layout.dialogue_history_scroll_rect.position.x, size.y - 68, 420, 38), "H / Esc 返回 · 滚轮翻阅", 15, Color("#c4b6b4"))
	hide()

func _label(rect: Rect2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.add_theme_font_override("font", DISPLAY)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func show_history(rows: Array, texture: Texture2D) -> void:
	for old in entries.get_children():
		entries.remove_child(old)
		old.queue_free()
	row_count = rows.size()
	portrait.texture = texture
	count_label.text = "%02d 条 / 已记录" % row_count
	for index in rows.size():
		var row: Dictionary = rows[index]
		var card := PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#f5cf67") if bool(row.get("player_choice", false)) or str(row.get("speaker", "")) == "你的选择" else PAPER
		style.border_color = INK
		style.set_border_width_all(3)
		style.content_margin_left = 20
		style.content_margin_right = 20
		style.content_margin_top = 13
		style.content_margin_bottom = 15
		card.add_theme_stylebox_override("panel", style)
		entries.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 5)
		card.add_child(content)
		var name := Label.new()
		name.text = "%02d  /  %s" % [index + 1, str(row.get("speaker", ""))]
		name.add_theme_font_override("font", DISPLAY)
		name.add_theme_font_size_override("font_size", 18)
		name.add_theme_color_override("font_color", RED.darkened(0.22))
		content.add_child(name)
		var text := RichTextLabel.new()
		text.text = str(row.get("text", ""))
		text.fit_content = true
		text.scroll_active = false
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_override("normal_font", BODY)
		text.add_theme_font_size_override("normal_font_size", 19)
		text.add_theme_color_override("default_color", INK)
		text.mouse_filter = Control.MOUSE_FILTER_PASS
		content.add_child(text)
	if rows.is_empty():
		var empty := Label.new()
		empty.text = "还没开口，先别翻案。"
		entries.add_child(empty)
	if open_tween != null and open_tween.is_valid(): open_tween.kill()
	scale = Vector2(0.92, 0.92)
	rotation = deg_to_rad(-1.3)
	modulate.a = 0.0
	show()
	open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(self, "scale", Vector2.ONE, 0.24)
	open_tween.tween_property(self, "rotation", 0.0, 0.24)
	open_tween.tween_property(self, "modulate:a", 1.0, 0.14)
	return_button.grab_focus()
	await get_tree().process_frame
	scroll.scroll_vertical = maxi(0, int(scroll.get_v_scroll_bar().max_value))

func _draw() -> void:
	draw_rect(Rect2(-position, Vector2(1280, 720)), Color(0.015, 0.008, 0.025, 0.90))
	draw_colored_polygon(PackedVector2Array([Vector2(10, 18), Vector2(size.x - 14, 0), Vector2(size.x, size.y - 13), Vector2(0, size.y)]), RED)
	draw_colored_polygon(PackedVector2Array([Vector2(22, 22), Vector2(size.x - 24, 14), Vector2(size.x - 16, size.y - 25), Vector2(12, size.y - 14)]), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(8, 120), Vector2(355, 55), Vector2(360, size.y - 94), Vector2(8, size.y - 36)]), RED)
	for index in 6:
		var at := Vector2(25 + index * 53, 196 + posmod(index * 37, 250))
		draw_polyline(PackedVector2Array([at, at + Vector2(30, -12), at + Vector2(19, 25), at]), Color("#f0bb9b"), 4.0, true)
	draw_line(Vector2(376, 23), Vector2(376, size.y - 24), PAPER, 3.0)
