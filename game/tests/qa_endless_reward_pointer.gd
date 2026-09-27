extends SceneTree
func _initialize():call_deferred("run")
func run():
 var g=load("res://main.tscn").instantiate();root.add_child(g);await process_frame
 g.test_mode=true;g.set_process(false);g.set_physics_process(false)
 g.mode_select_panel.close();g.stage_select_panel.close();g.squad_panel.root.hide();g.dialogue.hide();g.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 g.sim.reset_stage("stage_endless",squad,42);g.sim.start()
 g.sim.expedition.pending_rewards=1;g.sim.expedition.open_reward(g.sim)
 var ok:=true
 for pick in 3:
  var global_card:Dictionary={}
  for c:Dictionary in g.sim.rewards.cards:
   if c.get("target","")=="global" and g.sim.rewards.eligible(c,g.sim.run_state):global_card=c;break
  g.sim.rewards.offered.assign([global_card.duplicate(),global_card.duplicate(),global_card.duplicate()]);g.sim.rewards.offer_revision+=1
  g.refresh();await process_frame
  var button:Button=g.hud.reward_panel.buttons[0]
  var point:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
  for down in [true,false]:
   var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down
   g.get_viewport().push_input(e,true);await process_frame
  ok=ok and g.sim.expedition.cards_remaining==2-pick
 print("EXISTING CARD TEMPLATE POINTER x3 ",ok," state=",g.sim.state)
 ok=ok and g.sim.state=="running";g.queue_free();await process_frame;quit(0 if ok else 1)
