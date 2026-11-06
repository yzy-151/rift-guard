extends Control

const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
var progress := 0.0

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var origin:Vector2=UI_LAYOUT.mode_home_sidebar_rect.position
	var box:=Rect2(Vector2.ZERO,size)
	draw_style_box(_frame(),box)
	draw_colored_polygon(PackedVector2Array([Vector2(0,0),Vector2(size.x-13,0),Vector2(size.x,9),Vector2(size.x,12),Vector2(0,12)]),Color("#e31b49"))
	var portrait:Rect2=UI_LAYOUT.mode_home_amiya_rect
	portrait.position-=origin
	draw_colored_polygon(PackedVector2Array([portrait.position+Vector2(0,17),Vector2(portrait.end.x,portrait.position.y),portrait.end-Vector2(11,0),Vector2(portrait.position.x,portrait.end.y)]),Color("#2c1021"))
	var name:Rect2=UI_LAYOUT.mode_home_nameplate_rect
	name.position-=origin
	draw_rect(name,Color("#fff2df"))
	var status:Rect2=UI_LAYOUT.mode_home_progress_rect
	status.position-=origin
	var line:=Rect2(status.position+Vector2(0,status.size.y+3),Vector2(status.size.x,4))
	draw_rect(line,Color("#30202a"))
	line.size.x*=clampf(progress,0,1)
	if line.size.x>0:draw_rect(line,Color("#ffcf43"))

func _frame() -> StyleBoxFlat:
	var style:=StyleBoxFlat.new()
	style.bg_color=Color("#09090e")
	style.border_color=Color("#39212d")
	style.set_border_width_all(1)
	return style
