extends RefCounted
const Skills = preload("res://scripts/hero_signature_skills.gd")
const Cinematic = preload("res://scripts/battle_cinematic_vfx.gd")
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
	var tip = point+direction*size
	var shoulder = point+direction*size*0.12+side*size*0.28
	var base = point-direction*size*0.57+side*size*0.06
	var root = point-direction*size*0.38-side*size*0.19
	var notch = point+direction*size*0.14-side*size*0.14
	var shape = PackedVector2Array([tip,shoulder,base,root,notch,tip])
	v.draw_colored_polygon(shape,Color("#100e1c",alpha))
	v.draw_polyline(shape,Color("#040812",alpha),2.3,true)
	v.draw_colored_polygon(PackedVector2Array([tip,shoulder,base,point-direction*size*0.08]),Color("#614168",alpha*0.9))
	v.draw_colored_polygon(PackedVector2Array([tip,point-direction*size*0.08,root,notch]),Color("#252a3c",alpha))
	v.draw_polyline(PackedVector2Array([tip,shoulder,base]),Color(color,alpha*0.68),1.1,true)
	v.draw_line(point-direction*size*0.25,tip,Color(color.lightened(0.5),alpha*0.55),1.0,true)

static func needle(v, point: Vector2, direction: Vector2, alpha: float, scale: float = 1.0) -> void:
	if alpha < 0.005 or direction.length_squared() < 0.001: return
	var side = Vector2(-direction.y,direction.x)
	# The leading tip is the simulated collision point. A solid steel body and
	# enclosed eye stay readable even with reduced effects and dark backgrounds.
	if not v.reduced_effects:
		v.draw_line(point-direction*82.0*scale,point-direction*14.0*scale,Color(AQUA,alpha*0.09),16.0*scale,true)
	var shape = PackedVector2Array([point,point-direction*25.0*scale+side*3.2*scale,point-direction*52.0*scale+side*4.4*scale,point-direction*62.0*scale,point-direction*52.0*scale-side*4.4*scale,point-direction*25.0*scale-side*3.2*scale,point])
	v.draw_colored_polygon(shape,Color("#dcfff5",alpha))
	v.draw_polyline(shape,Color("#173d45",alpha),2.4*scale,true)
	v.draw_line(point-direction*45.0*scale-side*1.0*scale,point-direction*5.0*scale,Color(Color.WHITE,alpha),1.5*scale,true)
	var eye = point-direction*51.0*scale
	var hole = PackedVector2Array()
	for i in 17:
		var angle = float(i)*TAU/16.0
		hole.append(eye+direction*cos(angle)*6.0*scale+side*sin(angle)*2.3*scale)
	v.draw_colored_polygon(hole,Color("#143240",alpha))
	v.draw_polyline(hole,Color(AQUA,alpha),0.85*scale,true)
	var thread = PackedVector2Array()
	for i in 18:
		var t = float(i)/17.0
		thread.append(eye-direction*(12.0+76.0*t)*scale+side*sin(t*9.0+v.clock*14.0)*6.0*t*scale)
	thread[0] = eye
	v.draw_polyline(thread,Color("#124345",alpha*0.7),3.4*scale,true)
	v.draw_polyline(thread,Color(AQUA,alpha*0.92),1.5*scale,true)

