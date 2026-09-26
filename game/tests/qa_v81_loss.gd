extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 root.add_child(game)
 await process_frame
 game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.story.reset()
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 game.sim.reset_stage("stage_03",squad,12);game.sim.start()
 for trial in 2:
  game.mode_select_panel.close()
  game.sim.reset_stage("stage_03",squad,12+trial);game.sim.start()
  game.sim.base_hp=0;game.sim.state="lost"
  game._physics_process(0.016)
  await create_timer(3.0).timeout
  assert(game.dialogue.animation_waiting,"Death screen must accept input on repeated losses")
  assert(not game.hud.overlay.visible,"Old empty result overlay must remain hidden")
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  game._input(click)
  await create_timer(0.6).timeout
  assert(game.mode_select_panel.is_open(),"Click must return to menu")
  assert(not game.loss_transition_shown,"New run must rearm death animation")
 print("REPEATED_LOSS: 2 losses, click-to-menu passed")
 game.queue_free();await process_frame;quit()
