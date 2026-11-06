extends SceneTree
const SIM=preload("res://qa/crowded_20261005/profiled_sim.gd")
const VIEW=preload("res://qa/performance_20261006/profiled_view.gd")
const PROFILE=preload("res://data/stage_profiles/endless_arena_profile.gd")
const BOSS_DISPATCH=preload("res://scripts/boss_skill_vfx_20261006.gd")
var output := "res://../qa/performance-20261006/baseline"
var app
var freeze_path := "res://../qa/performance-20261006/frozen.var"
var freeze: Dictionary={}
var reference_warnings := false
var boss_vfx_enabled := true
var source_files: Dictionary={}

func source_manifest() -> Dictionary:
	var files: Array[String]=[]
	_collect_sources("res://scripts",files)
	_collect_sources("res://data",files)
	_collect_sources("res://shaders",files)
	files.append_array(["res://project.godot","res://main.tscn","res://qa/performance_20261006/native_benchmark.gd","res://qa/performance_20261006/profiled_view.gd","res://qa/crowded_20261005/profiled_sim.gd"])
	files.sort()
	var result: Dictionary={}
	for file: String in files:
		if FileAccess.file_exists(file):result[file]=FileAccess.get_sha256(file)
	return result

func _collect_sources(path: String,files: Array[String])->void:
	var directory:=DirAccess.open(path)
	if directory==null:return
	for file: String in directory.get_files():
		if file.get_extension() in ["gd","json","gdshader","tres"]:files.append(path.path_join(file))
	for child: String in directory.get_directories():_collect_sources(path.path_join(child),files)
func _initialize()->void: run.call_deferred()
func stats(values: Array)->Dictionary:
	if values.is_empty(): return {}
	values.sort();return {"p50":values[values.size()/2],"p95":values[floori(values.size()*.95)],"samples":values.size()}
