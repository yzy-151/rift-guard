extends RefCounted
const Skills = preload("res://scripts/hero_signature_skills.gd")
const AQUA = Color("#6df5e3")
const INK = Color("#241637")
const PINK = Color("#f0a1ee")
const BLUE = Color("#72d5ff")
const GOLD = Color("#ffde9b")

static func ellipse(v, center: Vector2, radius: float, color: Color, alpha: float) -> void:
	v._draw_skill_area_ellipse(center,radius,color,alpha)

static func crystal(v, point: Vector2, direction: Vector2, size: float, color: Color, alpha: float) -> void:
	if size < 0.1 or alpha < 0.005 or direction.length_squared() < 0.001: return
	var side = Vector2(-direction.y,direction.x)
	var shape = PackedVector2Array([point+direction*size,point+side*size*0.33,point-direction*size*0.65,point-side*size*0.33,point+direction*size])
	v.draw_colored_polygon(shape,Color(INK,alpha*0.95))
	v.draw_polyline(shape,Color(color,alpha),2.0,true)
	v.draw_line(point-direction*size*0.4,point+direction*size,Color.WHITE*Color(1,1,1,alpha*0.8),1.2,true)

static func needle(v, point: Vector2, direction: Vector2, alpha: float) -> void:
	var side = Vector2(-direction.y,direction.x)
	v.draw_line(point-direction*68.0,point,Color(AQUA,alpha*0.1),13.0,true)
	v.draw_line(point-direction*52.0,point,Color(AQUA,alpha*0.4),5.0,true)
	v.draw_colored_polygon(PackedVector2Array([point+direction*19.0,point-direction*14.0+side*3.0,point-direction*35.0,point-direction*14.0-side*3.0]),Color(0.86,1.0,0.96,alpha))
	v.draw_arc(point-direction*30.0,4.0,0,TAU,12,Color(AQUA,alpha),1.4,true)
	var thread = PackedVector2Array()
	for i in 12:
		var t = float(i)/11.0
		thread.append(point-direction*(35.0+60.0*t)+side*sin(t*8.0+v.clock*13.0)*4.0*t)
	v.draw_polyline(thread,Color(AQUA,alpha*0.65),1.6,true)

static func draw_preview(v, hero: Dictionary, ability: Dictionary, target: Vector2) -> void:
	var kind = str(ability.kind)
	var end = Skills.target_point(v.sim,hero,ability,target)
	if kind == "needle_barrage":
		var source = Vector2(hero.pos)
		var direction = (end-source).normalized()
		var normal = Vector2(-direction.y,direction.x)
		var side = normal*18.0
		var launch = source-direction*20.0
		var converge = source+direction*125.0
		var polygon = PackedVector2Array([v.world_to_screen(launch+normal*80.0),v.world_to_screen(converge+side),v.world_to_screen(end+side),v.world_to_screen(end-side),v.world_to_screen(converge-side),v.world_to_screen(launch-normal*80.0),v.world_to_screen(launch+normal*80.0)])
		v.draw_colored_polygon(polygon,Color(AQUA,0.10))
		v.draw_polyline(polygon,Color(AQUA,0.75),1.6,true)
		v.draw_dashed_line(v.world_to_screen(source),v.world_to_screen(end),Color(AQUA,0.6),1.5,14.0)
	else:
		ellipse(v,end,float(ability.radius)*(1.0+v.sim.skill_area_bonus),PINK if kind in ["arcane_lance","chimera"] else BLUE,0.85)
		if kind != "hydro_fanfare": v.draw_dashed_line(v.world_to_screen(hero.pos),v.world_to_screen(end),Color(1,1,1,0.35),1.0,12.0)

static func draw_cast(v, effect: Dictionary) -> void:
	var kind = str(effect.kind)
	var progress = clampf(1.0-float(effect.life)/float(effect.total),0.0,1.0)
	var source = Vector2(effect.caster_pos)
	var target = Vector2(effect.pos)
	var origin = v.world_to_screen(source)+Vector2(0,-22)
	if kind.begins_with("gwen_needle"):
		var dir = (v.world_to_screen(target)-v.world_to_screen(source)).normalized()
		for i in 5:
			var side = Vector2(-dir.y,dir.x)
			var p = origin-dir*(28.0+float(abs(i-2))*14.0)+side*float(i-2)*20.0
			needle(v,p,dir,progress*0.7)
	else:
		var color = PINK if kind.begins_with("amiya_") else BLUE
		ellipse(v,target,float(effect.radius),color,progress*0.55)
		for i in 6:
			var a = float(i)*TAU/6.0+v.clock
			crystal(v,origin+Vector2(cos(a),sin(a))*32.0,Vector2(cos(a),sin(a)),7.0,color,progress)

