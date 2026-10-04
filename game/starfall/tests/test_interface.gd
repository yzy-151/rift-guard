extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ",message)

func run() -> void:
	var sim = load("res://starfall/simulation.gd").new()
	sim.start("campaign",["traveler","hero_03","hero_08"],1)
	var ui = load("res://starfall/interface.gd").new()
	root.add_child(ui)
	ui.show_party("campaign")
	await process_frame
	for node in ui.root.get_children():
		if node is Button:
			for child in node.get_children():
				if child is TextureRect:
					check(child.size.x<=node.size.x,"portrait width fits character card")
					check(child.size.y<=node.size.y,"portrait height fits character card")
	ui.build_hud(sim)
	await process_frame
	print("core_size=",ui.bars.core.size," min=",ui.bars.core.get_minimum_size()," bg=",ui.bars.core.get_theme_stylebox("background").get_minimum_size()," fill=",ui.bars.core.get_theme_stylebox("fill").get_minimum_size())
	check(ui.bars.core.size.y<=12,"core bar respects 10-pixel HUD track")
	check(ui.bars.xp.size.y<=8,"XP bar does not extend below viewport")
	for i in range(3):
		check(ui.bars["hp%d"%i].size.y<=8,"hero health track does not cover text")
		check(ui.bars["energy%d"%i].size.y<=6,"energy track remains distinct from health")
	ui.queue_free()
	await process_frame
	if failures.is_empty(): print("PASS: Starfall native UI layout")
	quit(0 if failures.is_empty() else 1)
