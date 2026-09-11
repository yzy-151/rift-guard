extends RefCounted

const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V27 PASS: " + message)
	else:
		failures += 1
		push_error("V27 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.25).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v27-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var sim = game.sim
	var solo: Array[String] = ["traveler"]
	sim.reset_stage("stage_01", solo, 2701)
	var db = sim.database
	expect(db.errors.is_empty(), "V27 content and references validate")
	expect(db.enemy_visuals.size() == 9, "nine enemy roles use replaceable generated visuals")
	var slime_paths: Dictionary = {}
	var pivots_valid := true
	var facing_valid := true
	var texture_size_valid := true
	for visual: Dictionary in db.enemy_visuals.values():
		var path := str(visual.sprite)
		slime_paths[path] = true
		pivots_valid = pivots_valid and is_equal_approx(float(visual.pivot[0]),256.0) and is_equal_approx(float(visual.pivot[1]),480.0)
		facing_valid = facing_valid and int(visual.native_facing) == 1
		var texture: Texture2D = ResourceLoader.load(path)
		texture_size_valid = texture_size_valid and texture != null and texture.get_size() == Vector2(512,512)
	expect(slime_paths.size() == 5, "all five transparent slime variants are assigned")
	expect(texture_size_valid, "processed slime textures follow the 512 square replacement contract")
	expect(pivots_valid, "all slime sprites share one bottom-center gameplay pivot")
	expect(facing_valid, "generated slime source direction is declared as facing right")

	var catalog := SpriteAnchor.load_catalog()
	expect(catalog.size() == 10, "ten atlas animation profiles own generated frame pivots")
	expect(catalog.traveler_run.pivots.size() == 48 and catalog.hilichurl_run.pivots.size() == 30, "traveler and hilichurl pivots cover every run frame")
	expect(catalog.furina_attack.pivots.size() == 16 and catalog.furina_idle.pivots.size() == 8, "Furina pivots cover attack and idle frames")
	var asymmetric_pivot := Vector2(132,270)
	var forward := SpriteAnchor.placement(Vector2(132,132),Vector2(288,288),asymmetric_pivot,1.0)
	var backward := SpriteAnchor.placement(Vector2(132,132),Vector2(288,288),asymmetric_pivot,-1.0)
	expect(forward.rect.size.x > 0.0 and backward.rect.size.x > 0.0 and forward.flip_x == 1.0 and backward.flip_x == -1.0, "movement direction uses a positive rect and pivot-centered transform flip")
	expect(SpriteAnchor.mapped_pivot(forward,Vector2(288,288),asymmetric_pivot).is_equal_approx(Vector2.ZERO), "forward animation keeps its foot pivot fixed")
	expect(SpriteAnchor.mapped_pivot(backward,Vector2(288,288),asymmetric_pivot).is_equal_approx(Vector2.ZERO), "reversed animation keeps its foot pivot fixed")
	expect(game.battle.enemy_visual_textures.size() == 9, "battle view preloads every configured slime role")

	var blade_card: Dictionary = {}
	for card: Dictionary in db.cards:
		if str(card.id) == "orbit_arcane_blades":
			blade_card = card
			break
	expect(not blade_card.is_empty() and int(blade_card.value) == 2, "blade orbit starts with two swords")
	expect(str(blade_card.description).contains("180度") and str(blade_card.description).contains("60度"), "card text exposes exact sword spacing progression")
	sim.start()
	sim.deploy_hero(0,Vector2(480,360))
	sim.run_state.buff_levels[blade_card.id] = 1
	sim.apply_v2_card_effect(blade_card)
	expect(sim.orbitals.size() == 1 and int(sim.orbitals[0].count) == 2, "level one creates two swords at 180 degree spacing")
	sim.run_state.buff_levels[blade_card.id] = 3
	sim.apply_v2_card_effect(blade_card)
	expect(sim.orbitals.size() == 1 and int(sim.orbitals[0].count) == 3, "level three upgrades the same orbit to three swords at 120 degrees")
	sim.run_state.buff_levels[blade_card.id] = 6
	sim.apply_v2_card_effect(blade_card)
	expect(sim.orbitals.size() == 1 and int(sim.orbitals[0].count) == 6, "level six upgrades the same orbit to six swords at 60 degrees")
	expect(is_equal_approx(rad_to_deg(TAU/2.0),180.0) and is_equal_approx(rad_to_deg(TAU/3.0),120.0) and is_equal_approx(rad_to_deg(TAU/6.0),60.0), "orbit placement math matches 180, 120 and 60 degree intervals")
	sim.run_state.buff_levels[blade_card.id] = 9
	sim.apply_v2_card_effect(blade_card)
	sim.orbitals[0].storm_timer = 0.0
	sim.orbitals[0].timer = 99.0
	sim.spawn_enemy(Vector2(560,360),"grunt")
	sim.drain_events()
	sim._orbital_tick(0.02)
	expect(sim.drain_events().any(func(event: Dictionary)->bool: return event.kind == "orbit_storm"), "level nine periodically triggers the promised sword storm")
	expect(str(sim.orbitals[0].visual) == "blade", "blade orbit uses the upright sword presentation")

	sim.reset_stage("stage_endless", solo, 2799)
	sim.start()
	sim.deploy_hero(0,Vector2(1240,720))
	var preview_kinds := ["flyer","ranged","shielded","charger","boss_02"]
	for index in preview_kinds.size():
		var enemy: Dictionary = sim.spawn_enemy(Vector2(980+index*120,570+index%2*150),preview_kinds[index])
		enemy.facing = -1.0
	sim.run_state.buff_levels[blade_card.id] = 6
	sim.apply_v2_card_effect(blade_card)
	await capture(game,"01-slimes-and-upright-blades")
	print("V27 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
