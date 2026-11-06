extends SceneTree
const Vfx = preload("res://scripts/hero_skill_vfx_20261005.gd")
const Stage = preload("res://scripts/stage_projection.gd")
var checks := 0
var failures := 0

class CanvasAudit extends RefCounted:
	var sim
	var battle_view
	var clock := 1.7
	var reduced_effects := false
	var calls := 0
	var valid := true
	var total_polygons := 0
	var water_blades := 0
	var invalid_polygons: Array[PackedVector2Array] = []
	var widths: Array[float] = []
	func world_to_screen(point: Vector2) -> Vector2:
		if battle_view != null: return battle_view.world_to_screen(point)
		return point if sim.endless_mode else Stage.project(point)
	func reset() -> void:
		calls = 0
		valid = true
		water_blades = 0
		widths.clear()
	func note(points: PackedVector2Array, color: Color, width: float = 0.0) -> void:
		calls += 1
		valid = valid and is_finite(color.a) and color.a >= 0.0 and color.a <= 1.0
		for point: Vector2 in points:
			valid = valid and is_finite(point.x) and is_finite(point.y)
		if width > 0.0: widths.append(width)
	func draw_polyline(points: PackedVector2Array, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
		note(points, color, width)
	func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, _antialiased: bool = false) -> void:
		note(PackedVector2Array([from, to]), color, width)
	func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
		note(points, color)
		total_polygons += 1
		if points.size() == 4 and color.a > .2 and absf(color.r - Vfx.WATER_DEEP.r) < .001 and absf(color.g - Vfx.WATER_DEEP.g) < .001:
			var bounds := Rect2(points[0],Vector2.ZERO)
			for point: Vector2 in points: bounds = bounds.expand(point)
			if bounds.size.y > 11.5 and bounds.size.x < 35.0: water_blades += 1
		var triangles := Geometry2D.triangulate_polygon(points)
		var triangulates := not triangles.is_empty() and triangles.size() % 3 == 0
		valid = valid and triangulates
		if not triangulates: invalid_polygons.append(points.duplicate())
	func draw_circle(point: Vector2, radius: float, color: Color) -> void:
		note(PackedVector2Array([point]), color)
		valid = valid and radius > 0.0
	func draw_arc(point: Vector2, radius: float, _from: float, _to: float, _count: int, color: Color, width: float = 1.0, _antialiased: bool = false) -> void:
		note(PackedVector2Array([point]), color, width)
		valid = valid and radius > 0.0
	func draw_texture_rect(_texture: Texture2D, rect: Rect2, _tile: bool, color: Color) -> void:
		note(PackedVector2Array([rect.position, rect.end]), color)
	func draw_texture_rect_region(texture: Texture2D, rect: Rect2, region: Rect2, color: Color) -> void:
		note(PackedVector2Array([rect.position,rect.end]),color)
		valid = valid and rect.size.x > 0 and rect.size.y >= 50.0 and rect.size.y <= 60.0
		valid = valid and region.position.x >= 0 and region.position.y >= 0 and region.end.x <= texture.get_width() and region.end.y <= texture.get_height()
	func draw_set_transform(point: Vector2, rotation: float = 0.0, scale: Vector2 = Vector2.ONE) -> void:
		valid = valid and is_finite(point.x) and is_finite(point.y) and is_finite(rotation) and is_finite(scale.x) and is_finite(scale.y) and absf(scale.x) > .001 and absf(scale.y) > .001
	func draw_rect(rect: Rect2, color: Color) -> void:
		note(PackedVector2Array([rect.position, rect.end]), color)

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS ", label)
	else:
		failures += 1
		push_error(label)

