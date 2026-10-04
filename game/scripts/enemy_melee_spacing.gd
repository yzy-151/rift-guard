extends RefCounted
## Reserved approach positions, not a per-frame positional repulsion.
const SLOT_COUNT:=8
const RING_STEP:=60.0

static func supports(enemy: Dictionary) -> bool:
	return not bool(enemy.get("flying",false)) and float(enemy.get("speed",0.0))>0.0 and float(enemy.get("damage",0.0))>0.0 and float(enemy.get("attack_range",0.0))<=140.0

static func distance(enemy: Dictionary) -> float:
	if str(enemy.kind).begins_with("boss_"):
		var value:=maxf(112.0,float(enemy.get("size",100.0))*0.65+30.0)
		return minf(value,float(enemy.attack_range)-8.0) if float(enemy.get("attack_range",0.0))>0.0 else value
	if str(enemy.kind)=="hilichurl_brute":return 96.0
	return clampf(42.0+float(enemy.get("size",48.0))*0.4,60.0,84.0)

static func reach(enemy: Dictionary) -> float:
	return maxf(float(enemy.get("attack_range",0.0)),distance(enemy)+12.0)

static func release(enemy: Dictionary) -> void:
	enemy.erase("melee_hero_id")
	enemy.erase("melee_slot")
	enemy.erase("melee_slot_pos")
	enemy.erase("melee_wall_transit")
	enemy.melee_recheck=0.0

static func separation(a: Dictionary,b: Dictionary) -> float:
	return clampf(float(a.get("size",48.0))*0.36+float(b.get("size",48.0))*0.36+10.0,40.0,84.0)

static func target(sim,enemy: Dictionary) -> Dictionary:
	if not supports(enemy):return {}
	if not sim.endless_mode and Array(enemy.get("route_points",[])).size()>1:
		return _lane_blocker(sim,enemy)
	var current:=int(enemy.get("melee_hero_id",-1))
	if current>=0 and current<sim.heroes.size():
		var hero:Dictionary=sim.heroes[current]
		if hero.hp>0 and bool(hero.deployed) and (sim.endless_mode or Vector2(enemy.pos).distance_to(hero.pos)<=reach(enemy)+125.0):return hero
	release(enemy)
	var hero:Dictionary=sim._nearest_live_hero(enemy.pos)
	if hero.is_empty() or (not sim.endless_mode and Vector2(enemy.pos).distance_to(hero.pos)>reach(enemy)+55.0):return {}
	if not sim.endless_mode and sim.terrain_line_blocked(enemy.pos,hero.pos,8.0):return {}
	enemy.melee_hero_id=int(hero.id)
	return hero

static func _lane_blocker(sim,enemy:Dictionary) -> Dictionary:
	var route:Array=enemy.route_points
	var index:=clampi(int(enemy.get("route_index",1)),1,route.size()-1)
	var start:=Vector2(route[index-1]);var finish:=Vector2(route[index])
	if Vector2(enemy.pos).distance_to(Geometry2D.get_closest_point_to_segment(enemy.pos,start,finish))>1.0:
		release(enemy)
		return {}
	enemy.route_returning=false
	var direction:Vector2=(finish-start).normalized()
	var best:Dictionary={};var score:=INF
	for hero:Dictionary in sim.heroes:
		if hero.hp<=0 or not bool(hero.deployed) or int(hero.get("block",0))<=0:continue
		var on_lane:=Geometry2D.get_closest_point_to_segment(hero.pos,start,finish)
		if Vector2(hero.pos).distance_to(on_lane)>28.0:continue
		var ahead:float=(Vector2(hero.pos)-Vector2(enemy.pos)).dot(direction)
		# A blocker cannot pull enemies backward after they have passed it.
		if ahead < -distance(enemy):continue
		if sim.terrain_line_blocked(enemy.pos,hero.pos,8):continue
		if absf(ahead)<score:score=absf(ahead);best=hero
	if best.is_empty():release(enemy)
	else:enemy.melee_hero_id=int(best.id)
	return best

static func on_route(enemy:Dictionary,hero:Dictionary) -> bool:
	var route:Array=enemy.get("route_points",[])
	if route.size()<2:return true
	var index:=clampi(int(enemy.get("route_index",1)),1,route.size()-1)
	var closest:=Geometry2D.get_closest_point_to_segment(hero.pos,route[index-1],route[index])
	return Vector2(hero.pos).distance_to(closest)<=28.0

