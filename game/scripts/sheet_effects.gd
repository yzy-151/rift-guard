extends Node2D

const Stage = preload("res://scripts/stage_projection.gd")
const GOLD = preload("res://assets/effects/heal-sheet.png")
const FX_CIRCLE = preload("res://assets/vfx/third_party/kenney_particle/circle_05.png")
const FX_FLARE = preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")
const FX_MAGIC = preload("res://assets/vfx/third_party/kenney_particle/magic_01.png")
const FX_MAGIC_ALT = preload("res://assets/vfx/third_party/kenney_particle/magic_03.png")
const FX_SLASH = preload("res://assets/vfx/third_party/kenney_particle/slash_01.png")
const FX_SLASH_HEAVY = preload("res://assets/vfx/third_party/kenney_particle/slash_02.png")
const FX_SPARK = preload("res://assets/vfx/third_party/kenney_particle/spark_02.png")
const FX_FIRE = preload("res://assets/vfx/third_party/kenney_particle/fire_01.png")
const FX_TRACE = preload("res://assets/vfx/third_party/kenney_particle/trace_05.png")

var active: Array[Dictionary] = []
var reduced: bool = false
var battle_view

func _ready() -> void:
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = blend
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func accept(batch: Array[Dictionary]) -> void:
	if reduced:
		return
	for event: Dictionary in batch:
		var kind := str(event.get("kind", ""))
		if kind not in ["heal", "hit", "critical", "shield_break", "skill_cast", "skill_impact", "ultimate_impact", "element_burst"]:
			continue
		if (kind == "skill_cast" and str(event.get("value", "")) == "静风疗愈") or (kind == "skill_impact" and str(event.get("ability_kind", "")) == "heal_gust"):
			continue
		if kind in ["skill_cast", "ultimate_cast"] and str(event.get("value", "")) in ["无咏风域", "灼热乐章", "焰色交响曲", "冰晶花", "冰结之森", "精神爆发", "奇美拉", "水脉疗愈", "豪雷积层云", "风刃切流", "长风复苏", "丝缕缠流", "引针簇射", "静谧圣歌", "寂月安魂曲", "孤心沙龙", "万众狂欢"]:
			continue
		if kind in ["skill_impact", "ultimate_impact"] and str(event.get("value", "")) in ["无咏风域", "灼热乐章", "焰色交响曲", "冰晶花", "冰结之森", "精神爆发", "奇美拉", "水脉疗愈", "豪雷积层云", "风刃切流", "长风复苏", "丝缕缠流", "引针簇射", "静谧圣歌", "寂月安魂曲", "孤心沙龙", "万众狂欢"]:
			continue
		if kind == "hit" and active.size() >= 28:
			continue
		if active.size() >= 48:
			active.pop_front()
		active.append({
			"kind": kind,
			"pos": event.get("pos", Vector2.ZERO),
			"age": 0.0,
			"element": str(event.get("element", "")),
			"seed": float((int(event.get("hero_id", 0)) * 37 + active.size() * 19) % 100) / 100.0
		})
		if kind == "ultimate_impact" and active.size() < 48:
			active.append({"kind":"ultimate_ring", "pos":event.get("pos", Vector2.ZERO), "age":0.0, "element":str(event.get("element", "")), "seed":0.5})

func advance(dt: float) -> void:
	for effect in active:
		effect.age += dt
	active = active.filter(func(effect: Dictionary) -> bool: return effect.age < duration(str(effect.kind)))
	queue_redraw()

func duration(kind: String) -> float:
	return {
		"heal":0.70, "hit":0.22, "critical":0.36,
		"shield_break":0.46, "skill_cast":0.34, "skill_impact":0.48,
		"ultimate_impact":0.68, "ultimate_ring":0.78, "element_burst":0.56
	}.get(kind, 0.42)

func frame_region(kind: String, index: int) -> Rect2:
	var columns: int = 5 if kind == "heal" else 3
	var cell := Vector2(2048.0 / columns, 576 if kind == "heal" else 579)
	return Rect2(Vector2(index % columns, index / columns) * cell + Vector2(14, 44), cell - Vector2(28, 78))

func project_position(world: Vector2) -> Vector2:
	if battle_view != null and battle_view.has_method("world_to_screen"):
		return battle_view.world_to_screen(world)
	return Stage.project(world)

func element_tint(element: String) -> Color:
	return {
		"anemo":Color("#77ffe0"), "electro":Color("#c98cff"), "pyro":Color("#ff7958"),
		"hydro":Color("#62c8ff"), "geo":Color("#ffd067"), "cryo":Color("#b4f5ff")
	}.get(element, Color("#fff1da"))

func visual_texture(kind: String, element: String) -> Texture2D:
	if kind == "hit":
		return FX_SLASH
	if kind == "critical":
		return FX_SLASH_HEAVY
	if kind == "shield_break":
		return FX_SPARK
	if kind == "skill_cast":
		return FX_FLARE
	if kind == "ultimate_ring":
		return FX_CIRCLE
	if kind == "element_burst":
		return FX_MAGIC_ALT
	if element == "pyro":
		return FX_FIRE
	return FX_MAGIC

func _draw() -> void:
	pass

func draw_behind_units(target: CanvasItem) -> void:
	if reduced:
		return
	for effect: Dictionary in active:
		var kind := str(effect.kind)
		var point: Vector2 = project_position(effect.pos)
		if kind == "heal":
			var total: int = 10
			var fraction: float = clampf(effect.age / duration(kind), 0, 0.999)
			var frame: int = mini(total - 1, int(fraction * total))
			var size := Vector2(108, 128)
			size *= Stage.depth_scale(effect.pos)
			var opacity: float = 0.66 * minf(1.0, (1.0 - fraction) * 5.0)
			target.draw_texture_rect_region(GOLD, Rect2(point - Vector2(size.x * 0.5, size.y * 0.82), size), frame_region(kind, frame), Color(1, 1, 1, opacity))
			continue
		var fraction: float = clampf(float(effect.age) / duration(kind), 0.0, 1.0)
		var seed: float = float(effect.seed)
		var base_size: float = float({
			"hit":62.0, "critical":108.0, "shield_break":132.0, "skill_cast":92.0,
			"skill_impact":156.0, "ultimate_impact":224.0, "ultimate_ring":286.0, "element_burst":184.0
		}.get(kind, 110.0))
		var scale_value: float = lerpf(0.34, 1.24, ease(fraction, -1.7))
		if kind == "ultimate_ring":
			scale_value = lerpf(0.34, 1.52, ease(fraction, 0.65))
		var opacity: float = pow(1.0 - fraction, 0.66)
		var tint: Color = element_tint(str(effect.element))
		var rotation: float = (seed - 0.5) * 1.6 + fraction * (1.2 if kind in ["ultimate_ring", "skill_impact"] else 0.18)
		target.draw_set_transform(point, rotation, Vector2.ONE * scale_value)
		var texture: Texture2D = visual_texture(kind, str(effect.element))
		var rect: Rect2 = Rect2(Vector2.ONE * -base_size * 0.5, Vector2.ONE * base_size)
		target.draw_texture_rect(texture, rect, false, Color(tint, opacity * (0.88 if kind == "ultimate_ring" else 1.0)))
		if kind in ["skill_impact", "ultimate_impact", "element_burst"]:
			var trace_rect := Rect2(Vector2(-base_size * 0.62, -base_size * 0.18), Vector2(base_size * 1.24, base_size * 0.36))
			target.draw_texture_rect(FX_TRACE, trace_rect, false, Color(tint.lightened(0.22), opacity * 0.70))
		target.draw_set_transform(Vector2.ZERO)
