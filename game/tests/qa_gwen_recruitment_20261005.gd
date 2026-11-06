extends SceneTree

const State = preload("res://scripts/compendium_state.gd")
const Sim = preload("res://scripts/combat_simulation.gd")
const Checkpoint = preload("res://scripts/campaign_checkpoint.gd")
var checks := 0
var failures: Array[String] = []
var qa_directory := ""
var app

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("GWEN RECRUITMENT QA: " + label)

func _state_file(label: String, payload: Dictionary):
	var path := qa_directory.path_join(label + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	return State.new(path)

func _legacy(unlocks: Array, clears: Array = []) -> Dictionary:
	return {"save_version": 25, "unlocked_characters": unlocks, "cleared_stages": clears,
		"discovered_cards": ["qa_preserved_card"], "encountered_enemies": ["hilichurl_brute"],
		"stage_records": {"stage_01": {"best_kills": 19}},
		"achievement_stats": {"total_kills": 21}, "unlocked_achievements": {"qa_keep": {"unlocked_at": "old"}}}

func _squad(ids: Array) -> Array[String]:
	var result: Array[String] = []
	result.assign(ids)
	return result

func _graph(option: int) -> void:
	var remaining := 40
	while app.story.active and remaining > 0:
		if app.story.has_choices(): app.story.choose(option)
		else: app.story.advance()
		remaining -= 1
	check(not app.story.active, "authored dialogue reaches its ending")

func _panel_progress(progress) -> void:
	app.compendium = progress
	app.squad_panel.progress = progress

func _migration_checks() -> void:
	var legacy = _state_file("polluted-legacy", _legacy(["traveler", "hero_03", "hero_13"]))
	check(not legacy.unlocked_characters.has("hero_13") and not legacy.has_gwen_recruitment(), "old guest-only Gwen unlock is repaired")
	check(legacy.unlocked_characters.has("hero_03") and legacy.discovered_cards.has("qa_preserved_card") and legacy.encountered_enemies.has("hilichurl_brute"), "repair preserves Furina, cards and enemy archive")
	check(legacy.stage_records.stage_01.best_kills == 19 and legacy.achievement_stats.total_kills == 21 and legacy.unlocked_achievements.has("qa_keep"), "repair preserves records and achievements")
	legacy.save_progress()
	var repaired = State.new(legacy.save_path)
	check(not repaired.can_select_character("hero_13") and repaired.legacy_gwen_unlock, "repaired save persists while retaining legacy checkpoint compatibility")
	var completed = _state_file("legitimate-legacy", _legacy(["traveler", "hero_03", "hero_13"], ["stage_01"]))
	check(completed.can_select_character("hero_13") and completed.has_gwen_recruitment(), "old completed successful greeting keeps recruited Gwen")
	completed.save_progress()
	check(State.new(completed.save_path).has_gwen_recruitment(), "migrated legitimate recruitment survives reload")
	var modern_payload := _legacy(["traveler", "hero_03", "hero_13"], ["stage_01"])
	modern_payload.story_recruit_revision = 1
	modern_payload.story_recruits = {}
	var modern = _state_file("unproven-modern", modern_payload)
	check(not modern.can_select_character("hero_13"), "a modern stage-clear mark alone is never recruitment proof")
	check(not modern.unlock_character("hero_13") and not modern.record_story_recruit("hero_13", "mode1_opening"), "generic unlock and wrong-scene unlock cannot recruit Gwen")
	modern.clear_stage("stage_01", ["hero_13"])
	check(not modern.can_select_character("hero_13") and not State.new(modern.save_path).has_gwen_recruitment(), "stage rewards cannot bypass Gwen story outcome")

func _campaign_checks() -> void:
	check(app.compendium.unlocked_characters.keys() == ["traveler"], "fresh progression starts with only Traveler")
	check(app.sim.heroes.size() == 2 and app.sim.heroes[1].character_id == "hero_13" and app.sim.heroes[1].deployed and app.sim.heroes[1].get("temporary_assist", false), "first stage contains a deployed temporary Gwen")
	check(app.sim.run_state.squad == ["traveler"] and app.sim.run_state.temporary_assists == ["hero_13"], "field guest is separate from permanent squad")
	for observation in 12: app.compendium.observe(app.sim)
	check(not app.compendium.unlocked_characters.has("hero_13"), "ordinary battlefield observation never unlocks the guest")
	app.squad_panel.open("stage_01", _squad(["traveler", "hero_13"]), ["hero_13"])
	check(app.squad_panel.buttons.hero_13.disabled and app.squad_panel.selected == ["traveler"], "first-stage Gwen card is disabled even if passed as newly unlocked")
	app.squad_panel._open_detail("hero_13")
	check(not app.squad_panel.detail_panel.visible, "locked Gwen cannot open a selectable detail card")
	app.squad_panel.detail_id = "hero_13"
	app.squad_panel._confirm_detail()
	check(app.squad_panel.selected == ["traveler"], "stale detail selection cannot add unearned Gwen")
	app.squad_panel.root.hide()
	app.story.reset(); app.story_resume = "pre_stage"
	check(app.story.begin("mode1_opening"), "authored Furina opening starts")
	_graph(0)
	check(app.compendium.can_select_character("hero_03") and not app.compendium.can_select_character("hero_13"), "successful Furina opening unlocks only Furina")
	app.pending_stage_id = "stage_01"; app.pending_stage_number = 1; app.pending_stage_intro_completed = true
	app.confirm_next_squad(_squad(["traveler", "hero_03", "hero_13"]))
	check(app.sim.run_state.squad == ["traveler", "hero_03"] and app.sim.heroes.size() == 3, "actual squad entry filters unearned Gwen while keeping Furina and guest")
	check(app.sim.heroes[2].get("temporary_assist", false) and app.sim.heroes[2].deployed, "filtered Gwen still joins this battlefield as an already deployed guest")
	check(app.sim.export_run_snapshot().heroes.size() == 2 and app.sim.export_run_snapshot().squad == ["traveler", "hero_03"], "temporary guest is not inherited into endless party")
	app.sim.state = "won"
	app.check_story()
	check(app.sim.state == "stage_exit" and app.battle.stage_exit_active and not app.compendium.has_gwen_recruitment(), "winning combat starts greeting without recruiting Gwen")
	var original: Dictionary = app.story.graph_scenes.mode1_won.duplicate(true)
	for node: Dictionary in app.story.graph_scenes.mode1_won.nodes:
		if node.type == "ending": node.status = "badend"
	app.story.reset(); app.story_resume = "stage_recruit"
	check(app.story.begin("mode1_won"), "failed greeting fixture uses the actual authored graph")
	_graph(0)
	check(app.pending_campaign_outcome == "failure" and not app.compendium.has_gwen_recruitment() and not bool(app.sim.run_state.story_flags.get("gwen_recruited", true)), "bad ending records rejection without creating recruitment proof")
	app.compendium.observe(app.sim)
	check(not app.compendium.can_select_character("hero_13"), "observation after failed greeting remains locked")
	app.story.graph_scenes.mode1_won = original.duplicate(true)
	app.previewing = true
	app.story.reset(); app.story_resume = "stage_recruit"
	app.story.begin("mode1_won"); _graph(0)
	check(not app.compendium.has_gwen_recruitment(), "previewing a successful ending does not grant recruitment")
	app.previewing = false
	app.story.reset(); app.story_resume = "stage_recruit"
	app.story.begin("mode1_won"); _graph(0)
	check(app.pending_campaign_outcome == "success" and app.compendium.has_gwen_recruitment() and app.sim.run_state.story_flags.get("gwen_recruited", false), "real success ending writes both permanent receipt and checkpoint flag")
	check(State.new(app.compendium.save_path).can_select_character("hero_13"), "successful recruitment is saved before departure animation")
	app.squad_panel.open("stage_02", _squad(["traveler", "hero_03", "hero_13"]))
	check(not app.squad_panel.buttons.hero_13.disabled and app.squad_panel.selected.has("hero_13"), "Gwen becomes selectable after the actual success ending")
	app.squad_panel.root.hide()
	app.pending_stage_id = "stage_02"; app.pending_stage_number = 2; app.pending_stage_intro_completed = true
	app.confirm_next_squad(_squad(["traveler", "hero_03", "hero_13"]))
	check(app.sim.run_state.squad == ["traveler", "hero_03", "hero_13"] and app.sim.run_state.temporary_assists.is_empty(), "next stage contains permanent Gwen without creating another guest")

func _checkpoint_checks() -> void:
	var polluted = _state_file("checkpoint-polluted-progress", _legacy(["traveler", "hero_03", "hero_13"]))
	_panel_progress(polluted)
	var old_sim = Sim.new(9811, true)
	old_sim.reset_stage("stage_01", ["traveler", "hero_03", "hero_13"], 9811)
	var snapshot := Checkpoint.snapshot(old_sim, "battle")
	app.checkpoint_store = Checkpoint.new(qa_directory.path_join("bad-guest-checkpoint"))
	check(app.checkpoint_store.save_checkpoint(snapshot, app.sim.database), "legacy polluted battle checkpoint is valid")
	app.battle.reset_transients(); app.story.reset()
	check(app.resume_campaign(), "legacy battle checkpoint resumes successfully")
	check(app.sim.run_state.squad == ["traveler", "hero_03"] and not app.compendium.can_select_character("hero_13"), "resume does not promote checkpoint guest into a recruit")
	check(app.sim.heroes.size() == 3 and app.sim.heroes[2].get("temporary_assist", false) and app.sim.heroes[2].deployed, "resuming first-stage battle restores Gwen only as a deployed guest")
	var legitimate = _state_file("checkpoint-completed-progress", _legacy(["traveler", "hero_03", "hero_13"]))
	_panel_progress(legitimate)
	old_sim.reset_stage("stage_01", ["traveler", "hero_03"], 9812)
	snapshot = Checkpoint.snapshot(old_sim, "cleared")
	app.checkpoint_store = Checkpoint.new(qa_directory.path_join("completed-greeting-checkpoint"))
	check(app.checkpoint_store.save_checkpoint(snapshot, app.sim.database), "legacy completed greeting checkpoint is valid")
	app.open_mode_menu()
	check(app.compendium.can_select_character("hero_13") and State.new(app.compendium.save_path).has_gwen_recruitment(), "main menu restores genuine old recruitment before pressing Continue")
	check(app.resume_campaign() and app.compendium.can_select_character("hero_13"), "completed legacy greeting checkpoint preserves real recruitment before stage two")
	var rejected = _state_file("checkpoint-rejected-legacy", _legacy(["traveler", "hero_03", "hero_13"]))
	_panel_progress(rejected)
	app.sim.current_stage_id = "stage_01"; app.sim.state = "stage_exit"; app.story.key = "mode1_won"; app.story_resume = "stage_recruit"
	app._authored_ending_resolved({"status": "badend", "unlock_character": "hero_13"})
	check(not rejected.legacy_gwen_unlock and not app.sim.run_state.story_flags.gwen_recruited, "actual failed greeting clears only unearned legacy inference and records rejection")
	rejected.restore_story_recruitment(snapshot)
	check(not rejected.can_select_character("hero_13"), "a rejected guest cannot be re-unlocked from a clear mark alone")
	var modern = _state_file("checkpoint-modern-failure", {"save_version": 25, "unlocked_characters": ["traveler", "hero_03"], "story_recruit_revision": 1, "story_recruits": {}, "cleared_stages": ["stage_01"]})
	modern.restore_story_recruitment(snapshot)
	check(not modern.has_gwen_recruitment(), "modern clear checkpoint without success receipt cannot auto-recruit")
	snapshot.run.story_flags.gwen_recruited = true
	modern.restore_story_recruitment(snapshot)
	check(modern.can_select_character("hero_13"), "explicit saved success flag recovers recruitment if progress file is older")
	var next_stage_legacy = _state_file("checkpoint-stage-two", _legacy(["traveler", "hero_03", "hero_13"]))
	old_sim.reset_stage("stage_02", ["traveler", "hero_03"], 9813)
	next_stage_legacy.restore_story_recruitment(Checkpoint.snapshot(old_sim, "battle"))
	check(next_stage_legacy.can_select_character("hero_13"), "older stage-two checkpoint retains an already recruited Gwen")

func _run() -> void:
	qa_directory = "user://qa-gwen-%d-%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_directory))
	_migration_checks()
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true; app.set_process(false); app.set_physics_process(false)
	app.battle.set_process(false); app.mode_select_panel.close()
	_campaign_checks()
	_checkpoint_checks()
	check(checks == 46, "all QA scenarios ran to completion")
	print("GWEN RECRUITMENT QA: %d checks, %d failures" % [checks, failures.size()])
	# Release QA playback and let deferred/mixer work settle before shutting
	# down the fast headless release executable.
	for player: Node in app.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	app.queue_free()
	app = null
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	quit(0 if failures.is_empty() else 1)
