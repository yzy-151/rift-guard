extends Node2D
## All effects are cosmetic; gameplay remains in CombatSimulation.
const Stage = preload("res://scripts/stage_projection.gd")
const WORLD = Rect2(40, 140, 1200, 440)
const Sim = preload("res://scripts/combat_simulation.gd")
const INK = Color("#0c1017")
const TEAL = Color("#8fdbc8")
const RED = Color("#d66769")
var sim
var selected_id: int = 0
var reduced_effects: bool = false
var effects: Array[Dictionary] = []
var clock: float = 0.0
var shot_flashes: Dictionary = {}
var base_flash: float = 0.0
var shake_trauma: float = 0.0
var atlas: Texture2D = preload("res://assets/tiny-dungeon.png")
var furina_texture: Texture2D = preload("res://assets/characters/furina/furina-chibi-v1-alpha.png")
var furina_actor
var font: SystemFont
var slash_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_01.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_02.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_03.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_04.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_05.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_06.png")
]
var muzzle_fire_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_1.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_2.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_3.png")
]
var muzzle_ion_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_1.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_2.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_3.png")
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	build_furina_actor()

func advance(dt: float) -> void:
	clock += dt
	for id in shot_flashes:
		shot_flashes[id] = maxf(0.0, shot_flashes[id] - dt)
	base_flash = maxf(0.0, base_flash - dt)
	shake_trauma = maxf(0.0, shake_trauma - dt * 3.8)
	position = Vector2(sin(clock * 91.0), cos(clock * 73.0)) * shake_trauma * 5.0
	for effect in effects:
		effect.life -= dt
	effects = effects.filter(func(e: Dictionary) -> bool: return e.life > 0.0)
	sync_furina_actor(dt)
	queue_redraw()

func build_furina_actor() -> void:
	if furina_actor != null:
		return
	furina_actor = preload("res://scripts/furina_frame_actor.gd").new()
	add_child(furina_actor)
	call_deferred("sync_furina_actor")

func sync_furina_actor(dt: float = 0.0) -> void:
	if furina_actor == null or sim == null or sim.heroes.size() < 3:
		return
	var hero: Dictionary = sim.heroes[2]
	var shot_life: float = shot_flashes.get(hero.id, 0.0)
	furina_actor.sync(hero, Stage.project(hero.pos), Stage.depth_scale(hero.pos), shot_life, reduced_effects, dt)

func accept_events(batch: Array[Dictionary]) -> void:
	for event in batch:
		match event.kind:
			"shot":
				shot_flashes[event.hero_id] = 0.12
				var hero: Dictionary = sim.heroes[event.hero_id]
				effects.append({"kind": "muzzle", "pos": event.pos + Vector2(25, -20), "life": 0.16, "value": 1 if hero.get("element", "") == "electro" else 0})
			"hit", "death", "move", "hurt", "down", "heal", "vaporize", "slash", "splash", "multishot", "pierce", "chain", "echo", "death_burst", "frenzy", "reinforcement", "support_heal", "crossfire", "finale", "barrage":
				effects.append({"kind": event.kind, "pos": event.pos, "life": 0.6, "value": event.get("value", 0)})
				if event.kind in ["death_burst", "crossfire", "finale", "barrage"]:
					shake_trauma = minf(1.0, shake_trauma + 0.42)
				elif event.kind in ["hit", "slash", "chain"]:
					shake_trauma = minf(0.42, shake_trauma + 0.045)
			"leak":
				base_flash = 0.3

