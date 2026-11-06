extends RefCounted
const G = preload("res://scripts/boss_vfx_geometry_20261006.gd")
const GEL := Color("#8858e8")
const ROYAL := Color("#bc58e9")
const ELEMENTS := {"pyro":Color("#ff755d"),"hydro":Color("#58cef8"),"electro":Color("#b16bff"),"cryo":Color("#bbf4ff"),"anemo":Color("#68f2c4")}

static func _color(row: Dictionary) -> Color:
	return ELEMENTS.get(str(row.get("element","")),ROYAL if int(row.get("phase",1))>=2 else GEL)

static func _jelly(v, p: Vector2, size: Vector2, color: Color, squash: float = 1.0, crown: bool = false, alpha: float = 1.0) -> void:
	var points := PackedVector2Array()
	var radii := size*Vector2(squash,1/maxf(.4,squash))
	# Tiny wet droplets fade in alpha instead of collapsing 24 vertices to a point.
	radii = Vector2(maxf(1.1,radii.x),maxf(1.1,radii.y))
	for index in 24:
		var a := float(index)*TAU/24
		var bulge := 1+.045*sin(a*5)
		points.append(p+Vector2(cos(a),sin(a))*radii*bulge)
	G.body(v,points,Color(color.darkened(.16),alpha))
	G.ellipse(v,p+Vector2(0,-size.y*.16),radii*Vector2(.86,.73),Color(color,alpha),false)
	G.ellipse(v,p+Vector2(-size.x*.28,-size.y*.34),size*Vector2(.20,.14),Color("#eafff7",alpha*.9),false)
	if crown:
		var top := p+Vector2(0,-radii.y*.95)
		var c := size.x*.60
		G.body(v,PackedVector2Array([top+Vector2(-c,0),top+Vector2(-c,-c*.55),top+Vector2(-c*.38,-c*.24),top+Vector2(0,-c*.86),top+Vector2(c*.38,-c*.24),top+Vector2(c,-c*.55),top+Vector2(c,0)]),Color("#ffd34c",alpha))
		for side in [-1.0,1.0]:
			G.ellipse(v,p+Vector2(side*size.x*.27,-size.y*.02),Vector2(2.0,3.2),Color("#202038",alpha),false)

static func _wet_splash(v, world: Vector2, radius: float, age: float, color: Color, big: bool = false) -> void:
	if age<0 or age>.65: return
	var p: Vector2 = G.area_center(v,world)
	var scale: float = v.world_depth_scale(world)
	var radii: Vector2 = G.area_radii(v,world,radius)
	var fade := 1-smoothstep(.12,.42,age)
	var expand := .36+.68*(1-exp(-age*26))
	var lobes := PackedVector2Array()
	for index in 36:
		var angle := TAU*float(index)/36
		var lobe := 1+.09*sin(angle*7+1.3)+.05*cos(angle*11)
		lobes.append(p+Vector2.from_angle(angle)*radii*expand*lobe)
	# The contact compresses into a wet sheet, then retracts with the droplets.
	G.body(v,lobes,Color(color.darkened(.25),fade*.52),false)
	if age<.12: G.ellipse(v,p,radii*(.40+age*3),Color("#edfff7",(1-age/.12)*.85),false)
	var count := 6 if bool(v.reduced_effects) else (11 if big else 8)
	for index in count:
		var angle := float(index)*2.39996+.36
		var d := Vector2.from_angle(angle)
		var ground := p+d*radii*(.25+age*1.55)
		var lift := maxf(0,age*(260+float(index%3)*70)-age*age*790)*scale
		var drop := ground-Vector2(0,lift)
		var stretch := 1.25+float(index%3)*.38-age*.65
		_jelly(v,drop,Vector2(5+index%3*2,8+index%2*3)*scale*maxf(.1,fade),color,1/maxf(.7,stretch),false,fade)
		if age<.13:
			G.streak(v,ground,drop,3*scale,color,fade*.55)
	G.glow(v,p,radii*2.3,color,.30*fade)

static func _suction(v, p: Vector2, radii: Vector2, progress: float, color: Color, alpha: float) -> void:
	for index in 8:
		var angle := float(index)*TAU/8+.24
		var d := Vector2.from_angle(angle)
		var t := fposmod(progress*1.4+float(index)*.121,1.0)
		var head := p+d*radii*(1-t)*.93
		var tail := p+d*radii*clampf(1-t+.24,0,1)
		G.streak(v,tail,head,8+9*t,color,alpha*(.25+.75*t))

