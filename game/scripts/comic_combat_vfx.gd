extends RefCounted
## Cosmetic accents only. No damage, timers or random calls enter the simulation.
## Fixed-size recycled dictionaries also bound burst-heavy endless combat.
const VisualScale = preload("res://scripts/battle_visual_scale.gd")
const Pool = preload("res://scripts/reusable_effect_pool.gd")
const Flash = preload("res://scripts/impact_flash_vfx.gd")
const CartoonExplosion = preload("res://scripts/cartoon_explosion_vfx.gd")
const INK := Color("#130e20")
const PAPER := Color("#fff9df")
const HOT := Color("#ff4168")
const MAX_ACCENTS := 72
const REDUCED_ACCENTS := 28
var accents: Array[Dictionary] = []
var pool = Pool.new()
var sequence := 0
var hitstop_request := 0.0
var hitstop_cooldown := 0.0

func advance(dt: float) -> void:
	hitstop_cooldown = maxf(0.0, hitstop_cooldown - dt)
	for i in range(accents.size() - 1, -1, -1):
		accents[i].life = float(accents[i].life) - dt
		if float(accents[i].life) <= 0.0:
			pool.release(accents[i])
			accents.remove_at(i)

func reset() -> void:
	for accent in accents:
		pool.release(accent)
	accents.clear()
	hitstop_request = 0.0
	hitstop_cooldown = 0.0

func consume_hitstop_request() -> float:
	var duration := hitstop_request
	hitstop_request = 0.0
	return duration

func accept(v, event: Dictionary) -> void:
	if bool(event.get("bug_blast", false)):
		return # The volatile insect owns one dedicated blast, not two superimposed flashes.
	if not event.has("pos") or not v._render_point_visible(Vector2(event.pos), 150.0):
		return
	var kind := str(event.get("kind", ""))
	if kind == "death" and str(event.get("enemy_kind", "")) == "originium_bug":
		return # Its single explosion follows the dedicated one-second fuse and warning.
	if kind == "death" and str(event.get("enemy_kind", "")) in VisualScale.ORIGINAL_DOWN_ONLY:
		return # These actors finish through their original down atlas only.
	var lifetime := 0.0
	var weight := 1.0
	var pause := 0.0
	match kind:
		"hit": lifetime = 0.22
		"hurt":
			lifetime = 0.22
			weight = 0.72
		"critical":
			lifetime = 0.34
			weight = 1.55
			pause = 0.027
		"death":
			lifetime = 0.64
			weight = clampf(float(event.get("size", 48.0)) / 48.0, 0.75, 1.8)
			pause = 0.018
		"enemy_volatile", "death_burst", "shield_break", "geo_break":
			lifetime = 0.60
			weight = 1.50
			pause = 0.038
		"ultimate_impact", "galio_punch", "slime_bounce_hit", "fireball_impact":
			lifetime = 0.50
			weight = 1.7
			pause = 0.045
		"chain", "electro_charged", "overloaded", "shatter":
			lifetime = 0.24
			weight = 1.25
		"enemy_shot":
			if bool(event.get("physical", false)):
				lifetime = 0.18
		_: return
	if lifetime <= 0.0:
		return
	if pause > 0.0 and hitstop_cooldown <= 0.0:
		hitstop_request = maxf(hitstop_request, pause)
		hitstop_cooldown = 0.18
	# Merge coincident damage hits, never genuine warnings or moving projectiles.
	if kind == "hit":
		for i in range(accents.size() - 1, maxi(-1, accents.size() - 9), -1):
			var recent := accents[i]
			if str(recent.kind) == kind and float(recent.life) > lifetime - 0.05 and Vector2(recent.pos).distance_squared_to(Vector2(event.pos)) < 484.0:
				return
	var limit: int = REDUCED_ACCENTS if v.reduced_effects else MAX_ACCENTS
	while accents.size() >= limit:
		pool.release(accents[0])
		accents.remove_at(0)
	sequence += 1
	accents.append(pool.acquire({"kind":kind, "pos":Vector2(event.pos), "weight":weight,
		"element":str(event.get("element", "electro" if kind in ["chain", "electro_charged"] else "")),
		"seed":sequence, "enemy_kind":str(event.get("enemy_kind", ""))}, lifetime))

