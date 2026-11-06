extends RefCounted
## Petricite choreography. Actual shielding and hit timing stay in Sim.
const G=preload("res://scripts/boss_vfx_geometry_20261006.gd")
const GOLD:=Color("#e8c479")
const IVORY:=Color("#fff4d1")
const STONE:=Color("#a19b88")
const SHADOW:=Color("#292c34")
const PETRICITE:=Color("#d0d2ca")
const DUST:=Color("#737a7f")

static func _profile(v,enemy:Dictionary) -> Dictionary:
	var scale:float=v.world_depth_scale(Vector2(enemy.pos))
	var foot:Vector2=v.world_to_screen(Vector2(enemy.pos))+Vector2(0,12)*scale
	var galio:=str(enemy.kind)=="boss_galio"
	var center:=foot+Vector2(0,-184 if galio else -108)*scale
	var radii:=Vector2(157,201) if galio else Vector2(91,129)
	if v.has_method("_dual_boss_sequence_sample"):
		var sample:Dictionary=v._dual_boss_sequence_sample(enemy)
		if enemy.has("_armor_clip"):
			sample={"state":str(enemy._armor_clip),"frame":int(enemy._armor_frame),"facing":float(enemy._armor_facing)}
		var sequences=v.enemy_sequences
		var bounds:Rect2=sequences.draw_bounds(str(enemy.kind),str(sample.state),int(sample.frame))
		if bounds.size.x>0 and bounds.size.y>0:
			var ratio:Vector2=Vector2.ONE*sequences.display_size(str(enemy.kind))/sequences.cell(str(enemy.kind))
			var offset:Vector2=(bounds.get_center()-sequences.pivot(str(enemy.kind)))*ratio
			offset.x*=float(sample.facing)/float(sequences.definition(str(enemy.kind)).get("native_facing",1))
			center=foot+offset*scale
			radii=bounds.size*ratio*.55+Vector2(10,14)
	return {"center":center,"radii":radii*scale,"scale":scale,"foot":foot}

static func _armor_panel(v,points:PackedVector2Array,power:float,scale:float,shine:float) -> void:
	# Small transparent pieces sit on the armor, without an enclosing bubble.
	G.body(v,points,Color(PETRICITE,.045+.065*power),false)
	var first:Vector2=points[0].lerp(points[1],.08)
	var last:Vector2=points[0].lerp(points[1],.71)
	G.streak(v,first,last,3.0*scale,GOLD,(.30+.43*power)*shine)
	first=points[2].lerp(points[3],.15)
	last=points[2].lerp(points[3],.76)
	G.streak(v,first,last,2.1*scale,IVORY,(.20+.45*power)*shine)
	# The gap between the lit edges remains visible as a broken stone seam.
	var chip:Vector2=points[1].lerp(points[2],.36)
	var along:Vector2=(points[2]-points[1]).normalized()*4.0*scale
	var across:Vector2=along.orthogonal()*.48
	G.body(v,PackedVector2Array([chip+along,chip+across,chip-along*.58,chip-across]),Color(GOLD,(.28+.36*power)*shine),false)

static func _shield_shell(v,enemy:Dictionary,power:float,charging:bool) -> void:
	var profile:=_profile(v,enemy)
	var p:Vector2=profile.center
	var r:Vector2=profile.radii
	var scale:float=profile.scale
	var foot:Vector2=profile.foot
	var galio:=str(enemy.kind)=="boss_galio"
	var compression:float=lerpf(1.025,.985,power) if charging else 1.0
	for side in [-1.0,1.0]:
		var shine:float=.88+.12*sin(float(v.clock)*2.4+side*.8)
		if galio:
			var wing:=PackedVector2Array()
			for unit:Vector2 in [Vector2(.57,-.53),Vector2(.77,-.35),Vector2(.65,-.06),Vector2(.45,-.18)]:
				wing.append(p+Vector2(side*unit.x*r.x*compression,unit.y*r.y))
			_armor_panel(v,wing,power,scale,shine)
		var shoulder:=PackedVector2Array()
		for unit:Vector2 in [Vector2(.43,-.09),Vector2(.64,.02),Vector2(.54,.25),Vector2(.33,.12)]:
			shoulder.append(p+Vector2(side*unit.x*r.x*compression,unit.y*r.y))
		_armor_panel(v,shoulder,power,scale,shine)
		var sole:=foot+Vector2(side*r.x*.32,-3*scale)
		var width:float=minf(25*scale,r.x*.18)
		var height:float=minf(19*scale,r.y*.13)
		var ankle:=PackedVector2Array([sole+Vector2(-width,-height*.9),sole+Vector2(width*.55,-height),sole+Vector2(width,height*.12),sole+Vector2(-width*.68,height*.25)])
		_armor_panel(v,ankle,power,scale,shine)
		if charging and power>.82:
			G.glow(v,sole,Vector2(64,25)*scale,GOLD,(power-.82)*.55)

