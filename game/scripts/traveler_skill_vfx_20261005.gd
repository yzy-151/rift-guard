extends RefCounted
## Cosmetic only: compact white cores and short element silhouettes.
## Wind Q keeps its original gameplay; its new zone art lives in WindSkillVfx.
const WindSkillVfx = preload("res://scripts/wind_skill_vfx_20261005.gd")
const PALETTE = {"none":Color("#ffe4a0"),"pyro":Color("#ff884f"),"hydro":Color("#65d9ff"),"electro":Color("#be94ff"),"geo":Color("#efc76e"),"cryo":Color("#a3e9ff"),"anemo":Color("#85efd0")}
const KEYS = ["none_q","none_e","pyro_q","pyro_e","hydro_q","hydro_e","electro_q","electro_e","geo_q","geo_e","cryo_q","cryo_e","anemo_e"]
const GLOW = preload("res://assets/vfx/combat_20261005/orb_glow.png")
const FLARE = preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")

static func supports(key: String) -> bool: return key in KEYS

static func _lean(v) -> bool:
	return v.reduced_effects or v.sim.enemies.size() > 100

static func _glow(v,texture: Texture2D,p: Vector2,size: Vector2,color: Color,alpha: float) -> void:
	if alpha<.005: return
	if v.has_method("emit_glow"):
		v.emit_glow(texture,p,size,color,clampf(alpha,0,1))
	else:
		v.draw_texture_rect(texture,Rect2(p-size*.5,size),false,Color(color,clampf(alpha,0,1)))

static func _ring(v,c: Vector2,r: Vector2,color: Color,alpha: float,width: float=1.2,start: float=0.0,end: float=TAU) -> void:
	if alpha < 0.005 or minf(r.x,r.y) < 0.2: return
	v._draw_dedicated_arc(c,r,start,end,Color(color,clampf(alpha,0,1)),width)

static func _rail(v,points: PackedVector2Array,color: Color,alpha: float,width: float=1.4) -> void:
	if points.size()<2 or alpha<0.005: return
	if not _lean(v): v.draw_polyline(points,Color(color,alpha*.12),width+5.0,true)
	v.draw_polyline(points,Color(color,alpha*.65),width+1.1,true)
	v.draw_polyline(points,Color(Color.WHITE,alpha*.95),maxf(1.2,width*.65),true)

static func _glint(v,p: Vector2,size: float,color: Color,alpha: float,angle: float=0.0) -> void:
	if alpha<0.005 or size<0.1: return
	var axis=Vector2.from_angle(angle)*size
	var side=axis.orthogonal()*.57
	if not _lean(v):
		_glow(v,GLOW,p,Vector2.ONE*size*5.4,color,alpha*.75)
		_glow(v,FLARE,p,Vector2.ONE*size*2.8,Color.WHITE,alpha*.62)
	v.draw_line(p-axis,p+axis,Color(color.lightened(.65),alpha*.65),1.3,true)
	v.draw_line(p-side,p+side,Color(Color.WHITE,alpha),1.3,true)
	v.draw_circle(p,1.2,Color(Color.WHITE,alpha))

static func _chip(v,p: Vector2,length: float,color: Color,alpha: float,angle: float=0.0) -> void:
	if alpha<0.005 or length<.2: return
	var axis=Vector2.from_angle(angle-PI/2)*length
	var side=axis.orthogonal()*.34
	if not _lean(v): _glow(v,GLOW,p,Vector2.ONE*length*2.2,color,alpha*.48)
	var tip=p-axis
	var tail=p+axis*.55
	var left=p-side
	var right=p+side
	var points=PackedVector2Array([tip,right,tail,left])
	v.draw_colored_polygon(points,Color(color,alpha*.90))
	v.draw_colored_polygon(PackedVector2Array([tip,p,right]),Color(color.lightened(.7),alpha*.95))
	v.draw_colored_polygon(PackedVector2Array([p,left,tail]),Color(color.darkened(.25),alpha*.62))
	points.append(points[0])
	v.draw_polyline(points,Color(color.lightened(.85),alpha),1.6,true)
	v.draw_line(tip,tail,Color(Color.WHITE,alpha),1.4,true)

static func _flash(v,p: Vector2,color: Color,alpha: float) -> void:
	if alpha<.005: return
	if not _lean(v): _glow(v,GLOW,p,Vector2(96,96),color,alpha)
	_glow(v,GLOW,p,Vector2(46,46),Color.WHITE,alpha)
	v.draw_circle(p,5.0,Color(Color.WHITE,alpha))
	v.draw_line(p-Vector2(12,0),p+Vector2(12,0),Color(Color.WHITE,alpha*.85),1.9,true)

