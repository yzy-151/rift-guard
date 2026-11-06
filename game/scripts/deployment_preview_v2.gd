extends RefCounted
## Comic landing stamp and the real selected character replace the old crosshair.
const INK := Color("#10131a")
const CREAM := Color("#fff8ec")
const GOLD := Color("#ffce50")
const RED := Color("#dc244c")

static func draw(v) -> void:
	var id: int=v.deploy_preview_id
	if id<0 or id>=v.sim.heroes.size(): return
	var hero: Dictionary=v.sim.heroes[id]
	var foot: Vector2=v.world_to_screen(v.deploy_preview_point)
	var scale: float=v.world_depth_scale(v.deploy_preview_point)
	var allowed: bool=v.deploy_preview_valid
	var color := GOLD if allowed else RED
	var pad:=PackedVector2Array([foot+Vector2(-34,-5)*scale,foot+Vector2(-14,-17)*scale,foot+Vector2(33,-5)*scale,foot+Vector2(29,12)*scale,foot+Vector2(-24,14)*scale])
	v.draw_colored_polygon(pad,Color(INK,.88))
	pad.append(pad[0]);v.draw_polyline(pad,Color(CREAM,.9),2.0,true)
	var toe:=PackedVector2Array([foot+Vector2(-17,10)*scale,foot+Vector2(24,8)*scale,foot+Vector2(21,12)*scale,foot+Vector2(-15,14)*scale])
	v.draw_colored_polygon(toe,color)
	var character := str(hero.get("character_id","traveler"))
	var state := "idle"
	var textures=v.character_sequences
	if textures.has_character(character):
		var texture: Texture2D=textures.texture(character,state)
		if texture!=null:
			var size: float=textures.display_size(character)
			var frame: int=textures.frame_at_time(character,state,v.clock)
			var saved: Transform2D=v.current_actor_transform
			v.current_actor_transform=Transform2D(Vector2(scale,0),Vector2(0,scale),foot)
			v._draw_anchored_texture_region(texture,Vector2(0,8),Vector2.ONE*size,textures.cell(character),textures.pivot(character),1,1,textures.source_rect(character,state,frame),Color(1,1,1,.70 if allowed else .38))
			v.current_actor_transform=saved
			v.draw_set_transform(Vector2.ZERO)
	var label:=Rect2(foot+Vector2(-61,-143)*scale,Vector2(122,23)*scale)
	v.draw_rect(label,INK)
	v.draw_rect(Rect2(label.position+Vector2(0,2),Vector2(3,label.size.y-4)),color)
	v.caption(label.position+Vector2(10,16)*scale,("松手上场 · %d"%(id+1)) if allowed else "此处不可上场",color,12)
	if not allowed:
		var warning:=PackedVector2Array([foot+Vector2(-9,-19)*scale,foot+Vector2(1,-19)*scale,foot+Vector2(-5,-5)*scale,foot+Vector2(-12,-5)*scale])
		v.draw_colored_polygon(warning,RED)
