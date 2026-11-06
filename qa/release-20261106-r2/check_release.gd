extends SceneTree
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func run()->void:
	var app=load("res://main.tscn").instantiate();root.add_child(app);app.test_mode=true
	await process_frame;await process_frame
	check(not app.qa_storage_path.is_empty(),"isolated saves")
	check(app.sim.database.errors.is_empty(),"valid database: "+str(app.sim.database.errors))
	check(app.sim.database.modes.rift_watch.stage_ids==["stage_01","stage_02","stage_03"],"three chapters only")
	check(app.stage_select_panel.buttons.size()==8,"all eight stage buttons visible")
	app.stage_select_panel.open()
	for item in app.stage_select_panel.buttons.values():
		check(Rect2(0,0,1280,720).encloses(item.get_global_rect()),"stage card within screen")
	check(app.sim.database.stages.size()==9,"all campaign and endless data retained")
	check(app.stage_select_panel._is_unlocked("stage_01"),"first chapter unlocked")
	check(not app.stage_select_panel._is_unlocked("stage_02"),"second chapter starts locked")
	for i in range(1,9):app.compendium.cleared_stages["stage_%02d"%i]=true
	for i in range(4,9):
		var id:="stage_%02d"%i
		check(not app.stage_select_panel._is_unlocked(id),"old saves cannot unlock "+id)
		app.choose_stage(id)
		check(app.pending_stage_id!=id,"direct navigation blocked "+id)
	app.stage_select_panel._refresh()
	for i in range(4,9):
		var id:="stage_%02d"%i
		check(app.stage_select_panel.buttons[id].disabled,"later stage disabled")
		check(app.stage_select_panel.lock_labels[id].text=="暂未开放","permanent lock is explicit")
	for key:String in ["mode1_stage2_opening","mode1_stage2_won","mode1_stage3_opening","mode1_final_won"]:
		for branch in 2:
			var story=load("res://scripts/dialogue_director.gd").new()
			check(story.begin(key),"scene begins "+key)
			for step in 60:
				if not story.active:break
				var line:Dictionary=story.current()
				var portrait:=str(line.get("portrait",""))
				if not portrait.is_empty():check(ResourceLoader.exists(portrait),"portrait exists")
				if story.has_choices():story.choose(branch)
				else:story.advance()
			check(not story.active and story.last_ending.get("status")=="success","branch resolves "+key)
	app.story.reset();app.mode_select_panel.close()
	var squad:Array[String]=["traveler","hero_03","hero_13"]
	app.sim.reset_stage("stage_03",squad,6121)
	app.sim.state="won"
	check(not app.has_next_stage(),"third stage is finale")
	app.advance_stage()
	check(app.stage_clear_choice.is_open(),"final settlement opens")
	app.stage_clear_choice.root.hide();app._continue_campaign_stage()
	check(app.mode_select_panel.is_open(),"final settlement returns to menu")
	app.mode_select_panel.close();app.sim.state="paused"
	var level:int=app.sim.run_state.crystal_level
	app.open_debug_reward()
	check(app.sim.state=="paused" and app.sim.run_state.crystal_level==level,"help cannot award cards")
	for bar in app.hud.hero_hp_bars:
		check(bar.mouse_filter==Control.MOUSE_FILTER_IGNORE,"health bar cannot steal a deployment drag")
	for bar in app.hud.hero_energy_bars:
		check(bar.mouse_filter==Control.MOUSE_FILTER_IGNORE,"energy bar cannot steal a deployment drag")
	app.campaign_prelude_active=false
	app.sim.state="between"
	app._handle_mobile_back()
	check(app.sim.state=="paused" and not app.mode_select_panel.is_open(),"Android back pauses between waves")
	app._handle_mobile_back()
	check(app.sim.state=="between","Android back resumes the previous wave state")
	app.sim.state="reward"
	app._handle_mobile_back()
	check(app.sim.state=="reward" and not app.mode_select_panel.is_open(),"Android back preserves card selection")
	var result:={"checks":checks,"failures":failures}
	var out:String=get_script().resource_path.get_base_dir().path_join("results.json")
	var f:=FileAccess.open(out,FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	print("RELEASE CHECKS ",checks," failures=",failures.size())
	app.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
