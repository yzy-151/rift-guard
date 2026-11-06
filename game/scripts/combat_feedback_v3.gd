extends RefCounted
## Compact white cores, directional silhouettes and short sparks keep units readable.
const ORB_GLOW = preload("res://assets/vfx/combat_20261005/orb_glow.png")
const SHOT_GLOW = preload("res://assets/vfx/combat_20261005/shot_glow.png")
const ARROW_CORE = preload("res://assets/vfx/combat_20261005/arrow_core.png")
const ORB_CORE = preload("res://assets/vfx/combat_20261005/orb_core.png")
const BOLT_CORE = preload("res://assets/vfx/combat_20261005/bolt_core.png")
const FLARE = preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")
const FILLED_IMPACT = preload("res://scripts/explosion_vfx_20261005.gd")

static func projectile(view, shot: Dictionary, history: Array, friendly: bool) -> void:
	var world: Vector2 = shot.pos
	var point: Vector2 = view.world_to_screen(world) + Vector2(0, -18)
	var direction: Vector2 = Vector2(shot.get("direction", Vector2.LEFT if not friendly else Vector2.RIGHT))
	if not bool(shot.get("ballistic", false)) and shot.has("target"):
		direction = Vector2(shot.target) - world
	elif not bool(shot.get("ballistic", false)):
		if shot.has("previous_pos") and Vector2(shot.previous_pos).distance_squared_to(world) > 0.01:
			direction = world - Vector2(shot.previous_pos)
		else:
			var target_id := int(shot.get("target_id", -1))
			if target_id >= 0 and target_id < view.sim.heroes.size(): direction = Vector2(view.sim.heroes[target_id].pos) - world
	direction = (view.world_to_screen(world + direction.normalized() * 16.0) - view.world_to_screen(world)).normalized()
	if direction.length_squared() < 0.1: direction = Vector2.RIGHT
	var kind := str(shot.get("visual_kind", "orb"))
	var color: Color = view.element_color(str(shot.get("element", ""))) if friendly else Color("#ed70ff")
	if friendly and str(shot.get("element", "")) == "": color = Color("#9ff3ff")
	if not friendly and kind == "arrow": color = Color("#ffc878")
	var lean: bool = view.reduced_effects or (view.sim.projectiles.size() + view.sim.enemy_projectiles.size()) > 110
	var trail := PackedVector2Array()
	for index in range(maxi(0, history.size() - (3 if lean else 5)), history.size()):
		trail.append(view.world_to_screen(Vector2(history[index])) + Vector2(0, -18))
	if trail.size() < 2:
		trail = PackedVector2Array([point - direction * 22.0, point])
	# The tail ends at the real body; it never flies toward a second animated endpoint.
	if trail.size() > 1:
		if not lean: view.draw_polyline(trail, Color(color, 0.14), 6.0, true)
		view.draw_polyline(trail, Color(color.lightened(0.55), 0.57), 1.2, not lean)
	view.draw_set_transform(point, direction.angle())
	if kind == "orb":
		if not lean:
			if view.has_method("emit_glow"): view.emit_glow(ORB_GLOW,point,Vector2(46,46),color,.9)
			else: view.draw_texture_rect(ORB_GLOW, Rect2(-23,-23,46,46), false, Color(color,0.90))
		view.draw_texture_rect(ORB_CORE, Rect2(-13,-13,26,26), false, Color(color.lightened(0.65),0.97))
		if not lean:
			view.draw_line(Vector2(-5,0),Vector2(5,0),Color(1,1,1,0.90),1.6,true)
			view.draw_line(Vector2(0,-5),Vector2(0,5),Color(1,1,1,0.90),1.6,true)
	else:
		if not lean:
			if view.has_method("emit_glow"): view.emit_glow(ORB_GLOW,point,Vector2(45,32),color,.72)
			else: view.draw_texture_rect(SHOT_GLOW,Rect2(-34,-12,68,24),false,Color(color,0.72))
		var body: Texture2D = ARROW_CORE if kind == "arrow" else BOLT_CORE
		view.draw_texture_rect(body,Rect2(-25,-9,50,18),false,Color(color.lightened(0.86),1.0))
	view.draw_set_transform(Vector2.ZERO)
	if not lean:
		var side := direction.orthogonal()
		var phase: float = view.clock * 8.0 + float(shot.get("visual_id",0))
		for index in 2:
			var mote := point - direction * (15.0 + index * 9.0) + side * sin(phase + index * 2.3) * 3.0
			view.draw_circle(mote, 1.2, Color(color.lightened(0.6), 0.62 - index * 0.22))

static func burst(target: CanvasItem, point: Vector2, color: Color, progress: float, strength: float = 1.0, lean: bool = false, seed: float = 0.0, glow_screen: Vector2 = Vector2(INF,INF)) -> void:
	FILLED_IMPACT.impact(target,point,color,progress,strength,lean,seed,glow_screen)

static func local_event(view, event: Dictionary, progress: float) -> void:
	var kind := str(event.kind)
	var color: Color = view.element_color(str(event.get("element", "")))
	var point: Vector2 = event.pos + Vector2(0, -18)
	var screen_origin := Vector2(event.get("screen_origin",Vector2.ZERO))
	var screen_scale := float(event.get("screen_scale",1.0))
	if kind == "critical": color = Color("#dc244c")
	elif kind == "hurt": color = Color("#ff7975")
	elif kind == "heal": color = Color("#69ffc6")
	elif kind in ["enemy_shot", "enemy_projectile_cast"]: color = Color("#ffbe67") if str(event.get("enemy_kind", "")) == "ranged" else Color("#ff728f")
	if kind == "slash":
		var angle := float(event.get("angle", 0.0))
		var center := point + Vector2.from_angle(angle) * 13.0
		var fade := pow(1.0 - progress, 1.8)
		# Convex blade facets give the slash a filled, tapered face and white edge.
		# Its silhouette follows the swing direction, never a stationary hollow ring.
		for index in 16:
			var t0 := float(index) / 16.0
			var t1 := float(index + 1) / 16.0
			var a0 := angle - 1.15 + t0 * 2.30
			var a1 := angle - 1.15 + t1 * 2.30
			var radial0 := Vector2(cos(a0) * 49.0, sin(a0) * 30.0)
			var radial1 := Vector2(cos(a1) * 49.0, sin(a1) * 30.0)
			var edge0 := center + radial0
			var edge1 := center + radial1
			var thickness0 := 1.0 + sin(t0 * PI) * 13.0
			var thickness1 := 1.0 + sin(t1 * PI) * 13.0
			var inner0 := edge0 - radial0.normalized() * thickness0
			var inner1 := edge1 - radial1.normalized() * thickness1
			view.draw_colored_polygon(PackedVector2Array([edge0, edge1, inner1, inner0]), Color(color.lightened(.15), fade * .95))
			var core0 := edge0 - radial0.normalized() * thickness0 * .42
			var core1 := edge1 - radial1.normalized() * thickness1 * .42
			view.draw_colored_polygon(PackedVector2Array([edge0, edge1, core1, core0]), Color(1, 1, 1, fade))
			if not view.reduced_effects and index % 3 == 1 and view.has_method("emit_glow"):
				view.emit_glow(ORB_GLOW,screen_origin+(edge0+edge1)*.5*screen_scale,Vector2(43,36)*screen_scale,color,fade*.54)
	else:
		burst(view,point,color,progress,1.15 if kind=="critical" else .68,view.reduced_effects or view.sim.enemies.size()>100,float(int(event.get("enemy_id",event.get("hero_id",0)))%11)/11.0,screen_origin+point*screen_scale)
