extends SceneTree
func _initialize():call_deferred("run")
func run():
 var lib=load("res://scripts/enemy_sequence_library.gd").new()
 var args=OS.get_cmdline_user_args();var warm=args.has("warm")
 var max_slice:=0.0;var start=Time.get_ticks_usec()
 if warm:
  lib.queue_prewarm(["boss_03","boss_galio"])
  while not lib.warm_queue.is_empty() or not lib.warm_loading.is_empty():
   var t=Time.get_ticks_usec();lib.poll_prewarm();max_slice=maxf(max_slice,(Time.get_ticks_usec()-t)/1000.0);await process_frame
 var values:Array[float]=[]
 for id in ["boss_03","boss_galio"]:
  for state in lib.definition(id).states:
   var t=Time.get_ticks_usec();var texture=lib.texture(id,state);assert(texture!=null);texture.get_rid();values.append((Time.get_ticks_usec()-t)/1000.0)
 values.sort()
 print("V90 ATLAS ","warm" if warm else "cold"," max_demand_ms=",values[-1]," sum_demand_ms=",values.reduce(func(a,b):return a+b,0.0)," max_warm_slice_ms=",max_slice," elapsed_ms=",(Time.get_ticks_usec()-start)/1000.0)
 quit()