static func _ice_blade(v,p: Vector2,length: float,alpha: float,angle: float=0.0) -> void:
	if alpha<.005: return
	var axis=Vector2.from_angle(angle-PI/2)*length
	var side=axis.orthogonal()*.46
	var tip=p-axis
	var tail=p+axis*.55
	var left=p-side-axis*.06
	var right=p+side-axis*.06
	if not _lean(v): _glow(v,GLOW,p,Vector2.ONE*length*3.4,Color("#65dfff"),alpha)
	v.draw_colored_polygon(PackedVector2Array([tip,right,tail,left]),Color("#6edcff",alpha))
	v.draw_colored_polygon(PackedVector2Array([tip,p,left]),Color("#eaffff",alpha))
	v.draw_colored_polygon(PackedVector2Array([p,right,tail]),Color("#65b4ee",alpha*.98))
	v.draw_colored_polygon(PackedVector2Array([tip,right,p]),Color("#beffff",alpha))
	v.draw_polyline(PackedVector2Array([tip,right,tail,left,tip]),Color("#f4ffff",alpha),2.0,true)
	v.draw_line(tip,tail,Color(Color.WHITE,alpha),2.6,true)
	_glow(v,GLOW,p,Vector2(22,22),Color.WHITE,alpha)

static func _starfell_sword(v,p: Vector2,size: float,alpha: float) -> void:
	if alpha<.005: return
	# Starfell Sword / 荒星 reference: a rounded segmented shell with a flat cap,
	# vertical angular gold circuits, and crystal roots; never a five-point star.
	var outline=PackedVector2Array()
	for point: Vector2 in [Vector2(-.66,-.72),Vector2(-.27,-.9),Vector2(.37,-.87),Vector2(.75,-.60),Vector2(.94,-.15),Vector2(.90,.42),Vector2(.64,.77),Vector2(.14,.88),Vector2(-.45,.79),Vector2(-.86,.45),Vector2(-.94,-.08),Vector2(-.83,-.47)]: outline.append(p+point*size)
	v.draw_colored_polygon(outline,Color("#614635",alpha))
	for face: Array in [
		[Vector2(-.83,-.47),Vector2(-.42,-.64),Vector2(-.35,.73),Vector2(-.86,.45)],
		[Vector2(-.42,-.64),Vector2(.13,-.72),Vector2(.17,.84),Vector2(-.35,.73)],
		[Vector2(.13,-.72),Vector2(.61,-.62),Vector2(.67,.71),Vector2(.17,.84)],
		[Vector2(.61,-.62),Vector2(.86,-.26),Vector2(.90,.42),Vector2(.67,.71)]]:
		var polygon=PackedVector2Array()
		for point: Vector2 in face: polygon.append(p+point*size)
		v.draw_colored_polygon(polygon,Color("#9c7654" if face[0].x<0 else "#735443",alpha))
		polygon.append(polygon[0])
		v.draw_polyline(polygon,Color("#322d2b",alpha),2.4,true)
	# Two stepped stone cap slabs catch a gold-lit top edge.
	for cap: Array in [[Vector2(-.72,-.72),Vector2(-.17,-.98),Vector2(.43,-.93),Vector2(.56,-.72),Vector2(-.27,-.52)], [Vector2(-.62,-.85),Vector2(-.12,-1.01),Vector2(.48,-.94),Vector2(.35,-.81),Vector2(-.27,-.65)]]:
		var slab=PackedVector2Array()
		for point: Vector2 in cap: slab.append(p+point*size)
		v.draw_colored_polygon(slab,Color("#af885c",alpha))
		v.draw_polyline(PackedVector2Array([slab[0],slab[1],slab[2]]),Color("#ffe7a0",alpha),2.1,true)
	for circuit: Array in [
		[Vector2(-.69,-.31),Vector2(-.50,-.35),Vector2(-.53,.03),Vector2(-.37,.14),Vector2(-.37,.64)],
		[Vector2(-.27,-.43),Vector2(.02,-.45),Vector2(.01,-.06),Vector2(.33,.15),Vector2(.30,.38),Vector2(.47,.58)],
		[Vector2(.60,-.40),Vector2(.74,-.05),Vector2(.66,.07),Vector2(.79,.42)]]:
		var path=PackedVector2Array()
		for point: Vector2 in circuit: path.append(p+point*size)
		v.draw_polyline(path,Color("#d58a24",alpha),5.7,true)
		v.draw_polyline(path,Color("#ffcf48",alpha),3.1,true)
		v.draw_polyline(path,Color("#fff4b8",alpha),1.3,true)
		if not _lean(v):
			for index in range(1,path.size(),2): _glow(v,GLOW,path[index],Vector2.ONE*size*.65,Color("#ffd048"),alpha*.9)
	for i in (3 if _lean(v) else 5):
		var x=lerpf(-.91,.92,float(i)/4)
		_chip(v,p+Vector2(x,.78-absf(x)*.12)*size,size*(.24+.10*float(i%2)),Color("#ffcf48"),alpha,-.34+x*.48)
	var edge=outline.duplicate();edge.append(edge[0])
	v.draw_polyline(edge,Color("#d2a465",alpha),1.4,true)
	_glow(v,GLOW,p+Vector2(.05,.28)*size,Vector2.ONE*size*1.4,Color("#ffd04a"),alpha*.32)

