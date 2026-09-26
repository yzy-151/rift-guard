extends RefCounted
const GOLD = Color("#ffdc86")
const WHITE = Color("#fff9df")
const RAIN = Color("#81cafa")

static func sword(v,point: Vector2,scale: float,alpha: float) -> void:
	if alpha<0.01 or scale<0.01: return
	var shape=PackedVector2Array([Vector2(0,20),Vector2(-9,-5),Vector2(-6,-78),Vector2(0,-94),Vector2(6,-78),Vector2(9,-5)])
	for i in shape.size(): shape[i]=point+shape[i]*scale
	v.draw_colored_polygon(shape,Color(GOLD,alpha*0.4))
	var edge=shape.duplicate();edge.append(shape[0])
	v.draw_polyline(edge,Color(WHITE,alpha),2.5,true)
	v.draw_line(point+Vector2(0,15)*scale,point+Vector2(0,-83)*scale,Color(WHITE,alpha),3.5,true)
	v.draw_line(point+Vector2(-17,-75)*scale,point+Vector2(17,-75)*scale,Color(GOLD,alpha),4.0,true)

static func neutral(v,e: Dictionary,ultimate: bool) -> void:
	var casting=str(e.kind).ends_with("_cast")
	var t=clampf(1.0-float(e.life)/float(e.total),0.0,1.0)
	var alpha=(0.25+0.75*t) if casting else 1.0-smoothstep(0.30,1.0,t)
	var world=Vector2(e.pos)
	var c=v.world_to_screen(world)+Vector2(0,8)
	var radius=float(e.get("radius",330.0 if ultimate else 145.0))
	var r=v.sim.ability_area_screen_radii(world,radius)
	v._draw_skill_area_ellipse(world,radius,GOLD,alpha*0.6)
	if ultimate:
		if casting:
			var height=lerpf(150.0,5.0,pow(t,5.0))
			sword(v,c+Vector2(0,-height),1.5,alpha)
			for i in 4:
				var angle=float(i)*TAU/4.0+PI/4.0
				var p=c+Vector2(cos(angle)*r.x,sin(angle)*r.y)*0.85
				v.draw_line(p,c,Color(GOLD,alpha*0.18),1.3,true)
		else:
			sword(v,c,1.5,alpha)
			var spread=clampf(t*2.6,0.0,1.0)
			v._draw_dedicated_arc(c,r*maxf(0.04,spread),0,TAU,Color(WHITE,alpha*0.9),5.5*(1.0-t))
			for i in 12:
				var a=float(i)*TAU/12.0
				var d=Vector2(cos(a)*r.x,sin(a)*r.y)
				var p=c+d*(0.2+spread*0.8)
				v.draw_line(c+d*0.22,p,Color(GOLD,alpha*0.45),2.5,true)
				var shard=PackedVector2Array([p+Vector2(0,-(16.0+float(i%3)*7.0)*(1.0-t)),p+Vector2(-5,2),p+Vector2(5,2)])
				if alpha>0.01: v.draw_colored_polygon(shard,Color(WHITE,alpha*0.75))
			if t<0.3:
				v.draw_line(c+Vector2(0,-145),c,Color(GOLD,(1.0-t/0.3)*0.12),25.0,true)
		return
	# Two opposing crescent cuts, with broad white cores and gold afterimages.
	for blade in 2:
		var offset=float(blade)*0.15
		var phase=clampf((t-offset)/(1.0-offset),0.0,1.0)
		var sweep=(-PI*0.9+phase*PI*1.55) if blade==0 else PI*0.9-phase*PI*1.55
		var arc=PackedVector2Array()
		var span=PI*(0.25+phase*0.65) if casting else PI*0.86
		for i in 22:
			var a=sweep-float(i)/21.0*span
			arc.append(c+Vector2(cos(a)*r.x,sin(a)*r.y)*(0.6+phase*0.35))
		v.draw_polyline(arc,Color(GOLD,alpha*0.13),15.0,true)
		v.draw_polyline(arc,Color(GOLD,alpha*0.55),6.5,true)
		v.draw_polyline(arc,Color(WHITE,alpha*0.95),2.8,true)
	if not casting:
		for i in 7:
			var a=float(i)*TAU/7.0
			var d=Vector2(cos(a)*r.x,sin(a)*r.y)
			v.draw_line(c+d*t*0.5,c+d*t,Color(GOLD,alpha*0.65),1.6,true)

static func cloud(v,center: Vector2,radii: Vector2,motion: float,alpha: float) -> void:
	var roof=center+Vector2(0,-106)
	# Scalloped low storm ceiling; horizontal rather than a ground-ring decoration.
	var outline=PackedVector2Array()
	for i in 49:
		var a=float(i)*TAU/48.0
		var scallop=1.0+0.07*sin(a*9.0+motion*0.7)
		outline.append(roof+Vector2(cos(a)*radii.x*0.84,sin(a)*radii.y*0.48)*scallop)
	if alpha>0.01:
		v.draw_colored_polygon(outline,Color(0.15,0.19,0.31,alpha*0.84))
		v.draw_polyline(outline,Color(0.50,0.67,0.87,alpha*0.6),2.5,true)
	for i in 6:
		var x=(float(i)-2.5)*radii.x*0.25
		v.draw_circle(roof+Vector2(x,-9.0+sin(motion*0.5+i)*4),radii.y*0.27,Color(0.25,0.32,0.46,alpha*0.48))
	var drops=14 if v.reduced_effects else 28
	for i in drops:
		var x=sin(float(i)*2.399)*radii.x*0.76
		var y=cos(float(i)*1.7)*radii.y*0.55
		var fall=fposmod(motion*1.6+float(i)*0.137,1.0)
		var p=center+Vector2(x,y-95.0*(1.0-fall))
		v.draw_line(p-Vector2(3,11),p,Color(RAIN,alpha*0.4),1.3,true)
		if fall>0.86:
			v._draw_dedicated_arc(center+Vector2(x,y),Vector2(7,3)*(fall-0.86)*7.0,0,TAU,Color(RAIN,alpha*(1.0-fall)*3.0),1.0)
	v._draw_dedicated_arc(center,radii*0.92,0,TAU,Color(RAIN,alpha*0.3),1.6)

static func thunder(v,e: Dictionary) -> void:
	var t=clampf(1.0-float(e.life)/float(e.total),0.0,1.0)
	var alpha=1.0-smoothstep(0.12,1.0,t)
	var index=0
	for world in e.get("targets",[]):
		var p=v.world_to_screen(world)
		var phase=float(index)*1.4
		var top=p+Vector2(sin(phase)*22.0,-110)
		var bolt=PackedVector2Array([top,top.lerp(p,0.27)+Vector2(12,0),top.lerp(p,0.47)+Vector2(-9,0),top.lerp(p,0.64)+Vector2(8,0),p])
		v.draw_polyline(bolt,Color(RAIN,alpha*0.16),12.0,true)
		v.draw_polyline(bolt,Color(RAIN,alpha*0.8),4.0,true)
		v.draw_polyline(bolt,Color(0.95,0.99,1,alpha),1.7,true)
		v._draw_dedicated_arc(p+Vector2(0,8),Vector2(24,9)*(0.3+t),0,TAU,Color(RAIN,alpha*0.7),2.0)
		index+=1
