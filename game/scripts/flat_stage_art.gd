extends RefCounted
## Campaign-only, orthographic ground art. Every gameplay footprint comes from
## the live terrain and route data; the endless renderer keeps its own artwork.

const Stage = preload("res://scripts/stage_projection.gd")
const EnvironmentArt = preload("res://scripts/battle_environment_art.gd")
const Visual = preload("res://data/stage_visual_profile.tres")
const INK := Color("#15141c")
const BOARD := Rect2(40, 116, 1200, 440)
const FRAME := Rect2(16, 58, 1248, 554)
const HIGH_ICON = preload("res://assets/world/terrain_tiles_v64/pentaGraphic 1.png")
const ATTACK_ICON = preload("res://assets/world/terrain_tiles_v64/huge_vfx0002.png")
const LOW_ICON = preload("res://assets/world/terrain_tiles_v64/PORTAL0012.png")

static func draw_stage(view) -> void:
	if view.sim.endless_mode:
		return
	var stage_id: String = view.sim.current_stage_id
	var palette: Dictionary = Visual.palette(stage_id)
	var floor_color: Color = palette.get("floor", Color("#30333a"))
	var accent: Color = palette.get("accent", Color("#8ecbb1"))
	view._stage_layer("backdrop")
	view.draw_rect(FRAME, INK)
	view.draw_rect(FRAME.grow(-5), floor_color.darkened(0.35))
	view._stage_layer("atmosphere")
	_draw_border(view, stage_id, accent)
	view._stage_layer("ground")
	_draw_floor(view, stage_id, palette)
	view._stage_layer("routes")
	_draw_routes(view, floor_color, accent)
	view._stage_layer("terrain")
	for feature: Dictionary in view.sim.terrain_features:
		_draw_feature(view, feature, accent)
	view._stage_layer("architecture")
	# Perimeter bolts never masquerade as an obstacle in the playable area.
	for x in [28.0, 1252.0]:
		for y in [71.0, 602.0]:
			view.draw_circle(Vector2(x, y), 4.0, INK)
			view.draw_line(Vector2(x - 2, y), Vector2(x + 2, y), accent.darkened(0.2), 1.0, true)

static func draw_foreground(view) -> void:
	if view.sim.endless_mode:
		return
	if not view.debug_stage_layer_order.has("foreground"):
		view._stage_layer("foreground")
	view.draw_rect(FRAME, Color("#0c0b10"), false, 3.0)
	# A thin red frame ties the board to the original Helltaker interface.
	view.draw_line(Vector2(18, 59), Vector2(1262, 59), Color("#9f3244"), 2.0)
	view.draw_line(Vector2(18, 611), Vector2(1262, 611), Color("#9f3244"), 2.0)

static func draw_core(view) -> void:
	if view.sim.endless_mode:
		return
	var point: Vector2 = Stage.project(Vector2(100, 365))
	var tint := Color("#ff6879") if view.base_flash > 0.0 and not view.reduced_effects else Color("#a2efd1")
	view.draw_circle(point, 42.0, INK)
	view.draw_circle(point, 38.0, Color("#28443b"))
	view.draw_arc(point, 37.0, 0.0, TAU, 48, tint.darkened(0.25), 2.0, true)
	for i in 8:
		var direction := Vector2.from_angle(i * TAU / 8.0)
		view.draw_line(point + direction * 31, point + direction * 35, tint, 2.0, true)
	# Keep the original crystal asset as a compact, readable emblem.
	view.draw_texture_rect(view.crystal_texture, Rect2(point + Vector2(-21, -30), Vector2(42, 60)), false, tint)
	var health := clampf(float(view.sim.base_hp) / maxf(1.0, float(view.sim.base_max_hp)), 0.0, 1.0)
	view.draw_rect(Rect2(point + Vector2(-32, 44), Vector2(64, 7)), INK)
	view.draw_rect(Rect2(point + Vector2(-30, 46), Vector2(60 * health, 3)), tint)
	view.caption(point + Vector2(-30, 64), "风神像核心" if view.sim.current_stage_id == "stage_01" else "基地核心", tint, 10)

