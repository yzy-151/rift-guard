extends RefCounted

var profile: Dictionary = {}
var state := "idle"
var elapsed := 0.0
var facing := 1.0

func setup(definition: Dictionary) -> void:
	profile = definition.duplicate(true)
	state = "idle"
	elapsed = 0.0

func play(next_state: String, direction: float = 0.0) -> void:
	if not profile.get("states", {}).has(next_state):
		next_state = "idle"
	if state != next_state:
		state = next_state
		elapsed = 0.0
	if absf(direction) > 0.01:
		facing = signf(direction)

func tick(dt: float) -> void:
	elapsed += maxf(0.0, dt)
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	var duration := maxf(0.01, float(definition.get("duration", 1.0)))
	if elapsed >= duration:
		if bool(definition.get("loop", false)):
			elapsed = fmod(elapsed, duration)
		else:
			play("idle", facing)

func frame_index() -> int:
	var definition: Dictionary = profile.get("states", {}).get(state, {})
	var frames := maxi(1, int(definition.get("frames", 1)))
	var duration := maxf(0.01, float(definition.get("duration", 1.0)))
	return mini(frames - 1, floori(elapsed / duration * frames))
