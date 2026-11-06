extends RefCounted
## One quiet floor surface; cover geometry shares the collision profile.
const PROFILE = preload("res://data/stage_profiles/endless_arena_profile.gd")
const FLOOR = preload("res://assets/world/endless_20261006/arena_floor.png")

static func draw(v) -> void:
	v.draw_rect(Rect2(0,0,1280,720),Color("111217"))
	var target := Rect2(v.world_to_screen(PROFILE.ARENA.position),PROFILE.ARENA.size)
	v.draw_texture_rect(FLOOR,target,false,Color("dadfe1"))
	# This rim is the real arena boundary, never an interior false obstacle.
	v.draw_rect(target.grow(-6),Color("0c0d10"),false,12)
	v.draw_rect(target.grow(-15),Color("63504d"),false,2)

static func wall(v,r: Rect2,block_index: int = 0,opacity: float = 1.0) -> void:
	if not Rect2(-140,-140,1560,1000).intersects(r): return
	var horizontal := r.size.x >= r.size.y
	var height := 50.0
	var top := r.position-Vector2(0,height)
	var bottom := Vector2(r.position.x,r.end.y-height)
	var right_top := Vector2(r.end.x,r.position.y-height)
	var right_bottom := r.end-Vector2(0,height)
	var shadow := Rect2(r.position+Vector2(5,10),r.size+Vector2(14,10))
	v.draw_rect(shadow,Color(0,0,0,.28*opacity))
	v.draw_rect(r.grow(3),Color("101217",opacity))
	var front := PackedVector2Array([bottom,right_bottom,r.end,Vector2(r.position.x,r.end.y)])
	masonry(v,front,Color(.95,1.0,1.08,opacity),Rect2(230,130,90,50))
	v.draw_colored_polygon(PackedVector2Array([right_top,right_top+Vector2(8,8),r.end+Vector2(8,0),r.end,right_bottom]),Color("1c2129",opacity))
	var cap := PackedVector2Array([top+Vector2(7,0),right_top-Vector2(7,0),right_top+Vector2(0,7),right_bottom-Vector2(0,5),bottom+Vector2(0,-5),top+Vector2(0,7)])
	masonry(v,cap,Color(1.5,1.6,1.7,opacity),Rect2(260,180,90,50))
	v.draw_polyline(PackedVector2Array([bottom,right_bottom,r.end,Vector2(r.position.x,r.end.y),bottom]),Color("0c1016",opacity),3,true)
	var closed := cap.duplicate(); closed.append(cap[0])
	v.draw_polyline(closed,Color("10141b",opacity),3,true)
	v.draw_line(bottom+Vector2(4,-4),right_bottom-Vector2(4,4),Color("89909a",opacity),2,true)
	# A stout inset strap reads as solid cover, rather than a floor tile.
	if horizontal:
		var middle := r.get_center().x
		v.draw_rect(Rect2(middle-6,r.end.y-height+3,12,height-8),Color("22262d",opacity))
		v.draw_rect(Rect2(middle-3,r.end.y-height+7,6,12),Color("916657",opacity))
	else:
		var middle := r.get_center().y-height
		v.draw_line(Vector2(r.position.x+3,middle),Vector2(r.end.x-3,middle),Color("373e47",opacity),4,true)
	if block_index % 2 == 0:
		v.draw_colored_polygon(PackedVector2Array([top+Vector2(12,14),top+Vector2(28,11),top+Vector2(33,17),top+Vector2(20,21)]),Color("535a65",opacity))

static func masonry(v,points: PackedVector2Array,color: Color,source: Rect2) -> void:
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum=minimum.min(point); maximum=maximum.max(point)
	var extent := (maximum-minimum).max(Vector2.ONE)
	var uvs := PackedVector2Array()
	for point: Vector2 in points:
		uvs.append((source.position+(point-minimum)/extent*source.size)/FLOOR.get_size())
	v.draw_polygon(points,PackedColorArray([color]),uvs,FLOOR)