static func draw_zone(v, zone: Dictionary) -> void:
	var alpha = minf(smoothstep(0.0,0.20,float(zone.elapsed)),smoothstep(0.0,0.5,float(zone.life)))
	if bool(zone.get("cancelled",false)): alpha *= float(zone.life)/0.4
	var kind = str(zone.kind)
	var center = v.world_to_screen(zone.pos)+Vector2(0,8)
	var radii: Vector2 = v.sim.ability_area_screen_radii(zone.pos,float(zone.area))
	match kind:
		"needle_barrage":
			var direction = (v.world_to_screen(zone.pos)-v.world_to_screen(zone.source)).normalized()
			for shot: Dictionary in zone.shots:
				var tail_alpha = 1.0-smoothstep(0.0,0.2,float(zone.elapsed)-float(shot.get("ended_at",zone.elapsed))) if bool(shot.done) else 1.0
				needle(v,v.world_to_screen(shot.pos),direction,alpha*tail_alpha)
		"arcane_lance":
			for shot: Dictionary in zone.shots:
				if bool(shot.done): continue
				var p = v.world_to_screen(shot.pos)+Vector2(0,-14)
				var direction = (p-v.world_to_screen(shot.previous)).normalized()
				v.draw_line(p-direction*45.0,p,Color(PINK,alpha*0.16),9.0,true)
				crystal(v,p,direction,15.0,PINK,alpha)
				for trail in 3:
					crystal(v,p-direction*float(trail+1)*15.0, direction,5.0,PINK,alpha*(0.4-float(trail)*0.1))
		"chimera":
			ellipse(v,zone.pos,float(zone.area),PINK,alpha*0.65)
			var growth = smoothstep(0.0,0.8,float(zone.elapsed))
			for i in 10:
				var a = float(i)*TAU/10.0
				var base = center+Vector2(cos(a)*radii.x,sin(a)*radii.y)*0.78
				var height = (24.0+float(i%3)*12.0)*growth
				crystal(v,base+Vector2(0,-height*0.5),Vector2.UP,height,PINK,alpha*0.8)
			for ring in 3:
				var t = fposmod(float(zone.elapsed)*0.7+float(ring)/3.0,1.0)
				v._draw_dedicated_arc(center,radii*(1.0-t*0.82),0,TAU,Color(PINK,alpha*(1.0-t)*0.35),2.0)
			var shard = center+Vector2(0,-55.0-growth*25.0)
			crystal(v,shard,Vector2.UP,40.0+growth*15.0,PINK,alpha)
			v.draw_line(shard,center,Color(PINK,alpha*0.4),3.0,true)
		"salon_summon":
			ellipse(v,zone.pos,float(zone.area),BLUE,alpha*0.55)
			for i in 3:
				salon_actor(v,v.world_to_screen(Skills.salon_position(zone,i))+Vector2(0,-10),i,alpha)
			for shot: Dictionary in zone.shots:
				var p = v.world_to_screen(shot.pos)+Vector2(0,-9-sin(float(shot.age)/0.38*PI)*20.0)
				v.draw_circle(p,7.0+float(shot.index)*2.0,Color(BLUE,alpha*0.26))
				v.draw_arc(p,5.0+float(shot.index)*2.0,0,TAU,18,Color(BLUE,alpha),2.2,true)
				v.draw_circle(p+Vector2(-2,-2),2.5,Color(1,1,1,alpha*0.9))
		"hydro_fanfare":
			ellipse(v,zone.pos,float(zone.area),BLUE,alpha*0.72)
			# A low translucent theatre, kept behind all actors.
			for side in [-1.0,1.0]:
				var foot = center+Vector2(side*radii.x*0.9,0)
				var peak = foot+Vector2(-side*18.0,-90.0)
				v.draw_colored_polygon(PackedVector2Array([foot+Vector2(-8,0),peak+Vector2(-15,0),peak+Vector2(15,0),foot+Vector2(8,0)]),Color(BLUE,alpha*0.1))
				v.draw_line(foot,peak,Color(GOLD,alpha*0.62),2.0,true)
				v.draw_circle(peak,5.0,Color(GOLD,alpha*0.8))
			v._draw_dedicated_arc(center+Vector2(0,-76),Vector2(radii.x*0.8,20.0),PI,PI,Color(GOLD,alpha*0.68),2.4)
			for i in 9:
				var a = float(i)*PI/8.0
				var foot = center+Vector2(cos(a)*radii.x,sin(a)*radii.y)*0.88
				var height = 14.0+sin(v.clock*3.0+float(i))*6.0
				v.draw_line(foot,foot+Vector2(0,-height),Color(BLUE,alpha*0.55),2.0,true)
			for ally: Dictionary in v.sim.heroes:
				if ally.hp>0.0 and bool(ally.deployed) and v.sim.is_in_ability_area(zone.pos,ally.pos,float(zone.area)):
					var p = v.world_to_screen(ally.pos)+Vector2(0,-73)
					v.draw_polyline(PackedVector2Array([p+Vector2(-10,2),p+Vector2(-12,-8),p+Vector2(-4,-4),p+Vector2(0,-13),p+Vector2(4,-4),p+Vector2(12,-8),p+Vector2(10,2),p+Vector2(-10,2)]),Color(GOLD,alpha*0.92),2.1,true)