static func _durand_intake(v,enemy:Dictionary,progress:float) -> void:
	if progress<.70: return
	var center:Vector2=G.area_center(v,Vector2(enemy.pos))
	var r:Vector2=G.area_radii(v,Vector2(enemy.pos),float(enemy.special_warning_radius))
	var t:float=(progress-.70)/.30
	for index in (6 if bool(v.reduced_effects) else 10):
		var angle:float=TAU*float(index)/10+.12
		var direction:=Vector2(cos(angle),sin(angle))
		var p:=center+direction*r*(.93-t*.70)
		var scale:float=v.world_depth_scale(Vector2(enemy.pos))
		var tangent:=Vector2(-direction.y,direction.x)
		var size:float=(5+index%3)*scale
		G.body(v,PackedVector2Array([p+direction*size,p+tangent*size*.52,p-direction*size*.9,p-tangent*size*.52]),Color(GOLD,.30+t*.60),false)

static func warning(v,enemy:Dictionary) -> bool:
	var move:=str(enemy.get("special_move",""))
	if move not in ["galio_durand","galio_entrance","galio_punch","galio_winds"] or not bool(enemy.get("special_pending",false)): return false
	var progress:float=G.progress_of(enemy)
	var points:Array=enemy.get("special_warning_positions",[enemy.pos])
	var target:Vector2=Vector2(points[0]) if not points.is_empty() else Vector2(enemy.pos)
	var radius:=float(enemy.special_warning_radius)
	match move:
		"galio_durand":
			G.area(v,Vector2(enemy.pos),radius,Color(G.DANGER,.52+progress*.36),.035,2.4)
			_durand_intake(v,enemy,progress)
		"galio_entrance":
			G.area(v,target,radius,Color(G.DANGER,.56+progress*.36),.04,2.8)
			var point:Vector2=G.area_center(v,target)
			var radii:Vector2=G.area_radii(v,target,radius)
			var scale:float=v.world_depth_scale(target)
			var shadow_size:=Vector2(minf(radii.x,170*scale),minf(radii.y,47*scale))
			G.ellipse(v,point,shadow_size*(.78+.22*progress),Color(SHADOW,.10+.28*progress))
			_entrance_actor(v,enemy,target,progress)
			var remaining:=float(enemy.special_warning)
			if remaining<.32:
				_entrance_descent(v,point,scale,1-clampf(remaining/.32,0,1))
		"galio_punch":
			var direction:=(target-Vector2(enemy.pos)).normalized()
			if direction.length_squared()<.01: direction=Vector2.LEFT
			G.capsule(v,Vector2(enemy.pos),Vector2(enemy.pos)+direction*520,radius,Color(G.DANGER,.60+progress*.28))
			var scale:float=v.world_depth_scale(Vector2(enemy.pos))
			var projected:Vector2=(v.world_to_screen(Vector2(enemy.pos)+direction*100)-v.world_to_screen(Vector2(enemy.pos))).normalized()
			var normal:=projected.orthogonal()
			var hand:Vector2=v.world_to_screen(Vector2(enemy.pos))+projected*94*scale+Vector2(0,-76)*scale
			var size:float=lerpf(18,32,progress)*scale
			var fist:=PackedVector2Array([hand-projected*size*.65-normal*size*.62,hand+projected*size*.32-normal*size*.78,hand+projected*size*.68+normal*size*.23,hand-projected*size*.36+normal*size*.72])
			G.body(v,fist,Color(PETRICITE,.13+progress*.22))
			G.streak(v,fist[1],fist[2],4*scale,GOLD,.32+progress*.52)
		"galio_winds":
			G.area(v,target,radius,Color(G.DANGER,.50+progress*.32),.025,2)
			var source:Vector2=v.world_to_screen(Vector2(enemy.pos))
			var scale:float=v.world_depth_scale(Vector2(enemy.pos))
			for side in [-1.0,1.0]: _wind_lobe(v,source+Vector2(side*130,-104)*scale,scale*(.35+.30*progress),side,progress)
	return true

