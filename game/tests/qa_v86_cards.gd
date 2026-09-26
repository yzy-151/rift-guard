extends SceneTree
const Sim = preload("res://scripts/combat_simulation.gd")
const Pool = preload("res://scripts/rewards/card_pool.gd")
const Synergies = preload("res://scripts/rewards/card_synergies.gd")
const Effects = preload("res://scripts/rewards/combat_card_effects.gd")
var squad: Array[String] = ["traveler","hero_04","hero_13"]
func _initialize():call_deferred("run")
func find_card(s,id):
 for card in s.database.cards:
  if card.id==id:return card
 assert(false,id)
 return {}
func pick(s,id,owner=0):
 s.state="reward";s.rewards.offered.assign([find_card(s,id)])
 s.run_state.pending_level_ups=1
 assert(s.choose_reward(0,owner),id)
func ids(cards):
 var found: Array[String]=[]
 for c in cards:found.append(str(c.id))
 return found
func fresh():
 var s=Sim.new()
 s.reset_stage("stage_03",squad,86)
 return s
func run():
 var s=fresh()
 # Every roll is deterministic, eligible and unique, with no seen cards when the pool permits.
 for seed in 60:
  var a=Pool.new(s.database.cards,seed)
  var b=Pool.new(s.database.cards,seed)
  s.run_state.crystal_level=2 if seed%3==0 else (10 if seed%3==1 else 30)
  a.draw_three(s.run_state);b.draw_three(s.run_state)
  var seen: Array[String]=[]
  for roll in 3:
   assert(ids(a.offered)==ids(b.offered))
   var batch=ids(a.offered)
   assert(batch.size()==3)
   for id in batch:assert(id not in seen);seen.append(id)
   for card in a.offered:assert(a.eligible(card,s.run_state))
   if s.run_state.crystal_level==2:assert(a.offered.any(func(c):return c.effect=="assign_traveler_element"))
   if s.run_state.crystal_level==10:assert(a.offered.any(func(c):return c.rarity=="mythic"))
   if s.run_state.crystal_level==30:assert(a.offered.any(func(c):return bool(c.get("mechanic",false))))
   if roll<2:assert(a.reroll(s.run_state) and b.reroll(s.run_state))
  assert(a.rerolls_left==0)
  var frozen=ids(a.offered);assert(not a.reroll(s.run_state));assert(frozen==ids(a.offered))
 s.run_state.traveler_element="pyro"
 s.rewards.draw(s)
 for c in s.rewards.offered:assert(c.effect!="assign_traveler_element")
 assert(not s.reroll_rewards(),"Cannot reroll outside reward")
 s.state="reward";s.run_state.pending_level_ups=3
 assert(s.reroll_rewards() and s.run_state.pending_level_ups==3)
 var tiny: Array[Dictionary]=[find_card(s,"single_attack_common")]
 var small=Pool.new(tiny,7);small.draw_three(s.run_state)
 assert(small.offered.size()==1 and small.reroll(s.run_state))
 s=fresh()
 pick(s,"heartsteel",0);pick(s,"warmogs_armor",1)
 assert(not Synergies.hero_active(s.heroes[0],"immortal_heart"))
 pick(s,"warmogs_armor",0)
 var h=s.heroes[0]
 assert(Synergies.hero_active(h,"immortal_heart"))
 var hp=float(h.max_hp)
 Effects.on_target(h,{"id":999})
 assert(is_equal_approx(h.max_hp,hp+15))
 h.hp=1;h.warmog_timer=0
 assert(is_equal_approx(Effects.tick(h,.01),150))
 pick(s,"lethal_tempo",0);pick(s,"conqueror",0)
 h.hp=1;h.conqueror_attacks=0
 for n in 3:assert(Effects.on_attack(h)==1.0)
 assert(Effects.on_attack(h)==2.0 and h.hp==61)
 # Every recipe is activatable, idempotent, and inherited without reapplying bonuses.
 s=fresh()
 for recipe in Synergies.RECIPES:
  for id in recipe.cards:pick(s,id,0)
  assert(Synergies.ready(recipe,s,s.heroes[0]))
 assert(s.run_state.card_synergies.size()==6)
 var skill=s.skill_power_bonus
 var elite=s.elite_damage_bonus
 Synergies.refresh(s);Synergies.refresh(s)
 assert(skill==s.skill_power_bonus and elite==s.elite_damage_bonus)
 var inherited=Sim.new();inherited.reset_stage("stage_endless",squad,86)
 assert(inherited.import_run_snapshot(s.export_run_snapshot()))
 assert(inherited.skill_power_bonus==skill and inherited.elite_damage_bonus==elite)
 assert(inherited.run_state.card_synergies.size()==6 and inherited.fireball_level>0)
 Synergies.refresh(inherited);assert(inherited.skill_power_bonus==skill)
 # Actual support damage and healing, and matching meteor visual / hit radius.
 s=fresh();pick(s,"support_red_moon");pick(s,"support_crossfire")
 var e=s.spawn_enemy(Vector2(700,360),"grunt");e.hp=100000;e.max_hp=100000
 var health=float(e.hp)
 var support=s.supports.support_crossfire.duplicate(true);support.lane_y=360
 s._trigger_support("support_crossfire",support)
 var enhanced=health-e.hp
 s.run_state.card_synergies.erase("cross_barrage");health=e.hp
 s._trigger_support("support_crossfire",support)
 assert(is_equal_approx(enhanced/(health-e.hp),1.35))
 pick(s,"warmogs_armor");pick(s,"support_tidal_aid")
 s.heroes[0].hp=1;s._trigger_support("support_heal",{"power":100.0})
 assert(s.heroes[0].hp==151)
 pick(s,"evolve_fireball");pick(s,"mechanic_blast_core")
 s.state="running";s.meteor_timer=0;s.pending_impacts.clear();s.events.clear()
 s._evolution_tick(.1)
 assert(s.pending_impacts.size()>0)
 assert(is_equal_approx(float(s.pending_impacts[0].radius),360.0))
 var fall=s.events.filter(func(v):return v.kind=="fireball_fall")
 assert(not fall.is_empty() and fall[0].radius==s.pending_impacts[0].radius)
 s.reset_stage("stage_01",squad,87)
 assert(s.run_state.card_synergies.is_empty() and not s.heroes[0].has("card_synergies"))
 await ui_check()
 print("V86_PASS: 60 seeds, 180 unique offers, reroll budget/eligibility, 8 recipes, scope, real damage/healing, meteor radius, inheritance, UI")
 quit()
