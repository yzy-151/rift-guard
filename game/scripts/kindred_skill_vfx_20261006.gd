extends RefCounted
## Lamb's white arrows, original Wolf head, black spirit body and cyan sanctuary.
const G=preload("res://scripts/boss_vfx_geometry_20261006.gd")
const TEAL:=Color("#76eadc")
const WHITE:=Color("#e7fff3")
const INK:=Color("#111820")
const WOLF_REGION:=Rect2(154,105,92,61)

static func _wolf(v,p:Vector2,direction:Vector2,size:float,alpha:float,motion:float) -> void:
	if alpha<=.005: return
	if direction.length_squared()<.01: direction=Vector2.RIGHT
	direction=direction.normalized()
	var normal:=direction.orthogonal()
	var spine:=PackedVector2Array()
	var body:=PackedVector2Array()
	for index in 13:
		var t:=float(index)/12
		var center:=p-direction*t*142*size+normal*sin(t*4.7+motion*4)*13*t*size
		spine.append(center)
		body.append(center+normal*(22*(1-t)+1.2)*size)
	for index in range(12,-1,-1):
		var t:=float(index)/12
		body.append(spine[index]-normal*(22*(1-t)+1.2)*size)
	G.body(v,body,Color(INK,alpha*.87),false)
	for index in range(1,12,3):
		G.ellipse(v,spine[index]-normal*sin(motion*3+index)*7*size,Vector2(26,17)*size,Color(INK,alpha*.18))
		G.streak(v,spine[index+1],spine[index],3*size,TEAL,alpha*.45)
	# Exact original sprite crop; no generated head or duplicate Lamb body.
	var texture=v.enemy_sequences.texture("boss_03","spirit")
	if texture!=null:
		var source:Rect2=v.enemy_sequences.source_rect("boss_03","spirit",0)
		source=Rect2(source.position+WOLF_REGION.position,WOLF_REGION.size)
		var facing:=-1.0 if direction.x<0 else 1.0
		v.draw_set_transform(p,clampf(direction.y*.16,-.16,.16),Vector2(facing,1))
		v.draw_texture_rect_region(texture,Rect2(Vector2(-46,-37)*size,Vector2(92,61)*size),source,Color(1,1,1,alpha))
		v.draw_set_transform(Vector2.ZERO)

static func _sanctuary(v,world:Vector2,radius:float,timer:float) -> void:
	G.area(v,world,radius,Color(WHITE,.82),.035,2.6)
	var points:PackedVector2Array=G.area_points(v,world,radius)
	var center:Vector2=G.area_center(v,world)
	var breath:float=.50+.12*sin(float(v.clock)*2)
	for index in range(0,points.size(),8):
		var p:Vector2=points[index]
		var inward:Vector2=(center-p).normalized()
		var rise:float=fposmod(float(v.clock)*.46+float(index)*.037,1.0)
		var particle:=p+inward*12-Vector2(0,8+rise*24)
		G.streak(v,particle+Vector2(0,6),particle,2.8,WHITE,breath*(1-rise))
		G.glow(v,particle,Vector2(30,34),TEAL,(1-rise)*.15)
	if timer<.65: G.glow(v,center,Vector2(115,46),TEAL,(.65-timer)*.38)

static func _mark(v,world:Vector2,stage:int,alpha:float) -> void:
	var p:Vector2=v.world_to_screen(world)+Vector2(0,-87)*v.world_depth_scale(world)
	for index in 3:
		var center:=p+Vector2((index-1)*14,absi(index-1)*4)
		var rune:=PackedVector2Array([center+Vector2(0,-9),center+Vector2(5,-1),center+Vector2(0,7),center+Vector2(-5,-1)])
		G.body(v,rune,Color(INK,alpha*.86))
		var active:=index<stage
		G.body(v,PackedVector2Array([center+Vector2(0,-7),center+Vector2(3,-1),center+Vector2(0,4),center+Vector2(-3,-1)]),Color(WHITE if active else TEAL,alpha*(1.0 if active else .31)),false)

static func warning(v,enemy:Dictionary) -> bool:
	var move:=str(enemy.get("special_move",""))
	if not bool(enemy.get("special_pending",false)) or move not in ["kindred_dance","kindred_wolf","kindred_dread","kindred_lasers","kindred_hunt"]: return false
	var points:Array=enemy.get("special_warning_positions",[])
	var progress:float=G.progress_of(enemy)
	var source:=Vector2(enemy.pos)
	match move:
		"kindred_wolf":
			if not points.is_empty():
				var world:=Vector2(points[0])
				G.area(v,world,float(enemy.special_warning_radius),Color(G.DANGER,.57+progress*.29),.035,2.5)
				var p:Vector2=G.area_center(v,world)
				G.ellipse(v,p,Vector2(29,11)*(1+progress*.7),Color(INK,.14+progress*.24))
				G.glow(v,p,Vector2(85,35),TEAL,progress*.17)
		"kindred_dread":
			if not points.is_empty(): _mark(v,Vector2(points[0]),0,.50+progress*.45)
		"kindred_lasers":
			var origin:=Vector2(enemy.get("kindred_laser_source",source))
			for target:Vector2 in points: G.capsule(v,origin,target,14,Color(G.DANGER,.48+progress*.36),.025,2.5)
		"kindred_dance":
			for target:Vector2 in points:
				var p:Vector2=v.world_to_screen(target)
				G.body(v,PackedVector2Array([p+Vector2(-9,-5),p+Vector2(0,-13),p+Vector2(9,-5),p+Vector2(0,-2)]),Color(WHITE,.44+progress*.44),false)
		"kindred_hunt":
			for target:Vector2 in points:
				var p:Vector2=v.world_to_screen(target)
				for side in [-1.0,1.0]: G.streak(v,p+Vector2(side*15,-25),p+Vector2(side*6,-7),4,TEAL,.44+progress*.4)
	return true

