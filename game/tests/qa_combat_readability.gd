extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const Preview=preload("res://scripts/card_benefit_preview.gd")
const Runtime=preload("res://scripts/stages/stage_runtime.gd")
const Budget=preload("res://scripts/performance_budget.gd")
var failures=0
var checks=0
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func setup():
 var s=Sim.new(925,true)
 var ids: Array[String]=["traveler","hero_02","hero_06"]
 s.reset_stage("stage_03",ids,925);s.start()
 s.enemies.clear();s.enemy_lookup.clear()
 for h in s.heroes:
  h.deployed=true;h.armor=0;h.invulnerable_timer=0
 s.crystal_shield=0
 return s
func _initialize():call_deferred("run")
func run():
 var s=setup()
 var h=s.heroes[0]
 var before=float(h.hp)
 s.damage_hero(0,37,{"source_name":"测试射手","source_skill":"追踪球"})
 check(is_equal_approx(h.hp,before-37),"Damage is unchanged by provenance")
 check(s.last_incoming_hit.source_name=="测试射手" and s.last_incoming_hit.damage==37,"Exact HP damage and source captured")
 h.invulnerable_timer=1
 s.damage_hero(0,999,{"source_name":"无效攻击"})
 check(s.last_incoming_hit.source_name=="测试射手","Ignored invulnerable hit does not replace cause")
 h.invulnerable_timer=0
 s.damage_hero(0,1e9,{"source_name":"测试首领","source_skill":"重砸"})
 check(s.hero_down_causes.has(0) and s.hero_down_causes[0].source_skill=="重砸","Lethal skill recorded")
 check(s.Readability.report(s).contains("重砸"),"Loss report contains cause")
 s=setup();h=s.heroes[0]
 s._queue_enemy_projectile({"kind":"kindred_arrow","pos":h.pos,"target_id":0,"damage":23.0,"life":2.0,"speed":10.0,"source_name":"千珏","source_skill":"乱箭之舞"})
 s._enemy_projectile_tick(0.01)
 check(s.last_incoming_hit.source_name=="千珏","Delayed projectile keeps original source")
 var e=s.spawn_enemy(Vector2(100,360),"grunt")
 e.route_points=[];e.pos=Vector2(100,360);e.speed=0;e.attack_timer=999
 var base=s.base_hp
 s._enemy_tick(0.01)
 check(s.leak_count==1 and s.leak_damage==base-s.base_hp,"Leak ledger counts actual base loss")
 s.reset_stage("stage_01",["traveler"],1)
 check(s.leak_count==0 and s.hero_down_causes.is_empty() and s.last_incoming_hit.is_empty(),"New stage clears ledger")
 for effect in ["attack_multiplier","health_multiplier","attack_rate_multiplier","range_flat","armor_flat","projectile_count_add","pierce_add","crit_flat","heartsteel","warmogs_armor"]:
  s=setup();h=s.heroes[0]
  var card={"id":"qa","target":"character","effect":effect,"value":1.0}
  if effect=="crit_flat":h.crit_chance=0.8
  var text=Preview.hero_lines(card,h)
  var snapshot=h.duplicate(true)
  check(not text.is_empty() and h==snapshot,"Preview is non-mutating: "+effect)
  s.apply_v2_card_effect(card,0)
  if effect=="attack_multiplier":check(text.contains("%.0f"%h.damage),"Attack preview agrees with application")
  if effect=="health_multiplier":check(text.contains("%.0f"%h.max_hp),"HP preview agrees with application")
  if effect=="attack_rate_multiplier":check(text.contains("%.2f"%(1.0/h.rate)),"Interval preview agrees with application")
  if effect=="crit_flat":check(text.contains("85%") and is_equal_approx(h.crit_chance,0.85),"Crit preview uses real cap")
 s=setup();s.heroes[0].invulnerable_timer=0.1
 var rows=s.Readability.statuses(s,s.heroes[0])
 check(rows.size()>0 and float(rows[0][2])<1,"Status fades at timer end")
 check(Budget.critical_visual("enemy_shot") and Budget.critical_visual("enemy_volatile"),"Incoming attacks are priority visuals")
 var budget=Budget.new();budget.quality_scale=0.58
 check(not budget.can_spawn_cosmetic("hit",100) and budget.can_spawn_cosmetic("enemy_shot",100),"Load suppresses sparks but preserves enemy shots")
 var stages=JSON.parse_string(FileAccess.get_file_as_string("res://data/v2/stages.json"))
 for definition in stages:
  if not definition.has("breather_windows"):continue
  check(float(definition.get("pacing_health_multiplier",0))>=1.0,"Pacing preserves enemy health budget: "+definition.id)
  var rt=Runtime.new(definition)
  var expected=0;var emitted=0;var silence=true;var seen_boss=0
  for wave in definition.waves:expected+=int(wave.count)
  for tick in 2400:
   for event in rt.tick(0.25):
    if event.kind=="boss_wave":seen_boss+=1
    if event.kind!="spawn":continue
    emitted+=1
    for window in definition.breather_windows:
     if rt.elapsed>=window[0] and rt.elapsed<window[1]:silence=false
   if rt.time_complete and rt.all_spawns_emitted:break
  check(emitted==expected and seen_boss==1 and rt.all_spawns_emitted,"All waves finish: "+definition.id)
  check(silence,"Breather windows contain no scheduled spawns: "+definition.id)
  if definition.id=="stage_02":
   check(definition.waves[0].count==2 and definition.waves[8].count==6,"Stage two protected formations retained")
 print("READABILITY checks=",checks," failures=",failures)
 quit(1 if failures else 0)
