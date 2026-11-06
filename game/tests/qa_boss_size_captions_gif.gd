extends SceneTree
const OUT="res://../outputs/boss-size-captions/frames"
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide();game.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 game.sim.reset_stage("stage_03",squad,42);game.sim.start()
 game.sim.enemies.clear();game.sim.enemy_lookup.clear()
 var galio:Dictionary=game.sim.spawn_enemy(Vector2(850,390),"boss_galio")
 var kindred:Dictionary=game.sim.spawn_enemy(Vector2(1070,500),"boss_03")
 galio.galio_revealed=true;kindred.galio_summoned=true;kindred.kindred_respite_used=true
 for h in game.sim.heroes:h.deployed=true;h.pos=Vector2(480,330+h.id*55);h.target=h.pos;h.hp=100000;h.max_hp=100000
 game.sim.drain_events()
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var index:=0
 for pair in [["galio_winds","kindred_wolf"],["galio_punch","kindred_dance"],["galio_durand","kindred_dread"],["galio_entrance","kindred_hunt"]]:
  galio.pos=Vector2(850,390);kindred.pos=Vector2(1070,500);galio.galio_takeoff_pos=galio.pos
  game.battle.effects.clear();game.battle.boss_skill_captions.clear();game.sim.enemy_hazards.clear();game.sim.enemy_projectiles.clear()
  for i in 120:
   var dt:=1.0/24.0
   if i==18:
    game.sim._start_galio_warning(galio,pair[0]);galio.special_pending=true;galio.special_move=pair[0]
    game.sim._start_kindred_warning(kindred,pair[1]);kindred.special_pending=true;kindred.special_move=pair[1]
    game.hud.announce_boss_skill_warning(galio.special_move_name,1.5,1)
    assert(not game.hud.boss_skill_warning_panel.visible)
   for boss in [galio,kindred]:
    if boss.get("special_pending",false):
     boss.special_warning-=dt
     if boss.special_warning<=0:
      boss.special_pending=false
      if boss==galio:game.sim._execute_galio_special(boss,pair[0])
      else:game.sim._execute_kindred_special(boss,pair[1])
   game.sim._enemy_projectile_tick(dt);game.sim._enemy_hazard_tick(dt)
   game.battle.accept_events(game.sim.drain_events());game.battle.advance(dt);game.refresh();game.battle.queue_redraw()
   RenderingServer.force_draw();await process_frame
   if i==25:assert(game.battle.boss_skill_captions.size()==2,"both bosses must have their own caption")
   if i%2==0:
    var picture=game.get_viewport().get_texture().get_image();picture.resize(1280,720,Image.INTERPOLATE_LANCZOS);picture.save_png(OUT+"/frame-%04d.png"%index);index+=1
 print("BOSS CAPTION QA: four pairs, both labels, no central banner, ",index," frames")
 game.queue_free();await process_frame;quit()
