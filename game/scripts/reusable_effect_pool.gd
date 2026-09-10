extends RefCounted

var available: Array[Dictionary] = []
var acquired := 0
var reused := 0

func acquire(payload: Dictionary, lifetime: float) -> Dictionary:
	var item: Dictionary
	if available.is_empty():
		item = {}
	else:
		item = available.pop_back()
		reused += 1
	item.clear()
	item.merge(payload, true)
	item["life"] = lifetime
	item["total"] = lifetime
	acquired += 1
	return item

func release(item: Dictionary) -> void:
	item.clear()
	if available.size() < 384:
		available.append(item)

func stats() -> Dictionary:
	return {"acquired":acquired,"reused":reused,"available":available.size()}
