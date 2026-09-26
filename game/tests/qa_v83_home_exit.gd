extends SceneTree
func _initialize(): call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.story.reset();game.dialogue.hide()
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 game.sim.reset_stage("stage_03",squad,83)
 game.sim.heroes[0].pos=Vector2(400,220)
 game.sim.heroes[0].deployed=true
 game.sim.heroes[0].hp=0
 game.play_stage_exit()
 for tick in 900:
  game.sim.tick(1.0/60.0)
  game.battle.advance(1.0/60.0)
  if game.squad_panel.is_open():break
 print("EXIT_PROGRESS next_stage=",game.squad_panel.is_open()," phase=",game.battle.stage_exit_phase)
 if not game.squad_panel.is_open():quit(1);return
 for index in range(1,8):
  game.squad_panel.root.hide()
  game.sim.reset_stage("stage_%02d"%index,squad,83)
  game.sim.heroes[0].pos=Vector2(100,180)
  game.sim.heroes[0].hp=0;game.sim.heroes[0].deployed=false
  game.play_stage_exit()
  for tick in 900:
   game.sim.tick(1.0/60.0);game.battle.advance(1.0/60.0)
   if game.squad_panel.is_open():break
  assert(game.squad_panel.is_open(),"Every campaign transition must finish")
  assert(game.pending_stage_id=="stage_%02d"%(index+1),"Correct next stage")
 game.squad_panel.root.hide()
 game.sim.reset_stage("stage_02",squad,83)
 game.play_stage_exit()
 var enter=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true
 game._input(enter)
 assert(game.squad_panel.is_open(),"Enter must continue the cleared stage")
 game.squad_panel.root.hide()
 game.enter_home()
 game.home_panel.set_process(false)
 var home=game.home_panel
 home.move_player(Vector2.LEFT,0.1)
 assert(home.facing==-1.0,"Walking left must flip")
 home.move_player(Vector2.UP,0.1)
 assert(home.facing==-1.0,"Vertical movement must retain facing")
 home.move_player(Vector2.RIGHT,0.1)
 assert(home.facing==1.0,"Walking right must restore facing")
 for id in game.sim.database.characters:
  if not game.compendium.unlocked_characters.has(id):game.compendium.unlocked_characters.append(id)
 home.refresh_residents()
 for npc in home.npcs:
  assert(npc.pos.x>=30 and npc.pos.x<=2530,"Every resident must stay inside the map")
 home.player_pos=Vector2(100,480)
 assert(home.interaction_target().get("id")=="stages","Terminal must be reachable")
 var press=InputEventKey.new();press.keycode=KEY_F;press.pressed=true
 home.handle_input(press)
 assert(game.stage_select_panel.is_open(),"F must open stage selection")
 game.stage_select_panel.close()
 home.open();home.set_process(false)
 home.player_pos=Vector2(340,545);home.facing=-1.0;home.moving=true
 home._update_camera();home.map.queue_redraw()
 if DisplayServer.get_name()!="headless":await capture(game,"home-left")
 home.player_pos=Vector2(1960,545);home.facing=1.0
 home._update_camera();home.map.queue_redraw()
 if DisplayServer.get_name()!="headless":await capture(game,"home-right")
 home.close()
 game.sim.reset_stage("stage_03",squad,83)
 game.play_stage_exit();game.battle.advance(1.1)
 game.hud.get_child(0).show();game.hud.signature="";game.refresh()
 if DisplayServer.get_name()!="headless":await capture(game,"stage-exit")
 print("V83_PASS exit auto/dead/Enter, home facing/bounds/F facilities")
 await create_timer(1.0).timeout
 game.queue_free();await process_frame;quit()
func capture(game,label: String):
 for i in 3:await process_frame
 RenderingServer.force_draw()
 await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v83-home/"+label+".png"))
