extends RefCounted
static func hero_lines(card: Dictionary,h: Dictionary) -> String:
 if str(card.get("effect",""))=="card_bundle":return str(card.get("summary",""))
 var effect=str(card.get("effect",""))
 var value=float(card.get("value",0)) if card.get("value",0) is float or card.get("value",0) is int else 0.0
 var field="";var label="";var amount=value
 match effect:
  "attack_multiplier","squad_attack_multiplier":field="damage";label="攻击";amount=float(h.base_damage)*value
  "health_multiplier","squad_health_multiplier":field="max_hp";label="生命上限";amount=float(h.base_hp)*value
  "attack_rate_multiplier","squad_rate_multiplier":
   return "攻击间隔 %.2f → %.2f 秒" % [1.0/maxf(0.01,h.rate),1.0/maxf(0.01,h.rate+h.base_rate*value)]
  "range_flat","squad_range_flat":field="range";label="射程"
  "armor_flat","squad_armor_flat":field="armor";label="防御"
  "move_speed_flat":field="speed";label="移速"
  "projectile_count_add":field="projectile_count";label="弹道数"
  "pierce_add":field="pierce";label="贯穿"
  "chain_add","squad_chain":field="chain_count";label="连锁"
  "blast_add":field="blast_radius";label="爆炸半径"
  "echo_add":return "追击 %.0f%% → %.0f%%" % [float(h.get("echo_ratio",0))*100,(float(h.get("echo_ratio",0))+value)*100]
  "crit_flat","squad_crit_flat":return "暴击 %.0f%% → %.0f%%" % [minf(0.85,h.get("crit_chance",0))*100,minf(0.85,float(h.get("crit_chance",0))+value)*100]
  "lethal_tempo","conqueror","heartsteel","warmogs_armor":
   var old=int(h.get("card_levels",{}).get(effect,0))
   if effect=="heartsteel":return "首次命中增生命 %d → %d" % [old*10,(old+1)*10]
   if effect=="warmogs_armor":return "每5秒回复 %d → %d" % [old*100,(old+1)*100]
   if effect=="conqueror":return "6次攻击后伤害 ×%d → ×%d" % [int(pow(2,old)),int(pow(2,old+1))]
   return "叠满攻速加成 %d%% → %d%%" % [old*120,(old+1)*120]
  "mythic_projectile_storm":return "弹道 %d → %d · 贯穿 %d → %d" % [h.projectile_count,h.projectile_count+1,h.pierce,h.pierce+1]
  "mythic_world_breaker":return "攻击 %.0f → %.0f" % [h.damage,h.damage+h.base_damage*1.5]
 if field.is_empty():return ""
 var before=float(h.get(field,0))
 return "%s %.0f → %.0f" % [label,before,before+amount]
static func team_lines(card: Dictionary,sim) -> String:
 var lines: Array[String]=[]
 for h in sim.heroes:
  var change=hero_lines(card,h)
  if not change.is_empty():lines.append("%s：%s"%[h.name,change])
 return "\n".join(lines)
