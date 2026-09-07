extends SceneTree
func _initialize() -> void:
	var target := "res://../builds/m1/GODOT-LICENSE.txt"
	var file := FileAccess.open(target, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write Godot license")
		quit(1)
		return
	file.store_string(Engine.get_license_text())
	file.close()
	var notices := FileAccess.open("res://../builds/m1/GODOT-THIRD-PARTY-NOTICES.json", FileAccess.WRITE)
	notices.store_string(JSON.stringify({"copyright": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
	notices.close()
	print("GODOT NOTICES EXPORTED")
	quit()
