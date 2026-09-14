extends RefCounted

const PORTAL_PHASES := ["forming", "opening", "active", "closing"]
const STAGE_LAYER_ORDER := ["backdrop", "atmosphere", "ground", "routes", "terrain", "architecture", "foreground"]
const THEMES := {
	"stage_01":{"title":"裂隙前哨","motif":"rampart","background":1,"tile_style":"brick","fog":0.44},
	"stage_02":{"title":"赤潮回廊","motif":"gallery","background":2,"tile_style":"corridor","fog":0.38},
	"stage_03":{"title":"黑曜母巢","motif":"nest","background":3,"tile_style":"shard","fog":0.52},
	"stage_04":{"title":"苍穹交叉口","motif":"skybridge","background":4,"tile_style":"bridge","fog":0.30},
	"stage_05":{"title":"熔炉回旋庭","motif":"forge","background":5,"tile_style":"furnace","fog":0.58},
	"stage_06":{"title":"噬时钟楼","motif":"clock","background":6,"tile_style":"gear","fog":0.46},
	"stage_07":{"title":"永冻岔路","motif":"frost","background":7,"tile_style":"ice","fog":0.34},
	"stage_08":{"title":"蚀日围城","motif":"eclipse","background":8,"tile_style":"siege","fog":0.62},
	"stage_endless":{"title":"猩红荒原","motif":"wastes","background":8,"tile_style":"wastes","fog":0.68}
}

func stage_theme(stage_id: String) -> Dictionary:
	return THEMES.get(stage_id, THEMES["stage_01"]).duplicate(true)

func portal_phase(life: float, total: float) -> String:
	var progress := 1.0 - clampf(life / maxf(total, 0.001), 0.0, 1.0)
	if progress < 0.18:
		return "forming"
	if progress < 0.38:
		return "opening"
	if progress < 0.82:
		return "active"
	return "closing"

func portal_visual(life: float, total: float, clock: float, seed: int = 0) -> Dictionary:
	var phase := portal_phase(life, total)
	var progress := 1.0 - clampf(life / maxf(total, 0.001), 0.0, 1.0)
	var envelope := clampf(progress / 0.18, 0.0, 1.0) * clampf((1.0 - progress) / 0.18, 0.0, 1.0)
	var opening := smoothstep(0.0, 0.38, progress)
	return {
		"phase": phase,
		"alpha": envelope,
		"scale": Vector2(0.42 + opening * 0.28, 0.72 + opening * 0.34) * (1.0 + sin(clock * 9.0 + seed) * 0.055),
		"ring": 24.0 + opening * 15.0 + sin(clock * 5.5 + seed) * 2.5,
		"gap": lerpf(2.35, 0.18, opening),
		"progress": progress
	}

func route_material(route_id: String, flying: bool = false, boss: bool = false) -> Dictionary:
	var palettes := {
		"upper": Color("#e8a878"),
		"main": Color("#e98179"),
		"lower": Color("#c985aa"),
		"north": Color("#e8a878"),
		"east": Color("#e98179"),
		"south": Color("#c985aa"),
		"west": Color("#a9a2ad")
	}
	var color: Color = Color("#f2d471") if flying else palettes.get(route_id, Color("#e98179"))
	if boss:
		color = Color("#ffd57a")
	return {"color":color,"width":6.0 if boss else 4.0,"bed_alpha":0.11,"glow_alpha":0.10}

func route_length(route: Array) -> float:
	var total := 0.0
	for i in range(route.size() - 1):
		total += Vector2(route[i]).distance_to(Vector2(route[i + 1]))
	return total

func sample_route(route: Array, normalized_distance: float) -> Dictionary:
	if route.size() < 2:
		return {"point":Vector2.ZERO,"tangent":Vector2.LEFT}
	var total := route_length(route)
	var target := clampf(normalized_distance, 0.0, 1.0) * total
	var walked := 0.0
	for i in range(route.size() - 1):
		var a := Vector2(route[i])
		var b := Vector2(route[i + 1])
		var segment := a.distance_to(b)
		if target <= walked + segment or i == route.size() - 2:
			var local := clampf((target - walked) / maxf(segment, 0.001), 0.0, 1.0)
			return {"point":a.lerp(b, local),"tangent":(b-a).normalized()}
		walked += segment
	return {"point":Vector2(route[-1]),"tangent":(Vector2(route[-1])-Vector2(route[-2])).normalized()}

func route_samples(route: Array, clock: float, count: int = 7, speed: float = 0.16) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in maxi(1, count):
		result.append(sample_route(route, fposmod(clock * speed + float(i) / float(maxi(1, count)), 1.0)))
	return result
