extends RefCounted
## Basic attacks have a finite hit budget, shared by every visual delivery.
const MAX_PROJECTILES := 4
const MAX_PIERCE := 3
const MAX_BOUNCE := 3
const EXTRA_SHOT_SCALE := 0.60
const PIERCE_SCALE := 0.75
const BOUNCE_SCALE := 0.65
const BOUNCE_REACH := 140.0

static func eligible(sim,hero:Dictionary,enemy:Dictionary) -> bool:
	var air:bool=bool(hero.get("can_hit_air",false)) or int(hero.get("block",0))<=0 or (str(hero.get("character_id",""))=="traveler" and not str(hero.get("element","")).is_empty())
	return enemy.hp>0 and (not bool(enemy.get("flying",false)) or air) and sim.is_in_attack_range(hero,enemy.pos)

static func _neighbor(sim,hero:Dictionary,origin:Dictionary,excluded:Array,radius:float) -> Dictionary:
	var best:Dictionary={};var nearest:=radius*radius
	for candidate:Dictionary in sim.enemies:
		if int(candidate.id) in excluded or not eligible(sim,hero,candidate):continue
		var distance:=Vector2(origin.pos).distance_squared_to(candidate.pos)
		if distance>nearest or sim.terrain_line_blocked(origin.pos,candidate.pos,3):continue
		nearest=distance;best=candidate
	return best

static func clamp_growth(hero: Dictionary) -> void:
	hero.projectile_count = clampi(int(hero.get("projectile_count",1)),1,MAX_PROJECTILES)
	hero.pierce = clampi(int(hero.get("pierce",0)),0,MAX_PIERCE)
	hero.chain_count = clampi(int(hero.get("chain_count",0)),0,MAX_BOUNCE)
	hero.blast_radius = clampf(float(hero.get("blast_radius",0)),0,120)
	hero.echo_ratio = clampf(float(hero.get("echo_ratio",0)),0,0.60)
	hero.range = minf(float(hero.range),float(hero.get("base_range",hero.range))*1.6)

static func launch_attack(sim, hero: Dictionary, victim: Dictionary, damage: float, critical: bool, index: int = 0) -> void:
	if not sim.performance_budget.allow_projectile(sim.projectiles.size()): return
	var direction := (Vector2(victim.pos)-Vector2(hero.pos)).normalized()
	if direction.length_squared()<0.1: direction=Vector2.RIGHT
	var reach:float=sim.attack_range_screen_radii(hero).x
	var shot := {"basic_attack":true,"visual_id":sim.next_projectile_id,"pos":Vector2(hero.pos),"previous_pos":Vector2(hero.pos),"origin":Vector2(hero.pos),"target_pos":Vector2(victim.pos),"target_id":int(victim.id),"source_id":int(hero.id),"damage":damage,"element":hero.element,"secondary_element":hero.get("secondary_element",""),"splash":hero.get("splash",false),"slow":hero.get("slow",false),"pierce":mini(MAX_PIERCE,int(hero.get("pierce",0))),"chain_count":mini(MAX_BOUNCE,int(hero.get("chain_count",0))),"blast_radius":minf(120,float(hero.get("blast_radius",0))),"echo_ratio":minf(0.60,float(hero.get("echo_ratio",0))),"critical":critical,"style":str(hero.get("attack_style","standard")),"delivery":str(hero.get("attack_delivery","homing")),"velocity":direction*560.0,"age":0.0,"life":3.0,"reach":float(hero.range),"travelled":0.0,"hit_ids":[],"returning":false,"radius":14.0,"index":index,"bouncing":false}
	shot.reach=reach
	sim.projectiles.append(shot)
	sim.next_projectile_id+=1