static func _entrance_actor(v,enemy:Dictionary,target:Vector2,progress:float) -> void:
	if not v.has_method("_draw_boss_clip"): return
	var elapsed:float=progress*float(enemy.special_warning_total)
	var remaining:=float(enemy.special_warning)
	var facing:=-1.0 if target.x<float(enemy.pos.x) else 1.0
	var foot:=Vector2(0,float(v.ENEMY_FOOT_OFFSET))
	if elapsed<float(v.enemy_sequences.duration("boss_galio","takeoff")):
		v._draw_boss_clip("boss_galio","takeoff",elapsed,v.world_to_screen(Vector2(enemy.get("galio_takeoff_pos",enemy.pos)))+foot,facing)
	elif remaining<=11.0/24.0:
		v._draw_boss_clip("boss_galio","landing",11.0/24.0-remaining,v.world_to_screen(target)+foot,facing)

static func _entrance_descent(v,p:Vector2,scale:float,pressure:float) -> void:
	# A short, heavy vertical wake sits behind the original falling sprite.
	var wake:=PackedVector2Array()
	for unit:Vector2 in [Vector2(7,-380),Vector2(31,-268),Vector2(27,-93),Vector2(4,-19),Vector2(-18,-68),Vector2(-15,-211)]:
		wake.append(p+unit*scale)
	G.body(v,wake,Color(SHADOW,pressure*.20),false)
	var core:=PackedVector2Array()
	for unit:Vector2 in [Vector2(4,-252),Vector2(15,-124),Vector2(13,-50),Vector2(0,-23),Vector2(-9,-69),Vector2(-7,-160)]:
		core.append(p+unit*scale)
	G.body(v,core,Color(PETRICITE,pressure*.34),false)
	G.glow(v,p+Vector2(0,-34)*scale,Vector2(68,95)*scale,IVORY,pressure*.22)

static func _wind_lobe(v,p:Vector2,scale:float,side:float,phase:float,opacity:float=1.0) -> void:
	var direction:=Vector2(side,-.25+sin(phase*2)*.12).normalized()
	_wind_blade(v,p,direction,scale*(.55+.12*phase),opacity*.75)

static func _wind_blade(v,p:Vector2,direction:Vector2,scale:float,opacity:float) -> void:
	var normal:=direction.orthogonal()
	# A broad, open-backed crescent carries the flight, rather than a tiny coil.
	var body:=PackedVector2Array()
	for unit:Vector2 in [Vector2(-96,-42),Vector2(-42,-65),Vector2(28,-62),Vector2(92,-21),Vector2(112,3),Vector2(79,25),Vector2(31,62),Vector2(-49,64),Vector2(-101,27),Vector2(-58,26),Vector2(2,37),Vector2(51,20),Vector2(65,-6),Vector2(25,-30),Vector2(-39,-36),Vector2(-83,-20)]:
		body.append(p+(direction*unit.x+normal*unit.y)*scale)
	G.body(v,_wind_curve(body),Color(GOLD,.28*opacity),false)
	var shoulder:=PackedVector2Array()
	for unit:Vector2 in [Vector2(-83,-39),Vector2(-34,-56),Vector2(31,-49),Vector2(91,-17),Vector2(112,3),Vector2(70,16),Vector2(26,49),Vector2(-53,52),Vector2(-94,27),Vector2(-50,25),Vector2(2,31),Vector2(54,12),Vector2(55,-12),Vector2(17,-32),Vector2(-43,-37)]:
		shoulder.append(p+(direction*unit.x+normal*unit.y)*scale)
	G.body(v,_wind_curve(shoulder),Color(IVORY,.75*opacity),false)
	var edge:=PackedVector2Array()
	for unit:Vector2 in [Vector2(-74,-43),Vector2(-25,-53),Vector2(41,-40),Vector2(93,-10),Vector2(112,3),Vector2(89,-1),Vector2(49,-20),Vector2(-16,-30),Vector2(-59,-28)]:
		edge.append(p+(direction*unit.x+normal*unit.y)*scale)
	G.body(v,_wind_curve(edge),Color("#fffdf1",.91*opacity),false)
	G.glow(v,p+direction*48*scale,Vector2(174,91)*scale,IVORY,.22*opacity)

