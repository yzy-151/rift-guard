extends Node2D

const Stage = preload("res://scripts/stage_projection.gd")
const Comic = preload("res://scripts/comic_combat_vfx.gd")
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
		if kind not in ["heal", "skill_cast", "skill_impact", "element_burst"]:
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
			_draw_heal(target, effect, point)
			continue

		var age := float(effect.age)
		var color := element_tint(str(effect.element))
		if kind == "skill_cast":
			Comic.light(target, point - Vector2(0, 25), Vector2.ONE * 42, color, (1 - age / duration(kind)) * 0.4)
		elif age < 0.28:
			if str(effect.element) == "electro":
				Comic.lightning(target, point - Vector2(7, 35), point, color, 1 - age / 0.28, age, int(effect.seed * 100), 0.8)
			else:
				Comic.impact(target, point - Vector2(0, 20), age / 0.28, 1.2, color, int(effect.seed * 100))


func _draw_heal(target: CanvasItem, effect: Dictionary, point: Vector2) -> void:
	var progress := clampf(float(effect.age) / duration("heal"), 0.0, 1.0)
	var fade := sin(progress * PI)
	var depth: float = battle_view.world_depth_scale(effect.pos) if battle_view != null else Stage.depth_scale(effect.pos)
	Comic.light(target, point, Vector2(66, 32), Color("#63e9b9"), fade * 0.25)
	for index in 5:
		var phase := float(index) * TAU / 5.0 + float(effect.seed)
		var mote := point + Vector2(cos(phase)*26.0, sin(phase)*8.0-12.0-progress*48.0)*depth
		var half := (2.0 + sin(progress*PI))*depth
		target.draw_line(mote-Vector2(half,0),mote+Vector2(half,0),Color(0.68,1.0,0.85,fade),1.6,true)
		target.draw_line(mote-Vector2(0,half),mote+Vector2(0,half),Color(0.68,1.0,0.85,fade),1.6,true)
