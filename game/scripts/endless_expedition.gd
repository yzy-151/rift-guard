extends RefCounted
## Run-local objectives and zone pressure. No rendering or campaign state.
const ARENA := Rect2(80, 80, 3200, 2200)
const CENTERS := [Vector2(1680,1180), Vector2(2100,880), Vector2(2080,1470), Vector2(1240,1460), Vector2(1220,860)]
var tasks: Array[Dictionary] = []
var completed := 0
var pending_rewards := 0
var cards_remaining := 0
var cards_total := 3
var completion_notice := 0.0
var completion_name := ""
var safe_center := ARENA.get_center()
var next_center := ARENA.get_center()
var safe_radius := 2100.0
var phase_name := "探索准备"
var phase_remaining := 45.0
var storm_timer := 0.0
var outside_time: Dictionary = {}
var recycle_timer := 0.0
var seed := 0
var warned_boss := -1
var warning_beat := ""

func setup(sim) -> void:
	seed = sim.run_seed
	for i in 3:
		var offsets := [Vector2(-360,-160), Vector2(420,20), Vector2(40,350)]
		tasks.append(_task(sim,i,ARENA.get_center()+offsets[i]))

func _task(sim, kind: int, point: Vector2) -> Dictionary:
	var pos: Vector2 = sim._nearest_walkable_point(point,48.0)
	var names := ["重启信标", "清剿裂隙", "回收补给"]
	var shards: Array[Dictionary] = []
	for i in 3:
		var q: Vector2 = sim._nearest_walkable_point(pos+Vector2.from_angle(i*TAU/3.0)*Vector2(175.0,70.0),24.0)
		shards.append({"pos":q,"taken":false})
	return {"type":kind,"name":names[kind],"pos":pos,"active":false,"done":false,"progress":0.0,"target":18.0 if kind==0 else (16.0 if kind==1 else 3.0),"cooldown":0.0,"shards":shards}

func leader(sim) -> Dictionary:
	if sim.follow_leader_id < sim.heroes.size() and sim.heroes[sim.follow_leader_id].hp > 0:
		return sim.heroes[sim.follow_leader_id]
	for hero: Dictionary in sim.heroes:
		if hero.hp > 0 and bool(hero.get("deployed",true)):return hero
	return {}

func ground_distance(a: Vector2, b: Vector2) -> float:
	var d:=a-b
	return Vector2(d.x,d.y/0.4).length()

func update_zone(time: float) -> void:
	var cycle := floori(time/150.0)
	var t := fposmod(time,150.0)
	var from: Vector2 = CENTERS[cycle % CENTERS.size()]
	var to: Vector2 = CENTERS[(cycle+1) % CENTERS.size()]
	next_center = to
	var shrink := clampf((t-45.0)/60.0,0.0,1.0)
	safe_center = from.lerp(to,shrink)
	safe_radius = lerpf(3300.0 if cycle==0 else 2400.0,1800.0,shrink)
	phase_name = "探索准备" if t<45.0 else ("风暴收缩" if t<105.0 else "守住安全区")
	phase_remaining = (45.0-t) if t<45.0 else ((105.0-t) if t<105.0 else (150.0-t))

