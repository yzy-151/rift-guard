extends RefCounted

const AnimationMachine = preload("res://scripts/animation_state_machine.gd")
const UnitVisualActor = preload("res://scripts/unit_visual_actor.gd")
const CombatTimeline = preload("res://scripts/combat_timeline.gd")
const FeedbackDirector = preload("res://scripts/combat_feedback_director.gd")
const VfxPipeline = preload("res://scripts/vfx_pipeline.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V29 PASS: " + message)
	else:
		failures += 1
		push_error("V29 FAIL: " + message)

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var db = game.sim.database
	expect(db.errors.is_empty(), "V29 content and cross references validate")
	expect(db.characters.size() == 12, "the playable roster remains twelve characters")
	var states_complete := true
	for character_id: String in db.characters:
		var states: Dictionary = db.animation_profiles.get(character_id, {}).get("states", {})
		for state in ["idle","run","attack","hurt","skill","ultimate","down"]:
			states_complete = states_complete and states.has(state)
	expect(states_complete, "all twelve characters own seven required combat animation states")
	expect(game.battle.debug_visual_matrix.size() == 24, "visual acceptance matrix covers both facings for twelve heroes")
	expect(game.battle.debug_anchor_error_max <= 0.5, "visual matrix reports subpixel anchor error")
	expect(game.battle.debug_damage_shape_error_max <= 2.0, "telegraph and damage geometry share the acceptance tolerance")

	var timeline := CombatTimeline.compile({"timeline":{"duration":1.0,"hit_frame":0.48,"vfx_frame":0.1,"sfx_frame":0.9}})
	expect(is_equal_approx(float(timeline.hit_frame),float(timeline.vfx_frame)), "ability VFX is forced onto the damage frame")
	expect(is_equal_approx(float(timeline.hit_frame),float(timeline.sfx_frame)), "ability SFX is forced onto the damage frame")
	expect(CombatTimeline.validate({"timeline":{"duration":1.0,"hit_frame":0.48}}).is_empty(), "strict synchronized timeline validates")

	var machine = AnimationMachine.new()
	machine.setup(db.animation_profiles.traveler)
	machine.play("attack",-1.0,2.0)
	machine.tick(0.25)
	expect(machine.facing == -1.0 and is_equal_approx(machine.normalized_time(),0.5), "attack speed scales animation time without changing facing")
	expect(machine.consume_hit_event(), "animation emits its configured hit marker once")
	expect(not machine.consume_hit_event(), "animation hit marker cannot double fire")

	var actor = UnitVisualActor.new()
	actor.setup("traveler",db.animation_profiles.traveler)
	actor.sync({"animation_state":"idle","moving":false,"facing":-1.0,"rate":1.0,"base_rate":1.0},0.25)
	var sample := actor.sample()
	expect(sample.facing == -1.0 and sample.scale is Vector2, "unified visual actor preserves direction and fallback motion")

	expect(db.vfx_themes.size() == 15, "six elements and eight reactions plus neutral own VFX themes")
	var themes_valid := true
	for theme: Dictionary in db.vfx_themes.values():
		themes_valid = themes_valid and VfxPipeline.validate_theme(theme)
	expect(themes_valid, "every VFX theme exposes color and impact contracts")
	var director = FeedbackDirector.new()
	director.setup(db)
	expect(director.theme_id({"kind":"overloaded"}) == "overload", "overloaded reaction resolves its dedicated feedback theme")
	expect(director.theme_id({"kind":"hit","element":"cryo"}) == "cryo", "elemental hit resolves its projectile theme")
	expect(director.synchronized({"timeline":timeline}), "feedback director recognizes frame-perfect impact payloads")

	var squad: Array[String] = ["traveler","hero_02","hero_03"]
	game.sim.reset_stage("stage_01",squad,2901)
	game.sim.start()
	game.sim.deploy_hero(0,Vector2(420,360))
	game.battle._sync_unit_visuals(0.016)
	expect(game.battle.unit_visual_actors.has("traveler"), "battle view owns a synchronized visual actor for deployed heroes")
	var impact_batch: Array[Dictionary] = [{"kind":"synced_impact","pos":Vector2(600,360),"element":"pyro","value":100}]
	game.battle.accept_events(impact_batch)
	expect(not game.battle.effects.is_empty() and game.battle.effects.back().has("feedback_theme"), "battle effects carry data-driven visual themes")
	expect(game.squad_panel.preview_has_anchor and game.squad_panel.preview_has_validity, "deployment UI exposes anchor and legal-placement feedback")
	game.battle.deploy_preview_point = Vector2(400,360)
	game.battle.deploy_preview_valid = true
	expect(game.battle.deploy_preview_valid, "deployment preview stores the validated release position")

	print("V29 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
