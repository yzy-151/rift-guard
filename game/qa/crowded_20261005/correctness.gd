extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const View = preload("res://scripts/battle_view.gd")
const Plants = preload("res://scripts/pvz_plant_visual.gd")
var checks:=0
var failures: Array[String]=[]
class ProjectionStub:
	extends RefCounted
	func world_to_screen(p: Vector2)->Vector2: return p*Vector2(1.1,.65)+Vector2(20,30)
	func world_depth_scale(_p: Vector2)->float: return 1.0
func check(value: bool, label: String)->void:
	checks+=1
	if not value: failures.append(label)
func fixture():
	var sim=Sim.new(71005,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage("stage_02",squad,71005)
	sim.enemies.clear(); sim.enemy_lookup.clear(); sim.events.clear(); sim.terrain_features.clear()
	sim.pending_stage_spawns.clear(); sim.pending_troop_spawns.clear()
	sim.state="running"; sim.formation_mode="hold"
	return sim
func foe(sim,p: Vector2,kind: String="grunt")->Dictionary:
	var e: Dictionary=sim.spawn_enemy(p,kind)
	e.hp=10000.0; e.max_hp=10000.0; e.armor=0.0; e.affixes=[]; e.xp=0
	return e
func shot(p: Vector2,pierce: int=3)->Dictionary:
	return {"visual_id":123,"pos":p,"direction":Vector2.RIGHT,"speed":1000.0,"life":5.0,"damage":20.0,"element":"","source_id":-1,"hit_ids":[],"can_hit_air":true,"pierce":pierce,"chain_count":0,"blast_radius":0.0,"splash":false,"echo_ratio":0.0}
func _initialize()->void:
	call_deferred("run")
func run()->void:
	var sim=fixture()
	var far=foe(sim,Vector2(490,400)); var near=foe(sim,Vector2(450,400)); var middle=foe(sim,Vector2(470,400))
	sim.projectiles.append(shot(Vector2(400,388)))
	sim._projectile_tick(.10)
	var contacts: Array[int]=[]
	for e: Dictionary in sim.events:
		if e.kind=="projectile_impact": contacts.append(int(e.enemy_id))
	check(contacts==[int(near.id),int(middle.id),int(far.id)],"swept nearest contact order independent of spawn order")
	for e in [near,middle,far]: check(is_equal_approx(float(e.hp),9980.0),"each enemy receives one direct hit")
	sim._projectile_tick(.005)
	for e in [near,middle,far]: check(is_equal_approx(float(e.hp),9980.0),"continuing piercing shot never repeats same enemy")
	sim=fixture(); var fast=foe(sim,Vector2(800,400)); sim.projectiles.append(shot(Vector2(400,388),0)); sim._projectile_tick(.40)
	check(is_equal_approx(float(fast.hp),9980.0),"fast swept segment cannot tunnel through target")
	sim=fixture(); var first=foe(sim,Vector2(500,400)); var behind=foe(sim,Vector2(650,400))
	sim.terrain_features.append({"type":"blocked","area":Rect2(560,350,30,100),"collision_shape":"rect"})
	sim.projectiles.append(shot(Vector2(400,388),5)); sim._projectile_tick(.40)
	check(is_equal_approx(float(first.hp),9980.0) and is_equal_approx(float(behind.hp),10000.0),"wall preserves nearer hit and blocks farther targets")
	sim=fixture(); var origin=foe(sim,Vector2(600,400)); var left=foe(sim,Vector2(560,400)); var right=foe(sim,Vector2(640,400))
	sim.projectile_query_active=true
	check(sim._nearest_enemy_after(origin,[origin.id],{},180).id==left.id,"deterministic distance ties choose lower id")
	check(sim._nearest_enemy_after(origin,[origin.id,left.id],{},180).id==right.id,"excluded chain target cannot be chosen again")
	left.hp=0.0
	check(sim._nearest_enemy_after(origin,[origin.id],{},180).id==right.id,"cached nearest death recomputes eligibility")
	var added=foe(sim,Vector2(602,400))
	check(sim._nearest_enemy_after(origin,[origin.id],{},180).id==added.id,"spawn invalidates cached nearest choice")
	added.pos=Vector2(1000,400); sim._invalidate_enemy_position_queries()
	check(sim._nearest_enemy_after(origin,[origin.id],{},180).id==right.id,"position invalidation prevents stale chain/bucket hits")
	sim.reset_stage("stage_01",["traveler"],71005)
	check(not sim.projectile_bins_ready and not sim.projectile_query_active and sim.projectile_chain_cache.is_empty() and sim.projectile_enemy_bins.is_empty(),"restart clears transient spatial indexes")
	for endless in [false,true]:
		sim=fixture(); sim.endless_mode=endless; sim.workshop_mode=true; sim.workshop_enemy_action=false
		var arriving=foe(sim,Vector2(650,420),"buffer"); var ground: Vector2=arriving.pos
		check(View.shaman_drop_offset(arriving)==320.0 and arriving.spawn_timer>0.0,"shaman starts visibly above actual ground position")
		check(sim.apply_hit(arriving,20,"",-1)==0.0,"airborne shaman cannot take damage at false ground position")
		for frame in 32:
			sim._enemy_tick(1.0/60.0)
			check(arriving.pos==ground and not bool(arriving.attack_pending),"shaman ground anchor static and attacks disabled during fall")
		check(View.shaman_drop_offset(arriving)>0.0,"shaman descent has finite intermediate vertical offset")
		for frame in 3: sim._enemy_tick(1.0/60.0)
		check(arriving.spawn_timer==0.0 and arriving.spawn_phase=="ground" and View.shaman_drop_offset(arriving)==0.0,"shaman lands after .55 seconds even when workshop AI disabled")
		check(sim.apply_hit(arriving,20,"",-1)>0.0,"shaman cannot remain permanently immune after landing")
		check(sim.events.any(func(e: Dictionary)->bool:return e.kind=="shaman_land"),"landing feedback emitted")
		var boss=foe(sim,Vector2(900,500),"boss_galio")
		check(not boss.has("spawn_timer"),"boss entrance remains independent of shaman entrance")
	sim=fixture(); sim.battle_devices.gold=10000; sim.battle_devices.selected_kind="pea"
	check(sim.battle_devices.place(sim,Vector2(390,350)),"plant fixture deployment valid")
	var device: Dictionary=sim.battle_devices.placed[0]
	device.timer=999.0; device.visual_time=.23
	var aim=foe(sim,Vector2(850,device.pos.y)); aim.flying=false
	sim.run_state.buff_levels.device_gatling=1; sim.battle_devices.sync_modifiers(sim); device.timer=999
	check(sim.battle_devices._fire(sim,device) and sim.battle_devices.shots.size()==1 and device.burst_queue.size()==3,"gatling releases first pea and queues three real delayed shots")
	var initial: Dictionary=sim.battle_devices.shots[0]
	var projection=ProjectionStub.new()
	check(Plants.shot_screen(projection,initial).distance_to(Plants.mouth_screen(projection,device.pos,device.visual_variant,device.visual_time))<.001,"new pea appears at painted animated mouth")
	sim.battle_devices.tick(sim,.11)
	check(device.burst_queue.size()==3,"burst does not fire before .12 second delay")
	sim.battle_devices.tick(sim,.02)
	check(device.burst_queue.size()==2 and sim.battle_devices.shots.size()==2,"first delayed shot releases after .12 seconds")
	var delayed: Dictionary=sim.battle_devices.shots[1]
	check(is_equal_approx(float(delayed.visual_time),float(device.visual_time)),"delayed pea stores its own release animation phase")
	check(sim.battle_devices.muzzle_shots.has(Vector2(device.pos)),"near-mouth shots use stable device bucket")
	var report={"checks":checks,"failures":failures}
	var file=FileAccess.open("res://../qa/crowded-correctness-20261005.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