static func draw_preview(v, hero: Dictionary, ability: Dictionary, target: Vector2) -> void:
	var kind = str(ability.kind)
	var end = Skills.target_point(v.sim,hero,ability,target)
	if kind == "needle_barrage":
		var source = Vector2(hero.pos)
		var direction = (end-source).normalized()
		var normal = Vector2(-direction.y,direction.x)
		var data: Dictionary = v.sim.ability_preview_geometry(hero,ability,target)
		end = source + direction * float(data.length)
		var side = normal*Skills.NEEDLE_RADIUS
		var converge = source+direction*160.0
		var polygon = PackedVector2Array([v.world_to_screen(source+normal*66.0),v.world_to_screen(converge+side),v.world_to_screen(end+side),v.world_to_screen(end-side),v.world_to_screen(converge-side),v.world_to_screen(source-normal*66.0),v.world_to_screen(source+normal*66.0)])
		v.draw_colored_polygon(polygon,Color(AQUA,0.10))
		v.draw_polyline(polygon,Color(AQUA,0.75),1.6,true)
		v.draw_dashed_line(v.world_to_screen(source),v.world_to_screen(end),Color(AQUA,0.6),1.5,14.0)
		var screen_direction = (v.world_to_screen(end)-v.world_to_screen(source)).normalized()
		needle(v,v.world_to_screen(source+direction*90.0)+Vector2(0,-22),screen_direction,0.82,0.8)
	else:
		var geometry: Dictionary = v.sim.ability_preview_geometry(hero,ability,end)
		Cinematic.geometry(v,geometry,PINK if kind in ["arcane_lance","chimera"] else BLUE,0.85)
		if kind != "hydro_fanfare": v.draw_dashed_line(v.world_to_screen(hero.pos),v.world_to_screen(end),Color(1,1,1,0.35),1.0,12.0)

static func draw_cast(v, effect: Dictionary) -> void:
	var kind = str(effect.kind)
	# Real shots/actors own the active phase; replaying a cast on impact creates
	# stationary ghost needles and hides the travelling silhouettes.
	if not kind.ends_with("_cast"): return
	var progress = clampf(1.0-float(effect.life)/float(effect.total),0.0,1.0)
	var source = Vector2(effect.caster_pos)
	var target = Vector2(effect.pos)
	var origin = v.world_to_screen(source)+Vector2(0,-22)
	if kind.begins_with("gwen_needle"):
		var dir = (v.world_to_screen(target)-v.world_to_screen(source)).normalized()
		var p = origin+dir*(22.0+progress*20.0)
		needle(v,p,dir,0.25+progress*0.75)
		for i in (2 if v.reduced_effects else 4):
			var side = Vector2(-dir.y,dir.x)
			var tail = origin-dir*(45.0+float(i)*11.0)+side*sin(progress*PI+float(i))*16.0
			v.draw_line(tail,tail+dir*(9.0+progress*8.0),Color(AQUA,progress*0.55),1.3,true)
	else:
		var color = PINK if kind.begins_with("amiya_") else BLUE
		if kind.begins_with("amiya_"):
			for i in 3:
				var p = origin+Vector2((float(i)-1.0)*23.0,-16.0-abs(i-1)*12.0)*(1.2-progress*0.3)
				crystal(v,p,Vector2.UP,11.0+progress*8.0,color,progress)
		else:
			# A brief theatre flourish; the three animals appear only on release.
			for side in [-1.0,1.0]:
				v.draw_arc(origin+Vector2(side*17.0,0),22.0+progress*8.0,PI*0.95 if side<0 else -PI*0.05,PI*1.8 if side<0 else PI*0.8,18,Color(GOLD,progress*0.85),2.0,true)