func _actual_main_fanfare_route() -> Array[Dictionary]:
	var samples: Array[Dictionary] = []
	var app = load("res://main.tscn").instantiate()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false); app.set_physics_process(false)
	await process_frame
	check(not app.qa_storage_path.is_empty(), "actual Main uses isolated QA progress")
	check(app.battle.get_script().get_script_constant_map().get("HeroSkillVfx20261005") == Vfx, "actual BattleView dispatch uses this exact hero helper")
	var squad: Array[String] = ["hero_03", "traveler"]
	app.sim.reset_stage("stage_02",squad,20261005); app.sim.start()
	app.sim.enemies.clear(); app.sim.enemy_lookup.clear(); app.sim.terrain_features.clear()
	for index in app.sim.heroes.size():
		var hero: Dictionary = app.sim.heroes[index]
		hero.deployed = true; hero.pos = Vector2(430+index*140,350); hero.target = hero.pos
		hero.energy = hero.max_energy
	app.sim.drain_events(); app.battle.reset_transients()
	check(app.sim.activate_hero_ultimate(0,Vector2(755,350)), "actual Main Furina ultimate accepts its public cast")
	var batch: Array[Dictionary] = app.sim.drain_events()
	check(batch.any(func(event: Dictionary) -> bool: return event.kind == "ultimate_cast"), "actual cast emits ultimate_cast")
	app.battle.accept_events(batch)
	var probe := CanvasAudit.new(); probe.sim = app.sim; probe.battle_view = app.battle
	var signature_started := false
	var ultimate_impact_seen := false
	var marks: Dictionary = {}
	for tick in 156:
		var dt := 1.0/120.0
		app.sim.elapsed += dt
		app.sim._pending_impact_tick(dt); app.sim._skill_effect_tick(dt)
		batch = app.sim.drain_events()
		for event: Dictionary in batch:
			signature_started = signature_started or event.kind == "signature_start"
			ultimate_impact_seen = ultimate_impact_seen or event.kind == "ultimate_impact"
		app.battle.accept_events(batch); app.battle.advance(dt)
		for zone: Dictionary in app.sim.skill_effects:
			if str(zone.kind) != "hydro_fanfare": continue
			for age in [.08,.18,.32,.60]:
				if marks.has(age) or float(zone.elapsed) < age: continue
				marks[age] = true
				probe.reset(); Vfx.draw_zone(probe,zone)
				check(probe.valid,"actual Main release geometry triangulates at "+str(age))
				check(probe.water_blades >= 8 if age < .5 else probe.water_blades == 0,"actual live zone draws eight solid water blades only during release at "+str(age))
				samples.append({"zone_age":zone.elapsed,"blades":probe.water_blades,"calls":probe.calls,"pending_impacts":app.sim.pending_impacts.size(),"battle_effects":app.battle.effects.size()})
	check(signature_started and not ultimate_impact_seen,"real signature route works without fabricated ultimate_impact")
	check(marks.size() == 4,"actual Main captured every release and persistent checkpoint")
	probe.battle_view = null; probe.sim = null
	app.queue_free(); await process_frame; app = null; await process_frame
	# Let deferred renderer/audio cleanup finish after the real scene is freed.
	await create_timer(.15).timeout
	return samples

