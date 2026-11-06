extends Panel

const INK := Color("#090a0d")
const PAPER := Color("#fff8ec")
const RED := Color("#dc244c")
const YELLOW := Color("#ffc94d")
const TYPE = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const DISPLAY = preload("res://assets/fonts/Leigai.ttf")

var side_title := false
var title_rect := Rect2()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(7, 15), Vector2(size.x - 9, 0), Vector2(size.x, size.y - 12), Vector2(0, size.y)]), RED)
	draw_colored_polygon(PackedVector2Array([Vector2(17, 21), Vector2(size.x - 18, 11), Vector2(size.x - 12, size.y - 23), Vector2(11, size.y - 11)]), INK)
	if side_title:
		var right := title_rect.end.x + 15.0
		draw_colored_polygon(PackedVector2Array([Vector2(17, 23), Vector2(right, 13), Vector2(right - 24, size.y - 27), Vector2(11, size.y - 12)]), RED)
	else:
		var header := title_rect.grow(5)
		draw_colored_polygon(PackedVector2Array([header.position + Vector2(3, 6), Vector2(header.end.x - 15, header.position.y), header.end + Vector2(0, -5), Vector2(header.position.x, header.end.y)]), RED)

static func style_button(button: Button, primary := false, font_size := 23) -> void:
	button.add_theme_font_override("font", TYPE)
	button.add_theme_font_size_override("font_size", font_size)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = YELLOW if state in ["hover", "focus"] else RED if primary else PAPER
		box.border_color = INK
		box.set_border_width_all(3)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.shadow_color = RED
		box.shadow_size = 0
		box.shadow_offset = Vector2(-4, 4)
		button.add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, INK if state != "font_color" or not primary else PAPER)
	button.add_theme_color_override("font_disabled_color", Color("#837f79"))

static func paper_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PAPER
	box.border_color = INK
	box.set_border_width_all(3)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box
