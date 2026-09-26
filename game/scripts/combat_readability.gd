extends RefCounted
const DANGER = Color("#ff405c")
const HEAL = Color("#67efac")
const BUFF = Color("#71caff")
const Catalog = preload("res://scripts/combat_catalog.gd")
static func source(enemy: Dictionary, skill: String = "") -> Dictionary:
 var kind = str(enemy.get("kind", ""))
 return {"source_name":str(Catalog.ENEMIES.get(kind,{}).get("name",kind)), "source_skill":skill if not skill.is_empty() else str(enemy.get("special_move_name","普通攻击"))}
static func report(sim) -> String:
 var head = "基地被突破" if sim.base_hp<=0 else "全队倒地"
 var lines: Array[String]=[head+" · 本局漏怪 %d 次，基地实际损失 %d 点" % [sim.leak_count,sim.leak_damage]]
 var hit: Dictionary=sim.last_leak if sim.base_hp<=0 else sim.last_incoming_hit
 if not hit.is_empty():
  lines.append("%s · %s · %s受到 %.0f 点伤害" % [hit.get("source_name","未知来源"),hit.get("source_skill","攻击"),hit.get("victim","基地"),hit.get("damage",0)])
 for id in sim.hero_down_causes:
  var row: Dictionary=sim.hero_down_causes[id]
  lines.append("%s倒地：%s · %s（%.0f）" % [row.victim,row.source_name,row.source_skill,row.damage])
 return "\n".join(lines.slice(0,5))
static func statuses(sim,h: Dictionary) -> Array:
 var rows: Array=[]
 if h.hp<=0:
  var rescue: Dictionary=sim.supports.get("support_heal",{})
  rows.append(["急救 %.1fs"%maxf(0,float(rescue.timer)) if not rescue.is_empty() else "倒地 · 可治疗",HEAL,1.0])
  return rows
 var inv=float(h.get("invulnerable_timer",0))
 if inv>0:rows.append(["无敌 %.1fs"%inv,BUFF,minf(1.0,inv/0.25)])
 if sim.crystal_shield>0:rows.append(["共享盾 %.0f"%sim.crystal_shield,BUFF,1.0])
 var slow=float(h.get("slime_slow_timer",0))
 if slow>0:rows.append(["减速 %.1fs"%slow,Color("#baa6fa"),minf(1.0,slow/0.25)])
 var buff=0.0
 for effect in sim.skill_effects:
  if effect.kind=="columbia_attack_blessing" and int(h.id) in effect.get("ally_ids",[]):buff=maxf(buff,float(effect.life))
 if buff>0:rows.append(["攻击增益 %.1fs"%buff,BUFF,minf(1.0,buff/0.25)])
 return rows
