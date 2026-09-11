extends RefCounted

var profile: Dictionary = {}
var state := "idle"
var elapsed := 0.0
var facing := 1.0
var speed_scale := 1.0
var hit_emitted := false

func setup(definition: Dictionary) -> void:
	profile = definition.duplicate(true)
	state = "idle"
	elapsed = 0.0

func play(next_state: String, direction: float = 0.0, playback_speed: float = 1.0) -> void:
	if not profile.get("states", {}).has(next_state):
		next_state = "idle"
	if state != next_state:
		state = next_state
		elapsed = 0.0
		hit_emitted = false
	speed_scale = maxf(0.1, playback_speed)
	if absf(direction) > 0.01:
		facing = signf(direction)

func tick(dt: float) -> void:
	elapsed += maxf(0.0, dt) * speed_scale
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	var duration := maxf(0.01, float(definition.get("duration", 1.0)))
	if elapsed >= duration:
		if bool(definition.get("loop", false)):
			elapsed = fmod(elapsed, duration)
		else:
			play("idle", facing)

func normalized_time() -> float:
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	var duration := maxf(0.01, float(definition.get("duration", 1.0)))
	return clampf(elapsed / duration, 0.0, 1.0)

func consume_hit_event() -> bool:
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	if not definition.has("hit_ratio") or hit_emitted or normalized_time() < float(definition.hit_ratio):
		return false
	hit_emitted = true
	return true

func frame_index() -> int:
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	var frames := maxi(1, int(definition.get("frames", 1)))
	var duration := maxf(0.01, float(definition.get("duration", 1.0)))
	return mini(frames - 1, floori(elapsed / duration * frames))
