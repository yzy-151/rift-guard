extends RefCounted
## Original PvZ sprite animation. The leaves stay anchored while the actual frames sway.
const GROUND := Vector2(0,3)
const TEXTURES := {
	"pea":preload("res://assets/world/pvz_botany_20261005/pea.png"),
	"repeater":preload("res://assets/world/pvz_botany_20261005/repeater.png"),
	"threepeater":preload("res://assets/world/pvz_botany_20261005/threepeater.png"),
	"gatling":preload("res://assets/world/pvz_botany_20261005/gatling.png"),
	"snowpea":preload("res://assets/world/pvz_botany_20261005/snowpea.png"),
	"sunflower":preload("res://assets/world/pvz_botany_20261005/sunflower.png"),
	"potato_mine":preload("res://assets/world/pvz_botany_20261005/potato_mine.png"),
	"potato_unarmed":preload("res://assets/world/pvz_botany_20261005/potato_unarmed.png"),
	"potato_blast":preload("res://assets/world/pvz_botany_20261005/potato_blast.png"),
	"wallnut":preload("res://assets/world/pvz_botany_20261005/wallnut.png"),
	"wallnut_cracked":preload("res://assets/world/pvz_botany_20261005/wallnut_cracked.png"),
	"wallnut_broken":preload("res://assets/world/pvz_botany_20261005/wallnut_broken.png"),
	"tallnut":preload("res://assets/world/pvz_botany_20261005/tallnut.png"),
	"spikeweed":preload("res://assets/world/pvz_botany_20261005/spikeweed.png"),
	"cherry":preload("res://assets/world/pvz_botany_20261005/cherry.png"),
	"melon":preload("res://assets/world/pvz_botany_20261005/melon.png"),
	"melon_shoot":preload("res://assets/world/pvz_botany_20261005/melon_shoot.png"),
}
static var _manifest: Dictionary = {}
static var _metal: Dictionary = {}

static func _key(key: String) -> String:
	match key:
		"mine", "potato": return "potato_mine"
		"barricade", "iron_nut": return "wallnut"
		"snow_pea": return "snowpea"
		"cherrybomb": return "cherry"
	return key if TEXTURES.has(key) else "pea"

static func metadata(key: String) -> Dictionary:
	if _manifest.is_empty():
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/pvz_botany_20261005/manifest.json"))
		if data is Dictionary: _manifest = data.get("plants",{})
	return _manifest.get(_key(key),{})

static func frame_at(key: String, time: float) -> int:
	var info := metadata(key)
	var remaining := fposmod(time,maxf(.001,float(info.get("period",1))))
	var durations: Array = info.get("duration_ms",[100])
	for i in durations.size():
		remaining -= float(durations[i])*.001
		if remaining < .000001: return i
	return maxi(0,durations.size()-1)

static func frame_region(key: String, time: float) -> Rect2:
	var info := metadata(key)
	var size_data: Array = info.get("cell",[71,71])
	var cell := Vector2(float(size_data[0]),float(size_data[1]))
	var frame := frame_at(key,time)
	var columns := int(info.get("columns",info.get("frames",1)))
	return Rect2(Vector2((frame%columns)*cell.x,floori(float(frame)/columns)*cell.y),cell)

static func mouth_local(key: String, time: float, lane: int = 0) -> Vector2:
	var resolved := _key(key)
	var info := metadata(resolved)
	var foot_data: Array = info.get("foot",[35,69])
	var foot := Vector2(float(foot_data[0]),float(foot_data[1]))
	var all_mouths: Array = info.get("mouths",[])
	var mouth := Vector2(foot.x+24,foot.y-45)
	if not all_mouths.is_empty():
		var mouths: Array = all_mouths[frame_at(resolved,time)]
		if not mouths.is_empty():
			var index := clampi(lane+1,0,2) if resolved=="threepeater" else 0
			var point: Array = mouths[mini(index,mouths.size()-1)]
			mouth=Vector2(float(point[0]),float(point[1]))
	return GROUND+(mouth-foot)*float(info.get("unit",.9))

static func mouth_screen(v, origin: Vector2, key: String, time: float, lane: int = 0) -> Vector2:
	return v.world_to_screen(origin)+mouth_local(key,time,lane)*v.world_depth_scale(origin)

static func melon_shoot_time(age: float) -> float:
	return (float(metadata("melon_shoot").get("release_frame",13))+clampf(age/.70,0.0,1.0)*24.0)/12.0

static func melon_release_screen(v, origin: Vector2) -> Vector2:
	# The source melon disappears at this throwing frame; use its last authored basket position.
	return mouth_screen(v,origin,"melon_shoot",melon_shoot_time(0.0))