func caption(point: Vector2, text: String, color: Color, size: int = 12) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if sim == null or font == null:
		return
	_draw_stage()
	_draw_base_projected()
	_draw_portal_projected()
	if selected_id >= 0:
		var hero: Dictionary = sim.heroes[selected_id]
		if hero.hp > 0:
			_draw_range_indicator(hero)
	for hero in sim.heroes:
		if hero.hp > 0 and hero.pos.distance_to(hero.target) > 3.0:
			draw_dashed_line(Stage.project(hero.pos), Stage.project(hero.target), Color(hero.color, 0.6), 1.0, 7.0)
			_ground_circle(hero.target, 13.0, Color(hero.color))
	var actors: Array[Dictionary] = []
	for enemy in sim.enemies:
		actors.append({"unit": enemy, "hero": false})
	for hero in sim.heroes:
		actors.append({"unit": hero, "hero": true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.unit.pos.y < b.unit.pos.y)
	for actor in actors:
		var unit: Dictionary = actor.unit
		var point: Vector2 = Stage.project(unit.pos)
		var scale_factor: float = Stage.depth_scale(unit.pos)
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		draw_ellipse_shadow(Vector2.ZERO, 28.0 if actor.hero else unit.size * 0.48, Color(0, 0, 0, 0.5))
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		var visual: Dictionary = unit.duplicate()
		visual.pos = Vector2.ZERO
		if actor.hero:
			_draw_hero(visual)
		else:
			_draw_enemy(visual)
		draw_set_transform(Vector2.ZERO)
	for projectile in sim.projectiles:
		var point: Vector2 = Stage.project(projectile.pos) + Vector2(0, -18)
		var color: Color = {"hydro": Color("#74c9ff"), "pyro": Color("#ff7d54"), "electro": Color("#c189ff"), "cryo": Color("#b9efff"), "anemo": Color("#82ebc7"), "geo": Color("#f1c45c")}.get(projectile.element, Color("#ffd397"))
		draw_line(point - Vector2(24, 0), point, Color(color, 0.26), 7.0, true)
		draw_line(point - Vector2(16, 0), point, color, 2.8, true)
		draw_circle(point, 4.5, Color.WHITE)
	for effect in effects:
		var point: Vector2 = Stage.project(effect.pos)
		var scale_factor: float = Stage.depth_scale(effect.pos)
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		var visual: Dictionary = effect.duplicate()
		visual.pos = Vector2.ZERO
		_draw_effect(visual)
		draw_set_transform(Vector2.ZERO)
	# Foreground parapet gives the stage a solid front edge.
	var front := PackedVector2Array([Stage.project(Vector2(40, 580)), Stage.project(Vector2(1240, 580)), Vector2(1240, 609), Vector2(40, 609)])
	draw_colored_polygon(front, Color("#151018"))
	draw_line(front[0], front[1], Color("#725054"), 2.0)
	caption(Vector2(47, 595), "C I T A D E L   /   0 1", Color("#a68b91"), 11)
	caption(Vector2(960, 594), "敌军推进方向   ←", Color("#c99593"), 12)
	if sim.state == "between":
		caption(Vector2(548, 127), "队伍休整  %.1fs" % sim.wave_timer, TEAL, 16)

func _ground_circle(point: Vector2, radius: float, color: Color) -> void:
	for i in 40:
		draw_line(Stage.project(point + Vector2.from_angle(i * TAU / 40) * radius), Stage.project(point + Vector2.from_angle((i + 1) * TAU / 40) * radius), color, 1.3, true)

func _draw_range_indicator(hero: Dictionary) -> void:
	var center: Vector2 = Stage.project(hero.pos) + Vector2(0, 8)
	var depth: float = Stage.depth_scale(hero.pos)
	var radius_x: float = minf(210.0, 35.0 + hero.range * 0.56 * depth)
	var radius_y: float = radius_x * 0.30
	var color := Color(hero.color)
	var points := PackedVector2Array()
	for i in 72:
		var angle: float = float(i) * TAU / 72.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, Color(color, 0.055))
	points.append(points[0])
	draw_polyline(points, Color(color, 0.48), 1.6, true)
	for segment in 16:
		var start: float = float(segment) * TAU / 16.0 + 0.035
		var finish: float = start + TAU / 16.0 * 0.46
		var arc_points := PackedVector2Array()
		for step in 5:
			var angle: float = lerpf(start, finish, float(step) / 4.0)
			arc_points.append(center + Vector2(cos(angle) * radius_x * 0.92, sin(angle) * radius_y * 0.92))
		draw_polyline(arc_points, Color(color, 0.30), 1.0, true)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var edge := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		var tangent := Vector2(-sin(angle), cos(angle) * radius_y / radius_x).normalized()
		draw_line(edge - tangent * 5.0, edge + tangent * 5.0, Color(color, 0.85), 2.0, true)
	draw_arc(center, 12.0, 0, TAU, 32, Color(color, 0.28), 1.2, true)

