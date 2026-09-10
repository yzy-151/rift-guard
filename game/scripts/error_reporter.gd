extends RefCounted

var entries: Array[Dictionary] = []

func record(scope: String, message: String, context: Dictionary = {}) -> void:
	entries.append({"time":Time.get_datetime_string_from_system(),"scope":scope,"message":message,"context":context.duplicate(true)})
	if entries.size() > 100: entries.pop_front()

func flush(path: String = "user://rift-guard-errors.json") -> bool:
	if entries.is_empty(): return true
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"version":25,"errors":entries},"\t"))
	return true
