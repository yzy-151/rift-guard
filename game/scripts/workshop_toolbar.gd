extends Control
## A compact, flat command rail for the independent workshop battle.

const INK := Color("#140d14")
const DEEP := Color("#09070b")
const RED := Color("#b72743")
const LIGHT_RED := Color("#ed5d6f")
const WHITE := Color("#f6eeea")
const MUTED := Color("#b49ba2")
const DISPLAY_FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")

var running := true

class RailButton extends Button:
	var role := "tool"
	var symbol := ""
	var key_hint := ""
	var paused := false
	func _draw() -> void:
		var hovered := is_hovered() and not disabled
		var held := is_pressed() and not disabled
		var fill := Color("#b72743") if role == "transport" else Color("#191018")
		if role == "exit": fill = Color("#30101c")
		if hovered: fill = Color("#d43a54") if role == "transport" else Color("#552132")
		if held: fill = Color("#8d1c36")
		var points := PackedVector2Array([Vector2(5, 0), Vector2(size.x, 0), Vector2(size.x, size.y - 5), Vector2(size.x - 5, size.y), Vector2(0, size.y), Vector2(0, 5)])
		if role != "tool" or hovered or held:
			draw_colored_polygon(points, fill)
		if role != "tool":
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, Color("#09070b"), 2.0, true)
		if role == "transport" or role == "exit":
			draw_line(Vector2(6, size.y - 1), Vector2(size.x - 7, size.y - 1), Color("#ed5d6f"), 2.0)
		elif hovered:
			draw_line(Vector2(8, size.y - 1), Vector2(size.x - 8, size.y - 1), Color("#ed5d6f"), 2.0)
		var tint := Color("#f6eeea")
		var center := Vector2(15, size.y * 0.5)
		match symbol:
			"pause":
				if paused:
					draw_colored_polygon(PackedVector2Array([center + Vector2(-4, -6), center + Vector2(6, 0), center + Vector2(-4, 6)]), tint)
				else:
					draw_rect(Rect2(center + Vector2(-5, -6), Vector2(3, 12)), tint)
					draw_rect(Rect2(center + Vector2(2, -6), Vector2(3, 12)), tint)
			"step":
				draw_colored_polygon(PackedVector2Array([center + Vector2(-5, -5), center + Vector2(3, 0), center + Vector2(-5, 5)]), tint)
				draw_line(center + Vector2(5, -6), center + Vector2(5, 6), tint, 2.0)
			"exit":
				draw_line(center + Vector2(5, 0), center + Vector2(-5, 0), tint, 2.0)
				draw_polyline(PackedVector2Array([center + Vector2(0, -5), center + Vector2(-5, 0), center + Vector2(0, 5)]), tint, 2.0)
		if not key_hint.is_empty():
			var badge_width := 25.0 if key_hint != "." else 13.0
			var at := Vector2(size.x - badge_width - 7, 8)
			draw_rect(Rect2(at, Vector2(badge_width, size.y - 16)), Color("#09070b"))
			var font := get_theme_font("font")
			var text_width := font.get_string_size(key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, at + Vector2((badge_width - text_width) * 0.5, 12), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#e8cdd2"))
		var body_font := get_theme_font("font")
		var left := 25.0 if not symbol.is_empty() else 7.0
		var right := (34.0 if key_hint != "." else 22.0) if not key_hint.is_empty() else 7.0
		var text_width := body_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var baseline := (size.y - body_font.get_height(13)) * 0.5 + body_font.get_ascent(13)
		draw_string(body_font, Vector2(left + (size.x - left - right - text_width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, tint)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func _draw() -> void:
	var frame := PackedVector2Array([Vector2(7, 0), Vector2(size.x, 0), Vector2(size.x, size.y - 7), Vector2(size.x - 7, size.y), Vector2(0, size.y), Vector2(0, 7)])
	draw_colored_polygon(frame, INK)
	var outline := frame.duplicate()
	outline.append(frame[0])
	draw_polyline(outline, DEEP, 3.0, true)
	draw_line(Vector2(9, size.y - 1), Vector2(size.x - 9, size.y - 1), Color("#7b263a"), 2.0)
	# The angled title tab belongs to the workshop's red-and-black comic shell.
	draw_colored_polygon(PackedVector2Array([Vector2(4, 3), Vector2(272, 3), Vector2(257, 45), Vector2(4, 45)]), Color("#24111d"))
	draw_line(Vector2(9, 8), Vector2(9, 39), LIGHT_RED, 4.0)
	draw_rect(Rect2(610, 7, 442, 34), Color("#191018"))
	for x in [701.0, 819.0, 937.0]:
		draw_line(Vector2(x, 15), Vector2(x, 33), Color("#42212f"), 1.0)
	for x in [588.0, 1080.0]:
		draw_line(Vector2(x + 5, 9), Vector2(x - 5, 39), Color("#713244"), 2.0)
	var status := LIGHT_RED if running else MUTED
	draw_circle(Vector2(175, 16), 3.0, status)

func action(rect: Rect2, title: String, role: String = "tool", symbol: String = "", hint: String = "") -> Button:
	var button := RailButton.new()
	button.position = rect.position
	button.size = rect.size
	button.text = title
	button.role = role
	button.symbol = symbol
	button.key_hint = hint
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("dialogue_sound", true)
	button.add_theme_font_size_override("font_size", 13)
	# The custom draw owns typography so the flat art stays above its own paint.
	button.add_theme_color_override("font_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_hover_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_pressed_color", Color.TRANSPARENT)
	button.add_theme_color_override("font_outline_color", DEEP)
	button.add_theme_constant_override("outline_size", 0)
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxEmpty.new()
		style.content_margin_left = 25 if not symbol.is_empty() else 7
		style.content_margin_right = (34 if hint != "." else 22) if not hint.is_empty() else 7
		button.add_theme_stylebox_override(state, style)
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)
	button.button_down.connect(button.queue_redraw)
	button.button_up.connect(button.queue_redraw)
	add_child(button)
	return button

func style_speed(picker: OptionButton) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("#552132") if state in ["hover", "pressed"] else Color("#191018")
		box.set_border_width_all(2)
		box.border_color = DEEP
		box.content_margin_left = 10
		box.content_margin_right = 22
		picker.add_theme_stylebox_override(state, box)
	picker.add_theme_font_size_override("font_size", 13)
	picker.add_theme_color_override("font_color", WHITE)
	picker.add_theme_color_override("font_hover_color", Color.WHITE)
	picker.add_theme_color_override("font_pressed_color", Color.WHITE)
	picker.add_theme_color_override("font_outline_color", DEEP)
	picker.add_theme_constant_override("outline_size", 0)
	picker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func set_paused(value: bool) -> void:
	running = not value
	queue_redraw()
