extends Control

const PINK := Color("#dc244c")
const WHITE := Color("#fff9f1")
const INK := Color("#08090b")
const DISPLAY = preload("res://assets/fonts/Leigai.ttf")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var clock := 0.0
var animated := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not animated: return
	clock += delta
	queue_redraw()

func pattern_stride() -> float:
	return DISPLAY.get_string_size("RIFT GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, UI_LAYOUT.mode_pattern_font_size).x + UI_LAYOUT.mode_pattern_gap

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	draw_colored_polygon(PackedVector2Array([Vector2(34, 108), Vector2(444, 78), Vector2(477, 572), Vector2(26, 630)]), PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(969, 92), Vector2(1257, 50), Vector2(1300, 644), Vector2(931, 611)]), PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(474, 56), Vector2(719, 10), Vector2(944, 665), Vector2(566, 720)]), Color("#16171b"))
	var stride := pattern_stride()
	for baseline: float in [UI_LAYOUT.mode_pattern_baselines.x, UI_LAYOUT.mode_pattern_baselines.y]:
		for column in ceili(size.x / stride) + 1:
			draw_string(DISPLAY, Vector2(column * stride - 32, baseline), "RIFT GUARD", HORIZONTAL_ALIGNMENT_LEFT, -1, UI_LAYOUT.mode_pattern_font_size, Color("#3b3a40"))
	for i in 9:
		var y := 126.0 + i * 58.0
		draw_colored_polygon(PackedVector2Array([Vector2(0, y), Vector2(38, y + 22), Vector2(0, y + 43), Vector2(0, y + 33), Vector2(22, y + 22), Vector2(0, y + 10)]), Color("#464349"))
		draw_colored_polygon(PackedVector2Array([Vector2(1280, y), Vector2(1242, y + 22), Vector2(1280, y + 43), Vector2(1280, y + 33), Vector2(1258, y + 22), Vector2(1280, y + 10)]), Color("#464349"))
	_star(Vector2(493, 116), 35, WHITE)
	_star(Vector2(1060, 40), 16, WHITE)
	_star(Vector2(455, 625), 22, WHITE)
	_star(Vector2(889, 613), 23, PINK)
	_star(Vector2(953, 121), 12, Color("#ffc94d"))
	var offset := sin(clock * 1.1) * 3.0 if animated else 0.0
	draw_line(Vector2(566, 642 + offset), Vector2(838, 642 + offset), WHITE, 3)
	draw_line(Vector2(577, 651 + offset), Vector2(803, 651 + offset), PINK, 7)

func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 8:
		var angle := -PI * 0.5 + i * PI * 0.25
		var distance := radius if i % 2 == 0 else radius * 0.22
		points.append(center + Vector2(cos(angle), sin(angle)) * distance)
	draw_colored_polygon(points, INK)
	draw_polyline(points + PackedVector2Array([points[0]]), color, 4, true)
