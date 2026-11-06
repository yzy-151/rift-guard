extends SceneTree

func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1000, 560)
	root.content_scale_size = Vector2i(1000, 560)
	var stage := Control.new()
	root.add_child(stage)
	var bg := ColorRect.new()
	bg.size = Vector2(1000,560)
	bg.color = Color("17151c")
	stage.add_child(bg)
	var texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/ui/release_20261106/icon.png"))
	var old := ImageTexture.create_from_image(Image.load_from_file(get_script().resource_path.get_base_dir().path_join("previous.png")))
	var font = load("res://assets/fonts/TiejiliSC-Regular.ttf")
	var positions := [Vector2(30,70),Vector2(310,70),Vector2(650,90),Vector2(760,90),Vector2(870,90),Vector2(650,280)]
	var sizes := [256,256,32,48,64,192]
	var captions := ["之前", "重新设计", "32 px", "48 px", "64 px", "安卓圆形裁切预览"]
	for i in sizes.size():
		var img := TextureRect.new()
		img.position = positions[i]
		img.size = Vector2.ONE*sizes[i]
		img.texture = old if i==0 else texture
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		stage.add_child(img)
		if i == 5:
			var shader := Shader.new()
			shader.code = "shader_type canvas_item; void fragment(){ vec2 uv=(UV-vec2(0.5))*0.667+vec2(0.5); vec4 c=texture(TEXTURE,uv); c.a*=1.0-smoothstep(0.49,0.5,length(UV-vec2(0.5))); COLOR=c; }"
			var material := ShaderMaterial.new()
			material.shader = shader
			img.material = material
		var label := Label.new()
		label.position = positions[i]-Vector2(0,35)
		label.text = captions[i]
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",20)
		stage.add_child(label)
	var mono_texture := ImageTexture.create_from_image(Image.load_from_file("res://assets/ui/release_20261106/icon_monochrome.svg"))
	var mono_control := Control.new()
	stage.add_child(mono_control)
	mono_control.draw.connect(func(): mono_control.draw_texture_rect(mono_texture, Rect2(40,335,192,192),false))
	mono_control.queue_redraw()
	await process_frame
	await process_frame
	RenderingServer.force_draw(false,1.0/30)
	root.get_texture().get_image().save_png(get_script().resource_path.get_base_dir().path_join("preview.png"))
	stage.queue_free()
	await process_frame
	quit()
