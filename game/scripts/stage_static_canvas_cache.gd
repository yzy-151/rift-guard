extends SubViewport
## Rasterize immutable gallery masonry once; combat and depth walls stay live.
class Drawer:
	extends Node2D
	var art
	func _draw() -> void:
		art.backdrop(self)
		art.ground(self)

var complete := false

func setup(art) -> void:
	disable_3d=true
	size=Vector2i(2560,1440)
	transparent_bg=false
	# A 2x source already supersamples the floor; no persistent MSAA buffer.
	msaa_2d=Viewport.MSAA_DISABLED
	render_target_update_mode=SubViewport.UPDATE_ONCE
	var drawer=Drawer.new()
	drawer.art=art
	drawer.scale=Vector2(2,2)
	add_child(drawer)
	RenderingServer.frame_post_draw.connect(_completed,CONNECT_ONE_SHOT)

func _completed() -> void:
	complete=true