func tick(sim, dt: float) -> void:
	completion_notice=maxf(0.0,completion_notice-dt)
	update_zone(sim.elapsed)
	if sim.endless_next_boss_at-sim.elapsed<=10.0 and warned_boss!=sim.endless_boss_index:
		warned_boss=sim.endless_boss_index
		sim.events.append({"kind":"expedition_boss_warning"})
	var remaining:float=sim.endless_next_boss_at-sim.elapsed
	var beat:=str(sim.endless_boss_index)+":"+str(ceili(remaining))
	if remaining>0 and remaining<=3 and beat!=warning_beat:
		warning_beat=beat
		sim.events.append({"kind":"expedition_boss_warning","pitch":1.0+(3-ceili(remaining))*0.12})
	var player := leader(sim)
	if player.is_empty():return
	for task: Dictionary in tasks:
		if task.done:
			task.cooldown -= dt
			if task.cooldown <= 0:
				var angle := fposmod(float(seed%17)*0.13+completed*2.399+int(task.type)*TAU/3.0,TAU)
				var point := safe_center+Vector2.from_angle(angle)*600.0
				point = point.clamp(ARENA.position+Vector2(160,160),ARENA.end-Vector2(160,160))
				var fresh := _task(sim,posmod(int(task.type)+1,3),point)
				task.clear();task.merge(fresh)
			continue
		# Relocate abandoned objectives before the storm makes them unreachable.
		if ground_distance(Vector2(task.pos),safe_center)>safe_radius-150.0 and ground_distance(Vector2(player.pos),task.pos)>450.0:
			var point: Vector2 = safe_center+(Vector2(task.pos)-safe_center).normalized()*minf(600.0,safe_radius-220.0)
			var fresh := _task(sim,int(task.type),point)
			task.clear();task.merge(fresh)
		var distance := ground_distance(Vector2(player.pos),task.pos)
		if distance < 180.0:task.active = true
		if not task.active:continue
		if int(task.type)==0 and distance < 180.0:
			task.progress = minf(float(task.target),float(task.progress)+dt)
		elif int(task.type)==2:
			for shard: Dictionary in task.shards:
				if not shard.taken and Vector2(player.pos).distance_to(shard.pos)<58.0:
					shard.taken=true;task.progress+=1.0
		if float(task.progress)>=float(task.target):_complete(task)
	storm_timer += dt
	for hero: Dictionary in sim.heroes:
		var outside := ground_distance(Vector2(hero.pos),safe_center)>safe_radius
		outside_time[hero.id] = float(outside_time.get(hero.id,0.0))+dt if outside and hero.hp>0 else 0.0
	if storm_timer >= 1.0:
		storm_timer -= 1.0
		for hero: Dictionary in sim.heroes:
			if float(outside_time.get(hero.id,0.0))>3.0:
				sim.damage_hero(int(hero.id),float(hero.max_hp)*minf(0.04,0.012+sim.elapsed/60000.0),{"source_name":"猩红风暴","source_skill":"安全区外侵蚀"})
	recycle_timer -= dt
	if recycle_timer <= 0.0:
		recycle_timer=1.0
		for enemy: Dictionary in sim.enemies:
			if not str(enemy.kind).begins_with("boss_") and Vector2(enemy.pos).distance_to(player.pos)>1750.0:
				enemy.pos=spawn_point(sim,int(enemy.id)%4,0.37);enemy.erase("nav_waypoint");enemy.nav_timer=0.0
				break

func on_kill(enemy: Dictionary) -> void:
	for task: Dictionary in tasks:
		if task.done or not task.active or int(task.type)!=1:continue
		if ground_distance(Vector2(enemy.pos),task.pos)<=400.0:
			task.progress+=1.0
			if float(task.progress)>=float(task.target):_complete(task)

func _complete(task: Dictionary) -> void:
	if task.done:return
	task.done=true;task.cooldown=25.0
	completed+=1;pending_rewards+=1
	completion_name=str(task.name);completion_notice=2.0

func open_reward(sim) -> void:
	if pending_rewards<=0 or sim.state!="running" or completion_notice>0:return
	pending_rewards-=1;cards_remaining=cards_total
	for h: Dictionary in sim.heroes:
		if h.hp>0:h.hp=minf(h.max_hp,h.hp+h.max_hp*0.18)
	sim.rewards.draw(sim);sim.state="reward"

func choose_next(sim) -> void:
	cards_remaining-=1
	if cards_remaining>0:
		sim.rewards.draw(sim);sim.state="reward"
	else:
		sim.state="running"

func spawn_point(sim, side: int, ratio: float) -> Vector2:
	var player := leader(sim)
	var origin: Vector2 = player.get("pos",ARENA.get_center())
	var inner := ARENA.grow(-72.0)
	for i in 24:
		var angle := (side+ratio)*TAU/4.0+i*2.399
		var p: Vector2 = origin+Vector2.from_angle(angle)*(760.0+float(i%3)*65.0)
		if inner.has_point(p) and not sim._terrain_blocks(p,48.0) and not sim.active_view_rect.grow(45.0).has_point(p):return p
	return sim._nearest_walkable_point((origin+Vector2(-780,0)).clamp(inner.position,inner.end),48.0)