static func draw_zone(v, zone: Dictionary) -> void:
	var alpha = minf(smoothstep(0.0,0.08,float(zone.elapsed)),smoothstep(0.0,0.3,float(zone.life)))
	if bool(zone.get("cancelled",false)): alpha *= float(zone.life)/0.4
	var kind = str(zone.kind)
	var center = v.world_to_screen(zone.pos)+v.ground_visual_offset()
	var radii: Vector2 = v.sim.ability_area_screen_radii(zone.pos,float(zone.area))
	match kind:
		"needle_barrage":
			var direction = (v.world_to_screen(zone.pos)-v.world_to_screen(zone.source)).normalized()
			for shot: Dictionary in zone.shots:
				var tail_alpha = 1.0-smoothstep(0.0,0.14,float(zone.elapsed)-float(shot.get("ended_at",zone.elapsed))) if bool(shot.done) else 1.0
				var shot_direction: Vector2 = (v.world_to_screen(shot.pos)-v.world_to_screen(shot.get("previous",shot.start))).normalized()
				if shot_direction.length_squared()<0.1: shot_direction=direction
				needle(v,v.world_to_screen(shot.pos)+Vector2(0,-22),shot_direction,alpha*tail_alpha,1.0+float(shot.get("volley",0))*0.07)
		"arcane_lance":
			for shot: Dictionary in zone.shots:
				if bool(shot.done): continue
				var p = v.world_to_screen(shot.pos)+Vector2(0,-22)
				var direction = (v.world_to_screen(shot.pos)-v.world_to_screen(shot.previous)).normalized()
				var side = direction.orthogonal()
				v.draw_colored_polygon(PackedVector2Array([p,p-direction*90.0+side*11.0,p-direction*70.0-side*5.0]),Color("#0b0716",alpha*0.72))
				v.draw_line(p-direction*67.0,p,Color(PINK,alpha*0.2),4.0,true)
				crystal(v,p,direction,22.0,PINK,alpha)
				for trail in (2 if v.reduced_effects else 4):
					crystal(v,p-direction*float(trail+1)*20.0+side*sin(v.clock*17.0+trail)*7.0,direction,6.0-float(trail),PINK,alpha*(0.5-float(trail)*0.1))
		"chimera":
			chimera_field(v,zone.geometry,float(zone.elapsed),alpha)
		"salon_summon":
			# Short ripples under individual guests leave the stage readable.
			ellipse(v,zone.pos,float(zone.area),BLUE,alpha*0.18)
			for i in 3:
				var bob = sin(v.clock*(2.5+float(i)*0.35)+float(i)*1.8)*3.5
				salon_actor(v,v.world_to_screen(Skills.salon_position(zone,i))+Vector2(0,-18+bob),i,alpha)
			for shot: Dictionary in zone.shots:
				var p = v.world_to_screen(shot.pos)+Vector2(0,-9-sin(float(shot.age)/0.38*PI)*20.0)
				v.draw_circle(p,7.0+float(shot.index)*2.0,Color(BLUE,alpha*0.26))
				v.draw_arc(p,5.0+float(shot.index)*2.0,0,TAU,18,Color(BLUE,alpha),2.2,true)
				v.draw_circle(p+Vector2(-2,-2),2.5,Color(1,1,1,alpha*0.9))
		"hydro_fanfare":
			ellipse(v,zone.pos,float(zone.area),BLUE,alpha*0.28)
			# A low translucent theatre, kept behind all actors.
			for side in [-1.0,1.0]:
				var foot = center+Vector2(side*radii.x*0.9,0)
				var peak = foot+Vector2(-side*18.0,-90.0)
				v.draw_colored_polygon(PackedVector2Array([foot+Vector2(-8,0),peak+Vector2(-15,0),peak+Vector2(15,0),foot+Vector2(8,0)]),Color(BLUE,alpha*0.1))
				v.draw_line(foot,peak,Color(GOLD,alpha*0.62),2.0,true)
				v.draw_circle(peak,5.0,Color(GOLD,alpha*0.8))
			v._draw_dedicated_arc(center+Vector2(0,-76),Vector2(radii.x*0.8,20.0),PI,PI,Color(GOLD,alpha*0.68),2.4)
			for i in (5 if v.reduced_effects else 9):
				var a = float(i)*PI/8.0
				var foot = center+Vector2(cos(a)*radii.x,sin(a)*radii.y)*0.88
				var height = 14.0+sin(v.clock*3.0+float(i))*6.0
				v.draw_line(foot,foot+Vector2(0,-height),Color(BLUE,alpha*0.55),2.0,true)
			for ally: Dictionary in v.sim.heroes:
				if ally.hp>0.0 and bool(ally.deployed) and v.sim.is_in_ability_area(zone.pos,ally.pos,float(zone.area)):
					var p = v.world_to_screen(ally.pos)+Vector2(0,-73)
					v.draw_polyline(PackedVector2Array([p+Vector2(-10,2),p+Vector2(-12,-8),p+Vector2(-4,-4),p+Vector2(0,-13),p+Vector2(4,-4),p+Vector2(12,-8),p+Vector2(10,2),p+Vector2(-10,2)]),Color(GOLD,alpha*0.92),2.1,true)
			# Fanfare adds a real, capped set of lights instead of filling the arena.
			for i in int(zone.get("fanfare",0)):
				var lamp = center+Vector2((float(i)-2.0)*13.0,-87.0)
				v.draw_circle(lamp,2.6,Color(GOLD,alpha))

