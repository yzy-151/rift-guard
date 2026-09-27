extends SceneTree
var dismissed_count := 0
var resumed := false
func _initialize():call_deferred("run")
func click_at(point: Vector2):
 for pressed in [true,false]:
  var event=InputEventMouseButton.new()
  event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;event.position=point
  root.push_input(event,true)
  await process_frame
func run():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.story.reset();game.dialogue.root.hide()
 var popup=game.achievement_popup
 popup.dismissed.connect(func():dismissed_count+=1)
 var ids: Array[String]=[]
 game.campaign_prelude_active=true
 popup.open(ids);await process_frame
 await click_at(Vector2(640,570))
 if popup.is_open():
  push_error("REPRO: campaign transition gate swallowed achievement click")
  quit(1);return
 assert(dismissed_count==1)
 for key in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:
  popup.open(ids);await process_frame
  var event=InputEventKey.new();event.keycode=key;event.pressed=true
  root.push_input(event,true);await process_frame
  assert(not popup.is_open())
 assert(dismissed_count==4)
 game.campaign_prelude_active=false
 popup.open(ids);await process_frame
 await click_at(Vector2(20,20));assert(popup.is_open())
 await click_at(Vector2(640,570));assert(not popup.is_open())
 popup.close();assert(dismissed_count==5)
 game.campaign_prelude_active=true
 resume_after_modal(game)
 await process_frame
 await click_at(Vector2(640,570))
 assert(resumed and game.pending_achievement_ids.is_empty(),"Stage continuation must resume after dismissal")
 game.queue_free();await process_frame
 print("ACHIEVEMENT_DISMISS_PASS: gated click, Enter/Space/Esc, outside click, one dismissal")
 quit()
func resume_after_modal(game):
 game.pending_achievement_ids.assign(["test_pending_achievement"])
 await game._show_pending_achievements()
 resumed=true