func _draw_stage() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("#110e17"))
	draw_rect(Rect2(0, 94, 1280, 512), Color("#211b2b"))
	# Distant skyline, behind the wall.
	for i in 14:
		var x: float = i * 100 - 40
		var top: float = 105 + (i % 3) * 12
		draw_rect(Rect2(x, top, 66, 100), Color("#302532"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, top), Vector2(x + 33, top - 26), Vector2(x + 73, top)]), Color("#302532"))
	var floor: PackedVector2Array = Stage.polygon(WORLD)
	draw_colored_polygon(floor, Color("#302b34"))
	# Alternating stone tiles with perspective-correct seams.
	for row in 11:
		for col in 20:
			var rect := Rect2(40 + col * 60, 140 + row * 40, 60, 40)
			var tile_color := Color("#39313b") if (row + col) % 2 == 0 else Color("#342d37")
			draw_colored_polygon(Stage.polygon(rect.grow(-1)), tile_color)
	draw_colored_polygon(Stage.polygon(Sim.MOVE_AREA), Color(0.67, 0.28, 0.32, 0.10))
	var border: PackedVector2Array = Stage.polygon(Sim.MOVE_AREA)
	border.append(border[0])
	draw_polyline(border, Color("#9a5961"), 1.4, true)
	for lane in Sim.LANES:
		draw_line(Stage.project(Vector2(160, lane + 35)), Stage.project(Vector2(1200, lane + 35)), Color(0.72, 0.61, 0.62, 0.13), 1.0)
		for x in range(740, 1150, 110):
			var arrow: Vector2 = Stage.project(Vector2(x, lane))
			draw_polyline(PackedVector2Array([arrow + Vector2(5, -4), arrow, arrow + Vector2(5, 4)]), Color("#6f555e"), 1.5)
	# Rear wall has height independent of the floor projection.
	for i in 12:
		var ground: Vector2 = Stage.project(Vector2(45 + i * 105, 140))
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 48)), Color("#3e303c"))
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 5)), Color("#69505a"))
		draw_colored_polygon(PackedVector2Array([ground + Vector2(-5, 0), ground + Vector2(-5, -28), ground + Vector2(14, -40), ground + Vector2(33, -28), ground + Vector2(33, 0)]), Color("#211923"))
	for point in [Vector2(220, 145), Vector2(670, 145), Vector2(1120, 145)]:
		var screen: Vector2 = Stage.project(point)
		draw_line(screen, screen + Vector2(0, -45), Color("#89737a"), 4)
		draw_circle(screen + Vector2(0, -46), 5, Color("#e8967c"))
		if not reduced_effects:
			draw_circle(screen + Vector2(0, -46), 12 + sin(clock * 2) * 1.5, Color(0.9, 0.4, 0.3, 0.1))
	caption(Stage.project(Vector2(205, 525)), "自由部署区", Color("#c79398"), 12)

func _draw_base_projected() -> void:
	var point: Vector2 = Stage.project(Vector2(100, 365))
	draw_ellipse_shadow(point + Vector2(0, 13), 54, Color(0, 0, 0, 0.45))
	var tint: Color = RED if base_flash > 0.0 and not reduced_effects else Color("#e3b7ba")
	draw_colored_polygon(PackedVector2Array([point + Vector2(-36, 20), point + Vector2(-36, -97), point + Vector2(5, -120), point + Vector2(41, -95), point + Vector2(41, 18)]), Color("#59414d"))
	draw_colored_polygon(PackedVector2Array([point + Vector2(5, -120), point + Vector2(41, -95), point + Vector2(41, 18), point + Vector2(5, 35)]), Color("#31232e"))
	draw_rect(Rect2(point + Vector2(-25, -76), Vector2(29, 68)), Color("#211823"))
	draw_colored_polygon(PackedVector2Array([point + Vector2(-11, -67), point + Vector2(1, -40), point + Vector2(-11, -12), point + Vector2(-22, -40)]), tint)
	draw_line(point + Vector2(-30, -99), point + Vector2(6, -121), Color("#ab7b86"), 2)
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83, 6)), Color("#241d26"))
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83 * sim.base_hp / 100.0, 6)), tint)
	caption(point + Vector2(-35, 72), "基地核心", tint, 13)

