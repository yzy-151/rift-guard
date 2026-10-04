extends RefCounted
const FunctionalArt = preload("res://scripts/functional_terrain_art.gd")
## Quiet painted ground and physical terrain share the simulation footprints.
## Decorative scratches and lighting never create hidden collision geometry.
const ROOT := "res://assets/world/v92/"
const INK := Color("#11121b")
const PALETTES := {
	"crimson":{"stone":Color("#393542"),"rim":Color("#71606c"),"light":Color("#c48679"),"water":Color("#20343f")},
	"frost":{"stone":Color("#354652"),"rim":Color("#607b87"),"light":Color("#92c5d5"),"water":Color("#183e53")},
	"wind":{"stone":Color("#424641"),"rim":Color("#7c8070"),"light":Color("#c5c09a"),"water":Color("#294a46")},
	"meadow":{"stone":Color("#4a5049"),"rim":Color("#7a8572"),"light":Color("#bacb9c"),"water":Color("#344c43")}
}
static var textures: Dictionary = {}
static var cell_cache: Dictionary = {}
const REGIONS := {"stone":Rect2(74,82,504,502),"gate":Rect2(678,300,522,89),"trap":Rect2(85,690,482,488),"water":Rect2(716,690,456,481)}

static func merge_cells(cells: Array[Rect2]) -> Array[Rect2]:
	# Merge only rectangles with a complete shared edge. L-shapes and holes stay
	# visible; a six-cell pond becomes one pond instead of six little icons.
	var key:=hash(cells)
	if cell_cache.has(key) and cell_cache[key].source==cells: return cell_cache[key].merged
	var result: Array[Rect2]=cells.duplicate()
	var changed:=true
	while changed:
		changed=false
		for i in result.size():
			for j in range(i+1,result.size()):
				var a:=result[i]
				var b:=result[j]
				var horizontal:=is_equal_approx(a.position.y,b.position.y) and is_equal_approx(a.size.y,b.size.y) and (is_equal_approx(a.end.x,b.position.x) or is_equal_approx(b.end.x,a.position.x))
				var vertical:=is_equal_approx(a.position.x,b.position.x) and is_equal_approx(a.size.x,b.size.x) and (is_equal_approx(a.end.y,b.position.y) or is_equal_approx(b.end.y,a.position.y))
				if horizontal or vertical:
					result[i]=a.merge(b)
					result.remove_at(j)
					changed=true
					break
			if changed: break
	if cell_cache.size()>=128: cell_cache.clear()
	cell_cache[key]={"source":cells.duplicate(),"merged":result}
	return result

static func sprite(v, destination: Rect2, key: String, tint: Color = Color.WHITE) -> bool:
	if not textures.has("props"):
		if not ResourceLoader.exists(ROOT+"terrain-atlas.png"): return false
		textures.props=load(ROOT+"terrain-atlas.png")
	v.draw_texture_rect_region(textures.props,destination,REGIONS[key],tint)
	return true

static func theme_for_stage(id: String) -> String:
	if id=="stage_01": return "meadow"
	if id in ["stage_04","stage_07"]: return "frost"
	if id in ["stage_03","stage_06"]: return "wind"
	return "crimson"

static func texture(theme: String) -> Texture2D:
	if textures.has(theme): return textures[theme]
	var path := ROOT+"courtyard-"+theme+".png"
	if ResourceLoader.exists(path):
		textures[theme]=load(path)
		return textures[theme]
	return null

