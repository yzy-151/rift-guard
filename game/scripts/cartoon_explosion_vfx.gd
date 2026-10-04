extends RefCounted
## Painted explosion only: a squashed ignition, heavy smoke curls, then detached wisps.
## Fixed four overlapping clouds, two curls and three flecks, at most 24 points per contour.
## No nodes, sprite particles or gameplay RNG.
const DURATION := 0.48
const SMOKE := Color("#520d2b")
const FIRE := Color("#c92839")
const ORANGE := Color("#ff822d")
const YELLOW := Color("#ffe07d")
const WHITE := Color("#fffced")
const CLOUDS := [Vector4(12, -14, 25, 23), Vector4(-13, -8, 24, 20),
	Vector4(16, 11, 23, 20), Vector4(-14, 14, 22, 19)]
const DRIFT := [Vector2(9, -15), Vector2(-3, -10), Vector2(15, -5), Vector2(-8, 7)]

static func noise(seed: int) -> float:
	return fposmod(sin(float(seed) * 12.9898) * 43758.5453, 1.0)

static func blob(v, point: Vector2, offset: Vector2, axes: Vector2, angle: float, projection: Vector2, color: Color, wobble: float, count: int = 24) -> void:
	if color.a < 0.01 or minf(axes.x, axes.y) < 0.2: return
	var contour := PackedVector2Array()
	var forward := Vector2.from_angle(angle)
	var side := forward.orthogonal()
	for i in count:
		var theta := float(i) * TAU / float(count)
		var scallop := 1.0 + sin(theta * 4.0 + wobble) * 0.055 + cos(theta * 3.0 - wobble) * 0.045
		var local := Vector2(cos(theta) * axes.x, sin(theta) * axes.y) * scallop
		contour.append(point + (offset + forward * local.x + side * local.y) * projection)
	v.draw_colored_polygon(contour, color)

static func curl(v, point: Vector2, offset: Vector2, axes: Vector2, angle: float, projection: Vector2, alpha: float, wobble: float, reduced: bool) -> void:
	var path := PackedVector2Array()
	var forward := Vector2.from_angle(angle)
	var side := forward.orthogonal()
	for i in 12:
		var t := float(i) / 11.0
		var theta := -2.9 + t * 4.9 + wobble * 0.16
		var radius := lerpf(0.66, 0.10, t)
		var local := Vector2(cos(theta) * axes.x * radius, sin(theta) * axes.y * radius)
		path.append(point + (offset + forward * local.x + side * local.y) * projection)
	var scale := minf(projection.x, projection.y)
	v.draw_polyline(path, Color(ORANGE, alpha), maxf(0.7, axes.y * 0.23 * scale), true)
	if not reduced:
		v.draw_polyline(path.slice(0, 5), Color(YELLOW, alpha * 0.40), maxf(0.6, axes.y * 0.07 * scale), true)

static func burst(v, point: Vector2, age: float, size: float, seed: int, reduced: bool = false, ground_projection: Vector2 = Vector2.ONE) -> void:
	if age < 0.0 or age >= DURATION or size <= 0.0: return
	var projection := ground_projection * size
	var opening := smoothstep(0.035, 0.23, age)
	var peel := smoothstep(0.17, 0.44, age)
	var smoke_alpha := smoothstep(0.025, 0.065, age) * (1.0 - smoothstep(0.28, DURATION, age))
	var core_alpha := smoothstep(0.0, 0.015, age) * (1.0 - smoothstep(0.15, 0.30, age))
	var rotation := (noise(seed) - 0.5) * 0.45
	# Four overlapping rounded masses roll up to one side. They never form a ring of petals.
	for i in CLOUDS.size():
		if reduced and i == 3: continue
		var spec: Vector4 = CLOUDS[i]
		var offset: Vector2 = (Vector2(spec.x, spec.y) * (0.32 + opening * 0.68) + DRIFT[i] * peel).rotated(rotation)
		var grow := (0.56 + smoothstep(0.025, 0.08, age) * 0.44) * (1.0 - peel * 0.34)
		var axes := Vector2(spec.z, spec.w) * grow
		blob(v, point, offset, axes, -0.30 + i * 0.47 + peel * 0.2, projection, Color(SMOKE, smoke_alpha), noise(seed + i * 31) * TAU)
	# The hot color stays in two central tongues, leaving broad areas of solid dark smoke.
	for i in (1 if reduced else 2):
		var offset := (Vector2(-5, -5) if i == 0 else Vector2(13, 5)) + (Vector2(-2, -9) if i == 0 else Vector2(12, -4)) * peel
		offset = offset.rotated(rotation)
		var axes := (Vector2(17, 21) if i == 0 else Vector2(18, 14)) * (1.0 - peel * 0.44)
		var angle := -0.50 if i == 0 else 0.25
		blob(v, point, offset, axes, angle, projection, Color(FIRE, smoke_alpha), 1.7 + i)
		curl(v, point, offset, axes * 0.83, angle, projection, smoke_alpha * (1.0 - peel * 0.38), 1.7 + i, reduced)
	# The core begins wide and low, pops tall, then splits as the smoke pulls away.
	var pop := sin(clampf(age / 0.19, 0.0, 1.0) * PI)
	var core := Vector2(8.0 + pop * 21.0, 3.0 + pop * 20.0)
	var core_offset := Vector2(-3.0 + opening * 5.0, -2.0 - opening * 3.0)
	blob(v, point, core_offset, core, -0.18 + rotation, projection, Color(ORANGE, core_alpha), 1.4)
	blob(v, point, core_offset + Vector2(-1, -2), core * Vector2(0.83, 0.86), -0.18 + rotation, projection, Color(YELLOW, core_alpha), 1.4)
	blob(v, point, core_offset + Vector2(-3, -3), core * Vector2(0.66, 0.69), -0.18 + rotation, projection, Color(WHITE, core_alpha), 1.4)
	if core_alpha > 0.1 and not reduced and v.light_layer != null:
		v.light_layer.glow(point + core_offset * projection, Vector2(83, 67) * projection, YELLOW, core_alpha * 0.48)
	# Three broad, curved crumbs remain after the core. Nothing uses sprite particles.
	if not reduced:
		for i in 3:
			var release := smoothstep(0.10 + i * 0.047, 0.24 + i * 0.047, age)
			var fleck_alpha := smoke_alpha * release
			var direction: Vector2 = [Vector2(-0.91, -0.30), Vector2(0.74, -0.69), Vector2(0.67, 0.80)][i].rotated(rotation)
			var offset: Vector2 = direction * (30.0 + release * 24.0) + Vector2(6.0, -5.0) * peel
			var axes: Vector2 = [Vector2(9, 5), Vector2(7, 4), Vector2(4, 3)][i] * (1.0 - peel * 0.38)
			var angle := direction.angle() + 0.8 + i * 0.6 + peel * (1.0 if i == 0 else -0.8)
			blob(v, point, offset, axes, angle, projection, Color(SMOKE, fleck_alpha), float(i), 16)
			if i < 2: blob(v, point, offset - direction, axes * 0.55, angle, projection, Color(FIRE, fleck_alpha), float(i), 16)
