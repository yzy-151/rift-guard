extends RefCounted

# The model owns integer cells only; the home panel owns animation and audio.
const ROOM_DATA := "res://data/home_grid_rooms.json"

var rooms: Dictionary = {}
var room: Dictionary = {}
var room_id: String = ""
var player := Vector2i.ZERO
var blocks: Array[Vector2i] = []
var enemies: Array[Dictionary] = []
var keys: Array[Vector2i] = []
var spikes: Array[Vector2i] = []
var has_key := false
var steps_remaining := 0
# 0: spikes are raised. 1: spikes are retracted.
var phase := 0
var failed := false
var won := false
var history: Array = []
var blocked_cells: Array[Vector2i] = []


func _init() -> void:
	if not FileAccess.file_exists(ROOM_DATA):
		push_error("Home grid room data is missing.")
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOM_DATA))
	if parsed is Dictionary and parsed.get("rooms") is Dictionary:
		rooms = parsed["rooms"].duplicate(true)
	else:
		push_error("Home grid room data is invalid.")


func load_room(id: String) -> bool:
	if not rooms.has(id) or not rooms[id] is Dictionary:
		return false
	room_id = id
	room = rooms[id].duplicate(true)
	blocked_cells.clear()
	restart()
	return true


func restart() -> void:
	if room.is_empty():
		return
	player = _cell(room.get("spawn", [0, 0]))
	blocks = _cells(room.get("blocks", []))
	keys = _cells(room.get("keys", []))
	spikes = _cells(room.get("spikes", []))
	enemies.clear()
	for value in room.get("enemies", []):
		var enemy: Dictionary = value.duplicate(true)
		enemy["pos"] = _cell(enemy.get("pos", [0, 0]))
		enemy["hp"] = maxi(1, int(enemy.get("hp", 2)))
		enemies.append(enemy)
	has_key = false
	steps_remaining = maxi(0, int(room.get("steps", 0)))
	phase = 0
	failed = false
	won = false
	history.clear()


func is_floor(cell: Vector2i) -> bool:
	var grid: Array = room.get("grid", [])
	if cell.y < 0 or cell.y >= grid.size():
		return false
	var row: String = str(grid[cell.y])
	return cell.x >= 0 and cell.x < row.length() and row.substr(cell.x, 1) != "#"


func step(direction: Vector2i) -> Dictionary:
	var event := _event("blocked")
	if room.is_empty() or failed or won:
		event["reason"] = "finished" if failed or won else "no_room"
		return event
	if absi(direction.x) + absi(direction.y) != 1:
		event["reason"] = "invalid_direction"
		return event
	var target := player + direction
	if not is_floor(target):
		event["kind"] = "wall"
		return event
	if target in blocked_cells:
		event["reason"] = "resident_or_facility"
		return event
	var portal := _portal_at(target)
	if str(room.get("kind", "puzzle")) != "hub" and not portal.is_empty() and bool(portal.get("requires_key", false)) and not has_key:
		event["reason"] = "key_required"
		return event
	var enemy_index := _enemy_index(target)
	if enemy_index >= 0:
		_save_turn()
		var enemy: Dictionary = enemies[enemy_index]
		var hp := int(enemy.get("hp", 2)) - 1
		enemy["hp"] = hp
		if hp <= 0:
			enemies.remove_at(enemy_index)
		event["kind"] = "kick"
		event["enemy_pos"] = target
		event["enemy_hp"] = maxi(0, hp)
		event["enemy_removed"] = hp <= 0
		return _finish_turn(event)
	if target in blocks:
		var destination := target + direction
		if not is_floor(destination) or destination in blocks or destination in blocked_cells or _enemy_index(destination) >= 0:
			event["reason"] = "cannot_push"
			return event
		_save_turn()
		blocks[blocks.find(target)] = destination
		event["kind"] = "push"
		event["block_from"] = target
		event["block_to"] = destination
	else:
		_save_turn()
		event["kind"] = "move"
	player = target
	event["to"] = player
	event["moved"] = true
	return _finish_turn(event)


func wait_turn() -> Dictionary:
	var event := _event("blocked")
	if room.is_empty() or failed or won:
		event["reason"] = "finished" if failed or won else "no_room"
		return event
	_save_turn()
	event["kind"] = "wait"
	return _finish_turn(event)


func undo() -> bool:
	if history.is_empty():
		return false
	var snapshot: Dictionary = history.pop_back()
	player = snapshot["player"]
	blocks.assign(snapshot["blocks"])
	enemies.assign(snapshot["enemies"].duplicate(true))
	keys.assign(snapshot["keys"])
	has_key = bool(snapshot["has_key"])
	steps_remaining = int(snapshot["steps_remaining"])
	phase = int(snapshot["phase"])
	_update_outcome()
	return true


func _finish_turn(event: Dictionary) -> Dictionary:
	var damage := 0
	if phase == 0 and player in spikes:
		damage = 2
	event["trap_damage"] = damage
	event["step_cost"] = 1 + damage
	if int(room.get("steps", 0)) > 0:
		steps_remaining = maxi(0, steps_remaining - 1 - damage)
	if player in keys:
		keys.erase(player)
		has_key = true
		event["key_collected"] = true
		if str(event["kind"]) == "move":
			event["kind"] = "key"
	phase = 1 - phase
	_update_outcome()
	if won:
		event["action_kind"] = event["kind"]
		event["kind"] = "exit"
		event["exit_id"] = str(_portal_at(player).get("id", "exit"))
		event["next_room"] = str(room.get("next_room", ""))
		event["encounter"] = room.get("encounter", {}).duplicate(true)
	elif failed:
		event["action_kind"] = event["kind"]
		event["kind"] = "failed"
	event["phase"] = phase
	event["steps_remaining"] = steps_remaining
	event["won"] = won
	event["failed"] = failed
	return event


func _update_outcome() -> void:
	var portal := _portal_at(player)
	won = str(room.get("kind", "puzzle")) != "hub" and not portal.is_empty() and (has_key or not bool(portal.get("requires_key", false)))
	# Reaching an open door succeeds, including on the final affordable move.
	failed = not won and int(room.get("steps", 0)) > 0 and steps_remaining <= 0


func _save_turn() -> void:
	history.append({"player": player, "blocks": blocks.duplicate(), "enemies": enemies.duplicate(true), "keys": keys.duplicate(), "has_key": has_key, "steps_remaining": steps_remaining, "phase": phase})


func _event(kind: String) -> Dictionary:
	return {"kind": kind, "moved": false, "from": player, "to": player, "trap_damage": 0, "step_cost": 0, "key_collected": false, "phase": phase, "steps_remaining": steps_remaining, "won": won, "failed": failed}


func _enemy_index(cell: Vector2i) -> int:
	for index in enemies.size():
		if enemies[index].get("pos", Vector2i.ZERO) == cell:
			return index
	return -1


func _portal_at(cell: Vector2i) -> Dictionary:
	for value in room.get("portals", []):
		if _cell(value.get("pos", [0, 0])) == cell:
			return value
	return {}


func _cell(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	return Vector2i.ZERO


func _cells(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value in values:
		result.append(_cell(value))
	return result
