extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var suite = preload("res://scripts/qa_v95_simulation.gd").new()
	quit(suite.run())
