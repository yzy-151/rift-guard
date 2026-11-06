extends RefCounted
## Recipes are checked only after acquiring a card, never in the frame loop.
const RECIPES := [
 {"id":"immortal_heart","name":"不灭之心","scope":"hero","cards":["heartsteel","warmogs_armor"],"names":["心之钢","狂徒铠甲"],"description":"同一角色：心之钢成长 4→6／级，上限 600→900；狂徒治疗 ×1.35。"},
 {"id":"battle_fervor","name":"战斗狂热","scope":"hero","cards":["lethal_tempo","conqueror"],"names":["致命节奏","征服者"],"description":"同一角色：征服者 4 次攻击启动，每击每级回复 5 生命。"},
 {"id":"cross_barrage","name":"火力交织","scope":"team","cards":["support_red_moon","support_crossfire"],"names":["赤月炮击","交叉火力"],"description":"赤月炮击与交叉火力伤害 ×1.45；后续强化仍享受加成。"},
 {"id":"healing_tide","name":"生命潮汐","scope":"team","cards":["support_tidal_aid","warmogs_armor"],"names":["潮汐急救","狂徒铠甲"],"description":"潮汐急救的角色治疗与水晶修复 ×1.35。"},
 {"id":"twin_orbits","name":"双轨共振","scope":"team","cards":["orbit_arcane_blades","orbit_spell_rings"],"names":["星轨剑阵","术式环流"],"description":"飞剑、法术环及剑阵风暴伤害 ×1.4。"},
 {"id":"skyfire","name":"天火坠落","scope":"team","cards":["evolve_fireball","mechanic_blast_core"],"names":["天动万象","爆裂核心"],"description":"天动万象伤害 ×1.45、落点半径 ×1.25，画面与判定同步。"},
 {"id":"spell_overclock","name":"术式超频","scope":"team","cards":["v75_skill_overload","v75_time_compression"],"names":["技能超载","时间压缩"],"description":"额外提高全队技能伤害 30%，每局只激活一次。"},
 {"id":"giant_execution","name":"巨兽终结","scope":"team","cards":["mechanic_execution","mechanic_giant_slayer"],"names":["收集者","巨人杀手"],"description":"额外提高精英与首领伤害 25%，每局只激活一次。"}
]

static func hero_has(hero: Dictionary, card_id: String) -> bool:
 return int(hero.get("card_levels", {}).get(card_id, 0)) > 0

static func ready(recipe: Dictionary, sim, hero: Dictionary = {}) -> bool:
 for id: String in recipe.cards:
  if recipe.scope == "hero":
   if not hero_has(hero, id): return false
  elif int(sim.run_state.buff_levels.get(id, 0)) <= 0:
   return false
 return true

static func refresh(sim) -> void:
 var team_changed := false
 for recipe: Dictionary in RECIPES:
  if recipe.scope == "hero":
   for hero: Dictionary in sim.heroes:
    var activated: Dictionary = hero.get("card_synergies", {})
    if activated.has(recipe.id) or not ready(recipe, sim, hero): continue
    activated[recipe.id] = true
    hero.card_synergies = activated
    _announce(sim, recipe, hero.pos, str(hero.name))
  elif not sim.run_state.card_synergies.has(recipe.id) and ready(recipe, sim):
   team_changed = true
   sim.run_state.card_synergies[recipe.id] = true
   match str(recipe.id):
    "spell_overclock": sim.skill_power_bonus += 0.30
    "giant_execution": sim.elite_damage_bonus += 0.25
   _announce(sim, recipe, sim.heroes[0].pos if not sim.heroes.is_empty() else Vector2.ZERO, "全队")
 if team_changed: sim._clamp_combat_card_stats()

static func _announce(sim, recipe: Dictionary, point: Vector2, owner: String) -> void:
 sim.events.append({"kind":"tag_synergy","pos":point,"value":str(recipe.name)+" · "+owner,"level":1})

static func team_multiplier(sim, id: String, amount: float) -> float:
 if not sim.run_state.card_synergies.has(id): return 1.0
 if id == "skyfire": return 1.25 if amount <= 1.15 else 1.45
 return float({"cross_barrage":1.45,"healing_tide":1.35,"twin_orbits":1.40}.get(id,amount))

static func hero_active(hero: Dictionary, id: String) -> bool:
 return bool(hero.get("card_synergies", {}).get(id, false))

static func status(recipe: Dictionary, sim) -> String:
 if recipe.scope == "hero":
  var owners: Array[String] = []
  for hero: Dictionary in sim.heroes:
   if hero_active(hero, recipe.id): owners.append(str(hero.name))
  if not owners.is_empty(): return "已激活 · " + " / ".join(owners)
  var best := 0
  for hero: Dictionary in sim.heroes:
   var count := 0
   for id: String in recipe.cards:
    if hero_has(hero,id): count += 1
   best = maxi(best,count)
  return "同一角色 %d/2" % best
 if sim.run_state.card_synergies.has(recipe.id): return "已激活 · 全队"
 var count := 0
 for id: String in recipe.cards:
  if int(sim.run_state.buff_levels.get(id,0)) > 0: count += 1
 return "全队持有 %d/2" % count

static func preview(card: Dictionary, sim, hero_id: int = -1) -> String:
 var result: Array[String] = []
 for recipe: Dictionary in RECIPES:
  var index: int = recipe.cards.find(str(card.get("id","")))
  if index < 0: continue
  var partner_id: String = recipe.cards[1-index]
  var hint := "搭配「%s」" % str(recipe.names[1-index])
  if recipe.scope == "hero":
   var partners: Array[String] = []
   var active: Array[String] = []
   for hero: Dictionary in sim.heroes:
    if hero_id >= 0 and int(hero.id) != hero_id: continue
    if hero_active(hero, recipe.id): active.append(str(hero.name))
    elif hero_has(hero, partner_id): partners.append(str(hero.name))
   if not active.is_empty(): hint = "已激活：" + " / ".join(active)
   elif not partners.is_empty(): hint = "给 " + " / ".join(partners) + " 可激活"
   else: hint += "，需同一角色"
  elif sim.run_state.card_synergies.has(recipe.id):
   hint = "已激活"
  elif int(sim.run_state.buff_levels.get(partner_id,0)) > 0:
   hint = "选择即可激活"
  result.append(str(recipe.name) + "：" + hint)
 return "联动  " + "；".join(result) if not result.is_empty() else "联动图鉴可查看全部组合；同一组合只激活一次。"
