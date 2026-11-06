extends SceneTree
var failures: Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,msg:String):
	if not ok:failures.append(msg);push_error(msg)
func run():
	var sim=load("res://scripts/combat_simulation.gd").new()
	var squad:Array[String]=["traveler","hero_01","hero_04"]
	sim.reset_stage("stage_endless",squad,42);sim.start()
	check(sim.heroes.size()==3 and sim.heroes.all(func(h):return h.deployed),"three deployed")
	var ex=sim.expedition
	var task:Dictionary=ex.tasks[0]
	sim.heroes[0].pos=task.pos
	for i in 31:ex.tick(sim,1.0)
	check(ex.completed==1 and ex.pending_rewards==1,"hold completion once")
	ex.completion_notice=0;ex.open_reward(sim);check(sim.state=="reward" and ex.cards_remaining==1,"reward modal")
	var before:float=sim.elapsed;sim.tick(2.0);check(sim.elapsed==before,"reward pauses simulation")
	check(not sim.choose_reward(5,0),"invalid choice rejected")
	for i in 1:check(sim.choose_reward(0,0),"card accepted")
	check(not sim.choose_reward(0,0),"double choice rejected")
	var purge:Dictionary=ex._task(sim,1,task.pos);ex.tasks.append(purge)
	for i in 30:ex.on_kill({"pos":purge.pos,"kind":"grunt"})
	check(purge.done,"purge done")
	var collect:Dictionary=ex.tasks[1];collect.active=true
	for shard:Dictionary in collect.shards:sim.heroes[0].pos=shard.pos;ex.tick(sim,0.1)
	check(collect.done,"collection done")
	# Flood-fill all open navigation cells: every passable cell must be connected.
	var seen:Dictionary={};var queue:Array[Vector2i]=[sim._endless_nav_cell(sim.ENDLESS_ARENA.get_center())];seen[queue[0]]=true
	var cursor:=0
	while cursor<queue.size():
		var c:=queue[cursor];cursor+=1
		for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var q:Vector2i=c+d
			if not seen.has(q) and sim._endless_nav_cell_valid(q) and sim._endless_nav_cell_open(q):seen[q]=true;queue.append(q)
	var count:=0
	for x in sim.endless_nav_columns:
		for y in sim.endless_nav_rows:
			if sim._endless_nav_cell_open(Vector2i(x,y)):count+=1
	check(count==seen.size(),"map connectivity %d/%d" % [seen.size(),count])
	sim.reset_stage("stage_endless",squad,42);sim.start()
	check(sim.expedition.completed==0,"reset clears progress")
	# Boundary/spawn coverage at the center and all four corners.
	for origin in [Vector2(1680,1180),Vector2(160,160),Vector2(3200,160),Vector2(160,2200),Vector2(3200,2200)]:
		sim.heroes[0].pos=origin;sim.active_view_rect=Rect2(origin-Vector2(624,245),Vector2(1248,490))
		for side in 4:
			var point:Vector2=sim.expedition.spawn_point(sim,side,0.35)
			check(sim.ENDLESS_ARENA.has_point(point) and not sim._terrain_blocks(point,48),"spawn on walkable terrain")
			check(not sim.active_view_rect.has_point(point),"spawn outside camera")
	sim.elapsed=110;sim.heroes[0].pos=Vector2(160,160)
	var hp:float=sim.heroes[0].hp
	for i in 5:sim.expedition.tick(sim,1.0)
	check(sim.heroes[0].hp<hp,"storm damages outside after grace")
	sim.reset_stage("stage_endless",squad,42);sim.start()
	var peak:=0;var timing:Array[float]=[]
	for frame in 60*600:
		if sim.state=="reward":sim.choose_reward(0,0)
		for h:Dictionary in sim.heroes:h.hp=h.max_hp;h.invulnerable_timer=99999
		var start:=Time.get_ticks_usec();sim.tick(1.0/60.0);timing.append((Time.get_ticks_usec()-start)/1000.0)
		sim.drain_events();peak=maxi(peak,sim.enemies.size())
	check(peak<=96,"enemy cap")
	check(sim.elapsed>590,"ten minutes actually simulated, state="+sim.state)
	timing.sort();print("EXPEDITION QA failures=",failures," peak=",peak," p95_ms=",timing[int(timing.size()*0.95)]," kills=",sim.kills," elapsed=",sim.elapsed)
	quit(0 if failures.is_empty() else 1)
