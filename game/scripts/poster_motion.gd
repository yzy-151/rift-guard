extends RefCounted

# One finite entrance per surface; reopening always starts from its layout pose.
const STATE := &"poster_motion_state"
const DURATION := 0.42
const FADE_DURATION := 0.14

static func enter(owner: Node, items: Array[Dictionary], reduced := false) -> Tween:
	reset(owner)
	var poses: Array[Dictionary] = []
	var tween := owner.create_tween().set_parallel(true).set_ignore_time_scale(true)
	for item: Dictionary in items:
		var node: Control = item.get("node")
		if not is_instance_valid(node): continue
		var pose := {"node": node, "position": node.position, "scale": node.scale, "pivot": node.pivot_offset, "modulate": node.modulate, "offset": Vector2.ZERO if reduced else item.get("offset", Vector2(0, 24)), "start_scale": 1.0 if reduced else float(item.get("scale", 1.0))}
		poses.append(pose)
		node.pivot_offset = node.size * 0.5
		_sample(0.0, pose)
		var delay := 0.0 if reduced else clampf(float(item.get("delay", 0.0)), 0.0, 0.24)
		tween.tween_method(_sample.bind(pose), 0.0, 1.0, FADE_DURATION if reduced else DURATION).set_delay(delay)
	owner.set_meta(STATE, {"tween": tween, "poses": poses})
	return tween

static func reset(owner: Node) -> void:
	if not owner.has_meta(STATE): return
	var state: Dictionary = owner.get_meta(STATE)
	var tween: Tween = state.get("tween")
	if tween != null and tween.is_valid(): tween.kill()
	for pose: Dictionary in state.get("poses", []):
		var node: Control = pose.node
		if not is_instance_valid(node): continue
		node.position = pose.position
		node.scale = pose.scale
		node.pivot_offset = pose.pivot
		node.modulate = pose.modulate
	owner.remove_meta(STATE)

static func active(owner: Node) -> Tween:
	return owner.get_meta(STATE, {}).get("tween")

static func _sample(progress: float, pose: Dictionary) -> void:
	var node: Control = pose.node
	if not is_instance_valid(node): return
	var t := clampf(progress, 0.0, 1.0)
	var smooth := 1.0 - pow(1.0 - t, 4.0)
	# A small, single settling motion gives paper weight without repeated bouncing.
	var back := 1.0 + 1.65 * pow(t - 1.0, 3.0) + 0.65 * pow(t - 1.0, 2.0)
	node.position = pose.position + Vector2(pose.offset) * (1.0 - back)
	node.scale = Vector2(pose.scale) * lerpf(float(pose.start_scale), 1.0, back)
	var color: Color = pose.modulate
	color.a *= smooth
	node.modulate = color