static func salon_actor(v,p: Vector2,index: int,alpha: float) -> void:
	var color = Color(BLUE,alpha*0.7)
	var white = Color(0.90,0.99,1.0,alpha)
	v._draw_dedicated_arc(p+Vector2(0,12),Vector2(24,8),0,TAU,Color(BLUE,alpha*0.45),2.0)
	if index==0: # Top-hatted octopus, curled tentacles.
		v.draw_circle(p+Vector2(0,-7),13.0,color)
		for side in [-1.0,1.0]:
			v.draw_arc(p+Vector2(side*13,8),9,0,PI,16,white,3,true)
		v.draw_rect(Rect2(p+Vector2(-10,-33),Vector2(20,15)),Color(INK,alpha))
		v.draw_line(p+Vector2(-16,-18),p+Vector2(16,-18),white,3,true)
		v.draw_line(p+Vector2(-10,-24),p+Vector2(10,-24),Color(GOLD,alpha),2,true)
	elif index==1: # Crab silhouette with two claws.
		v.draw_circle(p,14.0,color)
		for side in [-1.0,1.0]:
			var claw = p+Vector2(side*24,-12)
			v.draw_line(p+Vector2(side*8,0),claw,white,3,true)
			v.draw_arc(claw,8,PI*0.2,PI*1.8,14,white,4,true)
			for j in 3: v.draw_line(p+Vector2(side*9,float(j)*4),p+Vector2(side*22,8+float(j)*3),color,2,true)
	else: # Seahorse and curled tail.
		v.draw_circle(p+Vector2(1,-14),10.0,color)
		v.draw_line(p+Vector2(6,-13),p+Vector2(18,-10),white,5,true)
		v.draw_arc(p+Vector2(-2,5),12,PI*0.3,PI*1.75,24,color,7,true)
		v.draw_arc(p+Vector2(4,9),5,0,PI*1.7,14,white,2,true)
		v.draw_polyline(PackedVector2Array([p+Vector2(-9,-11),p+Vector2(-20,-4),p+Vector2(-10,3)]),Color(GOLD,alpha),2,true)
	v.draw_circle(p+Vector2(-4,-9),2,white)
	v.draw_circle(p+Vector2(4,-9),2,white)

static func draw_event(v, effect: Dictionary) -> void:
	var kind = str(effect.kind)
	var progress = clampf(1.0-float(effect.life)/float(effect.total),0.0,1.0)
	var alpha = 1.0-smoothstep(0.25,1.0,progress)
	var p = v.world_to_screen(effect.pos)
	if kind == "signature_start": return
	if kind == "signature_needle_hit":
		var dir = Vector2(effect.direction)
		for i in 5:
			var angle = dir.angle()+(float(i)-2.0)*0.45
			var d = Vector2.from_angle(angle)
			v.draw_line(p+d*(6+progress*12),p+d*(24+progress*20),Color(AQUA,alpha),2.0,true)
	elif kind == "signature_black_hit":
		for i in 5:
			var d = Vector2.from_angle(float(i)*TAU/5.0)
			crystal(v,p+d*progress*32.0,d,8.0*(1.0-progress),PINK,alpha)
	elif kind == "signature_chimera_pulse":
		var radii: Vector2 = v.sim.ability_area_screen_radii(effect.pos,float(effect.radius))
		var final = int(effect.index)==2
		v._draw_dedicated_arc(p+Vector2(0,8),radii*(0.15+progress*0.85),0,TAU,Color(PINK,alpha),5.0 if final else 2.5)
		for target in effect.targets:
			var q = v.world_to_screen(target)
			crystal(v,q+Vector2(0,-22),Vector2.UP,(40.0 if final else 23.0)*(1.0-progress),PINK,alpha)
			if final: v.draw_line(q+Vector2(0,-85*(1.0-progress)),q,Color(PINK,alpha*0.7),4,true)
	elif kind == "signature_salon_hit":
		var radii: Vector2 = v.sim.ability_area_screen_radii(effect.pos,float(effect.radius))
		v._draw_dedicated_arc(p+Vector2(0,8),radii*(0.3+progress*0.7),0,TAU,Color(BLUE,alpha),3.0)
		for i in 7:
			var a = float(i)*TAU/7.0
			var q = p+Vector2(cos(a)*radii.x,sin(a)*radii.y)*progress+Vector2(0,-sin(progress*PI)*20)
			v.draw_circle(q,3.0*(1.0-progress),Color(BLUE,alpha))
	elif kind == "signature_heal":
		for target in effect.targets:
			var q = v.world_to_screen(target)+Vector2(0,8)
			v._draw_dedicated_arc(q,Vector2(36,14)*(0.3+progress),0,TAU,Color(GOLD,alpha*0.6),2.0)

static func draw_marks(v) -> void:
	for enemy: Dictionary in v.sim.enemies:
		if enemy.hp<=0.0 or float(enemy.get("amiya_mark_until",0.0))<=v.sim.elapsed: continue
		var marks = int(enemy.get("amiya_marks",0))
		for i in marks:
			var p = v.world_to_screen(enemy.pos)+Vector2((float(i)-(float(marks)-1.0)*0.5)*12.0,-68.0)
			var alpha = minf(1.0,float(enemy.amiya_mark_until)-v.sim.elapsed)
			crystal(v,p,Vector2.UP,7.0,PINK,alpha)
