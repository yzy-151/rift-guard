extends RefCounted
const PLANTS = preload("res://scripts/pvz_plant_visual.gd")
const EXPLOSION = preload("res://scripts/explosion_vfx_20261005.gd")
const PEA = preload("res://assets/world/pvz_botany_20261005/projectile_pea.png")
const SNOW_PEA = preload("res://assets/world/pvz_botany_20261005/projectile_snowpea.png")
const MELON = preload("res://assets/world/pvz_botany_20261005/projectile_melon.png")
const PEA_DIAMETER := 20.0
const MELON_RADIUS := 25.0
const INK := Color("#0b1019")
const WHITE := Color("#fff8ec")

static func polygon(v, cell: Rect2) -> PackedVector2Array:
	return PackedVector2Array([v.world_to_screen(cell.position),v.world_to_screen(Vector2(cell.end.x,cell.position.y)),v.world_to_screen(cell.end),v.world_to_screen(Vector2(cell.position.x,cell.end.y))])

static func ground(v) -> void:
	var devices = v.sim.battle_devices
	for device: Dictionary in devices.placed:
		if device.hp <= 0.0: continue
		var cell := Rect2(device.cell).grow(-3.0)
		var color := Color("#ffbf4c") if device.kind == "power" else Color("#7ddcef")
		var points := polygon(v,cell)
		if device.kind in ["power", "range"]:
			v.draw_colored_polygon(points,Color(INK,.78))
			var edge := points.duplicate();edge.append(points[0])
			v.draw_polyline(edge,Color(color,.9),1.6,true)
			var c: Vector2 = v.world_to_screen(device.pos)
			var depth: float = v.world_depth_scale(device.pos)
			if device.kind == "power":
				var bolt := PackedVector2Array([c+Vector2(-2,-11)*depth,c+Vector2(9,-11)*depth,c+Vector2(2,-1)*depth,c+Vector2(8,-1)*depth,c+Vector2(-7,12)*depth,c+Vector2(-2,3)*depth,c+Vector2(-9,3)*depth])
				v.draw_colored_polygon(bolt, color)
			else:
				v.draw_arc(c,9*depth,0,TAU,24,Color(color,.85),1.4,true)
				v.draw_line(c+Vector2(-15,0)*depth,c+Vector2(-5,0)*depth,color,1.4,true)
				v.draw_line(c+Vector2(5,0)*depth,c+Vector2(15,0)*depth,color,1.4,true)
				v.draw_line(c+Vector2(0,-15)*depth,c+Vector2(0,-5)*depth,color,1.4,true)
				v.draw_line(c+Vector2(0,5)*depth,c+Vector2(0,15)*depth,color,1.4,true)
	if not devices.selected_kind.is_empty() and devices.hover_cell.size != Vector2.ZERO:
		var p := polygon(v,Rect2(devices.hover_cell).grow(-1.0))
		var color := Color("#85f2c8") if devices.valid else Color("#ff4568")
		v.draw_colored_polygon(p,Color(color,.16))
		p.append(p[0]);v.draw_polyline(p,color,2.2,true)
		if devices.selected_kind in ["pea", "snowpea", "melon"] and devices.valid:
			var row := Rect2(Vector2(devices.hover_cell.end.x,devices.hover_cell.position.y),Vector2(maxf(0.0,1240-devices.hover_cell.end.x),devices.hover_cell.size.y))
			v.draw_colored_polygon(polygon(v,row),Color(color,.07))
	for shot: Dictionary in devices.shots:
		if str(shot.get("kind", "pea")) == "melon" or float(shot.pos.x)-float(shot.get("model_origin",shot.pos).x)>16.0: _shot(v,shot)

static func _shot(v, shot: Dictionary) -> void:
	if str(shot.get("kind", "pea")) == "melon":
		_melon_shot(v, shot)
		return
	var p: Vector2=PLANTS.shot_screen(v,shot)
	var traveled := maxf(0.0,float(shot.pos.x)-float(shot.get("model_origin",shot.pos).x))
	var tail: Vector2=PLANTS.shot_screen(v,shot,Vector2(shot.pos)-Vector2(minf(12,traveled),0))
	var ice := str(shot.get("kind", "pea")) == "snowpea" or bool(shot.get("slow", false))
	var color := Color("#72dbff") if ice else Color("#93e34c")
	v.draw_line(tail,p,Color(color,.30),3,true)
	var radius: float = PEA_DIAMETER*.5*v.world_depth_scale(Vector2(shot.get("visual_origin",shot.pos)))
	v.draw_texture_rect(SNOW_PEA if ice else PEA, Rect2(p-Vector2.ONE*radius,Vector2.ONE*radius*2.0),false)