static func _wind_curve(points:PackedVector2Array) -> PackedVector2Array:
	var result:=points
	for pass_index in 2:
		var rounded:=PackedVector2Array()
		for index in result.size():
			var a:Vector2=result[index]
			var b:Vector2=result[(index+1)%result.size()]
			rounded.append(a.lerp(b,.18))
			rounded.append(a.lerp(b,.82))
		result=rounded
	return result

static func _wind_ribbon(v,points:PackedVector2Array,width:float,opacity:float) -> void:
	if points.size()<2 or opacity<=.005: return
	var offsets:=PackedVector2Array()
	# Share each join between adjacent segments and bound it before a tight turn.
	for index in points.size():
		var incoming:Vector2=points[index]-points[maxi(0,index-1)]
		var outgoing:Vector2=points[mini(points.size()-1,index+1)]-points[index]
		if incoming.length_squared()<.25: incoming=outgoing
		if outgoing.length_squared()<.25: outgoing=incoming
		if incoming.length_squared()<.25 or outgoing.length_squared()<.25:
			offsets.append(Vector2.ZERO)
			continue
		var tangent:Vector2=incoming.normalized()+outgoing.normalized()
		if tangent.length_squared()<.001:
			offsets.append(Vector2.ZERO)
			continue
		var normal:=tangent.normalized().orthogonal()
		var t:float=float(index)/float(points.size()-1)
		var thickness:float=maxf(.7,width*pow(maxf(0,sin(t*PI)),.72))
		for segment:Vector2 in [incoming,outgoing]:
			var direction:=segment.normalized()
			if normal.dot(direction.orthogonal())<.1:
				thickness=0
			else:
				thickness=minf(thickness,segment.length()*.35/maxf(.001,absf(normal.dot(direction))))
		offsets.append(normal*thickness)
	for index in points.size()-1:
		var a:Vector2=points[index]
		var b:Vector2=points[index+1]
		if a.distance_squared_to(b)<.25: continue
		var offset_a:Vector2=offsets[index]
		var offset_b:Vector2=offsets[index+1]
		if offset_a.length_squared()<.0001 and offset_b.length_squared()<.0001: continue
		var t:float=(float(index)+.5)/float(points.size()-1)
		var alpha:float=opacity*(.42+.58*t)
		for tier in 2:
			var ratio:float=1.0 if tier==0 else .57
			var shape:=PackedVector2Array([a-offset_a*ratio,b-offset_b*ratio])
			if offset_b.length_squared()>=.0001: shape.append(b+offset_b*ratio)
			if offset_a.length_squared()>=.0001: shape.append(a+offset_a*ratio)
			G.body(v,shape,Color(GOLD,alpha*.28) if tier==0 else Color(IVORY,alpha),false)

static func _wind_path(start:Vector2,control:Vector2,finish:Vector2,t:float) -> Vector2:
	return start*(1-t)*(1-t)+control*2*(1-t)*t+finish*t*t