func _run() -> void:
	var sim = load("res://scripts/combat_simulation.gd").new()
	var squad: Array[String] = ["traveler", "hero_03", "hero_13"]
	sim.reset_stage("stage_endless", squad, 105)
	sim.start()
	sim.terrain_features.clear()
	for index in sim.heroes.size():
		sim.heroes[index].pos = Vector2(600 + index * 30, 340)
		sim.heroes[index].deployed = true
		sim.heroes[index].invulnerable_timer = 5.0
	var view := CanvasAudit.new()
	view.sim = sim
	check(Vfx.handles_ability(sim.heroes[1], sim.heroes[1].active_skill), "Furina Q is covered")
	check(Vfx.handles_ability(sim.heroes[1], sim.heroes[1].ultimate), "Furina E is covered")
	check(Vfx.handles_ability(sim.heroes[2], sim.heroes[2].active_skill), "Gwen Q is covered")
	check(Vfx.handles_ability(sim.heroes[2], sim.heroes[2].ultimate), "Gwen E is covered")
	check(not Vfx.handles_ability(sim.heroes[0], sim.heroes[0].active_skill), "other characters retain their renderer")
	for endless: bool in [false, true]:
		sim.endless_mode = endless
		for center: Vector2 in [Vector2(400, 230), Vector2(700, 410)]:
			var consistent := true
			for index in 32:
				var angle := float(index) * TAU / 32.0
				var edge := Vfx.ground_point(view, center, 345, angle)
				var foot := view.world_to_screen(center) + Vector2(0, 8)
				var inside := foot.lerp(edge, .997)
				var outside := foot + (edge - foot) * 1.007
				if not endless:
					inside = Stage.unproject(inside)
					outside = Stage.unproject(outside)
				consistent = consistent and sim.is_in_ability_area(center, inside, 345) and not sim.is_in_ability_area(center, outside, 345)
			check(consistent, "actual ellipse boundary matches hit test in " + ("endless" if endless else "campaign") + " at " + str(center))
	sim.endless_mode = true
	for index in [1, 2]:
		for ultimate: bool in [false, true]:
			view.reset()
			var ability: Dictionary = sim.heroes[index].ultimate if ultimate else sim.heroes[index].active_skill
			check(Vfx.draw_preview(view, sim.heroes[index], ability, Vector2(930, 340)), str(ability.kind) + " preview replaces old template")
			check(view.calls > 0 and view.valid, str(ability.kind) + " preview has finite visible primitives")
	sim.run_state.equipped_relics["relic_resonant_core"] = true
	var needle_preview := Vfx.needle_preview_outline(view, sim.heroes[2], sim.heroes[2].ultimate, Vector2(1000, 340))
	check(is_equal_approx(needle_preview[2].x, float(sim.heroes[2].pos.x) + 620.0 * 1.2), "needle preview includes actual 20 percent ultimate relic reach")
	check(is_equal_approx(absf(needle_preview[2].y - needle_preview[3].y), 36.0), "needle preview uses actual narrow 18-unit half width")
	var event_kinds: Array[String] = ["furina_salon_summon_cast", "furina_salon_summon_impact", "furina_hydro_fanfare_cast", "furina_hydro_fanfare_impact", "gwen_thread_shelter_cast", "gwen_thread_shelter_impact", "gwen_needle_barrage_cast", "gwen_needle_barrage_impact", "signature_needle_volley", "signature_needle_hit", "gwen_needle_hit", "signature_salon_hit", "signature_heal", "gwen_shelter_aura", "furina_fanfare_allies"]
	for kind: String in event_kinds:
		var effect := {"kind":kind, "pos":Vector2(800, 340), "caster_pos":Vector2(640, 340), "source":Vector2(640, 340), "radius":260.0, "hero_id":1, "direction":Vector2.RIGHT, "total":.5, "life":.32, "ally_ids":[0, 1, 2], "targets":[Vector2(640, 340)]}
		view.reset()
		check(Vfx.draw_event(view, effect), kind + " consumes legacy dispatch")
		check(view.valid, kind + " draws finite alpha and geometry")
		check(view.widths.is_empty() or view.widths.max() < 8.0, kind + " avoids old coarse strokes")
	var simulation_before := var_to_str(sim.heroes) + var_to_str(sim.skill_effects)
	var zones: Array[Dictionary] = [
		{"kind":"salon_summon", "signature":true, "pos":Vector2(700, 340), "area":260.0, "elapsed":1.0, "life":11.0, "shots":[{"pos":Vector2(740, 340), "source":Vector2(700, 340), "target":Vector2(830, 340), "index":2, "age":.2, "done":false}]},
		{"kind":"hydro_fanfare", "signature":true, "pos":Vector2(640, 340), "area":340.0, "elapsed":2.15, "life":9.85},
		{"kind":"needle_barrage", "signature":true, "pos":Vector2(1100, 340), "source":Vector2(640, 340), "area":620.0, "direction":Vector2.RIGHT, "elapsed":.5, "life":2.7, "shots":[{"pos":Vector2(900, 340), "index":2, "done":false}]},
		{"kind":"needle_barrage", "visual":"gwen_needles", "pos":Vector2(800, 340), "area":170.0, "elapsed":1.0, "life":1.0, "shots":[]},
		{"kind":"hydro_field", "visual":"furina_fanfare", "pos":Vector2(640, 340), "area":340.0, "elapsed":2.1, "life":7.9}
	]
	for zone: Dictionary in zones:
		view.reset()
		check(Vfx.draw_zone(view, zone), str(zone.kind) + "/" + str(zone.get("visual", "")) + " zone replaces legacy dispatch")
		check(view.calls > 0 and view.valid and view.calls < 130, str(zone.kind) + " zone renders bounded finite primitives")
	check(var_to_str(sim.heroes) + var_to_str(sim.skill_effects) == simulation_before, "visual module never changes hero or gameplay zone state")
	view.reset()
	Vfx.draw_zone(view, zones[1])
	var full_calls := view.calls
	view.reduced_effects = true
	view.reset()
	Vfx.draw_zone(view, zones[1])
	check(view.calls < full_calls, "dense/reduced effects lower primitive cost without losing the field")
	view.reduced_effects = false
	view.reset()
	var outside_effect := {"kind":"furina_fanfare_allies", "pos":Vector2(10, 10), "hero_id":-1, "radius":80.0, "total":3.4, "life":3.05, "ally_ids":[0, 1, 2]}
	Vfx.draw_event(view, outside_effect)
	check(view.calls == 0, "Furina bonus marks do not appear on out-of-range allies")
	view.reset()
	check(Vfx.draw_orbit(view, {"visual":"salon", "count":3, "radius":190.0, "life":5.0}, sim.heroes[1]) and view.calls > 0, "legacy salon orbital draws the new water silhouettes")
	check(not Vfx.draw_zone(view, {"kind":"arcane_lance"}) and not Vfx.draw_event(view, {"kind":"signature_black_hit"}), "Amiya and other legacy signature renderers remain delegated")
	var furina: Dictionary = sim.heroes[1]
	var gwen: Dictionary = sim.heroes[2]
	sim._execute_ability_impact(furina, furina.active_skill, Vector2(820, 340), false)
	sim._execute_ability_impact(furina, furina.ultimate, Vector2(furina.pos), true)
	sim._execute_ability_impact(gwen, gwen.ultimate, Vector2(1100, 340), true)
	check(sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "salon_summon"), "actual Furina Q creates a live salon zone")
	check(sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "hydro_fanfare"), "actual Furina E creates a live moving zone")
	check(sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "needle_barrage"), "actual Gwen E creates the live needle shots")
	var real_zone_snapshots: Array[Dictionary] = []
	for index in 20:
		sim._skill_effect_tick(.1)
		for zone: Dictionary in sim.skill_effects:
			if str(zone.kind) in ["salon_summon", "hydro_fanfare", "needle_barrage"]:
				view.reset()
				check(Vfx.draw_zone(view, zone) and view.valid, "actual " + str(zone.kind) + " state renders at " + str(index))
				if index == 10: real_zone_snapshots.append(zone.duplicate(true))
	var needle_zone: Dictionary = sim.skill_effects.filter(func(zone: Dictionary) -> bool: return str(zone.kind) == "needle_barrage")[0]
	check(int(needle_zone.released) == 15, "Gwen live E keeps three volleys of five needles")
	# A large ribbon can self-intersect only after rotating through an ellipse extremum;
	# inspect the complete twelve-second cycle in both coordinate systems.
	for endless: bool in [false,true]:
		sim.endless_mode = endless
		var all_valid := true
		for frame in 360:
			var elapsed := float(frame + 1) / 30.0
			var zone := {"kind":"hydro_fanfare","pos":Vector2(640,340),"area":340.0,"elapsed":elapsed,"life":maxf(.05,12.0-elapsed)}
			view.reset()
			Vfx.draw_zone(view,zone)
			all_valid = all_valid and view.valid
		check(all_valid,"all water curtain polygons triangulate through a full rotation in "+("endless" if endless else "campaign"))
		var release_valid := true
		for frame in 61:
			var age := float(frame)/120.0
			var release_zone := {"kind":"hydro_fanfare","pos":Vector2(640,340),"area":340.0,"elapsed":age,"life":12.0-age}
			view.reset(); Vfx.draw_zone(view,release_zone)
			release_valid = release_valid and view.valid
		check(release_valid,"entire half-second filled wave release triangulates in "+("endless" if endless else "campaign"))
	view.reset(); Vfx.draw_event(view,{"kind":"furina_hydro_fanfare_impact","pos":Vector2(640,340),"radius":340.0,"total":1.5,"life":1.32})
	check(view.calls == 0,"legacy Furina impact cannot duplicate the zone-owned release")
	view.reset(); Vfx.draw_zone(view,{"kind":"hydro_fanfare","pos":Vector2(640,340),"area":340.0,"elapsed":0.0,"life":12.0})
	check(view.valid and view.calls > 0,"live release is visible from zone creation before the persistent fade-in")
	check(view.invalid_polygons.is_empty(),"every emitted filled polygon passes Geometry2D.triangulate_polygon")
	var actual_main_samples := await _actual_main_fanfare_route()
	var report := {"checks":checks, "failures":failures, "polygon_checks":view.total_polygons,"invalid_polygon_count":view.invalid_polygons.size(),"invalid_polygon_samples":view.invalid_polygons.slice(0,3), "scope":"Headless route coverage plus actual Main public cast, pending impact, signature zone tick, BattleView accept_events and exact dispatched helper DrawProbe; true polygon triangulation and no gameplay mutation; screenshots/GIF require root render review", "real_zone_samples":real_zone_snapshots,"actual_main_release_samples":actual_main_samples}
	var path := ProjectSettings.globalize_path("res://../outputs/skills_20261005/hero-vfx-qa.json")
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	view.sim = null
	sim = null
	print("HERO SKILL VFX checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
