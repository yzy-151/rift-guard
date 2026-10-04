extends RefCounted
## V91 staged effects. All footprints are supplied by the simulation; decoration
## is deterministic and never feeds back into damage or random-number state.
const Comic = preload("res://scripts/comic_combat_vfx.gd")
const Danger = preload("res://scripts/danger_telegraph.gd")
const INK := Color("#160f21")
const PAPER := Color("#fff5de")
const GOLD := Color("#ffbf61")
const RED := Color("#ff4867")
const MINT := Color("#8bffd6")
const VIOLET := Color("#bc8aff")

static func edge(v, points: PackedVector2Array, color: Color, alpha: float, width: float = 2.0, fill: float = 0.0) -> void:
	if points.size() < 3 or alpha <= 0.005:
		return
	if fill > 0.0 and not Geometry2D.triangulate_polygon(points).is_empty():
		v.draw_colored_polygon(points, Color(color, fill * alpha))
	var closed := points.duplicate()
	closed.append(points[0])
	v.draw_polyline(closed, Color(color, alpha), width, true)

static func circle(v, center: Vector2, radius: float, color: Color, alpha: float, width: float = 2.0) -> void:
	if radius > 0.1 and alpha > 0.005:
		v.draw_arc(center, radius, 0, TAU, 48, Color(color, alpha), width, true)

static func ellipse(v, center: Vector2, radii: Vector2, color: Color, alpha: float, width: float = 2.0) -> void:
	var points := PackedVector2Array()
	for i in 48: points.append(center + Vector2(cos(i * TAU / 48) * radii.x, sin(i * TAU / 48) * radii.y))
	edge(v, points, color, alpha, width)

static func arrow(v, p: Vector2, direction: Vector2, length: float, color: Color, alpha: float) -> void:
	var tail := p - direction * minf(length, 44)
	v.draw_line(tail, p, Color(color, alpha * 0.22), 5.5, true)
	v.draw_line(tail.lerp(p, 0.18), p, Color(color, alpha), 2.8, true)
	v.draw_line(tail.lerp(p, 0.4), p + direction * 3, Color(Color.WHITE, alpha), 1.2, true)
	Comic.light(v, p, Vector2(32, 17), color, alpha * 0.8, direction.angle())

static func warning(v, enemy: Dictionary) -> void:
	var kind := str(enemy.get("kind", ""))
	if not kind.begins_with("boss_"):
		return
	var remaining := float(enemy.get("special_warning", 0))
	var total := maxf(0.01, float(enemy.get("special_warning_total", 1)))
	var t := clampf(1.0 - remaining / total, 0, 1)
	var source: Vector2 = v.world_to_screen(enemy.pos) + Vector2(0, -58)
	var color: Color = {"boss_01": VIOLET, "boss_02": Color("#f68ace"), "boss_03": Color("#c4faff"), "boss_galio": GOLD}.get(kind, RED)
	# Converging silhouettes are tied to the actual wind-up, not wall-clock phase.
	if kind == "boss_01":
		for i in 4:
			var d := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
			var p := source + d * lerpf(68, 25, t)
			Comic.polygon(v, PackedVector2Array([p + d * 12, p + d.orthogonal() * 5, p - d * 15, p - d.orthogonal() * 5]), Color(color, 0.35 + t * 0.65), 2)
		v.draw_line(source - Vector2(0, 24 + t * 14), source + Vector2(0, 24 + t * 14), Color(PAPER, t * 0.75), 1.6, true)
	elif kind == "boss_02":
		for i in 6:
			var angle := float(i) * TAU / 6 + t * 2
			var p := source + Vector2.from_angle(angle) * (42 - t * 12)
			v.draw_circle(p, 3 + t * 3, Color(color, 0.5 + t * 0.5))
	elif kind == "boss_03":
		for side in [-1.0, 1.0]:
			var wing := PackedVector2Array([source + Vector2(side * 5, -12), source + Vector2(side * (45 - t * 20), -38), source + Vector2(side * 18, 10), source])
			Comic.polygon(v, wing, Color(color if side < 0 else VIOLET, 0.32 + t * 0.55), 2)
	else:
		for side in [-1.0, 1.0]:
			for feather in 3:
				var p := source + Vector2(side * (25 + feather * 11), -feather * 9)
				v.draw_line(p, p + Vector2(side * (19 + 18 * t), -24 - 12 * t), Color(GOLD, 0.3 + t * 0.7), 5 - feather, true)
	# Small readable fuse at the caster complements the exact red ground boundary.
	var fuse := source + Vector2(-25, -48)
	v.draw_rect(Rect2(fuse, Vector2(50, 4)), INK)
	v.draw_rect(Rect2(fuse, Vector2(50 * t, 4)), Color(color, 0.9))

