extends RefCounted
## Records actual burst dispatch and renders the real battle scene; no gameplay handlers are replaced.
const Sim = preload("res://scripts/combat_simulation.gd")
const Comic = preload("res://scripts/comic_combat_vfx.gd")
const Flash = preload("res://scripts/impact_flash_vfx.gd")
const Tactics = preload("res://scripts/enemy_tactics.gd")
const CENTER := Vector2(720, 370)
const SMOKE := Color("#520d2b")
const FIRE := Color("#c92839")
var game
var tree: SceneTree
var output := ""
var phase := "after"
var checks := 0
var failures: Array[String] = []
var observations: Array[Dictionary] = []
var unchanged: Dictionary = {}
var native_deaths: Array[Dictionary] = []
var native_lifecycle: Dictionary = {}

class DrawRecorder extends RefCounted:
	var sim
	var reduced_effects := false
	var light_layer = null
	var commands: Array = []
	var polygons: Array[PackedVector2Array] = []
	var colors: Array[Color] = []
	func world_to_screen(point: Vector2) -> Vector2: return point
	func world_depth_scale(_point: Vector2) -> float: return 1.0
	func ground_visual_offset() -> Vector2: return Vector2(0, 8) if sim != null and sim.endless_mode else Vector2.ZERO
	func _render_point_visible(_point: Vector2, _margin: float) -> bool: return true
	func element_color(_element: String) -> Color: return Color("#ffae4d")
	func draw_colored_polygon(points: PackedVector2Array, color: Color) -> void:
		polygons.append(points); colors.append(color); commands.append(["polygon", points, color])
	func draw_polyline(points, color, width, antialias) -> void: commands.append(["polyline", points, color, width, antialias])
	func draw_line(a, b, color, width, antialias) -> void: commands.append(["line", a, b, color, width, antialias])
	func draw_circle(point, radius, color) -> void: commands.append(["circle", point, radius, color])
	func draw_arc(point, radius, start, end, count, color, width, antialias) -> void: commands.append(["arc", point, radius, start, end, count, color, width, antialias])
	func draw_texture_rect(texture, rect, tile, color) -> void: commands.append(["texture", texture.resource_path, rect, tile, color])

func check(ok: bool, label: String) -> void:
	checks += 1
	print("V95 EXPLOSION %s: %s" % ["PASS" if ok else "FAIL", label])
	if not ok: failures.append(label)

func has_color(view: DrawRecorder, target: Color) -> bool:
	return view.colors.any(func(color: Color) -> bool: return color.a > 0.05 and color.to_html(false) == target.to_html(false))

func extent(view: DrawRecorder, center: Vector2, radii := Vector2.ONE) -> float:
	var value := 0.0
	for polygon: PackedVector2Array in view.polygons:
		for point: Vector2 in polygon: value = maxf(value, ((point - center) / radii).length())
	return value

func record(view: DrawRecorder, label: String, age: float) -> void:
	var max_points := 0
	for polygon: PackedVector2Array in view.polygons: max_points = maxi(max_points, polygon.size())
	observations.append({"label": label, "age": age, "commands": view.commands.size(), "polygons": view.polygons.size(),
		"max_polygon_points": max_points, "extent": extent(view, CENTER), "record": var_to_str(view.commands)})

func sample_accent(kind: String, age: float, reduced: bool) -> DrawRecorder:
	var view := DrawRecorder.new(); view.reduced_effects = reduced
	var accents = Comic.new()
	accents.accept(view, {"kind": kind, "pos": CENTER + Vector2(0, 20), "size": 48, "enemy_kind": "slime_pyro"})
	for accent: Dictionary in accents.accents: accent.life = float(accent.total) - age
	accents.draw_accents(view)
	return view

func smoke_is_connected(view: DrawRecorder) -> bool:
	var clouds: Array[PackedVector2Array] = []
	for i in view.polygons.size():
		if view.polygons[i].size() == 24 and view.colors[i].to_html(false) == SMOKE.to_html(false): clouds.append(view.polygons[i])
	if clouds.is_empty() or clouds.size() > 4: return false
	var joined: Array[int] = [0]
	for step in clouds.size():
		for i in clouds.size():
			if i in joined: continue
			for j: int in joined.duplicate():
				if not Geometry2D.intersect_polygons(clouds[i], clouds[j]).is_empty():
					joined.append(i); break
	return joined.size() == clouds.size()

