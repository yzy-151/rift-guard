extends SceneTree
func _initialize():call_deferred("run")
func run():
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var g=load("res://main.tscn").instantiate();root.add_child(g);await process_frame
 g.test_mode=true;g.set_process(false);g.set_physics_process(false)
 g.mode_select_panel.close();g.stage_select_panel.close();g.squad_panel.root.hide();g.dialogue.hide();g.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 g.sim.reset_stage("stage_endless",squad,42);g.sim.start();g.sim.elapsed=900;g.sim.endless_next_boss_at=99999;g.sim.endless_spawn_timer=99999;g.sim.troop_convoy_timer=99999
 for h:Dictionary in g.sim.heroes:h.range=450;h.rate=4;h.projectile_count=3;h.pierce=2;h.damage*=4
 for i in 80:
  var e:Dictionary=g.sim.spawn_enemy(Vector2(1870+(i%10)*12,1060+(i/10)*23),"hilichurl_brute" if i%3!=0 else "shielded")
  e.hp=10000000;e.max_hp=e.hp;e.damage=0
 g.battle.camera_center=g.sim.heroes[0].pos
 var cpu:Array[float]=[];var render:Array[float]=[];var frames:Array[float]=[]
 for f in 300:
  var start:=Time.get_ticks_usec()
  for h:Dictionary in g.sim.heroes:h.hp=h.max_hp
  g.sim.tick(1.0/60);var tick_ms:float=(Time.get_ticks_usec()-start)/1000.0
  g.battle.accept_events(g.sim.drain_events());g.battle.advance(1.0/60);g.sim.active_view_rect=g.battle.visible_world_rect();g.refresh();g.battle.queue_redraw()
  var render_start:=Time.get_ticks_usec();RenderingServer.force_draw();await process_frame
  if f>=60:cpu.append(tick_ms);render.append((Time.get_ticks_usec()-render_start)/1000.0);frames.append((Time.get_ticks_usec()-start)/1000.0)
 cpu.sort();render.sort();frames.sort()
 var label:="before" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
 var result:={"label":label,"enemies":g.sim.enemies.size(),"cpu_p50_ms":cpu[120],"cpu_p95_ms":cpu[228],"draw_wait_p50_ms":render[120],"draw_wait_p95_ms":render[228],"frame_p50_ms":frames[120],"frame_p95_ms":frames[228],"texture_memory_mb":Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576,"static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
 var path:="res://../outputs/optimization-v88/"+label
 FileAccess.open(path+".json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 g.get_viewport().get_texture().get_image().save_png(path+".png")
 print(JSON.stringify(result))
 g.queue_free();await process_frame;quit()