func _draw_portal_projected() -> void:
	for lane in Sim.LANES:
		var point: Vector2 = Stage.project(Vector2(1195, lane))
		draw_set_transform(point + Vector2(0, -23), 0, Vector2(0.55, 1))
		draw_arc(Vector2.ZERO, 33, 0, TAU, 48, Color("#a64764"), 4, true)
		draw_arc(Vector2.ZERO, 25, 0, TAU, 48, Color("#ec8a9a"), 1.5, true)
		draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(pos: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		points.append(pos + Vector2(0, 9) + Vector2(cos(i * TAU / 32) * radius, sin(i * TAU / 32) * radius * 0.28))
	draw_colored_polygon(points, color)

func _draw_base() -> void:
	var tint: Color = RED if base_flash > 0.0 and not reduced_effects else TEAL
	draw_rect(Rect2(73, 255, 63, 216), Color("#1b2933"))
	draw_rect(Rect2(73, 255, 63, 216), Color("#51656c"), false, 2)
	for y in range(269, 460, 23):
		draw_line(Vector2(78, y), Vector2(129, y), Color("#2b3c45"), 1)
	draw_rect(Rect2(85, 302, 39, 100), Color("#0c151c"))
	draw_colored_polygon(PackedVector2Array([Vector2(104, 315), Vector2(119, 352), Vector2(104, 389), Vector2(89, 352)]), tint)
	draw_line(Vector2(104, 326), Vector2(104, 378), Color("#e4f4e7"), 2)
	draw_rect(Rect2(62, 474, 87, 8), Color("#27343d"))
	draw_rect(Rect2(62, 474, 87 * sim.base_hp / 100.0, 8), tint)
	caption(Vector2(71, 505), "基地核心", Color("#b2c0c8"), 13)
	draw_rect(Rect2(118, 220, 2, 312), Color(0.65, 0.78, 0.74, 0.14))

func _draw_portal() -> void:
	draw_rect(Rect2(1192, 226, 22, 285), Color("#39252e"))
	for lane in Sim.LANES:
		draw_arc(Vector2(1195, lane), 26, -PI / 2, PI / 2, 24, Color("#c66571"), 2)
		draw_arc(Vector2(1195, lane), 32 + sin(clock * 2) * 2, PI / 2, 3 * PI / 2, 24, Color("#50333f"), 1)
	caption(Vector2(1113, 208), "裂隙 / RIFT", Color("#c27b85"), 13)

func _draw_hero(hero: Dictionary) -> void:
	var down: bool = hero.hp <= 0
	var color := Color(hero.color)
	var is_furina: bool = hero.get("visual", "") == "furina"
	var bob: float = 0.0 if down else sin(clock * (14.0 if hero.moving else 3.0)) * (3.0 if hero.moving else 1.0)
	if selected_id == hero.id:
		draw_arc(hero.pos + Vector2(0, 8), 29, 0, TAU, 36, color, 2)
	var tint := Color("#67717a") if down else Color.WHITE
	if hero.flash > 0 and not reduced_effects:
		tint = Color("#f8a6a1")
	if is_furina:
		if shot_flashes.get(hero.id, 0.0) > 0.0 and not reduced_effects:
			var pulse: float = shot_flashes.get(hero.id, 0.0) / 0.12
			draw_circle(hero.pos + Vector2(30, -35), 7.0 + pulse * 5.0, Color(0.52, 0.88, 1.0, 0.16))
			draw_arc(hero.pos + Vector2(30, -35), 9.0 + pulse * 7.0, -1.25, 1.25, 16, Color("#a9ecff"), 2.0, true)
	else:
		draw_texture_rect_region(atlas, Rect2(hero.pos + Vector2(-29, -46 + bob), Vector2(58, 58)), Rect2(hero.tile, Vector2(16, 16)), tint)
	if not down:
		if hero.block > 0:
			draw_rect(Rect2(hero.pos + Vector2(17, -24), Vector2(16, 25)), Color("#a8a687"))
			draw_rect(Rect2(hero.pos + Vector2(21, -21), Vector2(8, 18)), Color("#445b5e"))
		elif not is_furina:
			draw_circle(hero.pos + Vector2(29, -16 + bob), 5, color)
			if shot_flashes.get(hero.id, 0.0) > 0 and not reduced_effects:
				draw_circle(hero.pos + Vector2(37, -16), 8, color)
	var label_y: float = -108.0 if is_furina else -65.0
	var health_y: float = -96.0 if is_furina else -53.0
	caption(hero.pos + Vector2(-29, label_y), "%d %s" % [hero.id + 1, hero.name], color, 13)
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50, 4)), Color("#303942"))
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50 * hero.hp / hero.max_hp, 4)), color)
	if down:
		caption(hero.pos + Vector2(-24, 30), "已倒地", RED, 12)
	elif hero.moving:
		caption(hero.pos + Vector2(-24, 30), "移动中", Color("#91a4ad"), 12)
	elif hero.block > 0:
		caption(hero.pos + Vector2(-28, 30), "阻挡 %d/%d" % [hero.blocked, hero.block], color, 12)

