extends Node2D
## Coherent full-silhouette frame animation; no detached body-part assembly.

const FRAME_SIZE := Vector2(256, 256)
const ATTACK_FRAME_SIZE := Vector2(512, 512)
const DISPLAY_SCALE := 0.52
const DEFINITIONS := {
	"idle": {"row": 0, "frames": 8, "fps": 6.0, "loop": true},
	"move": {"row": 1, "frames": 8, "fps": 12.0, "loop": true},
	"attack": {"row": 2, "frames": 16, "fps": 8.0, "loop": true},
	"hurt": {"row": 3, "frames": 4, "fps": 14.0, "loop": false},
	"down": {"row": 4, "frames": 8, "fps": 12.0, "loop": false},
}

var sprite: AnimatedSprite2D
var current_state := ""
var attack_hold := 0.0
var hurt_hold := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	sprite.position = Vector2(0, -100)
	sprite.sprite_frames = build_frames()
	add_child(sprite)
	set_state("idle")

func build_frames() -> SpriteFrames:
	var result := SpriteFrames.new()
	result.remove_animation("default")
	var legacy_atlas: Texture2D = load("res://assets/characters/furina_frames/furina-motion-sheet.png")
	var attack_atlas: Texture2D = load("res://assets/characters/furina_ai_frames/attack_16/furina-attack-16-atlas.png")
	for name in DEFINITIONS:
		var definition: Dictionary = DEFINITIONS[name]
		result.add_animation(name)
		result.set_animation_speed(name, definition.fps)
		result.set_animation_loop(name, definition.loop)
		for index in definition.frames:
			var frame := AtlasTexture.new()
			if name == "attack":
				frame.atlas = attack_atlas
				frame.region = Rect2(Vector2(index % 4, index / 4) * ATTACK_FRAME_SIZE, ATTACK_FRAME_SIZE)
			else:
				frame.atlas = legacy_atlas
				frame.region = Rect2(Vector2(index, definition.row) * FRAME_SIZE, FRAME_SIZE)
			result.add_frame(name, frame)
	return result

func sync(hero: Dictionary, screen_position: Vector2, depth: float, shot_life: float, reduced: bool, dt: float = 0.0) -> void:
	position = screen_position + Vector2(0, 8)
	var facing := float(hero.get("facing", 1.0))
	scale = Vector2(DISPLAY_SCALE * depth * facing, DISPLAY_SCALE * depth)
	attack_hold = maxf(0.0, attack_hold - dt)
	hurt_hold = maxf(0.0, hurt_hold - dt)
	if shot_life > 0.0:
		attack_hold = 2.0
	if hero.flash > 0.0:
		hurt_hold = 0.28
	var next_state := "idle"
	if hero.hp <= 0.0:
		next_state = "down"
	elif hurt_hold > 0.0:
		next_state = "hurt"
	elif attack_hold > 0.0:
		next_state = "attack"
	elif hero.moving:
		next_state = "move"
	set_state(next_state)
	modulate = Color("#ffb5b2") if next_state == "hurt" and not reduced else Color.WHITE
	if reduced and next_state not in ["attack", "hurt", "down"]:
		sprite.pause()
		sprite.frame = 0
	elif not sprite.is_playing() and (DEFINITIONS[current_state].loop or sprite.frame < DEFINITIONS[current_state].frames - 1):
		sprite.play()

func set_state(next_state: String) -> void:
	if current_state == next_state:
		return
	current_state = next_state
	sprite.scale = Vector2.ONE * (0.5 if next_state == "attack" else 1.0)
	sprite.play(next_state)
