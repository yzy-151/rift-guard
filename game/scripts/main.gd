extends Node

const Sim = preload("res://scripts/combat_simulation.gd")
const View = preload("res://scripts/battle_view.gd")
const Hud = preload("res://scripts/battle_hud.gd")
const QA = preload("res://scripts/qa_suite.gd")
const Stage = preload("res://scripts/stage_projection.gd")
const Story = preload("res://scripts/dialogue_director.gd")
const Content = preload("res://scripts/content_config.gd")
const CompendiumState = preload("res://scripts/compendium_state.gd")
const CompendiumPanel = preload("res://scripts/compendium_panel.gd")
const AchievementPopup = preload("res://scripts/achievement_popup.gd")
const SquadPanel = preload("res://scripts/squad_panel.gd")
const StageSelectPanel = preload("res://scripts/stage_select_panel.gd")
const ModeSelectPanel = preload("res://scripts/mode_select_panel.gd")
const HomePanel = preload("res://scripts/home_panel.gd")
const MobileControls = preload("res://scripts/mobile_controls.gd")
const AudioDirector = preload("res://scripts/audio_director.gd")
const WorkshopPanel = preload("res://scripts/workshop_panel.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const CampaignMapPanel = preload("res://scripts/campaign_map_panel.gd")
const CampaignEventPanel = preload("res://scripts/campaign_event_panel.gd")
const CampaignNodeResolver = preload("res://scripts/campaign_node_resolver.gd")
const CampaignCheckpoint = preload("res://scripts/campaign_checkpoint.gd")
const ENDLESS_UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
var content = Content.new()
var story = Story.new(content)
var saved_story
var previewing: bool = false
var picker
var fx
var effect_preview: float = 0.0
var dialogue
var story_resume: String = ""
var sim = Sim.new(-1, true)
var battle
var hud
var selected_id: int = 0
var muted: bool = false
var stage_enter_sound: AudioStreamPlayer
var audio_director
var combat_audio
var settings_panel
var workshop
var workshop_suspended: Array[Dictionary] = []
var workshop_audio_suspended: Array[Dictionary] = []
var workshop_audio_bus_db := 0.0
var campaign_map_panel
var campaign_event_panel
var campaign_node_resolver = CampaignNodeResolver.new()
var checkpoint_store = CampaignCheckpoint.new("user://campaign-story-v3-checkpoint")
var checkpoint_phase := "battle"
var checkpoint_active := false
var checkpoint_testing := false
var checkpoint_error := ""
var checkpoint_warning: Label
var checkpoint_overlay: CanvasLayer
var qa_storage_path := ""
var settings_from_menu := false
var pending_endless_inheritance: Dictionary = {}
var stage_clear_choice: CanvasLayer
var test_mode: bool = false
var compendium = CompendiumState.new()
var compendium_panel
var achievement_popup
var pending_achievement_ids: Array[String] = []
var squad_panel
var stage_select_panel
var mode_select_panel
var home_panel
var mobile_controls
var mobile_move_mode := false
var mobile_move_all := false
var home_facility_source := ""
var pending_home_outcome: Dictionary = {}
var pending_intro_outcome := ""
var campaign_prelude_active := false
var pending_campaign_outcome := ""
var campaign_recruits: Array[String] = []
var campaign_recruit_reselect := false
var last_home_scene: Dictionary = {}
var pending_stage_id := ""
var pending_stage_number := 0
var pending_stage_intro_completed := false
var stage_result_recorded := false
var skill_aiming := false
var ultimate_aiming := false
var keyboard_moving := false
var keyboard_move_timer := 0.0
var dragging_hero_id: int = -1
var recruited_heroes: Dictionary = {}
var pending_recruitment: Dictionary = {}
var recruitment_transition_active := false
var loss_transition_shown := false

func _ready() -> void:
	# Every QA process writes progress into its own directory, never the player's save.
	if Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.ends_with("-test") or arg.begins_with("--qa")):
		var qa_path := "user://qa-%d-%d" % [OS.get_process_id(), int(Time.get_unix_time_from_system() * 1000000)]
		if "--v33-restart-test" in OS.get_cmdline_user_args():
			for arg: String in OS.get_cmdline_user_args():
				if arg.begins_with("--qa-session="):
					var session := arg.trim_prefix("--qa-session=")
					if session.is_valid_identifier() and session.length() <= 64:
						qa_path = "user://qa-v33-restart-" + session
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_path))
		qa_storage_path = qa_path
		compendium = CompendiumState.new(qa_path.path_join("compendium.json"))
		checkpoint_store = CampaignCheckpoint.new(qa_path.path_join("campaign-checkpoint"))
	for character_id: String in sim.database.characters:
		var character_data: Dictionary = sim.database.characters[character_id]
		if not bool(character_data.get("content_ready", false)):
			compendium.unlocked_characters.erase(character_id)
		elif bool(character_data.get("unlocked_by_default", false)):
			compendium.unlocked_characters[character_id] = true
	audio_director = AudioDirector.new()
	if not qa_storage_path.is_empty():
		audio_director.save_path = qa_storage_path.path_join("settings.json")
	add_child(audio_director)
	battle = View.new()
	battle.sim = sim
	add_child(battle)
	battle.stage_exit_finished.connect(advance_stage)
	battle.stage_exit_meet.connect(_stage_exit_meet)
	fx = preload("res://scripts/sheet_effects.gd").new()
	fx.battle_view = battle
	battle.sheet_effects = fx
	battle.add_child(fx)
	hud = Hud.new()
	hud.config = content
	add_child(hud)
	hud.reward_action.connect(choose_reward)
	hud.reroll_action.connect(reroll_rewards)
	hud.primary_action.connect(primary)
	hud.pause_action.connect(toggle_pause)
	hud.restart_action.connect(restart)
	hud.select_action.connect(select_hero)
	hud.settings_action.connect(open_settings)
	hud.compendium_action.connect(toggle_compendium)
	hud.squad_action.connect(open_current_squad)
	hud.stage_action.connect(open_stage_select)
	hud.skill_action.connect(toggle_skill_aiming)
	hud.ultimate_action.connect(activate_selected_ultimate)
	hud.deploy_drag_action.connect(handle_deploy_drag)
	hud.recall_action.connect(recall_hero_to_bench)
	hud.main_menu_action.connect(return_to_main_menu)
	hud.formation_action.connect(set_formation_command)
	hud.map_action.connect(open_campaign_map)
	hud.debug_reward_action.connect(open_debug_reward)
	hud.device_purchase_requested.connect(_select_device)
	hud.device_placement_cancel_requested.connect(_cancel_device)
	hud.device_drag_hover_requested.connect(_hover_dragged_device)
	hud.device_drag_drop_requested.connect(_drop_dragged_device)
	checkpoint_overlay = CanvasLayer.new()
	checkpoint_overlay.layer = 100
	add_child(checkpoint_overlay)
	var checkpoint_frame: Panel = hud.panel(checkpoint_overlay, Rect2(40, 12, 1200, 46), Color("#32151f"), Color("#ff8797"))
	checkpoint_frame.theme = hud.get_child(0).theme
	checkpoint_warning = hud.label(checkpoint_frame, Vector2(16, 4), Vector2(1168, 38), "", 15, Color("#ffb1bc"))
	checkpoint_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	checkpoint_warning.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	checkpoint_warning.hide()
	checkpoint_overlay.hide()
	combat_audio = preload("res://scripts/combat_audio_director.gd").new()
	combat_audio.audio_director = audio_director
	add_child(combat_audio)
	stage_enter_sound = AudioStreamPlayer.new()
	stage_enter_sound.stream = preload("res://assets/helltaker/audio/button_chapter_confirm_01.wav")
	stage_enter_sound.bus = "SFX"
	stage_enter_sound.volume_db = -11
	add_child(stage_enter_sound)
	dialogue = preload("res://scripts/dialogue_panel.gd").new()
	add_child(dialogue)
	dialogue.config = content
	dialogue.build(hud, story)
	story.ending_resolved.connect(_authored_ending_resolved)
	picker = preload("res://scripts/content_preview.gd").new()
	add_child(picker)
	picker.build(self)
	compendium_panel = CompendiumPanel.new()
	add_child(compendium_panel)
	compendium_panel.build(hud, sim.database, compendium)
	compendium_panel.closed.connect(_home_archive_closed)
	achievement_popup = AchievementPopup.new()
	add_child(achievement_popup)
	achievement_popup.build(hud)
	squad_panel = SquadPanel.new()
	add_child(squad_panel)
	squad_panel.build(hud, sim.database, compendium)
	squad_panel.confirmed.connect(confirm_next_squad)
	squad_panel.cancelled.connect(_squad_selection_cancelled)
	stage_select_panel = StageSelectPanel.new()
	add_child(stage_select_panel)
	stage_select_panel.build(hud, sim.database, compendium)
	stage_select_panel.chosen.connect(choose_stage)
	stage_select_panel.cancelled.connect(_stage_select_cancelled)
	mode_select_panel = ModeSelectPanel.new()
	add_child(mode_select_panel)
	mode_select_panel.build(hud)
	mode_select_panel.chosen.connect(choose_mode)
	mode_select_panel.settings_requested.connect(open_settings)
	mode_select_panel.continue_requested.connect(resume_campaign)
	mode_select_panel.home_requested.connect(enter_home)
	mode_select_panel.archive_requested.connect(open_menu_archive)
	mode_select_panel.quit_requested.connect(func(): get_tree().quit())
	home_panel = HomePanel.new()
	add_child(home_panel)
	home_panel.build(hud, sim.database, compendium)
	home_panel.interact_requested.connect(begin_home_interaction)
	home_panel.facility_requested.connect(open_home_facility)
	home_panel.exit_requested.connect(return_to_main_menu)
	if OS.get_name() == "Android" or "--mobile-controls-test" in OS.get_cmdline_user_args():
		mobile_controls = MobileControls.new()
		add_child(mobile_controls)
		mobile_controls.build(hud)
		mobile_controls.interact_requested.connect(func(): home_panel.interact_active_target())
		mobile_controls.move_mode_requested.connect(_set_mobile_move_mode)
	var home_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/home_stories.json"))
	if home_data is Dictionary:
		story.stories.merge(home_data, true)
	campaign_map_panel = CampaignMapPanel.new()
	add_child(campaign_map_panel)
	campaign_map_panel.build(hud, sim.database, sim.run_state)
	campaign_map_panel.node_chosen.connect(choose_campaign_node)
	campaign_event_panel = CampaignEventPanel.new()
	add_child(campaign_event_panel)
	campaign_event_panel.build(hud)
	campaign_event_panel.option_chosen.connect(resolve_campaign_option)
	campaign_event_panel.closed.connect(_campaign_event_closed)
	settings_panel = SettingsPanel.new()
	add_child(settings_panel)
	settings_panel.build(hud)
	settings_panel.setting_changed.connect(apply_setting)
	settings_panel.closed.connect(settings_closed)
	settings_panel.workshop_requested.connect(open_workshop)
	settings_panel.quit_requested.connect(func(): get_tree().quit())
	apply_setting("reduced_effects", bool(audio_director.values.reduced_effects))
	dialogue.finished.connect(end_dialogue)
	dialogue.choice_committed.connect(apply_dialogue_choice)
	dialogue.fatal_choice_confirmed.connect(return_to_main_menu)
	refresh()
	if not content.errors.is_empty():
		var warning = hud.label(hud.get_child(0), Vector2(32, 102), Vector2(1215, 42), "Excel 配置未应用：" + content.errors[0] + "（完整记录：config-errors.txt）", 14, Color("#ff9c8c"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if "--v77-endless-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v77_endless_test")
	elif "--card-rework-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_card_rework_test")
	elif "--achievement-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_achievement_test")
	elif "--v74-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v74_test")
	elif "--squad-scroll-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_squad_scroll_test")
	elif "--v70-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v70_test")
	elif "--v69-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v69_visual_test")
	elif "--v68-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v68_visual_test")
	elif "--v68-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v68_test")
	elif "--v66-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v66_test")
	elif "--v67-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v67_visual_test")
	elif "--v65-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v65_visual_test")
	elif "--v65-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v65_test")
	elif "--v64-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v64_test")
	elif "--v63-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v63_test")
	elif "--reward-ui-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_reward_ui_test")
	elif "--v61-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v61_visual_test")
	elif "--v60-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v60_visual_test")
	elif "--v59-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v59_visual_test")
	elif "--v58-visual-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v58_visual_test")
	elif "--v58-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v58_test")
	elif "--v57-performance-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v57_performance_test")
	elif "--v57-map-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v57_map_test")
	elif "--v56-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v56_test")
	elif "--v55-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v55_test")
	elif "--v54-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v54_test")
	elif "--v53-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v53_test")
	elif "--v52-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v52_test")
	elif "--v51-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v51_test")
	elif "--v50-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v50_test")
	elif "--v49-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v49_test")
	elif "--v48-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v48_test")
	elif "--v34-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v34_test")
	elif "--v33-restart-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v33_restart_test")
	elif "--v33-ui-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v33_ui_test")
	elif "--v33-test" in OS.get_cmdline_user_args():
		test_mode = true
		checkpoint_testing = true
		set_physics_process(false)
		call_deferred("run_v33_test")
	elif "--v32-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v32_test")
	elif "--v31-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v31_test")
	elif "--v30-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v30_test")
	elif "--v29-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v29_test")
	elif "--v28-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v28_test")
	elif "--v27-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v27_test")
	elif "--v26-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v26_test")
	elif "--v25-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v25_test")
	elif "--v20-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v20_test")
	elif "--v19-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v19_test")
	elif "--v18-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v18_test")
	elif "--v17-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v17_test")
	elif "--v16-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v16_test")
	elif "--v15-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v15_test")
	elif "--v14-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v14_test")
	elif "--v13-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v13_test")
	elif "--v11-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v11_test")
	elif "--v12-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v12_test")
	elif "--v10-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v10_test")
	elif "--v9-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v9_test")
	elif "--v8-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v8_test")
	elif "--v6-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v6_test")
	elif "--v7-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v7_test")
	elif "--v5-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v5_test")
	elif "--config-window-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_config_window_test")
	elif "--phase1-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_phase1_test")
	elif "--v4-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_v4_test")
	elif "--m9-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m9_test")
	elif "--m5-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m5_test")
	elif "--m4-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_m4_test")
	elif "--ui-test" in OS.get_cmdline_user_args():
		test_mode = true
		set_physics_process(false)
		call_deferred("run_ui_test")
	elif "--smoke-test" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("run_smoke_test")
	else:
		call_deferred("open_mode_menu")

