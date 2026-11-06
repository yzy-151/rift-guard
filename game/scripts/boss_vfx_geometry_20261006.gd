extends RefCounted
## Only geometry and material helpers; each boss owns its own choreography.
const GroundProjection = preload("res://scripts/stage_projection.gd")
const INK := Color("#12131d")
const DANGER := Color("#ed234e")
static var light_texture: Texture2D
static var validate_geometry := false
static var invalid_geometry := 0

static func prewarm() -> void:
	validate_geometry = "--qa-vfx-triangulation" in OS.get_cmdline_user_args()
	if light_texture != null: return
	var image := Image.create(64,64,false,Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x-31.5,y-31.5).length()/31.5
			image.set_pixel(x,y,Color(1,1,1,pow(maxf(0,1-d),2.4)))
	light_texture = ImageTexture.create_from_image(image)

static func ellipse_points(p: Vector2, r: Vector2, segments: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in segments:
		points.append(p+Vector2.from_angle(TAU*float(index)/segments)*r)
	return points

static func closed(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	if not result.is_empty(): result.append(result[0])
	return result

static func area_points(v, world: Vector2, radius: float, barrage: bool = false, segments: int = 48) -> PackedVector2Array:
	var radii: Vector2 = v.sim.support_barrage_screen_radii(world,radius) if barrage else v.sim.ability_area_screen_radii(world,radius)
	if v.sim.endless_mode:
		return ellipse_points(v.world_to_screen(world)+Vector2(0,0 if barrage else 8),radii,segments)
	var outline := GroundProjection.ground_outline(world,radii,segments,0 if barrage else 8)
	outline.remove_at(outline.size()-1)
	return outline

static func area_center(v, world: Vector2, barrage: bool = false) -> Vector2:
	return v.world_to_screen(world)+Vector2(0,0 if barrage else 8)

static func area_radii(v, world: Vector2, radius: float, barrage: bool = false) -> Vector2:
	return v.sim.support_barrage_screen_radii(world,radius) if barrage else v.sim.ability_area_screen_radii(world,radius)

static func body(v, points: PackedVector2Array, color: Color, outline: bool = true) -> void:
	if points.size()<3 or color.a<=.001: return
	if validate_geometry and Geometry2D.triangulate_polygon(points).is_empty():
		invalid_geometry += 1
		push_error("Boss geometry invalid: "+str(points))
		print_stack()
		return
	v.draw_colored_polygon(points,color)
	if outline: v.draw_polyline(closed(points),Color(INK,color.a*.82),2,true)

static func ellipse(v, p: Vector2, r: Vector2, color: Color, outline: bool = false) -> void:
	if minf(r.x,r.y)<.5: return
	body(v,ellipse_points(p,r,32),color,outline)

static func area(v, world: Vector2, radius: float, color: Color, fill: float = .04, edge_width: float = 2.0, barrage: bool = false) -> void:
	var points := area_points(v,world,radius,barrage)
	if fill>0: body(v,points,Color(color,fill),false)
	if edge_width>0: v.draw_polyline(closed(points),color,edge_width,true)

static func band(v, p: Vector2, r: Vector2, outer: float, inner: float, color: Color) -> void:
	if outer<=inner or inner<0 or color.a<=.001 or minf(r.x,r.y)<.5: return
	var middle := (outer+inner)*.5
	var width := maxf(.65,(outer-inner)*minf(r.x,r.y))
	v.draw_polyline(closed(ellipse_points(p,r*middle,64)),color,width,true)

static func glow(v, p: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	if light_texture==null or alpha<=.005: return
	if v.has_method("emit_glow"): v.emit_glow(light_texture,p,size,color,clampf(alpha,0,.62))
	else: v.draw_texture_rect(light_texture,Rect2(p-size*.5,size),false,Color(color,clampf(alpha,0,.25)))

static func streak(v, a: Vector2, b: Vector2, width: float, color: Color, alpha: float = 1.0) -> void:
	if a.distance_squared_to(b)<1 or width<.5 or alpha<=.005: return
	var direction := (b-a).normalized()
	var normal := direction.orthogonal()
	var middle := a.lerp(b,.65)
	var points := PackedVector2Array([a,middle+normal*width*.52,b+direction*width*.7,middle-normal*width*.52])
	body(v,points,Color(color,alpha),false)
	var core := PackedVector2Array([a.lerp(b,.22),middle+normal*width*.17,b,middle-normal*width*.17])
	body(v,core,Color("#fffdf1",alpha*.95),false)

static func bolt(v, a: Vector2, b: Vector2, width: float, color: Color, seed_value: int = 0) -> void:
	if a.distance_squared_to(b)<1: return
	var normal := (b-a).normalized().orthogonal()
	var points := PackedVector2Array([a])
	for index in range(1,8):
		var t := float(index)/8
		points.append(a.lerp(b,t)+normal*sin(float(index*13+seed_value)*1.72)*width*.9*sin(t*PI))
	points.append(b)
	# A light discharge has a soft colored shoulder, not a dark rail outline.
	v.draw_polyline(points,Color(color,color.a*.12),width*3.3,true)
	v.draw_polyline(points,Color(color,color.a*.26),width*1.8,true)
	v.draw_polyline(points,color,width,true)
	v.draw_polyline(points,Color("#fffafd",color.a),maxf(1.4,width*.28),true)

static func shards(v, p: Vector2, size: float, age: float, color: Color, seed_value: int = 0) -> void:
	if age<0 or age>.48: return
	var fade := 1-smoothstep(.12,.48,age)
	var count := 5 if bool(v.reduced_effects) else 8
	for index in count:
		var angle := float(index)*2.39996+float(seed_value)*.41
		var direction := Vector2.from_angle(angle)
		var velocity := size*(1.5+float(index%3)*.33)
		var center := p+direction*(8+age*velocity)+Vector2(0,age*age*80)
		# Subpixel geometry must not collapse below the triangulator's tolerance.
		var length := maxf(.65,(5+float(index%3)*3)*fade)
		var side := direction.orthogonal()*length*.42
		body(v,PackedVector2Array([center+direction*length,center+side,center-direction*length*.45,center-side]),Color(color,fade),false)
		if index<3: body(v,PackedVector2Array([center+direction*length,center+side,center]),Color("#fff8df",fade),false)

static func capsule_points(v, source: Vector2, target: Vector2, radius: float, metric_y: float = 1.0) -> PackedVector2Array:
	var metric := Vector2(1,metric_y)
	var a := source*metric
	var b := target*metric
	var direction := (b-a).normalized()
	if direction.length_squared()<.01: direction=Vector2.LEFT
	var first := direction.angle()-PI*.5
	var points := PackedVector2Array()
	for index in 13: points.append(v.world_to_screen((b+Vector2.from_angle(first+PI*float(index)/12)*radius)/metric))
	for index in 13: points.append(v.world_to_screen((a+Vector2.from_angle(first+PI+PI*float(index)/12)*radius)/metric))
	return points

static func capsule(v, source: Vector2, target: Vector2, radius: float, color: Color, fill: float = .04, metric_y: float = 1.0) -> void:
	var points := capsule_points(v,source,target,radius,metric_y)
	body(v,points,Color(color,fill),false)
	v.draw_polyline(closed(points),color,2,true)

static func age_of(effect: Dictionary) -> float:
	var total := float(effect.get("total",1))
	return total-float(effect.get("life",total))

static func progress_of(enemy: Dictionary) -> float:
	return 1-clampf(float(enemy.get("special_warning",0))/maxf(.01,float(enemy.get("special_warning_total",1))),0,1)
