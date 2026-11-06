extends RefCounted
## Directional light bodies. Simulation owns all geometry and damage.
const Sim = preload("res://scripts/combat_simulation.gd")
const WARNING_RED := Color("#ff6775")
const MOVES := ["rift_laser","rift_orbs","rift_overhead","rift_storm","slime_bounce","slime_burst","slime_reflux","slime_court","kindred_dance","kindred_wolf","kindred_dread","kindred_hunt","kindred_lasers","galio_entrance","galio_punch","galio_winds","galio_durand"]
const EFFECTS := ["rift_laser","rift_orbs","rift_overhead","rift_storm","rift_orb_hit","slime_bounce","slime_burst","slime_reflux","slime_court","slime_bounce_hit","slime_glob_hit","slime_court_hit","slime_court_final","kindred_dance","kindred_wolf","kindred_dread","kindred_hunt","kindred_lasers","kindred_arrow_hit","kindred_wolf_strike","kindred_respite","kindred_respite_end","galio_entrance","galio_punch","galio_winds","galio_winds_pulse","galio_durand","galio_guard","crossfire","barrage"]
const HIT_EVENTS := ["rift_orb_hit","slime_bounce_hit","slime_glob_hit","slime_court_hit","slime_court_final","kindred_arrow_hit","kindred_wolf_strike","galio_winds_pulse"]
static var rendering_enabled := true
static var light_texture: Texture2D

static func prewarm() -> void:
	# One mathematical falloff created before skills; no external atlas or shader.
	if light_texture != null: return
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var distance := Vector2(x-31.5,y-31.5).length()/31.5
			image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-distance),2.8)))
	light_texture=ImageTexture.create_from_image(image)

static func handles_effect(kind: String) -> bool:
	return kind in EFFECTS

static func _lean(v) -> bool:
	return bool(v.reduced_effects) or v.sim.enemies.size()>100

static func _color(kind: String, phase: int = 1) -> Color:
	if kind.begins_with("galio_"): return Color("#ffd898")
	if kind.begins_with("slime_"): return Color("#9be9df") if phase<2 else Color("#c7aeed")
	if kind.begins_with("kindred_"): return Color("#b8bdff")
	if kind=="barrage": return Color("#ffb5a5")
	if kind=="crossfire": return Color("#ffe1b0")
	return Color("#c5b4ef") if phase<3 else Color("#ffacb8")

static func _ellipse(point: Vector2, radii: Vector2, steps: int = 32) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in steps:
		var angle := TAU*float(i)/float(steps)
		result.append(point+Vector2(cos(angle),sin(angle))*radii)
	return result

static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result:=points.duplicate()
	if not result.is_empty(): result.append(result[0])
	return result

static func _zone(v, world: Vector2, radius: float, color: Color, alpha: float, boundary: bool = true, barrage: bool = false) -> void:
	var radii: Vector2=v.sim.support_barrage_screen_radii(world,radius) if barrage else v.sim.ability_area_screen_radii(world,radius)
	if radii.x<.5 or radii.y<.5: return
	var points:=_ellipse(v.world_to_screen(world),radii)
	v.draw_colored_polygon(points,Color(color,clampf(alpha*.055,0,.055)))
	if boundary: v.draw_polyline(_closed(points),Color(color,clampf(alpha,0,1)),2,true)

static func _capsule(v, source: Vector2, target: Vector2, radius: float, color: Color, alpha: float, metric_y: float = 1.0) -> void:
	var metric:=Vector2(1,metric_y)
	var a:=source*metric
	var b:=target*metric
	var direction:=(b-a).normalized()
	if direction.length_squared()<.01 or radius<.5: return
	var start_angle:=direction.angle()-PI*.5
	var points:=PackedVector2Array()
	for index in 13:
		points.append(v.world_to_screen((b+Vector2.from_angle(start_angle+PI*float(index)/12)*radius)/metric))
	for index in 13:
		points.append(v.world_to_screen((a+Vector2.from_angle(start_angle+PI+PI*float(index)/12)*radius)/metric))
	v.draw_colored_polygon(points,Color(color,alpha*.055))
	v.draw_polyline(_closed(points),Color(color,alpha),2,true)

