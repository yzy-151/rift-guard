extends SceneTree
var errors:Array[String]=[]
func check(ok:bool,msg:String):
 if not ok:errors.append(msg);push_error(msg)
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_endless",squad,42);s.start()
 s.expedition._complete(s.expedition.tasks[0]);s.expedition.completion_notice=0
 s.expedition.open_reward(s)
 check(s.state=="reward" and s.expedition.cards_remaining==3,"existing card UI reward state")
 var pending:int=s.run_state.pending_level_ups
 for i in 3:
  var taken:=false
  for card in 3:
   for hero in 3:
    if s.choose_reward(card,hero):taken=true;break
   if taken:break
  check(taken,"card %d accepted" % i)
 check(s.state=="running" and s.expedition.cards_remaining==0,"three picks return to combat")
 check(s.run_state.pending_level_ups==pending,"quest does not consume level-up cards")
 check(s.expedition.ground_distance(Vector2.ZERO,Vector2(0,80))==200,"ellipse collision metric")
 check(s._endless_boss_multipliers(6).x>100,"late boss scaling")
 var bug:Dictionary=s.spawn_enemy(Vector2(1800,1180),"originium_bug")
 var other:Dictionary=s.spawn_enemy(Vector2(1810,1180),"grunt")
 var hp:float=other.hp
 s.pending_impacts.append({"kind":"bug_blast","pos":bug.pos,"life":0.01,"radius":125.0,"damage":100000.0})
 s._pending_impact_tick(0.02)
 check(other.hp<hp,"bug damages monsters")
 check(s.pending_impacts.any(func(p):return p.kind=="bug_blast"),"secondary bug blast survives queue")
 print("ENDLESS V2 QA ",errors)
 quit(0 if errors.is_empty() else 1)