static func attack_hit(sim, shot: Dictionary, enemy: Dictionary, hero: Dictionary) -> void:
	var damage := float(shot.damage)
	sim.apply_hit(enemy,damage,str(shot.element),int(hero.id))
	var secondary: String = sim.normalize_element(str(shot.get("secondary_element","")))
	if not secondary.is_empty() and enemy.hp>0: sim.apply_hit(enemy,damage*0.85,secondary,int(hero.id))
	if bool(shot.get("slow",false)): enemy.slow_timer=maxf(float(enemy.get("slow_timer",0)),2.0)
	# Blast is an explicit upgrade. Transfers cannot multiply its area damage.
	if not bool(shot.get("extras_used",false)):
		shot.extras_used=true
		var radius := minf(120,float(shot.get("blast_radius",hero.get("blast_radius",0))))
		if bool(shot.get("splash",false)): radius=maxf(radius,65)
		if radius>0:
			var excluded:Array=[int(enemy.id)]
			for i in 3:
				var neighbor:Dictionary=_neighbor(sim,hero,enemy,excluded,radius)
				if neighbor.is_empty():break
				excluded.append(int(neighbor.id))
				sim.apply_hit(neighbor,damage*0.40,str(shot.element),int(hero.id))
			sim.events.append({"kind":"splash","pos":enemy.pos,"radius":radius})
		var echo := minf(0.60,float(shot.get("echo_ratio",hero.get("echo_ratio",0))))
		if echo>0 and enemy.hp>0:sim.apply_hit(enemy,damage*echo,str(shot.element),int(hero.id))
	if bool(shot.get("critical",false)): sim.events.append({"kind":"critical","pos":enemy.pos,"value":ceili(damage)})

static func _bounce(sim, shot:Dictionary, enemy:Dictionary, hero:Dictionary) -> bool:
	if int(shot.chain_count)<=0:return false
	var next:Dictionary=_neighbor(sim,hero,enemy,shot.hit_ids,BOUNCE_REACH)
	if next.is_empty() or sim.terrain_line_blocked(enemy.pos,next.pos,3):return false
	shot.chain_count=int(shot.chain_count)-1
	shot.damage=float(shot.damage)*BOUNCE_SCALE
	shot.bouncing=true;shot.delivery="homing";shot.pierce=0
	shot.target_id=int(next.id);shot.pos=Vector2(enemy.pos);shot.target_pos=Vector2(next.pos)
	shot.velocity=(Vector2(next.pos)-Vector2(enemy.pos)).normalized()*560.0
	sim.events.append({"kind":"chain","pos":enemy.pos,"target_pos":next.pos,"source_id":hero.id})
	return true

static func _contact(sim, shot:Dictionary, enemy:Dictionary, hero:Dictionary) -> bool:
	shot.hit_ids.append(int(enemy.id))
	attack_hit(sim,shot,enemy,hero)
	var straight_target:=false
	if int(shot.pierce)>0:
		var direction:=Vector2(shot.velocity).normalized()
		for candidate:Dictionary in sim.enemies:
			if int(candidate.id) in shot.hit_ids or not eligible(sim,hero,candidate):continue
			var relative:=Vector2(candidate.pos)-Vector2(enemy.pos)
			if relative.dot(direction)>0 and absf(relative.cross(direction))<=float(shot.radius):straight_target=true;break
	if int(shot.pierce)>0 and straight_target:
		shot.pierce=int(shot.pierce)-1;shot.damage=float(shot.damage)*PIERCE_SCALE
		shot.delivery="piercing"
		sim.events.append({"kind":"pierce","pos":enemy.pos})
		return true
	return _bounce(sim,shot,enemy,hero)

