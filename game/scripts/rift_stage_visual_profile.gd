extends Resource
class_name RiftStageVisualProfile

@export_group("Common Layers")
@export var backdrop_tint := Color("#fff4f4")
@export var stage_veil := Color(0.05, 0.02, 0.06, 0.42)
@export var arena_overlay := Color(0.13, 0.08, 0.16, 0.72)
@export var border_color := Color("#9a5961")
@export var route_underlay := Color(0.02, 0.01, 0.025, 0.20)
@export var foreground_color := Color(0.08, 0.04, 0.075, 0.88)
@export var ember_color := Color("#e86a5f")

@export_group("Stage 01")
@export var stage_01_floor := Color("#302832")
@export var stage_01_tile_a := Color("#3d3440")
@export var stage_01_tile_b := Color("#342d37")
@export var stage_01_accent := Color("#c45a68")

@export_group("Stage 02")
@export var stage_02_floor := Color("#29263a")
@export var stage_02_tile_a := Color("#37354a")
@export var stage_02_tile_b := Color("#2e2d40")
@export var stage_02_accent := Color("#a57ac7")

@export_group("Stage 03+")
@export var stage_03_floor := Color("#272d35")
@export var stage_03_tile_a := Color("#343c45")
@export var stage_03_tile_b := Color("#2c333c")
@export var stage_03_accent := Color("#c77a68")

func palette(stage_id: String) -> Dictionary:
	if stage_id == "stage_01":
		return {"floor": stage_01_floor, "tile_a": stage_01_tile_a, "tile_b": stage_01_tile_b, "accent": stage_01_accent}
	if stage_id == "stage_02":
		return {"floor": stage_02_floor, "tile_a": stage_02_tile_a, "tile_b": stage_02_tile_b, "accent": stage_02_accent}
	return {"floor": stage_03_floor, "tile_a": stage_03_tile_a, "tile_b": stage_03_tile_b, "accent": stage_03_accent}
