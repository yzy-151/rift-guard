extends SceneTree
func _initialize():call_deferred("run")
func run():
 var folder:="res://../outputs/endless-v3/"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder+"frames"))
 var g=load("res://main.tscn").instantiate();root.add_child(g);await process_frame
 g.test_mode=true;g.set_process(false);g.set_physics_process(false)
 g.mode_select_panel.close();g.stage_select_panel.close();g.squad_panel.root.hide();g.dialogue.hide();g.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 g.sim.reset_stage("stage_endless",squad,42);g.sim.start()
 for i in g.sim.heroes.size():
  g.sim.heroes[i].pos=Vector2(2350,590)+Vector2(-i*70,i*40);g.sim.heroes[i].target=g.sim.heroes[i].pos
 g.battle.camera_center=g.sim.heroes[0].pos;g.sim.elapsed=166
 var index:=0
 for frame in 24*15:
  if g.sim.state=="reward":g.sim.choose_reward(0,0)
  g.sim.tick(1.0/24);g.process_events();g.battle.advance(1.0/24);g.sim.active_view_rect=g.battle.visible_world_rect()
  g.refresh();g.battle.queue_redraw()
  if frame%2==0:
   RenderingServer.force_draw();await process_frame
   var img:Image=g.get_viewport().get_texture().get_image();img.resize(1024,576)
   img.save_png(folder+"frames/frame-%04d.png" % index);index+=1
   if frame==24:img.save_png(folder+"map.png")
   if frame==180:img.save_png(folder+"warning.png")
 print("ENDLESS V3 DEMO ",index," frames")
 g.queue_free();await process_frame;quit()