static func chimera_field(v, geometry: Dictionary, elapsed: float, alpha: float) -> void:
	var polygons: Array = geometry.get("polygons",[])
	if polygons.is_empty(): return
	var polygon: PackedVector2Array = polygons[0]
	if polygon.size()<4: return
	var start: Vector2 = (polygon[0]+polygon[3])*0.5
	var end: Vector2 = (polygon[1]+polygon[2])*0.5
	var direction = (v.world_to_screen(end)-v.world_to_screen(start)).normalized()
	var side = direction.orthogonal()
	# The exact broad footprint is a targeting aid only. Live Arts tear a narrow,
	# irregular seam through its center; rooted clusters replace the old box and
	# regular floating diamonds.
	var seam = PackedVector2Array()
	for i in 25:
		var t = float(i)/24.0
		var jitter = sin(float(i)*2.37)*5.0+sin(float(i)*0.83)*3.0
		seam.append(v.world_to_screen(start.lerp(end,t))+side*jitter+Vector2(0,3.0))
	v.draw_polyline(seam,Color("#080811",alpha*0.95),11.0,true)
	v.draw_polyline(seam,Color("#38223f",alpha*0.65),4.0,true)
	for i in range(1,24,3):
		var flash = 0.2+0.55*pow(maxf(0.0,sin(elapsed*8.0-float(i)*0.31)),3.0)
		v.draw_line(seam[i],seam[i+1],Color(PINK,alpha*flash),1.2,true)
	var positions := [0.11,0.26,0.39,0.58,0.72,0.89]
	for i in (4 if v.reduced_effects else 6):
		var growth = smoothstep(float(i)*0.075,float(i)*0.075+0.28,elapsed)
		var base = v.world_to_screen(start.lerp(end,float(positions[i])))+side*sin(float(i)*2.1)*17.0
		var height = (18.0+float((i*3)%5)*7.0)*growth
		var lean = Vector2(sin(float(i)*3.7)*0.38,-1.0).normalized()
		crystal(v,base+Vector2(0,-height*0.36),lean,height,PINK,alpha*0.95)
		if not v.reduced_effects:
			crystal(v,base+Vector2(9.0,-height*0.18),Vector2(0.48,-1.0).normalized(),height*0.48,PINK,alpha*0.82)
	for i in (2 if v.reduced_effects else 4):
		var t = fposmod(elapsed*0.72+float(i)*0.24,1.0)
		var p = v.world_to_screen(start.lerp(end,t))+Vector2(0,-9.0)-side*sin(t*9.0)*7.0
		crystal(v,p,direction,5.0,PINK,alpha*sin(t*PI)*0.5)

