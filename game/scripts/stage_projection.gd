extends RefCounted
## World coordinates stay authoritative. All screen picking uses the inverse.
const DEPTH_START: float = 140.0
const DEPTH_SIZE: float = 440.0
static func depth_scale(point: Vector2) -> float:
	return 0.65 + 0.35 * (point.y - DEPTH_START) / DEPTH_SIZE
static func project(point: Vector2) -> Vector2:
	var t: float = (point.y - DEPTH_START) / DEPTH_SIZE
	return Vector2(640.0 + (point.x - 640.0) * (0.65 + 0.35 * t) + 50.0 * (1.0 - t), 150.0 + 445.0 * t)
static func unproject(point: Vector2) -> Vector2:
	var t: float = (point.y - 150.0) / 445.0
	var factor: float = maxf(0.1, 0.65 + 0.35 * t)
	return Vector2(640.0 + (point.x - 640.0 - 50.0 * (1.0 - t)) / factor, DEPTH_START + DEPTH_SIZE * t)
static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([project(rect.position), project(Vector2(rect.end.x, rect.position.y)), project(rect.end), project(Vector2(rect.position.x, rect.end.y))])
