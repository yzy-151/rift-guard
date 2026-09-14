extends RefCounted

const SurfaceRenderer = preload("res://scripts/stage_surface_renderer.gd")
const StageVisual = preload("res://data/stage_visual_profile.tres")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V48 PASS: " + message)
	else:
		failures += 1
		push_error("V48 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	game.refresh()
	await game.get_tree().create_timer(0.30).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v48-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		var error: Error = image.save_png(directory.path_join(name + ".png"))
		expect(error == OK, "capture written: " + name)

func run(game) -> void:
	var surface = SurfaceRenderer.new()
	var stage_ids := ["stage_01","stage_02","stage_03","stage_04","stage_05","stage_06","stage_07","stage_08"]
	var solo: Array[String] = ["traveler"]
	expect(SurfaceRenderer.STAGE_LAYER_ORDER == ["backdrop","atmosphere","ground","routes","terrain","architecture","foreground"], "campaign map exposes seven ordered visual layers")
	var motifs := {}
	var backgrounds := {}
	var accents := {}
	for stage_id in stage_ids:
		var theme: Dictionary = surface.stage_theme(stage_id)
		motifs[str(theme.motif)] = true
		backgrounds[int(theme.background)] = true
		accents[StageVisual.palette(stage_id).accent.to_html()] = true
		expect(game.battle._stage_background(stage_id) != null, stage_id + " binds a real Helltaker backdrop")
	expect(motifs.size() == 8, "all eight campaign stages own distinct architecture motifs")
	expect(backgrounds.size() == 8, "all eight campaign stages use distinct backdrop bindings")
	expect(accents.size() == 8, "all eight campaign stages own distinct floor palettes")
	for stage_id in ["stage_01","stage_04","stage_07","stage_08"]:
		game.sim.reset_stage(stage_id,solo,4800 + int(stage_id.trim_prefix("stage_")))
		game.battle._build_stage_tile_cache(stage_id)
		expect(game.battle.stage_tile_cache.size() == 220 and game.battle.stage_tile_cache_id == stage_id, stage_id + " builds a complete cached perspective floor")
		game.battle.route_previews["main"] = {"enemy_id":"runner","count":3,"boss":stage_id=="stage_08","flying":false,"life":2.0,"total":2.0}
		var routes: Dictionary = game.sim.stage_routes()
		if routes.has("main"):
			game.battle.spawn_portals["main"] = {"pos":routes.main[0],"life":0.55,"total":1.0}
		game.sim.start()
		game.sim.deploy_hero(0,Vector2(430,360))
		game.battle.advance(0.16)
		await capture(game,stage_id + "-seven-layer-map")
	game.sim.reset_stage("stage_endless",solo,4899)
	expect(surface.stage_theme("stage_endless").motif == "wastes", "endless mode keeps its own four-screen wastes theme")
	var phases := [surface.portal_phase(0.95,1.0),surface.portal_phase(0.70,1.0),surface.portal_phase(0.40,1.0),surface.portal_phase(0.10,1.0)]
	expect(phases == SurfaceRenderer.PORTAL_PHASES, "dynamic portal keeps four readable phases")
	print("V48 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
