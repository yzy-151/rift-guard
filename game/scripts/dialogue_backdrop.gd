extends Control
## Original black-red dialogue stage.  A configured TextureRect can replace it.

var clock: float = 0.0
var background: Texture2D = preload("res://assets/helltaker/backgrounds/dialBG_darkHell.png")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), Color("#09070b"))
	draw_texture_rect(background, Rect2(0, 0, size.x, size.y), false, Color.WHITE)
	draw_rect(Rect2(0, 78, size.x, 360), Color(0.18, 0.03, 0.07, 0.28))
	# Layered distant architecture keeps the portraits readable while giving the scene depth.
	for i in 13:
		var x := float(i) * 112.0 - 58.0
		var peak := 122.0 + float(i % 4) * 21.0
		var tower := PackedVector2Array([
			Vector2(x, 438), Vector2(x + 12, peak + 35), Vector2(x + 37, peak),
			Vector2(x + 61, peak + 35), Vector2(x + 79, 438)
		])
		draw_colored_polygon(tower, Color("#180b12"))
		draw_rect(Rect2(x + 33, peak + 56, 8, 42), Color("#b33c46"))
	# Broad diagonals create the hard graphic rhythm used throughout the project.
	for i in 7:
		var x := float(i) * 235.0 - 170.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 438), Vector2(x + 92, 78), Vector2(x + 145, 78), Vector2(x + 53, 438)
		]), Color(0.54, 0.10, 0.17, 0.22))
	var glow := 0.025 + sin(clock * 1.7) * 0.008
	draw_circle(Vector2(size.x * 0.5, 257), 390.0, Color(0.95, 0.20, 0.24, glow))
	draw_rect(Rect2(0, 435, size.x, 3), Color("#a43a48"))
	draw_rect(Rect2(0, 438, size.x, size.y - 438), Color("#0e0a10"))
	# Small deterministic embers keep the stage alive without competing with text.
	for i in 18:
		var seed := float(i * 73 % 101) / 101.0
		var x := fmod(float(i * 211), size.x)
		var y := 420.0 - fmod(clock * (12.0 + seed * 18.0) + float(i * 47), 260.0)
		draw_circle(Vector2(x, y), 1.0 + seed, Color(0.95, 0.34, 0.29, 0.20 + seed * 0.24))
