extends RefCounted
## Pure cosmetic geometry. Range, movement, pulse timing and damage stay in sim.
const GLOW = preload("res://assets/vfx/combat_20261005/orb_glow.png")
const BODY = preload("res://assets/vfx/hero_skills_20261005/wind_vortex_body_v1.png")
const WIND := Color("#61e7ba")

static func _lean(v) -> bool:
	return v.reduced_effects or v.sim.enemies.size()>100

static func _glow(v,p: Vector2,size: Vector2,color: Color,alpha: float) -> void:
	if alpha<.005: return
	if v.has_method("emit_glow"): v.emit_glow(GLOW,p,size,color,clampf(alpha,0,1))
	else: v.draw_texture_rect(GLOW,Rect2(p-size*.5,size),false,Color(color,clampf(alpha,0,1)))

static func _quad(v,a: Vector2,b: Vector2,c: Vector2,d: Vector2,color: Color) -> void:
	# A projected wind ribbon folds at its left/right extremum. The four corners
	# can become a bow-tie there; draw the two actual folded faces independently.
	# Subpixel tips also vanish at screen-coordinate float precision; omit them.
	if absf((b-a).cross(c-a))>.5:
		v.draw_colored_polygon(PackedVector2Array([a,b,c]),color)
	if absf((c-a).cross(d-a))>.5:
		v.draw_colored_polygon(PackedVector2Array([a,c,d]),color)

static func _crescent_point(p: Vector2,direction: Vector2,size: Vector2,f: float,inset: float) -> Vector2:
	var angle=lerpf(-1.35,1.35,f)
	var width=sin(f*PI)*size.x*.43+.12
	var local=Vector2(cos(angle)*size.x-size.x*.42-width*inset,sin(angle)*size.y)
	return p+local.rotated(direction.angle())

static func _blade_face(v,p: Vector2,direction: Vector2,size: Vector2,color: Color,alpha: float) -> void:
	var steps=12 if _lean(v) else 20
	for i in steps:
		var f=float(i)/steps
		var g=float(i+1)/steps
		var outside=_crescent_point(p,direction,size,f,0)
		var next_outside=_crescent_point(p,direction,size,g,0)
		var inside=_crescent_point(p,direction,size,f,1)
		var next_inside=_crescent_point(p,direction,size,g,1)
		_quad(v,outside,next_outside,next_inside,inside,Color(color,alpha))
		_quad(v,_crescent_point(p,direction,size,f,.15),_crescent_point(p,direction,size,g,.15),_crescent_point(p,direction,size,g,.63),_crescent_point(p,direction,size,f,.63),Color("#f2ffff",alpha*.98))

static func crescent(v,p: Vector2,direction: Vector2,size: Vector2,color: Color,alpha: float,trail: bool=true) -> void:
	if alpha<.005 or size.x<1 or size.y<1: return
	var heading=direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	if trail:
		for tail in (1 if _lean(v) else 2):
			_blade_face(v,p-heading*(14+tail*12),heading,size*(.90-float(tail)*.09),color,alpha*(.19-tail*.08))
	_blade_face(v,p,heading,size,color,alpha)
	_glow(v,p+heading*size.x*.24,Vector2(size.x*2.2,size.y*1.7),color,alpha*.75)
	_glow(v,p+heading*size.x*.23,Vector2(25,25),Color.WHITE,alpha*.84)

static func fragments(v,p: Vector2,color: Color,t: float,alpha: float) -> void:
	for i in (3 if _lean(v) else 6):
		var a=float(i)*TAU/6+.31
		var heading=Vector2(cos(a),sin(a)*.52).normalized()
		var c=p+heading*(10+40*t)-Vector2(0,sin(t*PI)*10)
		_blade_face(v,c,heading,Vector2(9,13)*(1-t*.5),color,alpha*(1-t*.45))
	_glow(v,p,Vector2(45,45),Color.WHITE,alpha*(1-smoothstep(.0,.40,t)))

static func _helix_point(c: Vector2,f: float,time: float,scale: float) -> Vector2:
	var angle=f*TAU*2.15-time*5.8
	var radius=(13+42*f)*scale
	return c+Vector2(cos(angle)*radius,sin(angle)*(4+12*f)*scale-100*f*scale)

