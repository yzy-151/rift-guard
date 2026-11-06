extends RefCounted
## World coordinates stay authoritative. All screen picking uses the inverse.
const DEPTH_START: float = 140.0
const DEPTH_SIZE: float = 440.0
const SCREEN_CENTER_X: float = 640.0
const SCREEN_TOP: float = 92.0
const SCREEN_HEIGHT: float = 482.0
const FAR_WIDTH: float = 0.70
const WIDTH_GAIN: float = 0.30
const WIDTH_OVERSCAN: float = 1.03
const FAR_X_OFFSET: float = 10.0
static func depth_scale(point: Vector2) -> float:
	return FAR_WIDTH + WIDTH_GAIN * (point.y - DEPTH_START) / DEPTH_SIZE
static func horizontal_scale(point: Vector2) -> float:
	return depth_scale(point) * WIDTH_OVERSCAN
static func project(point: Vector2) -> Vector2:
	var t: float = (point.y - DEPTH_START) / DEPTH_SIZE
	return Vector2(SCREEN_CENTER_X + (point.x - SCREEN_CENTER_X) * horizontal_scale(point) + FAR_X_OFFSET * (1.0 - t), SCREEN_TOP + SCREEN_HEIGHT * t)
static func unproject(point: Vector2) -> Vector2:
	var t: float = (point.y - SCREEN_TOP) / SCREEN_HEIGHT
	var factor: float = maxf(0.1, FAR_WIDTH + WIDTH_GAIN * t)
	return Vector2(SCREEN_CENTER_X + (point.x - SCREEN_CENTER_X - FAR_X_OFFSET * (1.0 - t)) / (factor * WIDTH_OVERSCAN), DEPTH_START + DEPTH_SIZE * t)
static func polygon(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([project(rect.position), project(Vector2(rect.end.x, rect.position.y)), project(rect.end), project(Vector2(rect.position.x, rect.end.y))])

## Range hit tests and ground art share one projected world-space footprint.
static func ground_center(point: Vector2, screen_offset_y: float = 8.0) -> Vector2:
	return unproject(project(point) + Vector2(0.0, screen_offset_y))
static func ground_world_radii(point: Vector2, screen_radii: Vector2) -> Vector2:
	return Vector2(screen_radii.x / maxf(0.1, horizontal_scale(point)), screen_radii.y * DEPTH_SIZE / SCREEN_HEIGHT)
static func ground_contains(center: Vector2, candidate: Vector2, screen_radii: Vector2, screen_offset_y: float = 8.0) -> bool:
	var origin := ground_center(center, screen_offset_y)
	var radii := ground_world_radii(center, screen_radii)
	var delta := candidate - origin
	return delta.x * delta.x / (radii.x * radii.x) + delta.y * delta.y / (radii.y * radii.y) <= 1.0
static func ground_outline(center: Vector2, screen_radii: Vector2, segments: int = 64, screen_offset_y: float = 8.0) -> PackedVector2Array:
	var origin := ground_center(center, screen_offset_y)
	var radii := ground_world_radii(center, screen_radii)
	var points := PackedVector2Array()
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		points.append(project(origin + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)))
	return points
