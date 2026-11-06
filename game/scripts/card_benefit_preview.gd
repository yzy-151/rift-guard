extends RefCounted

const CardEffects = preload("res://scripts/rewards/combat_card_effects.gd")

static func hero_lines(card: Dictionary, h: Dictionary) -> String:
	if str(card.get("effect", "")) == "card_bundle":
		var result: Array[String] = []
		for component: Dictionary in card.get("components", []):
			var line := hero_lines(component, h)
			if not line.is_empty(): result.append(line)
		return " · ".join(result)
	var effect := str(card.get("effect", ""))
	var raw: Variant = card.get("value", 0)
	var value := float(raw) if raw is float or raw is int else 0.0
	var field := ""
	var label := ""
	var amount := value
	var cap := INF
	match effect:
		"attack_multiplier", "squad_attack_multiplier": field = "damage"; label = "攻击"; amount = float(h.base_damage) * value
		"health_multiplier", "squad_health_multiplier": field = "max_hp"; label = "生命上限"; amount = float(h.base_hp) * value
		"attack_rate_multiplier", "squad_rate_multiplier":
			var rate_after := minf(minf(5.0, float(h.base_rate) * 3.0), float(h.rate) + float(h.base_rate) * value)
			return "攻击间隔 %.2f → %.2f 秒" % [1.0 / maxf(.01, float(h.rate)), 1.0 / maxf(.01, rate_after)]
		"range_flat", "squad_range_flat": field = "range"; label = "射程"; cap = 600.0
		"armor_flat", "squad_armor_flat": field = "armor"; label = "防御"; cap = 240.0
		"move_speed_flat": field = "speed"; label = "移速"; cap = 260.0
		"projectile_count_add": field = "projectile_count"; label = "弹道"; cap = 5.0
		"pierce_add": field = "pierce"; label = "贯穿"; cap = 3.0
		"chain_add", "squad_chain": field = "chain_count"; label = "连锁"; cap = 3.0
		"blast_add": field = "blast_radius"; label = "爆炸半径"; cap = 140.0
		"echo_add": return "追击 %.1f%% → %.1f%%" % [float(h.get("echo_ratio", 0)) * 100.0, minf(.45, float(h.get("echo_ratio", 0)) + value) * 100.0]
		"crit_flat", "squad_crit_flat": return "暴击 %.1f%% → %.1f%%" % [minf(.85, float(h.get("crit_chance", 0))) * 100.0, minf(.85, float(h.get("crit_chance", 0)) + value) * 100.0]
		"lethal_tempo", "conqueror", "heartsteel", "warmogs_armor":
			var old := CardEffects.level(h, effect)
			var next := mini(int(CardEffects.LEVEL_LIMITS[effect]), old + 1)
			var immortal_before:=bool(h.get("card_synergies",{}).get("immortal_heart",false))
			var immortal_after:=immortal_before or (effect=="heartsteel" and CardEffects.level(h,"warmogs_armor")>0) or (effect=="warmogs_armor" and CardEffects.level(h,"heartsteel")>0)
			if effect == "heartsteel": return "首击生命成长 %d → %d；累计上限 %d" % [old*(6.0 if immortal_before else CardEffects.HEARTSTEEL_GAIN),next*(6.0 if immortal_after else CardEffects.HEARTSTEEL_GAIN),900 if immortal_after else 600]
			if effect == "warmogs_armor":
				var pulse := CardEffects.WARMOG_FLAT+float(h.max_hp)*CardEffects.WARMOG_PERCENT
				return "每 5 秒回复 %.0f → %.0f" % [old*pulse*(1.35 if immortal_before else 1.0),next*pulse*(1.35 if immortal_after else 1.0)]
			if effect == "conqueror": return "连续 6 击后伤害 +%d%% → +%d%%" % [old * CardEffects.CONQUEROR_DAMAGE*100, next * CardEffects.CONQUEROR_DAMAGE*100]
			return "叠满攻速 +%d%% → +%d%%" % [old * CardEffects.TEMPO_MAXIMUM*100, next * CardEffects.TEMPO_MAXIMUM*100]
		"opening_strike", "third_strike", "counter_ready", "distant_strike", "desperate_guard", "attack_mend":
			var old := CardEffects.level(h, effect)
			var next := minf(float(CardEffects.LEVEL_LIMITS[effect]), float(old) + value)
			var coefficient := float(CardEffects.PASSIVE_COEFFICIENTS[effect]) * (1.0 if effect=="attack_mend" else 100.0)
			var title := str({"opening_strike":"开场伤害", "third_strike":"第三击伤害", "counter_ready":"反击伤害", "distant_strike":"远距伤害", "desperate_guard":"残血减伤", "attack_mend":"每击治疗"}[effect])
			return "%s %.0f → %.0f%s" % [title, old * coefficient, next * coefficient, "" if effect == "attack_mend" else "%"]
	if field.is_empty(): return ""
	var before := float(h.get(field, 0))
	return "%s %.1f → %.1f" % [label, before, minf(cap, before + amount)]

static func team_lines(card: Dictionary, sim) -> String:
	var lines: Array[String] = []
	for h: Dictionary in sim.heroes:
		var change := hero_lines(card, h)
		if not change.is_empty(): lines.append("%s：%s" % [h.name, change])
	return "\n".join(lines)