static func construct(v,z: Dictionary) -> void:
	if bool(z.get("device",false)) or float(z.get("hp",0))<=0: return
	var c=v.world_to_screen(z.pos)
	var depth=float(v.world_depth_scale(z.pos))
	_ring(v,c+Vector2(0,7),Vector2(32,12)*depth,Color("#ffc948"),.3,1.1)
	_starfell_sword(v,c-Vector2(0,37*depth),39*depth,1.0)
	var ratio=clampf(float(z.hp)/maxf(1,float(z.max_hp)),0,1)
	v.draw_rect(Rect2(c+Vector2(-25,17),Vector2(50,4)),Color("#352a27"))
	v.draw_rect(Rect2(c+Vector2(-25,17),Vector2(50*ratio,4)),Color("#efc75f"))

static func _hit_shards(v,c: Vector2,r: Vector2,color: Color,t: float,alpha: float,seed: float=0.0) -> void:
	var count=3 if _lean(v) else 7
	for i in count:
		var a=float(i)*TAU/7+seed
		var direction=Vector2(cos(a),sin(a)*.65)
		var p=c+direction*(14+58*(1-pow(1-t,2)))-Vector2(0,sin(t*PI)*(9+i%3*4))
		if color==PALETTE.cryo: _ice_blade(v,p,(17+float(i%3)*3)*(1-t*.5),alpha*(1-t*.4),a+PI/2)
		else: _chip(v,p,(13+float(i%3)*3)*(1-t*.5),color,alpha*(1-t*.4),a+PI/2)

static func _particles(v,c: Vector2,r: Vector2,color: Color,t: float,alpha: float,count: int=12,seed: float=0.0,shards: bool=false) -> void:
	var amount=mini(count,6) if _lean(v) else count
	for i in amount:
		var phase=float(i)*2.39996+seed
		var delay=float(i%3)*.035
		var progress=clampf((t-delay)*1.3,0,1)
		var d=Vector2(cos(phase)*r.x,sin(phase)*r.y)
		var p=c+d*(.15+progress*.72)-Vector2(0,sin(progress*PI)*float(6+i%4*4))
		var fade=alpha*(1-progress)*(.68+float(i%3)*.10)
		if shards: _chip(v,p,(5.0+i%3*2.0)*(1-progress*.4),color,fade,phase+PI/2)
		else:
			v.draw_line(p-d.normalized()*5*(1-progress),p,Color(color,fade*.7),1.25,true)
			v.draw_circle(p,1.5+float(i%2)*.5,Color(Color.WHITE,fade))
			if not _lean(v) and i%3==0: _glow(v,GLOW,p,Vector2(14,14),color,fade*.55)

static func _ellipse_pulse(v,c: Vector2,r: Vector2,color: Color,t: float,alpha: float) -> void:
	var spread=.12+.86*(1-pow(1-t,3))
	_ring(v,c,r*spread,color,alpha*.5,2.0*(1-t)+.6)
	_ring(v,c,r*maxf(.03,spread-.06),Color.WHITE,alpha*.67,.9)

static func _bolt(v,a: Vector2,b: Vector2,color: Color,alpha: float,step: float=0.0) -> void:
	var d=b-a
	var side=d.orthogonal().normalized()
	var points=PackedVector2Array()
	for i in 8:
		var f=float(i)/7
		points.append(a+d*f+side*sin(float(i)*3.7+step)*sin(f*PI)*5.0)
	_rail(v,points,color,alpha,1.8)
	_glint(v,b,8.0,color,alpha,PI/4)
	_flash(v,b,color,alpha*.6)
	for i in (2 if _lean(v) else 3):
		var angle=step+float(i)*TAU/3
		_chip(v,b+Vector2.from_angle(angle)*15,5.5,color,alpha*.65,angle+PI/2)