static func _prepare_lanes(sim) -> void:
	var groups:Dictionary={}
	for other:Dictionary in sim.enemies:
		if other.hp<=0 or not supports(other) or Array(other.get("route_points",[])).size()<2:continue
		var blocker:=_lane_blocker(sim,other)
		if blocker.is_empty():continue
		var route:Array=other.route_points
		var index:=clampi(int(other.route_index),1,route.size()-1)
		var key:="%d:%s:%s" % [int(blocker.id),Vector2(route[index-1]),Vector2(route[index])]
		if not groups.has(key):groups[key]={"hero":blocker,"start":Vector2(route[index-1]),"end":Vector2(route[index]),"units":[]}
		groups[key].units.append(other)
	for group:Dictionary in groups.values():
		var direction:Vector2=(group.end-group.start).normalized()
		var units:Array=group.units
		units.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
			var ahead:float=(Vector2(a.pos)-Vector2(b.pos)).dot(direction)
			return ahead>0.0 if not is_zero_approx(ahead) else int(a.id)<int(b.id))
		var center:=Geometry2D.get_closest_point_to_segment(group.hero.pos,group.start,group.end)
		var hero_offset:float=Vector2(group.hero.pos).distance_squared_to(center)
		# A real overlap with the defender needs temporary room behind the
		# front unit. Otherwise its neighbor stops at its own hero gap and
		# permanently cages the front unit inside the defender's body.
		var recovering:bool=Vector2(units[0].pos).distance_to(group.hero.pos)<distance(units[0])-1.0
		var prefix:=0.0
		for rank in units.size():
			var unit:Dictionary=units[rank]
			var gap:=sqrt(maxf(0,distance(unit)*distance(unit)-hero_offset))
			if rank>0:gap+=separation(unit,units[0])+4.0+prefix
			sim.enemy_crowd.lanes[int(unit.id)]={"rank":rank,"gap":gap,"hero":int(group.hero.id),"hero_pos":Vector2(group.hero.pos),"route_index":int(unit.route_index),"hero_recovery":recovering}
			if rank>0:prefix+=separation(units[rank-1],unit)+4.0
	sim.enemy_crowd.lanes_ready=true

static func _lane_destination(sim,enemy:Dictionary,hero:Dictionary) -> Vector2:
	var route:Array=enemy.route_points
	var index:=clampi(int(enemy.route_index),1,route.size()-1)
	var direction:Vector2=(Vector2(route[index])-Vector2(route[index-1])).normalized()
	var center:=Geometry2D.get_closest_point_to_segment(hero.pos,route[index-1],route[index])
	if not sim.enemy_crowd.active or not sim.enemy_crowd.lanes_ready:_prepare_lanes(sim)
	var entry:Dictionary=sim.enemy_crowd.lanes.get(int(enemy.id),{})
	if entry.is_empty() or int(entry.hero)!=int(hero.id) or Vector2(entry.hero_pos)!=Vector2(hero.pos) or int(entry.route_index)!=index:
		sim.enemy_crowd.invalidate_lanes();_prepare_lanes(sim)
		entry=sim.enemy_crowd.lanes.get(int(enemy.id),{})
	var rank:=int(entry.get("rank",0))
	var gap:=float(entry.get("gap",distance(enemy)))
	var point:=Geometry2D.get_closest_point_to_segment(center-direction*gap,route[index-1],route[index])
	# A full queue stops newcomers where they stand. Its desired spacing must
	# not become an upstream walking order that pushes the whole crowd back.
	# A defender-body overlap also lets that queue make bounded recovery room.
	if (point-Vector2(enemy.pos)).dot(direction)<0.0 and not bool(entry.get("hero_recovery",false)) and Vector2(enemy.pos).distance_to(hero.pos)>=distance(enemy)-1.0:
		point=enemy.pos
	enemy.melee_slot=0 if rank==0 else SLOT_COUNT+rank
	enemy.melee_slot_pos=point
	sim.enemy_crowd.update_slot(enemy)
	return point

static func _slot_point(enemy: Dictionary,hero: Dictionary,index: int) -> Vector2:
	return Vector2(hero.pos)+Vector2.from_angle(float(index%SLOT_COUNT)*TAU/SLOT_COUNT)*(distance(enemy)+float(index/SLOT_COUNT)*RING_STEP)

