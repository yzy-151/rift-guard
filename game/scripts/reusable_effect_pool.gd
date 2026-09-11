extends RefCounted

var available: Array[Dictionary] = []
var acquired := 0
var reused := 0
var released := 0
var capacity := 384

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
	released += 1
	if available.size() < capacity:
		available.append(item)

func live_count() -> int:
	return maxi(0, acquired - released)

func stats() -> Dictionary:
	return {"acquired":acquired,"reused":reused,"released":released,"live":live_count(),"available":available.size(),"capacity":capacity}