static func _sweep(v,c: Vector2,r: Vector2,color: Color,t: float,alpha: float,turn: float=0.0) -> void:
	var points=PackedVector2Array()
	var head=-PI*.8+t*PI*1.35+turn
	for i in 20:
		var f=float(i)/19
		var a=head-f*PI*.65
		points.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)*(.66+f*.2))
	_rail(v,points,color,alpha,2.5)
	_glint(v,points[0],6.0,color,alpha,head)

static func legacy_event(v,e: Dictionary) -> bool:
	if WindSkillVfx.legacy_event(v,e): return true
	var kind=str(e.get("kind",""))
	if not kind in ["traveler_none_cast","traveler_none_impact","neutral_starfall_cast","neutral_starfall_impact"]: return false
	var data=e.duplicate(false)
	data.skill="none_e" if kind.begins_with("neutral_starfall") else "none_q"
	data.element="none"
	data.kind="traveler_fx_cast" if kind.ends_with("_cast") else "traveler_fx_hit"
	if not data.has("source"):
		var hero_id=int(e.get("hero_id",-1))
		data.source=Vector2(v.sim.heroes[hero_id].pos) if hero_id>=0 and hero_id<v.sim.heroes.size() else e.get("caster_pos",e.pos)
	event(v,data)
	return true

