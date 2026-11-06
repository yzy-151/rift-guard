extends Control

const POSTER = preload("res://scripts/poster_surface.gd")

var kind := "row"
var accent := POSTER.RED
var known := true
var highlighted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	if kind == "backdrop":
		draw_rect(Rect2(Vector2.ZERO, size), POSTER.INK)
		for side in [0, 1]:
			var x := 8.0 if side == 0 else size.x - 8.0
			for step in 12:
				var y := 16.0 + step * 66.0
				var direction := 1.0 if side == 0 else -1.0
				draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + direction * 24.0, y + 29.0), Vector2(x, y + 58.0)]), Color("#37373c"))
		return
	var paper := POSTER.PAPER if known else Color("#d9d4cc")
	if highlighted: paper = Color("#ffedb9")
	draw_rect(Rect2(5, 5, size.x - 5, size.y - 5), POSTER.RED)
	draw_rect(Rect2(0, 0, size.x - 5, size.y - 5), POSTER.INK)
	draw_rect(Rect2(3, 3, size.x - 11, size.y - 11), paper)
	draw_colored_polygon(PackedVector2Array([Vector2(3, 3), Vector2(36, 3), Vector2(3, 36)]), accent if known else Color("#91877c"))
	if size.x < 350:
		draw_line(Vector2(104, 64), Vector2(size.x - 18, 64), POSTER.INK, 2.0, true)
	else:
		draw_line(Vector2(158, 52), Vector2(size.x - 26, 52), POSTER.INK, 2.0, true)
	if highlighted:
		draw_line(Vector2(size.x - 27, 12), Vector2(size.x - 14, 25), POSTER.RED, 3.0, true)
		draw_line(Vector2(size.x - 27, 25), Vector2(size.x - 14, 12), POSTER.RED, 3.0, true)
