extends RefCounted

const AnimationMachine = preload("res://scripts/animation_state_machine.gd")

var character_id := ""
var machine = AnimationMachine.new()
var profile: Dictionary = {}
var last_facing := 1.0
var attack_speed := 1.0

func setup(id: String, definition: Dictionary) -> void:
	character_id = id
	profile = definition.duplicate(true)
	machine.setup(profile)

func sync(unit: Dictionary, dt: float) -> void:
	var next_state := str(unit.get("animation_state", "idle"))
	if next_state == "run" and not bool(unit.get("moving", false)):
		next_state = "idle"
	last_facing = float(unit.get("facing", last_facing))
	attack_speed = maxf(0.25, float(unit.get("rate", 1.0)) / maxf(0.25, float(unit.get("base_rate", 1.0))))
	machine.play(next_state, last_facing, attack_speed if next_state == "attack" else 1.0)
	machine.tick(dt)

func sample() -> Dictionary:
	var fallback: Dictionary = profile.get("fallback", {})
	var phase := machine.normalized_time()
	var scale := Vector2.ONE
	var offset := Vector2.ZERO
	match machine.state:
		"idle":
			var breath := sin(phase * TAU) * float(fallback.get("breath_scale", 0.018))
			scale = Vector2(1.0 - breath * 0.35, 1.0 + breath)
		"run":
			offset.y = -absf(sin(phase * TAU * 2.0)) * 3.0
			scale = Vector2(1.0 + absf(sin(phase * TAU * 2.0)) * 0.035, 0.98)
		"attack", "skill", "ultimate":
			var impulse := sin(clampf(phase, 0.0, 1.0) * PI)
			scale = Vector2(1.0 + impulse * 0.08, 1.0 - impulse * 0.05)
		"hurt":
			var squash := float(fallback.get("hurt_squash", 0.12))
			scale = Vector2(1.0 + squash, 1.0 - squash)
	return {"state":machine.state,"frame":machine.frame_index(),"facing":machine.facing,"scale":scale,"offset":offset,"hit_ready":machine.consume_hit_event()}