static func _draw_border(_view, _stage_id: String, _accent: Color) -> void:
	pass # The painted scene supplies architecture instead of decorative UI ticks.

static func _draw_floor(view, stage_id: String, _palette: Dictionary) -> void:
	EnvironmentArt.ground(view,FRAME.grow(-3),EnvironmentArt.theme_for_stage(stage_id))

static func _road_patch(view, points: PackedVector2Array, art: Texture2D) -> void:
	if art==null:
		view.draw_colored_polygon(points,Color("#353641"))
		return
	var uv:=PackedVector2Array()
	for p: Vector2 in points: uv.append((p-FRAME.grow(-3).position)/FRAME.grow(-3).size)
	view.draw_polygon(points,PackedColorArray([Color(1.20,1.18,1.12)]),uv,art)

static func _draw_routes(view, _floor_color: Color, accent: Color) -> void:
	var routes: Dictionary = view.sim.stage_routes()
	var art:=EnvironmentArt.texture(EnvironmentArt.theme_for_stage(view.sim.current_stage_id))
	# Continuous paving reuses the ground's texture coordinates. Shared route
	# segments get exactly the same shade instead of accumulating alpha boxes.
	for route: Array in routes.values():
		var line:=PackedVector2Array()
		for point: Vector2 in route: line.append(Stage.project(point))
		if line.size()>1: view.draw_polyline(line,Color("#20212a"),43,true)
	for route: Array in routes.values():
		for i in range(route.size()-1):
			var a:=Stage.project(route[i])
			var b:=Stage.project(route[i+1])
			var normal:=(b-a).normalized().orthogonal()*20.0
			_road_patch(view,PackedVector2Array([a-normal,b-normal,b+normal,a+normal]),art)
		for point: Vector2 in route:
			var disc:=PackedVector2Array()
			for i in 20: disc.append(Stage.project(point)+Vector2.from_angle(i*TAU/20)*20)
			_road_patch(view,disc,art)
	var marked: Dictionary={}
	for route: Array in routes.values():
		for i in range(route.size()-1):
			var a:=Stage.project(route[i])
			var b:=Stage.project(route[i+1])
			var count:=maxi(1,floori(a.distance_to(b)/112.0))
			for j in count:
				var p:=a.lerp(b,(float(j)+0.5)/count)
				var key:=Vector2i(roundi(p.x/28),roundi(p.y/28))
				if marked.has(key): continue
				marked[key]=true
				_chevron(view,p,(b-a).normalized(),3.5,Color(accent,0.38),1.5)

