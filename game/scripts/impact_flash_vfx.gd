extends RefCounted
## Short, asymmetric light events inspired by the reference footage.
## Stateless drawing: no gameplay RNG, damage, nodes or independent clocks.
const PAPER := Color("#fffceb")
const FLARE := preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")

static func noise(seed: int) -> float:
	return fposmod(sin(float(seed) * 12.9898) * 43758.5453, 1.0)

static func glow(v, point: Vector2, size: Vector2, color: Color, alpha: float, angle: float = 0.0) -> void:
	if not v.reduced_effects and v.light_layer != null:
		v.light_layer.glow(point, size, color, alpha, angle)

static func shard(v, point: Vector2, direction: Vector2, length: float, width: float, color: Color) -> void:
	if length < 0.2 or width < 0.1 or color.a < 0.01: return
	var side := direction.orthogonal()
	v.draw_colored_polygon(PackedVector2Array([point+direction*length,point+side*width,point-direction*length*0.55,point-side*width*0.58]),color)

static func burst(v, point: Vector2, age: float, size: float, color: Color, seed: int, reduced: bool = false) -> void:
	if age < 0.0 or age >= 0.48: return
	var t := age / 0.48
	var open := 1.0-pow(1.0-t,4.0)
	var flash := (1.0-smoothstep(0.045,0.16,age)) * smoothstep(0.0,0.015,age)
	var spread := 12.0+open*46.0
	var fade := 1.0-smoothstep(0.14,0.47,age)
	glow(v,point,Vector2(148,115)*size,color,flash*0.85)
	glow(v,point,Vector2(49,43)*size,PAPER,flash*1.5)
	# A brief irregular white-hot silhouette opens, then leaves an empty centre.
	if flash > 0.01:
		var silhouette := PackedVector2Array()
		var core := (8.0+open*30.0)*size
		for i in 20:
			var angle := float(i)*TAU/20.0+noise(seed)*TAU
			var radius := core*(0.52+noise(seed+i*17)*0.60) if i%2==0 else core*0.29
			silhouette.append(point+Vector2.from_angle(angle)*radius)
		v.draw_colored_polygon(silhouette,Color(color,flash*0.92))
		for i in silhouette.size(): silhouette[i]=point+(silhouette[i]-point)*0.70
		v.draw_colored_polygon(silhouette,Color(PAPER,flash))
	# Unequal fragments break away in small clusters instead of wheel spokes.
	for i in (7 if reduced else 17):
		var random := noise(seed+i*31)
		var direction := Vector2.from_angle(i*2.399+noise(seed)*4.7)
		var travel := spread*(0.58+random*0.75)*size
		var head := point+direction*travel+Vector2(0,age*age*(40+random*90))*size
		var length := (3.0+(1.0-t)*(9.0+random*10.0))*size
		var alpha := fade*(0.5+random*0.5)
		shard(v,head,direction,length,1.0+3.0*(1.0-t)*size,Color(color,alpha*0.85))
		shard(v,head+direction*1.5,direction,length*0.60,0.65+size*0.9,Color(PAPER,alpha))
		if i%4==0: glow(v,head,Vector2.ONE*(18+random*12)*size,color,alpha*0.42)
	# Soft, detached wisps dissipate behind the fragments; no opaque smoke disc.
	if not reduced:
		for i in 4:
			var direction := Vector2.from_angle(i*2.399+seed*0.37)
			var center := point+direction*(10+open*29)*size-Vector2(0,t*17)*size
			var wisp := (18.0+t*24.0)*size
			v.draw_texture_rect(FLARE,Rect2(center-Vector2(wisp,wisp*0.38),Vector2(wisp*2,wisp*0.76)),false,Color(color,fade*0.18))

static func beam(v, start: Vector2, finish: Vector2, age: float, duration: float, color: Color) -> void:
	if age < 0.0 or age >= duration or start.distance_squared_to(finish)<1.0: return
	var t := clampf(age/maxf(0.01,duration),0,1)
	var fade := 1.0-smoothstep(0.30,1.0,t)
	var width := 1.5+pow(1.0-t,0.65)*5.5
	var direction := (finish-start).normalized()
	var side := direction.orthogonal()
	# Every strand stays collinear: full distance, one decisive release.
	v.draw_line(start,finish,Color(color,fade*0.12),width*4.0,true)
	v.draw_line(start,finish,Color(color.lightened(0.22),fade*0.65),width*1.75,true)
	v.draw_line(start,finish,Color(PAPER,fade),width*0.62,true)
	glow(v,(start+finish)*0.5,Vector2(start.distance_to(finish)+28,43),color,fade*0.6,direction.angle())
	glow(v,start,Vector2(60,54),PAPER,fade*0.85)
	glow(v,finish,Vector2(46,40),color,fade*0.9)
	var flare := (1.0-smoothstep(0.0,0.5,t))*18
	if flare>0.2:
		shard(v,start,side,flare,2.5,Color(PAPER,fade))
		shard(v,finish,side,flare*0.58,1.8,Color(PAPER,fade))
	if not v.reduced_effects:
		for i in 6:
			var fraction := float(i+1)/7.0
			var point := start.lerp(finish,fraction)+side*(1 if i%2 else -1)*(5+t*13)
			shard(v,point,direction,3.0+fade*8,0.7,Color(color.lightened(0.65),fade*0.7))

static func rift(v, point: Vector2, radius: float, color: Color, motion: float, alpha: float, spawned_age: float) -> void:
	if radius<1 or alpha<0.01: return
	var spawned := spawned_age>=0.0
	var emergence := 1.0-smoothstep(0.08,0.5,spawned_age) if spawned else 0.0
	var fade := alpha*(1.0-smoothstep(0.35,0.9,spawned_age)) if spawned else alpha*0.8
	if fade<0.01: return
	var height := radius*(1.5+emergence*0.60)
	var base := point+Vector2(0,radius*0.55)
	var top := base-Vector2(0,height*1.6)
	var wide := radius*(0.07+emergence*0.18)
	# An upright tear of light. No dark round hole painted over the floor.
	glow(v,(base+top)*0.5,Vector2(radius*1.8,height*2.2),color,fade*0.3)
	for strand in [-1.0,1.0]:
		var line := PackedVector2Array()
		for i in 17:
			var f := float(i)/16.0
			var bend:float=sin(f*PI)*(wide*float(strand)+sin(f*TAU+motion*4.3)*2.8)
			line.append(base.lerp(top,f)+Vector2(bend,0))
		v.draw_polyline(line,Color(color,fade*0.16),7.0,true)
		v.draw_polyline(line,Color(color.lightened(0.35),fade),2.1,true)
		if not v.reduced_effects: v.draw_polyline(line,Color(PAPER,fade*0.8),0.75,true)
	for i in (4 if v.reduced_effects else 9):
		var phase := fposmod(motion*0.8+i*0.137,1.0)
		var side := -1.0 if i%2 else 1.0
		var x := side*radius*(0.25+pow(1.0-phase,2.0)*0.7)
		var mote := base+Vector2(x,-phase*height*1.65)
		var a := fade*sin(phase*PI)
		shard(v,mote,Vector2(0.4*side,-1).normalized(),2.0+phase*3.5,0.9,Color(PAPER,a))
	if emergence>0.0:
		beam(v,base-Vector2(0,3),top+Vector2(0,4),spawned_age,0.24,color)
		glow(v,base-Vector2(0,height*0.45),Vector2(72,98),PAPER,emergence*0.75)