static func shot_screen(v, shot: Dictionary, at: Vector2 = Vector2(INF,INF)) -> Vector2:
	var origin := Vector2(shot.get("visual_origin",shot.pos))
	var start := Vector2(shot.get("model_origin",origin))
	var current := at if at.is_finite() else Vector2(shot.pos)
	var key := str(shot.get("visual_variant","pea"))
	var time := float(shot.get("visual_time",0))
	var lane := int(shot.get("muzzle_lane",0))
	var release := mouth_screen(v,origin,key,time,lane)
	var translated: Vector2 = release+v.world_to_screen(current)-v.world_to_screen(start)
	if _key(key)=="threepeater":
		# Launch at the painted head, then join its own world lane, not the middle lane.
		var distance := maxf(0,float(current.x)-float(start.x))
		var blend := smoothstep(0,70,distance)
		var row_screen: Vector2 = v.world_to_screen(current)+Vector2(0,mouth_local("pea",time).y)*v.world_depth_scale(current)
		return translated.lerp(row_screen,blend)
	return translated

static func _silver(texture: Texture2D, key: String) -> Texture2D:
	if not _metal.has(key):
		var image := _metal_image(texture.get_image())
		_metal[key]=ImageTexture.create_from_image(image)
	return _metal[key]

static func _metal_image(source: Image) -> Image:
	var image: Image=source.duplicate()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x,y)
			if color.a<.01: continue
			var light := color.r*.30+color.g*.59+color.b*.11
			image.set_pixel(x,y,Color(light*.86,light*.95,minf(1,light*1.10+.03),color.a))
	return image

static func _actor_key(device: Dictionary, requested: String) -> String:
	var key := requested if not requested.is_empty() else str(device.get("visual_variant",device.get("variant",device.get("kind","pea"))))
	if device.get("kind","")=="mine":
		key="potato_mine" if bool(device.get("armed",false)) else "potato_unarmed"
	if key in ["wallnut","iron_nut","barricade"]:
		var ratio := float(device.get("hp",1))/maxf(1,float(device.get("max_hp",1)))
		key="wallnut" if ratio>.66 else "wallnut_cracked" if ratio>.33 else "wallnut_broken"
	return _key(key)

static func draw(v, device: Dictionary, requested: String = "") -> void:
	var key := _actor_key(device,requested)
	var info := metadata(key)
	var time := float(device.get("visual_time",0))
	var age := float(device.get("shoot_age",999))
	# The original throw visibly follows the melon release, then restores its basket.
	if key=="melon" and age<.70:
		key="melon_shoot"
		info=metadata(key)
		time=melon_shoot_time(age)
	var point: Vector2 = v.world_to_screen(device.pos)
	var depth: float = v.world_depth_scale(device.pos)
	var foot_data: Array = info.get("foot",[35,69])
	var foot := Vector2(float(foot_data[0]),float(foot_data[1]))
	var region := frame_region(key,time)
	var unit := float(info.get("unit",.9))*depth
	var shadow := float(info.get("shadow_radius",24))*depth
	v.draw_ellipse_shadow(point+GROUND*depth-Vector2(0,9),shadow,Color(.025,.03,.05,.42))
	v.draw_ellipse_shadow(point+GROUND*depth-Vector2(0,9),shadow*.58,Color(.025,.03,.05,.24))
	var texture: Texture2D = TEXTURES[key]
	var iron := str(device.get("visual_variant",device.get("variant","")))=="iron_nut" or bool(device.get("iron",false))
	if iron and key.begins_with("wallnut"): texture=_silver(texture,key)
	v.draw_texture_rect_region(texture,Rect2(point+GROUND*depth-foot*unit,region.size*unit),region)
	if iron and key.begins_with("wallnut"):
		for offset: Vector2 in [Vector2(-17,-35),Vector2(17,-35),Vector2(-16,-11),Vector2(16,-11)]:
			v.draw_circle(point+offset*depth,1.7*depth,Color("#19222d"))
			v.draw_circle(point+(offset+Vector2(-.4,-.4))*depth,.7*depth,Color("#e7f7ff"))

static func draw_icon(canvas, key: String, rect: Rect2) -> void:
	var resolved := _key(key)
	var info := metadata(resolved)
	var region := frame_region(resolved,0)
	var bounds_data: Array = info.get("alpha_bounds",[0,0,region.size.x,region.size.y])
	var bounds := Rect2(float(bounds_data[0]),float(bounds_data[1]),float(bounds_data[2])-float(bounds_data[0]),float(bounds_data[3])-float(bounds_data[1]))
	var unit := minf(rect.size.x/maxf(1,bounds.size.x),rect.size.y/maxf(1,bounds.size.y))
	var destination := Rect2(rect.get_center()-bounds.size*unit*.5,bounds.size*unit)
	var texture: Texture2D=TEXTURES[resolved]
	if key=="iron_nut":texture=_silver(texture,resolved)
	canvas.draw_texture_rect_region(texture,destination,bounds)
