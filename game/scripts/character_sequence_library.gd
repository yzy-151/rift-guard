extends RefCounted
## Lazy atlas reader for replaceable 24 FPS character frame sequences.

const MANIFEST_PATH := "res://data/v2/character_sequences.json"
const STATE_ALIASES := {
	"idle": "idle",
	"run": "run",
	"attack": "attack",
	"skill": "attack",
	"ultimate": "attack",
	"hurt": "idle",
	"down": "down",
}

var definitions: Dictionary = {}
var textures: Dictionary = {}
var load_errors: Array[String] = []

func _init() -> void:
	reload_manifest()

func reload_manifest() -> void:
	definitions.clear()
	textures.clear()
	load_errors.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		load_errors.append("missing character sequence manifest")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		definitions = parsed
	else:
		load_errors.append("invalid character sequence manifest")

func has_character(character_id: String) -> bool:
	return definitions.has(character_id)

func definition(character_id: String) -> Dictionary:
	return definitions.get(character_id, {})

func state_name(runtime_state: String) -> String:
	return str(STATE_ALIASES.get(runtime_state, "idle"))

func state_definition(character_id: String, runtime_state: String) -> Dictionary:
	var row: Dictionary = definition(character_id)
	return row.get("states", {}).get(state_name(runtime_state), {})

func frame_count(character_id: String, runtime_state: String) -> int:
	return maxi(1, int(state_definition(character_id, runtime_state).get("frames", 1)))

func frame_at_time(character_id: String, runtime_state: String, elapsed: float) -> int:
	var state: Dictionary = state_definition(character_id, runtime_state)
	var count := maxi(1, int(state.get("frames", 1)))
	var fps := maxf(1.0, float(state.get("fps", 24.0)))
	var raw := maxi(0, floori(elapsed * fps))
	if bool(state.get("loop", false)):
		return posmod(raw, count)
	return mini(raw, count - 1)

func frame_at_phase(character_id: String, runtime_state: String, phase: float) -> int:
	var count := frame_count(character_id, runtime_state)
	return clampi(floori(clampf(phase, 0.0, 0.999999) * count), 0, count - 1)

func texture(character_id: String, runtime_state: String) -> Texture2D:
	var state := state_name(runtime_state)
	var key := character_id + ":" + state
	if textures.has(key):
		return textures[key]
	var path := str(state_definition(character_id, state).get("texture", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		load_errors.append("missing character sequence atlas: " + key)
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is Texture2D:
		textures[key] = resource
		return resource
	load_errors.append("invalid character sequence atlas: " + key)
	return null

func source_rect(character_id: String, runtime_state: String, frame: int) -> Rect2:
	var row: Dictionary = definition(character_id)
	var state: Dictionary = state_definition(character_id, runtime_state)
	var cell_data: Array = row.get("cell", [256, 256])
	var cell := Vector2(float(cell_data[0]), float(cell_data[1]))
	var columns := maxi(1, int(state.get("columns", 1)))
	return Rect2(Vector2(frame % columns, frame / columns) * cell, cell)

func cell(character_id: String) -> Vector2:
	var value: Array = definition(character_id).get("cell", [256, 256])
	return Vector2(float(value[0]), float(value[1]))

func pivot(character_id: String) -> Vector2:
	var value: Array = definition(character_id).get("pivot", [128, 248])
	return Vector2(float(value[0]), float(value[1]))

func display_size(character_id: String) -> float:
	return float(definition(character_id).get("display_size", 150.0))