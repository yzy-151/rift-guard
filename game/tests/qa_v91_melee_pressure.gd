extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures+=1
func arena(count:int):
	var s=Sim.new(9120,true)
	s.reset_stage("stage_endless",["traveler","hero_04","hero_08"],9120)
	s.elapsed=540;s.terrain_features.clear();s._rebuild_endless_navigation_grid();s.active_view_rect=s.ENDLESS_ARENA
	s.enemies.clear();s.enemy_lookup.clear();s.crystal_shield=0
	for i in s.heroes.size():
		var h:Dictionary=s.heroes[i];h.pos=Vector2(1200,640+i*125);h.target=h.pos;h.hp=10000000;h.max_hp=h.hp;h.block=3;h.armor=0
	for i in count:
		var e:Dictionary=s.spawn_enemy(Vector2(1200,760)+Vector2.from_angle(i*2.399963)*(205.0+float(i%4)*35.0),"runner" if i%3==0 else "grunt")
		e.special_timer=999;e.tactic_cooldown=999;e.hp=100000;e.max_hp=e.hp
	return s
func tick(s,dt:float):
	for h:Dictionary in s.heroes:h.blocked=0
	s.elapsed+=dt;s._enemy_tick(dt);s.events.clear()
func timings(label:String,values:Array[float]):
	values.sort()
	var total:=0.0
	for v in values:total+=v
	print("PERF %s mean_ms=%.3f p95_ms=%.3f max_ms=%.3f ticks_per_second=%.1f"%[label,total/values.size(),values[mini(values.size()-1,int(values.size()*0.95))],values[-1],1000.0/(total/values.size())])
func pressure(count:int,moving:bool):
	var s=arena(count)
	check(count<=s._endless_active_cap(),"fixture stays under original active cap %d/%d"%[count,s._endless_active_cap()])
	var times:Array[float]=[]
	var starting:Array[Vector2]=[]
	for e:Dictionary in s.enemies:starting.append(e.pos)
	for frame in 360:
		if moving:
			var center:=Vector2(1200,750)+Vector2(sin(float(frame)/100)*170.0,cos(float(frame)/120)*90.0)
			for i in s.heroes.size():s.heroes[i].pos=center+Vector2(0,(i-1)*125.0);s.heroes[i].target=s.heroes[i].pos
		var start:=Time.get_ticks_usec();tick(s,1.0/60.0)
		if frame>=120:times.append(float(Time.get_ticks_usec()-start)/1000.0)
	timings("%d_%s"%[count,"moving" if moving else "stationary"],times)
	var slot_times:Array[float]=[]
	for repeat in 30:
		var start:=Time.get_ticks_usec()
		for e:Dictionary in s.enemies:
			var h:Dictionary=Sim.EnemyMelee.target(s,e)
			if not h.is_empty():Sim.EnemyMelee.destination(s,e,h,1.0/60.0)
		slot_times.append(float(Time.get_ticks_usec()-start)/1000.0)
	timings("%d_slot_batch"%count,slot_times)
	var ready:=0;var unassigned:=0;var largest:=0.0
	for e:Dictionary in s.enemies:
		var h:Dictionary=s._nearest_live_hero(e.pos)
		largest=maxf(largest,Vector2(e.pos).distance_to(h.pos))
		if not e.has("melee_slot"):unassigned+=1
		elif Sim.EnemyMelee.ready(s,e,h):ready+=1
	print("CROWD count=%d moving=%s ready=%d unassigned=%d furthest_hero=%.1f"%[count,moving,ready,unassigned,largest])
	if moving:
		var moved:=0
		for i in s.enemies.size():
			if Vector2(s.enemies[i].pos).distance_to(starting[i])>45.0:moved+=1
		check(moved>=count/2,"moving squad draws a majority of the pursuing crowd: %d/%d"%[moved,count])
		for frame in 420:tick(s,1.0/60.0)
		ready=0
		for e:Dictionary in s.enemies:
			var target_id:=int(e.get("melee_hero_id",-1))
			if target_id>=0 and Sim.EnemyMelee.ready(s,e,s.heroes[target_id]):ready+=1
	check(s.heroes.any(func(h:Dictionary)->bool:return h.hp<10000000),"front ranks keep dealing damage under pressure")
	check(ready>0,"at least one attacker reaches a usable front slot")
func routes_and_wall():
	var s=Sim.new(9121,true)
	s.reset_stage("stage_01",["traveler"],9121)
	var mobs:Array[Dictionary]=[]
	for lane:String in s.stage_routes():
		for i in 6:mobs.append(s.spawn_on_route("ranged" if i%3==0 else "grunt",lane,i,true))
	for frame in 800:tick(s,0.1)
	check(mobs.all(func(e:Dictionary)->bool:return int(e.route_index)>=e.route_points.size()),"mixed first-wave enemies traverse every original route without a junction deadlock")
	s=arena(0)
	s.terrain_features.append({"id":"pressure_wall","type":"blocked","area":Rect2(1090,170,75,340),"hp":0.0})
	s._rebuild_endless_navigation_grid()
	for i in 3:s.heroes[i].pos=Vector2(1270,240+i*95);s.heroes[i].target=s.heroes[i].pos
	mobs=[]
	for i in 12:
		var e:Dictionary=s.spawn_enemy(Vector2(880-i%3*45,220+float(i/3)*70),"grunt");e.speed=110.0;mobs.append(e)
	for frame in 1200:tick(s,1.0/60.0)
	var crossed:=mobs.filter(func(e:Dictionary)->bool:return float(e.pos.x)>1180.0).size()
	print("WALL front crossed=%d/%d"%[crossed,mobs.size()])
	check(crossed>0,"wall approach reaches the squad instead of blocking the whole wave")
	check(s.heroes.any(func(h:Dictionary)->bool:return h.hp<10000000),"wall pursuit resumes actual attacks")
	# This fixture never attacks the front rank. Defeating that rank must let
	# every waiting unit advance, rather than leaving a permanent wall jam.
	for e:Dictionary in mobs:
		if float(e.pos.x)>1180:s.apply_hit(e,100000000.0,"",-1)
	for frame in 1200:tick(s,1.0/60.0)
	check(mobs.all(func(e:Dictionary)->bool:return float(e.pos.x)>1180.0),"all rear-rank enemies cross once defeated front ranks release passage")
	var closest:=INF
	for a in s.enemies.size():
		for b in range(a+1,s.enemies.size()):closest=minf(closest,Vector2(s.enemies[a].pos).distance_to(s.enemies[b].pos))
	check(closest>=38.0,"wall approach keeps strict final body spacing: %.2f"%closest)
func run():
	if "wall_only" in OS.get_cmdline_user_args():
		routes_and_wall();quit(1 if failures else 0);return
	for count in [60,80,96]:pressure(count,false)
	pressure(96,true)
	routes_and_wall()
	print("V91 PRESSURE: checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
