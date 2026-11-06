extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_endless",squad,42);s.start()
 var ex=s.expedition
 assert(ex.tasks.size()==2)
 var task=ex.tasks[0];ex._complete(task);ex.completion_notice=0;ex.open_reward(s)
 assert(ex.cards_remaining==1)
 s.choose_reward(0,0);s.state="running"
 s.elapsed=119;ex.tick(s,0.01);assert(ex.tasks[0].done,"completion cannot cause early refresh")
 s.elapsed=120;ex.tick(s,0.01);assert(ex.task_batch==1 and not ex.tasks[0].done)
 var kinds:Dictionary={}
 for batch in 6:
  s.elapsed=batch*120;ex.task_batch=batch;ex._refresh_tasks(s)
  for t in ex.tasks:kinds[t.type]=true
 assert(kinds.size()==8)
 s.elapsed=900;assert(s._endless_enemy_level(s._endless_tier())==100)
 s.elapsed=600;var health600:float=s._endless_enemy_scales(s._endless_tier()).health
 s.elapsed=900;assert(s._endless_enemy_scales(s._endless_tier()).health>health600*50)
 assert(s._endless_enemy_pool(s._endless_phase()).has("ranged") and s._endless_enemy_pool(s._endless_phase()).has("buffer"))
 s.run_state.crystal_level=40;var xp40=s.endless_next_threshold();s.run_state.crystal_level=50;assert(s.endless_next_threshold()>xp40*7)
 s.enemies.clear();var k=s.spawn_enemy(Vector2(1500,1000),"boss_03");k.hp=k.max_hp*0.09;k.endless_boss_number=3
 s._maybe_summon_galio(k);var count=s.enemies.size();assert(count==2 and s.enemies[1].special_move=="galio_entrance")
 s._maybe_summon_galio(k);assert(s.enemies.size()==count)
 var h=s.heroes[0];s.terrain_features.clear();h.pos=Vector2(1600,1100)
 s.terrain_features.append({"type":"attack_ground","area":Rect2(1550,1050,100,100),"attack_bonus":1.0})
 assert(s.displayed_attack_damage(h)==h.damage*2)
 s.terrain_features.clear();s.terrain_features.append({"type":"high_ground","area":Rect2(1550,1050,100,100),"range_bonus":1.0})
 assert(s.displayed_attack_range(h)==h.range*2)
 s.enemies.clear();s.enemy_lookup.clear();s.elapsed=900;s.endless_next_boss_at=99999
 for i in 12:s.endless_spawn_timer=0;s._endless_spawn_tick(0.1)
 var leaders=s.enemies.filter(func(e):return e.kind=="boss_01")
 assert(leaders.size()>0 and leaders[0].level==100)
 print("V90 LOGIC PASS: tasks, schedule, rewards, lv100, growth, mixed roster, XP, Galio summon, terrain stats, commanders")
 quit()
