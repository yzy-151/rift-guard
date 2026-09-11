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

static func placement(display_size: Vector2, source_size: Vector2, source_pivot: Vector2, facing: float, native_facing: float = 1.0) -> Dictionary:
	var horizontal_scale := display_size.x / maxf(1.0, source_size.x)
	var vertical_scale := display_size.y / maxf(1.0, source_size.y)
	return {
		"rect": Rect2(-Vector2(source_pivot.x * horizontal_scale, source_pivot.y * vertical_scale), display_size.abs()),
		"flip_x": 1.0 if facing * native_facing >= 0.0 else -1.0,
	}

static func mapped_pivot(placement_data: Dictionary, source_size: Vector2, source_pivot: Vector2) -> Vector2:
	var rect: Rect2 = placement_data.rect
	var point := rect.position + Vector2(source_pivot.x / maxf(1.0, source_size.x) * rect.size.x, source_pivot.y / maxf(1.0, source_size.y) * rect.size.y)
	return Vector2(point.x * float(placement_data.flip_x), point.y)