func _draw_furina(hero: Dictionary, tint: Color, bob: float, down: bool) -> void:
	if down:
		draw_texture_rect(furina_texture, Rect2(hero.pos + Vector2(-40, -29), Vector2(80, 42)), false, tint)
		return
	var attacking: bool = shot_flashes.get(hero.id, 0.0) > 0.0
	var stride: float = sin(clock * 14.0) if hero.moving else 0.0
	var width: float = 55.0 + absf(stride) * 2.0 + (5.0 if attacking else 0.0)
	var height: float = 94.0 - absf(stride) * 3.0 - (4.0 if attacking else 0.0)
	var origin: Vector2 = hero.pos + Vector2(-width * 0.5 + (4.0 if attacking else 0.0), -height + 9.0 + bob)
	if not reduced_effects:
		draw_circle(hero.pos + Vector2(0, -27), 29.0 + sin(clock * 2.4) * 2.0, Color(0.32, 0.73, 0.92, 0.08))
	draw_texture_rect(furina_texture, Rect2(origin, Vector2(width, height)), false, tint)
	if attacking and not reduced_effects:
		draw_arc(hero.pos + Vector2(29, -45), 10.0, -1.2, 1.2, 14, Color("#a9ecff"), 2.2, true)

func _draw_enemy(enemy: Dictionary) -> void:
	var bob: float = sin(clock * 8 + enemy.id) * 2
	var tint := Color("#fff5e5") if enemy.flash > 0 and not reduced_effects else Color(enemy.color)
	var side: float = enemy.size
	draw_texture_rect_region(atlas, Rect2(enemy.pos + Vector2(-side / 2, -side + 12 + bob), Vector2(side, side)), Rect2(0, 144, 16, 16), tint)
	var ratio: float = clampf(float(enemy.hp) / float(enemy.max_hp), 0, 1)
	draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44, 4)), Color("#302b32"))
	draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44 * ratio, 4)), RED)
	if enemy.kind == "armored":
		draw_arc(enemy.pos + Vector2(0, -18), 24, -PI * 0.4, PI * 0.4, 12, Color("#c5b2e3"), 3)
		caption(enemy.pos + Vector2(-7, 27), "甲", Color("#c5b2e3"), 12)
	elif enemy.kind == "runner":
		caption(enemy.pos + Vector2(-7, 27), "疾", Color("#e6c77b"), 12)
	if enemy.blocked_by >= 0:
		draw_line(enemy.pos + Vector2(-24, 10), enemy.pos + Vector2(24, 10), Color("#c5bd96"), 2)
	if enemy.slow_timer > 0:
		caption(enemy.pos + Vector2(19, 27), "缓", Color("#83c7e8"), 12)
	if enemy.aura != "":
		var is_water: bool = enemy.aura == "water"
		var color := Color("#83c7e8") if is_water else Color("#eaaa7d")
		draw_circle(enemy.pos + Vector2(30, -side), 11, Color("#10202b"))
		caption(enemy.pos + Vector2(24, -side + 5), "水" if is_water else "火", color, 12)

