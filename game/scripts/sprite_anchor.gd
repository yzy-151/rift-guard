extends RefCounted

const CATALOG_PATH := "res://data/v2/sprite_pivots.json"

static func load_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	return parsed if parsed is Dictionary else {}

static func pivot(catalog: Dictionary, profile_id: String, frame: int, fallback: Vector2) -> Vector2:
	var profile: Dictionary = catalog.get(profile_id, {})
	var pivots: Array = profile.get("pivots", [])
	if pivots.is_empty():
		return fallback
	var value: Variant = pivots[clampi(frame, 0, pivots.size() - 1)]
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback

static func destination(anchor: Vector2, display_size: Vector2, source_size: Vector2, source_pivot: Vector2, facing: float, native_facing: float = 1.0) -> Rect2:
	var horizontal_scale := display_size.x / maxf(1.0, source_size.x)
	var vertical_scale := display_size.y / maxf(1.0, source_size.y)
	var same_direction := facing * native_facing >= 0.0
	var x := anchor.x - source_pivot.x * horizontal_scale if same_direction else anchor.x + source_pivot.x * horizontal_scale
	return Rect2(Vector2(x, anchor.y - source_pivot.y * vertical_scale), Vector2(display_size.x if same_direction else -display_size.x, display_size.y))

static func mapped_pivot(rect: Rect2, source_size: Vector2, source_pivot: Vector2) -> Vector2:
	return rect.position + Vector2(source_pivot.x / maxf(1.0, source_size.x) * rect.size.x, source_pivot.y / maxf(1.0, source_size.y) * rect.size.y)
