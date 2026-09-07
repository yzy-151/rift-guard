extends RefCounted

var thresholds: Array[int] = []

func _init(values: Array) -> void:
	thresholds.assign(values)

func grant(run, amount: int) -> int:
	if amount <= 0:
		return 0
	run.crystal_xp += amount
	var gained := 0
	while run.crystal_level <= thresholds.size() and run.crystal_xp >= thresholds[run.crystal_level - 1]:
		run.crystal_level += 1
		run.pending_level_ups += 1
		gained += 1
	return gained

func consume_choice(run) -> bool:
	if run.pending_level_ups <= 0:
		return false
	run.pending_level_ups -= 1
	return true

func next_threshold(run) -> int:
	if run.crystal_level > thresholds.size():
		return -1
	return thresholds[run.crystal_level - 1]
