extends SceneTree
var output_dir:String=get_script().resource_path.get_base_dir()
func _initialize()->void:run.call_deferred()
func snap(name:String)->void:
	await process_frame
	RenderingServer.force_draw(false,1.0/30)
	root.get_texture().get_image().save_png(output_dir.path_join(name+".png"))
func run()->void:
	root.size=Vector2i(1280,720)
	var boot=load("res://boot.tscn").instantiate();root.add_child(boot);current_scene=boot
	await create_timer(0.9).timeout
	await snap("boot")
	for i in 100:
		await create_timer(.2).timeout
		if current_scene!=boot:break
	var app=current_scene
	await create_timer(1.5).timeout
	await snap("menu")
	app.mode_select_panel.close();app.stage_select_panel.open()
	await create_timer(.3).timeout;await snap("three-chapters")
	app.stage_select_panel.close()
	app.compendium.cleared_stages["stage_01"]=true
	app.choose_stage("stage_02")
	await create_timer(1.0).timeout;await snap("chapter2-story")
	print("PACKAGED UI CAPTURE COMPLETE")
	app.queue_free()
	await process_frame
	await process_frame
	quit()
