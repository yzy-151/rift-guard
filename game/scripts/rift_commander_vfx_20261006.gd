extends RefCounted
const G = preload("res://scripts/boss_vfx_geometry_20261006.gd")
const VIOLET := Color("#b069ff")
const CORE := Color("#fff2ff")

static func _color(row: Dictionary) -> Color:
	return Color("#ff456b") if bool(row.get("enraged",false)) or int(row.get("phase",row.get("boss_phase",1)))>=3 else VIOLET

static func _seal(v, p: Vector2, size: float, color: Color, t: float) -> void:
	var s := size*(1-.26*t)
	G.body(v,PackedVector2Array([p+Vector2(0,-s),p+Vector2(s*.55,0),p+Vector2(0,s),p+Vector2(-s*.55,0)]),Color("#251633",.65),false)
	G.body(v,PackedVector2Array([p+Vector2(0,-s*.72),p+Vector2(s*.22,0),p+Vector2(0,s*.70),p+Vector2(-s*.22,0)]),Color(color,.5+.5*t),false)
	G.glow(v,p,Vector2.ONE*s*5,color,.22+t*.34)

static func warning(v, enemy: Dictionary) -> bool:
	var move := str(enemy.get("special_move",""))
	if not move.begins_with("rift_"): return false
	var t := G.progress_of(enemy)
	var source := Vector2(enemy.pos)
	var points: Array = enemy.get("special_warning_positions",[])
	var radius := float(enemy.get("special_warning_radius",100))
	var color := _color(enemy)
	if move=="rift_laser":
		for target: Vector2 in points:
			G.capsule(v,source,target,radius,Color(G.DANGER,.68+.32*t),.025+.04*t)
			var a: Vector2 = v.world_to_screen(source)
			var b: Vector2 = v.world_to_screen(target)
			var d := (b-a).normalized()
			_seal(v,a+d*54-Vector2(0,25),24,color,t)
			if t>.70: G.bolt(v,a+d*42,a+d*112,3+(t-.7)*18,Color(color,(t-.7)/.3),floori(v.clock*10))
	elif move=="rift_overhead":
		for target: Vector2 in points:
			G.area(v,target,radius,Color(G.DANGER,.7+t*.3),.035+.045*t,3)
			var p: Vector2 = G.area_center(v,target)
			_seal(v,p-Vector2(0,128-58*t),17+t*11,color,t)
			if t>.6: G.streak(v,p-Vector2(0,82),p-Vector2(0,30),8,Color(color,.35*(t-.6)/.4))
	elif move=="rift_storm":
		G.area(v,source,radius,Color(G.DANGER,.85),.055+.035*t,3)
		var center: Vector2 = G.area_center(v,source)
		var radii: Vector2 = G.area_radii(v,source,radius)
		# Charged spires on the dangerous perimeter converge towards the caster.
		for index in 8:
			var d := Vector2.from_angle(index*TAU/8+.19)
			var p := center+d*radii*.88
			var height := 12+32*t*t
			G.body(v,PackedVector2Array([p+Vector2(-5,0),p+Vector2(0,-height),p+Vector2(7,0)]),Color(color,.3+t*.55),false)
		G.ellipse(v,center,radii*(.14+.16*t),Color(color,.12+t*.14))
		G.glow(v,center-Vector2(0,45),Vector2(150,145),color,.24+t*.28)
	else:
		var p: Vector2 = v.world_to_screen(source)-Vector2(0,50)
		for index in 4:
			var angle: float = v.clock*2+index*TAU/4
			_seal(v,p+Vector2.from_angle(angle)*Vector2(42,25),8+7*t,color,t)
	return true

static func _rupture(v, p: Vector2, radii: Vector2, age: float, color: Color) -> void:
	if age<0 or age>.55: return
	var fade := 1-smoothstep(.11,.55,age)
	var grow := .16+.95*(1-exp(-age*22))
	var points := PackedVector2Array()
	for index in 40:
		var a := index*TAU/40
		var k := .93+(.16 if index%2==0 else -.07)
		points.append(p+Vector2.from_angle(a)*radii*grow*k)
	G.body(v,points,Color(color,fade*.22),false)
	if age<.14: G.body(v,points,Color(CORE,(1-age/.14)*.74),false)
	G.band(v,p,radii,grow,maxf(.0,grow-.045-.12*fade),Color(color,fade*.70))
	G.glow(v,p,radii*2.3,color,.54*fade)
	G.shards(v,p,minf(120,radii.x*.5),age,color,11)

