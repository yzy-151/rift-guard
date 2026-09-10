extends Control
## Character-card preview with true atlas playback when available and a soft fallback breath loop.

var character_id := ""
var element_color := Color.WHITE
var source_texture: Texture2D
var atlas_frames := 0
var atlas_columns := 1
var atlas_cell := Vector2.ZERO
var elapsed := 0.0
var locked := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_process(true)

func configure(id: String, asset: Dictionary, color: Color, is_locked: bool) -> void:
	character_id = id
	element_color = color
	locked = is_locked
	atlas_frames = 0
	var idle_path := str(asset.get("idle", ""))
	atlas_frames = int(asset.get("idle_frames", 0))
	atlas_columns = maxi(1, int(asset.get("idle_columns", 1)))
	var cell_data: Array = asset.get("idle_cell", [])
	if atlas_frames > 0 and cell_data.size() >= 2 and ResourceLoader.exists(idle_path):
		atlas_cell = Vector2(float(cell_data[0]), float(cell_data[1]))
		source_texture = load(idle_path)
	else:
		atlas_frames = 0
		var portrait_path := str(asset.get("portrait", ""))
		source_texture = load(portrait_path) if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path) else null
	queue_redraw()

func set_locked(value: bool) -> void:
	locked = value
	queue_redraw()

func _process(dt: float) -> void:
	elapsed += dt
	queue_redraw()

func _draw() -> void:
	var area := Rect2(Vector2.ZERO, size)
	draw_rect(area, Color("#0c1016"))
	draw_circle(Vector2(size.x * 0.50, size.y * 0.68), size.x * 0.42, Color(element_color, 0.10))
	draw_arc(Vector2(size.x * 0.50, size.y * 0.76), size.x * 0.34, PI, TAU, 28, Color(element_color, 0.48), 2.0, true)
	for spark in 3:
		var angle := elapsed * (0.45 + spark * 0.11) + spark * TAU / 3.0
		var spark_pos := Vector2(size.x * 0.5, size.y * 0.62) + Vector2.from_angle(angle) * Vector2(size.x * 0.34, size.y * 0.20)
		draw_circle(spark_pos, 1.5 + spark * 0.45, Color(element_color, 0.68))
	if source_texture != null:
		var breath := 1.0 + sin(elapsed * PI) * 0.018
		var lift := sin(elapsed * PI) * 1.2
		var bounds := Vector2(size.x - 10.0, size.y - 6.0) * breath
		var destination := Rect2((size.x - bounds.x) * 0.5, size.y - bounds.y + lift, bounds.x, bounds.y)
		var tint := Color(0.29, 0.29, 0.31, 0.82) if locked else Color.WHITE
		if atlas_frames > 0:
			var frame := posmod(floori(elapsed * 24.0), atlas_frames)
			var source := Rect2(Vector2(frame % atlas_columns, frame / atlas_columns) * atlas_cell, atlas_cell)
			draw_texture_rect_region(source_texture, destination, source, tint)
		else:
			var texture_size := source_texture.get_size()
			var scale_factor := minf(bounds.x / maxf(1.0, texture_size.x), bounds.y / maxf(1.0, texture_size.y))
			var fitted := texture_size * scale_factor
			var fitted_rect := Rect2(Vector2((size.x - fitted.x) * 0.5, size.y - fitted.y + lift), fitted)
			draw_texture_rect(source_texture, fitted_rect, false, tint)
	if locked:
		draw_rect(area, Color(0.02, 0.02, 0.03, 0.46))
		draw_circle(Vector2(size.x * 0.5, size.y * 0.53), 12.0, Color("#171119"))
		draw_arc(Vector2(size.x * 0.5, size.y * 0.53), 8.0, PI, TAU, 16, Color("#8e747d"), 2.0, true)
		draw_rect(Rect2(size.x * 0.5 - 8.0, size.y * 0.53 - 1.0, 16.0, 13.0), Color("#8e747d"))
	draw_rect(area, Color(element_color, 0.56 if not locked else 0.18), false, 1.5)
