extends RefCounted
const Cinematic = preload("res://scripts/battle_cinematic_vfx.gd")
const EnvironmentArt = preload("res://scripts/battle_environment_art.gd")
const Flat = preload("res://scripts/flat_stage_art.gd")

static func palette(sim) -> Dictionary:
	var theme := str(sim.stage_runtime.definition.get("theme_id", "crimson"))
	match theme:
		"frost": return {"floor":Color("#87b6cf"), "wash":Color(0.08,0.21,0.29,0.20), "accent":Color("#b8e9ff"), "name":"霜晶群岛", "theme":theme}
		"wind": return {"floor":Color("#8ec6ae"), "wash":Color(0.03,0.20,0.15,0.20), "accent":Color("#b9f3d9"), "name":"风蚀十字庭", "theme":theme}
		_: return {"floor":Color("#a17b8c"), "wash":Color(0.16,0.025,0.06,0.13), "accent":Color("#ed7183"), "name":"猩红门廊", "theme":"crimson"}

static func draw_stage(v) -> void:
	var colors:=palette(v.sim)
	v.draw_rect(Rect2(0,0,1280,720),Color("#11121b"))
	var world: Rect2=v.sim.ENDLESS_ARENA
	EnvironmentArt.ground(v,Rect2(v.world_to_screen(world.position),world.size),str(colors.theme))
	details(v,colors)

static func draw_terrain(v) -> void:
	var colors:=palette(v.sim)
	for feature: Dictionary in v.sim.terrain_features:
		for area: Rect2 in EnvironmentArt.merge_cells(Flat.feature_rects(feature)):
			var display_area:=area.merge(Rect2(feature.get("effect_area",area)))
			if v.visible_world_rect().grow(80).intersects(display_area):
				EnvironmentArt.feature(v,area,feature,str(colors.theme))

static func details(v, _colors: Dictionary) -> void:
	var contract: Dictionary = v.sim.combat_contract
	if str(contract.get("metric", "")) == "zone_hold" and not bool(contract.get("completed", false)):
		var center: Vector2 = v.world_to_screen(Vector2(contract.get("zone_pos", Vector2.ZERO)))
		var radius := float(contract.get("zone_radius", 120))
		Cinematic.circle(v, center, radius, Color("#a9ffe0"), 0.9, 2.5)
		for i in 8:
			var d := Vector2.from_angle(i * TAU / 8)
			v.draw_line(center + d * (radius - 9), center + d * radius, Color("#e0fff0"),2,true)
		v.caption(center + Vector2(-37,-radius-10), "驻留目标区", Color("#baffde"),12)
