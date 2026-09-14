extends SceneTree
const Hud = preload("res://scripts/battle_hud.gd")
const Settings = preload("res://scripts/settings_panel.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var hud = Hud.new()
	root.add_child(hud)
	await process_frame
	var panel = Settings.new()
	root.add_child(panel)
	panel.build(hud)
	panel.open({"master":0.82,"music":0.62,"sfx":0.78,"fullscreen":false,"reduced_effects":false})
	await create_timer(0.35).timeout
	RenderingServer.force_draw()
	await process_frame
	var image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/v46-release"))
	var err = image.save_png(ProjectSettings.globalize_path("res://../outputs/v46-release/00b-settings.png"))
	print("SETTINGS CAPTURE: ", err, " size=", image.get_size())
	quit(err)