static func effect(v,event:Dictionary) -> bool:
	var kind:=str(event.get("kind",""))
	if kind not in ["kindred_dance","kindred_wolf","kindred_wolf_strike","kindred_dread","kindred_hunt","kindred_lasers","kindred_arrow_hit","kindred_respite","kindred_respite_end","kindred_protect"]: return false
	var age:float=G.age_of(event)
	var world:=Vector2(event.pos)
	match kind:
		"kindred_wolf":
			if age>=0 and age<.23:
				var source:Vector2=v.world_to_screen(Vector2(event.get("source",world)))
				var center:Vector2=G.area_center(v,world)
				_wolf(v,center+Vector2(0,-22),(center-source).normalized(),.96,1-smoothstep(.12,.23,age),float(v.clock))
		"kindred_wolf_strike":
			_wolf_strike(v,event,age)
		"kindred_dance":
			if age>=0 and age<.22:
				var source:Vector2=v.world_to_screen(Vector2(event.get("source",world)))
				var finish:Vector2=v.world_to_screen(world)
				G.ellipse(v,source+Vector2(0,9),Vector2(29,11),Color(INK,(1-age/.22)*.25))
				G.streak(v,source+Vector2(0,-24),finish+Vector2(0,-24),10,WHITE,1-age/.22)
		"kindred_lasers":
			if age>=0 and age<.24:
				var source:=Vector2(event.get("source",world))
				var a:Vector2=v.world_to_screen(source)
				for target:Vector2 in event.get("points",[]):
					var metric:=Vector2(1,2.5)
					var perpendicular:=((target-source)*metric).normalized().orthogonal()*14/metric
					var width:float=maxf(1.6,v.world_to_screen(source+perpendicular).distance_to(a)*.5)
					G.streak(v,a,v.world_to_screen(target),width,TEAL,1-smoothstep(.035,.24,age))
		"kindred_dread":
			if age>=0 and age<.6: _mark(v,Vector2(event.get("target",world)),mini(2,1+floori(age/.28)),.88)
		"kindred_hunt":
			if age>=0 and age<.20:
				var p:Vector2=v.world_to_screen(world)+Vector2(0,-38)
				for index in 3:
					var direction:=Vector2.from_angle(PI+(index-1)*.3)
					G.streak(v,p-direction*16,p+direction*31,4,WHITE,1-age/.20)
		"kindred_arrow_hit":
			if int(event.get("stack",0))==3:
				if age>=0 and age<.23:
					var p:Vector2=v.world_to_screen(world)+Vector2(0,-34)
					var source:Vector2=v.world_to_screen(Vector2(event.get("source",world+Vector2.LEFT)))
					_wolf(v,p,(p-source).normalized(),.84,1-age/.23,float(v.clock))
			G.shards(v,v.world_to_screen(world)+Vector2(0,-20),23,age,WHITE,int(event.get("stack",0)))
		"kindred_respite":
			# The field follows the actual Sim timer, including gameplay pauses.
			if age>=0 and age<.15:
				G.glow(v,G.area_center(v,world),Vector2(160,58),WHITE,(1-age/.15)*.48)
		"kindred_respite_end":
			_respite_heal(v,event,age)
		"kindred_protect":
			if age>=0 and age<.28:
				var p:Vector2=v.world_to_screen(world)+Vector2(0,-33)
				G.band(v,p,Vector2(28,47),1.12,.96,Color(WHITE,1-age/.28))
	return true

static func _wolf_strike(v,event:Dictionary,age:float) -> void:
	var targets:Array=event.get("hit_positions",[])
	if targets.is_empty() or age<0 or age>=.34: return
	var world:=Vector2(event.pos)
	var center:Vector2=G.area_center(v,world)
	var r:Vector2=G.area_radii(v,world,float(event.get("radius",275)))
	var angle:float=(float(v.clock)-age)*1.45
	var start:=center+Vector2(cos(angle)*r.x*.57,sin(angle)*r.y*.50)-Vector2(0,22)
	var target:Vector2=v.world_to_screen(Vector2(targets[0]))+Vector2(0,-25)
	var t:float=clampf(age/.12,0,1)
	_wolf(v,start.lerp(target,smoothstep(0,1,t)),(target-start).normalized(),1.03,1-smoothstep(.14,.34,age),float(v.clock))
	for index in mini(3,targets.size()):
		var p:Vector2=v.world_to_screen(Vector2(targets[index]))+Vector2(0,-19)
		G.shards(v,p,25,age,TEAL,index)

