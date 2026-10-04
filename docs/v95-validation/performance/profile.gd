extends SceneTree
var game
var output := ""
var pack_path := ""
var profile_dir := get_script().resource_path.get_base_dir()
var results: Array[Dictionary] = []
func _initialize() -> void:
 for arg: String in OS.get_cmdline_user_args():
  if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
  if arg.begins_with("--profile-pack="): pack_path=arg.trim_prefix("--profile-pack=")
 if not output.is_absolute_path(): quit(2);return
 DirAccess.make_dir_recursive_absolute(output)
 if not pack_path.is_empty() and not ProjectSettings.load_resource_pack(pack_path): quit(3);return
 call_deferred("run")
func stats(values: Array[float]) -> Dictionary:
 if values.is_empty(): return {}
 var sorted:=values.duplicate();sorted.sort()
 var sum:=0.0
 for v:float in values:sum+=v
 return {"mean_ms":sum/values.size(),"p95_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*0.95))],"max_ms":sorted[-1],"samples":values.size()}
func fixture(stage: String, count: int, name: String) -> void:
 var squad: Array[String]=["traveler","hero_12","hero_13"]
 game.mode_select_panel.close();game.story.reset();game.dialogue.root.hide()
 game.sim.reset_stage(stage,squad,9511);game.sim.start()
 game.sim.base_hp=1000000;game.sim.base_max_hp=1000000
 for hero:Dictionary in game.sim.heroes:
  hero.hp=1000000.0;hero.max_hp=1000000.0;hero.deployed=true
 game.sim.enemies.clear();game.sim.enemy_lookup.clear()
 var roster: Array[String]=["hilichurl_brute","armored","slime_pyro","runner","originium_bug","charger","rift_bat"]
 for i in count:
  var point:=Vector2(1180-float(i%10)*38,230+float(i/10)*28)
  if stage=="stage_endless":point=game.sim.heroes[0].pos+Vector2.from_angle(float(i)*TAU/count)*(210+float(i%6)*24)
  var enemy:Dictionary=game.sim.spawn_enemy(point,"hilichurl_brute" if name=="campaign-crowd" else roster[i%roster.size()])
  enemy.hp=1000000.0;enemy.max_hp=1000000.0
 game.battle.sim=game.sim;game.battle.reset_transients();game.battle.camera_center=game.sim.heroes[0].pos
 game.battle.draw_samples.clear();game.battle.section_samples.clear();game.hud.signature="";game.hud.get_child(0).show()
 var measurements: Dictionary={}
 for key:String in ["simulation","events","archive","hud","visual","frame"]:measurements[key]=[] as Array[float]
 var previous:=Time.get_ticks_usec()
 for frame in 140:
  var started:=Time.get_ticks_usec()
  game.sim.tick(1.0/60.0)
  var end:=Time.get_ticks_usec();var sim_ms:=float(end-started)/1000
  started=end;game.process_events();end=Time.get_ticks_usec();var event_ms:=float(end-started)/1000
  started=end;game.compendium.observe(game.sim);end=Time.get_ticks_usec();var archive_ms:=float(end-started)/1000
  started=end;game.hud.refresh(game.sim,0);end=Time.get_ticks_usec();var hud_ms:=float(end-started)/1000
  started=end;game.battle.advance(1.0/60.0);game.fx.advance(1.0/60.0);end=Time.get_ticks_usec();var visual_ms:=float(end-started)/1000
  await process_frame
  if frame>=20:
   measurements.simulation.append(sim_ms);measurements.events.append(event_ms);measurements.archive.append(archive_ms);measurements.hud.append(hud_ms);measurements.visual.append(visual_ms)
   measurements.frame.append(float(Time.get_ticks_usec()-previous)/1000)
  previous=Time.get_ticks_usec()
 var draw: Array[float]=game.battle.draw_samples.slice(mini(20,game.battle.draw_samples.size()))
 var row: Dictionary={"fixture":name,"enemy_count":game.sim.enemies.size(),"projectile_count":game.sim.projectiles.size(),"quality":game.sim.performance_budget.quality_scale,"draw":stats(draw)}
 for key:String in measurements:row[key]=stats(measurements[key])
 for key:String in game.battle.section_samples: row["draw_"+key]=stats(game.battle.section_samples[key])
 results.append(row);print("PROFILE: "+JSON.stringify(row))
 if DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  game.get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
 Engine.max_fps=0
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
  DisplayServer.window_set_size(Vector2i(1920,1080))
 game=load("res://main.tscn").instantiate();root.add_child(game)
 for frame in 4:await process_frame
 game.set_process(false);game.set_physics_process(false);game.test_mode=true
 var measured_view=load(profile_dir.path_join("profile_view.gd")).new()
 measured_view.sim=game.sim
 game.add_child(measured_view)
 game.fx.reparent(measured_view);measured_view.sheet_effects=game.fx;game.fx.battle_view=measured_view
 game.battle.hide();game.battle=measured_view
 await fixture("stage_02",0,"campaign-empty")
 await fixture("stage_02",14,"campaign-crowd")
 await fixture("stage_endless",96,"endless-stress")
 var f:=FileAccess.open(output.path_join("profile.json"),FileAccess.WRITE)
 f.store_string(JSON.stringify({"pack":pack_path,"version":ProjectSettings.get_setting("application/config/version"),"renderer":DisplayServer.get_name(),"fixtures":results},"\t"))
 game._stop_scene_audio(game);game.queue_free();await process_frame;quit()