func test_scoped_dispatch() -> void:
	for kind: String in ["death", "death_burst", "enemy_volatile"]:
		for reduced: bool in [false, true]:
			var label := kind + (" reduced" if reduced else " full")
			var ignition := sample_accent(kind, 0.11, reduced)
			check(has_color(ignition, SMOKE), label + " paints thick maroon smoke lobes")
			check(has_color(ignition, FIRE), label + " paints red inner lobes")
			check(ignition.colors.any(func(color: Color) -> bool: return color.r > 0.95 and color.g > 0.85 and color.b > 0.55 and color.a > 0.3), label + " retains a white yellow ignition core")
			var clean := true
			for command: Array in ignition.commands:
				if command[0] in ["line", "arc", "texture"]: clean = false
			check(clean, label + " explosion has no spokes, shard lines or flare sprites")
			var spreading := sample_accent(kind, 0.24, reduced)
			check(smoke_is_connected(spreading), label + " expanding smoke remains overlapping masses instead of a flower ring")
			check(spreading.commands.filter(func(command: Array) -> bool: return command[0] == "polyline").size() <= (1 if reduced else 4), label + " hot curls are limited to the central fire tongues")
			for age: float in [0.025, 0.11, 0.24, 0.40]:
				var view := sample_accent(kind, age, reduced)
				record(view, label, age)
				check(not view.polygons.is_empty() and view.commands.size() <= 48 and view.polygons.all(func(points: PackedVector2Array) -> bool: return points.size() <= 24), label + " phase %.3f draws bounded visible geometry" % age)
			check(sample_accent(kind, 0.49, reduced).commands.is_empty(), label + " dissipates without retained geometry")
	var view := DrawRecorder.new()
	var accents = Comic.new()
	accents.accept(view, {"kind":"death", "pos":CENTER, "enemy_kind":"originium_bug"})
	check(accents.accents.is_empty(), "source bug death creates no premature duplicate burst before its fuse")
	accents.reset()
	accents.accept(view, {"kind":"enemy_volatile", "pos":CENTER, "bug_blast":true})
	check(accents.accents.is_empty(), "dedicated bug explosion creates no second comic accent")
	accents.reset()
	accents.accept(view, {"kind":"death", "pos":CENTER, "enemy_kind":"grunt"})
	check(accents.accents.is_empty(), "original atlas deaths keep their original animation only")
	for style: String in ["shared_burst", "beam", "rift", "impact", "lightning"]:
		var old := DrawRecorder.new()
		match style:
			"shared_burst": Comic.burst(old, CENTER, 0.23, 1.0, Color("#ffae4d"), 17, false)
			"beam": Flash.beam(old, CENTER, CENTER + Vector2(100, -10), 0.10, 0.40, Color("#a1d9ff"))
			"rift": Flash.rift(old, CENTER, 26, Color("#c2a3ff"), 0.5, 0.8, -1.0)
			"impact": Comic.impact(old, CENTER, 0.28, 1.0, Color("#ffae4d"), 17)
			"lightning": Comic.lightning(old, CENTER, CENTER + Vector2(90, 30), Color("#b3a3ff"), 0.8, 0.12, 17)
		unchanged[style] = var_to_str(old.commands)
		check(not has_color(old, SMOKE), style + " keeps its existing independent drawing style")

func arena(endless: bool):
	var sim = Sim.new(9504, true)
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	sim.reset_stage("stage_endless" if endless else "stage_02", squad, 9504)
	sim.start(); sim.enemies.clear(); sim.enemy_lookup.clear(); sim.terrain_features.clear(); sim.events.clear(); sim.crystal_shield = 0
	for hero: Dictionary in sim.heroes:
		hero.deployed = true; hero.hp = 10000.0; hero.max_hp = hero.hp; hero.armor = 0
		hero.damage_reduction = 0; hero.invulnerable_timer = 0; hero.passive = {}; hero.card_levels = {}
	return sim

