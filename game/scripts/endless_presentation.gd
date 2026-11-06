extends RefCounted
## Presentation math only: never writes simulation positions or combat values.
const HERO_SCALE := 1.10
const MOB_SCALE := 0.92
const ELITE_KINDS := ["armored", "shielded", "hilichurl_brute", "warder", "troop_cannon"]
const RANGED_KINDS := ["ranged", "troop_ranged", "troop_cannon", "buffer"]

static func camera_bounds(arena: Rect2, viewport_size: Vector2) -> Rect2:
	var half := viewport_size * 0.5
	var minimum := arena.position + half
	var maximum := arena.end - half
	if minimum.x > maximum.x:
		minimum.x = arena.get_center().x
		maximum.x = minimum.x
	if minimum.y > maximum.y:
		minimum.y = arena.get_center().y
		maximum.y = minimum.y
	return Rect2(minimum, maximum - minimum)

static func clamp_camera(center: Vector2, arena: Rect2, viewport_size: Vector2) -> Vector2:
	var bounds := camera_bounds(arena, viewport_size)
	return center.clamp(bounds.position, bounds.end)

static func follow_camera(center: Vector2, leader: Vector2, dt: float, arena: Rect2, viewport_size: Vector2, deadzone: Vector2, response: float) -> Vector2:
	center = clamp_camera(center, arena, viewport_size)
	# Apply the deadzone to the real leader, so a boundary cannot retain an
	# extra deadzone-sized gap and leave the leader outside the visible arena.
	var delta := leader - center
	var excess := Vector2(signf(delta.x) * maxf(0.0, absf(delta.x) - maxf(0.0, deadzone.x)), signf(delta.y) * maxf(0.0, absf(delta.y) - maxf(0.0, deadzone.y)))
	var weight := 1.0 - exp(-maxf(0.0, dt) * maxf(0.0, response))
	return clamp_camera(center + excess * weight, arena, viewport_size)

static func is_elite(unit: Dictionary) -> bool:
	return str(unit.get("kind", "")) in ELITE_KINDS or not unit.get("affixes", []).is_empty()

static func is_ranged(unit: Dictionary) -> bool:
	return str(unit.get("kind", "")) in RANGED_KINDS

static func actor_scale(unit: Dictionary, hero: bool) -> float:
	if hero:
		return HERO_SCALE
	return 1.0 if is_elite(unit) or str(unit.get("kind", "")).begins_with("boss_") else MOB_SCALE

static func actor_transform(point: Vector2, scale_factor: float, foot_offset: float) -> Transform2D:
	# The foot maps to the same point before and after scaling.
	var origin := point + Vector2(0.0, foot_offset * (1.0 - scale_factor))
	return Transform2D(Vector2(scale_factor, 0.0), Vector2(0.0, scale_factor), origin)

static func wall_obscures_hero(wall: Rect2, hero_point: Vector2, sprite_height: float) -> bool:
	if hero_point.y >= wall.end.y:
		return false
	var hero_rect := Rect2(hero_point - Vector2(42.0, sprite_height), Vector2(84.0, sprite_height + 8.0))
	var wall_visual := Rect2(wall.position - Vector2(0.0, 58.0), wall.size + Vector2(0.0, 58.0))
	return wall_visual.intersects(hero_rect)

static func place_label(preferred: Rect2, bounds: Rect2, occupied: Array[Rect2]) -> Rect2:
	var best := Rect2(preferred.position.clamp(bounds.position, bounds.end - preferred.size), preferred.size)
	var best_score := INF
	var offsets: Array[Vector2] = [Vector2.ZERO]
	for step in range(1, 9):
		offsets.append(Vector2(0.0, -step * (preferred.size.y + 4.0)))
		offsets.append(Vector2(0.0, step * (preferred.size.y + 4.0)))
		offsets.append(Vector2(-step * (preferred.size.x + 6.0), 0.0))
		offsets.append(Vector2(step * (preferred.size.x + 6.0), 0.0))
	for offset: Vector2 in offsets:
		var candidate := Rect2((preferred.position + offset).clamp(bounds.position, bounds.end - preferred.size), preferred.size)
		var score := candidate.position.distance_squared_to(preferred.position)
		for other: Rect2 in occupied:
			var overlap := candidate.grow(2.0).intersection(other)
			score += maxf(0.0, overlap.size.x) * maxf(0.0, overlap.size.y) * 10000.0
		if score < best_score:
			best = candidate
			best_score = score
	return best