static func salon_actor(v,p: Vector2,index: int,alpha: float) -> void:
	var color = Color("#319ce5",alpha*0.91)
	var white = Color("#d9fbff",alpha)
	var ink = Color("#123252",alpha)
	v._draw_dedicated_arc(p+Vector2(0,20),Vector2(28,8),0,TAU,Color(BLUE,alpha*0.4),1.5)
	# Fast small shots = seahorse; medium shots = octopus; slow heavy shots = crab.
	if index==1:
		for tentacle in 4:
			var x = (float(tentacle)-1.5)*10.0
			var curl = p+Vector2(x,9.0+sin(v.clock*3.0+tentacle)*2.0)
			v.draw_arc(curl,8.0,0.05,PI*1.12,14,ink,8.0,true)
			v.draw_arc(curl,8.0,0.05,PI*1.12,14,color,4.5,true)
		v.draw_circle(p+Vector2(0,-7),18.0,ink)
		v.draw_circle(p+Vector2(0,-8),15.5,color)
		v.draw_arc(p+Vector2(-1,-8),12.0,PI*1.0,PI*1.7,14,white,1.7,true)
		v.draw_rect(Rect2(p+Vector2(-12,-41),Vector2(24,22)),ink)
		v.draw_rect(Rect2(p+Vector2(-9,-38),Vector2(18,16)),Color("#254d78",alpha))
		v.draw_line(p+Vector2(-19,-20),p+Vector2(19,-20),white,4,true)
		v.draw_line(p+Vector2(-10,-27),p+Vector2(10,-27),Color(GOLD,alpha),3,true)
		for side in [-1.0,1.0]: v.draw_circle(p+Vector2(side*6,-8),2.8,white)
	elif index==2:
		for side in [-1.0,1.0]:
			for j in 3:
				var leg = PackedVector2Array([p+Vector2(side*12,float(j)*4),p+Vector2(side*(25+j*3),float(j)*5+2),p+Vector2(side*(22+j*3),float(j)*5+9)])
				v.draw_polyline(leg,ink,6.0,true)
				v.draw_polyline(leg,color,3.2,true)
		var shell = PackedVector2Array([p+Vector2(-21,-6),p+Vector2(-13,-17),p+Vector2(12,-17),p+Vector2(21,-6),p+Vector2(16,12),p+Vector2(-16,12),p+Vector2(-21,-6)])
		v.draw_colored_polygon(shell,color)
		v.draw_polyline(shell,ink,2.4,true)
		v.draw_line(p+Vector2(-11,-7),p+Vector2(11,-7),white,1.7,true)
		for side in [-1.0,1.0]:
			var claw = p+Vector2(side*31,-22+sin(v.clock*2.2)*3.0)
			v.draw_line(p+Vector2(side*16,-1),claw,ink,7,true)
			v.draw_line(p+Vector2(side*16,-1),claw,color,4,true)
			v.draw_arc(claw,9,PI*0.12,PI*1.78,18,ink,8,true)
			v.draw_arc(claw,9,PI*0.12,PI*1.78,18,white,4.3,true)
			v.draw_circle(p+Vector2(side*6,-16),3.0,white)
	else:
		var body = PackedVector2Array([p+Vector2(-8,-29),p+Vector2(5,-32),p+Vector2(15,-22),p+Vector2(27,-20),p+Vector2(25,-13),p+Vector2(11,-14),p+Vector2(5,-3),p+Vector2(9,7),p+Vector2(1,17),p+Vector2(-11,9),p+Vector2(-14,-2),p+Vector2(-7,-13),p+Vector2(-8,-29)])
		v.draw_colored_polygon(body,color)
		v.draw_polyline(body,ink,2.6,true)
		v.draw_arc(p+Vector2(3,13),10.0,PI*1.0,PI*2.8,22,color,6.0,true)
		v.draw_arc(p+Vector2(4,14),5.0,PI*1.0,PI*2.5,16,white,1.7,true)
		v.draw_polyline(PackedVector2Array([p+Vector2(-9,-12),p+Vector2(-22,-6),p+Vector2(-13,3)]),Color(GOLD,alpha),2.6,true)
		v.draw_line(p+Vector2(-2,-5),p+Vector2(4,3),white,1.3,true)
		v.draw_circle(p+Vector2(8,-22),3.0,white)
		v.draw_circle(p+Vector2(9,-22),1.3,ink)

