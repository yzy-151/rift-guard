extends RefCounted

const SurfaceRenderer = preload("res://scripts/stage_surface_renderer.gd")
const PerformanceBudget = preload("res://scripts/performance_budget.gd")
const EffectPool = preload("res://scripts/reusable_effect_pool.gd")
const Simulation = preload("res://scripts/combat_simulation.gd")

var checks := 0
var failures := 0

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	game.hud.signature = ""
	game.refresh()
	await game.get_tree().create_timer(0.28).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v30-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(directory.path_join(name + ".png"))

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V30 PASS: " + message)
	else:
		failures += 1
		push_error("V30 FAIL: " + message)

func run(game) -> void:
	game.mode_select_panel.close()
	game.hud.get_child(0).show()
	var db = game.sim.database
	expect(db.errors.is_empty(), "V30 content and cross references validate")
	expect(db.stages.size() == 9, "campaign and endless expose nine maps")
	var stages_complete := true
	for stage: Dictionary in db.stages.values():
		stages_complete = stages_complete and stage.get("routes", {}).size() >= 3
		stages_complete = stages_complete and stage.get("terrain", []).size() >= 4
		stages_complete = stages_complete and stage.get("spawn_points", {}).size() >= 3
	expect(stages_complete, "all nine maps own readable routes terrain and multiple spawn groups")
	expect(db.stage_templates.has("fork") and db.stage_templates.has("loop") and db.stage_templates.has("breakable_shortcut"), "advanced route templates cover fork loop and breakable shortcut")

	var surface = SurfaceRenderer.new()
	var phases := [surface.portal_phase(0.95,1.0),surface.portal_phase(0.70,1.0),surface.portal_phase(0.40,1.0),surface.portal_phase(0.10,1.0)]
	expect(phases == SurfaceRenderer.PORTAL_PHASES, "spawn portal owns forming opening active and closing phases")
	var route: Array = [Vector2(1100,250),Vector2(820,390),Vector2(500,280),Vector2(120,360)]
	var samples_a := surface.route_samples(route,0.0,7)
	var samples_b := surface.route_samples(route,0.5,7)
	expect(samples_a.size() == 7 and samples_a[0].point != samples_b[0].point, "route arrows move continuously across turns")
	expect(float(surface.route_material("upper").bed_alpha) <= 0.15 and game.battle.debug_route_overlap_alpha <= 0.35, "overlapping route beds remain visually quiet")

	for slime_id: String in ["slime_split","slime_heal","slime_shield","slime_bomb","slime_elemental"]:
		expect(db.enemy_families.has(slime_id), slime_id + " is configured")
	var behaviors := {}
	for family: Dictionary in db.enemy_families.values():
		behaviors[str(family.get("behavior", ""))] = true
	expect(behaviors.size() >= 12, "enemy roster exposes at least twelve distinct behaviors")

	var solo: Array[String] = ["traveler"]
	game.sim.reset_stage("stage_01",solo,3001)
	var first: Dictionary = game.sim.spawn_on_route("grunt","upper",0)
	var second: Dictionary = game.sim.spawn_on_route("grunt","upper",1)
	expect(first.pos != second.pos and first.route_points.size() >= 2 and second.route_points.size() >= 2, "encounters rotate across legal route spawn points")
	expect(str(first.get("behavior", "")).length() > 0 and str(first.get("family", "")) == "slime", "spawned enemies inherit family behavior data")
	var warning_batch: Array[Dictionary] = [{"kind":"route_warning","route_id":"upper","enemy_id":"runner","count":3,"lead_time":3.0,"flying":false}]
	game.battle.accept_events(warning_batch)
	expect(game.battle.route_previews.has("upper") and game.battle.spawn_portals.has("upper"), "warnings alone reveal animated route and portal previews")
	expect(game.battle.debug_telegraphs_visible, "performance degradation always preserves combat warnings")

	var boss_contracts_complete: bool = db.boss_patterns.size() == 6
	var arena_kinds := {}
	for boss: Dictionary in db.boss_patterns.values():
		boss_contracts_complete = boss_contracts_complete and boss.get("phases", []).size() == 3
		for phase: Dictionary in boss.get("phases", []):
			boss_contracts_complete = boss_contracts_complete and not phase.get("arena_event", {}).is_empty()
			arena_kinds[str(phase.arena_event.get("type", ""))] = true
	expect(boss_contracts_complete and arena_kinds.size() == 18, "six three-phase bosses own eighteen distinct arena events")
	var arena: Dictionary = game.sim.stage_runtime.apply_arena_event({"type":"test_grid","duration":0.5,"radius":100},Vector2(640,360))
	expect(arena.life == 0.5 and game.sim.stage_runtime.arena_events.size() == 1, "stage runtime activates boss arena changes")
	game.sim.stage_runtime.tick(0.6)
	expect(game.sim.stage_runtime.arena_events.is_empty(), "arena changes expire without stale collision state")
	var boss_enemy: Dictionary = game.sim.spawn_on_route("boss_01","main",0)
	boss_enemy.hp = boss_enemy.max_hp * 0.60
	game.sim._update_boss_phase(boss_enemy)
	expect(boss_enemy.boss_phase == 2 and not game.sim.stage_runtime.arena_events.is_empty(), "boss health transition activates its configured arena event")
	game.sim.start()
	game.sim.deploy_hero(0,Vector2(430,360))
	game.battle.advance(0.16)
	await capture(game,"01-dynamic-route-portals-and-arena")

	var budget = PerformanceBudget.new()
	expect(budget.quality_for_load(300,180,120) >= 0.58, "300 enemies 180 projectiles and 120 effects remain inside staged budget")
	expect(budget.can_spawn_cosmetic("boss_phase",999) and not budget.can_spawn_cosmetic("move",999), "load shedding preserves critical combat information")
	var stress = Simulation.new(3010,true)
	stress.reset_stage("stage_endless",solo,3010)
	for i in 300:
		stress.spawn_enemy(Vector2(100+i%30*20,100+i/30*20),"grunt")
	for i in 180:
		stress.projectiles.append({"id":i})
	stress.performance_budget.sample(16.6,stress.enemies.size(),stress.projectiles.size())
	expect(stress.enemies.size() == 300 and stress.projectiles.size() == 180 and stress.performance_budget.allow_enemy(stress.enemies.size()), "stress fixture retains 300 enemies and 180 projectiles")
	var pool = EffectPool.new()
	var item := pool.acquire({"kind":"hit"},0.2)
	pool.release(item)
	var reused := pool.acquire({"kind":"skill_impact"},0.4)
	expect(pool.stats().reused == 1 and pool.available.size() <= pool.capacity and reused.kind == "skill_impact", "bounded effect pool reuses cosmetic payloads")

	print("V30 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	game.get_tree().quit(failures)
