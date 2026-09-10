extends RefCounted

const Timeline = preload("res://scripts/combat_timeline.gd")
const PerformanceBudget = preload("res://scripts/performance_budget.gd")
const SaveMigrator = preload("res://scripts/save_migrator.gd")
const AnimationStateMachine = preload("res://scripts/animation_state_machine.gd")
const VfxPipeline = preload("res://scripts/vfx_pipeline.gd")
const EffectPool = preload("res://scripts/reusable_effect_pool.gd")
const ErrorReporter = preload("res://scripts/error_reporter.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("V25 PASS: "+message)
	else:
		failures += 1
		push_error("V25 FAIL: "+message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.signature=""; game.refresh()
	await game.get_tree().create_timer(0.3).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory:=ProjectSettings.globalize_path("res://../docs/v25-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image:Image=game.get_viewport().get_texture().get_image()
	if image!=null: image.save_png(directory.path_join(name+".png"))

func run(game) -> void:
	game.mode_select_panel.close(); game.hud.get_child(0).show()
	var sim=game.sim; var db=sim.database
	expect(db.errors.is_empty(),"all V25 data and cross references validate")
	expect(db.characters.size()==12,"twelve-character roster remains stable")
	var active_kinds:Dictionary={}; var ultimate_kinds:Dictionary={}
	for id:String in db.characters:
		var hero:Dictionary=db.characters[id]
		expect(not hero.get("passive",{}).is_empty(),"%s owns a unique passive"%hero.name)
		active_kinds[str(hero.active_skill.kind)]=true; ultimate_kinds[str(hero.ultimate.kind)]=true
		var timeline:Dictionary=Timeline.compile(hero.active_skill,false)
		expect(absf(float(timeline.hit_frame)-float(timeline.sfx_frame))<=0.04,"%s damage and SFX share its hit frame"%hero.name)
	expect(active_kinds.size()==12 and ultimate_kinds.size()==12,"all active skills and ultimates use distinct gameplay kinds")
	expect(db.animation_profiles.size()==12,"all characters have replaceable animation profiles")
	for id:String in db.animation_profiles:
		var states:Dictionary=db.animation_profiles[id].get("states",{})
		expect(["idle","run","attack","skill","ultimate","hurt","down","deploy"].all(func(key:String)->bool:return states.has(key)),"%s animation state set is complete"%id)
	expect(db.stage_templates.size()==8,"eight route and terrain templates are data driven")
	expect(db.stages.size()==9 and db.modes.rift_watch.stage_ids.size()==8,"eight campaign stages plus endless are selectable")
	for stage_id:Variant in db.modes.rift_watch.stage_ids:
		var stage:Dictionary=db.stages[str(stage_id)]
		expect(stage.get("routes",{}).size()>=3 and stage.get("terrain",[]).size()>=5 and stage.get("waves",[]).size()>=14,"%s has three routes, terrain mechanics and a full wave plan"%stage_id)
	expect(db.boss_patterns.size()==6,"six boss pattern libraries are loaded")
	for boss_id:String in db.boss_patterns:
		var phases:Array=db.boss_patterns[boss_id].get("phases",[])
		expect(phases.size()==3 and phases.all(func(row:Dictionary)->bool:return not str(row.get("shape","")).is_empty() and not row.get("moves",[]).is_empty()),"%s owns three telegraphed phases"%boss_id)
	expect(db.enemy_affixes.size()>=8,"late-game enemy affix pool includes eight behaviors")
	expect(db.vfx_profiles.size()>=6 and db.vfx_profiles.values().all(func(profile:Dictionary)->bool:return VfxPipeline.validate_profile(profile)),"VFX profiles define valid pools and blend modes")
	var migrated:=SaveMigrator.migrate({"build_history":[]})
	expect(int(migrated.save_version)==25 and migrated.has("boss_records") and migrated.has("animation_settings"),"legacy saves migrate to V25 without losing history")
	var budget=PerformanceBudget.new()
	for i in 50: budget.sample(30.0,400,700)
	expect(budget.quality_scale<1.0 and budget.effect_cap()<PerformanceBudget.MAX_EFFECTS,"performance budget degrades cosmetic load under pressure")
	var animator=AnimationStateMachine.new(); animator.setup(db.animation_profiles.traveler); animator.play("attack",-1.0); animator.tick(0.5)
	expect(animator.state=="attack" and animator.frame_index()>0 and animator.facing<0.0,"animation state machine advances frames and preserves facing")
	animator.tick(1.0); expect(animator.state=="idle","one-shot animation returns to idle")
	expect(VfxPipeline.new().has_method("validate_profile") and VfxPipeline.validate_profile(db.vfx_profiles.impact_light),"transparent VFX import contract is executable")
	var pool=EffectPool.new(); var pooled=pool.acquire({"kind":"hit"},0.3); pool.release(pooled); pool.acquire({"kind":"muzzle"},0.2)
	expect(int(pool.stats().reused)==1,"reusable effect pool recycles visual dictionaries")
	var reporter=ErrorReporter.new(); reporter.record("qa","sample",{"version":25})
	expect(reporter.entries.size()==1 and reporter.entries[0].scope=="qa","structured error reporter retains diagnostic context")
	expect(not budget.allow_enemy(PerformanceBudget.MAX_ENEMIES) and not budget.allow_projectile(PerformanceBudget.MAX_PROJECTILES),"enemy and projectile hard caps protect endless-mode stability")

	var ids:Array=db.characters.keys()
	for group_start in range(0,ids.size(),3):
		var squad:Array[String]=[]
		for j in range(group_start,mini(group_start+3,ids.size())): squad.append(str(ids[j]))
		sim.reset_stage("stage_04",squad,2500+group_start); sim.start()
		for hero_id in sim.heroes.size(): sim.deploy_hero(hero_id,Vector2(390+hero_id*110,330+hero_id*45))
		for hero_id in sim.heroes.size():
			var hero:Dictionary=sim.heroes[hero_id]
			sim.enemies.clear(); sim.events.clear(); sim.pending_impacts.clear()
			var target:Dictionary=sim.spawn_enemy(hero.pos+Vector2(130,0),"armored"); target.hp=999999.0; target.max_hp=target.hp
			hero.skill_cooldown=0.0
			var active_ok:bool=sim.activate_hero_skill(hero_id,target.pos); sim._pending_impact_tick(2.0)
			var active_event:bool=sim.events.any(func(event:Dictionary)->bool:return event.kind=="skill_impact")
			expect(active_ok and active_event,"%s active skill resolves through the synchronized timeline"%hero.name)
			sim.events.clear(); sim.pending_impacts.clear(); hero.energy=hero.max_energy
			var ultimate_ok:bool=sim.activate_hero_ultimate(hero_id,target.pos); sim._pending_impact_tick(2.0)
			var ultimate_event:bool=sim.events.any(func(event:Dictionary)->bool:return event.kind=="ultimate_impact")
			expect(ultimate_ok and ultimate_event,"%s ultimate resolves independently"%hero.name)

	var final_squad: Array[String] = ["hero_08","hero_11","hero_12"]
	sim.reset_stage("stage_05",final_squad,2525); sim.start()
	for i in sim.heroes.size(): sim.deploy_hero(i,Vector2(430+i*120,340+i*35))
	var shield_before:float=sim.crystal_shield
	sim.recall_hero(0); var redeployed: bool = sim.deploy_hero(0,Vector2(440,340))
	expect(redeployed and sim.crystal_shield>shield_before,"right-click recall path supports redeploy and deploy passive")
	var boss:Dictionary=sim.spawn_enemy(Vector2(840,350),"boss_05"); boss.special_timer=0.0; sim._enemy_tick(0.01)
	expect(bool(boss.special_pending) and str(boss.special_warning_shape)=="targeted" and float(boss.special_warning_radius)>0.0,"boss attack uses phase-specific telegraph data")
	sim.heroes[1].energy=sim.heroes[1].max_energy; sim.activate_hero_ultimate(1,boss.pos); sim._pending_impact_tick(2.0)
	game.battle.accept_events(sim.drain_events()); game.hud.refresh(sim,1)
	await capture(game,"01-boss-skill-timeline")

	for stage_id:Variant in db.modes.rift_watch.stage_ids.slice(0,7): game.compendium.cleared_stages[str(stage_id)] = true
	game.stage_select_panel.open(); await capture(game,"02-eight-stage-selection"); game.stage_select_panel.close()
	sim.run_state.current_node="c2_combat_4"; game.campaign_map_panel.open(); await capture(game,"03-chapter-two-route"); game.campaign_map_panel.close()
	print("V25 QA COMPLETE: %d checks, %d failures"%[checks,failures])
	game.get_tree().quit(failures)
