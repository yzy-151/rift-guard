extends RefCounted
## Four physical devices share the simulation's exact active footprints.
## Cosmetic feedback never mutates feature state or consumes gameplay RNG.
const TYPES := ["relay", "spring", "wind_lane", "hazard_lane"]
const Flash = preload("res://scripts/impact_flash_vfx.gd")
const INK := Color("#12121c")
const PAPER := Color("#f6eada")
const COLORS := {"relay":Color("#c3a0ff"),"spring":Color("#87e9cf"),"wind_lane":Color("#aad8d7"),"hazard_lane":Color("#f7aa67")}
const ATLAS_PATH := "res://assets/world/v92-devices/functional-atlas.png"
const REGIONS := {"relay":Rect2(127,163,388,374),"spring":Rect2(737,165,388,376),"wind_lane":Rect2(105,800,426,231),"hazard_lane":Rect2(726,800,428,232)}
static var atlas: Texture2D
var bursts: Array[Dictionary] = []

func reset() -> void:
	bursts.clear()

func accept(batch: Array[Dictionary]) -> void:
	for event: Dictionary in batch:
		if str(event.get("kind",""))!="terrain_react": continue
		if str(event.get("type",""))!="spring": continue
		if str(event.get("phase","")) not in ["active","pulse","depleted"]: continue
		var burst:=event.duplicate()
		burst.life=0.52 if str(event.get("type",""))=="spring" else 0.32
		burst.total=burst.life
		bursts.append(burst)
		if bursts.size()>32: bursts.pop_front()

func advance(dt: float) -> void:
	for i in range(bursts.size()-1,-1,-1):
		bursts[i].life=float(bursts[i].life)-dt
		if float(bursts[i].life)<=0: bursts.remove_at(i)

static func color(feature: Dictionary) -> Color:
	return COLORS.get(str(feature.get("type","")),PAPER)

static func _outline(v, points: PackedVector2Array, tint: Color, width: float=2.0) -> void:
	if points.size()<3: return
	var loop:=points.duplicate()
	loop.append(loop[0])
	v.draw_polyline(loop,tint,width,true)

static func _plinth(v, rect: Rect2, tint: Color) -> void:
	var cut:=minf(8.0,minf(rect.size.x,rect.size.y)*0.18)
	var a:=rect.position
	var b:=rect.end
	var points:=PackedVector2Array([a+Vector2(cut,0),Vector2(b.x-cut,a.y),Vector2(b.x,a.y+cut),b-Vector2(0,cut),b-Vector2(cut,0),Vector2(a.x+cut,b.y),Vector2(a.x,b.y-cut),a+Vector2(0,cut)])
	v.draw_colored_polygon(points,Color("#252734"))
	_outline(v,points,INK,3)
	v.draw_line(a+Vector2(cut,3),Vector2(b.x-cut,a.y+3),Color(tint,0.24),2,true)

static func _sprite(v, kind: String, rect: Rect2, rotation: float=0.0, tint: Color=Color.WHITE) -> void:
	if atlas==null and ResourceLoader.exists(ATLAS_PATH): atlas=load(ATLAS_PATH)
	if atlas==null:
		_plinth(v,rect,COLORS[kind])
		v.draw_circle(rect.get_center(),8,COLORS[kind])
		return
	var source:Rect2=REGIONS[kind]
	var fit:=minf(rect.size.x/source.size.x,rect.size.y/source.size.y)
	var size:=source.size*fit
	v.draw_set_transform(rect.get_center(),rotation)
	v.draw_texture_rect_region(atlas,Rect2(-size*0.5,size),source,tint)
	v.draw_set_transform(Vector2.ZERO)

static func _brackets(v, rect: Rect2, tint: Color, alpha: float=0.5) -> void:
	var n:=minf(12,minf(rect.size.x,rect.size.y)*0.28)
	for edge in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
		var corner:Vector2=rect.get_center()+rect.size*edge*0.5
		v.draw_polyline(PackedVector2Array([corner-Vector2(edge.x*n,0),corner,corner-Vector2(0,edge.y*n)]),Color(tint,alpha),1.5,true)

static func _glow(v, point: Vector2, size: Vector2, tint: Color, strength: float) -> void:
	if v.light_layer!=null and not v.reduced_effects:
		v.light_layer.glow(point,size,tint,strength)

static func _arrow(v, point: Vector2, direction: Vector2, tint: Color, size: float=5.0) -> void:
	var side:=direction.orthogonal()
	v.draw_polyline(PackedVector2Array([point-direction*size+side*size,point,point-direction*size-side*size]),tint,2,true)

