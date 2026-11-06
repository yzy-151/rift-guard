extends RefCounted
## Stage II only: quiet cut-stone gallery, with physical terrain drawn in actor depth order.
## Every floor seam and obstacle footprint uses the authoritative stage projection.
const Stage = preload("res://scripts/stage_projection.gd")
const FIELD := Rect2(40, 140, 1200, 440)
const INK := Color("#11161d")
const STONE := Color("#333e47")
const SEAM := Color("#242e36")
var ground_commands: Array[Dictionary] = []
var wall_cap_commands: Dictionary = {0: [], 1: []}

func _init() -> void:
	_build_ground()
	_build_wall_caps()

func _polygon(points: PackedVector2Array, color: Color) -> void:
	ground_commands.append({"polygon": points, "color": color})

func _line(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	ground_commands.append({"line": points, "color": color, "width": width})

func _project(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(Stage.project(point))
	return result

func _build_ground() -> void:
	_polygon(Stage.polygon(FIELD), SEAM)
	for row in 11:
		for column in 20:
			var rect := Rect2(40 + column * 60, 140 + row * 40, 60, 40)
			var seed := posmod(column * 37 + row * 61, 19)
			var wear := float(seed) / 18.0
			var tile := STONE.lerp(Color("#3b4650"), wear * 0.32)
			var surface := Stage.polygon(rect.grow(-0.85))
			_polygon(surface, tile)
			_line(PackedVector2Array([surface[3], surface[0], surface[1]]), Color("#71808a", 0.17), 0.8)
			_line(PackedVector2Array([surface[1], surface[2], surface[3]]), Color("#17212b", 0.46), 1.0)
			# Broad, irregular stone grain stays below the silhouette contrast budget.
			var root := rect.position + Vector2(6 + seed % 9, 11 + seed % 7)
			_polygon(_project(PackedVector2Array([root, root + Vector2(25, -3), root + Vector2(41, 8), root + Vector2(19, 12)])), Color("#829399", 0.021 + wear * 0.022))
			if seed % 3 == 0:
				var chip := rect.position + Vector2(44, 29)
				_polygon(_project(PackedVector2Array([chip, chip + Vector2(9, 2), chip + Vector2(7, 6), chip + Vector2(2, 5)])), Color("#19242c", 0.34))
			if seed == 7 or seed == 15:
				var fracture := rect.position + Vector2(42, 2)
				_line(_project(PackedVector2Array([fracture, fracture + Vector2(-5, 9), fracture + Vector2(1, 16), fracture + Vector2(-9, 23)])), Color("#1b2630", 0.62), 0.85)
			if seed % 5 == 1:
				var scratch := rect.position + Vector2(11, 28)
				_line(_project(PackedVector2Array([scratch, scratch + Vector2(15, -2)])), Color("#849299", 0.10), 0.75)
	# A single solid curb joins the arena to its masonry surround.
	for rim: Rect2 in [Rect2(40, 140, 1200, 7), Rect2(40, 573, 1200, 7), Rect2(40, 140, 7, 440), Rect2(1233, 140, 7, 440)]:
		_polygon(Stage.polygon(rim), Color("#59636a"))
	var perimeter := Stage.polygon(FIELD)
	perimeter.append(perimeter[0])
	_line(perimeter, INK, 3.0)
	var inset := Stage.polygon(FIELD.grow(-8))
	inset.append(inset[0])
	_line(inset, Color("#819099", 0.25), 0.9)
	# Edge-only ambient occlusion, never a veil over characters.
	for band in 7:
		var depth := 3.0 + float(band) * 3.0
		for rim: Rect2 in [Rect2(48, 147 + depth, 1184, 3), Rect2(48, 570 - depth, 1184, 3), Rect2(48 + depth, 147, 3, 426), Rect2(1229 - depth, 147, 3, 426)]:
			_polygon(Stage.polygon(rim), Color(0.015, 0.025, 0.035, 0.12 * (1.0 - float(band) / 7.0)))

func _cap_polygon(rect: Rect2) -> PackedVector2Array:
	var world := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var result := PackedVector2Array()
	for point: Vector2 in world:
		result.append(Stage.project(point) - Vector2(0, lerpf(58.0, 81.0, (point.y - 140.0) / 440.0)))
	return result

func _build_wall_caps() -> void:
	for side in 2:
		var left := side == 0
		var start_x := -87.0 if left else 1246.0
		for row in 11:
			for column in 2:
				var cell := Rect2(start_x + column * 60.5, 140 + row * 40, 60.5, 40).grow(-0.60)
				var seed := posmod(row * 13 + column * 37 + side * 7, 11)
				var top := _cap_polygon(cell)
				var tint := Color("#3b4b57").lerp(Color("#4b5b66"), float(seed) * 0.035)
				wall_cap_commands[side].append({"polygon": top, "color": tint})
				wall_cap_commands[side].append({"line": PackedVector2Array([top[3], top[0], top[1]]), "color": Color("#95a6af", 0.16), "width": 0.9})
				wall_cap_commands[side].append({"line": PackedVector2Array([top[1], top[2], top[3]]), "color": Color("#172936", 0.58), "width": 1.0})
				var scuff := _cap_polygon(Rect2(cell.position + Vector2(8, 12), Vector2(35, 13)))
				wall_cap_commands[side].append({"polygon": PackedVector2Array([scuff[0], scuff[1], scuff[2].lerp(scuff[3], .32), scuff[3]]), "color": Color("#aec1c7", 0.038)})
				if seed % 4 == 1:
					wall_cap_commands[side].append({"line": PackedVector2Array([top[1].lerp(top[2], .18), top[1].lerp(top[3], .28), top[1].lerp(top[3], .47)]), "color": Color("#1c303c", 0.55), "width": 0.9})

func backdrop(v) -> void:
	v.draw_rect(Rect2(0, 0, 1280, 720), Color("#131b24"))
	_draw_gallery_surround(v)
	# Recessed walls are outside the playable trapezoid, with repeated piers
	# aligned to the stone curb rather than pasted across the battle floor.
	for side in 2:
		var left := side == 0
		for pier in 4:
			var world_y := 178.0 + float(pier) * 113.0
			var edge := Stage.project(Vector2(40 if left else 1240, world_y))
			var direction := -1.0 if left else 1.0
			var scale := Stage.depth_scale(Vector2(40, world_y))
			var width := 60.0 * scale
			var x := edge.x - width - 8.0 if left else edge.x + 8.0
			var face := Rect2(x, edge.y - 87.0 * scale, width, 91.0 * scale)
			v.draw_rect(face.grow(5), Color("#0b1118"))
			v.draw_rect(face, Color("#25313b"))
			v.draw_rect(Rect2(face.position + Vector2(4, 0), Vector2(8 * scale, face.size.y)), Color("#3f4d58"))
			v.draw_rect(Rect2(face.position + Vector2(14 * scale, 6 * scale), Vector2(width - 22 * scale, face.size.y - 15 * scale)), Color("#1b2631"))
			v.draw_line(face.position + Vector2(5, 1), Vector2(face.end.x - 2, face.position.y + 1), Color("#74808a", 0.45), 1.4, true)
			var capital := Rect2(face.position + Vector2(-5, -5 * scale), Vector2(width + 10, 12 * scale))
			v.draw_rect(capital, Color("#45525c"))
			v.draw_rect(Rect2(face.position.x - 7, face.end.y - 4 * scale, width + 14, 13 * scale), Color("#3e4a55"))
			v.draw_line(Vector2(face.position.x - 7, face.end.y - 4 * scale), Vector2(face.end.x + 7, face.end.y - 4 * scale), Color("#85929a", 0.28), 1, true)
			if pier in [0, 2]:
				var banner_x := x + width * 0.5 + direction * 11 * scale
				var banner_top := edge.y - 63 * scale
				var banner := PackedVector2Array([Vector2(banner_x - 14 * scale, banner_top), Vector2(banner_x + 14 * scale, banner_top), Vector2(banner_x + 14 * scale, banner_top + 54 * scale), Vector2(banner_x, banner_top + 65 * scale), Vector2(banner_x - 14 * scale, banner_top + 54 * scale)])
				v.draw_colored_polygon(banner, Color("#7c243d"))
				v.draw_line(Vector2(banner_x - 12 * scale, banner_top + 1), Vector2(banner_x + 12 * scale, banner_top + 1), Color("#c57b75", 0.55), 1, true)
				var crest := Vector2(banner_x, banner_top + 25 * scale)
				v.draw_colored_polygon(PackedVector2Array([crest + Vector2(0, -10) * scale, crest + Vector2(5, 0) * scale, crest + Vector2(0, 10) * scale, crest + Vector2(-5, 0) * scale]), Color("#d76974", 0.60))
	# Back lintel and foreground foundation use the same curb silhouette.
	var far := Stage.polygon(Rect2(40, 140, 1200, 8))
	var lintel := PackedVector2Array([far[0] + Vector2(0, -23), far[1] + Vector2(0, -23), far[1], far[0]])
	v.draw_colored_polygon(lintel, Color("#24303a"))
	v.draw_line(lintel[0], lintel[1], Color("#4d5961"), 2.0, true)
	for column in 12:
		var notch := far[0].lerp(far[1], float(column) / 12.0)
		v.draw_line(notch - Vector2(0, 21), notch - Vector2(0, 2), Color("#151e27"), 1.5, true)
	v.draw_rect(Rect2(0, 0, 1280, 62), Color("#080b10"))

func _draw_gallery_surround(v) -> void:
	for side in 2:
		var left := side == 0
		var inner_x := 34.0 if left else 1246.0
		var outer_x := -87.0 if left else 1367.0
		var near := Stage.project(Vector2(inner_x, 580))
		var far := Stage.project(Vector2(inner_x, 140))
		var outer_near := Stage.project(Vector2(outer_x, 580))
		var outer_far := Stage.project(Vector2(outer_x, 140))
		var outward := -1.0 if left else 1.0
		var far_lift := Vector2(0, 58)
		var near_lift := Vector2(0, 81)
		# Connect every pier with one continuous wall, cornice and foundation.
		v.draw_colored_polygon(PackedVector2Array([outer_far - far_lift, outer_near - near_lift, outer_near + Vector2(0, 16), outer_far + Vector2(0, 16)]), Color("#1b2631"))
		v.draw_colored_polygon(PackedVector2Array([far - far_lift, near - near_lift, near, far]), Color("#273440"))
		v.draw_colored_polygon(PackedVector2Array([outer_far - far_lift, far - far_lift, near - near_lift, outer_near - near_lift]), Color("#3d4c59"))
		for command: Dictionary in wall_cap_commands[side]:
			if command.has("polygon"): v.draw_colored_polygon(command.polygon, command.color)
			else: v.draw_polyline(command.line, command.color, command.width, true)
		v.draw_line(far - far_lift, near - near_lift, Color("#84929c", 0.40), 1.4, true)
		v.draw_line(far - far_lift + Vector2(0, 7), near - near_lift + Vector2(0, 9), Color("#141e28"), 2.0, true)
		var ledge_far := Stage.project(Vector2(inner_x + outward * 11, 140))
		var ledge_near := Stage.project(Vector2(inner_x + outward * 11, 580))
		v.draw_colored_polygon(PackedVector2Array([ledge_far - Vector2(0, 9), far - Vector2(0, 9), near - Vector2(0, 12), ledge_near - Vector2(0, 12)]), Color("#465460"))
		v.draw_colored_polygon(PackedVector2Array([far - Vector2(0, 9), near - Vector2(0, 12), near + Vector2(0, 3), far + Vector2(0, 3)]), Color("#354551"))
		v.draw_line(far - Vector2(0, 9), near - Vector2(0, 12), Color("#7e909b", 0.37), 1.25, true)
		v.draw_line(far + Vector2(0, 3), near + Vector2(0, 3), Color("#0c1722"), 2.0, true)
		for bay in 3:
			var world_y := 234.5 + float(bay) * 113.0
			var edge := Stage.project(Vector2(inner_x, world_y))
			var scale := Stage.depth_scale(Vector2(inner_x, world_y))
			var center := edge + Vector2(outward * 26 * scale, -27 * scale)
			var arch := PackedVector2Array([Vector2(-23, 30), Vector2(-23, -5), Vector2(-18, -19), Vector2(-9, -27), Vector2(0, -35), Vector2(9, -27), Vector2(18, -19), Vector2(23, -5), Vector2(23, 30)])
			var opening := PackedVector2Array()
			for point: Vector2 in arch: opening.append(center + point * scale)
			v.draw_colored_polygon(opening, Color("#111c29"))
			var border := opening.duplicate(); border.append(border[0])
			v.draw_polyline(border, Color("#455663"), 5.5 * scale, true)
			v.draw_polyline(border, Color("#0b1520"), 1.1, true)
			var recess := opening.duplicate()
			for index in recess.size(): recess[index] = center + (recess[index] - center) * Vector2(0.67, 0.78)
			v.draw_colored_polygon(recess, Color("#182d3f"))
			# Stone tracery, with a blue-grey window reflection deep in the recess.
			v.draw_line(center + Vector2(0, -26) * scale, center + Vector2(0, 21) * scale, Color("#3b4c5b"), 2.0 * scale, true)
			v.draw_line(center + Vector2(-15, 4) * scale, center + Vector2(15, 4) * scale, Color("#334654"), 2.0 * scale, true)
			v.draw_colored_polygon(PackedVector2Array([center + Vector2(-13, -14) * scale, center + Vector2(-6, -20) * scale, center + Vector2(-6, 14) * scale, center + Vector2(-13, 17) * scale]), Color("#678493", 0.10))
			var sill := Rect2(center + Vector2(-27, 26) * scale, Vector2(54, 7) * scale)
			v.draw_rect(sill, Color("#536370"))
			v.draw_line(sill.position, Vector2(sill.end.x, sill.position.y), Color("#8b9ca6", 0.36), 1.0, true)
			# Small missing chips on the cornice and staggered mortar joints.
			var crown := edge - Vector2(outward * 7 * scale, 70 * scale)
			v.draw_colored_polygon(PackedVector2Array([crown, crown + Vector2(outward * 10, -2) * scale, crown + Vector2(outward * 7, 4) * scale, crown + Vector2(outward * 2, 5) * scale]), Color("#1b2a37", 0.74))
		for joint in 15:
			var y := 152.0 + float(joint) * 28.0
			var edge := Stage.project(Vector2(inner_x, y))
			var scale := Stage.depth_scale(Vector2(inner_x, y))
			var seam_start := edge + Vector2(outward * 3 * scale, -18 * scale)
			v.draw_line(seam_start, seam_start + Vector2(outward * 35, 0) * scale, Color("#142430", 0.55), 0.9, true)
			if joint % 3 == 0:
				v.draw_line(seam_start + Vector2(outward * 16, 0) * scale, seam_start + Vector2(outward * 16, -12) * scale, Color("#142430", 0.48), 0.9, true)

func ground(v) -> void:
	for command: Dictionary in ground_commands:
		if command.has("polygon"):
			v.draw_colored_polygon(command.polygon, command.color)
		else:
			v.draw_polyline(command.line, command.color, command.width, true)

func route(v, route_points: Array, route_id: String) -> void:
	var points := PackedVector2Array()
	for point: Vector2 in route_points:
		points.append(v.world_to_screen(point))
	if points.size() < 2: return
	var tint: Color = {"upper": Color("#b29e7e"), "main": Color("#b1858c"), "lower": Color("#829bab")}.get(route_id, Color("#ad9d85"))
	v.draw_polyline(points, Color("#192630", 0.60), 6.6, true)
	v.draw_polyline(points, Color(tint, 0.28), 2.0, true)
	# The entire route is one continuous engraving; sparse arrowheads show direction.
	var total: float = v.surface_renderer.route_length(route_points)
	var count := maxi(2, floori(total / 190.0))
	for index in count:
		var sample: Dictionary = v.surface_renderer.sample_route(route_points, (float(index) + 0.45) / float(count))
		var center: Vector2 = v.world_to_screen(sample.point)
		var direction: Vector2 = (v.world_to_screen(sample.point + sample.tangent * 10.0) - center).normalized()
		var side := direction.orthogonal()
		v.draw_colored_polygon(PackedVector2Array([center + direction * 4.5, center - direction * 3.0 + side * 3.3, center - direction * 1.2, center - direction * 3.0 - side * 3.3]), Color(tint, 0.39))

func terrain(v, feature: Dictionary) -> bool:
	var kind := str(feature.get("type", ""))
	var area: Rect2 = feature.get("area", Rect2())
	if kind == "blocked":
		var footprint := Stage.polygon(area)
		for index in footprint.size(): footprint[index] += Vector2(7, 8)
		v.draw_colored_polygon(footprint, Color(0, 0, 0, 0.30))
		v.draw_colored_polygon(Stage.polygon(area), INK)
		return true # Stone blocks are placed in the actor depth pass.
	if kind == "low_ground":
		var surface := Stage.polygon(area.grow(-1.5))
		v.draw_colored_polygon(surface, Color("#26353c"))
		var edge := surface.duplicate(); edge.append(edge[0])
		v.draw_polyline(edge, Color("#121f29"), 2.2, true)
		# Recessed tide grate is passable, rather than a wall-shaped marsh sticker.
		for row in 4:
			var slat := Rect2(area.position + Vector2(7, 9 + row * 18), Vector2(area.size.x - 14, 5))
			v.draw_colored_polygon(Stage.polygon(slat), Color("#181f2b"))
			var corners := Stage.polygon(slat)
			v.draw_line(corners[0] + Vector2(0, -1), corners[1] + Vector2(0, -1), Color("#647378", 0.32), 1, true)
		var tide := area.grow(-8)
		v.draw_colored_polygon(Stage.polygon(tide), Color("#96334d", 0.16))
		for vein in 3:
			var y := tide.position.y + 10 + vein * 18
			v.draw_line(Stage.project(Vector2(tide.position.x + 12, y)), Stage.project(Vector2(tide.end.x - 16, y)), Color("#b66473", 0.15), 2.0, true)
		v.caption(Stage.project(Vector2(area.get_center().x, area.end.y)) + Vector2(-36, 14), "血潮 · 减速 70%", Color("#be8b91"), 9)
		return true
	if kind == "trap":
		var surface := Stage.polygon(area.grow(-5))
		v.draw_colored_polygon(surface, Color("#262734"))
		var edge := surface.duplicate(); edge.append(edge[0])
		v.draw_polyline(edge, Color("#786a8a", 0.55), 1.4, true)
		var center: Vector2 = v.world_to_screen(area.get_center())
		var pulse: float = 0.75 + sin(v.clock * 3.0) * 0.15
		v.draw_colored_polygon(PackedVector2Array([center + Vector2(1, -12), center + Vector2(-8, 2), center + Vector2(-1, 1), center + Vector2(-3, 11), center + Vector2(8, -3), center + Vector2(1, -2)]), Color("#c5afd8", pulse))
		return true
	return false

func wall_parts(feature: Dictionary) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var area: Rect2 = feature.area
	var columns := maxi(1, ceili(area.size.x / 60.0))
	var rows := maxi(1, ceili(area.size.y / 40.0))
	var size := area.size / Vector2(columns, rows)
	for row in rows:
		for column in columns:
			result.append(Rect2(area.position + Vector2(column, row) * size, size))
	return result

func wall(v, part: Rect2) -> void:
	var base := Stage.polygon(part.grow(-0.4))
	var height := 25.0 * Stage.depth_scale(part.get_center())
	var top := base.duplicate()
	for index in top.size(): top[index] -= Vector2(0, height)
	var front := PackedVector2Array([top[3], top[2], base[2], base[3]])
	var side := PackedVector2Array([top[1], top[2], base[2], base[1]])
	v.draw_colored_polygon(front, Color("#46505b"))
	v.draw_colored_polygon(side, Color("#2e3742"))
	v.draw_colored_polygon(top, Color("#626e78"))
	var outline := top.duplicate(); outline.append(top[0])
	v.draw_polyline(outline, INK, 1.5, true)
	v.draw_line(top[3] + Vector2(2, 0), top[2] - Vector2(2, 0), Color("#a3afb7", 0.57), 1.25, true)
	v.draw_line(base[3], base[2], INK, 1.5, true)
	v.draw_line(top[3], base[3], Color("#1c2530"), 1.0, true)
	v.draw_line(top[2], base[2], Color("#1c2530"), 1.0, true)
	var scratch: Vector2 = top[3].lerp(top[2], 0.63)
	v.draw_polyline(PackedVector2Array([scratch + Vector2(-6, 3), scratch + Vector2(-2, height * 0.40), scratch + Vector2(4, height * 0.54)]), Color("#273340", 0.64), 1.05, true)
	var scuff: Vector2 = top[0].lerp(top[2], 0.43)
	v.draw_colored_polygon(PackedVector2Array([scuff, scuff + Vector2(14, -3), scuff + Vector2(19, 2), scuff + Vector2(4, 5)]), Color("#9facb1", 0.13))

func foreground(v) -> void:
	var a := Stage.project(Vector2(40, 580))
	var b := Stage.project(Vector2(1240, 580))
	v.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, 26), a + Vector2(0, 26)]), Color("#24313b"))
	v.draw_line(a + Vector2(0, 1), b + Vector2(0, 1), Color("#83939c", 0.33), 1.2, true)
	v.draw_line(a + Vector2(0, 25), b + Vector2(0, 25), Color("#080e16"), 2.0, true)
	for notch in 20:
		var point := a.lerp(b, float(notch) / 20.0)
		v.draw_line(point + Vector2(0, 4), point + Vector2(0, 24), Color("#15212c"), 1, true)
