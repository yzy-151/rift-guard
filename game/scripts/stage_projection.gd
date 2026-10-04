extends RefCounted
## Planar campaign board. Simulation coordinates remain authoritative, including
## routes and terrain. A translation reserves the original HUD margins without
## skew, depth scaling or a different horizontal/vertical distance unit.
const DEPTH_START: float = 140.0
const DEPTH_SIZE: float = 440.0
const SCREEN_OFFSET := Vector2(0.0, -24.0)
static func depth_scale(_point: Vector2) -> float:
	return 1.0
static func project(point: Vector2) -> Vector2:
	return point + SCREEN_OFFSET
static func unproject(point: Vector2) -> Vector2:
	return point - SCREEN_OFFSET
static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([project(rect.position), project(Vector2(rect.end.x, rect.position.y)), project(rect.end), project(Vector2(rect.position.x, rect.end.y))])
