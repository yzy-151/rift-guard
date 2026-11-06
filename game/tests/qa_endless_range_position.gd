extends SceneTree
var failures:=0
func check(ok:bool,message:String):
 if not ok:failures+=1;push_error(message)
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler"]
 s.reset_stage("stage_endless",squad,42);s.start();s.terrain_features.clear()
 var h=s.heroes[0];h.range=200;h.element="wind";h.projectile_count=1;h.heal_timer=999
 var expected:=Vector2(166,66.4)
 for y in [300,1100,2000]:
  h.pos=Vector2(1600,y);s.elapsed+=1
  var radii:Vector2=s.attack_range_screen_radii(h)
  print("y=",y," radii=",radii)
  check(radii.is_equal_approx(expected),"position must not scale endless range")
  for offset in [Vector2(160,8),Vector2(0,68),Vector2(175,8),Vector2(0,80)]:
   var inside:bool=offset.x==160 or offset.y==68
   check(s.is_in_attack_range(h,h.pos+offset)==inside,"range boundary differs by position")
   s.enemies.clear();s.projectiles.clear();h.attack_timer=0
   var shots_before:int=h.shots
   s.spawn_enemy(h.pos+offset,"grunt");s._hero_tick()
   check((h.shots>shots_before)==inside,"actual targeting disagrees with displayed ellipse")
 s.terrain_features.append({"type":"high_ground","area":Rect2(1500,1900,200,200),"range_bonus":1.0})
 check(s.attack_range_screen_radii(h).is_equal_approx(expected*2),"terrain range bonus retained")
 s.reset_stage("stage_01",squad,42);s.terrain_features.clear();h=s.heroes[0];h.range=200
 h.pos=Vector2(640,140);var top:Vector2=s.attack_range_screen_radii(h)
 h.pos=Vector2(640,580);check(s.attack_range_screen_radii(h).x>top.x,"campaign perspective retained")
 print("ENDLESS RANGE failures=",failures);quit(1 if failures else 0)

