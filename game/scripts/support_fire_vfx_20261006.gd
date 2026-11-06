extends RefCounted
const G = preload("res://scripts/boss_vfx_geometry_20261006.gd")
const Sim = preload("res://scripts/combat_simulation.gd")
const HOT := Color("#ffbc41")
const RED := Color("#f0224b")

static func _lane(v, support: Dictionary) -> PackedVector2Array:
	var field: Rect2 = v.sim.active_view_rect if v.sim.endless_mode else Sim.MOVE_AREA
	var y := float(support.get("lane_y",350))
	return PackedVector2Array([v.world_to_screen(Vector2(field.position.x,y-58)),v.world_to_screen(Vector2(field.end.x,y-58)),v.world_to_screen(Vector2(field.end.x,y+58)),v.world_to_screen(Vector2(field.position.x,y+58))])

static func warning(v, kind: String) -> bool:
	var key := "support_barrage" if kind=="barrage" else "support_crossfire"
	if not v.sim.supports.has(key): return false
	var support: Dictionary = v.sim.supports[key]
	var total := 1.35 if kind=="barrage" else .85
	var remaining := float(support.get("timer",99))
	if remaining<=0 or remaining>total or v.sim.enemies.is_empty(): return true
	var t := 1-remaining/total
	if kind=="barrage":
		if not support.has("target_point"): return true
		var world := Vector2(support.target_point)
		G.area(v,world,float(support.get("radius",105)),Color(RED,.8),.045+t*.045,3,true)
		var p: Vector2 = G.area_center(v,world,true)
		var scale: float = v.world_depth_scale(world)
		# Shell arrives before the actual impact frame, already at the locked aim.
		if t>.70:
			var fly := (t-.70)/.30
			var head := p+Vector2(36*(1-fly),-250*(1-fly))*scale
			G.glow(v,head,Vector2(95,120)*scale,RED,.50)
			G.streak(v,head+Vector2(13,-92)*scale,head,29*scale,HOT)
			G.ellipse(v,head,Vector2(10,15)*scale,Color("#fff7bd"))
	else:
		if not support.has("lane_y"): return true
		var points := _lane(v,support)
		G.body(v,points,Color(HOT,.035+t*.025),false)
		v.draw_polyline(G.closed(points),Color(RED,.74),2,true)
		for side in [0,1]:
			var p := points[side].lerp(points[3-side],.5)
			var d := Vector2.RIGHT if side==0 else Vector2.LEFT
			G.body(v,PackedVector2Array([p-d*8+Vector2(0,-19),p+d*17+Vector2(0,-13),p+d*17+Vector2(0,13),p-d*8+Vector2(0,19)]),Color("#21161c",.65),false)
			G.streak(v,p-d*8,p+d*28,6+12*t,Color(HOT,.30+t*.65))
	return true

static func _explosion(v, p: Vector2, r: Vector2, age: float) -> void:
	if age<0 or age>.65: return
	var fade := 1-smoothstep(.22,.65,age)
	var spread := 1-exp(-age*19)
	# Opaque collision core opens into separate hot cloud lobes and charcoal ash.
	if age<.10: G.ellipse(v,p-Vector2(0,12),r*Vector2(.45,.9)*(1+age*5),Color("#fff9ce",1-age/.10))
	for index in 7:
		var a := float(index)*2.39996
		var d := Vector2.from_angle(a)
		var center := p+d*r*.55*spread-Vector2(0,(18+index%3*12)*spread)
		var blob := Vector2(25+index%3*13,19+index%2*14)*(.35+.8*spread)
		var cloud := PackedVector2Array()
		for step in 20:
			var angle := float(step)*TAU/20
			var lobe := 1+.13*sin(angle*3+float(index))+.06*sin(angle*7+.4)
			cloud.append(center+Vector2.from_angle(angle)*blob*lobe)
		G.body(v,cloud,Color("#271921",fade*.50),false)
		if age<.27:
			var heat := 1-smoothstep(.055,.27,age)
			var width := 11+float(index%3)*5
			var height := maxf(2.0,(37+float(index%3)*21)*heat)
			var base := center+Vector2(0,8)
			var flame := PackedVector2Array([base+Vector2(-width,5),base+Vector2(-width*.65,-height*.44),base+Vector2(-width*.2,-height),base+Vector2(width*.16,-height*.61),base+Vector2(width*.62,-height*.40),base+Vector2(width,6)])
			G.body(v,flame,Color(RED,heat*.86),false)
			var inner := PackedVector2Array()
			for point: Vector2 in flame: inner.append(base+(point-base)*Vector2(.67,.77))
			G.body(v,inner,Color(HOT,heat*.93),false)
			G.ellipse(v,base-Vector2(0,height*.15),Vector2(width*.33,height*.22),Color("#fff4c0",heat),false)
	G.glow(v,p-Vector2(0,18),r*1.7,HOT,fade*.44)
	G.shards(v,p,minf(r.x,100),age,HOT,29)

static func effect(v, row: Dictionary) -> bool:
	var kind := str(row.get("kind",""))
	if kind not in ["crossfire","barrage"]: return false
	var age := G.age_of(row)
	if kind=="barrage":
		var world := Vector2(row.pos)
		_explosion(v,G.area_center(v,world,true),G.area_radii(v,world,float(row.get("radius",105)),true),age)
	else:
		if age<0 or age>.40: return true
		var points := _lane(v,row)
		var fade := 1-smoothstep(.10,.40,age)
		for side in [0,1]:
			var source := points[side].lerp(points[3-side],.5)
			var target := points[1-side].lerp(points[2+side],.5)
			var normal := (target-source).normalized().orthogonal()
			var bias := normal*(7 if side==0 else -7)
			var d := (target-source).normalized()
			if age<.055:
				v.draw_polyline(PackedVector2Array([source+bias,target+bias]),Color("#fff4ba",1-age/.055),2.2,true)
			# Short alternating packets keep the two directions readable after one real hit.
			for pulse in 3:
				var elapsed := age-float(pulse)*.035
				if elapsed<0 or elapsed>.145: continue
				var progress := elapsed/.145
				var head := source.lerp(target,progress)+bias
				var tail := head-d*minf(82,(target-source).length()*progress)
				G.streak(v,tail,head,7.5,HOT,fade)
				G.glow(v,head,Vector2(53,37),HOT,fade*.35)
			G.body(v,PackedVector2Array([source+normal*19,source+d*45,source-normal*19,source-d*8]),Color("#fff4ba",fade),false)
			G.glow(v,source,Vector2(115,95),HOT,fade*.48)
	for index in mini(6,row.get("hit_positions",[]).size()):
		var world := Vector2(row.hit_positions[index])
		G.shards(v,v.world_to_screen(world)-Vector2(0,19),45,age,HOT,index)
	return true
