extends Node2D
## A bounded additive pass, shared by all combat lights. No per-particle nodes.
const MAX_LIGHTS := 240
var commands: Array[Dictionary] = []
var radial: GradientTexture2D

func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.38, 1.0])
	gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0.48), Color(1,1,1,0.11), Color(1,1,1,0)])
	radial = GradientTexture2D.new()
	radial.gradient = gradient
	radial.width = 128
	radial.height = 128
	radial.fill = GradientTexture2D.FILL_RADIAL
	radial.fill_from = Vector2(0.5, 0.5)
	radial.fill_to = Vector2(0.5, 0)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func begin_frame() -> void:
	commands.clear()
	queue_redraw()

func glow(point: Vector2, size: Vector2, color: Color, strength: float = 1.0, rotation: float = 0.0) -> void:
	if commands.size() >= MAX_LIGHTS or strength < 0.005:
		return
	commands.append({"point":point, "size":size, "color":Color(color, color.a * strength), "rotation":rotation})

func _draw() -> void:
	if radial == null:
		return
	for light: Dictionary in commands:
		draw_set_transform(light.point, float(light.rotation))
		draw_texture_rect(radial, Rect2(-Vector2(light.size) * 0.5, light.size), false, light.color)
	draw_set_transform(Vector2.ZERO)
