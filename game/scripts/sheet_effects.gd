extends Node2D
const Stage = preload("res://scripts/stage_projection.gd")
const GOLD = preload("res://assets/effects/heal-sheet.png")
const BLUE = preload("res://assets/effects/arcane-sheet.png")
var active: Array[Dictionary] = []
var reduced: bool = false
func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
func accept(batch: Array[Dictionary]) -> void:
	if reduced:
		return
	for event in batch:
		if event.kind in ["heal", "vaporize"] and active.size() < 12:
			active.append({"kind": event.kind, "pos": event.pos, "age": 0.0})
func advance(dt: float) -> void:
	for effect in active:
		effect.age += dt
	active = active.filter(func(effect: Dictionary) -> bool: return effect.age < duration(effect.kind))
	queue_redraw()
func duration(kind: String) -> float:
	return 0.7 if kind == "heal" else 0.5
func frame_region(kind: String, index: int) -> Rect2:
	var columns: int = 5 if kind == "heal" else 3
	var cell := Vector2(2048.0 / columns, 576 if kind == "heal" else 579)
	return Rect2(Vector2(index % columns, index / columns) * cell + Vector2(14, 44), cell - Vector2(28, 78))
func _draw() -> void:
	if reduced:
		return
	for effect in active:
		var total: int = 10 if effect.kind == "heal" else 6
		var fraction: float = clampf(effect.age / duration(effect.kind), 0, 0.999)
		var frame: int = mini(total - 1, int(fraction * total))
		var point: Vector2 = Stage.project(effect.pos)
		var size := Vector2(108, 128) if effect.kind == "heal" else Vector2(145, 113)
		size *= Stage.depth_scale(effect.pos)
		var opacity: float = 0.66 * minf(1.0, (1.0 - fraction) * 5.0)
		draw_texture_rect_region(GOLD if effect.kind == "heal" else BLUE, Rect2(point - Vector2(size.x * 0.5, size.y * 0.82), size), frame_region(effect.kind, frame), Color(1, 1, 1, opacity))