func draw_accents(v) -> void:
	for accent in accents:
		if not v._render_point_visible(Vector2(accent.pos), 150.0):
			continue
		var t := clampf(1.0 - float(accent.life) / float(accent.total), 0.0, 1.0)
		var p: Vector2 = v.world_to_screen(Vector2(accent.pos)) + Vector2(0, -20)
		var size := float(accent.weight) * float(v.world_depth_scale(Vector2(accent.pos)))
		var color: Color = v.element_color(str(accent.element))
		var seed := int(accent.seed)
		match str(accent.kind):
			"death", "enemy_volatile", "death_burst":
				CartoonExplosion.burst(v, p, float(accent.total) - float(accent.life), size, seed, v.reduced_effects)
			"chain", "electro_charged":
				for branch in (2 if v.reduced_effects else 3):
					var angle := float(branch) * TAU / 3.0 + float(seed) * 1.7
					var d := Vector2.from_angle(angle)
					lightning(v, p - d * 5.0, p + d * (14.0 + t * 19.0), color, pow(1.0 - t, 1.8), t * 0.24, seed + branch, 0.58)
			_: impact(v, p, minf(1, (float(accent.total) - float(accent.life)) / 0.28), size, color, seed, str(accent.kind) == "critical")

static func polygon(v, points: PackedVector2Array, color: Color, width: float = 3.0) -> void:
	if points.size() < 3 or color.a < 0.01:
		return
	v.draw_colored_polygon(points, color)
	var edge := points.duplicate()
	edge.append(points[0])
	v.draw_polyline(edge, Color(color.lightened(0.32), color.a * 0.55), minf(width, 1.3), true)

static func star(v, center: Vector2, radius: float, color: Color, rotation: float = 0.0, points: int = 4) -> void:
	if radius < 0.7 or color.a < 0.02:
		return
	var outline := PackedVector2Array()
	for i in points * 2:
		var r := radius if i % 2 == 0 else radius * 0.27
		outline.append(center + Vector2.from_angle(rotation + float(i) * PI / float(points)) * r)
	polygon(v, outline, color, 2.0)

static func light(v, point: Vector2, size: Vector2, color: Color, alpha: float = 1.0, rotation: float = 0.0) -> void:
	if v.light_layer != null:
		v.light_layer.glow(point, size, color, alpha, rotation)

static func impact(v, p: Vector2, t: float, size: float, color: Color, seed: int, critical: bool = false) -> void:
	# ~0.08 seconds of white ignition, followed by short accelerating fragments.
	var flash := 1.0 - smoothstep(0.10, 0.34, t)
	var fade := pow(maxf(0, 1.0 - t), 1.7)
	var opening := 1.0 - pow(1.0 - t, 4)
	var scale := size * (1.25 if critical else 1.0)
	light(v, p, Vector2.ONE * 68 * scale, color, flash * 0.9)
	light(v, p, Vector2.ONE * 27 * scale, Color.WHITE, flash * 2.2)
	if flash > 0.01:
		v.draw_circle(p, (3.0 + opening * 8.0) * scale, Color(Color.WHITE, flash))
		v.draw_line(p - Vector2(11, 0) * scale, p + Vector2(11, 0) * scale, Color(Color.WHITE, flash), 1.8, true)
	for i in (8 if critical else 5):
		var angle := float(seed % 13) * 0.49 + float(i) * 2.399
		var direction := Vector2.from_angle(angle)
		var head := p + direction * scale * (7 + opening * (25 + i % 3 * 8))
		var tail := head - direction * (3 + fade * 10) * scale
		v.draw_line(tail, head, Color(color, fade * 0.65), 3.5 * fade + 0.6, true)
		v.draw_line(tail.lerp(head, 0.25), head, Color(Color.WHITE, fade), 1.1, true)
		if i < 3: light(v, head, Vector2.ONE * 14 * scale, color, fade * 0.5)

