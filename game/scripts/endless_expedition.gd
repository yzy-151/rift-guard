extends RefCounted
## Run-local objectives and zone pressure. No rendering or campaign state.
const PROFILE = preload("res://data/stage_profiles/endless_arena_profile.gd")
const ARENA = PROFILE.ARENA
const CENTERS = PROFILE.ZONE_CENTERS
var tasks: Array[Dictionary] = []
var completed := 0
var pending_rewards := 0
var cards_remaining := 0
var cards_total := 1
var reward_queue: Array[Dictionary] = []
var next_tasks_at := 120.0
var task_batch := 0
var completion_reward := ""
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
var field_station: Dictionary = {}
var minimum_card_level := 1
var reward_waiting_level := 0

const TASK_NAMES := ["重启信标","清剿裂隙","回收补给","坚守阵线","猎杀精英","击败首领","压制远程","巡查据点"]
const TASK_HELP := ["留在光圈内累计30秒","在任务区击败30名敌人","走到金色补给箱旁拾取，共3箱","存活75秒","击败6名重甲或大型敌人","击败任意1名Boss","击败12名远程敌人","依次到达3个金色路标"]
const TASK_CARDS := [1,1,0,0,1,2,1,0]
func setup(sim) -> void:
	seed = sim.run_seed
	minimum_card_level=2147483647
	for card: Dictionary in sim.card_pool.cards: minimum_card_level=mini(minimum_card_level,int(card.get("min_crystal_level",1)))
	if minimum_card_level==2147483647: minimum_card_level=1
	field_station={"pos":PROFILE.MEDBAY,"radius":PROFILE.MEDBAY_RADIUS,"hold_seconds":PROFILE.MEDBAY_HOLD_SECONDS,"charge":0.0,"cooldown":0.0,"notice":0.0,"activations":0,"pressure_at":-100.0,"status":"靠近驻守"}
	update_zone(sim.elapsed)
	_refresh_tasks(sim)

func _refresh_tasks(sim) -> void:
	tasks.clear()
	var pairs := [[0,2],[6,7],[4,3],[1,5],[2,6],[7,4],[0,5],[1,3]]
	for index in 2:
		var kind: int = pairs[task_batch % pairs.size()][index]
		var preferred: int = [0,task_batch%4,2,task_batch%4,1,task_batch%4,1,3][kind]
		var district := _task_district(preferred)
		var task := _task(sim,kind,Vector2(district.center))
		task.district_id=district.id; task.district_name=district.name
		tasks.append(task)
	next_tasks_at = (task_batch+1)*120.0

func _task_district(preferred: int) -> Dictionary:
	var requested: Dictionary=PROFILE.DISTRICTS[preferred]
	if ground_distance(requested.center,safe_center)<safe_radius-140.0: return requested
	var closest: Dictionary=PROFILE.DISTRICTS[0]
	for district: Dictionary in PROFILE.DISTRICTS:
		if ground_distance(district.center,safe_center)<ground_distance(closest.center,safe_center): closest=district
	return closest

func _task(sim, kind: int, point: Vector2) -> Dictionary:
	var pos: Vector2 = sim._nearest_walkable_point(point,48.0)
	var shards: Array[Dictionary] = []
	for i in 3:
		var q: Vector2 = sim._nearest_walkable_point(pos+Vector2.from_angle(i*TAU/3.0)*Vector2(175.0,70.0),24.0)
		shards.append({"pos":q,"taken":false})
	if kind==7:
		var visits: Array[Vector2]=[PROFILE.HUB]
		var districts: Array=PROFILE.DISTRICTS.duplicate()
		districts.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return ground_distance(a.center,safe_center)<ground_distance(b.center,safe_center))
		for district: Dictionary in districts:
			if visits.size()>=3: break
			if ground_distance(district.center,safe_center)<safe_radius-80.0: visits.append(district.center)
		while visits.size()<3: visits.append(sim._nearest_walkable_point(PROFILE.HUB+Vector2(220*(visits.size()-1),0),24.0))
		shards.clear()
		for destination: Vector2 in visits: shards.append({"pos":sim._nearest_walkable_point(destination,24.0),"taken":false})
	return {"type":kind,"name":TASK_NAMES[kind],"help":TASK_HELP[kind],"pos":pos,"active":true,"done":false,"progress":0.0,"target":[30.0,30.0,3.0,75.0,6.0,1.0,12.0,3.0][kind],"cooldown":0.0,"shards":shards,"cards":TASK_CARDS[kind],"heal":0.25 if kind==2 else (0.15 if kind==5 else 0.0),"xp":150 if kind in [3,7] else 0}

func reward_text(task: Dictionary) -> String:
	var parts: Array[String] = []
	if int(task.cards)>0: parts.append("选卡%d张" % int(task.cards))
	if float(task.heal)>0: parts.append("恢复%d%%生命" % int(task.heal*100))
	if int(task.xp)>0: parts.append("经验%d" % int(task.xp))
	return " + ".join(parts)

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
	safe_radius = lerpf(3000.0 if cycle==0 else 2200.0,1550.0,shrink)
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
	_tick_field_station(sim,player,dt)
	if sim.elapsed >= next_tasks_at:
		task_batch = floori(sim.elapsed/120.0)
		_refresh_tasks(sim)
	for task: Dictionary in tasks:
		task.cooldown = maxf(0,next_tasks_at-sim.elapsed)
		if task.done: continue
		var distance := ground_distance(Vector2(player.pos),task.pos)
		if int(task.type)==0 and distance < 180.0:
			task.progress = minf(float(task.target),float(task.progress)+dt)
		elif int(task.type)==3:
			task.progress = minf(float(task.target),float(task.progress)+dt)
		elif int(task.type) in [2,7]:
			for shard: Dictionary in task.shards:
				if int(task.type)==7 and not shard.taken:
					if ground_distance(Vector2(player.pos),shard.pos)<90.0: shard.taken=true;task.progress+=1.0
					break
				if not shard.taken and ground_distance(Vector2(player.pos),shard.pos)<90.0:
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

