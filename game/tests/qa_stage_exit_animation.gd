extends SceneTree

var failures: Array[String] = []
var completions := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var battle = load("res://scripts/battle_view.gd").new()
	battle.sim = load("res://scripts/combat_simulation.gd").new()
	battle.sim.heroes.assign([{"pos": Vector2(400, 360), "target": Vector2(400, 360)}])
	battle.stage_exit_finished.connect(func(): completions += 1)
	var checked := 0
	for id in battle.character_sequences.definitions:
		battle.begin_stage_exit(id, id, "none")
		var start = battle._stage_exit_visual_sample()
		battle._advance_stage_exit(0.15)
		var moving = battle._stage_exit_visual_sample()
		check(moving.state == "run" and moving.facing == -1.0, id + ": entry must run left")
		check(moving.frame != start.frame, id + ": moving frame must advance")
		check(battle.stage_exit_newcomer_pos.x < battle.STAGE_EXIT_DOOR.x, id + ": entry position")
		check(battle.character_sequences.texture(id, "run") != null, id + ": run texture exists")
		check(battle.character_sequences.source_rect(id, "run", moving.frame) != battle.character_sequences.source_rect(id, "run", start.frame), id + ": distinct rendered frames")
		battle._advance_stage_exit(0.85)
		check(battle.stage_exit_phase == "waiting", id + ": arrival waits")
		battle._advance_stage_exit(0.15)
		var idle = battle._stage_exit_visual_sample()
		check(idle.state == "idle" and idle.frame > 0, id + ": waiting idle animates")
		battle.sim.heroes[0].pos = battle.STAGE_EXIT_MEET
		battle._advance_stage_exit(0.01)
		var leaving = battle._stage_exit_visual_sample()
		check(leaving.state == "run" and leaving.facing == 1.0, id + ": departure turns right")
		battle._advance_stage_exit(0.15)
		check(battle._stage_exit_visual_sample().frame > 0, id + ": departure animates")
		check(battle.stage_exit_newcomer_pos.x > battle.STAGE_EXIT_MEET.x, id + ": departure position")
		battle._advance_stage_exit(1.21)
		checked += 1
		check(not battle.stage_exit_active and not battle.spawn_portals.has("stage_exit"), id + ": completion cleans portal")
		check(completions == checked, id + ": one completion signal")
		battle.sim.heroes[0].pos = Vector2(400, 360)
	battle.free()
	print("STAGE_EXIT_ANIMATION: %d characters, %d failures" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
