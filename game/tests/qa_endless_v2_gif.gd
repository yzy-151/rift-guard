extends SceneTree
var index:=0
func _initialize():call_deferred("run")
func capture(g):
 g.refresh();g.battle.queue_redraw();RenderingServer.force_draw();await process_frame
 var img:Image=g.get_viewport().get_texture().get_image();img.resize(1024,576)
 img.save_png("res://../outputs/endless-v2/frames/frame-%04d.png" % index);index+=1
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/endless-v2/frames"))
 var g=load("res://main.tscn").instantiate();root.add_child(g);await process_frame
 g.test_mode=true;g.set_process(false);g.set_physics_process(false)
 g.mode_select_panel.close();g.stage_select_panel.close();g.squad_panel.root.hide();g.dialogue.hide();g.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 g.sim.reset_stage("stage_endless",squad,42);g.sim.start();g.battle.camera_center=g.sim.heroes[0].pos
 g.sim.command_move(0,g.sim.expedition.tasks[0].pos)
 for frame in 24*25:
  if g.sim.state=="reward" and g.sim.expedition.cards_remaining==0:g.sim.choose_reward(0,0)
  g.sim.tick(1.0/24);g.process_events();g.battle.advance(1.0/24);g.sim.active_view_rect=g.battle.visible_world_rect()
  if frame%2==0:await capture(g)
  if frame==300:g.get_viewport().get_texture().get_image().save_png("res://../outputs/endless-v2/map.png")
  if g.sim.expedition.cards_remaining>0:
   for hold in 24:await capture(g)
   g.get_viewport().get_texture().get_image().save_png("res://../outputs/endless-v2/cards.png")
   for pick in 3:
    g.sim.choose_reward(0,0);await capture(g)
   break
 g.sim.elapsed=172;g.sim.state="running"
 for frame in 48:
  g.sim.tick(1.0/24);g.process_events();g.battle.advance(1.0/24)
  if frame%2==0:await capture(g)
 g.get_viewport().get_texture().get_image().save_png("res://../outputs/endless-v2/warning.png")
 for i in g.sim.heroes.size():
  g.sim.heroes[i].pos=Vector2(2370,620)+Vector2(i*65,0);g.sim.heroes[i].target=g.sim.heroes[i].pos
 g.battle.camera_center=g.sim.heroes[0].pos
 g.refresh();g.battle.queue_redraw();RenderingServer.force_draw();await process_frame
 g.get_viewport().get_texture().get_image().save_png("res://../outputs/endless-v2/district.png")
 print("ENDLESS V2 DEMO frames=",index)
 g.queue_free();await process_frame;quit()
