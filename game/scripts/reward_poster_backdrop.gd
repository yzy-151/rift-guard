extends Control
const POSTER = preload("res://scripts/poster_surface.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#08090c"))
	for row in 2:
		var y := 25.0 if row == 0 else size.y - 8
		for column in 5:
			draw_string(POSTER.DISPLAY, Vector2(column * 318 - 25, y), "PICK A CARD", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#24242b"))
	_solid(header_polygon(), POSTER.RED)
	_solid(PackedVector2Array([Vector2(47, 195), Vector2(77, 169), Vector2(67, 588), Vector2(33, 613)]), POSTER.RED)
	_solid(PackedVector2Array([Vector2(size.x - 62, 167), Vector2(size.x - 29, 193), Vector2(size.x - 38, 616), Vector2(size.x - 69, 589)]), POSTER.RED)
	var footer: Rect2 = UI_LAYOUT.reward_footer_rect
	# Keep the operating hint on clean ink instead of the decorative word band.
	draw_rect(Rect2(Vector2(0, footer.position.y - 8), Vector2(size.x, footer.size.y + 16)), Color("#08090c"))
	draw_line(footer.position + Vector2(0, -7), Vector2(footer.end.x, footer.position.y - 7), POSTER.PAPER, 3, true)

func header_polygon() -> PackedVector2Array:
	var rect: Rect2 = UI_LAYOUT.reward_header_rect
	return PackedVector2Array([rect.position + Vector2(6, 12), Vector2(rect.end.x, rect.position.y), rect.end + Vector2(-8, -8), Vector2(rect.position.x, rect.end.y + 4)])

func _solid(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.2, true)
