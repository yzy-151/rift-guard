extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide();game.hud.get_child(0).show()
 var squad:Array[String]=["traveler","hero_01","hero_04"]
 game.sim.reset_stage("stage_endless",squad,42);game.sim.start();game.sim.terrain_features.clear();game.sim.enemies.clear();game.sim.enemy_lookup.clear()
 game.sim.terrain_features.append({"type":"blocked","area":Rect2(1510,1080,350,65)})
 game.sim.heroes[0].pos=Vector2(1580,1065);game.sim.heroes[1].pos=Vector2(1590,1170);game.sim.heroes[2].pos=Vector2(1770,1055)
 for h in game.sim.heroes:h.target=h.pos;h.deployed=true
 game.sim.spawn_enemy(Vector2(1660,1065),"grunt");game.sim.spawn_enemy(Vector2(1780,1170),"grunt")
 game.battle.camera_center=Vector2(1680,1110);game.battle.advance(0.01);game.refresh();game.battle.queue_redraw()
 RenderingServer.force_draw();await process_frame
 game.get_viewport().get_texture().get_image().save_png("res://../outputs/v89-wall-depth.png")
 game.queue_free();await process_frame;quit()