## Shared with QA: sparse grid features keep holes; non-grid blockers retain
## their authored collision scale and offset rather than the decorative area.
static func feature_rects(feature: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for cell: Variant in feature.get("grid_cells", []):
		if cell is Rect2:
			result.append(cell)
	if not result.is_empty():
		return result
	var area: Rect2 = feature.get("area", Rect2())
	if area.size == Vector2.ZERO:
		return result
	var raw_scale: Array = feature.get("collision_scale", [1.0, 1.0])
	var raw_offset: Array = feature.get("collision_offset", [0.0, 0.0])
	var scale := Vector2(float(raw_scale[0]), float(raw_scale[1])) if raw_scale.size() >= 2 else Vector2.ONE
	var offset := Vector2(float(raw_offset[0]), float(raw_offset[1])) if raw_offset.size() >= 2 else Vector2.ZERO
	var size := area.size * scale
	result.append(Rect2(area.get_center() + offset - size * 0.5, size))
	return result

static func timer_progress(feature: Dictionary) -> float:
	var interval := maxf(0.001, float(feature.get("interval", feature.get("pulse_interval", 4.0))))
	return 1.0 - clampf(float(feature.get("timer", interval)) / interval, 0.0, 1.0)

static func _draw_feature(view, feature: Dictionary, _accent: Color) -> void:
	if str(feature.get("type",""))=="weather":
		_draw_weather(view,feature)
		return
	var theme:=EnvironmentArt.theme_for_stage(view.sim.current_stage_id)
	for world: Rect2 in EnvironmentArt.merge_cells(feature_rects(feature)):
		EnvironmentArt.feature(view,world,feature,theme)

static func _draw_gate(view, rect: Rect2, feature: Dictionary) -> void:
	var center := rect.get_center()
	if str(feature.get("type", "")) != "one_way" and float(feature.get("hp", 0)) <= 0:
		for side in [-1.0, 1.0]:
			var p := center + Vector2(side * (rect.size.x * 0.5 - 9), 0)
			_polygon(view, PackedVector2Array([p + Vector2(-6, -7), p + Vector2(7, -3), p + Vector2(4, 7), p + Vector2(-5, 5)]), Color("#63503f"), INK, 2)
		return
	view.draw_rect(rect, INK)
	view.draw_rect(rect.grow(-3), Color("#654d40"))
	for x in range(9, int(rect.size.x) - 4, 18):
		view.draw_line(rect.position + Vector2(x, 5), Vector2(rect.position.x + x, rect.end.y - 5), Color("#ae8760"), 4)
	view.draw_line(rect.position + Vector2(5, 6), rect.end - Vector2(5, 6), INK, 5, true)
	view.draw_line(Vector2(rect.end.x - 5, rect.position.y + 6), Vector2(rect.position.x + 5, rect.end.y - 6), INK, 5, true)
	var health := clampf(float(feature.get("hp", 0)) / maxf(1, float(feature.get("max_hp", 1))), 0, 1)
	view.draw_rect(Rect2(rect.position + Vector2(5, rect.size.y - 7), Vector2(rect.size.x - 10, 3)), INK)
	view.draw_rect(Rect2(rect.position + Vector2(5, rect.size.y - 7), Vector2((rect.size.x - 10) * health, 3)), Color("#e4bd79"))

static func _draw_weather(view, feature: Dictionary) -> void:
	var area: Rect2 = feature.get("area", Rect2())
	var tint := Color("#91c7bf")
	match str(feature.get("element", "anemo")):
		"pyro": tint = Color("#d69a6f")
		"electro": tint = Color("#b894d7")
		"cryo": tint = Color("#9ad9e6")
		"geo": tint = Color("#d8ba78")
	var rect := Rect2(Stage.project(area.position), area.size)
	# Only corner brackets mark the real weather area, leaving combat readable.
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var direction := (rect.get_center() - Vector2(corner)).sign()
		view.draw_line(corner, Vector2(corner) + Vector2(direction.x * 10, 0), Color(tint, 0.45), 1.5)
		view.draw_line(corner, Vector2(corner) + Vector2(0, direction.y * 10), Color(tint, 0.45), 1.5)

static func _decal_point(index: int) -> Vector2:
	return Vector2(80 + (index * 173) % 1120, 148 + (index * 97) % 366)

static func _chevron(view, center: Vector2, direction: Vector2, size: float, color: Color, width: float) -> void:
	var side := direction.orthogonal()
	view.draw_polyline(PackedVector2Array([center - direction * size * 0.5 + side * size, center + direction * size * 0.5, center - direction * size * 0.5 - side * size]), color, width, true)

static func _diamond(view, center: Vector2, size: Vector2, color: Color) -> void:
	view.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -size.y), center + Vector2(size.x, 0), center + Vector2(0, size.y), center + Vector2(-size.x, 0)]), color)

static func _diamond_outline(view, center: Vector2, size: Vector2, color: Color, width: float) -> void:
	view.draw_polyline(PackedVector2Array([center + Vector2(0, -size.y), center + Vector2(size.x, 0), center + Vector2(0, size.y), center + Vector2(-size.x, 0), center + Vector2(0, -size.y)]), color, width, true)

static func _snowflake(view, center: Vector2, radius: float, color: Color) -> void:
	for i in 3:
		var direction := Vector2.from_angle(i * PI / 3) * radius
		view.draw_line(center - direction, center + direction, color, 1.5, true)

static func _ellipse(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 40:
		points.append(rect.get_center() + Vector2.from_angle(i * TAU / 40) * rect.size * 0.5)
	return points

static func _polygon(view, points: PackedVector2Array, fill: Color, outline: Color, width: float) -> void:
	view.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	view.draw_polyline(closed, outline, width, true)