static func _storm_release(v, world: Vector2, radius: float, age: float, color: Color) -> void:
	if age<0 or age>.52: return
	var p: Vector2 = G.area_center(v,world)
	var radii: Vector2 = G.area_radii(v,world,radius)
	var fade := 1-smoothstep(.10,.52,age)
	var expansion := .18+.83*(1-exp(-age*19))
	# A single charged rupture throws broad energy splinters; no repeated ring hits.
	if age<.075: G.ellipse(v,p,Vector2(94,48)*(1+age*3),Color(CORE,(1-age/.075)*.75))
	G.glow(v,p,radii*1.45,color,.44*fade)
	for index in (8 if bool(v.reduced_effects) else 14):
		var angle := float(index)*2.39996+.21
		var d := Vector2.from_angle(angle)
		var position := p+d*radii*expansion
		var orientation := (d*Vector2(1,.5)).normalized()
		var normal := orientation.orthogonal()
		# Forked discharges race outwards, instead of stationary decorative crystals.
		var root_position := p+d*radii*maxf(.06,expansion-.27)
		var width := maxf(.8,(2.4+float(index%3)*.55)*fade)
		G.bolt(v,root_position,position,width,Color(color,fade*.88),index+floori(age*28))
		if age<.19 and index%2==0:
			G.bolt(v,position-normal*18,position+orientation*21,width*.62,Color(CORE,fade*.75),index+2)
	G.shards(v,p,110,age,color,11)

static func effect(v, row: Dictionary) -> bool:
	var kind := str(row.get("kind",""))
	if not kind.begins_with("rift_"): return false
	var age := G.age_of(row)
	var source := Vector2(row.get("source",row.pos))
	var color := _color(row)
	if kind=="rift_laser" and age<.38:
		for target: Vector2 in row.get("targets",[row.get("target",source)]):
			var a: Vector2 = v.world_to_screen(source)
			var b: Vector2 = v.world_to_screen(target)
			var fade := 1-smoothstep(.09,.38,age)
			G.bolt(v,a,b,(8+float(row.get("phase",1))*1.5)*fade,Color(color,fade),floori(age*36))
			G.glow(v,a,Vector2(145,115),color,fade*.5)
	elif kind=="rift_overhead":
		for world: Vector2 in row.get("points",[]):
			var p: Vector2 = G.area_center(v,world)
			var scale: float = v.world_depth_scale(world)
			if age<.18:
				var fade := 1-age/.18
				var column := PackedVector2Array([p+Vector2(-28,0)*scale,p+Vector2(-7,-220)*scale,p+Vector2(9,-220)*scale,p+Vector2(34,0)*scale])
				G.body(v,column,Color(color,.78*fade),false)
				G.streak(v,p-Vector2(0,220)*scale,p,22*scale,Color(CORE,fade))
			_rupture(v,p,G.area_radii(v,world,float(row.get("radius",100))),age,color)
	elif kind=="rift_storm":
		_storm_release(v,source,float(row.radius),age,color)
	elif kind=="rift_orb_hit":
		_rupture(v,G.area_center(v,Vector2(row.pos)),G.area_radii(v,Vector2(row.pos),float(row.get("radius",62)))*.64,age,color)
	elif kind=="rift_orbs" and age<.2:
		var p: Vector2 = v.world_to_screen(source)-Vector2(0,40)
		G.glow(v,p,Vector2(125,125),color,(1-age/.2)*.56)
	return true

static func projectile(v, row: Dictionary) -> bool:
	if str(row.get("kind",""))!="rift_orb": return false
	var p: Vector2 = v.world_to_screen(Vector2(row.pos))
	var scale: float = v.world_depth_scale(Vector2(row.pos))
	var color := Color("#ff456b") if bool(row.get("enraged",false)) else VIOLET
	G.glow(v,p,Vector2.ONE*79*scale,color,.47)
	G.ellipse(v,p,Vector2.ONE*12.5*scale,Color(color,.9))
	G.ellipse(v,p-Vector2(2,2)*scale,Vector2.ONE*8*scale,CORE)
	G.ellipse(v,p-Vector2(4,4)*scale,Vector2.ONE*3*scale,Color.WHITE)
	var target_id := int(row.get("target_id",-1))
	if target_id>=0 and target_id<v.sim.heroes.size():
		var target: Vector2 = v.world_to_screen(Vector2(v.sim.heroes[target_id].pos))
		var d := (target-p).normalized()
		G.streak(v,p-d*48*scale,p-d*14*scale,9*scale,Color(color,.52))
	return true
