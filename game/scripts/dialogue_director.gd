extends RefCounted

signal choice_resolved(choice: Dictionary)

var stories: Dictionary = {}
var seen: Dictionary = {}
var lines: Array = []
var history: Array[Dictionary] = []
var choice_history: Array[Dictionary] = []
var key: String = ""
var index: int = 0
var active: bool = false

func _init(config = null) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	if parsed is Dictionary:
		var builtin: Dictionary = parsed.duplicate(true)
		stories = builtin.duplicate(true)
		if config != null and config.loaded:
			stories.merge(config.stories, true)
			# Campaign scenes are authored together; keep extra workbook scenes,
			# but do not let stale rows replace the current cast and branching.
			for scene_key: String in builtin:
				stories[scene_key] = builtin[scene_key].duplicate(true)

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
	if not active or index < 0 or index >= lines.size():
		return {}
	if lines[index] is Dictionary:
		return lines[index].duplicate(true)
	var row: Array = lines[index]
	return {"portrait": row[0], "speaker": row[1], "text": row[2]}

func has_choices() -> bool:
	return active and not current().get("choices", []).is_empty()

func choose(choice_index: int) -> bool:
	if not has_choices():
		return false
	var options: Array = current().get("choices", [])
	if choice_index < 0 or choice_index >= options.size() or not options[choice_index] is Dictionary:
		return false
	var option: Dictionary = options[choice_index].duplicate(true)
	choice_history.append({"scene": key, "line": index, "choice": choice_index, "text": str(option.get("text", "")), "result": str(option.get("result", ""))})
	history.append({"portrait": "", "speaker": "你的选择", "text": str(option.get("text", ""))})
	choice_resolved.emit(option.duplicate(true))
	var source: Dictionary = current()
	var response := {
		"portrait": str(option.get("response_portrait", source.get("portrait", ""))),
		"partner": str(source.get("partner", "")),
		"speaker": str(option.get("response_speaker", source.get("speaker", ""))),
		"text": str(option.get("response", "选择已经记录。")),
		"highlight": str(option.get("response_highlight", source.get("highlight", "main")))
	}
	index += 1
	lines.insert(index, response)
	var follow_up: Array = option.get("follow_up", [])
	for offset in follow_up.size():
		if follow_up[offset] is Dictionary:
			lines.insert(index + offset + 1, follow_up[offset].duplicate(true))
	_record()
	return true

func advance() -> bool:
	if not active:
		return false
	if has_choices():
		return true
	index += 1
	if index >= lines.size():
		active = false
		return false
	_record()
	return true

func _record() -> void:
	history.append(current().duplicate(true))

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
	choice_history.clear()
	lines = []
	key = ""
	index = 0
	active = false