func create_fixture(count: int):
	var sim=SIM.new(6106206,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage("stage_endless",squad,6106206);sim.start();sim.elapsed=211.0
	sim.run_state.crystal_level=11;sim.run_state.pending_level_ups=0;sim.team_level=11
	sim.endless_spawn_timer=999999;sim.endless_next_boss_at=999999;sim.troop_convoy_timer=999999
	sim.expedition.next_tasks_at=999999;sim.expedition.tasks.clear();sim.formation_mode="hold"
	for index in sim.heroes.size():
		var hero: Dictionary=sim.heroes[index]
		hero.pos=PROFILE.HUB+[Vector2(-80,0),Vector2(-150,65),Vector2(-130,-65)][index];hero.target=hero.pos
		hero.deployed=true;hero.hp=1000000.0;hero.max_hp=1000000.0;hero.damage=78.0;hero.range=550.0;hero.rate=2.4
		hero.projectile_count=3;hero.pierce=3;hero.chain_count=1;hero.blast_radius=0.0;hero.energy=100.0;hero.block=0
	sim.heroes[0].element="anemo";sim.run_state.traveler_element="anemo"
	for index in count-1:
		var kind: String=["ranged","buffer","hilichurl_brute","ranged","armored","rift_bat","buffer","grunt"][index%8]
		var point:=PROFILE.HUB+Vector2(70+(index%9)*56,-160+(index/9)*57)
		var enemy: Dictionary=sim.spawn_enemy(point,kind)
		enemy.hp=1000000.0;enemy.max_hp=1000000.0;enemy.damage=8.0;enemy.speed=9.0;enemy.armor=15.0;enemy.affixes=[]
		enemy.spawn_timer=0.0;enemy.spawn_phase="ground";enemy.attack_timer=float(index%7)*.14
		if kind in ["ranged","buffer"]:sim._begin_enemy_warning(enemy,sim.heroes[index%3],{})
	var boss: Dictionary=sim.spawn_enemy(PROFILE.HUB+Vector2(290,-85),"boss_01")
	boss.hp=1000000.0;boss.max_hp=1000000.0;boss.damage=16;boss.speed=0;boss.special_timer=2.0;boss.spawn_timer=0.0
	sim._start_rift_warning(boss,"rift_laser")
	sim.activate_hero_skill(1,PROFILE.HUB+Vector2(200,20));sim.activate_hero_ultimate(1,PROFILE.HUB+Vector2(200,20))
	sim.activate_hero_skill(2,PROFILE.HUB+Vector2(130,-20));sim.activate_hero_ultimate(2,PROFILE.HUB+Vector2(230,-20))
	sim.activate_hero_skill(0,PROFILE.HUB+Vector2(220,30))
	return sim
func freeze_fixture(sim)->Dictionary:
	var row: Dictionary={}
	for key in ["heroes","enemies","events","projectiles","enemy_projectiles","enemy_hazards","skill_effects","orbitals","pending_impacts","supports","elapsed","next_id","next_projectile_id","team_level"]:row[key]=sim.get(key).duplicate(true) if sim.get(key) is Array or sim.get(key) is Dictionary else sim.get(key)
	row.run_snapshot=sim.export_run_snapshot()
	return row
func restore_fixture(row: Dictionary):
	var sim=create_fixture(51)
	sim.import_run_snapshot(row.run_snapshot)
	for key: String in row:
		if key=="run_snapshot":continue
		var value: Variant=row[key]
		if value is Array:
			sim.get(key).assign(value.duplicate(true))
		elif value is Dictionary:sim.set(key,value.duplicate(true))
		else:sim.set(key,value)
	sim.enemy_lookup.clear()
	for enemy: Dictionary in sim.enemies:sim.enemy_lookup[int(enemy.id)]=enemy
	sim._reset_projectile_queries();sim.state="running";sim.timings.clear()
	return sim
func top_up(sim,frame: int,count: int)->void:
	while sim.projectiles.size()<count:
		var id: int=sim.next_projectile_id;sim.next_projectile_id+=1
		var point:=PROFILE.HUB+Vector2(-45+(id%5)*12,-155+(id%16)*19)
		sim.projectiles.append({"visual_id":id,"pos":point,"previous_pos":point,"direction":Vector2.RIGHT,"speed":650.0,"life":2.6,"hit_ids":[],"can_hit_air":true,"damage":18.0,"element":"hydro" if id%3 else "anemo","source_id":id%3,"splash":false,"slow":false,"pierce":3,"chain_count":1,"blast_radius":0.0,"echo_ratio":0.0,"critical":false,"ballistic":true,"style":"standard"})
	if frame%80==0:
		for enemy: Dictionary in sim.enemies:
			if enemy.kind in ["ranged","buffer"]:sim._begin_enemy_warning(enemy,sim.heroes[int(enemy.id)%3],{})
	for hero: Dictionary in sim.heroes:hero.hp=hero.max_hp
	sim.run_state.pending_level_ups=0;sim.state="running"
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
		elif arg=="--qa-warning-reference":reference_warnings=true
		elif arg=="--qa-boss-vfx-disabled":boss_vfx_enabled=false
	BOSS_DISPATCH.rendering_enabled=boss_vfx_enabled
	source_files=source_manifest()
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.size=Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	app=load("res://main.tscn").instantiate();root.add_child(app)
	await process_frame;await process_frame
	app.test_mode=true;app.process_mode=Node.PROCESS_MODE_DISABLED
	app.mode_select_panel.close();app.settings_panel.root.hide();app.home_panel.close();app.stage_select_panel.close();app.squad_panel.root.hide();app.dialogue.hide();app.hud.get_child(0).show()
	for player: Node in app.find_children("*","AudioStreamPlayer",true,false):player.stop()
	if FileAccess.file_exists(freeze_path):freeze=FileAccess.open(freeze_path,FileAccess.READ).get_var()
	else:
		for count in [51,80]:freeze[str(count)]=freeze_fixture(create_fixture(count))
		var frozen_file:=FileAccess.open(freeze_path,FileAccess.WRITE);frozen_file.store_var(freeze);frozen_file.close()
	var report: Dictionary={"schema":2,"renderer":RenderingServer.get_current_rendering_method(),"window":str(root.size),"logical_viewport":str(root.content_scale_size),"vsync":"disabled benchmark only","seed":6106206,"boss_dispatch":"boss_skill_vfx_20261006.gd","boss_vfx_enabled":boss_vfx_enabled,"warning_reference":reference_warnings,"source_sha256":JSON.stringify(source_files).sha256_text(),"source_files":source_files,"freeze_sha256":FileAccess.get_sha256(freeze_path),"fixture":"frozen 51/80 mixed enemies incl rift commander / traveler+Furina+Gwen / Lv11@211s / 90 or 120 real piercing projectiles / skills+warnings","cases":{}}
	for count in [51,80]:
		for trial in 2:
			var sim=restore_fixture(freeze[str(count)])
			app.sim=sim;app.selected_id=0
			app.battle.queue_free();await process_frame
			var view=VIEW.new();view.sim=sim;view.reference_warnings=reference_warnings;view.selected_id=0;view.camera_center=PROFILE.HUB;view.endless_camera_follow=false;view.process_mode=Node.PROCESS_MODE_DISABLED
			app.battle=view;app.add_child(view);app.move_child(view,0)
			app.fx=load("res://scripts/sheet_effects.gd").new();view.add_child(app.fx);view.sheet_effects=app.fx;app.fx.battle_view=view
			await process_frame
			var measures: Dictionary={};var counters: Dictionary={};var damage_before:=0.0
			for enemy: Dictionary in sim.enemies:damage_before+=float(enemy.hp)
			for frame in 210:
				top_up(sim,frame,90 if count==51 else 120)
				sim.set_active_view_rect(view.visible_world_rect());seed(6106206+frame)
				var start:=Time.get_ticks_usec();sim.tick(1.0/60.0);var tick_end:=Time.get_ticks_usec()
				var batch: Array[Dictionary]=sim.drain_events();view.accept_events(batch);app.fx.accept(batch);view.advance(1.0/60.0);app.fx.advance(1.0/60.0);var advance_end:=Time.get_ticks_usec()
				app.hud.refresh(sim,0);var hud_end:=Time.get_ticks_usec();view.queue_redraw()
				await process_frame;await RenderingServer.frame_post_draw
				var wall_ms: float=(Time.get_ticks_usec()-start)/1000.0
				if frame>=30:
					var values: Dictionary={"tick_ms":(tick_end-start)/1000.0,"advance_ms":(advance_end-tick_end)/1000.0,"hud_ms":(hud_end-advance_end)/1000.0,"draw_cpu_ms":view.draw_total_us/1000.0,"wall_frame_ms":wall_ms,"draw_calls":float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),"primitives":float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)),"glow_quads":view.combat_glow_layer.sprites.size(),"active_effects":view.effects.size(),"damage_numbers":view.damage_numbers.active.size(),"friendly_shots":sim.projectiles.size(),"hostile_shots":sim.enemy_projectiles.size()}
					for key in view.phase_us:values["draw_"+str(key)+"_ms"]=float(view.phase_us[key])/1000.0
					for key in values:
						if not measures.has(key):measures[key]=[]
						measures[key].append(values[key])
				if frame==75 and trial==0:root.get_texture().get_image().save_png(output.path_join("enemies-%d.png"%count))
				for event: Dictionary in batch:
					if event.kind in ["projectile_impact","enemy_shot","rift_laser"]:counters[str(event.kind)]=int(counters.get(str(event.kind),0))+1
			var phases: Dictionary={}
			for key in measures:phases[key]=stats(measures[key])
			for key in sim.timings:phases["sim_"+key+"_ms"]=stats(sim.timings[key].slice(30))
			var damage_after:=0.0
			for enemy: Dictionary in sim.enemies:damage_after+=float(enemy.hp)
			var result: Dictionary={"metrics":phases,"correctness":{"damage_to_enemies":damage_before-damage_after,"events":counters,"enemies":sim.enemies.size(),"elapsed":sim.elapsed},"fixture_sha256":FileAccess.get_sha256(freeze_path)}
			report.cases["%d-trial%d"%[count,trial]]=result
			var file:=FileAccess.open(output.path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
			print("NATIVE %d trial %d %s"%[count,trial,JSON.stringify(result)])
	report.source_unchanged=source_manifest()==source_files
	var final_file:=FileAccess.open(output.path_join("native.json"),FileAccess.WRITE);final_file.store_string(JSON.stringify(report,"\t"));final_file.close()
	app.queue_free();await process_frame;await process_frame;quit(0 if report.source_unchanged else 2)