static func warning(v, enemy: Dictionary) -> bool:
	var move := str(enemy.get("special_move",""))
	if not move.begins_with("slime_"): return false
	var t := G.progress_of(enemy)
	var radius := float(enemy.get("special_warning_radius",100))
	var points: Array = enemy.get("special_warning_positions",[])
	var color := ROYAL if int(enemy.get("boss_phase",1))>=2 else GEL
	for world: Vector2 in points:
		G.area(v,world,radius,Color(G.DANGER,.70+.3*t),.035+.055*t,2.5)
		var p: Vector2 = G.area_center(v,world)
		var r: Vector2 = G.area_radii(v,world,radius)
		if move=="slime_reflux":
			_suction(v,p,r,t,color,.45+.5*t)
			G.ellipse(v,p,r*(.16+.28*t),Color(color,.06+.09*t))
		elif move=="slime_bounce":
			var shadow := .32+.65*t
			G.ellipse(v,p,r*.63,Color("#131626",shadow*.36))
			if t>.62:
				_jelly(v,p+Vector2(0,-(1-t)*195),Vector2(34,36)*(.8+t*.3),color,.90,true,(t-.62)/.38*.60)
		elif move=="slime_court":
			# A royal split marker, not a fictitious damaging full-circle burst.
			var m := p+Vector2(0,-12)
			G.body(v,PackedVector2Array([m+Vector2(-12,0),m+Vector2(-12,-15),m+Vector2(-4,-9),m+Vector2(0,-22),m+Vector2(4,-9),m+Vector2(12,-15),m+Vector2(12,0)]),Color("#ffe390",.35+.6*t),false)
		elif move=="slime_burst":
			var index := points.find(world)
			var tint: Color = ELEMENTS.values()[index%ELEMENTS.size()]
			_jelly(v,p+Vector2(0,-7),Vector2(10,7),tint,1,false,.3+t*.4)
	return true

static func projectile(v, row: Dictionary) -> bool:
	var kind := str(row.get("kind",""))
	if kind not in ["slime_glob","slime_image"]: return false
	if float(row.get("delay",0))>0: return true
	var p: Vector2 = v.world_to_screen(Vector2(row.pos))
	var scale: float = v.world_depth_scale(Vector2(row.pos))
	var target: Vector2 = v.world_to_screen(Vector2(row.get("target_pos",row.pos)))
	var d := (target-p).normalized()
	var color := _color(row)
	# Wet rounded projectiles and recognizable mini royal clones.
	G.glow(v,p,Vector2(70,55)*scale,color,.38)
	if kind=="slime_image":
		_jelly(v,p-Vector2(0,13)*scale,Vector2(23,20)*scale,color,1.13,true)
		G.ellipse(v,p+Vector2(0,5),Vector2(24,7)*scale,Color("#0c131b",.25))
	else:
		_jelly(v,p,Vector2(15,12)*scale,color,1.15,false)
		for index in 2: _jelly(v,p-d*(22+index*14)*scale,Vector2(7,5)*scale*(1-index*.35),color,1,false,.42-index*.17)
	return true

static func hazard(v, row: Dictionary) -> bool:
	var kind := str(row.get("kind",""))
	if kind not in ["slime_pool","slime_bounce_impact","slime_court_final"]: return false
	var world := Vector2(row.pos)
	var radius := float(row.get("radius",100))
	var delay := float(row.get("delay",0))
	var color := _color(row)
	if kind=="slime_pool":
		var p: Vector2 = G.area_center(v,world)
		var r: Vector2 = G.area_radii(v,world,radius)
		var fade := clampf(float(row.life)/.45,0,1)
		G.area(v,world,radius,Color(color,.68*fade),.17*fade,3)
		for index in 3:
			var bubble := p+Vector2(sin(v.clock*1.7+index*2.1)*r.x*.42,cos(v.clock*1.3+index)*r.y*.38)
			_jelly(v,bubble,Vector2(6,3)*(1+.20*sin(v.clock*3+index)),color,1,false,.50*fade)
	elif delay>0:
		G.area(v,world,radius,Color(G.DANGER,.9),.08,3)
		if kind=="slime_court_final":
			G.ellipse(v,G.area_center(v,world),G.area_radii(v,world,radius)*(1-clampf(delay/1.05,0,1)*.7),Color(color,.09))
	return true

static func effect(v, row: Dictionary) -> bool:
	var kind := str(row.get("kind",""))
	if not kind.begins_with("slime_"): return false
	var age := G.age_of(row)
	var world := Vector2(row.pos)
	var radius := float(row.get("radius",100))
	var color := _color(row)
	if kind in ["slime_bounce_hit","slime_glob_hit","slime_court_hit","slime_court_final"]:
		_wet_splash(v,world,radius,age,color,kind=="slime_court_final")
	elif kind=="slime_reflux" and age<.48:
		var p: Vector2 = G.area_center(v,world)
		var radii: Vector2 = G.area_radii(v,world,radius)
		_suction(v,p,radii,.54+age*1.9,color,1-smoothstep(.12,.48,age))
		G.glow(v,p,radii*.75,color,(1-age/.48)*.46)
		if age<.12: G.ellipse(v,p,radii*.2,Color("#d4fff3",(1-age/.12)*.5))
	elif kind in ["slime_burst","slime_court"] and age<.18:
		var p: Vector2 = v.world_to_screen(world)
		G.ellipse(v,p+Vector2(0,-35),Vector2(28,36),Color(color,(1-age/.18)*.42))
		G.glow(v,p+Vector2(0,-35),Vector2(120,100),color,(1-age/.18)*.36)
	return true