static func _glow(v, point: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	if light_texture==null or alpha<=.005: return
	if v.has_method("emit_glow"): v.emit_glow(light_texture,point,size,color,minf(.30,alpha))
	else: v.draw_texture_rect(light_texture,Rect2(point-size*.5,size),false,Color(color,minf(.18,alpha)))

static func _path(v, points: PackedVector2Array, width: float, color: Color, alpha: float) -> void:
	# Convex half-strips: bright spine, colored fading edge, no concave ring fill.
	if points.size()<2 or width<.7 or alpha<=.005: return
	var count:=points.size()
	for index in count-1:
		var a:=points[index]
		var b:=points[index+1]
		if a.distance_squared_to(b)<.04: continue
		var normal:=(b-a).normalized().orthogonal()
		var u:=float(index)/float(count-1)
		var next_u:=float(index+1)/float(count-1)
		var side_a:=maxf(.22,width*pow(maxf(0,sin(PI*u)),.65))
		var side_b:=maxf(.22,width*pow(maxf(0,sin(PI*next_u)),.65))
		for sign_value in [-1.0,1.0]:
			var quad:=PackedVector2Array([a,b,b+normal*side_b*sign_value,a+normal*side_a*sign_value])
			var colors:=PackedColorArray([Color(1,.99,.96,alpha),Color(1,.99,.96,alpha),Color(color,alpha*.08),Color(color,alpha*.08)])
			v.draw_polygon(quad,colors)

static func _ribbon(v, source: Vector2, target: Vector2, width: float, color: Color, alpha: float, bend: float = 0.0) -> void:
	if source.distance_squared_to(target)<1: return
	var normal:=(target-source).normalized().orthogonal()
	var points:=PackedVector2Array()
	for index in 11:
		var t:=float(index)/10
		points.append(source.lerp(target,t)+normal*sin(t*PI)*bend)
	_path(v,points,width,color,alpha)

static func _arc(v, center: Vector2, radii: Vector2, angle: float, sweep: float, width: float, color: Color, alpha: float) -> void:
	if minf(radii.x,radii.y)<2: return
	var points:=PackedVector2Array()
	for index in 13:
		var theta:=angle+sweep*float(index)/12
		points.append(center+Vector2(cos(theta),sin(theta))*radii)
	_path(v,points,minf(width,minf(radii.x,radii.y)*.30),color,alpha)

static func _charge(v, enemy: Dictionary, progress: float) -> void:
	var world:=Vector2(enemy.pos)
	var points: Array=enemy.get("special_warning_positions",[])
	var target:=Vector2(points[0]) if not points.is_empty() else world+Vector2.LEFT
	var direction: Vector2=(v.world_to_screen(target)-v.world_to_screen(world)).normalized()
	if direction.length_squared()<.01: direction=Vector2.LEFT
	var scale: float=v.world_depth_scale(world)
	# Beside the body, instead of hidden at the foot of a large boss sprite.
	var body_width:=285.0
	if v.has_method("_draw_boss_clip"): body_width=float(v.enemy_sequences.display_size(str(enemy.kind)))
	var side:=-1.0 if direction.x<=0 else 1.0
	var anchor: Vector2=v.world_to_screen(world)+Vector2(side*maxf(116,body_width*.52+22),-64)*scale
	var color:=_color(str(enemy.special_move),int(enemy.get("boss_phase",1)))
	var extent:=lerpf(52,18,smoothstep(0,.96,progress))*scale
	var alpha:=.24+.72*progress
	var angle:=float(v.clock)*2.6
	for index in (2 if _lean(v) else 3):
		_arc(v,anchor,Vector2(extent,extent*.62),angle+float(index)*TAU/3,1.9,lerpf(3,9,progress)*scale,color,alpha)
	_glow(v,anchor,Vector2.ONE*64*scale,color,progress*.19)
	if progress>.78:
		_ribbon(v,anchor-direction*16*scale,anchor+direction*18*scale,5*scale,color,(progress-.78)/.22)

static func _entrance_actor(v, enemy: Dictionary, points: Array, progress: float) -> void:
	# This is the actual character animation formerly embedded in the old warning.
	# BattleView intentionally excludes this actor while the entrance is pending.
	if points.is_empty() or not v.has_method("_draw_boss_clip"): return
	var elapsed:=progress*float(enemy.special_warning_total)
	var remaining:=float(enemy.special_warning)
	var target:=Vector2(points[0])
	var facing:=-1.0 if target.x<float(enemy.pos.x) else 1.0
	var foot:=Vector2(0,float(v.ENEMY_FOOT_OFFSET))
	if elapsed<float(v.enemy_sequences.duration("boss_galio","takeoff")):
		v._draw_boss_clip("boss_galio","takeoff",elapsed,v.world_to_screen(Vector2(enemy.get("galio_takeoff_pos",enemy.pos)))+foot,facing)
	elif remaining<=11.0/24.0:
		v._draw_boss_clip("boss_galio","landing",11.0/24.0-remaining,v.world_to_screen(target)+foot,facing)

static func draw_warning(v, enemy: Dictionary) -> bool:
	if not rendering_enabled: return false
	var move:=str(enemy.get("special_move",""))
	if move not in MOVES or not bool(enemy.get("special_pending",false)): return false
	var total:=maxf(.01,float(enemy.get("special_warning_total",1)))
	var progress:=1-clampf(float(enemy.get("special_warning",0))/total,0,1)
	var radius:=float(enemy.get("special_warning_radius",100))
	var points: Array=enemy.get("special_warning_positions",[])
	var source:=Vector2(enemy.pos)
	if move=="galio_entrance": _entrance_actor(v,enemy,points,progress)
	_charge(v,enemy,progress)
	if move in ["rift_laser","kindred_lasers"]:
		for target: Vector2 in points:
			_capsule(v,Vector2(enemy.get("kindred_laser_source",source)),target,radius,WARNING_RED,.50+progress*.36,2.5 if move=="kindred_lasers" else 1.0)
	elif move=="galio_punch":
		var target:=Vector2(points[0]) if not points.is_empty() else source+Vector2.LEFT
		var direction:=(target-source).normalized()
		if direction.length_squared()<.01: direction=Vector2.LEFT
		_capsule(v,source,source+direction*520,radius,WARNING_RED,.50+progress*.36)
	elif move in ["kindred_dance","kindred_dread","kindred_hunt","rift_orbs"]:
		for target: Vector2 in points:
			_arc(v,v.world_to_screen(target),Vector2(13,8)*v.world_depth_scale(target),float(v.clock)*2,4.8,3,_color(move),.35+progress*.4)
	else:
		for target: Vector2 in points:
			var center:=source if move in ["galio_durand","slime_reflux"] else target
			_zone(v,center,radius,WARNING_RED,.50+progress*.36)
	return true

static func _wave(v, world: Vector2, radius: float, age: float, color: Color, inward: bool = false, barrage: bool = false) -> void:
	if age<0 or age>=.40: return
	var t:=age/.40
	var extent:=lerpf(.99,.12,t) if inward else lerpf(.15,.99,smoothstep(0,.84,t))
	var radii: Vector2=(v.sim.support_barrage_screen_radii(world,radius) if barrage else v.sim.ability_area_screen_radii(world,radius))*extent
	var alpha: float=(1-smoothstep(.22,1,t))*.94
	var center: Vector2=v.world_to_screen(world)
	var scale: float=v.world_depth_scale(world)
	for index in (2 if _lean(v) else 3):
		_arc(v,center,radii,float(index)*TAU/3+t*.95,1.55,(9 if inward else 13)*scale,color,alpha)

static func _hit(v, world: Vector2, radius: float, age: float, color: Color, seed: int = 0) -> void:
	if age<0 or age>=.34: return
	var t:=age/.34
	var fade:=1-smoothstep(.10,1,t)
	if fade<.025: return
	var center: Vector2=v.world_to_screen(world)
	var scale: float=v.world_depth_scale(world)
	var extent:=clampf(radius*.28,20,58)*scale
	_glow(v,center,Vector2.ONE*extent*2.8,color,(1-smoothstep(0,.45,t))*.28)
	for index in (3 if _lean(v) else 6):
		var angle:=float(index)*TAU/6+float(seed%17)*.27
		var direction:=Vector2.from_angle(angle)
		var head:=center+direction*extent*(.20+t*.95)
		var length:=(10+float(index%3)*4)*scale*fade
		_ribbon(v,head-direction*length,head,(3.2+float(index%2))*scale*fade,color,fade,2*scale)

static func _event_hits(v, effect: Dictionary, age: float, color: Color) -> void:
	var positions: Array=effect.get("hit_positions",[])
	if not positions.is_empty():
		for index in mini(6,positions.size()): _hit(v,Vector2(positions[index]),70,age,color,index)
	elif int(effect.get("hits",0))>0 or (str(effect.kind) in HIT_EVENTS and not effect.has("hits")):
		_hit(v,Vector2(effect.pos),float(effect.get("radius",75)),age,color,int(effect.get("phase",1)))

static func _beam(v, source: Vector2, target: Vector2, radius: float, age: float, color: Color, metric_y: float = 1.0) -> void:
	if age<0 or age>=.34: return
	var a: Vector2=v.world_to_screen(source)
	var b: Vector2=v.world_to_screen(target)
	if a.distance_squared_to(b)<1: return
	var scale: float=v.world_depth_scale(source)
	var alpha:=1-smoothstep(.06,.34,age)
	var width:=clampf(radius*.23,3.5,15)*scale/metric_y
	_ribbon(v,a,b,width,color,alpha,sin(age*31)*minf(6,radius*.08)*scale/metric_y)
	var head:=a.lerp(b,clampf(age/.11,0,1))
	var direction:=(b-a).normalized()
	_ribbon(v,head-direction*42*scale,head+direction*13*scale,width*1.5,color,alpha)

static func _launch(v, world: Vector2, target: Vector2, age: float, color: Color) -> void:
	if age<0 or age>=.25: return
	var source: Vector2=v.world_to_screen(world)
	var direction: Vector2=(v.world_to_screen(target)-source).normalized()
	if direction.length_squared()<.01: direction=Vector2.LEFT
	var scale: float=v.world_depth_scale(world)
	var head:=source+direction*(42+age*200)*scale+Vector2(0,-26)*scale
	_ribbon(v,head-direction*70*scale,head,10*scale,color,1-age/.25,18*scale)

static func draw_effect(v, effect: Dictionary) -> bool:
	if not rendering_enabled: return false
	var kind:=str(effect.get("kind",""))
	if not handles_effect(kind): return false
	var total:=maxf(.01,float(effect.get("total",1)))
	var age:=total-float(effect.get("life",total))
	var world:=Vector2(effect.get("pos",Vector2.ZERO))
	var source:=Vector2(effect.get("source",world))
	var radius:=float(effect.get("radius",100))
	var color:=_color(kind,int(effect.get("phase",1)))
	if kind=="crossfire": _crossfire(v,effect,age)
	elif kind=="barrage":
		if age>=0 and age<.18:
			var point: Vector2=v.world_to_screen(world)
			var scale: float=v.world_depth_scale(world)
			_ribbon(v,point+Vector2(10,-220)*scale,point,24*scale,color,1-smoothstep(.04,.18,age),-14*scale)
		if age>=0 and age<.20: _zone(v,world,radius,color,.32*(1-age/.20),true,true)
		_wave(v,world,radius,age,color,false,true)
	elif kind in ["rift_laser","kindred_lasers"]:
		for target: Vector2 in effect.get("targets",effect.get("points",[effect.get("target",world)])):
			_beam(v,source,target,14 if kind=="kindred_lasers" else radius,age,color,2.5 if kind=="kindred_lasers" else 1.0)
	elif kind=="rift_overhead":
		for target: Vector2 in effect.get("points",[]):
			if age>=0 and age<.16:
				var point: Vector2=v.world_to_screen(target)
				var scale: float=v.world_depth_scale(target)
				_ribbon(v,point+Vector2(12,-150)*scale,point,16*scale,color,1-age/.16,14*scale)
			_wave(v,target,radius,age,color)
	elif kind in ["rift_storm","slime_reflux","galio_durand","galio_entrance"]:
		# Durand acts around cast_source, not event.pos (the old aim point).
		var center:=source if kind=="galio_durand" else world
		if age>=0 and age<.20: _zone(v,center,radius,color,.32*(1-age/.20))
		_wave(v,center,radius,age,color,kind in ["slime_reflux","galio_durand"])
		if kind in ["galio_entrance","galio_durand"] and age>=0 and age<.24:
			var radii: Vector2=v.sim.ability_area_screen_radii(center,radius)
			var point: Vector2=v.world_to_screen(center)
			var scale: float=v.world_depth_scale(center)
			for side in [-1.0,1.0]:
				var foot:=point+Vector2(side*radii.x*.56,radii.y*.26)
				_ribbon(v,foot,foot+Vector2(side*35,-135)*scale,16*scale,color,1-age/.24,side*24*scale)
	elif kind=="galio_punch": _beam(v,source,Vector2(effect.get("finish",world)),radius,age,color)
	elif kind in ["slime_bounce","slime_burst","slime_court","kindred_dance","kindred_dread","kindred_hunt","rift_orbs"]:
		var targets: Array=effect.get("points",[effect.get("target",world+Vector2.LEFT*100)])
		if targets.is_empty(): targets=[world+Vector2.LEFT*100]
		for index in mini(3,targets.size()): _launch(v,world,Vector2(targets[index]),age,color)
	elif kind=="kindred_wolf": _wave(v,world,radius,age,color)
	elif kind in ["kindred_respite","kindred_respite_end"]:
		_zone(v,world,radius,Color("#cfceee"),.40)
		if kind=="kindred_respite_end": _wave(v,world,radius,age,color)
		else: _arc(v,v.world_to_screen(world),v.sim.ability_area_screen_radii(world,radius)*.84,float(v.clock)*.65,1.5,5,_color(kind),.42)
	elif kind=="galio_guard":
		if age<.38:
			var point: Vector2=v.world_to_screen(world)
			_arc(v,point+Vector2(0,-36),Vector2(52,68)*v.world_depth_scale(world),-PI*.75+age*2,PI*1.5,9,color,1-age/.38)
	elif kind=="galio_winds": _launch(v,source,world,age,color)
	_event_hits(v,effect,age,color)
	return true

static func draw_projectile(v, projectile: Dictionary) -> bool:
	if not rendering_enabled: return false
	var kind:=str(projectile.get("kind",""))
	if kind not in ["kindred_arrow","kindred_dread_arrow","rift_orb","slime_glob","slime_image"]: return false
	if float(projectile.get("delay",0))>0: return true
	var world:=Vector2(projectile.pos)
	var point: Vector2=v.world_to_screen(world)
	var scale: float=v.world_depth_scale(world)
	var direction:=Vector2(projectile.get("direction",Vector2.LEFT))
	if projectile.has("target_pos"): direction=v.world_to_screen(Vector2(projectile.target_pos))-point
	elif int(projectile.get("target_id",-1))>=0 and int(projectile.target_id)<v.sim.heroes.size():
		direction=v.world_to_screen(Vector2(v.sim.heroes[int(projectile.target_id)].pos))-point
	if direction.length_squared()<.01: direction=Vector2.LEFT
	direction=direction.normalized()
	var color:=_color(kind,int(projectile.get("phase",1)))
	var arrow:=kind in ["kindred_arrow","kindred_dread_arrow"]
	var length:=(92 if int(projectile.get("dread_stack",0))>=3 else (64 if arrow else 43))*scale
	_ribbon(v,point-direction*length,point+direction*8*scale,(6 if arrow else 11)*scale,color,.95,0 if arrow else 8*scale)
	_glow(v,point,Vector2.ONE*31*scale,color,.15)
	return true

static func draw_hazard(v, hazard: Dictionary) -> bool:
	if not rendering_enabled: return false
	var kind:=str(hazard.get("kind",""))
	if kind not in ["kindred_wolf_zone","galio_winds","slime_bounce_impact","slime_court_final","slime_pool"]: return false
	var world:=Vector2(hazard.pos)
	var radius:=float(hazard.get("radius",100))
	var delay:=float(hazard.get("delay",0))
	var color:=_color(kind,int(hazard.get("phase",1)))
	if delay>0:
		_zone(v,world,radius,WARNING_RED,.70)
		if kind=="galio_winds":
			var source:=Vector2(hazard.get("source",world))
			var travel:=1-clampf(delay/maxf(.01,float(hazard.get("travel_total",.72))),0,1)
			var head: Vector2=v.world_to_screen(source.lerp(world,travel))
			var direction: Vector2=(v.world_to_screen(world)-v.world_to_screen(source)).normalized()
			_ribbon(v,head-direction*75,head,10,color,.65,18)
		return true
	_zone(v,world,radius,color,.30)
	if kind in ["kindred_wolf_zone","galio_winds","slime_pool"]:
		var radii: Vector2=v.sim.ability_area_screen_radii(world,radius)
		var angle:=float(v.clock)*(2.2 if kind=="kindred_wolf_zone" else -1.8)
		for index in (1 if _lean(v) else 2):
			_arc(v,v.world_to_screen(world),radii*(.60+float(index)*.18),angle+index*PI,1.8,7*v.world_depth_scale(world),color,.58 if kind!="slime_pool" else .30)
	# Sparks only from real *_hit / *_pulse events, never a hazard's start.
	return true

static func draw_support_warning(v, kind: String) -> bool:
	if not rendering_enabled: return false
	var key:="support_barrage" if kind=="barrage" else "support_crossfire"
	if not v.sim.supports.has(key): return false
	var support: Dictionary=v.sim.supports[key]
	var total:=1.35 if kind=="barrage" else .85
	var remaining:=float(support.get("timer",99))
	if remaining<=0 or remaining>total or v.sim.enemies.is_empty(): return true
	var progress:=1-remaining/total
	var color:=_color(kind)
	if kind=="barrage":
		if not support.has("target_point"): return true
		var world:=Vector2(support.target_point)
		_zone(v,world,float(support.get("radius",105)),WARNING_RED,.50+progress*.32,true,true)
		var scale: float=v.world_depth_scale(world)
		var point: Vector2=v.world_to_screen(world)+Vector2(0,-145)*scale
		_arc(v,point,Vector2(lerpf(28,13,progress),lerpf(17,8,progress))*scale,float(v.clock)*3,4.2,5*scale,color,.25+progress*.62)
	else:
		if not support.has("lane_y"): return true
		var field: Rect2=v.sim.active_view_rect if v.sim.endless_mode else Sim.MOVE_AREA
		var y:=float(support.lane_y)
		var corners:=PackedVector2Array([v.world_to_screen(Vector2(field.position.x,y-58)),v.world_to_screen(Vector2(field.end.x,y-58)),v.world_to_screen(Vector2(field.end.x,y+58)),v.world_to_screen(Vector2(field.position.x,y+58))])
		v.draw_colored_polygon(corners,Color(color,.025+progress*.018))
		v.draw_polyline(_closed(corners),Color(WARNING_RED,.50+progress*.30),2,true)
		for side in [0,1]:
			var point:=corners[side].lerp(corners[3-side],.5)
			_arc(v,point,Vector2(lerpf(30,13,progress),lerpf(19,9,progress)),float(v.clock)*2+side*PI,3.8,5,color,.25+progress*.62)
	return true

static func _crossfire(v, effect: Dictionary, age: float) -> void:
	if age<0 or age>=.38: return
	var field: Rect2=v.sim.active_view_rect if v.sim.endless_mode else Sim.MOVE_AREA
	var y:=float(effect.get("lane_y",Vector2(effect.pos).y))
	var half_width:=float(effect.get("lane_half_width",58))
	var color:=_color("crossfire")
	var fade:=1-smoothstep(.10,.38,age)
	var travel:=clampf(age/.19,0,1)
	for side in [0,1]:
		var start:=Vector2(field.position.x if side==0 else field.end.x,y-half_width*.38)
		var finish:=Vector2(field.end.x if side==0 else field.position.x,y+half_width*.38)
		var head: Vector2=v.world_to_screen(start.lerp(finish,travel))
		var tail: Vector2=v.world_to_screen(start.lerp(finish,maxf(0,travel-.36)))
		_ribbon(v,tail,head,11,color,fade,side*6-3)
		# Full firing strand at the actual instantaneous release, then moving tails.
		if age<.10: _ribbon(v,v.world_to_screen(start),v.world_to_screen(finish),4.5,color,(1-age/.10)*.80)