static func boss_release(v, e: Dictionary) -> bool:
	var kind := str(e.kind)
	var age := float(e.total) - float(e.life)
	var t := clampf(age / 0.32, 0, 1)
	var fade := 1.0 - smoothstep(0.12, 1.0, t)
	var center: Vector2 = v.world_to_screen(Vector2(e.get("pos", Vector2.ZERO)))
	if kind in ["rift_overhead", "rift_storm", "rift_laser"]:
		var radius := float(e.get("radius", 92))
		if kind == "rift_laser":
			for target in e.get("targets", [e.get("target", e.pos)]):
				var finish: Vector2 = v.world_to_screen(Vector2(target))
				var normal := (finish - center).normalized().orthogonal()
				var beam := Danger.capsule_points(v, Vector2(e.pos), Vector2(target), radius)
				if t < 0.1: edge(v, beam, VIOLET, fade * 0.35, 1, 0.025)
				for strand in [-1.0, 0.0, 1.0]:
					Comic.lightning(v, center + normal * radius * strand * 0.55, finish + normal * radius * strand * 0.55, VIOLET, fade, t, int(strand + 2), 1.3)
				Comic.impact(v, finish, minf(1, age / 0.28), 1.3, VIOLET, 23)
		elif kind == "rift_overhead":
			for point in e.get("points", [e.pos]):
				var p: Vector2 = v.world_to_screen(Vector2(point))
				var slit := p + Vector2(0, -165)
				Comic.polygon(v, PackedVector2Array([slit + Vector2(-28 * fade, 0), slit + Vector2(0, -24), slit + Vector2(28 * fade, 0), slit + Vector2(0, 24)]), Color(VIOLET, fade), 2)
				if t < 0.6:
					Comic.lightning(v, slit, p, VIOLET, fade, t, 29, 1.8)
				Comic.impact(v, p, minf(1, age / 0.28), 1.65, VIOLET, 31)
				fracture(v, p, radius, t, VIOLET, fade)
		else:
			for i in 8:
				var d := Vector2.from_angle(i * TAU / 8)
				var p := center + d * radius * minf(1, t * 2.5)
				Comic.lightning(v, center + d * 18, p, VIOLET, fade * 0.7, t, i, 0.8)
				Comic.polygon(v, PackedVector2Array([p + d * 14, p + d.orthogonal() * 6, p - d * 8, p - d.orthogonal() * 6]), Color(VIOLET, fade), 2)
			Comic.impact(v, center, minf(1, age / 0.28), 2.0, VIOLET, 41)
			fracture(v, center, radius, t, VIOLET, fade)
		return true
	if kind in ["slime_bounce_hit", "slime_court_final", "slime_reflux"]:
		var points: Array = e.get("points", [e.pos])
		var radius := float(e.get("radius", 100))
		for point in points:
			var p: Vector2 = v.world_to_screen(Vector2(point))
			var color: Color = v._slime_element_color(str(e.get("element", "hydro")))
			if kind in ["slime_court", "slime_court_final"]:
				color = Color("#ec8ddd")
			var splash := PackedVector2Array()
			for i in 48:
				var a := i * TAU / 48
				var r: Vector2 = v.sim.ability_area_screen_radii(Vector2(point), radius) * minf(1, 0.2 + t * 3) * (0.83 + 0.12 * sin(a * 9 + t * 4))
				splash.append(p + v.ground_visual_offset() + Vector2(cos(a) * r.x, sin(a) * r.y))
			if age < 0.08: edge(v, splash, color, fade * 0.55, 1.2, 0.025)
			Comic.impact(v, p, minf(1, age / 0.28), 1.55, color, 35)
			for i in (5 if v.reduced_effects else 10):
				var d := Vector2.from_angle(i * TAU / 10 + 0.4)
				var droplet := p + d * radius * (0.2 + minf(1, t * 1.5) * 0.7) - Vector2(0, sin(t * PI) * (24 + i % 3 * 12))
				var size := (5 + i % 3 * 2) * fade
				v.draw_circle(droplet, size, Color(color, fade))
				v.draw_circle(droplet + Vector2(-1, -2), size * 0.28, Color(PAPER, fade))
		return true
	if kind in ["rift_orb_hit", "slime_glob_hit", "slime_court_hit", "kindred_arrow_hit"]:
		var color: Color = VIOLET if kind.begins_with("rift") else (Color("#d9ffff") if kind.begins_with("kindred") else v._slime_element_color(str(e.get("element", "hydro"))))
		Comic.impact(v, center - Vector2(0, 18), minf(1, age / 0.28), 1.15, color, 56)
		return true
	if kind == "kindred_wolf_strike":
		for hit in e.get("hit_positions", []):
			var p: Vector2 = v.world_to_screen(Vector2(hit)) - Vector2(0, 24)
			Comic.impact(v, p, minf(1, age / 0.28), 0.85, Color("#d9ffff"), 61)
			if age < 0.16:
				for claw in 3:
					var offset := Vector2((claw - 1) * 6, 0)
					v.draw_line(p + offset - Vector2(6, 12), p + offset + Vector2(4, 10), Color(VIOLET, fade), 1.2, true)
		return true
	if kind in ["galio_entrance", "galio_punch", "galio_durand"]:
		if age >= 0.38: return true
		if kind == "galio_punch":
			var source: Vector2 = v.world_to_screen(Vector2(e.get("source", e.pos)))
			var finish: Vector2 = v.world_to_screen(Vector2(e.get("finish", e.pos)))
			var side := (finish - source).normalized().orthogonal()
			for streak in 3:
				var offset := side * (streak - 1) * 11
				v.draw_line(source.lerp(finish, minf(1, age / 0.25)) + offset, finish + offset, Color(GOLD, fade * 0.40), 2.0, true)
			Comic.impact(v, finish, minf(1, age / 0.28), 1.5, GOLD, 65)
		else:
			Comic.burst(v, center, minf(1, age / 0.38), 1.8, GOLD, 67, v.reduced_effects)
			fracture(v, center, float(e.get("radius", 180)) * 0.60, t, GOLD, fade * 0.60)
		return true
	return false

