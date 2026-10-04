extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var game = load("res://main.tscn").instantiate()
	root.add_child(game); current_scene = game
	var suite = preload("res://scripts/qa_v95_explosion.gd").new()
	var code: int = await suite.run(game)
	game._stop_scene_audio(game)
	await create_timer(0.25).timeout
	game.queue_free(); await process_frame
	quit(code)