static func _relay_lane(v, feature: Dictionary, tint: Color) -> void:
	var world:Rect2=feature.get("effect_area",feature.area)
	var rect:=Rect2(v.world_to_screen(world.position),world.size)
	var phase:=str(feature.get("phase","idle"))
	var direction:Vector2=feature.get("facing",Vector2.RIGHT)
	var length:=rect.size.x if absf(direction.x)>0.5 else rect.size.y
	var start:=rect.get_center()-direction*length*0.5
	var finish:=rect.get_center()+direction*length*0.5
	var progress:=clampf(float(feature.get("phase_progress",0)),0,1)
	if phase=="warning":
		v.draw_rect(rect,Color(tint,0.025+progress*0.04))
		_brackets(v,rect,tint,0.24+progress*0.30)
		v.draw_line(start,finish,Color(tint,0.12+progress*0.26),1.0,true)
		_glow(v,start,Vector2(38,42),tint,progress*0.35)
	elif phase=="active":
		Flash.beam(v,start,finish,progress*float(feature.get("active_duration",0.22)),0.38,tint)
	elif phase=="cooldown":
		var residual_age:=0.22+progress*float(feature.get("cooldown",8.0))
		if residual_age<0.38: Flash.beam(v,start,finish,residual_age,0.38,tint)

static func _lane(v, feature: Dictionary, tint: Color, danger: bool) -> void:
	if not danger:
		_relay_lane(v,feature,tint)
		return
	var world: Rect2=feature.get("effect_area",feature.area)
	var rect:=Rect2(v.world_to_screen(world.position),world.size)
	var phase:=str(feature.get("phase","cooldown"))
	var active:=phase=="active"
	var warning:=phase=="warning"
	var progress:=clampf(float(feature.get("phase_progress",0)),0,1)
	var intensity:=0.12 if active else (0.035+progress*0.06 if warning else 0.015)
	v.draw_rect(rect,Color(tint,intensity))
	_brackets(v,rect,tint,0.75 if active or warning else 0.17)
	var horizontal:=rect.size.x>=rect.size.y
	var axis:=Vector2.RIGHT if horizontal else Vector2.DOWN
	var side:=axis.orthogonal()
	var length:=rect.size.x if horizontal else rect.size.y
	var width:=rect.size.y if horizontal else rect.size.x
	var start:=rect.get_center()-axis*length*0.5
	var motion:=0.0 if v.reduced_effects else float(feature.get("clock",v.clock))
	if warning:
		for offset in [-1.0,1.0]:
			v.draw_dashed_line(start+side*width*0.48*offset,start+axis*length+side*width*0.48*offset,Color(tint,0.60),1.5,8,true)
		for i in maxi(1,floori(length/56)):
			var p:=start+axis*(28+i*56)
			if danger:
				v.draw_line(p-side*5,p+side*5,tint,2,true)
				v.draw_circle(p+axis*5,1.5,tint)
			else: _arrow(v,p,axis,Color(tint,0.5),4)
	if not active: return
	var count:=maxi(2,floori(length/24))
	for i in count:
		var along:=fposmod(i*24.0+motion*60.0,length-12.0)+6
		var p:=start+axis*along+side*sin(i*2.8)*width*0.23
		var plume:=13+8*sin(i+motion*13)
		var flame:=PackedVector2Array([p-axis*7,p-side*5-axis*3,p+axis*plume*0.6-side*3,p+axis*plume+side*sin(i)*5,p+axis*4+side*5])
		v.draw_colored_polygon(flame,Color(tint,0.82))
		v.draw_line(p,p+axis*plume*0.6,PAPER,2,true)
		if i%3==0: _glow(v,p,Vector2(60,45),tint,0.22)

