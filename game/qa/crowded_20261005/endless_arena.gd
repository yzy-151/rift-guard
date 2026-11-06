extends SceneTree
const SIM=preload("res://scripts/combat_simulation.gd")
const PROFILE=preload("res://data/stage_profiles/endless_arena_profile.gd")
var checks := 0
var failures: Array[String]=[]
var movement_checks := 0
var longest_arrival := 0.0
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func fixture():
	var sim=SIM.new(61006,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage("stage_endless",squad,61006); sim.start()
	sim.endless_spawn_timer=999999; sim.endless_next_boss_at=999999; sim.troop_convoy_timer=999999
	return sim
func point_open(sim,p: Vector2)->bool:
	return PROFILE.ARENA.has_point(p) and not sim._terrain_blocks(p,24.0) and sim._endless_nav_cell_open(sim._nearest_open_endless_nav_cell(p))
func move_party(sim,goal: Vector2,max_seconds: float,follow: bool=true)->void:
	sim.formation_mode="follow" if follow else "hold"
	sim.command_move(0,goal,false)
	var reached := false
	for frame in ceili(max_seconds*30):
		sim.elapsed+=1.0/30.0
		sim._update_follow_targets(1.0/30.0)
		for hero: Dictionary in sim.heroes:
			var before: Vector2=hero.pos
			sim._move_hero_with_terrain(hero,1.0/30.0)
			movement_checks+=1
			check(PROFILE.ARENA.has_point(hero.pos) and not sim._terrain_blocks(hero.pos,17.0),"actual actor stays on walkable world at "+str(frame)+" / "+str(hero.id))
			check(not sim.terrain_line_blocked(before,hero.pos,16.9),"actual movement never crosses a solid cover")
		if Vector2(sim.heroes[0].pos).distance_to(goal)<4.0:
			reached=true; longest_arrival=maxf(longest_arrival,float(frame+1)/30.0)
			if not follow: break
			if sim.heroes.all(func(hero: Dictionary)->bool: return Vector2(hero.pos).distance_to(goal)<135.0): break
	check(reached,"actual leader reaches commanded district/cover destination "+str(goal))
	if follow:
		for hero: Dictionary in sim.heroes:
			check(Vector2(hero.pos).distance_to(goal)<135.0,"actual following ally reaches district without wall stuck "+str(hero.id))
func _initialize()->void: run.call_deferred()
func run()->void:
	var sim=fixture()
	check(SIM.ENDLESS_ARENA==PROFILE.ARENA,"one agreed world geometry for simulation and art")
	check(sim.terrain_features.size()==8 and sim.terrain_features.all(func(f: Dictionary)->bool: return f.type=="blocked"),"only eight true covers and no hidden buff pads")
	for index in 8: check(Rect2(sim.terrain_features[index].area)==PROFILE.COVERS[index],"runtime collision matches shared artwork cover "+str(index))
	check(Vector2(sim.heroes[0].pos)==PROFILE.HUB and sim.heroes.all(func(h: Dictionary)->bool: return h.deployed),"actual fresh party starts deployed at central hub")
	var seen := {}
	var queue: Array[Vector2i]=[sim._endless_nav_cell(PROFILE.HUB)]
	seen[queue[0]]=true
	var cursor := 0
	while cursor<queue.size():
		var cell := queue[cursor];cursor+=1
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next := cell+offset
			if sim._endless_nav_cell_open(next) and not seen.has(next): seen[next]=true;queue.append(next)
	var open_count := 0
	for row in sim.endless_nav_rows:
		for col in sim.endless_nav_columns:
			if sim._endless_nav_cell_open(Vector2i(col,row)): open_count+=1
	check(open_count==seen.size(),"all passable navigation cells connected: %d/%d"%[seen.size(),open_count])
	for district: Dictionary in PROFILE.DISTRICTS:
		check(point_open(sim,district.center) and seen.has(sim._endless_nav_cell(district.center)),"district reachable "+str(district.id))
		move_party(sim,district.center,28.0)
	move_party(sim,PROFILE.HUB,28.0)
	# Every cover is crossed by a long command: exercise real path detours, not just grid reachability.
	for cover: Rect2 in PROFILE.COVERS:
		for hero: Dictionary in sim.heroes: hero.target=hero.pos;hero.erase("endless_move_path")
		var start := cover.get_center()-Vector2(0,cover.size.y*.5+80)
		var goal := cover.get_center()+Vector2(0,cover.size.y*.5+80)
		sim.heroes[0].pos=start;sim.heroes[0].target=start
		for index in range(1,sim.heroes.size()): sim.heroes[index].pos=start+Vector2(-70,index*25);sim.heroes[index].target=sim.heroes[index].pos
		sim._reset_follow_history(); move_party(sim,goal,15.0)
	# Continuous WASD/click commands must not erase historical positions when the leader stays the same.
	sim=fixture(); sim.elapsed=2.0; sim.follow_history.append({"time":1.8,"pos":PROFILE.HUB-Vector2(50,0)})
	var history: Array=sim.follow_history.duplicate(true)
	for index in 20: sim.command_move(0,PROFILE.HUB+Vector2(90+index,0),false)
	check(sim.follow_history==history,"repeated commands keep current leader's trail intact")
	check(sim.set_follow_leader(1) and sim.follow_leader_id==1 and sim.follow_history!=history,"changing leader explicitly resets trail")
	# Import intentionally hostile legacy placement; keep build and HP, restore only endless staging.
	var snapshot: Dictionary=sim.export_run_snapshot()
	for index in snapshot.heroes.size():
		snapshot.heroes[index].pos=Vector2(500,360);snapshot.heroes[index].deployed=false;snapshot.heroes[index].hp=123.0
		snapshot.heroes[index].damage=100.0+index
	check(sim.import_run_snapshot(snapshot),"campaign build import accepted")
	for index in sim.heroes.size():
		var hero: Dictionary=sim.heroes[index]
		check(Vector2(hero.pos).distance_to(PROFILE.HUB)<130 and Vector2(hero.target)==Vector2(hero.pos) and hero.deployed,"legacy imported hero returns to deployed hub formation")
		check(is_equal_approx(float(hero.hp),123.0) and is_equal_approx(float(hero.damage),100.0+index),"import retains HP and permanent build without free heal")
	check(sim.follow_leader_id==0 and sim.formation_mode=="follow" and sim.follow_history.size()==18,"import refreshes current actual leader trail")
	var task_types := {}
	for batch in 12:
		sim.elapsed=float(batch)*120;sim.expedition.task_batch=batch;sim.expedition.update_zone(sim.elapsed);sim.expedition._refresh_tasks(sim)
		check(sim.expedition.next_tasks_at==float(batch+1)*120,"task batches remain tied to survival clock")
		for task: Dictionary in sim.expedition.tasks:
			task_types[int(task.type)]=true
			check(point_open(sim,task.pos) and seen.has(sim._endless_nav_cell(task.pos)),"new task destination belongs to reachable district")
			check(not str(task.district_id).is_empty(),"task has clear named district identity")
			for shard: Dictionary in task.shards: check(point_open(sim,shard.pos),"task supply/waypoint is walkable")
	check(task_types.size()==8,"all eight existing task types remain diverse without reward inflation")
	sim=fixture(); var ex=sim.expedition
	var first: Dictionary=ex.tasks[0]
	ex._complete(first); ex.completion_notice=0
	var next_at: float=ex.next_tasks_at; ex.open_reward(sim)
	check(sim.state=="running" and ex.reward_queue.size()==1 and ex.reward_waiting_level==2,"first level task card waits in queue until actual cards unlock")
	var supply: Dictionary=ex._task(sim,2,PROFILE.MEDBAY);sim.heroes[0].hp=float(sim.heroes[0].max_hp)*.50
	var wounded_hp: float=sim.heroes[0].hp
	ex._complete(supply);ex.completion_notice=0;ex.open_reward(sim)
	check(sim.state=="running" and ex.reward_queue.size()==1 and is_equal_approx(float(sim.heroes[0].hp),wounded_hp+float(sim.heroes[0].max_hp)*.25),"waiting card never blocks later supply healing")
	sim.run_state.crystal_level=2;ex.open_reward(sim)
	check(sim.state=="reward" and ex.cards_remaining==1 and sim.card_pool.offered.size()>0,"real first completed task opens one existing card choice")
	check(ex.tasks.size()==2 and ex.next_tasks_at==next_at,"completion does not immediately generate new tasks")
	var chosen := false
	for index in sim.card_pool.offered.size():
		for target in sim.heroes.size():
			if sim.choose_reward(index,target): chosen=true;break
		if chosen:break
	check(chosen and sim.state=="running", "real quest card returns to normal running")
	var patrol: Dictionary=ex._task(sim,7,PROFILE.DISTRICTS[3].center)
	ex.tasks.clear();ex.tasks.append(patrol);sim.heroes[0].pos=patrol.shards[2].pos;ex.tick(sim,.1)
	check(float(patrol.progress)==0,"patrol refuses out of order final waypoint")
	for shard: Dictionary in patrol.shards:sim.heroes[0].pos=shard.pos;ex.tick(sim,.1)
	check(patrol.done and float(patrol.progress)==3,"patrol reaches all three real destinations in order")
	# Hold-to-heal is a finite map interaction with both ranged and melee pressure.
	sim=fixture(); ex=sim.expedition;ex.tasks.clear();sim.heroes[0].pos=PROFILE.MEDBAY
	for hero: Dictionary in sim.heroes: hero.hp=float(hero.max_hp)*.50
	var initial_hp: float=sim.heroes[0].hp
	for index in 16:sim.elapsed+=.25;ex.tick(sim,.25)
	check(ex.field_station.charge==4.0 and sim.heroes[0].hp==initial_hp,"station requires complete five second uninterrupted hold")
	check(sim.enemies.size()==4 and sim.enemies.filter(func(e: Dictionary)->bool:return e.kind=="ranged").size()==2,"station triggers bounded two ranged/two melee pressure")
	sim.heroes[0].pos=PROFILE.HUB;sim.elapsed+=.25;ex.tick(sim,.25)
	check(float(ex.field_station.charge)==0,"leaving station resets hold charge")
	sim.heroes[0].pos=PROFILE.MEDBAY
	for index in 20:sim.elapsed+=.25;ex.tick(sim,.25)
	check(int(ex.field_station.activations)==1 and float(ex.field_station.cooldown)==90.0,"station heals once then starts shared ninety second cooldown")
	check(is_equal_approx(float(sim.heroes[0].hp),initial_hp+float(sim.heroes[0].max_hp)*.20),"station grants exactly twenty percent HP")
	check(sim.enemies.size()==4,"reentering before pressure grace cannot generate endless extra spawns")
	for index in 20:sim.elapsed+=.25;ex.tick(sim,.25)
	check(int(ex.field_station.activations)==1,"standing on station during cooldown never repeats heal")
	ex.field_station.cooldown=0.0;ex.safe_center=Vector2(2100,480);ex.safe_radius=800
	ex._tick_field_station(sim,sim.heroes[0],1.0)
	check(ex.field_station.status=="风暴封锁" and int(ex.field_station.activations)==1,"unsafe station cannot be used as storm immunity")
	sim.heroes[2].hp=0;ex.safe_center=PROFILE.HUB;ex.safe_radius=3000;ex.field_station.cooldown=0
	for index in 20:ex._tick_field_station(sim,sim.heroes[0],.25)
	check(sim.heroes[2].hp==0,"station never revives defeated party members")
	for time: float in [0,300,600,900,1200]:
		sim.elapsed=time
		var pool: Array[String]=sim._endless_enemy_pool(sim._endless_phase())
		if time>=600: check("ranged" in pool and "buffer" in pool and "hilichurl_brute" in pool,"late pressure retains ranged/melee/support mix")
		if time==900: check(sim._endless_enemy_level(sim._endless_tier())==100,"fifteen minute enemy level remains exactly one hundred")
		check(sim._endless_active_cap()<=80,"interaction leaves late active load budget unchanged")
	sim.elapsed=600;var health600: float=sim._endless_enemy_scales(sim._endless_tier()).health
	sim.elapsed=900;check(float(sim._endless_enemy_scales(sim._endless_tier()).health)>health600*50,"late exponential fatal pressure is preserved")
	for origin: Vector2 in [PROFILE.HUB,Vector2(160,160),Vector2(2560,160),Vector2(160,1600),Vector2(2560,1600)]:
		sim.heroes[0].pos=origin;sim.active_view_rect=Rect2(origin-Vector2(624,245),Vector2(1248,490))
		for side in 4:
			var spawn: Vector2=ex.spawn_point(sim,side,.35)
			check(PROFILE.ARENA.has_point(spawn) and not sim._terrain_blocks(spawn,48),"edge and center spawns remain walkable inside compact map")
			check(not sim.active_view_rect.has_point(spawn),"regular spawn stays off camera")
	# Check the existing ellipse against real attacks entirely within the new world.
	sim=fixture();sim.terrain_features.clear()
	var ranged: Dictionary=sim.heroes[0];ranged.range=200.0;ranged.element="anemo";ranged.projectile_count=1;ranged.heal_timer=999.0
	for y: float in [300,880,1480]:
		ranged.pos=Vector2(1360,y);sim.elapsed+=1.0
		check(sim.attack_range_screen_radii(ranged).is_equal_approx(Vector2(166,66.4)),"visual attack ellipse stays fixed within compact arena")
		for offset: Vector2 in [Vector2(160,8),Vector2(0,68),Vector2(175,8),Vector2(0,80)]:
			var inside: bool=offset.x==160 or offset.y==68
			check(sim.is_in_attack_range(ranged,ranged.pos+offset)==inside,"logical attack ellipse remains position independent")
			sim.enemies.clear();sim.enemy_lookup.clear();sim.projectiles.clear();sim._reset_projectile_queries();ranged.attack_timer=0.0
			var shots_before: int=ranged.shots
			sim.spawn_enemy(ranged.pos+offset,"grunt");sim._hero_tick()
			check((ranged.shots>shots_before)==inside,"real in-map attacks match displayed ellipse")
	sim.reset_stage("stage_endless",["traveler"],61007)
	check(sim.endless_nav_cache.is_empty() and sim.heroes.all(func(h: Dictionary)->bool:return not h.has("endless_move_path")),"restart clears transient path caches")
	check(sim.expedition.field_station.activations==0 and float(sim.expedition.field_station.cooldown)==0,"restart clears local station state")
	var report := {"checks":checks,"failures":failures,"actual_movement_checks":movement_checks,"all_open_cells":open_count,"reachable_open_cells":seen.size(),"task_types":task_types.size(),"longest_actual_arrival_seconds":longest_arrival,"fatal_level_at_15_minutes":100}
	var file := FileAccess.open("res://../qa/endless-arena-20261006.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  "));file.close()
	print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
