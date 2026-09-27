extends SceneTree
func _initialize():call_deferred("run")
func run():
 var s=load("res://scripts/combat_simulation.gd").new()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 s.reset_stage("stage_endless",squad,42)
 var rng=RandomNumberGenerator.new();rng.seed=882
 for i in 3000:
  var p=Vector2(rng.randf_range(80,3280),rng.randf_range(80,2280))
  var q=p+Vector2(rng.randf_range(-400,400),rng.randf_range(-400,400))
  var radius=rng.randf_range(0,50)
  s.endless_blocker_index_ready=true
  var indexed_point=not s._terrain_blocker_at(p,radius).is_empty()
  var indexed_segment=not s._terrain_blocker_on_segment(p,q,radius).is_empty()
  s.endless_blocker_index_ready=false
  assert(indexed_point==not s._terrain_blocker_at(p,radius).is_empty(),"point collision changed")
  assert(indexed_segment==not s._terrain_blocker_on_segment(p,q,radius).is_empty(),"segment collision changed")
 s.endless_blocker_index_ready=true
 s._rebuild_endless_navigation_fields()
 var cached=s.endless_nav_fields.duplicate(true)
 s.endless_nav_cache.clear();s._rebuild_endless_navigation_fields()
 assert(cached==s.endless_nav_fields,"cached navigation differs")
 s._rebuild_endless_navigation_grid()
 assert(s.endless_nav_cache.is_empty(),"terrain rebuild must invalidate cache")
 print("V88: 6000 indexed collision checks and navigation cache checks passed")
 quit()
