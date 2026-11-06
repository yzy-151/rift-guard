extends Control
const PLANTS = preload("res://scripts/pvz_plant_visual.gd")
const POWER = preload("res://assets/ui/device_card_icons_20261005/device_power_pad.png")
const RANGE = preload("res://assets/ui/device_card_icons_20261005/device_range_pad.png")

var kind := "power"
var color := Color("#fff8ec"):
	set(value):
		color = value
		modulate = value

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if kind in ["power", "range"]:
		draw_texture_rect(POWER if kind == "power" else RANGE, Rect2(Vector2.ZERO, size), false)
	else:
		var key := "wallnut" if kind == "barricade" else "potato_mine" if kind == "mine" else kind
		PLANTS.draw_icon(self, key, Rect2(Vector2.ZERO, size))
