extends SceneTree
const Main=preload("res://main.tscn")
var report=[]
func _initialize():call_deferred("run")
func run():
 var game=Main.instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_physics_process(false);game.set_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.root.hide();game.story.reset()
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 for stage in ["stage_02","stage_03"]:
  game.sim.reset_stage(stage,squad,822);game.sim.start();game.battle.reset_transients();game.hud.get_child(0).show()
  var s=game.sim;var choices=0;var first_card=-1.0;var second_deploy=-1.0;var peaks=0;var next_log=20.0;var captured=false
  for step in 21600:
   if s.state in ["lost","won"]:break
   for i in s.heroes.size():
    if not s.heroes[i].deployed and s.deployment_slot_unlocked(i) and s.heroes[i].hp>0:
     if s.deploy_hero(i,Vector2(540,280+i*75),true) and i==1:second_deploy=s.elapsed
   if s.state=="reward":
    var best=0;var score=-1
    var priority={"assign_traveler_element":90,"attack_multiplier":100,"squad_attack_multiplier":98,"support_barrage":95,"support_crossfire":94,"projectile_count_add":88,"pierce_add":80,"attack_rate_multiplier":75,"range_flat":70}
    for i in s.rewards.offered.size():
     var value=int(priority.get(s.rewards.offered[i].effect,30))
     if value>score:score=value;best=i
    if s.choose_reward(best,0):
     choices+=1
     if first_card<0:first_card=s.elapsed
   if step%30==0 and not s.enemies.is_empty():
    var target=s.enemies[0]
    for e in s.enemies:
     if e.hp>0 and e.pos.x<target.pos.x:target=e
    for h in s.heroes:
     if h.deployed and h.hp>0:
      s.activate_hero_skill(h.id,target.pos);s.activate_hero_ultimate(h.id,target.pos)
   s.tick(1.0/30.0);peaks=maxi(peaks,s.enemies.size())
   game.battle.accept_events(s.drain_events());game.battle.advance(1.0/30.0)
   if s.elapsed>=next_log:
    print(stage," t=",int(s.elapsed)," HP=",s.base_hp," level=",s.run_state.crystal_level," cards=",choices," kills=",s.kills," enemies=",s.enemies.size()," queued=",s.pending_stage_spawns.size())
    next_log+=30
   if step%60==0:
    game.hud.signature="";game.refresh();await process_frame
    if not captured and s.elapsed>=230 and DisplayServer.get_name()!="headless":
     captured=true;RenderingServer.force_draw();await process_frame
     game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v82-balance/"+stage+"-late.png"))
  var result={"stage":stage,"elapsed":s.elapsed,"state":s.state,"base":s.base_hp,"kills":s.kills,"cards":choices,"first_card":first_card,"second_deploy":second_deploy,"peak":peaks}
  report.append(result);print("RESULT ",JSON.stringify(result))
  game.hud.signature="";game.refresh();await process_frame;RenderingServer.force_draw();await process_frame
  if DisplayServer.get_name()!="headless":game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v82-balance/"+stage+".png"))
 var f=FileAccess.open("res://../outputs/v82-balance/play.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"  "));f.close()
 game.queue_free();await process_frame;quit()
