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

 var hits: Array[Dictionary]=[{"kind":"hit","pos":game.sim.enemies[0].pos,"value":47,"element":"none","style":"blade_wave"},{"kind":"slash","pos":game.sim.enemies[0].pos,"angle":0.0,"element":"none"}]
 game.battle.accept_events(hits)
 game.battle.advance(0.04)
 await capture(game,"battle")
 game.sim.state="reward"
 game.sim.rewards.offered.clear()
 for effect in ["projectile_count_add","squad_range_flat","squad_attack_multiplier"]:
  for card in game.sim.rewards.cards:
   if card.effect==effect:
    game.sim.rewards.offered.append(card);break
 game.hud.signature="";game.refresh()
 await capture(game,"cards")
 for label in game.hud.reward_panel.summary_labels:
  assert(label.get_line_count()<=2,"Card preview must fit")
 game.sim.state="running";game.hud.signature="";game.refresh()
 game.hud.announce_deployment(game.sim.heroes[1].name)
 game.hud.refresh(game.sim,0)
 await create_timer(0.3).timeout
 await capture(game,"unlock")
 await create_timer(4.0).timeout
 game.hud.announce_route_warning({"boss":true})
 await create_timer(0.4).timeout
 await capture(game,"boss-warning")
 await create_timer(4.2).timeout
 print("V81_VISUAL complete")
 game.queue_free();await process_frame;quit()
func capture(game,name: String):
 for i in 3:await process_frame
 RenderingServer.force_draw()
 await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v81-fixes/"+name+".png"))
