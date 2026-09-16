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

@export_group("Chapter 1 - Mondstadt Assets")
@export var chapter1_background: Texture2D
@export var chapter1_ground: Texture2D
@export var chapter1_crystal: Texture2D
@export var chapter1_lowland: Texture2D
@export var chapter1_high_platform: Texture2D
@export var chapter1_barricade: Texture2D
@export var chapter1_bush: Texture2D
@export var chapter1_moving_platform: Texture2D
@export var chapter1_mechanism: Texture2D
@export_group("Stage 01 - Rift Outpost")
@export var stage_01_floor := Color("#486342")
@export var stage_01_tile_a := Color("#718d55")
@export var stage_01_tile_b := Color("#607a49")
@export var stage_01_accent := Color("#71d5b1")

@export_group("Stage 02 - Crimson Gallery")
@export var stage_02_floor := Color("#29263a")
@export var stage_02_tile_a := Color("#37354a")
@export var stage_02_tile_b := Color("#2e2d40")
@export var stage_02_accent := Color("#a57ac7")

@export_group("Stage 03 - Obsidian Nest")
@export var stage_03_floor := Color("#272d35")
@export var stage_03_tile_a := Color("#343c45")
@export var stage_03_tile_b := Color("#2c333c")
@export var stage_03_accent := Color("#c77a68")

@export_group("Stage 04 - Sky Crossroads")
@export var stage_04_floor := Color("#25323a")
@export var stage_04_tile_a := Color("#32434b")
@export var stage_04_tile_b := Color("#293941")
@export var stage_04_accent := Color("#6fc3d4")

@export_group("Stage 05 - Furnace Court")
@export var stage_05_floor := Color("#382923")
@export var stage_05_tile_a := Color("#4b3429")
@export var stage_05_tile_b := Color("#3f2c25")
@export var stage_05_accent := Color("#ef8a42")

@export_group("Stage 06 - Devouring Clocktower")
@export var stage_06_floor := Color("#29263a")
@export var stage_06_tile_a := Color("#3a3347")
@export var stage_06_tile_b := Color("#302b3c")
@export var stage_06_accent := Color("#d2b46a")

@export_group("Stage 07 - Frozen Fork")
@export var stage_07_floor := Color("#21313d")
@export var stage_07_tile_a := Color("#2b4351")
@export var stage_07_tile_b := Color("#263844")
@export var stage_07_accent := Color("#8ed9ea")

@export_group("Stage 08 - Eclipse Siege")
@export var stage_08_floor := Color("#2d222b")
@export var stage_08_tile_a := Color("#3d2932")
@export var stage_08_tile_b := Color("#33242c")
@export var stage_08_accent := Color("#f04d5f")

@export_group("Endless - Crimson Wastes")
@export var endless_floor := Color("#2d222b")
@export var endless_tile_a := Color("#382a33")
@export var endless_tile_b := Color("#30262f")
@export var endless_accent := Color("#df5965")

func palette(stage_id: String) -> Dictionary:
	match stage_id:
		"stage_01": return {"floor":stage_01_floor,"tile_a":stage_01_tile_a,"tile_b":stage_01_tile_b,"accent":stage_01_accent}
		"stage_02": return {"floor":stage_02_floor,"tile_a":stage_02_tile_a,"tile_b":stage_02_tile_b,"accent":stage_02_accent}
		"stage_03": return {"floor":stage_03_floor,"tile_a":stage_03_tile_a,"tile_b":stage_03_tile_b,"accent":stage_03_accent}
		"stage_04": return {"floor":stage_04_floor,"tile_a":stage_04_tile_a,"tile_b":stage_04_tile_b,"accent":stage_04_accent}
		"stage_05": return {"floor":stage_05_floor,"tile_a":stage_05_tile_a,"tile_b":stage_05_tile_b,"accent":stage_05_accent}
		"stage_06": return {"floor":stage_06_floor,"tile_a":stage_06_tile_a,"tile_b":stage_06_tile_b,"accent":stage_06_accent}
		"stage_07": return {"floor":stage_07_floor,"tile_a":stage_07_tile_a,"tile_b":stage_07_tile_b,"accent":stage_07_accent}
		"stage_08": return {"floor":stage_08_floor,"tile_a":stage_08_tile_a,"tile_b":stage_08_tile_b,"accent":stage_08_accent}
		"stage_endless": return {"floor":endless_floor,"tile_a":endless_tile_a,"tile_b":endless_tile_b,"accent":endless_accent}
	return {"floor":stage_01_floor,"tile_a":stage_01_tile_a,"tile_b":stage_01_tile_b,"accent":stage_01_accent}
