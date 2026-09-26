extends SceneTree
const Director=preload("res://scripts/dialogue_director.gd")
const Recruit=preload("res://scripts/recruitment_dialogue.gd")
var errors=0
var paths=0
func check(ok: bool,label: String):
 if not ok:errors+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/home_stories.json"))
 for cid in ["hero_02","hero_06"]:
  for variant in 2:
   var key="home_%s_%d" % [cid,variant]
   var branching=key in ["home_hero_02_0","home_hero_06_1"]
   var routes: Array=[[0,0],[0,1],[1]] if branching else [[0],[1]]
   for recruit in [false,true]:
    for route in routes:
     var d=Director.new()
     d.stories[key]=Recruit.for_character(data,cid,variant) if recruit else data[key]
     var results: Array=[]
     d.choice_resolved.connect(func(c):
      if c.has("recruit_success" if recruit else "home_success"):results.append(c.get("recruit_success" if recruit else "home_success")))
     check(d.begin(key),"Scene begins")
     var at=0
     var steps=0
     while d.active and steps<40:
      steps+=1
      var row=d.current()
      check(not d._is_player_line(row),"Only NPC dialogue is shown")
      check(not str(row.text).is_empty(),"No blank response")
      if d.has_choices():
       check(at<route.size(),"Unexpected extra branch")
       if at>=route.size():break
       d.choose(route[at]);at+=1
      else:d.advance()
     check(not d.active,"Branch reaches ending")
     check(at==route.size(),"All requested choices reached")
     check(results.size()==1,"Exactly one terminal outcome; no premature success")
     if results.size()==1:check(results[0]==(route.all(func(n):return n==0)),"Outcome matches designed reversal")
     paths+=1
 check(not data['home_hero_02_0'][-1].choices[1].has("recruit_success"),"Conversion does not mutate home stories")
 print("DIALOGUE paths=",paths," failures=",errors)
 quit(1 if errors else 0)