static func effect(v,event:Dictionary) -> bool:
	var kind:=str(event.get("kind",""))
	if kind not in ["galio_durand","galio_entrance","galio_punch","galio_winds","galio_winds_pulse","galio_guard"]: return false
	var age:float=G.age_of(event)
	if kind=="galio_entrance":
		_entrance_impact(v,event,age)
		return true
	if kind=="galio_punch":
		_punch_release(v,event,age)
		return true
	if kind=="galio_guard":
		_guard_arrival(v,event,age)
		return true
	if kind=="galio_winds" or kind=="galio_guard": return true
	if kind=="galio_winds_pulse":
		if int(event.get("hits",0))>0: G.shards(v,G.area_center(v,Vector2(event.pos)),28,age,IVORY)
		return true
	if age<0 or age>=.42: return true
	var source:=Vector2(event.get("source",event.pos))
	var targets:Array=event.get("hit_positions",[])
	# Each stone fragment follows the actual 105-unit pull from a recorded contact.
	for index in mini(6,targets.size()):
		var world:=Vector2(targets[index])
		var finish:Vector2=world.move_toward(source,105)
		var start:Vector2=G.area_center(v,world)
		var position:Vector2=G.area_center(v,world.lerp(finish,smoothstep(0,.23,age)))
		var direction:Vector2=(G.area_center(v,source)-start).normalized()
		if direction.length_squared()<.01: direction=Vector2.UP
		var normal:=direction.orthogonal()
		var scale:float=v.world_depth_scale(world)
		var fade:float=1-smoothstep(.16,.42,age)
		G.body(v,PackedVector2Array([position+direction*12*scale,position+normal*6*scale,position-direction*10*scale,position-normal*6*scale]),Color(PETRICITE,fade*.42),false)
		G.streak(v,position-direction*32*scale,position,9*scale,GOLD,fade*.76)
		if age<.08: G.glow(v,start,Vector2(49,26)*scale,IVORY,(1-age/.08)*.35)
	return true

static func _guard_arrival(v,event:Dictionary,age:float) -> void:
	if age<0 or age>=.27: return
	var world:=Vector2(event.pos)
	var profile:Dictionary={}
	for enemy:Dictionary in v.sim.enemies:
		if str(enemy.kind)=="boss_03" and float(enemy.hp)>0 and Vector2(enemy.pos).distance_to(world)<96:
			profile=_profile(v,enemy)
			break
	if profile.is_empty(): return
	var p:Vector2=profile.center
	var r:Vector2=profile.radii
	var scale:float=profile.scale
	var t:=smoothstep(0,.17,age)
	var fade:=1-smoothstep(.10,.27,age)
	for side in [-1.0,1.0]:
		var center:=p+Vector2(side*r.x*(.82-.28*t),r.y*.06)
		var length:=Vector2(9,22)*scale
		G.body(v,PackedVector2Array([center+Vector2(-length.x,-length.y*.6),center+Vector2(length.x*.3,-length.y),center+Vector2(length.x,length.y*.5),center+Vector2(-length.x*.5,length.y)]),Color(PETRICITE,fade*.22),false)
		G.streak(v,center+Vector2(side*14,-16)*scale,center+Vector2(0,12)*scale,4*scale,GOLD,fade*.70)