static func _available(sim,enemy: Dictionary,hero: Dictionary,point: Vector2) -> bool:
	if not sim._movement_bounds().grow(-20.0).has_point(point) or sim._terrain_blocks(point,18.0):return false
	if sim.terrain_line_blocked(point,hero.pos,6.0):return false
	var neighbors:Array=sim.enemy_crowd.nearby(point,true) if sim.enemy_crowd.active else sim.enemies
	for other:Dictionary in neighbors:
		if other.hp<=0 or int(other.id)==int(enemy.id) or not other.has("melee_slot_pos"):continue
		var squared:=point.distance_squared_to(other.melee_slot_pos)
		if squared>=84.0*84.0:continue
		var gap:=separation(enemy,other)
		if squared<gap*gap:return false
	for ally:Dictionary in sim.heroes:
		if int(ally.id)!=int(hero.id) and ally.hp>0 and bool(ally.deployed) and point.distance_to(ally.pos)<distance(enemy)-2.0:return false
	return true

static func destination(sim,enemy: Dictionary,hero: Dictionary,dt: float) -> Vector2:
	if not sim.endless_mode and Array(enemy.get("route_points",[])).size()>1:
		return _lane_destination(sim,enemy,hero)
	# Choose a side of the hero only after rounding walls. Reserving a slot
	# from the far side commits several units to crossing occupied front ranks.
	if sim.terrain_line_blocked(enemy.pos,hero.pos,maxf(12.0,float(enemy.get("size",28.0))*0.25)):
		enemy.melee_wall_transit=true
		enemy.erase("melee_slot")
		enemy.erase("melee_slot_pos")
		enemy.melee_recheck=0.0
		return Vector2(hero.pos)+(Vector2(enemy.pos)-Vector2(hero.pos)).normalized()*distance(enemy)
	# Far reinforcements navigate normally without reserving every nearby slot.
	if Vector2(enemy.pos).distance_to(hero.pos)>distance(enemy)+240.0 and not enemy.has("melee_slot"):
		return Vector2(hero.pos)+(Vector2(enemy.pos)-Vector2(hero.pos)).normalized()*distance(enemy)
	enemy.melee_recheck=maxf(0.0,float(enemy.get("melee_recheck",0.0))-dt)
	var index:=int(enemy.get("melee_slot",-1))
	var existing:Vector2=_slot_point(enemy,hero,index) if index>=0 else Vector2.ZERO
	if float(enemy.melee_recheck)>0.0:
		if index<0:return enemy.pos
		enemy.melee_slot_pos=existing
		sim.enemy_crowd.update_slot(enemy)
		return existing
	if index>=0 and not _available(sim,enemy,hero,existing):index=-1
	if index<0 or index>=SLOT_COUNT:
		var best:=INF
		var selected:=-1
		for ring in 4:
			for slot in SLOT_COUNT:
				var candidate_index:=ring*SLOT_COUNT+slot
				var candidate:=_slot_point(enemy,hero,candidate_index)
				if not _available(sim,enemy,hero,candidate):continue
				var score:=Vector2(enemy.pos).distance_squared_to(candidate)
				if score<best:best=score;selected=candidate_index
			if selected>=0:break
		if selected>=0:index=selected
	# Stagger rechecks so a full waiting ring does not rescan every frame or
	# release all its queued work on one frame. Movement still checks bodies.
	enemy.melee_recheck=0.30+float(int(enemy.id)%11)*0.027
	if index<0:return enemy.pos
	enemy.melee_slot=index
	var result:=_slot_point(enemy,hero,index)
	enemy.melee_slot_pos=result
	sim.enemy_crowd.update_slot(enemy)
	return result

