extends SceneTree
const MainScene=preload("res://main.tscn")
func _initialize():call_deferred("run")
func run():
 var game=MainScene.instantiate()
 root.add_child(game)
 await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close()
 game.squad_panel.root.hide();game.dialogue.hide();game.story.reset()
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 game.sim.reset_stage("stage_03",squad,92526);game.sim.start()
 game.sim.enemies.clear();game.sim.enemy_lookup.clear()
 for i in 3:
  var h=game.sim.heroes[i]
  h.deployed=true;h.pos=Vector2(440+i*105,300+i*65);h.target=h.pos
 for i in 6:
  game.sim.spawn_enemy(Vector2(865+i%3*90,285+i/3*145),"grunt" if i%2==0 else "ranged")
 game.sim.heroes[0].invulnerable_timer=2.5
 game.sim.crystal_shield=90
 game.sim.enemies[0].frozen_timer=2.0
 game.sim.enemies[1].attack_pending=true
 game.sim.enemies[1].warning_timer=0.7
 game.sim.enemies[1].warning_total=1.0
 game.sim.enemies[1].warning_pos=game.sim.heroes[2].pos
 game.sim.enemies[1].warning_radius=65.0
 game.sim.drain_events()
 game.hud.get_child(0).show()
 game.selected_id=0;game.refresh();game.battle.advance(0.1)
 for i in 4:await process_frame
 RenderingServer.force_draw()
 await process_frame
 var image=game.get_viewport().get_texture().get_image()
 var args=OS.get_cmdline_user_args()
 var destination="res://../outputs/combat-readability/battle.png"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/stage03-art"))
 image.save_png(ProjectSettings.globalize_path(destination))
 game.sim.rewards.offered.assign([{"id":"qa_attack","name":"攻击强化","target":"character","effect":"attack_multiplier","value":1.0}])
 game.hud.reward_panel.show()
 game.hud.reward_panel.show_target_picker(0,game.sim)
 for i in 3:await process_frame
 RenderingServer.force_draw()
 await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/combat-readability/card-preview.png"))
 print("STAGE03_CAPTURE ",destination)
 game.queue_free();await process_frame;quit()