func ui_check():
 var game=load("res://main.tscn").instantiate();root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.compendium.save_path="res://../outputs/v86-card-synergies/test-compendium.json"
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide();game.story.reset()
 game.sim.reset_stage("stage_03",squad,86);pick(game.sim,"heartsteel",0)
 game.sim.state="reward";game.sim.rewards.draw(game.sim);game.hud.signature="";game.refresh()
 game.hud.get_child(0).show()
 var panel=game.hud.reward_panel
 var before=ids(game.sim.rewards.offered)
 var input=InputEventKey.new();input.keycode=KEY_R;input.pressed=true
 game._input(input)
 assert(game.sim.rewards.rerolls_left==1 and ids(game.sim.rewards.offered)!=before)
 assert(panel.reroll_button.text.contains("1/2"))
 game.sim.rewards.offered.assign([find_card(game.sim,"warmogs_armor"),find_card(game.sim,"conqueror"),find_card(game.sim,"support_red_moon")])
 game.sim.rewards.offer_revision+=1;game.hud.signature="";game.refresh()
 panel.show_target_picker(0,game.sim)
 game._input(input)
 assert(game.sim.rewards.rerolls_left==1,"Target picker blocks refresh")
 assert(panel.target_buttons[0].tooltip_text.contains("可激活"))
 panel.close_target_picker();panel.show_synergies();game._input(input)
 assert(game.sim.rewards.rerolls_left==1,"Recipe overlay blocks refresh")
 if DisplayServer.get_name()!="headless":
  await capture(game,"synergies")
 panel.close_synergies()
 for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1440)]:
  root.size=size
  await create_timer(.3).timeout
  assert(not panel.reroll_button.get_global_rect().intersects(panel.buttons[2].get_global_rect()))
  assert(not panel.synergy_hint.get_global_rect().intersects(panel.history_label.get_global_rect()))
  if DisplayServer.get_name()!="headless":await capture(game,"cards-%d"%size.x)
 await create_timer(.5).timeout
 game.queue_free();await process_frame
func capture(game,label):
 await process_frame;RenderingServer.force_draw();await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v86-card-synergies/"+label+".png"))
