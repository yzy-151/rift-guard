extends RefCounted

const Pointer = preload("res://scripts/qa_v17.gd")
const Resolver = preload("res://scripts/campaign_node_resolver.gd")
var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		print("V33 RESTART PASS: " + message)
	else:
		failures += 1
		push_error("V33 RESTART FAIL: " + message)

func run(game) -> void:
	var role := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-role="):
			role = arg.trim_prefix("--qa-role=")
	var state = game.sim.run_state
	var store = game.checkpoint_store
	var database = game.sim.database
	var squad: Array[String] = ["traveler", "hero_03"]
	expect(game.qa_storage_path.begins_with("user://qa-v33-restart-"), "shared session stays inside isolated QA storage")
	if role == "write":
		expect(not bool(store.load_checkpoint(database).ok), "writer starts with an unused checkpoint directory")
		game.choose_mode("rift_watch")
		game.choose_stage("stage_02")
		game.confirm_next_squad(squad)
		game.story.skip()
		game.end_dialogue()
		state.rift_shards = 240
		state.campaign_luck = 0.18
		state.add_campaign_perk("fortify")
		state.add_relationship("hero_12", 2)
		state.set_story_flag("trusted_signal")
		state.rewarded_stages["stage_01"] = 40
		game.squad_panel.root.hide()
		game.sim.state = "won"
		state.current_node = "c1_story"
		game.campaign_map_panel.open()
		await Pointer.new().click_control(game, game.campaign_map_panel.buttons["c1_shop"])
		var saved: Dictionary = store.load_checkpoint(database)
		expect(bool(saved.ok) and saved.snapshot.phase == "event", "writer persists a pending event before process exit")
		expect(game.campaign_event_panel.is_open(), "writer exits from the actual event screen")
	elif role in ["resume", "settled"]:
		game.open_mode_menu()
		expect(not game.mode_select_panel.continue_button.disabled, "new process discovers the saved continue entry")
		await Pointer.new().click_control(game, game.mode_select_panel.continue_button)
		expect(not game.mode_select_panel.is_open() and state.squad == squad, "new process continues the saved squad through the menu")
		expect(game.sim.current_stage_id == "stage_02" and state.current_node == "c1_shop", "stage and route survive a process restart")
		expect(is_equal_approx(state.campaign_luck, 0.18) and game.sim.base_max_hp == 125, "persistent luck and fortification reach the restored simulation")
		expect(state.relationships.get("hero_12") == 2 and state.story_flags.get("trusted_signal") == true, "relationships and story flags survive a process restart")
		expect(state.grant_stage_reward("stage_01", 100, 100, true) == 0, "old stage cannot award currency in a new process")
		if role == "resume":
			expect(game.campaign_event_panel.is_open() and state.rift_shards == 240, "pending event and currency resume together")
			await Pointer.new().click_control(game, game.campaign_event_panel.option_buttons[0])
			expect(game.campaign_event_panel.resolved and state.rift_shards == 185, "real event click pays once and persists its result")
		else:
			expect(game.campaign_map_panel.is_open() and not game.campaign_event_panel.is_open(), "third process resumes the route after the settled event")
			expect(state.rift_shards == 185 and state.resolved_nodes.has("c1_shop") and state.equipped_relics.size() == 1, "purchased relic, remaining currency and one-shot ledger survive restart")
			var duplicate := {"node_id": "c1_shop", "cost": 0, "kind": "supply", "value": 70, "id": "duplicate"}
			expect(not bool(Resolver.new().apply_option(duplicate, state).ok) and state.rift_shards == 185, "new process rejects a second event reward")
	else:
		expect(false, "restart role must be write, resume or settled")
	print("V33 RESTART PROCESS: %d %s" % [OS.get_process_id(), role])
	print("V33 RESTART QA COMPLETE: %d checks, %d failures" % [checks, failures])
	for player: Node in game.find_children("*", "AudioStreamPlayer", true, false):
		player.stop()
		player.stream = null
	await game.get_tree().create_timer(0.6).timeout
	game.get_tree().quit(failures)
