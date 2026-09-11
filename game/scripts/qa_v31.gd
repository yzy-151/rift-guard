extends RefCounted

const Resolver = preload("res://scripts/campaign_node_resolver.gd")

var checks := 0
var failures := 0

func expect(ok: bool, message: String) -> void:
	checks += 1
	if ok: print("V31 PASS: " + message)
	else: failures += 1; push_error("V31 FAIL: " + message)

func capture(game, name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await game.get_tree().create_timer(0.25).timeout
	await game.get_tree().process_frame
	RenderingServer.force_draw()
	var directory := ProjectSettings.globalize_path("res://../docs/v31-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	var image: Image = game.get_viewport().get_texture().get_image()
	if image != null: image.save_png(directory.path_join(name+".png"))

func run(game) -> void:
	game.mode_select_panel.close()
	var state = game.sim.run_state
	state.reset_run_meta()
	var reward: int = state.grant_stage_reward("qa_stage",60,80,true)
	expect(reward >= 70 and state.rift_shards == reward,"stage clear grants kill health and boss currency")
	expect(state.grant_stage_reward("qa_stage",99,100,true) == 0,"stage reward cannot be claimed twice")
	state.rift_shards = 999
	var resolver = Resolver.new()
	var shop := {"id":"qa_shop","type":"shop"}
	var shop_options: Array[Dictionary] = resolver.build_options(shop,state,game.sim.database)
	expect(shop_options.size() == 3,"shop generates three readable offers")
	var before: int = state.rift_shards
	var bought := resolver.apply_option(shop_options[0],state)
	expect(bool(bought.ok) and state.rift_shards < before and state.equipped_relics.size() == 1,"shop purchase validates price and grants relic")
	var duplicate := resolver.apply_option(shop_options[0],state)
	expect(not bool(duplicate.ok),"resolved campaign node cannot be exploited twice")

	var rest_options: Array[Dictionary] = resolver.build_options({"id":"qa_rest","type":"rest"},state,game.sim.database)
	var rested := resolver.apply_option(rest_options[0],state)
	expect(bool(rested.ok) and int(state.campaign_perks.get("fortify",0)) == 1,"rest node grants a persistent expedition perk")
	var hidden_options: Array[Dictionary] = resolver.build_options({"id":"qa_hidden","type":"hidden","unlock":"hero_12"},state,game.sim.database)
	var hidden := resolver.apply_option(hidden_options[0],state)
	expect(bool(hidden.ok) and state.story_flags.has("hidden_signal_resolved") and int(state.relationships.get("hero_12",0)) == 2,"hidden node records flag relationship and unlock payload")
	var recruit_options: Array[Dictionary] = resolver.build_options({"id":"qa_recruit","type":"recruit"},state,game.sim.database)
	var recruited := resolver.apply_option(recruit_options[0],state)
	expect(bool(recruited.ok) and state.squad.size() == 2,"recruit node changes the active expedition squad")

	state.grant_relic("relic_glass_cannon")
	state.add_campaign_perk("charged_start",1)
	state.add_campaign_perk("elemental_focus",1)
	var squad: Array[String] = state.squad.duplicate()
	game.sim.reset_stage("stage_02",squad,3101)
	expect(game.sim.base_max_hp == 125 and game.sim.heroes[0].max_hp > game.sim.heroes[0].base_hp,"fortify affects next stage base and hero health")
	expect(game.sim.heroes.all(func(hero:Dictionary)->bool:return hero.energy == 18.0),"rested energy applies to every squad member")
	expect(game.sim.reaction_damage_bonus >= 0.12,"hidden elemental focus changes combat reaction damage")
	expect(game.sim.heroes[0].damage > game.sim.heroes[0].base_damage,"purchased relic is reapplied after stage reset")

	state.rift_shards = 999
	var panel_node: Dictionary = {"id":"qa_panel_shop","type":"shop"}
	var panel_options: Array[Dictionary] = resolver.build_options(panel_node,state,game.sim.database)
	game.campaign_event_panel.open(panel_node,panel_options,state.rift_shards)
	expect(game.campaign_event_panel.is_open() and game.campaign_event_panel.option_buttons.size() == 3,"Helltaker-styled event panel presents three choices")
	var click_point: Vector2 = game.campaign_event_panel.option_buttons[0].get_global_rect().get_center()
	expect(game.campaign_event_panel.activate_at(click_point),"campaign option responds to a real pointer hit path")
	expect(game.campaign_event_panel.resolved,"successful pointer selection locks the one-shot node")
	await capture(game,"01-campaign-shop-choice")

	var exported: Dictionary = state.export_build()
	expect(exported.has("rift_shards") and exported.has("campaign_perks") and exported.has("resolved_nodes"),"final build records expedition economy and node choices")
	print("V31 QA COMPLETE: %d checks, %d failures" % [checks,failures])
	game.get_tree().quit(failures)
