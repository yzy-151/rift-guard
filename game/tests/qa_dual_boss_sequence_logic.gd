extends SceneTree
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	if not ok: failures.append(message); push_error(message)
func run():
	var battle = load("res://scripts/battle_view.gd").new()
	var sim = load("res://scripts/combat_simulation.gd").new()
	battle.sim = sim
	var squad: Array[String] = ["traveler", "hero_01", "hero_04"]
	sim.reset_stage("stage_03", squad, 7303)
	sim.enemies.clear(); sim.enemy_lookup.clear()
	for kind in ["boss_galio", "boss_03"]:
		var boss: Dictionary = sim.spawn_enemy(Vector2(900,350), kind)
		for state in battle.enemy_sequences.definition(kind).states:
			var row: Dictionary = battle.enemy_sequences.state_definition(kind,state)
			check(float(row.fps) == 24.0, kind+state+" fps")
			check(battle.enemy_sequences.texture(kind,state) != null,kind+state+" texture")
			check(battle.enemy_sequences.frame_at_time(kind,state,100) < int(row.frames),kind+state+" frame bounds")
		battle._update_boss_sequence_visuals(0.01)
		check(battle._dual_boss_sequence_sample(boss).state == "idle",kind+" idle")
		boss.pos.x -= 2; boss.facing = -1.0
		battle._update_boss_sequence_visuals(0.1)
		check(battle._dual_boss_sequence_sample(boss).state == "run",kind+" movement")
		boss.pos.x += 2; boss.facing = 1.0
		battle._update_boss_sequence_visuals(0.1)
		check(battle._dual_boss_sequence_sample(boss).facing == 1.0,kind+" turn")
		var period: float = battle.enemy_sequences.duration(kind,"run")
		check(battle.enemy_sequences.frame_at_time(kind,"run",period+0.1) == battle.enemy_sequences.frame_at_time(kind,"run",0.1),kind+" loop")
		boss.special_pending = true
		boss.special_move = "galio_punch" if kind == "boss_galio" else "kindred_dance"
		boss.special_warning_total = 1.0; boss.special_warning = 0.5
		boss.special_warning_positions = [Vector2(600,350)]
		var draw_copy: Dictionary = boss.duplicate();draw_copy.world_pos = boss.pos;draw_copy.pos = Vector2.ZERO
		check(battle._dual_boss_sequence_sample(draw_copy).facing == -1.0,kind+" world-space cast direction")
		boss.special_pending = false
		battle._accept_boss_sequence_event({"kind":boss.special_move,"caster_id":boss.id,"pos":Vector2(600,350),"source":boss.pos})
		check(battle._dual_boss_sequence_sample(boss).state == ("punch" if kind == "boss_galio" else "dance"),kind+" release clip")
		battle._update_boss_sequence_visuals(10.0)
		check(battle._dual_boss_sequence_sample(boss).state == "idle",kind+" recovery ends")
		check(battle.enemy_sequences.frame_at_time(kind,"down",100) == battle.enemy_sequences.frame_count(kind,"down")-1,kind+" death holds last frame")
	battle.reset_transients()
	check(battle.boss_sequence_visuals.is_empty(),"stage reset clears clip state")
	battle.free()
	print("DUAL_BOSS_SEQUENCES: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
