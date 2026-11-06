extends SceneTree
const OUT = "res://../qa/traveler_skill_vfx_20261005"
var capture_root := OUT
var app
var frame_index := 0
var manifest: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")

func capture(key: String,mark: String="") -> void:
	app.battle.queue_redraw()
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	picture.save_png(capture_root+"/frames/frame-%04d.png" % frame_index)
	if not mark.is_empty(): picture.save_png(capture_root+"/"+key+"-"+mark+".png")
	frame_index+=1

func setup(element: String) -> void:
	var squad: Array[String]=["traveler","hero_03"]
	app.sim.reset_stage("stage_02",squad,20261005)
	app.sim.start()
	app.sim.enemies.clear();app.sim.enemy_lookup.clear();app.sim.terrain_features.clear()
	app.battle.reset_transients()
	var hero: Dictionary=app.sim.heroes[0]
	hero.deployed=true;hero.pos=Vector2(370,360);hero.target=hero.pos
	hero.element="" if element=="none" else element
	hero.energy=hero.max_energy
	var ally: Dictionary=app.sim.heroes[1]
	ally.deployed=true;ally.pos=Vector2(645,390);ally.target=ally.pos;ally.hp=100
	for p in [Vector2(575,360),Vector2(720,360),Vector2(860,360),Vector2(815,290),Vector2(815,440)]:
		var enemy: Dictionary=app.sim.spawn_enemy(p,"grunt")
		enemy.hp=100000;enemy.max_hp=100000;enemy.armor=0;enemy.shield=0
	app.sim.drain_events()
	app.selected_id=0
	app.refresh()

func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var wind_only := "--qa-wind-only" in OS.get_cmdline_user_args()
	if wind_only: capture_root = "res://../qa/wind_skill_vfx_20261005/capture"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_root+"/frames"))
	app=load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	app.test_mode=true;app.set_process(false);app.set_physics_process(false)
	app.mode_select_panel.close();app.stage_select_panel.close();app.squad_panel.root.hide();app.dialogue.hide()
	app.hud.get_child(0).show()
	for element in ["none","pyro","hydro","electro","geo","cryo","anemo"]:
		for ultimate in [false,true]:
			var key: String=element+("_e" if ultimate else "_q")
			if wind_only and not key in ["none_q","anemo_q","anemo_e","hydro_e"]: continue
			setup(element)
			var ability: Dictionary=app.sim.hero_ability(0,ultimate)
			var accepted: bool=app.sim.activate_hero_ultimate(0,Vector2(720,360)) if ultimate else app.sim.activate_hero_skill(0,Vector2(720,360))
			if not accepted: push_error("Cast rejected "+key);quit(1);return
			var batch: Array[Dictionary]=app.sim.drain_events()
			var impact_delay := .34
			for event: Dictionary in batch:
				if event.kind in ["skill_cast","ultimate_cast"]: impact_delay=float(event.get("hit_delay",.34))
			app.battle.accept_events(batch)
			var start := frame_index
			var seconds := (6.9 if key=="electro_e" else 5.1 if key=="cryo_e" else 4.7 if key=="anemo_q" else 4.1 if key=="anemo_e" else 3.6 if key=="hydro_e" else 2.7 if key=="pyro_e" else 2.0)
			var captured_peak := false
			var captured_cast := false
			var hit_time := -1.0
			var peak_offsets: Array[float] = [.08,.18,.32]
			var peaks_taken: Array[float] = []
			var wind_marks: Array[String] = []
			for frame in ceili(seconds*24):
				var dt := 1.0/24
				app.sim.elapsed+=dt
				app.sim._pending_impact_tick(dt);app.sim._skill_effect_tick(dt)
				var time := float(frame+1)/24
				var events: Array[Dictionary]=app.sim.drain_events()
				if hit_time<0:
					for event: Dictionary in events:
						if event.kind in ["traveler_fx_hit","traveler_fx_arc","skill_impact","ultimate_impact"] or (key=="hydro_e" and event.kind=="hit"):
							hit_time=time;break
				app.battle.accept_events(events);app.battle.advance(dt);app.refresh()
				for offset: float in peak_offsets:
					if hit_time>=0 and not offset in peaks_taken and time-hit_time>=offset-dt*.5:
						peaks_taken.append(offset)
						await capture(key,"hit-%.2f" % offset)
				if key=="anemo_q":
					for phase: Dictionary in [{"name":"start","time":.35},{"name":"sustain","time":1.5},{"name":"expired","time":4.30}]:
						if not str(phase.name) in wind_marks and time>=impact_delay+float(phase.time):
							wind_marks.append(str(phase.name))
							await capture(key,str(phase.name))
				if frame%2==0:
					var mark := ""
					if not captured_cast and time>impact_delay*.45 and time<impact_delay: mark="cast";captured_cast=true
					elif not captured_peak and time>impact_delay+.06: mark="peak";captured_peak=true
					elif key=="cryo_e" and time>impact_delay+4.08 and time<impact_delay+4.17: mark="burst"
					elif time>impact_delay+1.0 and time<impact_delay+1.1: mark="sustain"
					await capture(key,mark)
			manifest.append({"key":key,"start":start,"end":frame_index,"fps":12,"skill":ability.get("name",key)})
			print("TRAVELER DRAW CAPTURE "+key+" frames="+str(frame_index-start))
	var file := FileAccess.open(capture_root+"/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"));file.close()
	app.queue_free();await process_frame;app=null;await process_frame
	print("TRAVELER CAPTURE COMPLETE "+str(frame_index)+" frames")
	quit(0)
