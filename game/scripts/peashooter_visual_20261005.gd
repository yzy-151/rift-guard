extends RefCounted
## The drawing and released projectile share one source-image mouth landmark.
const TEXTURE = preload("res://assets/world/battle_devices_20261005/peashooter_flat_v2.png")
const SOURCE := Rect2(106,138,1031,1046)
const FOOT := Vector2(615,1183)
const MOUTH := Vector2(999,494)
const UNIT := 62.0 / 1046.0
const GROUND := Vector2(0,8)

static func pose(time: float, pulse: float, shoot_age: float = -1.0) -> Dictionary:
	var age := shoot_age if shoot_age>=0.0 else .18-pulse if pulse>0.0 else 999.0
	var beat := clampf(age/.50,0.0,1.0)
	# One shot gives one clear recoil, counter-swing, then a soft return to rest.
	var swing := -sin(beat*TAU)*.16*pow(1.0-beat,1.3)
	var squeeze := sin(beat*PI)*.028*(1.0-beat)
	return {"angle":sin(time*2.6)*.010+swing,"stretch":Vector2(1.0+squeeze,1.0-squeeze*.5+sin(time*2.6)*.004)}

static func mouth_local(time: float, pulse: float, shoot_age: float = -1.0) -> Vector2:
	var state := pose(time,pulse,shoot_age)
	return GROUND+((MOUTH-FOOT)*UNIT*Vector2(state.stretch)).rotated(float(state.angle))

static func mouth_screen(v, origin: Vector2, time: float, pulse: float, shoot_age: float = -1.0) -> Vector2:
	return v.world_to_screen(origin)+mouth_local(time,pulse,shoot_age)*v.world_depth_scale(origin)

static func shot_screen(v, shot: Dictionary, at: Vector2 = Vector2(INF,INF)) -> Vector2:
	var origin := Vector2(shot.get("visual_origin",shot.pos))
	var start := Vector2(shot.get("model_origin",origin))
	var current := at if at.is_finite() else Vector2(shot.pos)
	return mouth_screen(v,origin,float(shot.get("visual_time",0)),float(shot.get("muzzle_pulse",.18)),float(shot.get("shoot_age",-1)))+v.world_to_screen(current)-v.world_to_screen(start)

static func draw(v, device: Dictionary) -> void:
	var point: Vector2=v.world_to_screen(device.pos)
	var depth: float=v.world_depth_scale(device.pos)
	var state := pose(float(device.get("visual_time",0)),float(device.get("pulse",0)),float(device.get("shoot_age",-1)))
	# Ground stays fixed while the stem makes a small spring motion.
	v.draw_ellipse_shadow(point+GROUND*depth-Vector2(0,9),24.0*depth,Color(.025,.03,.05,.40))
	v.draw_ellipse_shadow(point+GROUND*depth-Vector2(0,9),14.0*depth,Color(.025,.03,.05,.24))
	v.draw_set_transform(point+GROUND*depth,float(state.angle),Vector2(state.stretch)*depth)
	v.draw_texture_rect_region(TEXTURE,Rect2((SOURCE.position-FOOT)*UNIT,SOURCE.size*UNIT),SOURCE)
	v.draw_set_transform(Vector2.ZERO)