func test_bug_authority() -> void:
	for endless: bool in [false, true]:
		var sim = arena(endless)
		var radii: Vector2 = sim.ability_area_screen_radii(CENTER, 80.0)
		var offset := Vector2(0, 8) if endless else Vector2.ZERO
		for i in 3: sim.heroes[i].pos = CENTER + offset + Vector2.RIGHT * radii * ([79.0, 81.0, 120.0][i] / 80.0)
		var bug: Dictionary = sim.spawn_enemy(CENTER, "originium_bug")
		bug.pos = CENTER; bug.armor = 0; bug.shield = 0; bug.affixes = ["volatile"]
		var damage := float(bug.damage) * 1.5
		sim.apply_hit(bug, 1000000, "", 0)
		var label := "endless" if endless else "campaign"
		check(sim.pending_impacts.size() == 1 and sim.pending_impacts[0].radius == 80.0 and sim.pending_impacts[0].life == 1.0, label + " bug retains one 80-radius blast with one-second fuse")
		check(sim.pending_impacts[0].damage == damage, label + " bug keeps original damage multiplier")
		sim._pending_impact_tick(0.99)
		check(sim.heroes.all(func(hero: Dictionary) -> bool: return hero.hp == 10000), label + " bug deals no damage before the fuse completes")
		sim._pending_impact_tick(0.02)
		check(is_equal_approx(10000 - float(sim.heroes[0].hp), damage) and sim.heroes[1].hp == 10000 and sim.heroes[2].hp == 10000, label + " original 79/81/120 projected damage boundaries remain exact")
		var blasts: Array = sim.events.filter(func(event: Dictionary) -> bool: return bool(event.get("bug_blast", false)))
		check(blasts.size() == 1 and sim.pending_impacts.is_empty(), label + " bug detonates exactly once")
		sim._pending_impact_tick(2.0)
		check(is_equal_approx(10000 - float(sim.heroes[0].hp), damage), label + " completed blast cannot damage again")
		for reduced: bool in [false, true]:
			for age: float in [0.025, 0.11, 0.24, 0.40]:
				var view := DrawRecorder.new(); view.sim = sim; view.reduced_effects = reduced
				Tactics.draw_blast(view, {"pos":CENTER, "total":0.85, "life":0.85 - age, "radius":80.0, "seed":17})
				record(view, label + " bug" + (" reduced" if reduced else " full"), age)
				check(extent(view, CENTER + offset, radii) <= 1.0, label + " painted blast phase %.3f stays inside its true projected footprint" % age)
				if is_equal_approx(age, 0.11): check(has_color(view, SMOKE) and has_color(view, FIRE), label + " dedicated bug blast uses the cartoon smoke and fire palette")
				check(not view.polygons.is_empty() and view.commands.size() <= 48, label + " dedicated blast draws bounded visible geometry")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	game.battle.queue_redraw()
	await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(output.path_join(phase + "-" + name + ".png"))

func set_visual_age(age: float) -> void:
	game.battle.enemy_death_visuals.assign(native_deaths.duplicate(true))
	for death: Dictionary in game.battle.enemy_death_visuals: death.elapsed = float(death.elapsed) + age
	for effect: Dictionary in game.battle.effects: effect.life = maxf(0.001, float(effect.total) - age)
	for accent: Dictionary in game.battle.comic_vfx.accents: accent.life = maxf(0.001, float(accent.total) - age)
	game.battle.clock = age
	game.battle.advance(0.0) # Apply the original down-frame expiry at this exact chronological age.