static func tactic(_v, _e: Dictionary) -> void:
	pass # Brute attacks use only the original animation, including spin attacks.

static func boss_finish(v, e: Dictionary) -> void:
	var kind := str(e.kind)
	if not kind.begins_with("kindred_") and not kind.begins_with("galio_"):
		return
	var t := clampf(1.0 - float(e.life) / maxf(0.01, float(e.total)), 0, 1)
	var fade := 1.0 - smoothstep(0.24, 1, t)
	var p: Vector2 = v.world_to_screen(Vector2(e.get("pos", Vector2.ZERO)))
	if kind in ["galio_entrance", "galio_punch", "galio_durand"]:
		fracture(v, p, float(e.get("radius", 96)), t, GOLD, fade)
		for side in [-1.0, 1.0]:
			for i in 4:
				var root := p + Vector2(side * (20 + i * 12 + t * 58), -12 - i * 8 - sin(t * PI) * 30)
				var tip := root + Vector2(side * 24, -27) * fade
				Comic.polygon(v, PackedVector2Array([root, root + Vector2(side * 12, 6), tip]), Color(GOLD, fade * 0.8), 2)
	elif kind in ["kindred_dance", "kindred_dread", "kindred_arrow_hit", "kindred_respite_end"]:
		for i in 5:
			var angle := float(i) * TAU / 5 + t * 0.8
			var d := Vector2.from_angle(angle)
			var point := p + d * (14 + t * 72) - Vector2(0, t * 20)
			Comic.polygon(v, PackedVector2Array([point - d * 10, point + d.orthogonal() * 4, point + d * 15, point - d.orthogonal() * 3]), Color(PAPER if i % 2 == 0 else VIOLET, fade), 1.6)

static func fracture(v, p: Vector2, radius: float, t: float, color: Color, alpha: float) -> void:
	for i in (5 if v.reduced_effects else 9):
		var d := Vector2.from_angle(i * TAU / 9 + 0.2)
		var n := d.orthogonal()
		var reach := minf(1, t * 4) * radius
		var path := PackedVector2Array([p + d * 12, p + d * reach * 0.36 + n * 8, p + d * reach * 0.64 - n * 5, p + d * reach * 0.94])
		v.draw_polyline(path, Color(color, alpha * 0.8), 1.6, true)