func _physics_process(dt: float) -> void:
	if workshop != null: return
	if story.active or campaign_prelude_active or recruitment_transition_active or picker.visible or effect_preview > 0 or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or mode_select_panel.is_open() or (home_panel != null and home_panel.is_open()) or (campaign_map_panel != null and campaign_map_panel.is_open()) or (campaign_event_panel != null and campaign_event_panel.is_open()) or (achievement_popup != null and achievement_popup.is_open()):
		return
	if sim.endless_mode:
		sim.set_active_view_rect(battle.visible_world_rect())
	_update_selected_hero_keyboard(dt)
	sim.tick(dt)
	check_story()
	process_events()
	if sim.state == "lost" and not loss_transition_shown:
		loss_transition_shown = true
		call_deferred("_play_loss_transition")
	compendium.observe(sim)
	record_stage_result()
	if not story.active:
		hud.refresh(sim, selected_id)

func record_stage_result() -> void:
	if sim.state not in ["won", "lost"] or stage_result_recorded:
		return
	if sim.state == "won":
		var stage: Dictionary = sim.database.stages.get(sim.current_stage_id, {})
		if sim.current_stage_id != "stage_01":
			compendium.clear_stage(sim.current_stage_id, stage.get("unlocks", []))
		if not sim.endless_mode:
			var node: Dictionary = CampaignCheckpoint.nodes(sim.database).get(sim.run_state.current_node, {})
			var boss: bool = str(node.get("type", "")) == "boss" or sim.current_stage_id in ["stage_03", "stage_08"]
			sim.run_state.grant_stage_reward(sim.current_stage_id, sim.kills, sim.base_hp, boss)
			if sim.current_stage_id != "stage_01":
				save_campaign_checkpoint("cleared")
	compendium.record_result(sim.current_stage_id, sim.kills, sim.base_hp, sim.best_streak)
	compendium.record_build(sim)
	var unlocked_now: Array[String] = compendium.evaluate_achievements(sim, sim.database)
	pending_achievement_ids.append_array(unlocked_now)
	stage_result_recorded = true

func _notification(what: int) -> void:
	if OS.get_name() != "Android" or not is_instance_valid(hud):
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if sim.state in ["running", "between"]:
			sim.toggle_pause()
			combat_audio.reset()
			refresh()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_mobile_back()

func _handle_mobile_back() -> void:
	if dialogue != null and dialogue.history_panel.visible:
		dialogue.close_history()
		return
	if story.active or campaign_prelude_active or recruitment_transition_active:
		return # Never choose or skip a story branch on the Android Back key.
	if settings_panel.is_open():
		settings_panel.close()
		return
	if compendium_panel.is_open():
		compendium_panel.close()
		refresh()
		return
	if skill_aiming or ultimate_aiming:
		set_skill_aiming(false)
		set_ultimate_aiming(false)
		return
	if sim.state in ["reward", "stage_exit"] or (stage_clear_choice != null and stage_clear_choice.is_open()):
		return
	if sim.state in ["running", "between", "paused"] and not mode_select_panel.is_open():
		toggle_pause()
	elif not mode_select_panel.is_open():
		return_to_main_menu()

func _process(dt: float) -> void:
	if workshop != null: return
	if mobile_controls != null:
		var at_home: bool = home_panel.is_open() and not home_panel.busy and not story.active and not settings_panel.is_open() and not compendium_panel.is_open() and not squad_panel.is_open() and not stage_select_panel.is_open() and not mode_select_panel.is_open()
		var in_battle: bool = sim.state in ["running", "between", "stage_exit"] and not story.active and not settings_panel.is_open() and not compendium_panel.is_open() and not squad_panel.is_open() and not stage_select_panel.is_open() and not mode_select_panel.is_open() and not picker.visible and not campaign_event_panel.is_open() and not campaign_map_panel.is_open() and not achievement_popup.is_open() and not at_home
		if not in_battle or skill_aiming or ultimate_aiming:
			mobile_move_mode = false
		mobile_controls.update_modes(at_home, in_battle, mobile_move_mode, mobile_move_all)
		home_panel.touch_axis = mobile_controls.movement_axis() if at_home else Vector2.ZERO
	if effect_preview > 0:
		effect_preview = maxf(0, effect_preview - dt)
		fx.advance(dt)
		if effect_preview <= 0:
			hud.signature = ""
			refresh()
	if not story.active and not campaign_prelude_active and not picker.visible and not compendium_panel.is_open() and not squad_panel.is_open() and not stage_select_panel.is_open() and not mode_select_panel.is_open() and not (home_panel != null and home_panel.is_open()) and not settings_panel.is_open() and not (achievement_popup != null and achievement_popup.is_open()) and effect_preview <= 0 and sim.state not in ["paused", "reward"]:
		sim.performance_budget.observe_render_frame(dt * 1000.0)
		battle.advance(dt)
		var force_reduced_effects := bool(audio_director.values.reduced_effects)
		if force_reduced_effects:
			battle.reduced_effects = true
		fx.reduced = force_reduced_effects or battle.reduced_effects
		fx.advance(dt)

func process_events() -> void:
	var batch: Array[Dictionary] = sim.drain_events()
	battle.accept_events(batch)
	fx.accept(batch)
	combat_audio.enabled = not muted and not test_mode
	combat_audio.accept(batch, sim, battle.visible_world_rect())
	for event in batch:
		if event.kind == "regroup":
			combat_audio.reset()
		if event.kind == "route_warning":
			hud.announce_route_warning(event)
		if event.kind == "deployment_unlocked":
			hud.announce_deployment(str(event.name))
		if event.kind == "expedition_boss_warning":
			hud.boss_warning.pitch_scale=float(event.get("pitch",0.82))
			hud.boss_warning.play()
		if event.kind == "boss_arrival":
			hud.announce_boss(str(event.value))
		if event.kind == "boss_phase":
			hud.announce_boss_phase(str(event.name), int(event.value))
		if event.kind == "boss_warning":
			hud.announce_boss_skill_warning(str(event.get("name", "首领技能")), float(event.get("duration", 1.5)), int(event.get("phase", 1)))
		if event.kind == "arena_event":
			hud.announce_arena_event(str(event.get("arena_type", "hazard")), float(event.get("duration", 6.0)))
		if event.kind == "contract_complete":
			hud.announce_contract(str(event.value), str(event.get("reward", "")))

func refresh() -> void:
	battle.selected_id = selected_id
	if not story.active:
		hud.refresh(sim, selected_id)
	battle.queue_redraw()

