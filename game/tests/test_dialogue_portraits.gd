extends SceneTree

const PortraitCatalog = preload("res://scripts/dialogue_portrait_catalog.gd")
const DialoguePanel = preload("res://scripts/dialogue_panel.gd")

func _initialize() -> void:
	var catalog = PortraitCatalog.new()
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue_portraits.json"))
	var portraits: Dictionary = parsed.get("portraits", {})
	var files: Array = parsed.get("files", [])
	var valid := true
	if files.size() != 29 or portraits.size() != 8:
		print("Unexpected catalog size: ", files.size(), " / ", portraits.size())
		valid = false
	var checked := 0
	for speaker: String in portraits:
		var expressions: Dictionary = portraits[speaker]
		for expression: String in expressions:
			var expected: String = str(expressions[expression])
			var actual: String = catalog.resolve_line({"speaker": speaker, "expression": expression, "text": ""})
			if actual != expected:
				print("Wrong expression: ", speaker, " / ", expression, " -> ", actual)
				valid = false
			if not ResourceLoader.exists(expected):
				print("Missing resource: ", expected)
				valid = false
			elif not load(expected) is Texture2D:
				print("Not a texture: ", expected)
				valid = false
			checked += 1
	var fallback: String = catalog.resolve_line({"speaker": "希露菲", "portrait": "res://assets/characters/sequences/hero_02/portrait.png"})
	if fallback != "res://assets/characters/sequences/hero_02/portrait.png":
		print("Wrong missing-art fallback: ", fallback)
		valid = false
	var cold: String = catalog.resolve_line({"speaker": "丰川祥子", "text": "她冷声说：先集合。"})
	if cold != str(portraits["丰川祥子"]["冷淡"]):
		print("Wrong cold expression: ", cold)
		valid = false
	var surprise: String = catalog.resolve_line({"speaker": "芙宁娜", "text": "她突然停住脚步。"})
	if surprise != str(portraits["芙宁娜"]["惊讶"]):
		print("Wrong surprise expression: ", surprise)
		valid = false
	valid = valid and DialoguePanel != null
	print("DIALOGUE PORTRAITS: %d expressions; %s" % [checked, "PASS" if valid else "FAIL"])
	quit(0 if valid else 1)