extends RefCounted

const Checkpoint = preload("res://scripts/campaign_checkpoint.gd")
const Sim = preload("res://scripts/combat_simulation.gd")
const Resolver = preload("res://scripts/campaign_node_resolver.gd")
const Pointer = preload("res://scripts/qa_v17.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V33 PASS: " + message)
	else:
		failures += 1
		push_error("V33 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await game.get_tree().create_timer(0.25).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v33-validation")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):
			directory = arg.trim_prefix("--qa-output=")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	expect(image != null and image.save_png(directory.path_join(name + ".png")) == OK, "visual evidence saved: " + name)

func write_text(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(content)
		file.close()

func run(game) -> void:
	var database = game.sim.database
	var state = game.sim.run_state
	var store = game.checkpoint_store
	game.open_mode_menu()
	expect(game.compendium.save_path.contains("qa-") and store.path.contains("qa-") and game.audio_director.save_path.contains("qa-"), "QA progress, settings and checkpoints are isolated from player saves")
	expect(game.mode_select_panel.continue_button.disabled, "fresh install disables continue without a checkpoint")
	expect(not game.resume_campaign(), "missing checkpoint leaves menu open")
	game.choose_mode("rift_watch")
	game.choose_stage("stage_02")
	var squad: Array[String] = ["traveler", "hero_03"]
	game.confirm_next_squad(squad)
	game.squad_panel.root.hide()
	var briefing: Dictionary = store.load_checkpoint(database)
	expect(briefing.snapshot.phase == "briefing", "formation checkpoint retains unfinished opening dialogue")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.story.active, "continuing a briefing reopens unfinished dialogue")
	game.story.skip()
	game.end_dialogue()
	expect(store.load_checkpoint(database).snapshot.phase == "battle", "completed opening commits a battle checkpoint")
	game.story.reset()
	game.dialogue.root.hide()
	expect(bool(store.load_checkpoint(database).ok), "formation confirmation writes a real stage-entry checkpoint")
	expect(state.current_node == "c1_elite", "direct stage selection aligns its campaign node")

	state.rift_shards = 240
	state.current_node = "c1_shop"
	state.completed_nodes.assign(["c1_combat_1", "c1_story"])
	state.add_campaign_perk("fortify")
	state.add_campaign_perk("charged_start")
	state.add_relationship("hero_12", 2)
	state.set_story_flag("trusted_signal")
	state.grant_relic("relic_glass_cannon")
	state.rewarded_stages["stage_01"] = 40
	state.campaign_luck = 0.18
	var snapshot: Dictionary = Checkpoint.snapshot(game.sim, "event")
	expect(Checkpoint.validate(snapshot, database).is_empty(), "all campaign fields form a valid event checkpoint")
	expect(store.save_checkpoint(snapshot, database), "checkpoint saves after previous stage-entry record")
	var fresh_store = Checkpoint.new(store.path)
	var loaded: Dictionary = fresh_store.load_checkpoint(database)
	expect(bool(loaded.ok) and loaded.snapshot.run.rift_shards == 240, "a fresh reader restores latest on-disk checkpoint")
	expect(loaded.snapshot.run.completed_nodes.size() == 2 and loaded.snapshot.run.resolved_nodes.is_empty(), "route completion and pending choice round-trip")
	expect(int(loaded.snapshot.seed) == game.sim.run_seed, "stage seed round-trips")

	var restored = Sim.new(3300, true)
	expect(Checkpoint.restore(loaded.snapshot, restored), "checkpoint applies to a fresh simulation")
	expect(restored.run_state.squad == squad and restored.current_stage_id == "stage_02", "squad and stage restore together")
	expect(restored.run_state.relationships.get("hero_12") == 2 and restored.run_state.story_flags.get("trusted_signal") == true, "relationship thresholds and story flags survive restore")
	expect(restored.base_max_hp == 125 and restored.heroes[0].energy >= 18, "restored expedition perks reach combat stats")
	expect(restored.run_state.active_resonances.has("star_and_tide") and restored.heroes[0].damage > restored.heroes[0].base_damage, "relic and resonance effects recompute from restored composition")
	expect(restored.run_state.buff_levels.is_empty() and restored.enemies.is_empty(), "checkpoint restarts stage without stale enemies or local cards")
	expect(restored.run_state.grant_stage_reward("stage_01", 100, 100, true) == 0, "reward ledger prevents claiming cleared stage again after restore")

	for invalid_field: String in ["squad", "completed_nodes", "relics", "campaign_perks", "relationships", "story_flags", "resolved_nodes", "rewarded_stages"]:
		var malformed: Dictionary = snapshot.duplicate(true)
		malformed.run[invalid_field] = "invalid"
		expect(not Checkpoint.validate(malformed, database).is_empty(), "malformed field rejected: " + invalid_field)
	var bad: Dictionary = snapshot.duplicate(true)
	bad.version = 999
	expect(not Checkpoint.restore(bad, restored) and restored.run_state.rift_shards == 240, "unknown schema rejects before touching live state")
	bad = snapshot.duplicate(true)
	bad.run.squad = ["traveler", "missing_character"]
	expect(not Checkpoint.validate(bad, database).is_empty(), "unknown character rejected")
	bad.run.squad = ["traveler", "traveler"]
	expect(not Checkpoint.validate(bad, database).is_empty(), "duplicate party members rejected")
	bad = snapshot.duplicate(true)
	bad.stage_id = "stage_endless"
	expect(not Checkpoint.validate(bad, database).is_empty(), "endless cannot enter campaign checkpoint")
	bad = snapshot.duplicate(true)
	bad.run.rift_shards = -1
	expect(not Checkpoint.validate(bad, database).is_empty(), "negative currency rejected")
	bad.run.rift_shards = 1.5
	expect(not Checkpoint.validate(bad, database).is_empty(), "fractional currency rejected")
	bad = snapshot.duplicate(true)
	bad.run.campaign_perks = {"unknown_perk": 1}
	expect(not Checkpoint.validate(bad, database).is_empty(), "unknown expedition perk rejected")
	bad = snapshot.duplicate(true)
	bad.run.node = "c1_combat_1"
	expect(not Checkpoint.validate(bad, database).is_empty(), "event checkpoint cannot point to a combat node")

	var fail_store = Checkpoint.new(store.path + "-missing/child")
	expect(not fail_store.save_checkpoint(snapshot, database) and fail_store.last_message.contains("保存失败"), "unwritable destination reports a save error")
	expect(bool(store.load_checkpoint(database).ok), "failed save elsewhere preserves valid campaign checkpoint")
	var corruption_store = Checkpoint.new(store.path + "-corruption")
	expect(corruption_store.save_checkpoint(snapshot, database), "first recovery slot written")
	var newer: Dictionary = snapshot.duplicate(true)
	newer.run.rift_shards = 300
	expect(corruption_store.save_checkpoint(newer, database), "second recovery slot written")
	var latest: Dictionary = corruption_store.load_checkpoint(database)
	write_text(corruption_store.path + ".%d.json" % int(latest.slot), "{\"partial\":")
	var recovered: Dictionary = corruption_store.load_checkpoint(database)
	expect(bool(recovered.ok) and bool(recovered.recovered) and recovered.snapshot.run.rift_shards == 240, "truncated latest slot recovers previous complete record")
	var valid_slot := int(recovered.slot)
	var tampered := JSON.stringify(snapshot)
	write_text(corruption_store.path + ".%d.json" % valid_slot, JSON.stringify({"sequence": 12, "payload": tampered, "sha256": "wrong"}))
	expect(not bool(corruption_store.load_checkpoint(database).ok), "bad checksum and truncated backup fail without applying data")
	expect(corruption_store.save_checkpoint(snapshot, database), "new checkpoint can recover an unusable pair")

	game.return_to_main_menu()
	expect(game.mode_select_panel.checkpoint_title.text.contains("240") and not game.mode_select_panel.continue_button.disabled, "menu shows latest currency and enabled continue")
	expect(game.mode_select_panel.checkpoint_detail.text.contains("芙宁娜"), "menu exposes saved squad")
	await capture(game, "01-continue-expedition")
	await Pointer.new().click_control(game, game.mode_select_panel.continue_button)
	expect(game.campaign_event_panel.is_open() and not game.mode_select_panel.is_open(), "real continue click restores pending event directly")
	var option: Dictionary = game.campaign_event_panel.options[0].duplicate(true)
	var before: int = state.rift_shards
	await Pointer.new().click_control(game, game.campaign_event_panel.option_buttons[0])
	expect(game.campaign_event_panel.resolved and state.rift_shards == before - int(option.cost), "resumed event pointer choice spends currency once")
	var purchased: Dictionary = store.load_checkpoint(database)
	expect(purchased.snapshot.phase == "route" and purchased.snapshot.run.resolved_nodes.has("c1_shop"), "resolved event immediately persists its one-shot ledger")
	await capture(game, "02-resumed-event-result")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.campaign_map_panel.is_open(), "resolved event resumes on route instead of offering reward again")
	expect(not bool(Resolver.new().apply_option(option, state).ok), "event cannot be purchased twice after reloading")
	game.campaign_map_panel.close()
	game.open_campaign_map()
	expect(game.campaign_map_panel.is_open(), "restored route remains accessible through the public map action")
	game.choose_campaign_node("c1_recruit")
	expect(game.campaign_event_panel.is_open() and game.checkpoint_phase == "event", "restored route can still enter its next pending event")
	game.checkpoint_store = fail_store
	await Pointer.new().click_control(game, game.campaign_event_panel.option_buttons[0])
	expect(game.campaign_event_panel.resolved and game.checkpoint_error.contains("保存失败"), "successful event reports checkpoint write failure separately")
	var warning_layer: CanvasLayer = game.checkpoint_warning.get_canvas_layer_node()
	var overlay_is_above: bool = warning_layer != null and warning_layer != game.hud and warning_layer.layer > game.campaign_event_panel.layer and warning_layer.layer > game.campaign_map_panel.layer and warning_layer.layer > game.dialogue.layer
	expect(overlay_is_above and game.checkpoint_warning.is_visible_in_tree(), "save failure remains visible above full-screen event, map and dialogue panels")
	expect(game.checkpoint_warning.mouse_filter == Control.MOUSE_FILTER_IGNORE, "save failure notification does not intercept pointer input")
	game.hud.get_child(0).hide()
	expect(game.checkpoint_warning.is_visible_in_tree(), "save failure remains visible when dialogue hides the HUD")
	game.hud.get_child(0).show()
	expect(game.checkpoint_phase == "route", "failed event save still advances live route phase")
	await capture(game, "04-checkpoint-save-error")
	game.checkpoint_store = store
	expect(game.save_campaign_checkpoint("route") and game.checkpoint_error.is_empty() and not game.checkpoint_warning.is_visible_in_tree(), "successful retry clears the visible save failure")
	game.campaign_event_panel.close()

	var luck_options: Array[Dictionary] = Resolver.new().build_options({"id":"c2_shop", "type":"shop"}, state, database)
	state.rift_shards = 999
	var luck_option: Dictionary = luck_options.filter(func(row: Dictionary) -> bool: return row.kind == "luck")[0]
	expect(bool(Resolver.new().apply_option(luck_option, state).ok), "shop luck offer applies")
	var saved_luck: float = state.campaign_luck
	game.sim.reset_stage("stage_03", squad, 3303)
	expect(saved_luck > 0.18 and state.luck >= saved_luck, "shop luck survives stage reset")
	game.sim.reset_stage("stage_04", squad, 3304)
	expect(is_equal_approx(state.campaign_luck, saved_luck) and state.luck >= saved_luck, "persistent luck reapplies without accumulating every reset")

	game.campaign_map_panel.close()
	game.sim.run_state.current_node = "c2_combat_4"
	game.save_campaign_checkpoint("battle")
	var before_loss: Dictionary = store.load_checkpoint(database)
	game.story.reset()
	game.sim.state = "lost"
	game.check_story()
	expect(game.story.active and game.story.key == "mode1_lost", "defeat opens its actual dialogue")
	game.story.skip()
	game.end_dialogue()
	expect(int(store.load_checkpoint(database).sequence) == int(before_loss.sequence), "finishing defeat dialogue never replaces battle checkpoint with route")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.sim.state == "running" and not game.campaign_map_panel.is_open(), "continuing after defeat replays the stage instead of bypassing it")
	game.toggle_pause()
	game.open_campaign_map()
	expect(not game.campaign_map_panel.is_open(), "paused battle after defeat cannot open a route that skips the stage")
	game.campaign_map_panel.close()
	game.campaign_map_panel._build_nodes()
	game.choose_campaign_node("c2_elite_5")
	expect(game.pending_stage_id.is_empty() and state.current_node == "c2_combat_4" and not game.squad_panel.is_open(), "direct route selection cannot bypass an unfinished restored battle")
	game.squad_panel.root.hide()
	game.pending_stage_id = ""
	state.current_node = "c2_combat_4"
	var previous_shards: int = state.rift_shards
	game.sim.state = "lost"
	game.stage_result_recorded = false
	game.record_stage_result()
	expect(state.rift_shards == previous_shards and not state.rewarded_stages.has("stage_04"), "defeat grants no campaign currency or reward ledger entry")
	game.sim.state = "won"
	game.sim.kills = 63
	game.sim.base_hp = 47
	game.sim.best_streak = 19
	game.sim.reactions = 12
	game.stage_result_recorded = false
	game.record_stage_result()
	var victory_shards: int = state.rift_shards
	expect(victory_shards > previous_shards and state.rewarded_stages.has("stage_04"), "victory grants campaign currency")
	game.record_stage_result()
	expect(state.rift_shards == victory_shards, "result callback cannot grant rewards twice")
	expect(int(game.compendium.build_history[0].rift_shards) == victory_shards, "build history records currency after settlement")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.sim.state == "won" and game.stage_result_recorded, "cleared checkpoint resumes post-victory with settlement already recorded")
	expect(game.squad_panel.selected == squad and game.compendium.unlocked_characters.has("hero_03"), "next-stage formation retains checkpoint squad even with a fresh progress file")
	expect(game.squad_panel.is_open() and game.pending_stage_id == "stage_05", "cleared checkpoint exposes next-stage formation without requiring stage hotkeys")
	expect(game.sim.kills == 63 and game.sim.base_hp == 47 and game.sim.best_streak == 19 and game.sim.reactions == 12, "restored victory displays its actual settled combat statistics")
	await capture(game, "03-next-stage-formation")
	game.squad_panel.root.hide()
	game.pending_stage_id = ""
	var before_restart: Dictionary = store.load_checkpoint(database)
	game.checkpoint_store = fail_store
	expect(not game.save_campaign_checkpoint("cleared"), "cleared stage write failure is reproducible before retrying battle")
	game.restart()
	game.open_campaign_map()
	expect(game.checkpoint_phase == "briefing" and not game.campaign_map_panel.is_open(), "restarting a cleared stage resets route access even when checkpoint writing fails")
	expect(int(store.load_checkpoint(database).sequence) == int(before_restart.sequence), "restart preserves the previous checkpoint until its opening completes")
	game.checkpoint_store = store
	game.sim.reset_stage("stage_03", squad, 3333)
	state.current_node = "c1_boss"
	game.sim.state = "won"
	game.save_campaign_checkpoint("cleared")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.squad_panel.is_open() and game.pending_stage_id == "stage_04", "chapter-one boss checkpoint continues directly into chapter-two formation")
	game.squad_panel.root.hide()
	game.campaign_map_panel.close()
	game.sim.reset_stage("stage_02", squad, 3340)
	state.current_node = "c1_elite"
	game.save_campaign_checkpoint("battle")
	game.return_to_main_menu()
	expect(game.resume_campaign() and game.sim.state == "running" and game.sim.elapsed == 0.0, "battle checkpoint resumes at stage start and runs")
	game.return_to_main_menu()
	game.choose_mode("rift_watch")
	game.choose_stage("stage_01")
	game.confirm_next_squad(squad)
	game.squad_panel.root.hide()
	game.story.advance()
	game.story.advance()
	var opening_choice: Dictionary = game.story.current().choices[0].duplicate(true)
	game.apply_dialogue_choice(opening_choice)
	game.story.skip()
	game.end_dialogue()
	var opening_relation: int = int(state.relationships.get("traveler", 0))
	var opening_luck: float = state.luck
	game.return_to_main_menu()
	expect(game.resume_campaign() and not game.story.active and int(state.relationships.get("traveler", 0)) == opening_relation, "completed opening restores relationship without replaying its choice")
	expect(is_equal_approx(state.luck, opening_luck), "opening luck is retained when restarting from saved battle entry")
	game.toggle_pause()
	game.open_campaign_map()
	expect(not game.campaign_map_panel.is_open(), "opening choice moving the route node cannot unlock route travel during battle")
	game.campaign_map_panel.close()
	game.campaign_map_panel._build_nodes()
	var opening_node: String = state.current_node
	game.choose_campaign_node("c1_rest")
	expect(state.current_node == opening_node and not game.campaign_event_panel.is_open(), "direct event selection is blocked after an opening changes the route node")
	game.campaign_event_panel.root.hide()
	var campaign_record: Dictionary = store.load_checkpoint(database)
	game.choose_mode("endless_survival")
	game.sim.state = "lost"
	game.stage_result_recorded = false
	game.record_stage_result()
	expect(state.rift_shards == 0 and state.rewarded_stages.is_empty(), "endless result never grants campaign currency")
	expect(int(store.load_checkpoint(database).sequence) == int(campaign_record.sequence), "playing endless preserves the campaign checkpoint")
	print("V33 QA COMPLETE: %d checks, %d failures" % [checks, failures])
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await game.get_tree().create_timer(0.6).timeout
	game.get_tree().quit(failures)
