extends RefCounted
## Lazy atlas reader for replaceable 24 FPS enemy frame sequences.

const MANIFEST_PATH := "res://data/v2/enemy_sequences.json"
const STATE_ALIASES := {
	"idle": "idle",
	"run": "run",
	"attack": "attack",
	"down": "down",
}

var definitions: Dictionary = {}
var textures: Dictionary = {}
var load_errors: Array[String] = []
var warm_queue: Array[String] = []
var warm_loading: Dictionary = {}

func _init() -> void:
	reload_manifest()

func reload_manifest() -> void:
	definitions.clear()
	textures.clear()
	load_errors.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		load_errors.append("missing enemy sequence manifest")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if parsed is Dictionary:
		definitions = parsed
	else:
		load_errors.append("invalid enemy sequence manifest")

func queue_prewarm(ids: Array) -> void:
	for id in ids:
		for state in definition(str(id)).get("states", {}):
			var key := str(id)+":"+str(state)
			if not textures.has(key) and not warm_queue.has(key) and not warm_loading.has(key):warm_queue.append(key)

func poll_prewarm() -> void:
	# One texture finalization per frame avoids a burst of atlas uploads.
	for key in warm_loading.keys():
		var path: String = warm_loading[key]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var resource = ResourceLoader.load_threaded_get(path)
			if resource is Texture2D:
				textures[key]=resource
				resource.get_rid()
			warm_loading.erase(key)
			return
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			warm_loading.erase(key)
	if warm_loading.size()<2 and not warm_queue.is_empty():
		var key: String = warm_queue.pop_front()
		var split := key.split(":")
		var path := str(state_definition(split[0],split[1]).get("texture",""))
		if ResourceLoader.load_threaded_request(path,"Texture2D")==OK:warm_loading[key]=path

func has_enemy(enemy_id: String) -> bool:
	return definitions.has(enemy_id)

func definition(enemy_id: String) -> Dictionary:
	return definitions.get(enemy_id, {})

func state_definition(enemy_id: String, state: String) -> Dictionary:
	var states: Dictionary = definition(enemy_id).get("states", {})
	return states.get(state, states.get(str(STATE_ALIASES.get(state, "run")), {}))

func frame_count(enemy_id: String, state: String) -> int:
	return maxi(1, int(state_definition(enemy_id, state).get("frames", 1)))

func frame_at_time(enemy_id: String, state: String, elapsed: float) -> int:
	var row := state_definition(enemy_id, state)
	var count := maxi(1, int(row.get("frames", 1)))
	var fps := maxf(1.0, float(row.get("fps", 24.0)))
	var raw := maxi(0, floori(elapsed * fps))
	return posmod(raw, count) if bool(row.get("loop", false)) else mini(raw, count - 1)

func frame_at_phase(enemy_id: String, state: String, phase: float) -> int:
	var count := frame_count(enemy_id, state)
	return clampi(floori(clampf(phase, 0.0, 0.999999) * count), 0, count - 1)

func duration(enemy_id: String, state: String) -> float:
	var row := state_definition(enemy_id, state)
	return float(frame_count(enemy_id, state)) / maxf(1.0, float(row.get("fps", 24.0)))

func texture(enemy_id: String, state: String) -> Texture2D:
	var key := enemy_id + ":" + state
	if textures.has(key):
		return textures[key]
	if warm_loading.has(key):
		if ResourceLoader.load_threaded_get_status(warm_loading[key]) != ResourceLoader.THREAD_LOAD_LOADED:return null
		textures[key]=ResourceLoader.load_threaded_get(warm_loading[key]);warm_loading.erase(key)
		return textures[key]
	var path := str(state_definition(enemy_id, state).get("texture", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		load_errors.append("missing enemy sequence atlas: " + key)
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is Texture2D:
		textures[key] = resource
		return resource
	load_errors.append("invalid enemy sequence atlas: " + key)
	return null

func source_rect(enemy_id: String, state: String, frame: int) -> Rect2:
	var row := definition(enemy_id)
	var value: Dictionary = state_definition(enemy_id, state)
	var cell_data: Array = row.get("cell", [256, 256])
	var cell := Vector2(float(cell_data[0]), float(cell_data[1]))
	var columns := maxi(1, int(value.get("columns", 1)))
	return Rect2(Vector2(frame % columns, frame / columns) * cell, cell)

func cell(enemy_id: String) -> Vector2:
	var value: Array = definition(enemy_id).get("cell", [256, 256])
	return Vector2(float(value[0]), float(value[1]))

func pivot(enemy_id: String) -> Vector2:
	var value: Array = definition(enemy_id).get("pivot", [128, 248])
	return Vector2(float(value[0]), float(value[1]))

func display_size(enemy_id: String) -> float:
	return float(definition(enemy_id).get("display_size", 120.0))

func portrait_path(enemy_id: String) -> String:
	return "res://assets/enemies/sequences/%s/portrait.png" % enemy_id

func procedural(enemy_id: String) -> String:
	return str(definition(enemy_id).get("procedural", ""))
func draw_bounds(enemy_id: String, state: String, frame: int) -> Rect2:
	var bounds: Array = state_definition(enemy_id,state).get("draw_bounds",[])
	if frame<0 or frame>=bounds.size():return Rect2()
	var b: Array=bounds[frame]
	return Rect2(b[0],b[1],b[2],b[3])