static func burst(v, p: Vector2, t: float, size: float, color: Color, seed: int, reduced: bool = false) -> void:
	Flash.burst(v,p,clampf(t,0,1)*0.48,size,color,seed,reduced)

static func lightning(v, a: Vector2, b: Vector2, color: Color, alpha: float, age: float, seed: int = 0, thickness: float = 1.0) -> void:
	if alpha < 0.01 or a.distance_squared_to(b) < 4.0:
		return
	var direction := b - a
	var normal := direction.orthogonal().normalized()
	var tick := floori(age * 32.0)
	var count := clampi(ceili(direction.length() / 18.0), 4, 22)
	var path := PackedVector2Array()
	for i in count + 1:
		var fraction := float(i) / float(count)
		var jitter := sin(float(i * 17 + seed * 13 + tick * 7)) * sin(fraction * PI) * minf(12.0, direction.length() * 0.12)
		path.append(a + direction * fraction + normal * jitter)
	var pulse := 0.68 + 0.32 * absf(sin(age * 71.0 + float(seed)))
	v.draw_polyline(path, Color(color, alpha * 0.10), 12.0 * thickness, true)
	v.draw_polyline(path, Color(color, alpha * 0.24), 6.0 * thickness, true)
	v.draw_polyline(path, Color(color, alpha * pulse), 2.6 * thickness, true)
	v.draw_polyline(path, Color(Color.WHITE, alpha * pulse), 1.05 * thickness, true)
	light(v, b, Vector2.ONE * 43 * thickness, color, alpha * 0.55)
	if not v.reduced_effects:
		for index in [maxi(1, count / 3), maxi(1, count * 2 / 3)]:
			var origin := path[index]
			var tip := origin + normal * (-1 if index % 2 else 1) * (10 + posmod(seed + tick, 3) * 5) + direction.normalized() * 11
			var branch := PackedVector2Array([origin, origin.lerp(tip, 0.52) - direction.normalized() * 4, tip])
			v.draw_polyline(branch, Color(color, alpha * 0.38), 3.3 * thickness, true)
			v.draw_polyline(branch, Color(Color.WHITE, alpha * 0.78), 0.8 * thickness, true)
			light(v, origin, Vector2.ONE * 29 * thickness, color, alpha * 0.18)

static func orb(v, point: Vector2, direction: Vector2, radius: float, color: Color, motion: float, hostile: bool = false) -> void:
	var d := direction.normalized() if direction.length_squared() > 0.01 else Vector2.LEFT
	var side := d.orthogonal()
	var r := radius * (1.0 + sin(motion * 17.0) * 0.025)
	light(v, point, Vector2.ONE * r * 6, color, 0.8)
	light(v, point - d * r * 1.4, Vector2(r * 5, r * 1.9), color, 0.48, d.angle())
	# Transparent spherical water body, saturated thin rim and asymmetric highlight.
	v.draw_circle(point, r, Color(color, 0.46))
	v.draw_arc(point, r * 0.88, -2.6, 0.8, 18, Color(color.lightened(0.42), 0.85), 1.3, true)
	v.draw_circle(point - d * r * 0.13, r * (0.36 if not hostile else 0.48), Color.WHITE)
	v.draw_circle(point + Vector2(-0.31, -0.39) * r, r * 0.22, Color.WHITE)
	for i in (1 if v.reduced_effects else 3):
		var offset := 1.9 + i * 0.75 + fposmod(motion * 2 + i * 0.24, 1) * 0.4
		var drop := point - d * r * offset + side * sin(motion * 8 + i) * r * 0.18
		v.draw_circle(drop, maxf(0.8, r * (0.21 - i * 0.045)), Color(color.lightened(0.55), 0.68 - i * 0.15))

static func portal(v, point: Vector2, radius: float, color: Color, motion: float, alpha: float, spawned_age: float = -1.0) -> void:
	Flash.rift(v,point,radius,color,motion,alpha,spawned_age)