static func _entrance_impact(v,event:Dictionary,age:float) -> void:
	if age<0 or age>=.52: return
	var world:=Vector2(event.pos)
	var p:Vector2=G.area_center(v,world)
	var scale:float=v.world_depth_scale(world)
	# One hot foot contact, with the real landing animation above it.
	if age<.07:
		var contact:float=1-age/.07
		G.ellipse(v,p,Vector2(86,17)*scale,Color(IVORY,contact*.87))
		G.glow(v,p,Vector2(185,61)*scale,IVORY,contact*.56)
	var settle:float=1-smoothstep(.22,.52,age)
	# Wide fractured plates open under the weight; none forms a circular front.
	for index in 4:
		var side:float=-1 if index%2==0 else 1
		var center:=p+Vector2(side*(32+floorf(float(index)*.5)*38),-5+index%3*10)*scale
		var length:float=(32+index%3*8)*scale
		var plate:=PackedVector2Array([center+Vector2(-length,-7*scale),center+Vector2(length*.25,-12*scale),center+Vector2(length,2*scale),center+Vector2(length*.21,10*scale),center+Vector2(-length*.80,6*scale)])
		G.body(v,plate,Color(SHADOW,settle*.48),false)
		var lip:=plate[0].lerp(plate[1],.1)+Vector2(0,-3)*scale
		G.body(v,PackedVector2Array([lip,plate[1]+Vector2(0,-3)*scale,plate[1],plate[0].lerp(plate[1],.1)]),Color(DUST,settle*.48),false)
	# Broad, short gray dust rolls out below the knees instead of a glowing ring.
	for side in [-1.0,1.0]:
		for tier in (2 if bool(v.reduced_effects) else 3):
			var plume:=p+Vector2(side*(48+tier*35+age*(225+tier*35)),7+tier%2*10-age*10)*scale
			var size:=Vector2(58+tier*13+age*58,20+tier*4+age*24)*scale
			_stone_dust(v,plume+Vector2(0,4)*scale,size,Color(SHADOW,settle*(.36-tier*.035)))
			_stone_dust(v,plume+Vector2(-side*6,-5)*scale,size*Vector2(.86,.78),Color(DUST,settle*(.32-tier*.035)))
	# Individual slabs recoil upward once, then fall under gravity through the dust.
	for index in (4 if bool(v.reduced_effects) else 6):
		var angle:float=index*2.39996+.4
		var direction:=Vector2(cos(angle),sin(angle)*.40)
		var ground:=p+direction*(64+age*(125+index%3*30))*scale
		var lift:float=maxf(0,age*(275+index%3*31)-age*age*795)*scale
		var size:float=(17+index%3*5)*scale
		G.ellipse(v,ground,Vector2(size,5*scale),Color(SHADOW,settle*.30))
		var center:=ground+Vector2(0,-lift)
		var slab:=PackedVector2Array([center+Vector2(-size,-size*.40),center+Vector2(size*.56,-size*.64),center+Vector2(size,size*.12),center+Vector2(-size*.41,size*.52)])
		G.body(v,slab,Color(DUST,settle*.88))
		G.body(v,PackedVector2Array([slab[0],slab[1],center+Vector2(size*.33,0),center+Vector2(-size*.66,size*.08)]),Color(PETRICITE,settle*.44),false)

static func _stone_dust(v,p:Vector2,size:Vector2,color:Color) -> void:
	var points:=PackedVector2Array()
	for unit:Vector2 in [Vector2(-1,-.18),Vector2(-.74,-.70),Vector2(-.19,-1),Vector2(.44,-.74),Vector2(1,-.28),Vector2(.88,.26),Vector2(-.65,.36)]:
		points.append(p+unit*size)
	G.body(v,points,color,false)

