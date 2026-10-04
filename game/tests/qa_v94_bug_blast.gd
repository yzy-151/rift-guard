extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const Tactics = preload("res://scripts/enemy_tactics.gd")
const CENTER := Vector2(640, 360)
var checks := 0
var failures := 0

class DrawRecorder extends RefCounted:
	var sim
	var clock := 0.5
	var reduced_effects := true
	var light_layer = null
	var polygons: Array[PackedVector2Array] = []
	func world_to_screen(point: Vector2) -> Vector2: return point + Vector2(17, -24)
	func ground_visual_offset() -> Vector2: return Vector2(0, 8) if sim.endless_mode else Vector2.ZERO
	func _ability_ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
		var points := PackedVector2Array()
		for i in 65: points.append(center + Vector2.from_angle(TAU * i / 64.0) * radii)
		return points
	func draw_colored_polygon(points: PackedVector2Array, _color: Color) -> void: polygons.append(points)
	func draw_polyline(_points, _color, _width, _antialias) -> void: pass
	func draw_line(_from, _to, _color, _width, _antialias) -> void: pass
	func draw_circle(_center, _radius, _color) -> void: pass
	func draw_rect(_rect, _color) -> void: pass

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1
func arena(endless: bool):
	var s = Sim.new(9404, true)
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	s.reset_stage("stage_endless" if endless else "stage_02", squad, 9404)
	s.start()
	s.enemies.clear(); s.enemy_lookup.clear(); s.terrain_features.clear(); s.events.clear()
	s.crystal_shield = 0
	for h: Dictionary in s.heroes:
		h.deployed = true; h.hp = 10000.0; h.max_hp = h.hp; h.armor = 0
		h.damage_reduction = 0; h.invulnerable_timer = 0; h.passive = {}; h.card_levels = {}
	return s
func furthest_polygon_point(view: DrawRecorder, center: Vector2) -> float:
	var extent := 0.0
	for polygon: PackedVector2Array in view.polygons:
		for point: Vector2 in polygon: extent = maxf(extent, point.distance_to(center))
	return extent
func boundary_case(endless: bool, volatile: bool, direction: Vector2) -> void:
	var label := ("endless" if endless else "campaign") + (" volatile" if volatile else " ordinary") + (" horizontal" if direction == Vector2.RIGHT else " vertical")
	var s = arena(endless)
	var radii: Vector2 = s.ability_area_screen_radii(CENTER, 80.0)
	var ground_offset := Vector2(0, 8) if endless else Vector2.ZERO
	# Campaign distances are world units. Endless maps the same canonical
	# 79/81/120 boundary probes into its unchanged ground projection.
	for i in 3: s.heroes[i].pos = CENTER + ground_offset + direction * radii * ([79.0, 81.0, 120.0][i] / 80.0)
	var bug: Dictionary = s.spawn_enemy(CENTER, "originium_bug")
	bug.pos = CENTER; bug.armor = 0; bug.shield = 0; bug.affixes = ["volatile"] if volatile else []
	if endless: s._apply_endless_scaling(bug, 4)
	var expected_damage := float(bug.damage) * 1.5
	s.apply_hit(bug, 1000000, "", 0)
	check(s.pending_impacts.size() == 1 and s.pending_impacts[0].kind == "bug_blast", label + " queues exactly one blast")
	if s.pending_impacts.is_empty(): return
	var impact: Dictionary = s.pending_impacts[0]
	check(is_equal_approx(float(impact.radius), 80.0), label + " authoritative radius is 80")
	check(is_equal_approx(float(impact.life), 1.0) and is_equal_approx(float(impact.damage), expected_damage), label + " preserves one-second fuse and scaled damage")
	check(s.heroes.all(func(h: Dictionary) -> bool: return h.hp == 10000), label + " death has no immediate damage")
	var view := DrawRecorder.new(); view.sim = s
	Tactics.draw_ground(view)
	var warning_matches := not view.polygons.is_empty()
	if warning_matches:
		for point: Vector2 in view.polygons[0]:
			var displacement := point - view.world_to_screen(CENTER) - ground_offset
			warning_matches = warning_matches and is_equal_approx((displacement / radii).length(), 1.0)
	check(warning_matches, label + " drawn warning exactly matches damage projection")
	s._pending_impact_tick(0.99)
	check(s.heroes.all(func(h: Dictionary) -> bool: return h.hp == 10000), label + " allows dodge throughout warning")
	s._pending_impact_tick(0.02)
	check(is_equal_approx(10000.0 - float(s.heroes[0].hp), expected_damage), label + " canonical 79 receives unchanged damage")
	check(s.heroes[1].hp == 10000, label + " canonical 81 stays safe")
	check(s.heroes[2].hp == 10000, label + " canonical 120 stays safe")
	var blasts: Array = s.events.filter(func(event: Dictionary) -> bool: return bool(event.get("bug_blast", false)))
	check(s.pending_impacts.is_empty() and blasts.size() == 1 and is_equal_approx(float(blasts[0].radius), 80.0), label + " resolves once and forwards radius to flash")
	s._pending_impact_tick(2.0)
	check(is_equal_approx(10000.0 - float(s.heroes[0].hp), expected_damage), label + " cannot damage twice")

func run() -> void:
	for endless: bool in [false, true]:
		for volatile: bool in [false, true]:
			for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN]: boundary_case(endless, volatile, direction)
	var s = arena(false)
	var view := DrawRecorder.new(); view.sim = s
	var effect := {"pos":CENTER, "total":0.85, "life":0.60, "radius":80.0}
	Tactics.draw_blast(view, effect)
	var large := furthest_polygon_point(view, view.world_to_screen(CENTER))
	view.polygons.clear(); effect.radius = 40.0
	Tactics.draw_blast(view, effect)
	var small := furthest_polygon_point(view, view.world_to_screen(CENTER))
	check(large > 30.0 and large < 95.0, "80-radius flash stays proportionate to its footprint")
	check(small > 0.0 and large / small > 1.8 and large / small < 2.2, "flash scales from the authoritative event radius")
	print("V94 BUG BLAST checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
