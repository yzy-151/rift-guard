extends RefCounted
# Gameplay owns all endpoints and hit timing; the view only renders this state.
const KINDS := ["needle_barrage", "arcane_lance", "chimera", "salon_summon", "hydro_fanfare"]

static func handles(kind: String) -> bool:
	return kind in KINDS

static func target_point(sim, hero: Dictionary, ability: Dictionary, target: Vector2) -> Vector2:
	if str(ability.kind) == "hydro_fanfare":
		return Vector2(hero.pos)
	var origin := Vector2(hero.pos)
	var delta := target - origin
	var reach := float(ability.get("cast_range", 480.0))
	if str(ability.kind) == "needle_barrage":
		var direction := delta.normalized() if delta.length_squared() > 1.0 else Vector2.RIGHT
		return origin + direction * float(ability.get("radius", 620.0)) * (1.0 + sim.skill_area_bonus)
	return origin + delta.limit_length(reach)

static func start(sim, hero: Dictionary, ability: Dictionary, target: Vector2, power: float, radius: float) -> void:
	var kind := str(ability.kind)
	var duration: float = {"needle_barrage":3.2, "arcane_lance":2.2, "chimera":2.6, "salon_summon":12.0, "hydro_fanfare":12.0}[kind]
	var zone := {"kind":kind, "signature":true, "pos":target, "source":Vector2(hero.pos), "hero_id":int(hero.id), "life":duration, "total":duration, "elapsed":0.0, "power":power, "area":radius, "pulse":0.0, "shots":[], "released":0, "hit_ids":[], "timers":[0.2,0.6,1.0]}
	if kind == "needle_barrage":
		zone.pos = target_point(sim, hero, ability, target)
		zone["direction"] = (Vector2(zone.pos) - Vector2(hero.pos)).normalized()
	elif kind == "chimera":
		hero.hp = maxf(1.0, float(hero.hp) - float(hero.max_hp) * 0.08)
	elif kind == "hydro_fanfare":
		zone.pos = Vector2(hero.pos)
		sim._damage_area(zone.pos, radius, power, "hydro", int(hero.id))
	sim.skill_effects.append(zone)
	sim.events.append({"kind":"signature_start", "skill":kind, "pos":zone.pos, "source":hero.pos, "radius":radius})

static func candidates(sim, center: Vector2, radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for enemy: Dictionary in sim.enemies:
		if enemy.hp > 0.0 and sim._ability_target_visible(enemy.pos) and sim.is_in_ability_area(center, enemy.pos, radius):
			result.append(enemy)
	result.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return Vector2(a.pos).distance_squared_to(center) < Vector2(b.pos).distance_squared_to(center))
	return result

static func segment_hit(point: Vector2, start: Vector2, end: Vector2, width: float) -> bool:
	return Geometry2D.get_closest_point_to_segment(point, start, end).distance_squared_to(point) <= width * width

static func tick(sim, zone: Dictionary, dt: float) -> bool:
	var id := int(zone.hero_id)
	if id < 0 or id >= sim.heroes.size():
		return false
	var hero: Dictionary = sim.heroes[id]
	zone.life = maxf(0.0, float(zone.life) - dt)
	zone.elapsed = float(zone.total) - float(zone.life)
	if hero.hp <= 0.0 or not bool(hero.deployed):
		zone.life = minf(float(zone.life),0.4)
		zone["cancelled"] = true
	if bool(zone.get("cancelled",false)):
		return float(zone.life) > 0.0
	match str(zone.kind):
		"needle_barrage": _needles(sim,zone,dt)
		"arcane_lance": _black_shards(sim,zone,dt)
		"chimera": _chimera(sim,zone)
		"salon_summon": _salon(sim,zone,dt)
		"hydro_fanfare":
			zone.pos = Vector2(hero.pos)
			zone.pulse = float(zone.pulse)-dt
			if float(zone.pulse) <= 0.0 and float(zone.life) > 0.4:
				zone.pulse += 2.0
				var recipients: Array[Vector2] = []
				for ally: Dictionary in sim.heroes:
					if ally.hp > 0.0 and bool(ally.deployed) and sim.is_in_ability_area(zone.pos,ally.pos,float(zone.area)):
						ally.hp = minf(float(ally.max_hp),float(ally.hp)+20.0+float(hero.damage)*0.15)
						recipients.append(ally.pos)
				sim.events.append({"kind":"signature_heal", "pos":zone.pos, "targets":recipients, "radius":zone.area})
	return float(zone.life) > 0.0