static func _punch_release(v,event:Dictionary,age:float) -> void:
	if age<0 or age>=.36: return
	var source:=Vector2(event.get("source",event.pos))
	var finish:=Vector2(event.get("finish",event.pos))
	var a:Vector2=v.world_to_screen(source)
	var b:Vector2=v.world_to_screen(finish)
	var direction:Vector2=(b-a).normalized()
	if direction.length_squared()<.01: direction=Vector2.LEFT
	var normal:=direction.orthogonal()
	var scale:float=v.world_depth_scale(source)
	a+=Vector2(0,-38)*scale;b+=Vector2(0,-38)*scale
	var fade:float=1-smoothstep(.09,.36,age)
	var front:=a.lerp(b,lerpf(.18,1,smoothstep(0,.14,age)))
	var width:float=minf(56,float(event.get("radius",105))*.54)*scale
	width=maxf(8*scale,width)
	var reach:=minf(87*scale,maxf(24*scale,a.distance_to(b)*.38))
	# A short blunt head carries the force; it never becomes a full-length laser.
	var pressure:=PackedVector2Array([front-direction*reach-normal*width*.24,front-direction*reach*.27-normal*width*.69,front+direction*width*.30-normal*width*.47,front+direction*width*.42+normal*width*.15,front-direction*reach*.19+normal*width*.65,front-direction*reach+normal*width*.21])
	G.body(v,pressure,Color(DUST,fade*.30),false)
	var fist:=PackedVector2Array([front-direction*reach*.55-normal*width*.21,front-direction*reach*.12-normal*width*.46,front+direction*width*.27-normal*width*.28,front+direction*width*.31+normal*width*.20,front-direction*reach*.26+normal*width*.39])
	G.body(v,fist,Color(GOLD,fade*.61),false)
	var core:=PackedVector2Array([front-direction*reach*.32-normal*width*.12,front+direction*width*.14-normal*width*.27,front+direction*width*.20+normal*width*.15,front-direction*reach*.19+normal*width*.21])
	G.body(v,core,Color(IVORY,fade*.83),false)
	G.glow(v,front,Vector2(82,45)*scale,IVORY,fade*.24)
	# Detached stone wake follows this direction without drawing a continuous board.
	for index in (2 if bool(v.reduced_effects) else 3):
		var distance:float=(19+index*25)*scale
		var center:Vector2=front-direction*distance+normal*sin(float(index)*2.1)*12*scale
		var size:float=(8+index%2*3)*scale
		G.body(v,PackedVector2Array([center+direction*size,center+normal*size*.45,center-direction*size*.73,center-normal*size*.48]),Color(PETRICITE,fade*.38),false)
	if int(event.get("hits",0))<=0: return
	var contacts:Array=event.get("hit_positions",[])
	# Older events only have a locked target: show its contact if it is in the real capsule.
	if contacts.is_empty():
		var target:=Vector2(event.pos)
		if target.distance_to(Geometry2D.get_closest_point_to_segment(target,source,finish))<=float(event.get("radius",105)):
			contacts=[target]
	for index in mini(3,contacts.size()):
		var contact:Vector2=v.world_to_screen(Vector2(contacts[index]))+Vector2(0,-24)*scale
		if age<.08:
			var hot:float=1-age/.08
			G.body(v,PackedVector2Array([contact-direction*18*scale-normal*14*scale,contact+direction*15*scale-normal*21*scale,contact+direction*25*scale+normal*6*scale,contact-direction*12*scale+normal*17*scale]),Color(IVORY,hot*.90),false)
			G.glow(v,contact,Vector2(99,61)*scale,IVORY,hot*.48)
		G.shards(v,contact,45*scale,age,PETRICITE,index)

static func projectile(_v,_projectile:Dictionary) -> bool:
	return false