func render_native_scene() -> void:
	if DisplayServer.get_name() == "headless": return
	# Render clocks now run independently from physics. Freeze both during exact phase captures.
	game.set_process(false)
	game.mode_select_panel.close(); game.stage_select_panel.close(); game.squad_panel.root.hide(); game.compendium_panel.close()
	game.dialogue.root.hide(); game.battle.set_process(false)
	var squad: Array[String] = ["traveler", "hero_01", "hero_03"]
	game.sim.reset_stage("stage_02", squad, 9504)
	game.sim.start(); game.sim.enemies.clear(); game.sim.enemy_lookup.clear(); game.sim.terrain_features.clear(); game.sim.events.clear()
	game.battle.effects.clear(); game.battle.reset_transients(); game.battle.reduced_effects = false
	for i in game.sim.heroes.size():
		var hero: Dictionary = game.sim.heroes[i]
		hero.deployed = true; hero.pos = CENTER + Vector2(-155 - i * 60, i * 48 - 42); hero.target = hero.pos
		hero.hp = hero.max_hp; hero.invulnerable_timer = 0
	var bug: Dictionary = game.sim.spawn_enemy(CENTER, "originium_bug")
	bug.pos = CENTER; bug.armor = 0; bug.shield = 0; bug.affixes = ["volatile"]
	bug.hp = 125; bug.max_hp = 125
	game.sim.apply_hit(bug, 300, "", 0)
	game.process_events(); game.refresh()
	await capture("bug-fuse")
	game.sim._pending_impact_tick(0.99)
	game.sim._enemy_tick(0.99)
	game.battle.advance(0.99)
	game.fx.advance(0.99)
	check(game.sim.pending_impacts.size() == 1, "native actual bug retains its warning until the complete fuse")
	check(game.sim.enemies.is_empty(), "native actual enemy tick removes the defeated bug from live actors")
	game.sim._pending_impact_tick(0.02)
	game.sim._enemy_tick(0.02)
	game.battle.advance(0.02)
	game.fx.advance(0.02)
	check(game.battle.enemy_death_visuals.all(func(death: Dictionary) -> bool: return float(death.elapsed) >= 1.0), "native original down animation advances through the real one-second fuse")
	native_deaths.assign(game.battle.enemy_death_visuals.duplicate(true))
	native_lifecycle = {"fuse_elapsed":1.01, "down_duration":game.battle.enemy_sequences.duration("originium_bug", "down"),
		"down_visual_duration":game.battle.enemy_sequences.duration("originium_bug", "down") + 0.16}
	game.process_events()
	check(game.battle.effects.filter(func(effect: Dictionary) -> bool: return bool(effect.get("bug_blast", false))).size() == 1, "native actual bug event dispatch renders exactly one dedicated blast")
	for age: float in [0.025, 0.11, 0.24, 0.40]:
		set_visual_age(age); await capture("bug-%.3f" % age)
	check(game.battle.enemy_death_visuals.is_empty(), "native original down tail expires naturally during the explosion")
	var movie_dir := output.path_join("frames")
	DirAccess.make_dir_recursive_absolute(movie_dir)
	for frame in 30:
		set_visual_age(float(frame) / 60.0)
		await RenderingServer.frame_post_draw
		game.battle.queue_redraw()
		await RenderingServer.frame_post_draw
		game.get_viewport().get_texture().get_image().save_png(movie_dir.path_join("%03d.png" % frame))
	game.battle.effects.clear(); game.battle.comic_vfx.reset(); native_deaths.clear()
	var batch: Array[Dictionary] = [
		{"kind":"death_burst", "pos":CENTER + Vector2(-60, -80)},
		{"kind":"enemy_volatile", "pos":CENTER + Vector2(120, 20)},
		{"kind":"death", "pos":CENTER + Vector2(250, -50), "enemy_kind":"slime_pyro", "size":48}]
	game.battle.accept_events(batch)
	for age: float in [0.025, 0.11, 0.24, 0.40]:
		set_visual_age(age); await capture("named-bursts-%.3f" % age)
	game.return_to_main_menu()
	game.set_process(true)

func run(owner_game) -> int:
	game = owner_game; tree = game.get_tree()
	game.test_mode = false; game.set_physics_process(false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-phase="): phase = arg.trim_prefix("--qa-phase=")
	if not output.is_absolute_path(): return 2
	DirAccess.make_dir_recursive_absolute(output)
	check(game.qa_storage_path.begins_with(output), "explosion validation uses isolated save data")
	check(game.battle != null and game.sim != null, "actual battle and simulation initialized")
	for frame in 4: await tree.process_frame
	test_scoped_dispatch(); test_bug_authority()
	await render_native_scene()
	var file := FileAccess.open(output.path_join("explosion-results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks, "failures":failures, "observations":observations, "unchanged_styles":unchanged, "native_lifecycle":native_lifecycle}, "\t"))
	print("V95 EXPLOSION COMPLETE: %d checks, %d failures" % [checks, failures.size()])
	return 0 if failures.is_empty() else 1
