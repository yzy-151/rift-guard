extends RefCounted
var stories: Dictionary = {}
var seen: Dictionary = {}
var lines: Array = []
var history: Array[Dictionary] = []
var key: String = ""
var index: int = 0
var active: bool = false

func _init(config = null) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	if parsed is Dictionary:
		stories = parsed
	if config != null and config.loaded:
		stories.merge(config.stories, true)

func begin(scene_key: String) -> bool:
	if active or seen.has(scene_key) or not stories.has(scene_key):
		return false
	key = scene_key
	lines = stories[key].duplicate(true)
	if lines.is_empty():
		return false
	index = 0
	active = true
	seen[key] = true
	_record()
	return true

func current() -> Dictionary:
	if not active:
		return {}
	if lines[index] is Dictionary:
		return lines[index].duplicate()
	var row: Array = lines[index]
	return {"portrait": row[0], "speaker": row[1], "text": row[2]}

func advance() -> bool:
	if not active:
		return false
	index += 1
	if index >= lines.size():
		active = false
		return false
	_record()
	return true

func _record() -> void:
	history.append(current().duplicate())

func skip() -> void:
	if not active:
		return
	while index + 1 < lines.size():
		index += 1
		_record()
	active = false

func reset() -> void:
	seen.clear()
	history.clear()
	lines = []
	key = ""
	index = 0
	active = false