static func anemo_tornado(v,z: Dictionary) -> void:
	var total=maxf(.1,float(z.get("total_life",4.2)))
	var life=maxf(0,float(z.get("life",0)))
	var time=maxf(0,total-life)
	var alpha=minf(1,time/.15)*minf(1,life/.42)
	if alpha<.005: return
	var c=v.world_to_screen(Vector2(z.pos))+Vector2(0,8)
	var scale=clampf(float(v.world_depth_scale(z.pos)),.82,1.1)
	var breath=1+sin(time*3.2)*.025
	var size=Vector2(122*breath,154*(1+sin(time*2.1)*.012))*scale
	var shear=sin(time*2.7)*3.0*scale
	var points=PackedVector2Array([c+Vector2(-size.x*.5+shear,-size.y),c+Vector2(size.x*.5+shear,-size.y),c+Vector2(size.x*.5,0),c+Vector2(-size.x*.5,0)])
	var uv=PackedVector2Array([Vector2.ZERO,Vector2(1,0),Vector2.ONE,Vector2(0,1)])
	v.draw_colored_polygon(points,Color(Color.WHITE,alpha),uv,BODY)
	# The single solid cloud sprite stays in reduced mode as one cheap draw;
	# skip ornamental light and debris there rather than rebuilding line coils.
	var radii: Vector2=v.sim.ability_area_screen_radii(z.pos,135*float(z.get("area",1)))
	v._draw_dedicated_arc(c,radii,0,TAU,Color(WIND,alpha*.11),1.0)
	if _lean(v): return
	_glow(v,c-Vector2(0,size.y*.73),Vector2(28,40)*scale,WIND,alpha*.32)
	_glow(v,c-Vector2(0,size.y*.40),Vector2(23,42)*scale,Color.WHITE,alpha*.18)
	for i in 3:
		var f=fposmod(time*.58+float(i)/3,1)
		var a=time*2.2+float(i)*TAU/3
		var p=c+Vector2(cos(a)*(48-30*f),-size.y*(.18+f*.65)+sin(a)*9)*scale
		_blade_face(v,p,Vector2(cos(a),sin(a)).normalized(),Vector2(7,11)*scale,Color("#b7ffec"),alpha*.8)

static func anemo_tornado_fallback(v,z: Dictionary) -> void:
	# Procedural reduced-detail fallback retained for geometry/resource QA only.
	var total=maxf(.1,float(z.get("total_life",4.2)))
	var life=maxf(0,float(z.get("life",0)))
	var time=maxf(0,total-life)
	var alpha=minf(1,time/.15)*minf(1,life/.42)
	if alpha<.005: return
	var c=v.world_to_screen(Vector2(z.pos))+Vector2(0,8)
	var scale=clampf(float(v.world_depth_scale(z.pos)),.82,1.1)
	var radii: Vector2=v.sim.ability_area_screen_radii(z.pos,135*float(z.get("area",1)))
	v._draw_dedicated_arc(c,radii,0,TAU,Color(WIND,alpha*.13),1.0)
	var segments=40 if _lean(v) else 64
	# Each helix segment is a filled ribbon face. Air remains between its coils.
	for i in segments:
		var f=float(i)/segments
		var g=float(i+1)/segments
		var a=_helix_point(c,f,time,scale)
		var b=_helix_point(c,g,time,scale)
		var width=(3.6+f*7.0)*scale
		var next_width=(3.6+g*7.0)*scale
		var front=sin(f*TAU*2.15-time*5.8)>=0
		var color=Color("#88f3cf" if front else "#368c87",alpha*(.90 if front else .58))
		_quad(v,a-Vector2(0,width*.5),b-Vector2(0,next_width*.5),b+Vector2(0,next_width*.5),a+Vector2(0,width*.5),color)
		_quad(v,a-Vector2(0,width*.48),b-Vector2(0,next_width*.48),b-Vector2(0,next_width*.16),a-Vector2(0,width*.16),Color("#edfff8",alpha*(.96 if front else .45)))
		if front and i%12==0: _glow(v,a,Vector2(38,24)*scale,WIND,alpha*.64)
	# A compact lifted core and solid debris reinforce the upward volume.
	_glow(v,c-Vector2(0,45*scale),Vector2(36,72)*scale,WIND,alpha*.35)
	for i in (3 if _lean(v) else 6):
		var f=fposmod(time*.61+float(i)*.17,1)
		var p=_helix_point(c,f,time+.11*float(i),scale)
		var direction=Vector2.from_angle(f*TAU*2.15-time*5.8+PI/2)
		_blade_face(v,p,direction,Vector2(6,9)*scale,Color("#cbfff1"),alpha*(.9-f*.3))

static func legacy_event(v,e: Dictionary) -> bool:
	if str(e.get("kind","")) not in ["traveler_anemo_cast","traveler_anemo_impact"]: return false
	var total=maxf(.01,float(e.get("total",.4)))
	var age=maxf(0,total-float(e.get("life",total)))
	var casting=str(e.kind).ends_with("_cast")
	var t=clampf(age/(total if casting else .36),0,1)
	if not casting and t>=1: return true
	var alpha=.35+t*.6 if casting else 1-smoothstep(.1,1,t)
	var c=v.world_to_screen(Vector2(e.pos))+Vector2(0,-18)
	crescent(v,c-Vector2(20*(1-t),0),Vector2.RIGHT,Vector2(23,31),WIND,alpha,true)
	if not casting: fragments(v,c,WIND,t,alpha)
	return true