static func _respite_heal(v,event:Dictionary,age:float) -> void:
	if age<0 or age>=.62: return
	var world:=Vector2(event.pos)
	var points:PackedVector2Array=G.area_points(v,world,float(event.get("radius",285)))
	var center:Vector2=G.area_center(v,world)
	var fade:float=1-smoothstep(.18,.62,age)
	for index in range(0,points.size(),4):
		var direction:Vector2=(points[index]-center).normalized()
		var p:Vector2=center.lerp(points[index],.42+age*.88)+Vector2(0,-age*35)
		var side:=direction.orthogonal()*8*fade
		G.body(v,PackedVector2Array([p+direction*16*fade,p+side,p-direction*6*fade,p-side]),Color(WHITE,fade*.86),false)
	G.glow(v,center,Vector2(175,65),TEAL,fade*.26)

static func projectile(v,projectile:Dictionary) -> bool:
	var kind:=str(projectile.get("kind",""))
	if kind not in ["kindred_arrow","kindred_dread_arrow"]: return false
	if float(projectile.get("delay",0))>0: return true
	var p:Vector2=v.world_to_screen(Vector2(projectile.pos))+Vector2(0,-19)
	var target_id:=int(projectile.get("target_id",-1))
	var direction:=Vector2.LEFT
	if target_id>=0 and target_id<v.sim.heroes.size(): direction=v.world_to_screen(Vector2(v.sim.heroes[target_id].pos))+Vector2(0,-19)-p
	if direction.length_squared()<.01: direction=Vector2.LEFT
	direction=direction.normalized()
	var scale:float=v.world_depth_scale(Vector2(projectile.pos))
	if kind=="kindred_dread_arrow" and int(projectile.get("dread_stack",0))==3:
		_wolf(v,p,direction,.79*scale,.98,float(v.clock))
	else:
		G.streak(v,p-direction*40*scale,p,3.4*scale,TEAL,.95)
		G.glow(v,p,Vector2(38,30)*scale,WHITE,.23)
		var normal:=direction.orthogonal()*4.2*scale
		G.body(v,PackedVector2Array([p+direction*8*scale,p-direction*7*scale+normal,p-direction*3*scale,p-direction*7*scale-normal]),WHITE,false)
	return true

static func hazard(v,hazard:Dictionary) -> bool:
	if str(hazard.get("kind",""))!="kindred_wolf_zone": return false
	var world:=Vector2(hazard.pos)
	G.area(v,world,float(hazard.radius),Color(G.DANGER,.58),.025,2)
	# Avoid painting a second idle Wolf while the genuine strike/entry is shown.
	if v.has_method("_accept_boss_sequence_event"):
		for event:Dictionary in v.effects:
			if str(event.kind) not in ["kindred_wolf","kindred_wolf_strike"] or Vector2(event.pos).distance_squared_to(world)>1: continue
			var age:float=G.age_of(event)
			if (str(event.kind)=="kindred_wolf" and age<.23) or (str(event.kind)=="kindred_wolf_strike" and age<.34 and not event.get("hit_positions",[]).is_empty()): return true
	var center:Vector2=G.area_center(v,world)
	var r:Vector2=G.area_radii(v,world,float(hazard.radius))
	var angle:float=float(v.clock)*1.45
	var p:=center+Vector2(cos(angle)*r.x*.57,sin(angle)*r.y*.50)-Vector2(0,22)
	var direction:=Vector2(-sin(angle)*r.x,cos(angle)*r.y*.65).normalized()
	_wolf(v,p,direction,.98*v.world_depth_scale(world),.90,float(v.clock))
	return true

static func overlay(v) -> void:
	for enemy:Dictionary in v.sim.enemies:
		if str(enemy.kind)!="boss_03" or not bool(enemy.get("kindred_respite_active",false)): continue
		var center:=Vector2(enemy.get("kindred_respite_center",enemy.pos))
		var radius:=float(enemy.get("kindred_respite_radius",285))
		for hero:Dictionary in v.sim.heroes:
			if not bool(hero.get("deployed",false)) or float(hero.hp)<=0 or not v.sim.is_in_ability_area(center,Vector2(hero.pos),radius): continue
			var scale:float=v.world_depth_scale(Vector2(hero.pos))
			var p:Vector2=v.world_to_screen(Vector2(hero.pos))+Vector2(0,-38)*scale
			G.band(v,p,Vector2(29,51)*scale,1.07,.99,Color(TEAL,.46))
			G.band(v,p,Vector2(29,51)*scale,1.022,.998,Color(WHITE,.60))

static func persistent_ground(v) -> void:
	for enemy:Dictionary in v.sim.enemies:
		if str(enemy.kind)!="boss_03" or not bool(enemy.get("kindred_respite_active",false)): continue
		_sanctuary(v,Vector2(enemy.get("kindred_respite_center",enemy.pos)),float(enemy.get("kindred_respite_radius",285)),float(enemy.get("kindred_respite_timer",0)))
