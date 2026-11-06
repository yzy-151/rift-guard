extends Node2D
## Additive light halos stay local to combat effects; no full-screen bloom/filter.
const LIMIT := 96
var sprites: Array[Dictionary] = []

func _ready() -> void:
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	set_process(false)

func begin_frame() -> void:
	sprites.clear()
	queue_redraw()

func emit(texture: Texture2D, point: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	if sprites.size() >= LIMIT or alpha <= .005: return
	sprites.append({"texture":texture,"rect":Rect2(point-size*.5,size),"color":Color(color,clampf(alpha,0.0,1.0))})
	queue_redraw()

func _draw() -> void:
	for sprite: Dictionary in sprites:
		draw_texture_rect(sprite.texture,sprite.rect,false,sprite.color)
