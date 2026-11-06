extends Control
## Flat cut-paper art; the parent Button remains the entire card's hit region.
const POSTER = preload("res://scripts/poster_surface.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")

var accent := POSTER.RED
var selected := false
var rarity := "common"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var edge := POSTER.YELLOW if selected else POSTER.PAPER
	var paper := paper_polygon()
	var shadow := PackedVector2Array()
	for point in paper: shadow.append(point + Vector2(7, 9))
	_solid(shadow, POSTER.INK)
	_solid(paper, POSTER.RED)
	_solid(body_polygon(), POSTER.PAPER)
	draw_polyline(paper + PackedVector2Array([paper[0]]), edge, 3, true)
	_solid(title_polygon(), POSTER.INK)
	var icon: Rect2 = UI_LAYOUT.reward_icon_slot_rect
	var sticker := PackedVector2Array([icon.position + Vector2(1, 4), Vector2(icon.end.x - 6, icon.position.y - 4), icon.end + Vector2(4, -2), Vector2(icon.position.x - 4, icon.end.y + 3)])
	_solid(sticker, Color("#ffffff"))
	draw_polyline(sticker + PackedVector2Array([sticker[0]]), POSTER.INK, 3, true)
	# Rarity remains visible even when another card owns the yellow focus border.
	_solid(PackedVector2Array([Vector2(11, 44), Vector2(20, 43), Vector2(20, size.y - 38), Vector2(11, size.y - 36)]), accent)
	var badge: Rect2 = UI_LAYOUT.battle_reward_rarity_badge_rect
	_solid(PackedVector2Array([badge.position + Vector2(-2, 0), Vector2(badge.end.x + 1, badge.position.y - 1), badge.end + Vector2(0, 1), Vector2(badge.position.x - 3, badge.end.y + 2)]), accent)
	var preview: Rect2 = UI_LAYOUT.reward_preview_rect
	_solid(PackedVector2Array([preview.position + Vector2(-3, 3), Vector2(preview.end.x + 1, preview.position.y - 2), preview.end + Vector2(0, 1), Vector2(preview.position.x - 5, preview.end.y + 4)]), POSTER.INK)
	_solid(action_polygon(), POSTER.YELLOW if selected else POSTER.RED)
	# Tiny torn-paper tabs give the card a collage silhouette without texture noise.
	_solid(PackedVector2Array([Vector2(size.x - 47, 6), Vector2(size.x - 24, 4), Vector2(size.x - 28, 14), Vector2(size.x - 50, 14)]), POSTER.INK)
	draw_line(preview.position + Vector2(2, preview.size.y + 4), preview.end + Vector2(-2, -1), accent, 3, true)

func paper_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(8, 6), Vector2(size.x - 7, 2), Vector2(size.x - 2, size.y - 9), Vector2(2, size.y - 2)])

func body_polygon() -> PackedVector2Array:
	return PackedVector2Array([Vector2(16, 15), Vector2(size.x - 17, 11), Vector2(size.x - 12, size.y - 13), Vector2(11, size.y - 10)])

func title_polygon() -> PackedVector2Array:
	var title: Rect2 = UI_LAYOUT.reward_title_rect
	return PackedVector2Array([title.position + Vector2(-4, -2), Vector2(title.end.x + 2, title.position.y - 4), title.end + Vector2(1, 3), Vector2(title.position.x - 5, title.end.y + 6)])

func action_polygon() -> PackedVector2Array:
	var action: Rect2 = UI_LAYOUT.reward_action_rect
	return PackedVector2Array([action.position + Vector2(-1, -1), Vector2(action.end.x + 1, action.position.y - 2), action.end + Vector2(1, 1), Vector2(action.position.x - 1, action.end.y + 2)])

func _solid(points: PackedVector2Array, color: Color) -> void:
	draw_colored_polygon(points, color)
	# Canvas polygon fills have hard edges in Compatibility; an AA fringe covers
	# their stair steps without changing the deliberately angled paper silhouette.
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.2, true)
