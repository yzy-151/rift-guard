extends SceneTree
## Run natively for light coordinates and framebuffer evidence. Headless runs
## the warning lifetime/grouping contracts and explicitly skips frame checks.
const Sim = preload("res://scripts/combat_simulation.gd")

class ProbeView extends "res://scripts/battle_view.gd":
	var route_calls: Array[Dictionary] = []
	var captions: Array[Dictionary] = []
	func _draw() -> void:
		route_calls.clear()
		captions.clear()
		super._draw()
	func _draw_route_preview(route: Array, preview: Dictionary, route_id: String = "main") -> void:
		route_calls.append({"route":route.duplicate(), "preview":preview.duplicate(true), "route_id":route_id})
		if DisplayServer.get_name() != "headless": super._draw_route_preview(route, preview, route_id)
	func caption(point: Vector2, value: String, color: Color, size: int = 12) -> void:
		captions.append({"point":point, "text":value})
		super.caption(point, value, color, size)

var view: ProbeView
var checks := 0
var failures: Array[String] = []
var output := "C:/Users/yzy/Desktop/codex/rift-guard/v93-2026-10-04/workshop/visual-contract"
var native := false

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if not output.is_absolute_path(): quit(2); return
	DirAccess.make_dir_recursive_absolute(output)
	create_timer(75.0).timeout.connect(func(): printerr("FAIL visual contract timeout"); quit(2))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frame() -> Image:
	view.queue_redraw()
	await process_frame
	if not native: return null
	await RenderingServer.frame_post_draw
	# The separate additive child redraws from the commands populated by its
	# parent's draw callback. Settle one more frame before reading pixels.
	view.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func warning(wave: int, enemy: String, seconds: float, count: int = 1, units: int = 1) -> Dictionary:
	return {"kind":"route_warning", "route_id":"main", "wave":wave,
		"enemy_id":enemy, "lead_time":seconds, "count":count, "unit_count":units,
		"group_size":7 if enemy == "troop_cannon" else 1,
		"boss":enemy == "boss_01", "flying":false, "value":wave,
		"pos":Vector2(1130,360), "points":[Vector2(1130,360),Vector2(620,360),Vector2(130,360)]}

func warnings() -> void:
	var events: Array[Dictionary] = [warning(1,"grunt",1.0,3,3),
		warning(2,"troop_cannon",3.0,2,14), warning(3,"grunt",4.5,6,6),
		warning(4,"boss_01",2.0)]
	view.accept_events(events)
	check(view.route_previews.size() == 4, "same-route simultaneous waves and enemy groups all survive ingestion")
	if not native:
		view.route_calls.clear()
		view._draw_live_route_previews()
	var image := await frame()
	check(view.route_calls.size() == 1 and view.route_calls[0].preview.entries.size() == 4,
		"four live warnings draw one shared route with all four entries")
	var expected: Array[String] = []
	for preview: Dictionary in view.route_previews.values(): expected.append(view._route_warning_text(preview))
	check(expected.has("02 波 · 炮车编队 ×2组（14敌）"), "cannon warning preserves group count and actual enemy count")
	var grunt_name := str(Sim.Catalog.ENEMIES.grunt.name)
	check(expected.has("01 波 · %s ×3" % grunt_name) and expected.has("03 波 · %s ×6" % grunt_name),
		"same enemy on separate waves retains each wave number and count")
	check(expected.has("04 波 · BOSS · %s" % str(Sim.Catalog.ENEMIES.boss_01.name)), "boss warning retains actual boss name")
	if native:
		var drawn: Array[Dictionary] = view.captions.filter(func(c: Dictionary) -> bool: return c.text in expected)
		check(drawn.size() == 4, "native draw actually emits every simultaneous warning label")
		var spaced := drawn.size() == 4
		for i in range(1,drawn.size()): spaced = spaced and absf(float(drawn[i].point.y)-float(drawn[i-1].point.y)) >= 17.0
		check(spaced, "simultaneous warning labels have separate readable rows")
		image.save_png(output.path_join("simultaneous-warnings.png"))
	view.advance(1.05)
	check(view.route_previews.size() == 3 and not view.route_previews.has("main:1:grunt"), "first warning expires without erasing later same-route warnings")
	view.advance(1.0)
	check(view.route_previews.size() == 2 and view.route_previews.has("main:2:troop_cannon") and view.route_previews.has("main:3:grunt"), "boss warning expires independently of troop and later grunt warnings")
	view.advance(1.0)
	check(view.route_previews.size() == 1 and view.route_previews.has("main:3:grunt"), "troop warning expires at its own lead time")
	view.advance(1.5)
	check(view.route_previews.is_empty(), "all route warning overlays finish after their actual lifetimes")
	view.reset_transients()
	view.position = Vector2.ZERO