static func _needles(sim, zone: Dictionary, dt: float) -> void:
	while int(zone.released)<15 and float(zone.elapsed)>=float(int(zone.released)/5)*0.65+float(int(zone.released)%5)*0.066:
		var index := int(zone.released)
		if index % 5 == 0:
			sim.events.append({"kind":"signature_needle_volley","pos":zone.source,"volley":index/5})
		var direction := Vector2(zone.direction)
		var side := Vector2(-direction.y,direction.x)
		var offset: float = [0.0,-34.0,34.0,-62.0,62.0][index % 5]
		var source := Vector2(zone.source)-direction*20.0+side*offset
		zone.shots.append({"pos":source,"start":source,"age":0.0,"index":index,"hits":[],"done":false})
		zone.released = index+1
	for shot: Dictionary in zone.shots:
		if bool(shot.done): continue
		var previous := Vector2(shot.pos)
		shot.age = float(shot.age)+dt
		var distance := float(shot.age)*900.0
		var direction := Vector2(zone.direction)
		var offset := Vector2(shot.start)-Vector2(zone.source)
		shot.pos = Vector2(zone.source)+direction*minf(distance,float(zone.area))+offset*(1.0-smoothstep(0.0,125.0,distance))
		for enemy: Dictionary in sim.enemies.duplicate():
			if enemy.hp <= 0.0 or int(enemy.id) in shot.hits: continue
			if segment_hit(enemy.pos,previous,shot.pos,18.0):
				shot.hits.append(int(enemy.id))
				sim.apply_hit(enemy,float(zone.power),"",int(zone.hero_id))
				enemy.slow_timer = maxf(float(enemy.get("slow_timer",0.0)),2.0)
				sim.events.append({"kind":"signature_needle_hit","pos":enemy.pos,"direction":direction})
		if distance >= float(zone.area):
			shot.done = true
			shot["ended_at"] = float(zone.elapsed)

static func _black_shards(sim, zone: Dictionary, dt: float) -> void:
	while int(zone.released)<6 and float(zone.elapsed)>=float(zone.released)*0.12:
		var index := int(zone.released)
		var targets := candidates(sim,zone.pos,float(zone.area))
		if not targets.is_empty():
			var victim: Dictionary = targets[index % mini(3,targets.size())]
			zone.shots.append({"pos":Vector2(zone.source),"previous":Vector2(zone.source),"target_id":int(victim.id),"age":0.0,"index":index,"done":false})
		zone.released = index+1
	for shot: Dictionary in zone.shots:
		if bool(shot.done): continue
		var enemy: Dictionary = sim.find_enemy(int(shot.target_id))
		if enemy.is_empty() or enemy.hp <= 0.0:
			shot.done = true
			continue
		shot.age = float(shot.age)+dt
		shot.previous = shot.pos
		shot.pos = Vector2(shot.pos).move_toward(enemy.pos,650.0*dt)
		if Vector2(shot.pos).distance_to(enemy.pos) <= 12.0:
			sim.apply_hit(enemy,float(zone.power)*0.55,"electro",int(zone.hero_id))
			var previous := int(enemy.get("amiya_marks",0)) if float(enemy.get("amiya_mark_until",0.0)) > sim.elapsed else 0
			enemy.amiya_marks = mini(3,previous+1)
			enemy.amiya_mark_until = sim.elapsed+8.0
			shot.done = true
			sim.events.append({"kind":"signature_black_hit","pos":enemy.pos,"marks":enemy.amiya_marks})

