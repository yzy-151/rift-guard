extends SceneTree
const Director = preload("res://scripts/dialogue_director.gd")
const Catalog = preload("res://scripts/dialogue_portrait_catalog.gd")
var branches := 0
func _initialize(): call_deferred("run")
func walk(key: String, path: Array) -> void:
 var d=Director.new()
 assert(d.begin(key))
 var step=0
 while d.active:
  var l: Dictionary=d.current()
  assert(not l.speaker in ["旅行者","旁白","荧","你"])
  var art=Catalog.new().resolve_line(l)
  assert(ResourceLoader.exists(art),art)
  if d.has_choices():
   if step==path.size():
    for i in l.choices.size(): walk(key,path+[i])
    return
   var expected=l.choices[path[step]].get("response_expression","")
   assert(d.choose(path[step]))
   assert(d.current().get("expression","")==expected)
   step+=1
  else: d.advance()
  assert(step<12)
 branches+=1
func run():
 var comics: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_comics.json"))
 assert(comics.size()==16)
 for key in comics:
  walk(key,[])
  for panel in comics[key]:assert(ResourceLoader.exists(panel.image))
 var game=load("res://main.tscn").instantiate()
 root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.compendium.save_path="res://../outputs/v85-story/test-compendium.json"
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.story.reset();game.dialogue.root.hide()
 var squad: Array[String]=["traveler","hero_02","hero_03"]
 game.sim.reset_stage("stage_01",squad,85)
 assert(game.begin_dialogue("mode1_opening","start"))
 await process_frame
 var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
 game._input(click)
 assert(game.story.index==0,"Click during entrance must not skip NPC lines")
 for index in 3:
  for tick in 300:
   if game.dialogue.animation_waiting:break
   await create_timer(.01).timeout
  assert(game.dialogue.animation_waiting)
  if DisplayServer.get_name()!="headless":await capture(game,"comic_%d"%index)
  game._input(click)
  await create_timer(.30).timeout
 for tick in 300:
  if not game.campaign_prelude_active:break
  await create_timer(.01).timeout
 assert(not game.campaign_prelude_active)
 await create_timer(.5).timeout
 var count=game.dialogue.portrait_entrance_count
 game.dialogue.advance()
 await create_timer(.4).timeout
 assert(game.dialogue.portrait_entrance_count==count,"Same portrait should stay still")
 game.dialogue.advance();await create_timer(.3).timeout
 assert(game.story.has_choices())
 if DisplayServer.get_name()!="headless":await capture(game,"roxy_choices")
 game.dialogue.choose_option(0)
 await create_timer(.4).timeout
 assert(game.dialogue.portrait_entrance_count==count+1,"Changed expression should enter")
 assert(game.campaign_recruits.has("hero_04"))
 if DisplayServer.get_name()!="headless":await capture(game,"roxy_success")
 game.dialogue.advance();await create_timer(.4).timeout
 game.dialogue.advance()
 for tick in 500:
  if game.dialogue.animation_waiting:break
  await create_timer(.01).timeout
 assert(game.dialogue.animation_waiting,"Success must wait for acknowledgement")
 game._input(click)
 for tick in 400:
  if game.squad_panel.is_open():break
  await create_timer(.01).timeout
 assert(game.squad_panel.is_open() and game.campaign_recruit_reselect)
 var recruited: Array[String]=["traveler","hero_04","hero_02"]
 game.squad_panel.root.hide()
 game.confirm_next_squad(recruited)
 assert(game.sim.run_state.squad.has("hero_04"))
 assert(not game.story.active and not game.campaign_prelude_active and not game.campaign_recruit_reselect)
 assert(game.sim.state=="running","Recruit confirmation must enter battle, not loop intro")
 print("V85_PASS scenes=16 branches=",branches," comics=3 portrait reuse/change, result expression, click gate, recruit -> battle")
 await create_timer(1.0).timeout
 game.queue_free()
 for frame in 4:await process_frame
 quit()
func capture(game,label):
 await process_frame;RenderingServer.force_draw();await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v85-story/"+label+".png"))
