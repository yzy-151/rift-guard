extends RefCounted
const Regions = preload("res://scripts/home_regions.gd")
var region := "base"
var visited: Dictionary = {"base":true}
var completed: Dictionary = {}
var save_path := ""
func _init(path: String = "") -> void:
	save_path = path
	if path.is_empty() or not FileAccess.file_exists(path): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary: return
	for key: Variant in parsed.get("visited", []):
		if Regions.INFO.has(str(key)): visited[str(key)] = true
	var authored := Regions.stories()
	for key: Variant in parsed.get("completed", []):
		if authored.has(str(key)): completed[str(key)] = true
	var saved_region := str(parsed.get("region", "base"))
	if visited.has(saved_region): region = saved_region
func enter(destination: String) -> bool:
	var connected := false
	for portal: Dictionary in Regions.portals(region):
		if str(portal.id) == destination: connected = true
	if not connected: return false
	region = destination
	visited[region] = true
	save()
	return true
func complete_scene(key: String) -> bool:
	if not Regions.stories().has(key): return false
	completed[key] = true
	save()
	return true
func save() -> bool:
	if save_path.is_empty(): return true
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"version":1, "region":region, "visited":visited.keys(), "completed":completed.keys()}))
	return true
