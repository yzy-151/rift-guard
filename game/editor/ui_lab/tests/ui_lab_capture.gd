extends SceneTree

const WorkspaceScene = preload("res://editor/ui_lab/ui_lab_workspace.tscn")
const PAGES := ["Dialogue", "Mode", "Mission", "Squad", "Campaign Battle", "Endless Battle", "Reward", "Settings", "Stage"]

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.size = Vector2i(1280, 1040)
	for page: String in PAGES:
		var workspace = WorkspaceScene.instantiate()
		root.add_child(workspace)
		workspace.rebuild(page)
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var path := "res://../outputs/ui-lab/%s-lab.png" % page.to_lower().replace(" ", "_")
		var error := image.save_png(ProjectSettings.globalize_path(path))
		if error != OK:
			push_error("CAPTURE FAIL: %s" % error_string(error))
		else:
			print("CAPTURE PASS: " + path)
		workspace.release_lock()
		workspace.queue_free()
		await process_frame
	quit()