static func tick_attack(sim, shot: Dictionary, dt: float) -> bool:
	var id:=int(shot.source_id)
	if id<0 or id>=sim.heroes.size():return false
	var hero:Dictionary=sim.heroes[id]
	if hero.hp<=0 or not bool(hero.get("deployed",true)):return false
	shot.age=float(shot.age)+dt;shot.life=float(shot.life)-dt
	if float(shot.life)<=0:return false
	var start:=Vector2(shot.pos)
	var delivery:=str(shot.delivery)
	if delivery in ["homing","lob"]:
		var target:Dictionary=sim.find_enemy(int(shot.target_id))
		if target.is_empty() or not eligible(sim,hero,target):return false
		var end:=Vector2(target.pos)
		var finish:=start.move_toward(end,560.0*dt)
		shot.previous_pos=start;shot.pos=finish;shot.travelled=float(shot.travelled)+start.distance_to(finish)
		if sim.terrain_line_blocked(start,finish,3):return false
		if delivery=="lob":shot.arc_height=sin(clampf(float(shot.age)/maxf(0.01,Vector2(shot.origin).distance_to(end)/560.0),0,1)*PI)*48.0
		if finish.distance_to(end)<=0.1:return _contact(sim,shot,target,hero)
		return true
	var remaining:=maxf(0,float(shot.reach)-float(shot.travelled))
	var finish:=start+Vector2(shot.velocity).normalized()*minf(560.0*dt,remaining)
	shot.previous_pos=start;shot.pos=finish;shot.travelled=float(shot.travelled)+start.distance_to(finish)
	if sim.terrain_line_blocked(start,finish,3):return false
	var targets:Array[Dictionary]=[]
	for e:Dictionary in sim.enemies:
		if int(e.id) in shot.hit_ids or not eligible(sim,hero,e):continue
		if Geometry2D.get_closest_point_to_segment(e.pos,start,finish).distance_to(e.pos)<=float(shot.radius):targets.append(e)
	targets.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return start.distance_squared_to(a.pos)<start.distance_squared_to(b.pos))
	for e:Dictionary in targets:
		if not _contact(sim,shot,e,hero):return false
		if bool(shot.bouncing):return true
	if float(shot.travelled)>=float(shot.reach):return false
	return true

static func resolve_melee(sim, impact:Dictionary, hero:Dictionary) -> void:
	var victim:Dictionary=sim.find_enemy(int(impact.get("target_id",-1)))
	if victim.is_empty() or not eligible(sim,hero,victim) or sim.terrain_line_blocked(hero.pos,victim.pos,3):return
	if impact.has("geometry") and not sim.is_in_skill_geometry(impact.geometry,victim.pos):return
	var strike:=impact.duplicate(true)
	strike.hit_ids=[int(victim.id)];strike.blast_radius=hero.get("blast_radius",0);strike.echo_ratio=hero.get("echo_ratio",0)
	strike.slow=hero.get("slow",false)
	attack_hit(sim,strike,victim,hero)
	var last:=victim
	var count:=mini(MAX_PIERCE,int(hero.get("pierce",0)))
	if bool(hero.get("cleave",false)):count=maxi(count,1)
	for i in count:
		var next:Dictionary={};var best:=INF
		for e:Dictionary in sim.enemies:
			if int(e.id) in strike.hit_ids or not eligible(sim,hero,e):continue
			if impact.has("geometry") and not sim.is_in_skill_geometry(impact.geometry,e.pos):continue
			if sim.terrain_line_blocked(hero.pos,e.pos,3):continue
			var distance:float=Vector2(e.pos).distance_squared_to(last.pos)
			if distance<best:best=distance;next=e
		if next.is_empty():break
		strike.hit_ids.append(int(next.id));strike.damage=float(strike.damage)*PIERCE_SCALE
		attack_hit(sim,strike,next,hero);last=next
	if int(hero.get("chain_count",0))>0:
		var before:int=sim.projectiles.size()
		launch_attack(sim,hero,last,float(strike.damage),false)
		if sim.projectiles.size()==before:return
		var shot:Dictionary=sim.projectiles[-1]
		shot.hit_ids=strike.hit_ids;shot.extras_used=true;shot.pierce=0
		if not _bounce(sim,shot,last,hero):sim.projectiles.pop_back()
	sim.events.append({"kind":"synced_impact","pos":victim.pos,"hero_id":hero.id,"value":ceili(float(impact.damage))})