static func support(v, e: Dictionary) -> bool:
	var kind := str(e.kind)
	var t := clampf(1.0 - float(e.life) / maxf(0.01, float(e.total)), 0, 1)
	var fade := 1.0 - smoothstep(0.56, 1, t)
	var p: Vector2 = v.world_to_screen(Vector2(e.get("pos", Vector2.ZERO)))
	if kind == "barrage":
		var radius := float(e.get("radius", 105))
		var radii: Vector2 = v.sim.support_barrage_screen_radii(Vector2(e.pos), radius)
		if t < 0.065: ellipse(v, p, radii, RED, fade * 0.4, 1)
		for i in (8 if v.reduced_effects else 18):
			var delay := float(i % 6) * 0.065
			var flight := clampf((t - delay) / 0.28, 0, 1)
			if flight <= 0: continue
			var angle := float(i) * 2.399
			var land := p + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * sqrt(float(i + 1) / 19.0) * 0.9
			var start := land + Vector2(-96, -230)
			var head := start.lerp(land, flight)
			arrow(v, head, Vector2(96, 230).normalized(), 35, RED, fade)
			if flight >= 1:
				var age := t - delay - 0.28
				if age < 0.22: Comic.impact(v, land, age / 0.22, 0.6, GOLD, i)
		return true
	if kind == "crossfire":
		var edges: Array[Vector2] = v._crossfire_field_edges(float(e.get("lane_y", p.y)), float(e.get("lane_half_width", 58)))
		if t < 0.07: edge(v, PackedVector2Array(edges), GOLD, fade * 0.25, 1, 0.02)
		for side in 2:
			for i in (3 if v.reduced_effects else 6):
				var lane := (float(i) + 0.5) / 6
				var a: Vector2 = edges[0].lerp(edges[3], lane) if side == 0 else edges[1].lerp(edges[2], lane)
				var b: Vector2 = edges[1].lerp(edges[2], lane) if side == 0 else edges[0].lerp(edges[3], lane)
				var progress := clampf(t * 1.8 - float(i % 3) * 0.13, 0, 1)
				arrow(v, a.lerp(b, progress), (b - a).normalized(), 68, GOLD if side == 0 else Color("#8edfff"), fade)
		return true
	if kind in ["fireball_fall", "fireball_impact"]:
		var radius := float(e.get("radius", 160))
		var radii: Vector2 = v.sim.ability_area_screen_radii(Vector2(e.pos), radius)
		p += v.ground_visual_offset()
		if kind == "fireball_fall":
			for mark in 4:
				var angle := mark * PI * 0.5
				var boundary := p + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
				var tangent := Vector2(-sin(angle), cos(angle))
				v.draw_line(boundary - tangent * 6, boundary + tangent * 6, Color(GOLD, 0.24 + t * 0.36), 1.2, true)
			Comic.light(v, p, Vector2(90, 50), GOLD, 0.18 + t * 0.22)
			var meteor := p + Vector2(-180, -280) * (1 - t * t)
			var d := Vector2(180, 280).normalized()
			var side := d.orthogonal()
			Comic.light(v, meteor, Vector2(84, 67), GOLD, 0.92, d.angle())
			# Two curved tapering flames connect to a rounded irregular hot core.
			for flame in 2:
				var rim_a := PackedVector2Array()
				var rim_b := PackedVector2Array()
				var sign_value := -1.0 if flame == 0 else 1.0
				for step in 14:
					var f := float(step) / 13.0
					var bend := sign_value * sin(f * PI) * (18 + flame * 9)
					var trail := meteor - d * (7 + f * (88 + flame * 18)) + side * bend
					var half_width := pow(1 - f, 1.6) * (8 - flame * 2)
					rim_a.append(trail + side * half_width)
					rim_b.append(trail - side * half_width)
				rim_b.reverse()
				rim_a.append_array(rim_b)
				v.draw_colored_polygon(rim_a, Color(GOLD if flame == 0 else RED, 0.66 - flame * 0.14))
			var flame_head := PackedVector2Array()
			var hot_core := PackedVector2Array()
			for point_index in 13:
				var angle := point_index * TAU / 13.0
				var variation := sin(point_index * 2.13 + t * 22)
				flame_head.append(meteor + Vector2.from_angle(angle) * (15 + variation * 2.3))
				hot_core.append(meteor + Vector2.from_angle(angle) * (8.5 + variation * 1.1))
			v.draw_colored_polygon(flame_head, Color("#ffa33e"))
			v.draw_colored_polygon(hot_core, Color("#fffce4"))
			Comic.light(v, meteor - d * 2, Vector2.ONE * 24, Color.WHITE, 1.4)
		else:
			var age := float(e.total) - float(e.life)
			Comic.burst(v, p, minf(1, age / 0.42), 1.55, GOLD, 17, v.reduced_effects)
			if age < 0.24:
				for chip in 7:
					var dir := Vector2.from_angle(chip * 2.399)
					var travel := 1 - pow(1 - age / 0.24, 3)
					var dust := p + dir * (10 + travel * (28 + chip % 3 * 10)) + Vector2(0, age * age * 80)
					var size := (4 + chip % 2 * 2) * (1 - age / 0.24)
					v.draw_colored_polygon(PackedVector2Array([dust - dir * size, dust + dir.orthogonal() * size * 0.6, dust + dir * size]), Color("#d2a681", 0.7 * (1 - age / 0.24)))
		return true
	if kind == "support_heal":
		for id in e.get("hero_ids", []):
			if int(id) < 0 or int(id) >= v.sim.heroes.size(): continue
			var hero: Dictionary = v.sim.heroes[int(id)]
			var foot: Vector2 = v.world_to_screen(hero.pos)
			var source: Vector2 = v.world_to_screen(Vector2(100, 365)) if not v.sim.endless_mode else foot + Vector2(-90, -45)
			var arrival := clampf(t / 0.4, 0, 1)
			var path := PackedVector2Array()
			for i in 24:
				var f := float(i) / 23 * arrival
				path.append(source.lerp(foot, f) - Vector2(0, sin(f * PI) * 50))
			v.draw_polyline(path, Color(MINT, fade * 0.8), 2.4, true)
			Comic.star(v, path[-1], 9 * fade, Color(PAPER, fade), t * 3, 4)
			if arrival >= 1:
				circle(v, foot, 22 + sin(t * PI) * 9, MINT, fade, 2)
				for i in 3:
					var cross := foot + Vector2((i - 1) * 18, -18 - fposmod(t * 80 + i * 19, 54))
					v.draw_line(cross - Vector2(4, 0), cross + Vector2(4, 0), Color(MINT, fade), 3, true)
					v.draw_line(cross - Vector2(0, 4), cross + Vector2(0, 4), Color(MINT, fade), 3, true)
		return true
	if kind == "finale":
		var field: Rect2 = v.ENDLESS_PLAYFIELD_SCREEN
		for band in 3:
			var progress := clampf(t * 2.7 - band * 0.16, 0, 1)
			var head := field.position.x + field.size.x * progress
			var y := field.position.y + field.size.y * (0.25 + band * 0.25)
			v.draw_line(Vector2(maxf(field.position.x, head - 230), y), Vector2(head, y), Color(RED, fade * 0.4), 11, true)
			v.draw_line(Vector2(maxf(field.position.x, head - 140), y), Vector2(head, y), Color(PAPER, fade * 0.8), 2.4, true)
			Comic.star(v, Vector2(head, y), 18 * fade, Color(GOLD, fade), PI * 0.25, 4)
		for index in mini(20, v.sim.enemies.size()):
			var target: Vector2 = v.world_to_screen(Vector2(v.sim.enemies[index].pos))
			Comic.star(v, target - Vector2(0, 20), 19 * fade, Color(GOLD, fade), PI * 0.25, 4)
		return true
	return false

