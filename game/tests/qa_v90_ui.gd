extends SceneTree
const OUT="res://../outputs/v90-ui/"
func _initialize():call_deferred("run")
func shot(game,name:String):
 RenderingServer.force_draw();await process_frame
 var im=game.get_viewport().get_texture().get_image();im.resize(1280,720,Image.INTERPOLATE_LANCZOS);im.save_png(OUT+name+".png")
func run():
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide();game.hud.get_child(0).show()
 game.compendium_panel.open("characters");await process_frame;await shot(game,"characters");game.compendium_panel.close()
 game.stage_select_panel.open();game.stage_select_panel._focus_stage("stage_03");await shot(game,"roster");game.stage_select_panel.close()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 game.sim.reset_stage("stage_endless",squad,42);game.sim.start();game.battle.camera_center=Vector2(1680,1180)
 game.battle.advance(0.01);game.refresh();game.battle.queue_redraw();await shot(game,"tasks")
 game.sim.reset_stage("stage_01",squad,42);game.sim.state="won";game.advance_stage();await shot(game,"choice")
 assert(game.stage_clear_choice.is_open())
 var frame=game.stage_clear_choice.root.get_child(1)
 var choices:Array=[]
 for node in frame.get_children():
  if node is Button:choices.append(node)
 var original_damage=game.sim.heroes[0].damage
 var point:Vector2=choices[1].get_global_rect().get_center()
 for pressed in [true,false]:
  var event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point;root.push_input(event,true);await process_frame
 assert(game.sim.endless_mode and game.sim.heroes[0].damage==original_damage,"inheritance click")
 print("V90 UI PASS: encyclopedia, roster, tasks, inheritance click")
 game.queue_free();await process_frame;quit()