func _tick_field_station(sim, player: Dictionary, dt: float) -> void:
	field_station.cooldown=maxf(0,float(field_station.cooldown)-dt)
	field_station.notice=maxf(0,float(field_station.notice)-dt)
	if float(field_station.cooldown)>0:
		field_station.status="冷却中"; field_station.charge=0.0; return
	if ground_distance(field_station.pos,safe_center)>safe_radius-80.0:
		field_station.status="风暴封锁"; field_station.charge=0.0; return
	var wounded: bool = sim.heroes.any(func(hero: Dictionary)->bool: return hero.hp>0 and hero.hp<float(hero.max_hp)*.95)
	if not wounded:
		field_station.status="生命充足"; field_station.charge=0.0; return
	if ground_distance(player.pos,field_station.pos)>float(field_station.radius):
		field_station.status="靠近驻守"; field_station.charge=0.0; return
	if float(field_station.charge)==0 and sim.elapsed-float(field_station.pressure_at)>=15.0:
		field_station.pressure_at=sim.elapsed
		_spawn_field_station_pressure(sim)
		sim.events.append({"kind":"expedition_station_start","pos":field_station.pos,"life":.7})
	field_station.status="驻守医疗"
	field_station.charge=minf(float(field_station.hold_seconds),float(field_station.charge)+dt)
	if float(field_station.charge)<float(field_station.hold_seconds): return
	var healed_ids: Array[int]=[]
	for hero: Dictionary in sim.heroes:
		if hero.hp<=0: continue
		var amount := minf(float(hero.max_hp)-float(hero.hp),float(hero.max_hp)*PROFILE.MEDBAY_HEAL_RATIO)
		hero.hp+=amount; healed_ids.append(int(hero.id))
		if amount>0: sim.events.append({"kind":"heal","pos":hero.pos,"value":ceili(amount)})
	field_station.activations=int(field_station.activations)+1
	field_station.cooldown=PROFILE.MEDBAY_COOLDOWN; field_station.charge=0.0; field_station.notice=3.0; field_station.status="恢复完成"
	sim.events.append({"kind":"expedition_station_heal","pos":field_station.pos,"hero_ids":healed_ids,"life":.7})

func _spawn_field_station_pressure(sim) -> void:
	var available: int=maxi(0,sim._endless_active_cap()-sim.enemies.size())
	for index in mini(4,available):
		var offset: Vector2=[Vector2(300,-90),Vector2(300,90),Vector2(-240,-100),Vector2(-240,100)][index]
		var enemy: Dictionary=sim.spawn_enemy(sim._nearest_walkable_point(PROFILE.MEDBAY+offset,48.0),"ranged" if index<2 else "armored")
		sim._apply_endless_scaling(enemy,sim._endless_tier())
		enemy.expedition_station_pressure=true

func on_kill(enemy: Dictionary) -> void:
	for task: Dictionary in tasks:
		if task.done or not task.active:continue
		var kind := str(enemy.kind)
		var eligible := false
		match int(task.type):
			1: eligible = ground_distance(Vector2(enemy.pos),task.pos)<=400.0
			4: eligible = kind in ["armored","shielded","hilichurl_brute","warder"]
			5: eligible = kind.begins_with("boss_")
			6: eligible = kind in ["ranged","troop_ranged","troop_cannon","buffer"]
		if eligible:
			task.progress+=1.0
			if float(task.progress)>=float(task.target):_complete(task)

func _complete(task: Dictionary) -> void:
	if task.done:return
	task.done=true
	completed+=1
	reward_queue.append(task.duplicate(true));pending_rewards=reward_queue.size()
	completion_name=str(task.name);completion_reward=reward_text(task);completion_notice=2.0

func open_reward(sim) -> void:
	if reward_queue.is_empty() or sim.state!="running" or completion_notice>0:return
	# A task can finish before the first crystal level-up; keep its card reward until cards unlock.
	reward_waiting_level=0
	var available := 0
	while available<reward_queue.size():
		if int(reward_queue[available].cards)>0 and sim.run_state.crystal_level<minimum_card_level:
			reward_waiting_level=minimum_card_level; available+=1
		else: break
	if available>=reward_queue.size(): return
	var reward: Dictionary = reward_queue.pop_at(available)
	pending_rewards=reward_queue.size();cards_total=int(reward.cards);cards_remaining=cards_total
	for h: Dictionary in sim.heroes:
		if h.hp>0:h.hp=minf(h.max_hp,h.hp+h.max_hp*float(reward.heal))
	if int(reward.xp)>0:sim.grant_xp(int(reward.xp))
	if sim.run_state.crystal_level>=minimum_card_level: reward_waiting_level=0
	if cards_remaining>0 and not sim.open_reward_or_compensate():
		cards_remaining=0

func choose_next(sim) -> void:
	cards_remaining=maxi(0,cards_remaining-1)
	if cards_remaining>0:
		if not sim.open_reward_or_compensate(): cards_remaining=0
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