static func ground(v, destination: Rect2, theme: String) -> void:
	var art := texture(theme)
	v.draw_rect(destination,Color("#1b1d29"))
	if art!=null:
		if not v.sim.endless_mode:
			v.draw_texture_rect(art,destination,false)
		else:
			# Keep small masonry at the same scale as the characters. Stretching a
			# single image over the four-screen arena made individual bricks huge.
			var size:=art.get_size()
			var interior:=Rect2(size*Vector2(0.12,0.15),size*Vector2(0.76,0.70))
			var tile_size:=interior.size*0.62
			for x in range(ceili(destination.size.x/tile_size.x)):
				for y in range(ceili(destination.size.y/tile_size.y)):
					var tile:=Rect2(destination.position+Vector2(x,y)*tile_size,tile_size)
					var visible:=tile.intersection(destination)
					var source:=Rect2(interior.position,visible.size/0.62)
					v.draw_texture_rect_region(art,visible,source,Color(0.74,0.76,0.84))
			# The wall ends at the existing walkable boundary, never inside it.
			var inset:Vector2=v.sim._movement_bounds().position-v.sim.ENDLESS_ARENA.position
			var border:=maxf(0.0,minf(inset.x,inset.y))
			v.draw_texture_rect_region(art,Rect2(destination.position,Vector2(destination.size.x,border)),Rect2(0,0,size.x,size.y*0.1))
			v.draw_texture_rect_region(art,Rect2(destination.position+Vector2(0,destination.size.y-border),Vector2(destination.size.x,border)),Rect2(0,size.y*0.9,size.x,size.y*0.1))
			v.draw_texture_rect_region(art,Rect2(destination.position,Vector2(border,destination.size.y)),Rect2(0,0,size.x*0.075,size.y))
			v.draw_texture_rect_region(art,Rect2(destination.position+Vector2(destination.size.x-border,0),Vector2(border,destination.size.y)),Rect2(size.x*0.925,0,size.x*0.075,size.y))
	# A restrained veil keeps the brightest value budget for units and impacts.
	v.draw_rect(destination,Color(0.035,0.04,0.065,0.13))

static func feature(v, world: Rect2, data: Dictionary, theme: String) -> void:
	if world.size.x<1 or world.size.y<1: return
	if str(data.get("type","")) in FunctionalArt.TYPES:
		FunctionalArt.draw_feature(v,world,data)
		return
	var rect := Rect2(v.world_to_screen(world.position),world.size)
	var kind:=str(data.get("type",""))
	var colors: Dictionary=PALETTES.get(theme,PALETTES.crimson)
	if kind=="blocked" and data.get("grid_cells",[]).is_empty() and str(data.get("collision_shape","rect"))=="ellipse":
		var points:=PackedVector2Array()
		for i in 18:
			var edge:=Vector2.from_angle(i*TAU/18)*rect.size*0.5*(0.96+0.04*cos(i*4.7))
			points.append(rect.get_center()+edge)
		var shadow:=PackedVector2Array()
		for point in points: shadow.append(point+Vector2(2,4))
		v.draw_colored_polygon(shadow,Color(INK,0.6))
		v.draw_colored_polygon(points,colors.stone)
		points.append(points[0])
		v.draw_polyline(points,INK,2,true)
		var c:=rect.get_center()
		v.draw_polyline(PackedVector2Array([c+rect.size*Vector2(-0.33,-0.20),c+rect.size*Vector2(-0.08,-0.32),c+rect.size*Vector2(0.18,-0.24)]),Color(colors.rim,0.6),2,true)
		v.draw_polyline(PackedVector2Array([c+rect.size*Vector2(0.22,0.3),c+rect.size*Vector2(0.1,0.08),c+rect.size*Vector2(0.21,-0.05)]),Color(INK,0.55),1.5,true)
		return
	match kind:
		"blocked": wall(v,rect,colors)
		"door","shortcut","one_way": gate(v,rect,data,colors)
		"low_ground","slow": water(v,rect,colors)
		"high_ground","attack_ground","attack_buff": platform(v,rect,colors)
		"trap": trap(v,rect,data,colors)
		"mechanism": mechanism(v,rect,data,colors)
		"conveyor": conveyor(v,rect,data,colors)

static func surface(v, rect: Rect2, colors: Dictionary) -> void:
	# A chipped stone block has a dark joint, an inset face, and short edge wear.
	v.draw_rect(Rect2(rect.position+Vector2(3,5),rect.size),Color(0.02,0.02,0.035,0.4))
	v.draw_rect(rect,INK)
	v.draw_rect(rect.grow(-2),colors.stone)
	v.draw_line(rect.position+Vector2(3,3),Vector2(rect.end.x-3,rect.position.y+3),Color(colors.rim,0.65),2,true)
	v.draw_line(rect.position+Vector2(3,3),Vector2(rect.position.x+3,rect.end.y-3),Color(colors.rim,0.3),1,true)

