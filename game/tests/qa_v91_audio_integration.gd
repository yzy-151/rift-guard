extends SceneTree
## Uses the real controller while isolating every save under the requested cache.
var game
var output: String = ""
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			output = arg.trim_prefix("--qa-output=").replace("\\","/").simplify_path()
	if not output.is_absolute_path() or not output.to_lower().begins_with("c:/users/yzy/desktop/codex/"):
		printerr("Provide --qa-output as an absolute task directory under C:/Users/yzy/Desktop/codex/")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func seed_voice() -> void:
	game.battle_audio.reset()
	game.battle_audio.set_enabled(true)
	game.battle_audio.handle_events([{"kind":"down","hero_id":0}],game.sim)
	check(not game.battle_audio.voice.is_empty() and not game.battle_audio.queued.is_empty(), "fixture has a live voice and delayed effect")

func check_cleared(label: String) -> void:
	var state: Dictionary = game.battle_audio.debug_snapshot()
	check(state.voice_key=="" and state.active_sfx==0 and state.queued==0 and is_zero_approx(state.duck_db), label)

func run() -> void:
	game = load("res://main.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	game.test_mode = true
	game._stop_scene_audio(game)
	game.battle_audio.playback_enabled = false
	check(str(game.qa_storage_path).replace("\\","/").begins_with(output+"/"), "controller saves are isolated from player data")
	var squad: Array[String] = ["hero_06"]
	game.sim.reset_stage("stage_01",squad,91)
	game.test_mode = false
	game.sim.events.clear()
	game.sim.events.append({"kind":"down","hero_id":0,"pos":game.sim.heroes[0].pos})
	game.process_events()
	check(game.battle_audio.debug_snapshot().voice_key=="hero_06_down", "main resolves simulation hero_id to the actual character")
	game.apply_setting("sfx",0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "settings mute the parent SFX bus immediately")
	game.process_events()
	check_cleared("muted event processing clears battle sounds")
	game.apply_setting("sfx",0.9)
	game.test_mode = true
	seed_voice()
	await game.restart(true)
	check_cleared("restart clears old voice and delayed impact")
	seed_voice()
	game.pending_stage_id = "stage_endless"
	game.confirm_next_squad(squad)
	check_cleared("direct endless entry clears the previous battle voice")
	seed_voice()
	game.pending_endless_inheritance = game.sim.export_run_snapshot()
	game.start_inherited_endless()
	check_cleared("inherited endless entry clears the previous battle voice")
	seed_voice()
	game.open_mode_menu()
	check_cleared("mode menu clears battle audio")
	seed_voice()
	game.enter_home()
	check_cleared("home clears battle audio")
	seed_voice()
	game._stop_scene_audio(game)
	var before: int = game.battle_audio.played
	game.battle_audio.advance(0.12)
	check_cleared("scene exit clears pending cues before changing scenes")
	check(game.battle_audio.played==before,"no delayed sound restarts during the exit wait")
	game._stop_scene_audio(game)
	game.free()
	OS.delay_msec(160)
	await process_frame
	print("V91 AUDIO INTEGRATION checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