static func geometry(v, data: Dictionary, color: Color, alpha: float, impact: bool = false) -> void:
	if str(data.get("shape", "")) == "ring":
		var center: Vector2 = v.world_to_screen(Vector2(data.target)) + v.ground_visual_offset()
		var outer: Vector2 = v.sim.ability_area_screen_radii(Vector2(data.target), float(data.radius))
		var inner: Vector2 = v.sim.ability_area_screen_radii(Vector2(data.target), float(data.get("inner_radius", float(data.radius) * 0.28)))
		for i in 48:
			var a := Vector2.from_angle(i * TAU / 48)
			var b := Vector2.from_angle((i + 1) * TAU / 48)
			v.draw_colored_polygon(PackedVector2Array([center + a * outer, center + b * outer, center + b * inner, center + a * inner]), Color(color, alpha * 0.055))
		ellipse(v, center, outer, color, alpha, 2)
		ellipse(v, center, inner, color, alpha * 0.72, 1.6)
		return
	for polygon in data.get("polygons", []):
		var screen := PackedVector2Array()
		for point in polygon: screen.append(v.world_to_screen(Vector2(point)))
		edge(v, screen, color, alpha, 2.3 if impact else 1.8, 0.095 if impact else 0.045)
		if impact and screen.size() > 2:
			for i in range(0, screen.size(), maxi(1, screen.size() / 8)):
				Comic.star(v, screen[i], 5 * alpha, Color(PAPER, alpha), float(i), 4)