static func wall(v, rect: Rect2, colors: Dictionary) -> void:
	surface(v,rect,colors)
	var horizontal:=rect.size.x>=rect.size.y
	var long_size:=rect.size.x if horizontal else rect.size.y
	var sections:=maxi(1,ceili(long_size/58.0))
	for i in range(sections):
		var start:=float(i)*long_size/sections
		var end:=float(i+1)*long_size/sections
		var stone:=Rect2(rect.position+Vector2(start,0) if horizontal else rect.position+Vector2(0,start),Vector2(end-start,rect.size.y) if horizontal else Vector2(rect.size.x,end-start))
		stone=stone.grow(-3)
		if not sprite(v,stone,"stone",Color.WHITE.darkened(0.05)):
			v.draw_rect(stone,Color(colors.stone).lightened(0.045 if i%3==0 else 0))
		v.draw_rect(stone,Color(INK,0.7),false,1)
		var crack:=stone.position+stone.size*Vector2(0.25+float(i%3)*0.18,0.35)
		v.draw_polyline(PackedVector2Array([crack+Vector2(-5,-5),crack,crack+Vector2(-2,8),crack+Vector2(4,12)]),Color(INK,0.38),1,true)
		v.draw_line(stone.position+Vector2(4,2),stone.position+Vector2(minf(stone.size.x-3,16),2),Color(colors.rim,0.6),2,true)
	# Sparse brass collars replace the old high-contrast pink cube stack.
	if long_size>110:
		for fraction in [0.12,0.88]:
			var p:=rect.position+(Vector2(long_size*fraction,rect.size.y*0.5) if horizontal else Vector2(rect.size.x*0.5,long_size*fraction))
			var half:=Vector2(4,maxf(2,rect.size.y*0.5-4)) if horizontal else Vector2(maxf(2,rect.size.x*0.5-4),4)
			v.draw_rect(Rect2(p-half,half*2),Color(colors.rim).darkened(0.28))
			v.draw_circle(p,2,Color(colors.light,0.6))

static func gate(v, rect: Rect2, data: Dictionary, colors: Dictionary) -> void:
	if str(data.get("type",""))!="one_way" and float(data.get("hp",0))<=0:
		for offset in [-1.0,1.0]:
			var p:=rect.get_center()+Vector2(offset*rect.size.x*0.36,0)
			v.draw_line(p-Vector2(4,9),p+Vector2(5,8),Color(colors.rim,0.65),4,true)
		return
	v.draw_rect(rect,Color(INK,0.75))
	var horizontal:=rect.size.x>=rect.size.y
	var length:=rect.size.x if horizontal else rect.size.y
	var thickness:=minf(rect.size.y if horizontal else rect.size.x,length*89.0/522.0)
	v.draw_set_transform(rect.get_center(),0 if horizontal else PI*0.5)
	var drawn:=sprite(v,Rect2(Vector2(-length,-thickness)*0.5,Vector2(length,thickness)),"gate")
	v.draw_set_transform(Vector2.ZERO)
	var c:=rect.get_center()
	if not drawn:
		for step in range(7,int(length)-2,11):
			var a:=rect.position+(Vector2(step,3) if horizontal else Vector2(3,step))
			var b:=Vector2(a.x,rect.end.y-3) if horizontal else Vector2(rect.end.x-3,a.y)
			v.draw_line(a,b,INK,6,true)
			v.draw_line(a,b,colors.rim,3,true)
			v.draw_line(a,b,Color(colors.light,0.3),1,true)
		v.draw_circle(c,7,INK)
		v.draw_circle(c,4,Color("#b2966b"))
	var hp:=clampf(float(data.get("hp",1))/maxf(1,float(data.get("max_hp",1))),0,1)
	if hp<0.99:
		v.draw_rect(Rect2(c+Vector2(-20,rect.size.y*0.5+5),Vector2(40,3)),INK)
		v.draw_rect(Rect2(c+Vector2(-20,rect.size.y*0.5+5),Vector2(40*hp,3)),colors.light)

static func water(v, rect: Rect2, colors: Dictionary) -> void:
	v.draw_rect(rect,Color(colors.water,0.86))
	sprite(v,rect,"water",Color(0.85,0.92,0.98))
	v.draw_rect(rect.grow(-2),Color(colors.rim,0.16),false,2)
	for i in range(maxi(3,int(rect.size.x/48))):
		var x:=rect.position.x+14+fposmod(float(i)*51+v.clock*3,maxf(1,rect.size.x-28))
		var y:=rect.position.y+8+fposmod(float(i)*19,maxf(1,rect.size.y-16))
		v.draw_line(Vector2(x,y),Vector2(minf(x+15,rect.end.x-3),y),Color(colors.light,0.12),1,true)
	# A dark worn shore makes the traversable shallow region readable without a neon box.
	v.draw_line(rect.position,Vector2(rect.end.x,rect.position.y),Color(INK,0.42),3,true)