static func event(v,e: Dictionary) -> void:
	var key=str(e.get("skill",""))
	if not supports(key): return
	var color: Color=PALETTE.get(str(e.get("element","none")),PALETTE.none)
	var total=maxf(.01,float(e.get("total",.4)))
	var age=maxf(0,total-float(e.get("life",total)))
	var casting=str(e.kind)=="traveler_fx_cast"
	var length=total if casting else (.25 if e.kind=="traveler_fx_arc" else .48 if key.ends_with("_e") else .36)
	var t=clampf(age/maxf(.01,length),0,1)
	if not casting and t>=1: return
	var alpha=(.25+.65*t) if casting else (1-smoothstep(.10,1.0,t))
	var c=v.world_to_screen(Vector2(e.pos))+Vector2(0,8)
	var r: Vector2=v.sim.ability_area_screen_radii(e.pos,float(e.get("radius",160)))
	var source=v.world_to_screen(Vector2(e.get("source",e.pos)))+Vector2(0,-20)
	if e.kind=="traveler_fx_arc":
		if e.has("targets"):
			var index=0
			for point in e.targets:
				var a=float(index%3)*TAU/3-PI/2
				_bolt(v,c+Vector2(cos(a)*r.x,sin(a)*r.y)-Vector2(0,24),v.world_to_screen(point)+Vector2(0,-18),color,alpha,float(index))
				index+=1
		else: _bolt(v,source,c+Vector2(0,-18),color,alpha)
		return
	if casting:
		_ring(v,c,r*(.93+.07*t),color,.28+sin(t*PI)*.23,1.0)
		for i in (3 if _lean(v) else 5):
			var a=float(i)*TAU/5+t*.5
			_glint(v,c+Vector2(cos(a)*r.x,sin(a)*r.y)*(.5+.43*t),3.0,color,alpha*.6,a)
		if key=="none_e": _falling_blade(v,c,lerpf(110,0,pow(t,4)),color,alpha)
		elif key=="pyro_e": _comet(v,c,145*(1-t),color,alpha)
		elif key=="geo_q": _starfell_sword(v,c-Vector2(0,30+100*(1-t)),27+10*t,alpha)
		elif key=="geo_e":
			for i in 3:
				var a=float(i)*TAU/3-PI/2
				_chip(v,c+Vector2(cos(a)*r.x,sin(a)*r.y)*.35-Vector2(0,8),16+8*t,Color("#ffe179"),alpha*.85)
		elif key=="none_q":
			var heading=(c-source).normalized()
			WindSkillVfx.crescent(v,source.lerp(c,t)-Vector2(0,6),heading,Vector2(26,39),Color("#c6fff0"),alpha,true)
		elif key=="pyro_q": _sweep(v,c,r*.72,color,t,alpha*.6)
		return
	_ellipse_pulse(v,c,r,color,t,alpha*.19)
	_flash(v,c-Vector2(0,10),color,(1-smoothstep(.02,.18,age))*.93)
	_hit_shards(v,c-Vector2(0,10),r,color,t,alpha*.85,float(e.get("step",0))*.71)
	match key:
		"none_q":
			var heading=(c-source).normalized()
			WindSkillVfx.crescent(v,c-Vector2(0,16)+heading*45*t,heading,Vector2(29,43),Color("#a1ffe2"),alpha,true)
			WindSkillVfx.fragments(v,c-Vector2(0,16),Color("#a1ffe2"),t,alpha)
		"pyro_q":
			_sweep(v,c,r,color,t,alpha)
			_particles(v,c,r*.8,color,t,alpha,10,float(e.get("step",0)))
		"none_e":
			_falling_blade(v,c,0,color,alpha*(1-t))
			_particles(v,c,r,color,t,alpha,16,0,true)
			_glint(v,c-Vector2(0,12),16*(1-t),color,alpha,PI/2)
		"pyro_e":
			_particles(v,c,r,color,t,alpha,16,float(e.get("step",0))*.6,true)
			_glint(v,c-Vector2(0,5),14*(1-t),color,alpha,PI/4)
		"hydro_q":
			_particles(v,c,r*.5,color,t,alpha*.7,8)
			_glint(v,c-Vector2(0,13+10*sin(t*PI)),7*(1-t),color,alpha,PI/2)
		"hydro_e": _particles(v,c,r,color,t,alpha,10)
		"electro_q": _glint(v,c-Vector2(0,16),8,color,alpha,PI/4)
		"electro_e": _particles(v,c,r,color,t,alpha*.65,8,1.5)
		"geo_q","geo_e":
			_particles(v,c,r*.86,color,t,alpha,8 if key=="geo_q" else 14,1.1,true)
			_glint(v,c-Vector2(0,7),8*(1-t),color,alpha,PI/4)
			if key=="geo_e":
				for i in (3 if _lean(v) else 5):
					var a=float(i)*TAU/5-PI/2
					var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*(.28+.45*t)-Vector2(0,10)
					_chip(v,p,20*(1-t*.35),Color("#ffe179"),alpha)
		"cryo_q":
			_ice_blade(v,c-Vector2(0,12),26*(1-t*.6),alpha,PI/4)
			_particles(v,c,r*.7,color,t,alpha,8,2,true)
		"cryo_e":
			if int(e.get("step",0))>=4: _particles(v,c,r,color,t,alpha,18,1,true)
			else: _particles(v,c,r*.68,color,t,alpha*.6,6,1,true)
		"anemo_e":
			WindSkillVfx.fragments(v,c-Vector2(0,16),color,t,alpha)
			for i in (2 if _lean(v) else 3):
				var a=float(i)*TAU/3+t*.65
				var heading=Vector2(cos(a),sin(a)*.5).normalized()
				WindSkillVfx.crescent(v,c+heading*(20+65*t)-Vector2(0,18+30*t),heading,Vector2(21,31),color,alpha,true)

static func _falling_blade(v,c: Vector2,height: float,color: Color,alpha: float) -> void:
	var p=c-Vector2(0,height+20)
	_chip(v,p,29,color,alpha)
	_rail(v,PackedVector2Array([p-Vector2(0,64),p+Vector2(0,20)]),color,alpha*.38,1.5)
	v.draw_line(p+Vector2(-9,-15),p+Vector2(9,-15),Color(Color.WHITE,alpha),1.4,true)

static func _comet(v,c: Vector2,height: float,color: Color,alpha: float) -> void:
	var p=c+Vector2(-height*.34,-height)
	var direction=Vector2(.34,1).normalized()
	var side=direction.orthogonal()
	var tail=p-direction*53
	var flame=PackedVector2Array([p+direction*10,p+side*9-direction*8,tail+side*3,p-direction*23,tail-side*3,p-side*8-direction*6])
	if not _lean(v): _glow(v,GLOW,p,Vector2(62,62),color,alpha*.95)
	v.draw_colored_polygon(flame,Color(color,alpha*.85))
	v.draw_colored_polygon(PackedVector2Array([p+direction*8,p+side*5-direction*7,p-direction*40,p-side*5-direction*7]),Color(color.lightened(.65),alpha*.95))
	_rail(v,PackedVector2Array([tail,p-direction*15,p]),color,alpha,3.0)
	_chip(v,p,15,color,alpha,direction.angle()+PI/2)
	_glint(v,p,8,color,alpha,PI/3)