static func _step_clear(sim,enemy: Dictionary,start: Vector2,finish: Vector2) -> bool:
	if start.distance_squared_to(finish)<0.000001:return true
	# A displaced unit must finish rejoining before it can reserve a queue slot.
	# Existing overlapping knockback/spawn bodies may separate during that step.
	if not sim.endless_mode and bool(enemy.get("route_returning",false)):return true
	var neighbors:Array=sim.enemy_crowd.nearby(finish) if sim.enemy_crowd.active else sim.enemies
	for other:Dictionary in neighbors:
		if other.hp<=0 or int(other.id)==int(enemy.id) or bool(other.get("flying",false)):continue
		if sim.endless_mode and not other.has("melee_slot_pos"):continue
		if not sim.endless_mode and bool(other.get("route_returning",false)):continue
		if not sim.endless_mode and not _shared_road(enemy,other):continue
		# A unit rounding the next corner occupies space before it reserves an
		# attack slot. Stop followers early instead of later pushing them back.
		var before:=start.distance_squared_to(other.pos)
		var after:=finish.distance_squared_to(other.pos)
		if after>=84.0*84.0:continue
		var gap:=separation(enemy,other)-2.0
		if after<gap*gap and after<before-0.01:return false
	return true

static func _shared_road(a:Dictionary,b:Dictionary) -> bool:
	# Authored roads can run closer together than a body's diameter. Parallel
	# lanes and crossings have independent traffic until they actually merge;
	# otherwise two advancing queues can hold each other forever at a junction.
	if str(a.get("route_id",""))==str(b.get("route_id","")):return true
	var ar:Array=a.get("route_points",[]);var br:Array=b.get("route_points",[])
	if ar.size()<2 or br.size()<2:return true
	var ai:=clampi(int(a.get("route_index",1)),1,ar.size()-1)
	var bi:=clampi(int(b.get("route_index",1)),1,br.size()-1)
	return Vector2(b.pos).distance_squared_to(Geometry2D.get_closest_point_to_segment(b.pos,ar[ai-1],ar[ai]))<=1.0 or Vector2(a.pos).distance_squared_to(Geometry2D.get_closest_point_to_segment(a.pos,br[bi-1],br[bi]))<=1.0

static func advance(sim,enemy: Dictionary,hero: Dictionary,slot: Vector2,step: float,dt: float) -> Vector2:
	var start:=Vector2(enemy.pos)
	if not sim.endless_mode and Array(enemy.get("route_points",[])).size()>1:
		var candidate:Vector2=sim._move_with_terrain(start,slot,step,maxf(12.0,float(enemy.get("size",28.0))*0.34))
		return candidate if _step_clear(sim,enemy,start,candidate) else start
	var relative:=start-Vector2(hero.pos)
	var gap:=distance(enemy)
	var aim:=slot
	if start.distance_squared_to(slot)<0.01 and relative.length()>=gap-1.0:return start
	if relative.length()<gap-1.0:
		var outward:=relative.normalized() if relative.length_squared()>1.0 else (slot-Vector2(hero.pos)).normalized()
		aim=Vector2(hero.pos)+outward*gap
		step=maxf(step,110.0*dt)
	elif (not bool(enemy.get("melee_wall_transit",false)) or relative.length()<=gap+24.0) and Geometry2D.get_closest_point_to_segment(hero.pos,start,slot).distance_to(hero.pos)<gap-2.0:
		var turn:=wrapf((slot-Vector2(hero.pos)).angle()-relative.angle(),-PI,PI)
		aim=Vector2(hero.pos)+relative.normalized().rotated(clampf(turn,-0.25,0.25))*maxf(gap+3.0,relative.length())
	var navigation_radius:=maxf(12.0,float(enemy.get("size",28.0))*0.25)
	if sim.terrain_line_blocked(start,aim,navigation_radius):
		aim=sim._enemy_navigation_target(enemy,aim,navigation_radius,dt)
	else:
		enemy.erase("nav_waypoint")
	var direction:Vector2=(aim-start).normalized()
	for angle:float in [0.0,0.65,-0.65,1.1,-1.1]:
		var candidate:Vector2=sim._move_with_terrain(start,aim if angle==0.0 else start+direction.rotated(angle)*step,step,navigation_radius)
		if _step_clear(sim,enemy,start,candidate):return candidate
	return start

static func ready(sim,enemy: Dictionary,hero: Dictionary) -> bool:
	var tolerance:=8.0 if sim.endless_mode else 0.5
	return int(enemy.get("melee_slot",SLOT_COUNT))<SLOT_COUNT and Vector2(enemy.pos).distance_to(enemy.get("melee_slot_pos",enemy.pos))<=tolerance and Vector2(enemy.pos).distance_to(hero.pos)<=reach(enemy) and not sim.terrain_line_blocked(enemy.pos,hero.pos,6.0)
