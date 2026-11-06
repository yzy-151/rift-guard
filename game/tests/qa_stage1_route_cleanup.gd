extends SceneTree

const Sim = preload("res://scripts/combat_simulation.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim = Sim.new(9801, true)
	var squad: Array[String] = ["traveler", "hero_03", "hero_08"]
	sim.reset_stage("stage_01", squad, 9801)
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("type", "")) in ["high_ground", "mechanism"]:
			push_error("Stage 1 still contains a raised platform or auto-attacking mechanism")
			quit(1)
			return
	var routes: Dictionary = sim.stage_routes()
	if routes.size() != 3:
		push_error("Stage 1 should retain all three enemy approaches")
		quit(1)
		return
	for route_id: String in routes:
		var points: Array = routes[route_id]
		if points.size() < 5 or Vector2(points[-1]).distance_to(Vector2(130, 395)) > 10.0:
			push_error("Stage 1 route is missing or does not reach the statue")
			quit(1)
			return
	sim.start()
	var enemy: Dictionary = sim.spawn_on_route("grunt", "lower")
	var route: Array = enemy.route_points
	enemy.pos = route[0]
	enemy.route_index = 1
	var before := Vector2(enemy.pos)
	sim._enemy_tick(0.12)
	var delta := Vector2(enemy.pos) - before
	if delta.length() <= 0.1 or (absf(delta.x) > 0.1 and absf(delta.y) > 0.1):
		push_error("Stage 1 enemies should follow the same orthogonal route as other stages")
		quit(1)
		return
	print("STAGE1_ROUTE_CLEANUP_OK routes=3 orthogonal_movement=true high_ground=0 mechanism=0")
	quit(0)