static func platform(v, rect: Rect2, colors: Dictionary) -> void:
	surface(v,rect,colors)
	sprite(v,rect,"stone",Color(1.0,0.98,0.9))
	v.draw_rect(rect.grow(-5),Color(colors.rim,0.2),false,1)
	var c:=rect.get_center()
	var r:=minf(rect.size.x,rect.size.y)*0.24
	v.draw_arc(c,r,0,TAU,32,Color(colors.light,0.2),1,true)
	for angle in [0.0,PI*0.5,PI,PI*1.5]:
		var d:=Vector2.from_angle(angle)
		v.draw_line(c+d*r*0.72,c+d*r*1.17,Color(colors.light,0.28),2,true)

static func trap(v, rect: Rect2, data: Dictionary, colors: Dictionary) -> void:
	surface(v,rect,colors)
	var interval:=maxf(0.01,float(data.get("interval",4)))
	var charge:=1-clampf(float(data.get("timer",interval))/interval,0,1)
	if sprite(v,rect,"trap"):
		if charge>0.7: v.draw_rect(rect.grow(-3),Color(0.95,0.27,0.35,(charge-0.7)*0.65),false,2)
		return
	v.draw_rect(rect.grow(-5),Color("#1c151f"))
	for x in range(10,int(rect.size.x)-5,16):
		for y in range(10,int(rect.size.y)-5,18):
			var p:=rect.position+Vector2(x,y)
			v.draw_circle(p,4,INK)
			v.draw_colored_polygon(PackedVector2Array([p+Vector2(-2,2),p+Vector2(0,-3-4*charge),p+Vector2(2,2)]),Color(colors.rim).lerp(Color("#e28d82"),charge))
	if charge>0.7:
		v.draw_rect(rect.grow(-3),Color(0.95,0.27,0.35,(charge-0.7)*0.65),false,2)

static func mechanism(v, rect: Rect2, data: Dictionary, colors: Dictionary) -> void:
	platform(v,rect,colors)
	var c:=rect.get_center()
	var r:=minf(rect.size.x,rect.size.y)*0.29
	v.draw_circle(c,r,INK)
	v.draw_circle(c,r-3,colors.stone)
	for i in 8:
		var d:=Vector2.from_angle(i*TAU/8+v.clock*0.15)
		v.draw_line(c+d*(r-4),c+d*(r+3),colors.rim,4,true)
	v.draw_circle(c,5,Color("#b3d7c8"))
	var interval:=maxf(0.01,float(data.get("interval",4)))
	var charge:=1-clampf(float(data.get("timer",interval))/interval,0,1)
	v.draw_arc(c,r-7,-PI*0.5,-PI*0.5+TAU*charge,30,Color("#8bb9a8"),2,true)

static func conveyor(v, rect: Rect2, data: Dictionary, colors: Dictionary) -> void:
	# Recessed rollers follow the old displacement footprint without a solid slab.
	v.draw_rect(rect,Color(INK,0.20))
	var raw: Array=data.get("direction",[-1.0,0.0])
	var direction:=Vector2(float(raw[0]),float(raw[1])).normalized()
	var horizontal:=absf(direction.x)>=absf(direction.y)
	var length:=rect.size.x if horizontal else rect.size.y
	var width:=rect.size.y if horizontal else rect.size.x
	var side:=direction.orthogonal()
	var start:=rect.get_center()-direction*length*0.5
	for fraction in [0.1,0.9]:
		var center:Vector2=start+direction*length*fraction
		FunctionalArt._sprite(v,"wind_lane",Rect2(center-Vector2(25,14),Vector2(50,28)),direction.angle(),Color(0.9,0.85,0.73))
	for offset in [-1.0,1.0]:
		v.draw_dashed_line(start+side*width*0.45*offset,start+direction*length+side*width*0.45*offset,Color(colors.rim,0.32),1,15,true)
	var motion:float=0.0 if v.reduced_effects else float(v.clock)*20.0
	for i in maxi(1,floori(length/38.0)):
		var c:=start+direction*(fposmod(i*38.0+motion,maxf(1,length-18))+9)
		FunctionalArt._arrow(v,c,direction,Color(colors.light,0.35),4)
