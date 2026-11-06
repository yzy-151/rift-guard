extends SceneTree
const PeaVisual=preload("res://scripts/peashooter_visual_20261005.gd")
var app
var checks:=0
var failures:Array[String]=[]
var out:="C:/Users/23081/Desktop/codex/rift-guard/qa/devices-polish-20261005/native"
var frame_index:=0
var muzzle_samples:Array[Dictionary]=[]

func _initialize() -> void:
	for arg:String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):out=arg.trim_prefix("--qa-output=")
	run.call_deferred()

func check(ok:bool,label:String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)

func frame(dt:float,folder:String) -> void:
	if dt>0:
		app.sim.tick(dt)
		app.battle.accept_events(app.sim.drain_events())
		app.battle.advance(dt)
	app.refresh()
	app.battle.queue_redraw()
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name()!="headless":
		var picture:Image=root.get_texture().get_image()
		picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
		picture.save_png(out+"/"+folder+"/frame-%04d.png"%frame_index)
	frame_index+=1

func run() -> void:
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.test_mode=true;app.set_process(false);app.set_physics_process(false)
	app.mode_select_panel.close();app.stage_select_panel.close();app.squad_panel.root.hide();app.dialogue.hide();app.home_panel.close()
	app.hud.get_child(0).show()
	var sim=app.sim
	var squad:Array[String]=["traveler","hero_03"]
	sim.reset_stage("stage_01",squad,45106);sim.start()
	sim.pending_stage_spawns.clear();sim.enemies.clear();sim.enemy_lookup.clear();sim.events.clear()
	sim.stage_runtime.definition=sim.stage_runtime.definition.duplicate(true);sim.stage_runtime.definition.waves=[];sim.wave_timer=999
	sim.battle_devices.gold=2000
	check(sim.heroes.any(func(h):return h.character_id=="hero_13" and bool(h.deployed) and bool(h.get("temporary_assist",false))),"first stage keeps real temporary Gwen on field")
	check(not sim.run_state.squad.has("hero_13"),"temporary Gwen is absent from selected squad")
	check(sim.terrain_features.all(func(f):return f.type not in ["attack_ground","high_ground"]),"first-stage live terrain has no legacy buff tiles")
	for i in sim.heroes.size():
		var hero:Dictionary=sim.heroes[i];hero.pos=Vector2(300+i*135,230);hero.target=hero.pos;hero.attack_timer=999;hero.hp=hero.max_hp
	sim.battle_devices.select(sim,"pea")
	var site:=Vector2(430,400)
	if not sim.battle_devices.placement_error(sim,site).is_empty():
		for y in range(320,480,40):
			for x in range(360,520,60):
				if sim.battle_devices.placement_error(sim,Vector2(x,y)).is_empty():site=Vector2(x,y);break
			if sim.battle_devices.placement_error(sim,site).is_empty():break
	check(sim.battle_devices.place(sim,site),"new Peashooter uses real paid placement")
	if sim.battle_devices.placed.is_empty():quit(1);return
	var device:Dictionary=sim.battle_devices.placed[-1]
	var enemy:Dictionary=sim.spawn_enemy(Vector2(device.pos)+Vector2(380,0),"grunt")
	enemy.hp=99999;enemy.max_hp=99999;enemy.xp=0;enemy.speed=0;enemy.damage=0;enemy.attack_timer=999
	app.battle.reset_transients();sim.drain_events();app.battle.selected_id=-1
	for folder:String in ["pea","deployment","explosion"]:DirAccess.make_dir_recursive_absolute(out+"/"+folder)
	device.timer=0
	# Record the actual first emission slowly enough to see the pea emerge inside the mouth.
	for index in 16:
		await frame(1.0/240.0,"pea")
		if not sim.battle_devices.shots.is_empty():
			var shot:Dictionary=sim.battle_devices.shots[0]
			var mouth:Vector2=PeaVisual.mouth_screen(app.battle,shot.visual_origin,shot.visual_time,shot.muzzle_pulse)
			var at_start:Vector2=PeaVisual.shot_screen(app.battle,shot,shot.model_origin)
			check(mouth.distance_to(at_start)<.001,"native released pea starts exactly at the source-image mouth")
			muzzle_samples.append({"mouth":[mouth.x,mouth.y],"bullet":[PeaVisual.shot_screen(app.battle,shot).x,PeaVisual.shot_screen(app.battle,shot).y],"world_start":[shot.model_origin.x,shot.model_origin.y],"travel":shot.pos.x-shot.model_origin.x})
	for index in 72:await frame(1.0/24.0,"pea")
	check(enemy.hp<99999,"native same-row pea shots actually deal damage")
	var hero:Dictionary=sim.heroes[1];hero.deployed=false
	frame_index=0
	app.handle_deploy_drag(1,true,app.battle.world_to_screen(Vector2(620,340)))
	check(app.battle.deploy_preview_active and app.battle.deploy_preview_id==1,"actual drag handler displays selected-character ghost")
	for index in 24:
		app._update_deploy_preview(app.battle.world_to_screen(Vector2(620,340)))
		await frame(0,"deployment")
	check(app.battle.deploy_preview_valid,"valid floor shows gold landing stamp")
	for index in 12:
		app._update_deploy_preview(app.battle.world_to_screen(Vector2(620,580)))
		await frame(0,"deployment")
	check(not app.battle.deploy_preview_valid,"out-of-field preview warns in red")
	app._finish_deploy_drag(app.battle.world_to_screen(Vector2(620,340)))
	check(bool(hero.deployed) and not app.battle.deploy_preview_active,"release lands hero and removes preview")
	frame_index=0
	sim.battle_devices.select(sim,"mine")
	var mine_site:=Vector2(730,440)
	if not sim.battle_devices.placement_error(sim,mine_site).is_empty():mine_site=Vector2(850,440)
	check(sim.battle_devices.place(sim,mine_site),"real mine placed for explosion demonstration")
	var mine:Dictionary=sim.battle_devices.placed[-1]
	var trigger:Dictionary=sim.spawn_enemy(mine.pos,"grunt");trigger.hp=9999;trigger.max_hp=9999;trigger.xp=0;trigger.speed=0;trigger.damage=0;trigger.attack_timer=999
	sim.tick(.001)
	var events:Array[Dictionary]=sim.drain_events()
	check(events.any(func(e):return e.kind=="device_explosion"),"actual enemy contact emits new explosion")
	app.battle.accept_events(events)
	for index in 18:await frame(1.0/36.0,"explosion")
	var ice:Dictionary=sim.spawn_enemy(Vector2(870,330),"slime_cryo");ice.hp=9999;ice.max_hp=9999;ice.xp=0;ice.speed=0;ice.damage=0;ice.attack_timer=999;ice.shield=150
	sim.apply_hit(ice,100,"",0);events=sim.drain_events()
	check(events.any(func(e):return e.kind=="shield_hit"),"real shield absorption emits hit cloud")
	app.battle.accept_events(events)
	for index in 16:await frame(1.0/36.0,"explosion")
	sim.apply_hit(ice,200,"",0);events=sim.drain_events()
	check(events.any(func(e):return e.kind=="shield_break"),"real shield depletion emits BREAK and ice fragments")
	app.battle.accept_events(events)
	for index in 24:await frame(1.0/36.0,"explosion")
	var report:=FileAccess.open(out+"/validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"muzzle_samples":muzzle_samples},"\t"));report.close()
	print("NATIVE DEVICE POLISH: %d checks, %d failures"%[checks,failures.size()])
	app.queue_free();await process_frame;await process_frame;await create_timer(.25).timeout
	quit(0 if failures.is_empty() else 1)
