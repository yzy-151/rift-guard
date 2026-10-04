extends Node2D
## Retained map draw commands. Camera movement translates this canvas item;
## only edited geometry, gate health or a different map rebuild its commands.
const Flat = preload("res://scripts/flat_stage_art.gd")
const EnvironmentArt = preload("res://scripts/battle_environment_art.gd")
const Endless = preload("res://scripts/endless_stage_art.gd")
const Stage = preload("res://scripts/stage_projection.gd")
const Visual = preload("res://data/stage_visual_profile.tres")
const STATIC_TYPES := ["blocked", "high_ground", "attack_ground", "attack_buff", "door", "shortcut", "one_way", "weather"]
var sim
var static_features: Array[Dictionary] = []
var dynamic_features: Array[Dictionary] = []
var rebuild_count := 0
var _signature := 0
var _initialized := false

func sync_from(view) -> void:
	sim = view.sim
	if sim == null: return
	static_features.clear()
	dynamic_features.clear()
	var geometry: Array = []
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("type", "")) in STATIC_TYPES:
			static_features.append(feature)
			# Weather timers change every tick but their corner marks do not.
			geometry.append([feature.get("type"), feature.get("area"), feature.get("grid_cells"),
				feature.get("collision_scale"), feature.get("collision_offset"), feature.get("collision_shape"),
				feature.get("hp"), feature.get("max_hp"), feature.get("element")])
		else:
			dynamic_features.append(feature)
	var signature := hash([sim.current_stage_id, sim.endless_layout_id, sim.run_seed, geometry,
		sim.stage_routes() if not sim.endless_mode else Endless.palette(sim)])
	position = view.ENDLESS_PLAYFIELD_SCREEN.get_center() - view.camera_center if sim.endless_mode else Vector2.ZERO
	if not _initialized or signature != _signature:
		_initialized = true
		_signature = signature
		rebuild_count += 1
		queue_redraw()

func world_to_screen(point: Vector2) -> Vector2:
	return point if sim.endless_mode else Stage.project(point)

func _draw() -> void:
	if sim == null: return
	if sim.endless_mode:
		var theme: String = Endless.palette(sim).theme
		draw_rect(sim.ENDLESS_ARENA.grow(2048), Color("#11121b"))
		EnvironmentArt.ground(self, sim.ENDLESS_ARENA, theme)
		for feature: Dictionary in static_features:
			for area: Rect2 in EnvironmentArt.merge_cells(Flat.feature_rects(feature)):
				EnvironmentArt.feature(self, area, feature, theme)
		return
	var palette: Dictionary = Visual.palette(sim.current_stage_id)
	var floor_color: Color = palette.get("floor", Color("#30333a"))
	var accent: Color = palette.get("accent", Color("#8ecbb1"))
	draw_rect(Flat.FRAME, Flat.INK)
	draw_rect(Flat.FRAME.grow(-5), floor_color.darkened(0.35))
	Flat._draw_border(self, sim.current_stage_id, accent)
	Flat._draw_floor(self, sim.current_stage_id, palette)
	Flat._draw_routes(self, floor_color, accent)
	for feature: Dictionary in static_features:
		Flat._draw_feature(self, feature, accent)
	for x in [28.0, 1252.0]:
		for y in [71.0, 602.0]:
			draw_circle(Vector2(x, y), 4.0, Flat.INK)
			draw_line(Vector2(x - 2, y), Vector2(x + 2, y), accent.darkened(0.2), 1.0, true)
