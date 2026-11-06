extends Control

const WHITE := Color("#fff9f1")
const INK := Color("#08090b")
const YELLOW := Color("#ffc94d")
const DISPLAY = preload("res://assets/fonts/Leigai.ttf")
const CHINESE = preload("res://assets/fonts/TiejiliSC-Regular.ttf")

var caption := ""
var english := ""
var tilt := -0.10
var focused := false
var available := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var skew := 12.0
	var plate := PackedVector2Array([Vector2(skew, 5), Vector2(size.x - 8, 0), Vector2(size.x - skew, size.y - 8), Vector2(0, size.y)])
	draw_colored_polygon(plate, INK)
	draw_polyline(plate + PackedVector2Array([plate[0]]), WHITE if available else Color("#706c76"), 3, true)
	var inner := PackedVector2Array([Vector2(20, 12), Vector2(size.x - 19, 7), Vector2(size.x - 24, size.y - 14), Vector2(9, size.y - 9)])
	draw_colored_polygon(inner, YELLOW if focused and available else INK)
	draw_set_transform(Vector2(size.x * 0.5, size.y * 0.5), tilt, Vector2.ONE)
	var text_width := size.x - 40.0
	var chinese_size := 29
	var english_size := 58 if size.y > 90 else 43
	while DISPLAY.get_string_size(english, HORIZONTAL_ALIGNMENT_LEFT, -1, english_size).x > text_width and english_size > 26:
		english_size -= 1
	var color := INK if focused and available else WHITE if available else Color("#79747f")
	var x := -size.x * 0.5 + 22
	var top := -size.y * 0.5 + 35.0
	draw_string_outline(CHINESE, Vector2(x, top), caption, HORIZONTAL_ALIGNMENT_LEFT, text_width, chinese_size, 5, INK if color != INK else YELLOW)
	draw_string(CHINESE, Vector2(x, top), caption, HORIZONTAL_ALIGNMENT_LEFT, text_width, chinese_size, color)
	var bottom := size.y * 0.5 - 13.0
	draw_string_outline(DISPLAY, Vector2(x, bottom), english, HORIZONTAL_ALIGNMENT_LEFT, text_width, english_size, 5, INK if color != INK else YELLOW)
	draw_string_outline(DISPLAY, Vector2(x, bottom), english, HORIZONTAL_ALIGNMENT_LEFT, text_width, english_size, 1, color)
	draw_string(DISPLAY, Vector2(x, bottom), english, HORIZONTAL_ALIGNMENT_LEFT, text_width, english_size, color)