func open_mode_menu() -> void:
	audio_director.set_scene("menu")
	hud.get_child(0).hide()
	var checkpoint: Dictionary = checkpoint_store.load_checkpoint(sim.database)
	if bool(checkpoint.get("ok", false)):
		compendium.restore_story_recruitment(checkpoint.snapshot)
	if not checkpoint_error.is_empty():
		checkpoint["message"] = checkpoint_error
	mode_select_panel.update_checkpoint(checkpoint, sim.database)
	mode_select_panel.open()

func enter_home() -> void:
	home_facility_source = ""
	mode_select_panel.close()
	hud.get_child(0).hide()
	audio_director.set_scene("menu")
	home_panel.open()

func open_menu_archive() -> void:
	home_facility_source = "menu_archive"
	mode_select_panel.close()
	compendium_panel.open("characters")

func choose_mode(mode_id: String) -> void:
	mode_select_panel.close()
	sim.run_state.reset_run_meta()
	checkpoint_active = false
	hud.get_child(0).hide()
	if mode_id == "endless_survival":
		choose_stage("stage_endless")
	else:
		sim.run_state.mode_id = "rift_watch"
		stage_select_panel.open()

func return_to_main_menu() -> void:
	if is_instance_valid(combat_audio): combat_audio.reset()
	home_facility_source = ""
	if home_panel != null:
		home_panel.close()
	pending_home_outcome.clear()
	pending_recruitment.clear()
	pending_intro_outcome = ""
	recruitment_transition_active = false
	story.reset()
	dialogue.root.hide()
	campaign_event_panel.root.hide()
	campaign_map_panel.root.hide()
	squad_panel.root.hide()
	stage_select_panel.close()
	pending_stage_id = ""
	pending_stage_number = 0
	stage_result_recorded = false
	loss_transition_shown = false
	sim.state = "ready"
	battle.reset_transients()
	set_skill_aiming(false)
	hud.signature = ""
	open_mode_menu()

func save_campaign_checkpoint(phase: String) -> bool:
	if not checkpoint_active or sim.endless_mode:
		return false
	# Live progression must remain correct even when the disk write fails.
	checkpoint_phase = phase
	if test_mode and not checkpoint_testing:
		return false
	var snapshot: Dictionary = CampaignCheckpoint.snapshot(sim, phase)
	if not checkpoint_store.save_checkpoint(snapshot, sim.database):
		checkpoint_error = checkpoint_store.last_message
		checkpoint_warning.text = checkpoint_error
		checkpoint_warning.show()
		checkpoint_overlay.show()
		mode_select_panel.update_checkpoint({"ok": false, "message": checkpoint_error}, sim.database)
		return false
	checkpoint_error = ""
	checkpoint_warning.hide()
	checkpoint_overlay.hide()
	return true

func resume_campaign() -> bool:
	pending_recruitment.clear()
	recruitment_transition_active = false
	var loaded: Dictionary = checkpoint_store.load_checkpoint(sim.database)
	if not bool(loaded.ok):
		mode_select_panel.update_checkpoint(loaded, sim.database)
		return false
	var snapshot: Dictionary = loaded.snapshot
	compendium.restore_story_recruitment(snapshot)
	snapshot = snapshot.duplicate(true)
	if not compendium.has_gwen_recruitment():
		snapshot.run.squad.erase("hero_13")
	if not CampaignCheckpoint.restore(snapshot, sim):
		return false
	for id: String in snapshot.run.squad:
		compendium.unlock_character(id)
	story.reset()
	story_resume = ""
	dialogue.root.hide()
	mode_select_panel.close()
	stage_select_panel.close()
	squad_panel.root.hide()
	campaign_event_panel.root.hide()
	campaign_map_panel.root.hide()
	pending_stage_id = ""
	pending_stage_number = 0
	checkpoint_active = true
	checkpoint_phase = str(snapshot.phase)
	stage_result_recorded = checkpoint_phase == "cleared"
	selected_id = 0
	fx.active.clear()
	battle.reset_transients()
	set_skill_aiming(false)
	hud.get_child(0).show()
	if checkpoint_phase == "briefing":
		var ids: Array = sim.database.modes.get("rift_watch", {}).get("stage_ids", [])
		var number := ids.find(sim.current_stage_id) + 1
		var opening_key := "mode1_opening" if number == 1 else "mode1_stage%d_opening" % number
		if not begin_dialogue(opening_key, "start"):
			sim.start()
			save_campaign_checkpoint("battle")
	elif checkpoint_phase == "battle":
		sim.start()
		audio_director.set_scene("battle")
	else:
		sim.state = "won" if checkpoint_phase == "cleared" else "paused"
		story.seen["mode1_won"] = true
		story.seen["mode1_final_won"] = true
		if checkpoint_phase == "cleared" and has_next_stage():
			advance_stage()
		else:
			campaign_map_panel.open()
		if checkpoint_phase == "event":
			var node: Dictionary = CampaignCheckpoint.nodes(sim.database).get(sim.run_state.current_node, {})
			campaign_map_panel.close()
			open_campaign_event(node)
	refresh()
	return true

func primary() -> void:
	if story.active:
		return
	match sim.state:
		"ready":
			if test_mode:
				sim.start()
			else:
				choose_stage(sim.current_stage_id)
		"paused":
			sim.toggle_pause()
		"won", "lost":
			await restart()
			if test_mode:
				primary()
	refresh()

func choose_reward(index: int, hero_id: int = -1) -> void:
	if story.active or sim.state != "reward" or index < 0 or index >= sim.rewards.offered.size():
		return
	var card: Dictionary = sim.rewards.offered[index]
	if hero_id < 0 and sim.v2_mode and card.get("target", "global") == "character" and str(card.get("character_id", "")).is_empty():
		hud.reward_panel.show_target_picker(index, sim)
		return
	if sim.choose_reward(index, hero_id):
		refresh()

func reroll_rewards() -> void:
	if story.active or hud.reward_panel.target_overlay.visible or hud.reward_panel.synergy_overlay.visible:
		return
	if sim.reroll_rewards():
		hud.signature = ""
		refresh()

func open_debug_reward() -> void:
	var help := AcceptDialog.new()
	help.title = "操作说明"
	help.dialog_text = "拖动下方角色卡到战场部署；点选角色后使用技能按钮。\n电脑：右键移动，Q 瞄准技能，E 释放大招，F11 全屏。\n手机：点‘移动’或‘全队移动’，再点目标位置；拖动卡片部署。\n击杀获得金币，点击植物商店购买后放到空格。\n红色预警出现时及时移动；守住水晶并击败首领即可通关。"
	add_child(help)
	help.confirmed.connect(help.queue_free)
	help.canceled.connect(help.queue_free)
	help.popup_centered(Vector2i(800,280))

func restart(skip_death_animation: bool = false) -> void:
	if not test_mode and not skip_death_animation and dialogue != null:
		await dialogue.play_death_transition()
	pending_intro_outcome = ""
	story.reset()
	story_resume = ""
	hud.get_child(0).show()
	if dialogue != null:
		dialogue.root.hide()
		dialogue.auto_mode = false
		dialogue.auto_button.text = "自动：关"
	sim.restart_current_stage()
	recruited_heroes.clear()
	pending_recruitment.clear()
	recruitment_transition_active = false
	if checkpoint_active and not sim.endless_mode:
		checkpoint_phase = "briefing"
	campaign_map_panel.root.hide()
	campaign_event_panel.root.hide()
	selected_id = 0
	fx.active.clear()
	effect_preview = 0
	battle.effects.clear()
	battle.shot_flashes.clear()
	battle.hero_attack_visuals.clear()
	battle.hero_down_visuals.clear()
	battle.projectile_trails.clear()
	battle.base_flash = 0.0
	combat_audio.reset()
	set_skill_aiming(false)
	stage_result_recorded = false
	loss_transition_shown = false
	refresh()
	if not test_mode:
		await dialogue.play_stage_transition()
		sim.start()
		audio_director.set_scene("endless" if sim.endless_mode else "battle")
		refresh()

func toggle_pause() -> void:
	if story.active:
		return
	sim.toggle_pause()
	if sim.state == "paused":
		combat_audio.reset()
	refresh()

func select_hero(id: int) -> void:
	if story.active:
		return
	if sim.state not in ["running", "between", "stage_exit"]:
		return
	if id < 0 or id >= sim.heroes.size():
		return
	selected_id = id
	if sim.formation_mode == "follow":
		sim.set_follow_leader(id)
	set_skill_aiming(false)