func _draw_effect(effect: Dictionary) -> void:
	var t: float = 1.0 - effect.life / 0.6
	var fade: float = minf(1.0, effect.life * 4)
	if effect.kind == "muzzle" and not reduced_effects:
		var frames: Array[Texture2D] = muzzle_ion_frames if int(effect.value) == 1 else muzzle_fire_frames
		var muzzle_t: float = 1.0 - effect.life / 0.16
		var muzzle_index: int = clampi(floori(muzzle_t * frames.size()), 0, frames.size() - 1)
		draw_texture_rect(frames[muzzle_index], Rect2(effect.pos + Vector2(-32, -32), Vector2(64, 64)), false, Color.WHITE)
	elif effect.kind == "slash" and not reduced_effects:
		var frame_index: int = clampi(floori(t * slash_frames.size()), 0, slash_frames.size() - 1)
		draw_texture_rect(slash_frames[frame_index], Rect2(effect.pos + Vector2(-62, -82), Vector2(124, 124)), false, Color(1, 0.88, 0.78, fade))
	elif effect.kind == "vaporize":
		caption(effect.pos + Vector2(-23, -76 - t * 22), "蒸发 ×%.2f" % sim.vapor_multiplier, Color(0.9, 0.85, 0.67, fade), 16)
		if not reduced_effects:
			draw_arc(effect.pos + Vector2(0, -17), 14 + t * 32, 0, TAU, 32, Color(0.7, 0.85, 0.95, fade * 0.6), 2)
	elif effect.kind in ["heal", "hurt"]:
		var healing: bool = effect.kind == "heal"
		var color := Color(0.5, 0.95, 0.73, fade) if healing else Color(1, 0.5, 0.5, fade)
		caption(effect.pos + Vector2(13, -35 - t * 30), ("+" if healing else "-") + str(effect.value), color, 15)
	elif effect.kind == "splash":
		if not reduced_effects:
			draw_arc(effect.pos, 15 + t * 50, 0, TAU, 32, Color(1, 0.7, 0.4, fade * 0.5), 2)
	elif effect.kind in ["chain", "pierce", "echo", "multishot"]:
		var accent := Color(0.73, 0.52, 1.0, fade) if effect.kind == "chain" else Color(1.0, 0.88, 0.56, fade)
		draw_arc(effect.pos + Vector2(0, -15), 9 + t * 34, -0.8, 0.8, 18, accent, 3.0, true)
		for ray in 4:
			var angle: float = -0.7 + ray * 0.45
			draw_line(effect.pos + Vector2.from_angle(angle) * 8.0, effect.pos + Vector2.from_angle(angle) * (24.0 + t * 28.0), accent, 2.0, true)
	elif effect.kind in ["barrage", "crossfire", "finale", "death_burst"]:
		var blast_color := Color(1.0, 0.30, 0.26, fade)
		for ring in 3:
			draw_arc(effect.pos, 18.0 + ring * 16.0 + t * 52.0, 0, TAU, 40, Color(blast_color, fade * (0.72 - ring * 0.16)), 4.0 - ring, true)
		for ray in 12:
			var direction := Vector2.from_angle(ray * TAU / 12.0)
			draw_line(effect.pos + direction * (9.0 + t * 25.0), effect.pos + direction * (30.0 + t * 85.0), Color(1.0, 0.76, 0.42, fade), 3.0, true)
	elif effect.kind in ["support_heal", "reinforcement", "frenzy"]:
		var support_color := Color(0.48, 0.95, 0.79, fade)
		draw_arc(effect.pos, 16 + t * 62, 0, TAU, 40, support_color, 3.0, true)
		caption(effect.pos + Vector2(-42, -58 - t * 20), "支援接入" if effect.kind != "frenzy" else "战意升级", support_color, 18)
	elif effect.kind == "hit":
		caption(effect.pos + Vector2(-8, -25 - t * 30), str(effect.value), Color(1, 0.84, 0.58, fade), 16)
		if not reduced_effects:
			for i in 5:
				var direction := Vector2.from_angle(i * TAU / 5)
				draw_line(effect.pos + direction * (5 + t * 18), effect.pos + direction * (10 + t * 22), Color(1, 0.75, 0.4, fade), 2)
	elif effect.kind in ["death", "down"]:
		if not reduced_effects:
			draw_arc(effect.pos, 10 + t * 27, 0, TAU, 24, Color(0.8, 0.4, 0.42, fade * 0.6), 1.5)
	elif effect.kind == "move":
		draw_arc(effect.pos, 7 + t * 19, 0, TAU, 24, Color(0.55, 0.86, 0.78, fade), 1.5)
