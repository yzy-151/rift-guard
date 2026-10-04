extends SceneTree

const FlatProjection = preload("res://scripts/stage_projection.gd")
const FlatArt = preload("res://scripts/flat_stage_art.gd")
const Sim = preload("res://scripts/combat_simulation.gd")
var failures: Array[String] = []
var checks := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: ", message)

func _initialize() -> void:
	var playfield := Rect2(16, 88, 1248, 490)
	for y in [140.0, 250.0, 360.0, 470.0, 580.0]:
		for x in [40.0, 340.0, 640.0, 940.0, 1240.0]:
			var point := Vector2(x, y)
			var screen: Vector2 = FlatProjection.project(point)
			expect(FlatProjection.unproject(screen).is_equal_approx(point), "picking round trip at " + str(point))
			expect(is_equal_approx(FlatProjection.depth_scale(point), 1.0), "equal actor scale at " + str(point))
			expect(playfield.has_point(screen), "world remains inside battle playfield at " + str(point))
			expect((FlatProjection.project(point + Vector2(30, 0)) - screen).is_equal_approx(Vector2(30, 0)), "horizontal movement is unskewed at " + str(point))
			expect((FlatProjection.project(point + Vector2(0, 30)) - screen).is_equal_approx(Vector2(0, 30)), "vertical movement is unskewed at " + str(point))
	var center := Vector2(640, 360)
	for index in range(32):
		var circle_point := center + Vector2.from_angle(index * TAU / 32.0) * 125.0
		expect(is_equal_approx(FlatProjection.project(circle_point).distance_to(FlatProjection.project(center)), 125.0), "circular world geometry stays circular " + str(index))
	var rectangle := Rect2(100, 200, 120, 80)
	var polygon: PackedVector2Array = FlatProjection.polygon(rectangle)
	expect(polygon.size() == 4, "terrain footprint retains four corners")
	expect((polygon[1] - polygon[0]).is_equal_approx(Vector2(120, 0)), "terrain top edge keeps authoritative width")
	expect((polygon[2] - polygon[1]).is_equal_approx(Vector2(0, 80)), "terrain side edge keeps authoritative height")
	check_terrain_footprints()
	check_trap_timing()
	if failures.is_empty(): print("PASS: %d flat projection, picking, circular geometry, terrain and timer assertions" % checks)
	quit(0 if failures.is_empty() else 1)

func check_terrain_footprints() -> void:
	var sim: RefCounted = Sim.new(827, true)
	var squad: Array[String] = ["traveler"]
	for stage_index in range(1, 9):
		sim.reset_stage("stage_%02d" % stage_index, squad, 827)
		for feature: Dictionary in sim.terrain_features:
			var rects: Array[Rect2] = FlatArt.feature_rects(feature)
			expect(not rects.is_empty(), "authored feature renders: " + str(feature.id))
			var grid: Array = feature.get("grid_cells", [])
			if not grid.is_empty():
				expect(rects.size() == grid.size(), "sparse terrain keeps claimed grid count: " + str(feature.id))
			else:
				expect(rects[0].is_equal_approx(sim._feature_collision_rect(feature)), "footprint uses collision scale/offset: " + str(feature.id))
			for rect: Rect2 in rects:
				expect(sim._feature_contains(feature, rect.get_center()), "visible terrain center is an actual gameplay feature: " + str(feature.id))
	# A hole inside a feature's enclosing area must never become a filled tile.
	var sparse := {"area": Rect2(40, 140, 180, 40), "grid_cells": [Rect2(40, 140, 60, 40), Rect2(160, 140, 60, 40)]}
	var footprint: Array[Rect2] = FlatArt.feature_rects(sparse)
	expect(not footprint.any(func(rect: Rect2) -> bool: return rect.has_point(Vector2(130, 160))), "grid holes remain visibly walkable")

func check_trap_timing() -> void:
	var trap := {"interval": 2.8, "timer": 2.8, "clock": 0.0}
	expect(is_zero_approx(FlatArt.timer_progress(trap)), "trap starts uncharged after an actual pulse")
	trap.timer = 0.7
	expect(is_equal_approx(FlatArt.timer_progress(trap), 0.75), "trap fills from the actual remaining timer")
	trap.clock = 3000.0
	expect(is_equal_approx(FlatArt.timer_progress(trap), 0.75), "cosmetic clock cannot change the trap warning")
	trap.timer = 0.0
	expect(is_equal_approx(FlatArt.timer_progress(trap), 1.0), "trap is charged exactly when timer reaches zero")
	trap.timer = -0.1
	expect(is_equal_approx(FlatArt.timer_progress(trap), 1.0), "timer warning remains bounded after overshoot")
	trap.timer = 2.8
	expect(is_zero_approx(FlatArt.timer_progress(trap)), "timer warning resets with the next damage pulse")