func clear_effects() -> void:
	for effect: Dictionary in view.effects: view.effect_pool.release(effect)
	view.effects.clear()
	view.comic_vfx.reset()
	view.shake_trauma = 0.0
	view.position = Vector2.ZERO

func signature_casts() -> void:
	var original = view.sim
	for identity: Array in [["hero_13","gwen_needle_barrage_cast"],["hero_06","amiya_chimera_cast"]]:
		view.sim = Sim.new(9304,true)
		var squad: Array[String] = [str(identity[0])]
		view.sim.reset_stage("stage_02",squad,9304)
		view.sim.start()
		var hero: Dictionary = view.sim.heroes[0]
		hero.deployed = true
		hero.pos = Vector2(420,350)
		hero.target = hero.pos
		hero.energy = hero.max_energy
		view.sim.events.clear()
		check(view.sim.activate_hero_ultimate(0,Vector2(850,350)), str(identity[0]) + " actually starts its ultimate cast")
		view.accept_events(view.sim.drain_events())
		check(view.effects.filter(func(e: Dictionary) -> bool: return e.kind == identity[1]).size() == 1
			and view.effects.all(func(e: Dictionary) -> bool: return e.kind != "presentation_cast"),
			str(identity[0]) + " real ultimate_cast reaches its dedicated signature windup exactly once")
		clear_effects()
	view.sim = original

func changed_pixels(before: Image, after: Image, center: Vector2, radius: int = 86) -> int:
	var changed := 0
	for y in range(maxi(0,int(center.y)-radius), mini(before.get_height(),int(center.y)+radius)):
		for x in range(maxi(0,int(center.x)-radius), mini(before.get_width(),int(center.x)+radius)):
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.12: changed += 1
	return changed

func bursts() -> void:
	# A nonzero camera translation catches both world/screen confusion and the
	# prior local draw_set_transform leak into the separate additive light pass.
	view.sim.endless_mode = true
	view.camera_center = Vector2(960,640)
	var point := Vector2(1110,695)
	var center := view.world_to_screen(point) + Vector2(0,-20)*view.world_depth_scale(point)
	check(center.distance_to(point) > 100.0 and center.distance_to(Vector2.ZERO) > 400.0, "burst fixture uses translated camera and non-origin impact")
	for reduced in [false,true]:
		view.reduced_effects = reduced
		clear_effects()
		var baseline := await frame()
		for kind: String in ["boss_move","boss_summon","boss_phase"]:
			clear_effects()
			var events: Array[Dictionary] = [{"kind":kind,"pos":point,"value":2,"name":"QA"}]
			view.accept_events(events)
			for effect: Dictionary in view.effects: effect.life = float(effect.total)-0.06
			var rendered := await frame()
			var near: Array = view.light_layer.commands.filter(func(light: Dictionary) -> bool: return Vector2(light.point).distance_to(center) < 1.0)
			if reduced:
				check(near.is_empty(), kind + " reduced mode omits additive burst glow")
			else:
				check(near.size() >= 2, kind + " additive glow centers on the actual camera-transformed impact")
			check(changed_pixels(baseline,rendered,center) > 150, kind + (" reduced" if reduced else " normal") + " burst silhouette remains visibly rendered at the impact")
			if kind == "boss_summon": rendered.save_png(output.path_join("burst-reduced.png" if reduced else "burst-normal.png"))
			for effect: Dictionary in view.effects: effect.life = float(effect.total)-0.55
			var expired := await frame()
			check(changed_pixels(baseline,expired,center,72) < 30, kind + (" reduced" if reduced else " normal") + " burst fragments finish within half a second")
	clear_effects()

func run() -> void:
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1280,720)
	view = ProbeView.new()
	view.sim = Sim.new(9304,true)
	var squad: Array[String] = ["traveler"]
	view.sim.reset_stage("stage_02",squad,9304)
	view.sim.enemies.clear()
	view.sim.enemy_lookup.clear()
	view.sim.terrain_features.clear()
	view.sim.events.clear()
	view.sim.stage_runtime.arena_events.clear()
	for hero: Dictionary in view.sim.heroes: hero.deployed = false
	view.selected_id = -1
	root.add_child(view)
	await process_frame
	signature_casts()
	await warnings()
	if native: await bursts()
	else: print("SKIP native framebuffer/light checks: rerun without --headless")
	check(checks == (34 if native else 13), "all scheduled contracts finished without an aborted test coroutine")
	var report := {"checks":checks,"failures":failures,"renderer":DisplayServer.get_name(),"native_render_checks":native}
	FileAccess.open(output.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("V93 VISUAL CONTRACT: %d checks, %d failures" % [checks,failures.size()])
	view.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