func set_formation_command(mode: String) -> void:
	if story.active or sim.state not in ["running", "between"]:
		return
	if mode == "squad":
		selected_id = -2
		sim.formation_mode = "squad"
	else:
		sim.set_formation_mode(mode)
		if mode == "follow":
			var leader_id := selected_id
			if not sim.set_follow_leader(leader_id):
				leader_id = sim._resolve_follow_leader_id()
				sim.set_follow_leader(leader_id)
			selected_id = leader_id
	process_events()
	refresh()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		apply_setting("fullscreen", not bool(audio_director.values.fullscreen))
		get_viewport().set_input_as_handled()
		return
	if workshop != null: return
	if stage_clear_choice != null and stage_clear_choice.is_open():return
	# The achievement modal must receive input before the suspended stage transition.
	# Pointer events continue to GUI dispatch; no underlying gameplay handles them.
	if achievement_popup != null and achievement_popup.is_open():
		if achievement_popup.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if dialogue != null and dialogue.history_panel.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_H, KEY_ESCAPE, KEY_ENTER, KEY_SPACE]:
			dialogue.close_history()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and dialogue.history_panel.return_button.get_global_rect().has_point(event.position):
			dialogue.close_history()
			get_viewport().set_input_as_handled()
		return
	if dialogue != null and dialogue.animation_waiting:
		var confirms_animation: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE])
		if confirms_animation:
			dialogue.acknowledge_animation()
			get_viewport().set_input_as_handled()
		return
	if campaign_prelude_active:
		get_viewport().set_input_as_handled()
		return
	if campaign_event_panel != null and campaign_event_panel.is_open():
		if campaign_event_panel.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if campaign_event_panel.activate_at(event.position):
				get_viewport().set_input_as_handled()
		return
	if dragging_hero_id >= 0 and event is InputEventMouseMotion:
		_update_deploy_preview(event.position)
	if dragging_hero_id >= 0 and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_deploy_drag(event.position)
		get_viewport().set_input_as_handled()
		return
	if settings_panel != null and settings_panel.is_open():
		if settings_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if hud != null and hud.reward_panel != null and hud.reward_panel.visible and hud.reward_panel.synergy_overlay.visible:
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_ESCAPE:
				hud.reward_panel.close_synergies()
			get_viewport().set_input_as_handled()
		return
	if hud != null and hud.reward_panel != null and hud.reward_panel.target_overlay != null and hud.reward_panel.target_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				hud.reward_panel.close_target_picker()
			elif event.keycode in [KEY_1, KEY_2, KEY_3]:
				hud.reward_panel._pick_target(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10 and (mode_select_panel.is_open() or sim.state == "paused" or (home_panel != null and home_panel.is_open() and not home_panel.busy and not story.active)):
		open_settings()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var handled := false
		if mode_select_panel != null and mode_select_panel.is_open():
			handled = mode_select_panel.activate_at(event.position)
		elif stage_select_panel != null and stage_select_panel.is_open():
			handled = stage_select_panel.activate_at(event.position)
		elif squad_panel != null and squad_panel.is_open():
			handled = squad_panel.activate_at(event.position)
		elif campaign_event_panel != null and campaign_event_panel.is_open():
			handled = campaign_event_panel.activate_at(event.position)
		elif story.active:
			handled = dialogue.activate_choice_at(event.position)
		if handled:
			get_viewport().set_input_as_handled()
			return
	if mode_select_panel != null and mode_select_panel.is_open():
		return
	if sim.state == "stage_exit" and not story.active and not squad_panel.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]:
			if not battle.stage_exit_requires_dialogue:
				battle.reset_transients()
				advance_stage()
			get_viewport().set_input_as_handled()
			return
	if home_panel != null and home_panel.is_open() and not story.active:
		if home_panel.busy:
			if dialogue.animation_waiting and ((event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)):
				dialogue.acknowledge_animation()
			get_viewport().set_input_as_handled()
			return
		if home_panel.handle_input(event):
			get_viewport().set_input_as_handled()
		return
	if campaign_map_panel != null and campaign_map_panel.is_open():
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ESCAPE, KEY_F5]:
			campaign_map_panel.close()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F2 and not story.active:
		if not sim.battle_devices.selected_kind.is_empty(): _cancel_device()
		toggle_compendium()
		get_viewport().set_input_as_handled()
		return
	if hud.device_shop_ui != null and hud.device_shop_ui.drawer.is_visible_in_tree() and not story.active:
		var close_seeds: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE
		close_seeds = close_seeds or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT)
		if close_seeds:
			hud.device_shop_ui.close_drawer()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not story.active and not sim.battle_devices.selected_kind.is_empty():
		_cancel_device()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3 and not story.active:
		if not sim.battle_devices.selected_kind.is_empty(): _cancel_device()
		open_current_squad()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4 and not story.active:
		if not sim.battle_devices.selected_kind.is_empty(): _cancel_device()
		open_stage_select()
		get_viewport().set_input_as_handled()
		return
	if compendium_panel.is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			compendium_panel.close()
			get_viewport().set_input_as_handled()
		return
	if squad_panel.is_open():
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
			squad_panel.confirm()
		get_viewport().set_input_as_handled()
		return
	if stage_select_panel.is_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			stage_select_panel.close()
		get_viewport().set_input_as_handled()
		return
	if picker.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			picker.hide()
			refresh()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not story.active:
		if event.keycode == KEY_F6 and OS.has_feature("editor") and test_mode:
			picker.open()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F5 and sim.state in ["ready", "paused", "won"]:
			open_campaign_map()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F7 and OS.has_feature("editor") and test_mode and sim.state in ["ready", "paused"]:
			preview_effects()
			get_viewport().set_input_as_handled()
			return
	if story.active:
		dialogue.handle_input(event)
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			toggle_skill_aiming()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_E:
			activate_selected_ultimate()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE and (skill_aiming or ultimate_aiming):
			set_skill_aiming(false)
			get_viewport().set_input_as_handled()
			return
		match event.keycode:
			KEY_Z:
				set_formation_command("squad")
				get_viewport().set_input_as_handled()
			KEY_X:
				set_formation_command("follow")
				get_viewport().set_input_as_handled()
			KEY_C:
				set_formation_command("hold")
				get_viewport().set_input_as_handled()
			KEY_SPACE, KEY_ESCAPE:
				toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				if sim.state in ["ready", "won", "lost"]:
					primary()
					get_viewport().set_input_as_handled()
			KEY_R:
				if sim.state == "reward":
					reroll_rewards()
				else:
					hud.request_restart_confirmation()
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3:
				if sim.state == "reward":
					choose_reward(event.keycode - KEY_1)
				else:
					select_hero(event.keycode - KEY_1)
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if workshop != null: return
	if dialogue != null and dialogue.history_panel.visible: return
	if story.active or picker.visible or effect_preview > 0 or squad_panel.is_open() or stage_select_panel.is_open() or mode_select_panel.is_open() or (campaign_map_panel != null and campaign_map_panel.is_open()) or (campaign_event_panel != null and campaign_event_panel.is_open()):
		return
	if sim.state not in ["running", "between", "stage_exit"]:
		return
	if sim.endless_mode and (event is InputEventMouseMotion or event is InputEventMouseButton):
		var endless_screen: Vector2 = battle.get_global_transform().affine_inverse() * event.position
		if not View.ENDLESS_PLAYFIELD_SCREEN.has_point(endless_screen) or ENDLESS_UI_LAYOUT.battle_expedition_tasks_rect.has_point(endless_screen) or ENDLESS_UI_LAYOUT.battle_expedition_minimap_rect.grow(6).has_point(endless_screen):
			return
		if sim.elapsed<9.0 and ENDLESS_UI_LAYOUT.battle_expedition_guide_rect.has_point(endless_screen): return
	if not sim.battle_devices.selected_kind.is_empty():
		if event is InputEventMouseMotion:
			var device_screen: Vector2 = battle.get_global_transform().affine_inverse() * event.position
			sim.battle_devices.hover(sim, battle.screen_to_world(device_screen))
			hud.refresh(sim, selected_id)
			battle.queue_redraw()
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_cancel_device()
			elif event.button_index == MOUSE_BUTTON_LEFT:
				var device_screen: Vector2 = battle.get_global_transform().affine_inverse() * event.position
				sim.battle_devices.place(sim, battle.screen_to_world(device_screen))
				process_events()
				refresh()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and (skill_aiming or ultimate_aiming):
		var hover_screen: Vector2 = battle.get_global_transform().affine_inverse() * event.position
		battle.skill_point = battle.screen_to_world(hover_screen)
		battle.queue_redraw()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and (skill_aiming or ultimate_aiming):
			set_skill_aiming(false)
			get_viewport().set_input_as_handled()
			return
		var screen_point: Vector2 = battle.get_global_transform().affine_inverse() * event.position
		var point: Vector2 = battle.screen_to_world(screen_point)
		var playable_area: Rect2 = Sim.ENDLESS_ARENA if sim.endless_mode else View.WORLD
		if not playable_area.has_point(point):
			return
		if event.button_index == MOUSE_BUTTON_LEFT and mobile_move_mode and not skill_aiming and not ultimate_aiming:
			if mobile_move_all and sim.state != "stage_exit":
				sim.command_squad(point)
			else:
				var hero_id := 0 if sim.state == "stage_exit" or selected_id < 0 else selected_id
				sim.command_move(hero_id, point)
			mobile_move_mode = false
			refresh()
			get_viewport().set_input_as_handled()
			return
		if sim.state == "stage_exit" and event.button_index == MOUSE_BUTTON_RIGHT:
			selected_id = 0
			sim.command_move(0, point)
			refresh()
			return
		if sim.state == "stage_exit":
			return
		if event.button_index == MOUSE_BUTTON_LEFT and skill_aiming:
			if sim.activate_hero_skill(selected_id, point):
				set_skill_aiming(false)
				process_events()
				refresh()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and ultimate_aiming:
			if sim.activate_hero_ultimate(selected_id, point):
				set_ultimate_aiming(false)
				process_events()
				refresh()
			return
		elif event.button_index == MOUSE_BUTTON_LEFT:
			selected_id = -1
			var closest: float = 48.0
			for h in sim.heroes:
				if not bool(h.get("deployed", true)):
					continue
				var distance: float = screen_point.distance_to(battle.world_to_screen(h.pos) + Vector2(0, -18))
				if distance < closest:
					closest = distance
					selected_id = h.id
			if selected_id >= 0 and sim.formation_mode == "follow":
				sim.set_follow_leader(selected_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if selected_id == -2:
				sim.command_squad(point)
			else:
				sim.command_move(selected_id, point)
		refresh()

func _set_mobile_move_mode(all_heroes: bool) -> void:
	if mobile_move_mode and mobile_move_all == all_heroes:
		mobile_move_mode = false
	else:
		mobile_move_mode = true
		mobile_move_all = all_heroes
		if skill_aiming or ultimate_aiming:
			set_skill_aiming(false)

func _select_device(kind: String) -> void:
	if story.active or settings_panel.is_open() or sim.state not in ["running", "between", "ready"]: return
	set_skill_aiming(false)
	ultimate_aiming = false
	mobile_move_mode = false
	sim.battle_devices.select(sim, kind)
	hud.refresh(sim, selected_id)
	battle.queue_redraw()

func _cancel_device() -> void:
	sim.battle_devices.cancel()
	hud.cancel_device_placement()
	hud.refresh(sim, selected_id)
	battle.queue_redraw()

func _hover_dragged_device(screen_pos: Vector2) -> void:
	if story.active or settings_panel.is_open() or sim.state not in ["running", "between", "ready"] or sim.battle_devices.selected_kind.is_empty(): return
	var local: Vector2 = battle.get_global_transform().affine_inverse() * screen_pos
	sim.battle_devices.hover(sim, battle.screen_to_world(local))
	hud.refresh(sim, selected_id)
	battle.queue_redraw()

func _drop_dragged_device(kind: String, screen_pos: Vector2) -> void:
	if story.active or settings_panel.is_open() or sim.state not in ["running", "between", "ready"] or sim.battle_devices.selected_kind != kind: return
	var local: Vector2 = battle.get_global_transform().affine_inverse() * screen_pos
	sim.battle_devices.place(sim, battle.screen_to_world(local))
	process_events()
	refresh()

func run_smoke_test() -> void:
	primary()
	for frame in 150:
		await get_tree().process_frame
	print("M3 EXPORTED SMOKE PASSED; state=" + sim.state)
	get_tree().quit()

func run_ui_test() -> void:
	var suite = QA.new()
	await suite.run(self)

func begin_dialogue(key: String, resume_action: String = "") -> bool:
	if not story.begin(key):
		return false
	if resume_action in ["start", "pre_stage"]:
		pending_intro_outcome = ""
	story_resume = resume_action
	combat_audio.reset()
	if resume_action != "recruit":
		audio_director.set_scene("dialogue")
	hud.get_child(0).hide()
	pending_campaign_outcome = ""
	campaign_recruits.clear()
	var comics: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
	if comics.has(key):
		campaign_prelude_active = true
		_play_campaign_prelude.call_deferred(key, comics[key])
	else:
		dialogue.display()
	return true

func _play_campaign_prelude(scene_key: String, panels: Array) -> void:
	for panel: Dictionary in panels:
		await dialogue.play_comic_panel(str(panel.image), str(panel.text))
		if not story.active or story.key != scene_key:
			campaign_prelude_active = false
			return
	dialogue.comic_playing = true
	await dialogue.play_stage_transition()
	dialogue.comic_playing = false
	campaign_prelude_active = false
	dialogue.display()

func open_home_facility(facility_id: String) -> void:
	if story.active:
		return
	home_facility_source = facility_id
	home_panel.close()
	match facility_id:
		"stages":
			stage_select_panel.open()
		"archive":
			compendium.observe(sim)
			compendium_panel.open()
		"achievements":
			compendium.observe(sim)
			compendium_panel.open("achievements")
		"settings":
			open_settings()
		_:
			home_facility_source = ""
			home_panel.open()

func _stage_select_cancelled() -> void:
	if home_facility_source == "stages":
		home_facility_source = ""
		home_panel.open()
	else:
		mode_select_panel.open()

func _home_archive_closed() -> void:
	if home_facility_source == "menu_archive":
		home_facility_source = ""
		open_mode_menu()
		return
	if home_facility_source in ["archive", "achievements"]:
		home_facility_source = ""
		home_panel.open()

func begin_home_interaction(character_id: String) -> void:
	var scene_index := randi_range(0, 4)
	if scene_index == int(last_home_scene.get(character_id, -1)):
		scene_index = (scene_index + randi_range(1, 4)) % 5
	last_home_scene[character_id] = scene_index
	var scene_key := "home_%s_%d" % [character_id, scene_index]
	if not story.stories.has(scene_key):
		home_panel.busy = false
		return
	story.seen.erase(scene_key)
	pending_home_outcome.clear()
	if not begin_dialogue(scene_key, "home"):
		home_panel.busy = false

func _home_visitor_readonly() -> bool:
	return story_resume == "home" and home_panel != null and bool(home_panel.get("visiting_encounter"))

func apply_dialogue_choice(choice: Dictionary) -> void:
	var visitor_readonly := _home_visitor_readonly()
	if not visitor_readonly and choice.has("campaign_outcome"):
		pending_campaign_outcome = str(choice.campaign_outcome)
	if not visitor_readonly and choice.has("intro_outcome"):
		pending_intro_outcome = str(choice.intro_outcome)
	if choice.has("home_success"):
		pending_home_outcome = {"success": bool(choice.home_success), "reason": str(choice.get("home_reason", ""))}
	if not visitor_readonly and choice.has("recruit_success") and not pending_recruitment.is_empty():
		pending_recruitment.success = bool(choice.recruit_success)
	var unlock_id := str(choice.get("unlock_character", ""))
	if not visitor_readonly and not unlock_id.is_empty() and sim.database.characters.has(unlock_id):
		var selectable := unlock_id != "hero_13" or compendium.has_gwen_recruitment()
		if selectable: compendium.unlock_character(unlock_id)
		if selectable and story_resume in ["start", "pre_stage"] and not sim.run_state.squad.has(unlock_id) and not campaign_recruits.has(unlock_id):
			campaign_recruits.append(unlock_id)
	var relationship: Dictionary = choice.get("relationship", {})
	if not relationship.is_empty():
		sim.run_state.add_relationship(str(relationship.get("character_id", "traveler")), int(relationship.get("value", 0)))
	var flag := str(choice.get("story_flag", ""))
	if not visitor_readonly and not flag.is_empty():
		sim.run_state.set_story_flag(flag)
	var next_node := str(choice.get("campaign_node", ""))
	if not visitor_readonly and not next_node.is_empty():
		sim.run_state.select_campaign_node(next_node)
	var effect: Dictionary = choice.get("effect", {})
	if visitor_readonly: effect = {}
	match str(effect.get("type", "")):
		"luck":
			sim.run_state.luck = clampf(sim.run_state.luck + float(effect.get("value", 0.0)), 0.0, 0.75)
		"inherit_endless":
			pending_endless_inheritance = sim.export_run_snapshot()
			story_resume = "inherit_endless"
	hud.signature = ""

func _authored_ending_resolved(ending: Dictionary) -> void:
	var accepted := str(ending.get("status", "badend")) == "success"
	if story_resume == "recruit":
		if not pending_recruitment.is_empty(): pending_recruitment.success = accepted
	elif story_resume == "home":
		pending_home_outcome = {"success": accepted}
	else:
		pending_campaign_outcome = "success" if accepted else "failure"
	if not accepted and not previewing and story_resume == "stage_recruit" and story.key == "mode1_won" and sim.current_stage_id == "stage_01" and not compendium.has_gwen_recruitment():
		compendium.reject_gwen_recruitment()
		sim.run_state.set_story_flag("gwen_recruited", false)
	if accepted and not previewing and not _home_visitor_readonly():
		if str(ending.get("unlock_character", "")) == "hero_13" and story_resume == "stage_recruit" and story.key == "mode1_won" and sim.current_stage_id == "stage_01" and sim.state in ["won", "stage_exit"]:
			compendium.record_story_recruit("hero_13", "mode1_won")
			sim.run_state.set_story_flag("gwen_recruited")
		apply_dialogue_choice({"unlock_character": str(ending.get("unlock_character", ""))})

func _play_authored_result() -> void:
	if pending_campaign_outcome == "success":
		await dialogue.play_success_animation()
	else:
		await dialogue.play_death_transition("")
	for panel: Dictionary in story.last_ending.get("comics", []):
		await dialogue.play_comic_panel(str(panel.get("image", "")), str(panel.get("text", "")))
	await dialogue.play_stage_transition()

func _stage_exit_meet() -> void:
	story.seen.erase("mode1_won")
	if not begin_dialogue("mode1_won", "stage_recruit"):
		push_error("First-stage greeting scene is missing")

func end_dialogue() -> void:
	if previewing:
		story = saved_story
		dialogue.director = story
		previewing = false
	hud.get_child(0).show()
	hud.signature = ""
	var action: String = story_resume
	story_resume = ""
	var campaign_result: bool = action in ["start", "pre_stage", "stage_exit", "stage_recruit"] or (story.key == "mode1_final_won" and not previewing)
	if campaign_result:
		campaign_prelude_active = true
	if action not in ["home", "recruit", "stage_recruit"] and not pending_achievement_ids.is_empty():
		await _show_pending_achievements()
	if action == "pre_stage":
		var scene_key: String = story.key
		var accepted := pending_campaign_outcome != "failure"
		if story.graph_mode:
			accepted = pending_campaign_outcome == "success"
			await _play_authored_result()
		else:
			await dialogue.play_stage_transition()
		campaign_prelude_active = false
		if not accepted:
			story.seen.erase(scene_key)
			begin_dialogue(scene_key, "pre_stage")
			return
		pending_stage_intro_completed = true
		var available_squad: Array[String] = sim.run_state.squad.duplicate()
		for id: String in campaign_recruits:
			if not available_squad.has(id): available_squad.append(id)
		squad_panel.open(pending_stage_id, available_squad, campaign_recruits)
		return
	if action == "stage_recruit":
		await _play_authored_result()
		if pending_campaign_outcome == "success":
			compendium.clear_stage(sim.current_stage_id, ["hero_13"])
			save_campaign_checkpoint("cleared")
			await _show_pending_achievements()
			campaign_prelude_active = false
			battle.start_stage_departure()
		else:
			campaign_prelude_active = false
			_stage_exit_meet()
		return
	if action == "home":
		hud.get_child(0).hide()
		if bool(pending_home_outcome.get("success", false)):
			await dialogue.play_success_animation()
		else:
			await dialogue.play_death_transition() # The NPC already explained the failed choice in dialogue.
		await dialogue.play_stage_transition()
		pending_home_outcome.clear()
		home_panel.open()
		audio_director.set_scene("menu")
		return
	if action == "recruit":
		await _resolve_recruitment()
	elif action == "start":
		if pending_campaign_outcome == "failure":
			await dialogue.play_death_transition("")
		elif pending_intro_outcome == "success" or pending_campaign_outcome == "success":
			await dialogue.play_success_animation()
		elif pending_intro_outcome == "roxy_departure":
			await dialogue.play_comic_panel("res://assets/story_comics/roxy_departure.png", "你刚把‘魔族’喊出口，就意识到自己说错了话。\n你追到门边，只听见渐远的脚步声。")
		pending_intro_outcome = ""
		await dialogue.play_stage_transition()
		if not campaign_recruits.is_empty():
			pending_stage_id = sim.current_stage_id
			pending_stage_number = int(sim.current_stage_id.trim_prefix("stage_"))
			campaign_recruit_reselect = true
			squad_panel.open(pending_stage_id, sim.run_state.squad, campaign_recruits)
			campaign_prelude_active = false
			return
		sim.start()
		save_campaign_checkpoint("battle")
		audio_director.set_scene("endless" if sim.endless_mode else "battle")
		hud.signature = ""
		refresh()
	elif action == "stage_exit":
		if pending_campaign_outcome == "success":
			await dialogue.play_success_animation()
		elif pending_campaign_outcome == "failure":
			await dialogue.play_death_transition("")
		await dialogue.play_stage_transition()
		save_campaign_checkpoint("cleared")
		play_stage_exit()
	elif action == "inherit_endless":
		start_inherited_endless()
	elif action == "campaign_route":
		save_campaign_checkpoint("route")
	elif campaign_result:
		if pending_campaign_outcome == "success":
			await dialogue.play_success_animation()
		elif pending_campaign_outcome == "failure":
			await dialogue.play_death_transition("")
		await dialogue.play_stage_transition()
	if campaign_result:
		campaign_prelude_active = false
		if sim.state == "won" and not has_next_stage():advance_stage()
	refresh()

func check_story() -> void:
	if story.active:
		return
	if sim.state == "lost":
		return
	if sim.v2_mode:
		if sim.state == "won":
			if sim.current_stage_id == "stage_01":
				record_stage_result()
				play_stage_exit()
				return
			if has_next_stage():
				var stage_ids: Array = sim.database.modes.get(sim.run_state.mode_id, {}).get("stage_ids", [])
				var stage_number := stage_ids.find(sim.current_stage_id) + 1
				var victory_key := "mode1_won" if stage_number == 1 else "mode1_stage%d_won" % stage_number
				begin_dialogue(victory_key, "stage_exit")
			else:
				begin_dialogue("mode1_final_won")
		return
	if sim.state == "reward" and not sim.v2_mode:
		begin_dialogue("node%d" % sim.wave)
	elif sim.state == "won":
		begin_dialogue(sim.state)

func has_next_stage() -> bool:
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	return index >= 0 and index + 1 < ids.size()

func play_stage_exit() -> void:
	var stage: Dictionary = sim.database.stages.get(sim.current_stage_id, {})
	var unlocks: Array = stage.get("unlocks", [])
	var character_id := ""
	var character_name := "新同行者"
	var element_id := "none"
	if not unlocks.is_empty() and sim.database.characters.has(str(unlocks[0])):
		character_id = str(unlocks[0])
		var character: Dictionary = sim.database.characters[character_id]
		character_name = str(character.name)
		element_id = str(character.element)
	set_skill_aiming(false)
	keyboard_moving = false
	sim.begin_stage_exit()
	selected_id = 0
	battle.begin_stage_exit(character_id, character_name, element_id, sim.current_stage_id == "stage_01")
	refresh()

func advance_stage() -> void:
	if stage_clear_choice != null and stage_clear_choice.is_open():return
	if stage_clear_choice != null:stage_clear_choice.queue_free()
	stage_clear_choice=preload("res://scripts/stage_clear_choice.gd").new()
	add_child(stage_clear_choice);stage_clear_choice.build(hud, not has_next_stage())
	stage_clear_choice.continue_campaign.connect(_continue_campaign_stage)
	stage_clear_choice.enter_endless.connect(func():
		pending_endless_inheritance=sim.export_run_snapshot()
		campaign_prelude_active=false
		start_inherited_endless())

func _continue_campaign_stage() -> void:
	if not has_next_stage():
		return_to_main_menu()
		return
	campaign_prelude_active=false
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	if index < 0 or index + 1 >= ids.size():
		stage_select_panel.open()
		return
	var completed: Dictionary = sim.database.stages.get(sim.current_stage_id, {})
	var unlocks: Array = completed.get("unlocks", [])
	compendium.clear_stage(sim.current_stage_id, unlocks)
	choose_stage(str(ids[index + 1]))
	combat_audio.reset()

func can_travel_campaign_route() -> bool:
	if sim.endless_mode or sim.state not in ["ready", "paused", "won"]:
		return false
	return sim.state == "won" or checkpoint_phase in ["route", "event", "cleared"]

func open_campaign_map() -> void:
	if story.active or campaign_map_panel.is_open() or not can_travel_campaign_route():
		return
	campaign_map_panel.open()
	combat_audio.reset()

func choose_campaign_node(node_id: String) -> void:
	if story.active or not can_travel_campaign_route():
		return
	var node: Dictionary = campaign_map_panel.node_rows.get(node_id, {})
	if node.is_empty():
		return
	sim.run_state.select_campaign_node(node_id)
	campaign_map_panel.close()
	var unlock_id := str(node.get("unlock", ""))
	match str(node.get("type", "")):
		"combat", "elite", "boss":
			if not unlock_id.is_empty(): compendium.unlock_character(unlock_id)
			var stage_id := str(node.get("stage_id", ""))
			if not stage_id.is_empty():
				choose_stage(stage_id)
		"story":
			if not begin_dialogue(str(node.get("story", "mode1_opening")), "campaign_route"):
				begin_dialogue("mode1_opening", "campaign_route")
		"shop", "rest", "recruit", "hidden":
			save_campaign_checkpoint("event")
			open_campaign_event(node)
	hud.signature = ""
	refresh()

func open_campaign_event(node: Dictionary) -> void:
	var rows: Array[Dictionary] = campaign_node_resolver.build_options(node,sim.run_state,sim.database)
	campaign_event_panel.open(node,rows,sim.run_state.rift_shards)

func resolve_campaign_option(option: Dictionary) -> void:
	var result: Dictionary = campaign_node_resolver.apply_option(option,sim.run_state)
	if bool(result.get("ok",false)):
		var unlock_id := str(result.get("unlock_character",""))
		if not unlock_id.is_empty(): compendium.unlock_character(unlock_id)
		compendium.save_progress()
		save_campaign_checkpoint("route")
	campaign_event_panel.show_result(result,sim.run_state.rift_shards)
	refresh()

func _campaign_event_closed() -> void:
	if campaign_map_panel != null:
		campaign_map_panel.open()

func open_current_squad() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or sim.state not in ["ready", "won", "paused"]:
		return
	if sim.state == "ready" and not sim.endless_mode:
		choose_stage(sim.current_stage_id)
		return
	var mode: Dictionary = sim.database.modes.get(sim.run_state.mode_id, {})
	var ids: Array = mode.get("stage_ids", [])
	var index := ids.find(sim.current_stage_id)
	if index < 0:
		return
	pending_stage_id = sim.current_stage_id
	pending_stage_number = index + 1
	squad_panel.open(pending_stage_id, sim.run_state.squad)
	combat_audio.reset()

func open_stage_select() -> void:
	if is_instance_valid(combat_audio): combat_audio.reset()
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or sim.state not in ["ready", "won", "paused"]:
		return
	stage_select_panel.open()
	combat_audio.reset()

func choose_stage(stage_id: String) -> void:
	if not stage_select_panel._is_unlocked(stage_id):
		return
	mode_select_panel.close()
	stage_select_panel.close()
	var selected_mode := "endless_survival" if stage_id == "stage_endless" else "rift_watch"
	var ids: Array = sim.database.modes.get(selected_mode, {}).get("stage_ids", [])
	var index := ids.find(stage_id)
	if index < 0:
		return
	sim.run_state.mode_id = selected_mode
	pending_stage_id = stage_id
	pending_stage_number = index + 1
	pending_stage_intro_completed = false
	story.reset()
	var opening_key := "mode1_opening" if index == 0 else "mode1_stage%d_opening" % (index + 1)
	if stage_id == "stage_endless" or not begin_dialogue(opening_key, "pre_stage"):
		pending_stage_intro_completed = true
		squad_panel.open(stage_id, sim.run_state.squad)

func _squad_selection_cancelled() -> void:
	if campaign_recruit_reselect:
		campaign_recruit_reselect = false
		pending_stage_id = ""
		pending_stage_number = 0
		sim.start()
		save_campaign_checkpoint("battle")
		audio_director.set_scene("battle")
		refresh()
		return
	if pending_stage_id == "stage_endless":
		pending_stage_id = ""
		pending_stage_number = 0
		mode_select_panel.open()
	else:
		stage_select_panel.open()

func confirm_next_squad(squad: Array[String]) -> void:
	if pending_stage_id.is_empty():
		return
	if not compendium.has_gwen_recruitment():
		squad = squad.duplicate()
		squad.erase("hero_13")
	home_facility_source = ""
	var intro_completed := pending_stage_intro_completed
	pending_stage_intro_completed = false
	story.reset()
	if stage_enter_sound != null and not muted and not test_mode:
		stage_enter_sound.stop()
		stage_enter_sound.play()
	sim.reset_stage(pending_stage_id, squad)
	recruited_heroes.clear()
	pending_recruitment.clear()
	recruitment_transition_active = false
	if not sim.endless_mode:
		var campaign_nodes := CampaignCheckpoint.nodes(sim.database)
		var current: Dictionary = campaign_nodes.get(sim.run_state.current_node, {})
		if str(current.get("stage_id", "")) != pending_stage_id:
			for node: Dictionary in campaign_nodes.values():
				if str(node.get("stage_id", "")) == pending_stage_id:
					sim.run_state.current_node = str(node.id)
					break
		checkpoint_active = true
		save_campaign_checkpoint("briefing")
	if sim.endless_mode and not sim.heroes.is_empty():
		battle.camera_center = sim.heroes[0].pos
	selected_id = 0
	set_skill_aiming(false)
	stage_result_recorded = false
	loss_transition_shown = false
	fx.active.clear()
	battle.effects.clear()
	battle.shot_flashes.clear()
	battle.hero_attack_visuals.clear()
	battle.hero_down_visuals.clear()
	battle.projectile_trails.clear()
	battle.reset_transients()
	hud.get_child(0).show()
	var dialogue_key := "" if intro_completed or sim.endless_mode or campaign_recruit_reselect else ("mode1_opening" if pending_stage_number == 1 else "mode1_stage%d_opening" % pending_stage_number)
	pending_stage_id = ""
	pending_stage_number = 0
	campaign_recruit_reselect = false
	if dialogue_key.is_empty() or not begin_dialogue(dialogue_key, "start"):
		sim.start()
		save_campaign_checkpoint("battle")
		audio_director.set_scene("endless" if sim.endless_mode else "battle")
		hud.signature = ""
		refresh()

func open_settings() -> void:
	if settings_panel == null or settings_panel.is_open() or story.active:
		return
	settings_from_menu = mode_select_panel.is_open()
	if settings_from_menu:
		mode_select_panel.close()
	elif sim.state in ["running", "between"]:
		sim.toggle_pause()
	settings_panel.open(audio_director.snapshot())
	refresh()

func apply_setting(key: String, value: Variant) -> void:
	audio_director.set_setting(key, value)
	if key == "reduced_effects":
		battle.reduced_effects = bool(value)
		fx.reduced = bool(value)
		hud.reduced = bool(value)
	elif key == "sfx":
		muted = float(value) <= 0.001
	elif key == "fullscreen" and settings_panel != null:
		settings_panel.sync_fullscreen(bool(value))

func settings_closed() -> void:
	if home_facility_source == "settings":
		home_facility_source = ""
		home_panel.open()
	elif settings_from_menu:
		mode_select_panel.open()
	settings_from_menu = false
	refresh()

func start_inherited_endless() -> void:
	if pending_endless_inheritance.is_empty():
		return
	var snapshot := pending_endless_inheritance.duplicate(true)
	pending_endless_inheritance.clear()
	var squad: Array[String] = []
	for id: Variant in snapshot.get("squad", ["traveler"]):
		squad.append(str(id))
	sim.reset_stage("stage_endless", squad)
	sim.run_state.mode_id = "endless_survival"
	sim.import_run_snapshot(snapshot)
	selected_id = sim._resolve_follow_leader_id()
	sim.set_follow_leader(selected_id)
	battle.camera_center = sim.heroes[selected_id].pos if selected_id >= 0 else Sim.ENDLESS_ARENA.get_center()
	set_skill_aiming(false)
	stage_result_recorded = false
	loss_transition_shown = false
	fx.active.clear()
	battle.effects.clear()
	battle.reset_transients()
	hud.get_child(0).show()
	sim.start()
	audio_director.set_scene("endless")
	refresh()

func run_m4_test() -> void:
	var suite = preload("res://scripts/qa_m4.gd").new()
	await suite.run(self)

func preview_scene(key: String) -> void:
	picker.hide()
	saved_story = story
	story = Story.new(content)
	dialogue.director = story
	previewing = true
	if not begin_dialogue(key):
		story = saved_story
		dialogue.director = story
		previewing = false

func preview_effects() -> void:
	effect_preview = 1.5
	hud.overlay.hide()
	fx.active.clear()
	fx.active.append({"kind": "heal", "pos": Vector2(420, 370), "age": -0.15})
	fx.active.append({"kind": "hit", "pos": Vector2(790, 370), "age": -0.15, "element": "hydro", "seed": 0.5})

func run_m5_test() -> void:
	var suite = preload("res://scripts/qa_m5.gd").new()
	await suite.run(self)

func run_v11_test() -> void:
	var suite = preload("res://scripts/qa_v11.gd").new()
	await suite.run(self)

func run_v12_test() -> void:
	var suite = preload("res://scripts/qa_v12.gd").new()
	await suite.run(self)

func run_v13_test() -> void:
	var suite = preload("res://scripts/qa_v13.gd").new()
	await suite.run(self)

func run_v14_test() -> void:
	var suite = preload("res://scripts/qa_v14.gd").new()
	await suite.run(self)

func run_m9_test() -> void:
	var suite = preload("res://scripts/qa_m9.gd").new()
	await suite.run(self)

func run_config_window_test() -> void:
	var suite = preload("res://scripts/qa_config_window.gd").new()
	await suite.run(self)

func run_phase1_test() -> void:
	var suite = preload("res://scripts/qa_phase1.gd").new()
	await suite.run(self)

func toggle_compendium() -> void:
	if story.active or squad_panel.is_open() or stage_select_panel.is_open():
		return
	if compendium_panel.is_open():
		compendium_panel.close()
	else:
		compendium.observe(sim)
		compendium_panel.open()
		combat_audio.reset()

func toggle_skill_aiming() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or sim.state != "running":
		return
	if selected_id < 0 or selected_id >= sim.heroes.size():
		return
	var hero: Dictionary = sim.heroes[selected_id]
	if not bool(hero.get("deployed", false)) or float(hero.get("skill_cooldown", 0.0)) > 0.0:
		return
	if str(hero.get("active_skill", {}).get("kind", "")) == "columbia_tide_ring":
		if sim.activate_hero_skill(selected_id, Vector2(hero.pos)):
			process_events()
			refresh()
		return
	set_skill_aiming(not skill_aiming)

func set_skill_aiming(enabled: bool) -> void:
	if not enabled:
		hud.dismiss_info_popover()
	skill_aiming = enabled
	if enabled:
		ultimate_aiming = false
	elif ultimate_aiming:
		ultimate_aiming = false
	_sync_ability_aiming(false)

func activate_selected_ultimate() -> void:
	if story.active or compendium_panel.is_open() or squad_panel.is_open() or stage_select_panel.is_open() or sim.state != "running":
		return
	if selected_id < 0 or selected_id >= sim.heroes.size():
		return
	var hero: Dictionary = sim.heroes[selected_id]
	if not bool(hero.get("deployed", false)) or float(hero.get("ultimate_cooldown", 0.0)) > 0.0 or float(hero.get("energy", 0.0)) < float(hero.get("max_energy", 100.0)):
		return
	if str(hero.get("ultimate", {}).get("kind", "")) in ["columbia_tidal_benediction", "hydro_fanfare"]:
		if sim.activate_hero_ultimate(selected_id, Vector2(hero.pos)):
			process_events()
			refresh()
		return
	set_ultimate_aiming(not ultimate_aiming)

func set_ultimate_aiming(enabled: bool) -> void:
	if not enabled:
		hud.dismiss_info_popover()
	ultimate_aiming = enabled
	if enabled:
		skill_aiming = false
	_sync_ability_aiming(enabled)

func _sync_ability_aiming(preview_ultimate: bool) -> void:
	battle.skill_targeting = skill_aiming or ultimate_aiming
	battle.skill_preview_ultimate = preview_ultimate and ultimate_aiming
	if battle.skill_targeting and selected_id >= 0 and selected_id < sim.heroes.size():
		var offset := Vector2(230, 0)
		battle.skill_point = sim.heroes[selected_id].pos + offset
	hud.set_skill_aiming(skill_aiming)
	hud.set_ultimate_aiming(ultimate_aiming)
	refresh()

func _update_selected_hero_keyboard(dt: float) -> void:
	keyboard_move_timer = maxf(0.0, keyboard_move_timer - dt)
	if sim.endless_mode and sim.state == "running" and (selected_id == -1 or (selected_id >= 0 and selected_id < sim.heroes.size() and sim.heroes[selected_id].hp <= 0.0)):
		selected_id = sim._resolve_follow_leader_id()
		if sim.formation_mode == "follow": sim.set_follow_leader(selected_id)
	if sim.state != "running" or selected_id < 0 or selected_id >= sim.heroes.size() or skill_aiming or ultimate_aiming:
		keyboard_moving = false
		return
	var hero: Dictionary = sim.heroes[selected_id]
	if hero.hp <= 0.0 or not bool(hero.get("deployed", false)):
		keyboard_moving = false
		return
	var direction := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	if direction.length_squared() > 0.0:
		if keyboard_move_timer <= 0.0:
			sim.command_move(selected_id, hero.pos + direction.normalized() * 96.0, false)
			keyboard_move_timer = 0.07
		keyboard_moving = true
	elif keyboard_moving:
		hero.target = hero.pos
		hero.moving = false
		keyboard_moving = false


func handle_deploy_drag(hero_id: int, pressed: bool, screen_pos: Vector2) -> void:
	if not pressed or sim.state not in ["running", "between"] or hero_id < 0 or hero_id >= sim.heroes.size() or not sim.deployment_slot_unlocked(hero_id):
		return
	if sim.endless_mode:
		select_hero(hero_id)
		return
	if bool(sim.heroes[hero_id].get("deployed", false)):
		select_hero(hero_id)
		return
	dragging_hero_id = hero_id
	battle.deploy_preview_id = hero_id
	battle.deploy_preview_active = true
	_update_deploy_preview(screen_pos)

func recall_hero_to_bench(hero_id: int) -> void:
	if sim.recall_hero(hero_id):
		if selected_id == hero_id:
			selected_id = 0
			for i in sim.heroes.size():
				if bool(sim.heroes[i].get("deployed",false)) and sim.heroes[i].hp > 0.0:
					selected_id = i
					break
		process_events()
		refresh()

func _update_deploy_preview(screen_pos: Vector2) -> void:
	var local: Vector2 = battle.get_global_transform().affine_inverse() * screen_pos
	battle.deploy_preview_point = battle.screen_to_world(local)
	var playable: Rect2 = Sim.ENDLESS_ARENA if sim.endless_mode else Sim.MOVE_AREA
	battle.deploy_preview_valid = playable.has_point(battle.deploy_preview_point) and not sim.is_device_plant_cell(battle.deploy_preview_point)
	battle.queue_redraw()

func _finish_deploy_drag(screen_pos: Vector2) -> void:
	var hero_id := dragging_hero_id
	dragging_hero_id = -1
	battle.deploy_preview_active = false
	var local: Vector2 = battle.get_global_transform().affine_inverse() * screen_pos
	var point: Vector2 = battle.screen_to_world(local)
	var playable: Rect2 = Sim.ENDLESS_ARENA if sim.endless_mode else Sim.MOVE_AREA
	if playable.has_point(point) and not sim.is_device_plant_cell(point) and hero_id > 0 and not test_mode and not sim.endless_mode and not recruited_heroes.has(hero_id):
		_begin_recruitment(hero_id, point)
		return
	if playable.has_point(point) and sim.deploy_hero(hero_id, point):
		selected_id = hero_id
		process_events()
	refresh()

func run_v4_test() -> void:
	var suite = preload("res://scripts/qa_v4.gd").new()
	await suite.run(self)

func run_v5_test() -> void:
	var suite = preload("res://scripts/qa_v5.gd").new()
	await suite.run(self)

func run_v6_test() -> void:
	var suite = preload("res://scripts/qa_v6.gd").new()
	await suite.run(self)

func run_v7_test() -> void:
	var suite = preload("res://scripts/qa_v7.gd").new()
	await suite.run(self)

func run_v8_test() -> void:
	var suite = preload("res://scripts/qa_v8.gd").new()
	await suite.run(self)

func run_v9_test() -> void:
	var suite = preload("res://scripts/qa_v9.gd").new()
	await suite.run(self)

func run_v10_test() -> void:
	var suite = preload("res://scripts/qa_v10.gd").new()
	await suite.run(self)

func run_reward_ui_test() -> void:
	var suite = preload("res://scripts/qa_reward_ui.gd").new()
	await suite.run(self)

func run_v64_test() -> void:
	var suite = preload("res://scripts/qa_v64.gd").new()
	await suite.run(self)

func run_v65_visual_test() -> void:
	var suite = preload("res://scripts/qa_v65_visual.gd").new()
	await suite.run(self)

func run_v67_visual_test() -> void:
	var suite = preload("res://scripts/qa_v67_visual.gd").new()
	await suite.run(self)

func run_card_rework_test() -> void:
	var suite = preload("res://scripts/qa_card_rework.gd").new()
	await suite.run(self)

func run_achievement_test() -> void:
	var suite = preload("res://scripts/qa_achievements.gd").new()
	await suite.run(self)

func run_v74_test() -> void:
	var suite = preload("res://scripts/qa_v74.gd").new()
	await suite.run(self)

func run_squad_scroll_test() -> void:
	var suite = preload("res://scripts/qa_squad_scroll.gd").new()
	await suite.run(self)

func run_v70_test() -> void:
	var suite = preload("res://scripts/qa_v70.gd").new()
	await suite.run(self)

func run_v69_visual_test() -> void:
	var suite = preload("res://scripts/qa_v69_visual.gd").new()
	await suite.run(self)

func run_v68_visual_test() -> void:
	var suite = preload("res://scripts/qa_v68_visual.gd").new()
	await suite.run(self)

func run_v68_test() -> void:
	var suite = preload("res://scripts/qa_v68.gd").new()
	await suite.run(self)

func run_v66_test() -> void:
	var suite = preload("res://scripts/qa_v66.gd").new()
	await suite.run(self)

func run_v65_test() -> void:
	var suite = preload("res://scripts/qa_v65.gd").new()
	await suite.run(self)

func run_v63_test() -> void:
	var suite = preload("res://scripts/qa_v63.gd").new()
	await suite.run(self)

func run_v77_endless_test() -> void:
	var suite = preload("res://scripts/qa_v77_endless.gd").new()
	await suite.run(self)

func run_v61_visual_test() -> void:
	var suite = preload("res://scripts/qa_v61_visual.gd").new()
	await suite.run(self)

func run_v60_visual_test() -> void:
	var suite = preload("res://scripts/qa_v60_visual.gd").new()
	await suite.run(self)

func run_v59_visual_test() -> void:
	var suite = preload("res://scripts/qa_v59_visual.gd").new()
	await suite.run(self)

func run_v58_visual_test() -> void:
	var suite = preload("res://scripts/qa_v58_visual.gd").new()
	await suite.run(self)

func run_v58_test() -> void:
	var suite = preload("res://scripts/qa_v58.gd").new()
	await suite.run(self)

func run_v57_performance_test() -> void:
	var suite = preload("res://scripts/qa_v57_performance.gd").new()
	await suite.run(self)

func run_v57_map_test() -> void:
	var suite = preload("res://scripts/qa_v57_map.gd").new()
	await suite.run(self)

func run_v56_test() -> void:
	var suite = preload("res://scripts/qa_v56.gd").new()
	await suite.run(self)
func run_v55_test() -> void:
	var suite = preload("res://scripts/qa_v55.gd").new()
	await suite.run(self)
func run_v54_test() -> void:
	var suite = preload("res://scripts/qa_v54.gd").new()
	await suite.run(self)

func run_v53_test() -> void:
	var suite = preload("res://scripts/qa_v53.gd").new()
	await suite.run(self)

func run_v52_test() -> void:
	var suite = preload("res://scripts/qa_v52.gd").new()
	await suite.run(self)

func run_v51_test() -> void:
	var suite = preload("res://scripts/qa_v51.gd").new()
	await suite.run(self)

func run_v50_test() -> void:
	var suite = preload("res://scripts/qa_v50.gd").new()
	await suite.run(self)

func run_v49_test() -> void:
	var suite = preload("res://scripts/qa_v49.gd").new()
	await suite.run(self)

func run_v48_test() -> void:
	var suite = preload("res://scripts/qa_v48.gd").new()
	await suite.run(self)

func run_v34_test() -> void:
	var suite = preload("res://scripts/qa_v34.gd").new()
	await suite.run(self)

func run_v33_restart_test() -> void:
	var suite = preload("res://scripts/qa_v33_restart.gd").new()
	await suite.run(self)

func run_v33_ui_test() -> void:
	var suite = preload("res://scripts/qa_v33_ui.gd").new()
	await suite.run(self)

func run_v33_test() -> void:
	var suite = preload("res://scripts/qa_v33.gd").new()
	await suite.run(self)

func run_v32_test() -> void:
	var suite = preload("res://scripts/qa_v32.gd").new()
	await suite.run(self)

func run_v31_test() -> void:
	var suite = preload("res://scripts/qa_v31.gd").new()
	await suite.run(self)

func run_v30_test() -> void:
	var suite = preload("res://scripts/qa_v30.gd").new()
	await suite.run(self)

func run_v29_test() -> void:
	var suite = preload("res://scripts/qa_v29.gd").new()
	await suite.run(self)

func run_v28_test() -> void:
	var suite = preload("res://scripts/qa_v28.gd").new()
	await suite.run(self)

func run_v27_test() -> void:
	var suite = preload("res://scripts/qa_v27.gd").new()
	await suite.run(self)

func run_v26_test() -> void:
	var suite = preload("res://scripts/qa_v26.gd").new()
	await suite.run(self)

func run_v25_test() -> void:
	var suite = preload("res://scripts/qa_v25.gd").new()
	await suite.run(self)

func run_v20_test() -> void:
	var suite = preload("res://scripts/qa_v20.gd").new()
	await suite.run(self)

func run_v19_test() -> void:
	var suite = preload("res://scripts/qa_v19.gd").new()
	await suite.run(self)

func run_v18_test() -> void:
	var suite = preload("res://scripts/qa_v18.gd").new()
	await suite.run(self)

func run_v17_test() -> void:
	var suite = preload("res://scripts/qa_v17.gd").new()
	await suite.run(self)

func run_v16_test() -> void:
	var suite = preload("res://scripts/qa_v16.gd").new()
	await suite.run(self)

func run_v15_test() -> void:
	var suite = preload("res://scripts/qa_v15.gd").new()
	await suite.run(self)



func _play_loss_transition() -> void:
	if dialogue != null and not test_mode and sim.state == "lost":
		await dialogue.play_death_transition(sim.Readability.report(sim))
		if not pending_achievement_ids.is_empty():
			await _show_pending_achievements()
		if sim.state == "lost":
			return_to_main_menu()

func _show_pending_achievements() -> void:
	if pending_achievement_ids.is_empty() or achievement_popup == null:
		return
	var ids: Array[String] = pending_achievement_ids.duplicate()
	pending_achievement_ids.clear()
	achievement_popup.open(ids)
	await achievement_popup.dismissed





func _begin_recruitment(hero_id: int, point: Vector2) -> void:
	if hero_id < 0 or hero_id >= sim.heroes.size() or not sim.deployment_slot_unlocked(hero_id):
		return
	var hero: Dictionary = sim.heroes[hero_id]
	# Reuse the expression portrait catalog; dialogue only shows the NPC.
	var portrait_path: String = dialogue.portrait_catalog.resolve_line({"speaker": str(hero.name), "text": "该我上场了。"})
	if not ResourceLoader.exists(portrait_path):
		portrait_path = ""
	var scene_key := "deploy_%s_%d" % [sim.current_stage_id, hero_id]
	var correct := {"text":"先守住水晶，我掩护你的侧翼。", "response":"这次我会守好自己的位置。出发吧。", "response_speaker":str(hero.name), "recruit_success":true}
	var wrong := {"text":"不用配合，你自己冲进敌阵。", "response":"你根本没有把我当作同伴。这场战斗，我不奉陪了！", "response_speaker":str(hero.name), "recruit_success":false}
	story.stories[scene_key] = [{"portrait":portrait_path, "speaker":str(hero.name), "text":"水晶已经升至 Lv.%d。该我上场了，你希望我们如何配合？" % sim.run_state.crystal_level, "choices":[correct, wrong]}]
	var authored: Array = preload("res://scripts/recruitment_dialogue.gd").for_character(story.stories,str(hero.character_id),randi_range(0,1))
	if not authored.is_empty():
		story.stories[scene_key] = authored
	var variants: Array[String] = []
	for graph_key: String in story.graph_scenes:
		if graph_key.begins_with("deploy_%s_" % str(hero.character_id)):
			variants.append(graph_key)
	if not variants.is_empty():
		scene_key = variants[randi_range(0, variants.size() - 1)]
	story.seen.erase(scene_key)
	pending_recruitment = {"hero_id":hero_id, "point":point, "success":false}
	recruitment_transition_active = true
	if not begin_dialogue(scene_key, "recruit"):
		pending_recruitment.clear()
		recruitment_transition_active = false

func _resolve_recruitment() -> void:
	if pending_recruitment.is_empty():
		recruitment_transition_active = false
		return
	var hero_id: int = int(pending_recruitment.get("hero_id", -1))
	var point: Vector2 = pending_recruitment.get("point", Vector2.ZERO)
	var accepted: bool = bool(pending_recruitment.get("success", false))
	pending_recruitment.clear()
	if accepted:
		await dialogue.play_success_animation()
		for panel: Dictionary in story.last_ending.get("comics", []):
			await dialogue.play_comic_panel(str(panel.get("image", "")), str(panel.get("text", "")))
		if sim.deploy_hero(hero_id, point, true):
			recruited_heroes[hero_id] = true
			selected_id = hero_id
			process_events()
		else:
			push_error("Recruitment accepted but hero deployment failed: %d, state=%s" % [hero_id, sim.state])
	else:
		await dialogue.play_death_transition("")
		for panel: Dictionary in story.last_ending.get("comics", []):
			await dialogue.play_comic_panel(str(panel.get("image", "")), str(panel.get("text", "")))
		await battle.play_recruit_departure(str(sim.heroes[hero_id].character_id), point)
		sim.rejected_recruits[hero_id] = true
	recruitment_transition_active = false
	hud.signature = ""
	refresh()

func open_workshop() -> void:
	if workshop != null or settings_panel == null or not settings_panel.is_open(): return
	workshop_suspended.clear()
	workshop_audio_suspended.clear()
	var battle_fx_bus := AudioServer.get_bus_index("BattleFX")
	workshop_audio_bus_db = AudioServer.get_bus_volume_db(battle_fx_bus) if battle_fx_bus >= 0 else 0.0
	_suspend_workshop_audio(self)
	for child: Node in get_children():
		var snapshot := {"node":child, "process_mode":child.process_mode}
		if child is CanvasLayer or child is CanvasItem:
			snapshot["visible"] = child.visible
			child.hide()
		workshop_suspended.append(snapshot)
		child.process_mode = Node.PROCESS_MODE_DISABLED
	workshop = WorkshopPanel.new()
	add_child(workshop)
	workshop.build(hud, bool(audio_director.values.reduced_effects))
	workshop.closed.connect(_workshop_closed)

func _suspend_workshop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		workshop_audio_suspended.append({"node":node, "paused":node.stream_paused})
		node.stream_paused = true
	for child: Node in node.get_children(): _suspend_workshop_audio(child)

func _workshop_closed() -> void:
	workshop = null
	for snapshot: Dictionary in workshop_suspended:
		var node: Node = snapshot.node
		if not is_instance_valid(node): continue
		node.process_mode = snapshot.process_mode
		if snapshot.has("visible"): node.visible = snapshot.visible
	for snapshot: Dictionary in workshop_audio_suspended:
		if is_instance_valid(snapshot.node): snapshot.node.stream_paused = bool(snapshot.paused)
	workshop_suspended.clear()
	workshop_audio_suspended.clear()
	var battle_fx_bus := AudioServer.get_bus_index("BattleFX")
	if battle_fx_bus >= 0: AudioServer.set_bus_volume_db(battle_fx_bus, workshop_audio_bus_db)
	settings_panel.workshop_button.grab_focus()