static func draw_event(v, effect: Dictionary) -> void:
	var kind = str(effect.kind)
	var progress = clampf(1.0-float(effect.life)/float(effect.total),0.0,1.0)
	var alpha = 1.0-smoothstep(0.25,1.0,progress)
	var p = v.world_to_screen(effect.pos)
	if kind == "signature_start": return
	if kind == "signature_needle_volley":
		var dir = (v.world_to_screen(Vector2(effect.pos)+Vector2(effect.direction)*20.0)-p).normalized()
		p += Vector2(0,-22)
		var count = int(effect.get("count",1))
		for i in count:
			var q = p+dir.orthogonal()*(float(i)-float(count-1)*0.5)*12.0-dir*progress*14.0
			v.draw_line(q-dir*(11.0+progress*12.0),q,Color(AQUA,alpha*0.7),1.8,true)
	elif kind == "signature_needle_hit":
		var dir = (v.world_to_screen(Vector2(effect.pos)+Vector2(effect.direction)*20.0)-p).normalized()
		p += Vector2(0,-22)
		for i in (2 if v.reduced_effects else 4):
			var d = dir.rotated([0.45,-0.72,0.91,-0.32][i])
			var head = p+d*(7.0+progress*(22.0+float(i)*7.0))
			v.draw_line(head-d*(12.0*(1.0-progress)),head,Color(AQUA if i%2 else Color.WHITE,alpha),1.8,true)
		var stitch = PackedVector2Array([p-dir*10.0+dir.orthogonal()*6.0,p+dir*7.0-dir.orthogonal()*5.0,p+dir*17.0+dir.orthogonal()*3.0])
		v.draw_polyline(stitch,Color(AQUA,alpha*0.7),1.4,true)
	elif kind == "signature_black_hit":
		for i in 5:
			var d = Vector2.from_angle(float(i)*TAU/5.0)
			crystal(v,p+d*progress*32.0,d,8.0*(1.0-progress),PINK,alpha)
	elif kind == "signature_chimera_pulse":
		var final = int(effect.index)==2
		var geometry: Dictionary = effect.get("geometry",{})
		if geometry.has("polygons") and not geometry.polygons.is_empty():
			var polygon: PackedVector2Array = geometry.polygons[0]
			var a = v.world_to_screen((polygon[0]+polygon[3])*0.5)+Vector2(0,3)
			var b = v.world_to_screen((polygon[1]+polygon[2])*0.5)+Vector2(0,3)
			var seam = PackedVector2Array()
			for i in 17:
				var t = float(i)/16.0
				seam.append(a.lerp(b,t)+Vector2(0,sin(t*24.0+int(effect.index))*7.0*(1.0-progress)))
			v.draw_polyline(seam,Color("#110a1c",alpha*0.9),18.0 if final else 9.0,true)
			v.draw_polyline(seam,Color(PINK,alpha*0.9),4.5 if final else 2.0,true)
			if progress<0.22: v.draw_line(a,b,Color(Color.WHITE,alpha*(1.0-progress/0.22)),2.0,true)
		for target in effect.targets:
			var q = v.world_to_screen(target)
			crystal(v,q+Vector2(0,-22),Vector2.UP,(40.0 if final else 23.0)*(1.0-progress),PINK,alpha)
			if final: v.draw_line(q+Vector2(0,-85*(1.0-progress)),q,Color(PINK,alpha*0.7),4,true)
	elif kind == "signature_salon_hit":
		var radii: Vector2 = v.sim.ability_area_screen_radii(effect.pos,float(effect.radius))
		v._draw_dedicated_arc(p+v.ground_visual_offset(),radii*(0.3+progress*0.7),0,TAU,Color(BLUE,alpha),3.0)
		for i in 7:
			var a = float(i)*TAU/7.0
			var q = p+Vector2(cos(a)*radii.x,sin(a)*radii.y)*progress+Vector2(0,-sin(progress*PI)*20)
			v.draw_circle(q,3.0*(1.0-progress),Color(BLUE,alpha))
	elif kind == "signature_heal":
		for target in effect.targets:
			var q = v.world_to_screen(target)+v.ground_visual_offset()
			v._draw_dedicated_arc(q,Vector2(36,14)*(0.3+progress),0,TAU,Color(GOLD,alpha*0.6),2.0)

static func draw_marks(v) -> void:
	for enemy: Dictionary in v.sim.enemies:
		if enemy.hp<=0.0 or float(enemy.get("amiya_mark_until",0.0))<=v.sim.elapsed: continue
		var marks = int(enemy.get("amiya_marks",0))
		for i in marks:
			var p = v.world_to_screen(enemy.pos)+Vector2((float(i)-(float(marks)-1.0)*0.5)*12.0,-68.0)
			var alpha = minf(1.0,float(enemy.amiya_mark_until)-v.sim.elapsed)
			crystal(v,p,Vector2.UP,7.0,PINK,alpha)