static func release_geometry(v, e: Dictionary) -> void:
	var data: Dictionary = e.geometry
	var age := float(e.total) - float(e.life)
	var color: Color = v.element_color(str(e.get("element", "none")))
	if str(e.kind) == "presentation_cast":
		var source: Vector2 = v.world_to_screen(Vector2(data.get("origin", e.pos))) - Vector2(0, 30)
		Comic.light(v, source, Vector2.ONE * 40, color, 0.35)
		return
	if age < 0.075:
		geometry(v, data, color, (1 - age / 0.075) * 0.38, true)
	if age >= 0.28: return
	var t := age / 0.28
	for polygon in data.get("polygons", []):
		if polygon.size() < 3: continue
		var center := Vector2.ZERO
		for value in polygon: center += Vector2(value)
		center /= polygon.size()
		for i in (3 if v.reduced_effects else 5):
			var sample := center.lerp(Vector2(polygon[i % polygon.size()]), 0.25 + float(i % 3) * 0.2)
			if not v.sim.is_in_skill_geometry(data, sample): continue
			Comic.impact(v, v.world_to_screen(sample), t, 0.5, color, i + int(center.x))
	if str(e.kind) != "attack_geometry": identity(v, e)

static func zone(v, field: Dictionary) -> void:
	var data: Dictionary = field.geometry
	var kind := str(field.kind)
	var color: Color = {"storm_field":Color("#687fff"), "cryo_field":Color("#70e5ff"), "frozen_forest":Color("#90e9ff"), "renewing_breeze":MINT, "saki_lanes":Color("#e881ea"), "burning_ground":GOLD, "columbia_tide_ring":Color("#40bcff"), "hydro_field":Color("#39baff")}.get(kind, MINT)
	var fade := minf(1, float(field.get("life", 1)) / 0.65)
	# Sparse local floor lighting and motifs describe the live area without a box.
	for polygon in data.get("polygons", []):
		if polygon.size() < 3: continue
		var center := Vector2.ZERO
		for point in polygon: center += Vector2(point)
		center /= polygon.size()
		for i in (5 if v.reduced_effects else 12):
			var index := posmod(i * 7, polygon.size())
			var sample: Vector2 = center.lerp(Vector2(polygon[index]), 0.32 + float(i % 4) * 0.18)
			if not v.sim.is_in_skill_geometry(data, sample): continue
			var p: Vector2 = v.world_to_screen(sample)
			var beat := fposmod(v.clock * 0.48 + i * 0.173, 1.0)
			var shimmer := sin(beat * PI) * fade
			if i % 3 == 0: Comic.light(v, p, Vector2(82, 44), color, shimmer * 0.22)
			if kind == "storm_field":
				if beat < 0.1: Comic.lightning(v, p - Vector2(8, 36), p, color, fade * (1 - beat / 0.1), beat, i, 0.52)
			elif kind in ["frozen_forest", "cryo_field"]:
				for ray in 3:
					var d := Vector2.from_angle(ray * PI / 3 + i)
					v.draw_line(p - d * 6, p + d * 6, Color(color.lightened(0.45), shimmer * 0.7), 1.0, true)
				var h := 8 + i % 4 * 5
				v.draw_colored_polygon(PackedVector2Array([p - Vector2(3, 0), p - Vector2(1, h), p + Vector2(4, -h * 0.6), p + Vector2(3, 0)]), Color(color, fade * 0.45))
				v.draw_line(p - Vector2(1, h), p, Color(Color.WHITE, shimmer * 0.55), 1, true)
			elif kind in ["saki_lanes", "burning_ground"]:
				var note := p - Vector2(0, beat * 17)
				v.draw_circle(note, 2.0, Color(color.lightened(0.45), shimmer))
				v.draw_line(note + Vector2(1.5, 0), note + Vector2(1.5, -10), Color(color.lightened(0.7), shimmer), 1.2, true)
			elif kind in ["hydro_field", "columbia_tide_ring"]:
				var path := PackedVector2Array()
				for step in 10: path.append(p + Vector2(step * 3 - 14, sin(step * 0.4 + v.clock * 2 + i) * 3))
				v.draw_polyline(path, Color(color.lightened(0.4), shimmer * 0.65), 1.2, true)
				v.draw_circle(p - Vector2(0, beat * 14), 1.4, Color(Color.WHITE, shimmer * 0.7))
			else:
				v.draw_arc(p - Vector2(0, beat * 10), 6 + beat * 4, -2.4, 0.8, 12, Color(color, shimmer * 0.7), 1.2, true)