static func hazard(v,hazard:Dictionary) -> bool:
	if str(hazard.get("kind",""))!="galio_winds": return false
	var world:=Vector2(hazard.pos)
	var p:Vector2=G.area_center(v,world)
	var r:Vector2=G.area_radii(v,world,float(hazard.radius))
	var scale:float=v.world_depth_scale(world)
	var delay:=float(hazard.get("delay",0))
	G.area(v,world,float(hazard.radius),Color(G.DANGER,.53),.02,2)
	if delay>0:
		var source:Vector2=v.world_to_screen(Vector2(hazard.get("source",world)))+Vector2(0,-84)*scale
		var raw_t:=1-clampf(delay/maxf(.01,float(hazard.get("travel_total",.72))),0,1)
		var t:=pow(raw_t,.9)
		for side in [-1.0,1.0]:
			var start:Vector2=source+Vector2(side*108,-14)*scale
			var control:Vector2=source.lerp(p,.45)+Vector2(side*205,-104)*scale
			var point:=_wind_path(start,control,p,t)
			var direction:Vector2=((control-start)*2*(1-t)+(p-control)*2*t).normalized()
			if direction.length_squared()<.01: direction=Vector2.LEFT
			var tail:=PackedVector2Array()
			for index in 11:
				var past_t:=maxf(0,t-.44+.44*float(index)/10)
				tail.append(_wind_path(start,control,p,past_t))
			_wind_ribbon(v,tail,19*scale,.45)
			_wind_blade(v,point,direction,scale*lerpf(.76,.96,t),.91)
	else:
		var total:=float(hazard.get("total",5.2))
		var remaining:=maxf(0,float(hazard.get("life",total)))
		var elapsed:=maxf(0,total-remaining)
		var appear:=smoothstep(0,.20,elapsed)
		var fade:=smoothstep(0,.44,remaining)
		var opacity:=(.56+.44*appear)*fade
		var width:=minf(r.x*.86,126*scale)
		G.ellipse(v,p,Vector2(width*.86,width*.27),Color(SHADOW,.17*opacity))
		# Both incoming blades open across the ground, then feed a continuous spiral.
		if elapsed<.22:
			var opening:=smoothstep(0,.22,elapsed)
			for side in [-1.0,1.0]:
				var point:=p+Vector2(side*width*.32*opening,-8*scale)
				_wind_blade(v,point,Vector2(side,-.28).normalized(),scale*(.68+.28*opening),(1-opening)*.63)
		for layer in (2 if bool(v.reduced_effects) else 3):
			var points:=PackedVector2Array()
			for index in 21:
				var t:=float(index)/20
				var angle:float=-elapsed*5.6+float(layer)*TAU/3+t*TAU*.79
				var radius:float=width*(.96-.69*t)
				points.append(p+Vector2(cos(angle)*radius,sin(angle)*radius*.40)-Vector2(0,sin(t*PI)*9*scale))
			_wind_ribbon(v,points,(12-layer*2)*scale,opacity*(.63-layer*.10))
		# Loose rising strips emerge from the center: no rigid cone or stacked hoops.
		for side in [-1.0,1.0]:
			var rising:=PackedVector2Array()
			for index in 17:
				var t:=float(index)/16
				var angle:float=-elapsed*4.8+(PI if side<0 else 0)+t*TAU*.64
				var reach:float=(18+38*t)*scale
				rising.append(p+Vector2(cos(angle)*reach,sin(angle)*reach*.26-(10+71*t)*scale))
			_wind_ribbon(v,rising,9*scale,opacity*.53)
		G.glow(v,p+Vector2(0,-15)*scale,Vector2(width*1.55,54*scale),IVORY,opacity*.17)
	return true

static func overlay(v) -> void:
	for enemy:Dictionary in v.sim.enemies:
		if float(enemy.hp)<=0: continue
		var id:=str(enemy.kind)
		if id not in ["boss_galio","boss_03"]: continue
		var charging:=id=="boss_galio" and bool(enemy.get("special_pending",false)) and str(enemy.get("special_move",""))=="galio_durand"
		var shield:=float(enemy.get("shield",0))
		var ally_guard:=id=="boss_03" and bool(enemy.get("galio_summoned",false))
		if shield<=0 and not charging: continue
		if id=="boss_03" and not ally_guard: continue
		if v.has_method("_render_point_visible") and not v._render_point_visible(Vector2(enemy.pos),400): continue
		var power:float=G.progress_of(enemy) if charging else .58+.34*clampf(shield/maxf(1,float(enemy.get("max_shield",shield))),0,1)
		var shown:Dictionary=enemy
		if id=="boss_galio" and bool(enemy.get("special_pending",false)) and str(enemy.get("special_move",""))=="galio_entrance":
			var remaining:=float(enemy.special_warning)
			var elapsed:=float(enemy.special_warning_total)-remaining
			var takeoff:float=v.enemy_sequences.duration("boss_galio","takeoff")
			if elapsed>=takeoff and remaining>11.0/24.0: continue
			shown=enemy.duplicate()
			var target:Vector2=enemy.get("galio_landing_pos",enemy.get("galio_target",enemy.pos))
			shown._armor_facing=-1.0 if target.x<float(enemy.pos.x) else 1.0
			if elapsed<takeoff:
				shown.pos=enemy.get("galio_takeoff_pos",enemy.pos)
				shown._armor_clip="takeoff"
				shown._armor_frame=v.enemy_sequences.frame_at_time("boss_galio","takeoff",elapsed)
			else:
				shown.pos=target
				shown._armor_clip="landing"
				shown._armor_frame=v.enemy_sequences.frame_at_time("boss_galio","landing",11.0/24.0-remaining)
		_shield_shell(v,shown,power,charging)