static func draw_feature(v, world: Rect2, feature: Dictionary) -> void:
	var kind:=str(feature.get("type",""))
	if kind not in TYPES: return
	var rect:=Rect2(v.world_to_screen(world.position),world.size)
	var center:=rect.get_center()
	var tint:=color(feature)
	var phase:=str(feature.get("phase","idle"))
	var direction:Vector2=feature.get("facing",Vector2.RIGHT)
	var clock_value:=float(feature.get("clock",v.clock))
	var motion:=0.0 if v.reduced_effects else clock_value
	match kind:
		"relay":
			_lane(v,feature,tint,false)
			var activation:Rect2=feature.get("activation_area",world.grow(34))
			_brackets(v,Rect2(v.world_to_screen(activation.position),activation.size),tint,0.3 if phase=="charging" else 0.11)
			_sprite(v,kind,Rect2(center-Vector2(45,45),Vector2(90,90)))
			var charge:=float(feature.get("charge",0))
			for i in 4:
				var p:=center+Vector2(-18+i*12,31)
				v.draw_rect(Rect2(p,Vector2(8,3)),tint if charge>(i+0.5)/4.0 else Color("#494456"))
			if phase in ["charging","warning","active"]:
				_glow(v,center,Vector2(50,50),tint,0.18+charge*0.35)
				if phase=="warning":
					v.draw_line(center-direction*11,center+direction*11,Color(PAPER,0.75),2,true)
		"spring":
			var fill:=clampf(float(feature.get("reservoir",0))/maxf(1,float(feature.get("capacity",80))),0,1)
			_sprite(v,kind,Rect2(center-Vector2(48,48),Vector2(96,96)),0,Color.WHITE.darkened(0.3 if fill<=0.05 else 0))
			v.draw_arc(center+Vector2(0,-3),11+sin(motion*2.0),0.3,PI*1.8,24,Color(tint,fill*0.35),1,true)
			for i in 4:
				var p:=center+Vector2(-17+i*11,32)
				v.draw_rect(Rect2(p,Vector2(7,3)),tint if fill>(i+0.5)/4.0 else Color("#344847"))
			_glow(v,center,Vector2(62,52),tint,0.10*fill)
		"wind_lane":
			# A floor inlay and small grates, not an opaque UI-shaped track.
			v.draw_rect(rect,Color(0.12,0.23,0.24,0.18))
			var horizontal:=absf(direction.x)>0.5
			var lane_length:=rect.size.x if horizontal else rect.size.y
			var side:=direction.orthogonal()
			var width:=rect.size.y if horizontal else rect.size.x
			var start:=center-direction*lane_length*0.5
			for fraction in [0.1,0.9]:
				var grate:Vector2=start+direction*lane_length*fraction
				_sprite(v,kind,Rect2(grate-Vector2(32,18),Vector2(64,36)),direction.angle())
			for edge in [-1.0,1.0]:
				for i in maxi(1,floori(lane_length/48)):
					var a:Vector2=start+direction*(i*48+6)+side*width*0.44*edge
					v.draw_line(a,a+direction*30,Color(tint,0.20),1.5,true)
			for i in maxi(2,floori(lane_length/38)):
				var p:=start+direction*(fposmod(i*38.0+motion*28.0,lane_length-22)+11)
				_arrow(v,p,direction,Color(tint,0.3),4)
				if not v.reduced_effects:
					v.draw_line(p+side*width*0.24-direction*12,p+side*width*0.24,Color(tint,0.16),1,true)
		"hazard_lane":
			_lane(v,feature,tint,true)
			var horizontal:=rect.size.x>=rect.size.y
			var axis:=Vector2.RIGHT if horizontal else Vector2.DOWN
			for sign_value in [-1.0,1.0]:
				var p:Vector2=center+axis*sign_value*((rect.size.x if horizontal else rect.size.y)*0.5-17)
				_sprite(v,kind,Rect2(p-Vector2(32,24),Vector2(64,48)),0 if horizontal else PI*0.5)
			if phase=="warning":
				_glow(v,center,rect.size,tint,0.07)

func draw_feedback(v) -> void:
	for burst:Dictionary in bursts:
		if str(burst.get("type",""))!="spring": continue
		var center:Vector2=v.world_to_screen(Vector2(burst.pos))
		var t:=1.0-float(burst.life)/float(burst.total)
		var tint:Color=COLORS.spring
		var alpha:float=(1-t)*0.85
		for i in (3 if v.reduced_effects else 6):
			var p:=center+Vector2(cos(i*2.4)*25,sin(i*2.4)*14-24*t)
			v.draw_line(p-Vector2(3,0),p+Vector2(3,0),Color(tint,alpha),2,true)
			v.draw_line(p-Vector2(0,3),p+Vector2(0,3),Color(tint,alpha),2,true)
		_glow(v,center,Vector2(95,80),tint,alpha*0.2)

static func description(feature:Dictionary) -> String:
	match str(feature.get("type","")):
		"relay": return "驻守蓄电 · 沿前方直线贯穿放电"
		"spring": return "回复生命与能量 · 储量缓慢恢复"
		"wind_lane": return "顺风移速 +35% · 敌我双方有效"
		"hazard_lane": return "亮起后喷发 · 火焰伤及敌我"
	return ""

static func draw_hint(v) -> void:
	var mouse:Vector2=v.get_global_mouse_position()
	if not Rect2(18,60,1244,548).has_point(mouse): return
	var point:Vector2=v.screen_to_world(mouse)
	for feature:Dictionary in v.sim.terrain_features:
		if str(feature.get("type","")) not in TYPES: continue
		if not Rect2(feature.area).has_point(point): continue
		var tint:=color(feature)
		var place:=Vector2(clampf(mouse.x+18,24,986),clampf(mouse.y-72,118,536))
		var box:=Rect2(place,Vector2(266,61))
		v.draw_rect(box,Color(INK,0.96))
		v.draw_rect(Rect2(place,Vector2(3,61)),tint)
		var label_text:=str(feature.get("label","机关"))
		var phase:=str(feature.get("phase","idle"))
		var status:String={"idle":"待驻守","charging":"蓄电中","warning":"即将释放","active":"生效中","cooldown":"冷却中","ready":"可使用","depleted":"恢复储量"}.get(phase,"")
		v.caption(place+Vector2(12,20),label_text+"  ·  "+status,tint,13)
		v.caption(place+Vector2(12,41),description(feature),PAPER,12)
		var progress:=float(feature.get("phase_progress",0))
		if str(feature.type)=="relay" and phase in ["idle","charging","warning","active"]: progress=float(feature.get("charge",0))
		elif str(feature.type)=="wind_lane":progress=1.0
		if str(feature.type)=="spring":progress=float(feature.get("reservoir",0))/maxf(1,float(feature.get("capacity",80)))
		v.draw_rect(Rect2(place+Vector2(12,51),Vector2(242,2)),Color("#403a48"))
		v.draw_rect(Rect2(place+Vector2(12,51),Vector2(242*clampf(progress,0,1),2)),tint)
		return
