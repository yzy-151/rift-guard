extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const Effects=preload("res://scripts/rewards/combat_card_effects.gd")
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 root.add_child(game);await process_frame
 game.test_mode=true;game.set_process(false);game.set_physics_process(false)
 game.mode_select_panel.close();game.stage_select_panel.close();game.squad_panel.root.hide();game.dialogue.hide();game.story.reset()
 var s=game.sim
 var squad: Array[String]=["traveler","hero_02","hero_06"]
 assert(s.database.errors.is_empty())
 assert(s.database.cards.size()==150)
 var changed=0
 for card in s.database.cards:
  if card.effect!="card_bundle":continue
  changed+=1
  s.reset_stage("stage_01",squad,84)
  var before=s.heroes.duplicate(true)
  for stack in 2:
   s.rewards.offered.assign([card])
   assert(s.rewards.take(0,s,1 if card.target=="character" else -1))
  var targets=[1] if card.target=="character" else [0,1,2]
  for index in targets:
   var h=s.heroes[index];var old=before[index]
   for part in card.components:
    var fields={"range_flat":"range","armor_flat":"armor","move_speed_flat":"speed","projectile_count_add":"projectile_count","pierce_add":"pierce","blast_add":"blast_radius","echo_add":"echo_ratio"}
    if fields.has(part.effect):assert(is_equal_approx(float(h[fields[part.effect]]),float(old.get(fields[part.effect],0))+2*part.value),card.id)
    elif part.effect=="attack_multiplier":assert(is_equal_approx(h.damage,old.damage+old.base_damage*part.value*2),card.id)
    elif part.effect=="health_multiplier":assert(is_equal_approx(h.max_hp,old.max_hp+old.base_hp*part.value*2),card.id)
    elif part.effect=="attack_rate_multiplier":assert(is_equal_approx(h.rate,old.rate+old.base_rate*part.value*2),card.id)
    elif part.effect=="crit_flat":assert(is_equal_approx(h.crit_chance,minf(.85,old.crit_chance+part.value*2)),card.id)
    elif part.effect not in ["skill_area_add","skill_cooldown_add"]:assert(Effects.level(h,part.effect)==int(part.value*2),card.id)
  if card.target=="character":assert(is_equal_approx(s.heroes[0].damage,before[0].damage) and s.heroes[0].get("card_levels",{})==before[0].get("card_levels",{}))
 assert(changed==39)
 s.reset_stage("stage_01",squad,84)
 var h=s.heroes[0]
 h.card_levels={"third_strike":1}
 assert(Effects.on_attack(h)==1.0 and Effects.on_attack(h)==1.0 and Effects.on_attack(h)==2.5)
 h.card_levels={"opening_strike":1};h.card_attack_idle=3.0
 assert(is_equal_approx(Effects.on_attack(h),1.8))
 assert(Effects.on_attack(h)==1.0)
 Effects.tick(h,2.99);assert(Effects.on_attack(h)==1.0)
 Effects.tick(h,3.0);assert(is_equal_approx(Effects.on_attack(h),1.8))
 h.card_levels={"counter_ready":1};h.hp=h.max_hp;h.deployed=true;s.crystal_shield=0
 s.damage_hero(0,10)
 assert(is_equal_approx(Effects.on_attack(h),1.5) and Effects.on_attack(h)==1.0)
 h.card_levels={"attack_mend":8};h.hp=100;Effects.on_attack(h);assert(h.hp==108)
 h.card_levels={"desperate_guard":1};h.hp=h.max_hp*.2
 var old_hp=h.hp
 s.damage_hero(0,10)
 assert(is_equal_approx(old_hp-h.hp,8.5*100/(100+h.armor)))
 s.reset_stage("stage_01",squad,84);s.start();s.terrain_features.clear()
 var archer=s.heroes[2]
 archer.deployed=true;archer.pos=Vector2(400,360);archer.target=archer.pos
 archer.range=1000;archer.crit_chance=0;archer.block=0;archer.card_levels={"distant_strike":1}
 for i in 2:s.heroes[i].deployed=false
 var enemy=s.spawn_enemy(Vector2(700,360),"grunt")
 s._hero_tick()
 assert(s.projectiles.size()>0)
 assert(is_equal_approx(s.projectiles[0].damage,archer.damage*1.8),"Distant attack must gain 80%")
 s.projectiles.clear();enemy.pos=Vector2(600,360);archer.attack_timer=0
 s._hero_tick()
 assert(is_equal_approx(s.projectiles[0].damage,archer.damage),"Near attack must not gain distant bonus")
 s.reset_stage("stage_03",squad,84);s.start()
 for i in 3:
  var hero=s.heroes[i];hero.deployed=true;hero.pos=Vector2(400+i*160,360);hero.target=hero.pos
 game.hud.get_child(0).show();game.refresh()
 var batch: Array[Dictionary]=[]
 for hero in s.heroes:batch.append({"kind":"heal","pos":hero.pos,"value":100})
 game.fx.accept(batch);game.fx.advance(.28);game.battle.accept_events(batch);game.battle.advance(.28)
 if DisplayServer.get_name()!="headless":
  await capture(game,"healing")
  s.state="reward";s.rewards.offered.clear()
  for id in ["v75_kraken_tempo","v75_horizon_focus","v75_bramble_vest"]:
   for card in s.database.cards:
    if card.id==id:s.rewards.offered.append(card)
  game.hud.signature="";game.refresh()
  await capture(game,"cards")
 print("V84_PASS: 150 cards, 39 reworks, targets/stacks/triggers/healing")
 await create_timer(.8).timeout
 game.queue_free();await process_frame;quit()
func capture(game,label):
 for i in 3:await process_frame
 RenderingServer.force_draw();await process_frame
 game.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/v84-card-heal/"+label+".png"))