static func zone(v,z: Dictionary) -> void:
	var key=str(z.kind)
	if not supports(key): return
	var color: Color=PALETTE.get(str(z.element),PALETTE.none)
	var alpha=minf(1,float(z.elapsed)/.16)*minf(1,float(z.life)/.4)
	if bool(z.get("cancelled",false)): alpha*=minf(1,float(z.life)/.45)
	var c=v.world_to_screen(z.pos)+Vector2(0,8)
	var r: Vector2=v.sim.ability_area_screen_radii(z.pos,float(z.radius))
	var time=float(z.elapsed)
	if key in ["pyro_q","geo_q","electro_q","geo_e"]: return
	if key=="pyro_e":
		if time<1.4: _comet(v,c,160*(1-fposmod(time,.7)/.7),color,alpha)
		return
	if key=="cryo_q":
		if int(z.step)<5:
			var from=v.world_to_screen(z.source)+Vector2((int(z.step)-2)*13,-35)
			var progress=clampf((time-float(z.step)*.24)/.24,0,1)
			var p=from.lerp(c,progress)
			_rail(v,PackedVector2Array([from.lerp(c,maxf(0,progress-.16)),p]),color,alpha,1.3)
			_ice_blade(v,p,28,alpha,(c-from).angle()+PI/2)
		return
	if key in ["cryo_e","anemo_e"] and time>(4.0 if key=="cryo_e" else 3.0): return
	if key=="hydro_e" and time>2.2: return
	_ring(v,c,r,color,alpha*.15,1.0)
	match key:
		"hydro_q":
			var pulse=fposmod(time,1.0)
			_ring(v,c,r*(.13+pulse*.72),color,alpha*(1-pulse)*.26,1.1)
			for i in (3 if _lean(v) else 6):
				var a=float(i)*TAU/6
				var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*.55
				var f=fposmod(time*.8+float(i)*.16,1)
				var bead=c.lerp(p,f)-Vector2(0,sin(f*PI)*21)
				v.draw_circle(bead,1.6,Color(Color.WHITE,alpha*.75))
		"hydro_e":
			var direction: Vector2=(v.world_to_screen(Vector2(z.pos)+Vector2(z.direction)*20)-v.world_to_screen(z.pos)).normalized()
			WindSkillVfx.crescent(v,c+direction*18-Vector2(0,15),direction,Vector2(37,55),Color("#66d8ff"),alpha,true)
			var angle=direction.angle()
			for i in (3 if _lean(v) else 6):
				var a=angle-PI*.4+float(i)/5*PI*.8
				var travel=fposmod(time*1.8+float(i)*.17,1.0)
				var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*(.6+.37*travel)-Vector2(0,7+sin(travel*PI)*8)
				_rail(v,PackedVector2Array([p-direction*9,p]),color,alpha*(1-travel*.5),1.5)
				_chip(v,p,12+float(i%3)*3,color,alpha*(.85-travel*.3),direction.angle()+PI/2)
				_glint(v,p,4.7,color,alpha*.8,a)
		"electro_e":
			for i in 3:
				var a=float(i)*TAU/3-PI/2
				var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)
				_ring(v,p,Vector2(14,5),color,alpha*.45,1.0)
				_chip(v,p-Vector2(0,18),14,color,alpha*.6,a)
				var pulse=1-smoothstep(0,.18,fposmod(time+float(i)*.06,.75))
				_glint(v,p-Vector2(0,18),5+3*pulse,color,alpha*(.35+.6*pulse),PI/4)
		"cryo_e":
			var growth=minf(1,time/4.0)
			_ice_blade(v,c-Vector2(0,15),16+growth*13,alpha*.9)
			for i in (4 if _lean(v) else 8):
				var a=float(i)*TAU/8
				var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*.83
				_ice_blade(v,p,12+growth*8,alpha*.85,a+PI/2)
				var pulse=pow(maxf(0,sin(time*3+float(i))),7)
				_glint(v,p,4,color,alpha*pulse*.7,a)
		"anemo_e":
			for blade in (2 if _lean(v) else 3):
				var f=fposmod(time*.70+float(blade)/3,1)
				var a=float(blade)*TAU/3-time*2.0
				var p=c+Vector2(cos(a)*r.x,sin(a)*r.y)*(.78-f*.52)-Vector2(0,15+f*25)
				var heading=(c-Vector2(0,30)-p).normalized()
				WindSkillVfx.crescent(v,p,heading,Vector2(23,34),color,alpha*(.8+f*.2),true)