static func _chimera(sim, zone: Dictionary) -> void:
	var thresholds := [0.8,1.15,1.5]
	while int(zone.released)<3 and float(zone.elapsed)>=thresholds[int(zone.released)]:
		var index := int(zone.released)
		var hit_positions: Array[Vector2] = []
		for enemy: Dictionary in candidates(sim,zone.pos,float(zone.area)):
			var marks := int(enemy.get("amiya_marks",0)) if float(enemy.get("amiya_mark_until",0.0)) > sim.elapsed else 0
			var bonus := 1.0+float(marks)*0.3 if index==2 else 1.0
			sim.apply_hit(enemy,float(zone.power)*(0.35 if index<2 else 1.2)*bonus,"electro",int(zone.hero_id))
			enemy.slow_timer = maxf(float(enemy.get("slow_timer",0.0)),2.0)
			if index==2: enemy.amiya_marks = 0
			hit_positions.append(enemy.pos)
		sim.events.append({"kind":"signature_chimera_pulse","pos":zone.pos,"radius":zone.area,"index":index,"targets":hit_positions})
		zone.released = index+1

static func salon_position(zone: Dictionary, index: int) -> Vector2:
	var angle := float(index)*TAU/3.0+float(zone.elapsed)*0.35
	return Vector2(zone.pos)+Vector2(cos(angle)*float(zone.area)*0.39,sin(angle)*float(zone.area)*0.19)

static func _salon(sim, zone: Dictionary, dt: float) -> void:
	for index in 3:
		if float(zone.life)<=0.9: continue
		zone.timers[index] = float(zone.timers[index])-dt
		if float(zone.timers[index])>0.0: continue
		zone.timers[index] += [0.85,1.3,1.8][index]
		var targets := candidates(sim,zone.pos,float(zone.area))
		if targets.is_empty(): continue
		var target: Dictionary = targets[index % targets.size()]
		var source := salon_position(zone,index)
		# Travel and impact use the same destination; no invisible full-stage damage.
		zone.shots.append({"pos":source,"source":source,"target":Vector2(target.pos),"age":0.0,"index":index,"done":false})
	for shot: Dictionary in zone.shots:
		if bool(shot.done): continue
		shot.age = float(shot.age)+dt
		var t := clampf(float(shot.age)/0.38,0.0,1.0)
		shot.pos = Vector2(shot.source).lerp(Vector2(shot.target),t)
		if t>=1.0:
			shot.done = true
			var splash: float = [38.0,65.0,90.0][int(shot.index)]
			for enemy: Dictionary in candidates(sim,shot.target,splash):
				if sim.is_in_ability_area(zone.pos,enemy.pos,float(zone.area)):
					sim.apply_hit(enemy,float(zone.power)*[0.55,0.75,1.0][int(shot.index)],"hydro",int(zone.hero_id))
			sim.events.append({"kind":"signature_salon_hit","pos":shot.target,"radius":splash,"index":shot.index})
	# Bound allocations for twelve-second summons and endless sessions.
	zone.shots = zone.shots.filter(func(shot: Dictionary) -> bool: return not bool(shot.done))

static func outgoing_multiplier(sim, id: int) -> float:
	if id<0 or id>=sim.heroes.size(): return 1.0
	for zone: Dictionary in sim.skill_effects:
		if bool(zone.get("signature",false)) and str(zone.kind)=="hydro_fanfare" and float(zone.life)>0.4 and not bool(zone.get("cancelled",false)):
			var owner: Dictionary = sim.heroes[int(zone.hero_id)]
			if owner.hp>0.0 and bool(owner.deployed) and sim.is_in_ability_area(owner.pos,sim.heroes[id].pos,float(zone.area)):
				return 1.35
	return 1.0