static func identity(v, e: Dictionary) -> void:
	var id := str(e.get("character_id", "traveler"))
	var t := clampf(1.0 - float(e.life) / maxf(0.01, float(e.total)), 0, 1)
	var fade := 1.0 - smoothstep(0.04, 0.36, float(e.total) - float(e.life))
	if fade <= 0: return
	var p: Vector2 = v.world_to_screen(Vector2(e.pos)) - Vector2(0, 36)
	var color: Color = v.element_color(str(e.get("element", "none")))
	match id:
		"hero_01", "hero_03": # tide singer / salon: paired tidal crests
			for side in [-1.0, 1.0]:
				v.draw_arc(p + Vector2(side * 15, 0), 17 + t * 12, -2.7 if side < 0 else -0.4, 0.4 if side < 0 else 2.7, 20, Color(color, fade), 3, true)
			Comic.star(v, p - Vector2(0, 21), 9 * fade, Color(PAPER, fade), 0, 4)
		"hero_02", "hero_10": # wind healers: rising feathers
			for i in 5:
				var q := p + Vector2((i - 2) * 14, -sin(t * PI) * 24 - abs(i - 2) * 6)
				Comic.polygon(v, PackedVector2Array([q, q + Vector2(-5, -14), q + Vector2(5, -28), q + Vector2(4, -8)]), Color(MINT, fade), 1.5)
		"hero_04": # Roxy: angular thunder rune
			Comic.lightning(v, p - Vector2(28, 38), p + Vector2(25, 18), Color("#97bbff"), fade, t, 42, 1.2)
		"hero_06": # Amiya: black diamond / pink fracture
			for i in 3:
				var q := p + Vector2((i - 1) * 18, -i % 2 * 12)
				Comic.polygon(v, PackedVector2Array([q - Vector2(0, 28), q + Vector2(7, 0), q + Vector2(0, 20), q - Vector2(7, 0)]), Color("#dfa4ee", fade), 2)
		"hero_07": # Sakiko: an actual musical staff and notes
			for i in 5: v.draw_line(p + Vector2(-34, (i - 2) * 6), p + Vector2(34, (i - 2) * 6), Color(color, fade * 0.5), 1, true)
			for i in 3:
				var note := p + Vector2((i - 1) * 20, sin(t * 5 + i) * 10)
				v.draw_circle(note, 4, Color(PAPER, fade))
				v.draw_line(note + Vector2(3, 0), note + Vector2(3, -19), Color(color, fade), 2, true)
		"hero_08": # Emilia: sixfold frost
			for i in 6:
				var d := Vector2.from_angle(i * TAU / 6)
				v.draw_line(p, p + d * (18 + t * 18), Color("#b6f6ff", fade), 2, true)
				v.draw_line(p + d * 16, p + d * 22 + d.orthogonal() * 6, Color(PAPER, fade), 2, true)
		"hero_13": # Gwen: crossing scissors, pointed handles
			for side in [-1.0, 1.0]:
				var d := Vector2(side * (0.35 + t * 0.5), -1).normalized()
				arrow(v, p + d * 27, d, 48, MINT, fade)
				circle(v, p - d * 24, 7, MINT, fade, 2)
		_: Comic.star(v, p, (24 + t * 15) * fade, Color(GOLD, fade), t * 0.7, 4)