static func _melon_shot(v, shot: Dictionary) -> void:
	var progress := clampf(float(shot.get("flight_time", 0.0)) / maxf(.01, float(shot.get("flight_total", 1.0))), 0.0, 1.0)
	var origin := Vector2(shot.get("visual_origin", shot.model_origin))
	var start: Vector2 = PLANTS.melon_release_screen(v, origin)
	var landing: Vector2 = v.world_to_screen(shot.target)
	var point: Vector2 = start.lerp(landing, progress) - Vector2(0, sin(progress * PI) * float(shot.get("arc_height", 85.0)))
	var radius: float = MELON_RADIUS * v.world_depth_scale(origin)
	v.draw_ellipse_shadow(v.world_to_screen(shot.pos) - Vector2(0, 9), radius, Color(0,0,0,.26))
	v.draw_set_transform(point, progress * TAU)
	v.draw_texture_rect(MELON, Rect2(Vector2(-radius,-radius*.87),Vector2(radius*2,radius*1.74)),false)
	v.draw_set_transform(Vector2.ZERO)

static func actor(v, device: Dictionary) -> void:
	var p: Vector2 = v.world_to_screen(device.pos)
	var depth: float = v.world_depth_scale(device.pos)
	PLANTS.draw(v,device)
	if device.kind in ["pea", "snowpea"] and str(device.get("visual_variant", "pea")) != "melon":
		# The newly released pea must remain visible inside the painted mouth opening.
		for shot: Dictionary in v.sim.battle_devices.muzzle_shots.get(Vector2(device.pos), []):
			_shot(v,shot)
	if device.kind == "barricade" or (device.kind in ["pea", "snowpea", "sunflower", "melon"] and device.hp < device.max_hp):
		v.draw_rect(Rect2(p+Vector2(-24,7)*depth,Vector2(48,3)*depth),INK)
		v.draw_rect(Rect2(p+Vector2(-24,7)*depth,Vector2(48*float(device.hp)/maxf(1.0,float(device.max_hp)),3)*depth),Color("#8be1bd"))
	elif device.kind == "mine" and not bool(device.get("armed", false)):
		var ratio := 1.0 - clampf(float(device.get("arm_remaining", 3.0)) / 3.0, 0.0, 1.0)
		v.draw_rect(Rect2(p + Vector2(-15, 8)*depth, Vector2(30, 2)*depth), INK)
		v.draw_rect(Rect2(p + Vector2(-15, 8)*depth, Vector2(30*ratio, 2)*depth), Color("#ffc94d"))

static func event(v, e: Dictionary) -> bool:
	var kind := str(e.get("kind", ""))
	if not kind.begins_with("device_"): return false
	var age := maxf(0.0,float(e.get("total",.5))-float(e.get("life",.5)))
	var p: Vector2=v.world_to_screen(e.pos)
	if kind == "device_explosion":
		EXPLOSION.event(v,e)
	elif kind == "device_melon_hit":
		EXPLOSION.impact(v,p,Color("#b8e75c"),age/.48,1.2,v.reduced_effects,0,p)
	elif kind == "device_sun":
		var rise := age * 35.0
		v.draw_circle(p - Vector2(0, 52 + rise), 11.0, Color(INK, 1.0-age/.6))
		v.draw_circle(p - Vector2(0, 52 + rise), 8.5, Color(1,.8,.25,1.0-age/.6))
		v.draw_string(v.COMBAT_LABEL_FONT,p + Vector2(13,-46-rise),"+%d"%int(e.get("value",20)),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color(1,.85,.4,1.0-age/.6))
	elif kind in ["device_place", "device_pea_hit"]:
		if e.has("shot_visual"): p=PLANTS.shot_screen(v,e.shot_visual,e.pos)
		EXPLOSION.impact(v,p,Color("#a9ed67"),age/.28,.58,v.reduced_effects,0,p)
	return true
