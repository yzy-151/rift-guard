extends RefCounted

const Synergies = preload("res://scripts/rewards/card_synergies.gd")
const CardEffects = preload("res://scripts/rewards/combat_card_effects.gd")
const MAX_REROLLS := 2
const DISCRETE_EFFECTS := ["projectile_count_add","pierce_add","chain_add","squad_chain","opening_strike","third_strike","counter_ready","distant_strike","desperate_guard","attack_mend","orbit_add","orbit_spell_add","evolving_fireball","lethal_tempo","conqueror","heartsteel","warmogs_armor","solo_leveling","last_stand"]

const ELEMENTS := ["anemo", "electro", "pyro", "hydro", "geo", "cryo"]

var cards: Array[Dictionary] = []
var offered: Array[Dictionary] = []
var history: Array[String] = []
var levels: Dictionary = {}
var rerolls_left := 0
var offer_revision := 0
var seen_this_offer: Array[String] = []
var rng := RandomNumberGenerator.new()
var combat_heroes: Array[Dictionary] = []
var combat_limits: Dictionary = {}

func _init(source_cards: Array[Dictionary], seed_value: int = -1) -> void:
	cards.assign(source_cards)
	reseed(seed_value)

func reseed(seed_value: int) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()

func eligible(card: Dictionary, run) -> bool:
	var card_level := int(run.buff_levels.get(str(card.get("id", "")), 0))
	if card_level >= maxi(1, int(card.get("max_stacks", 1))):
		return false
	if not combat_limits.is_empty() and not _has_runtime_gain(card):
		return false
	if run.crystal_level < int(card.get("min_crystal_level", 1)):
		return false
	if str(card.get("family", "")) == "device":
		if run.mode_id != "rift_watch" or not run.device_cards_enabled:
			return false
		if int(run.buff_levels.get(str(card.id), 0)) >= int(card.get("max_stacks", 1)):
			return false
	if run.mode_id == "endless_survival" and str(card.get("effect", "")) in ["crystal_health_flat", "crystal_heal"]:
		return false
	if card.get("target", "global") == "character":
		var character_id := str(card.get("character_id", ""))
		if run.squad.is_empty() or (not character_id.is_empty() and not _character_is_present(character_id, run)):
			return false
	if card.get("effect", "") == "assign_traveler_element":
		if run.traveler_element != "none" or "traveler" not in run.squad: return false
	if card.get("effect", "") == "dual_element_mythic":
		if run.traveler_element == "none" or run.traveler_secondary_element != "none": return false
	if card.get("effect", "") == "deploy_reinforcement":
		if run.squad.size() + run.temporary_assists.size() + _reinforcement_count(run) >= run.MAX_SQUAD_SIZE or int(run.buff_levels.get(card.id, 0)) > 0:
			return false
		if _character_is_present(str(card.get("value", "")), run): return false
	if card.get("effect", "") == "grant_relic":
		if run.equipped_relics.has(str(card.get("value", ""))): return false
	var required_element: String = str(card.get("requires_element", ""))
	if not required_element.is_empty() and required_element != run.traveler_element:
		return false
	for required_id: String in card.get("requires", []):
		if int(run.buff_levels.get(required_id, 0)) <= 0:
			return false
	for excluded_id: String in card.get("excludes", []):
		if int(run.buff_levels.get(excluded_id, 0)) > 0:
			return false
	var requires_any: Array = card.get("requires_any", [])
	if not requires_any.is_empty() and not requires_any.any(func(id: String) -> bool: return int(run.buff_levels.get(id, 0)) > 0):
		return false
	if str(card.get("effect", "")) == "crystal_heal" and int(run.buff_levels.get("crystal_repair_1", 0)) >= int(card.get("max_stacks", 1)):
		return false
	return true

func _has_runtime_gain(card: Dictionary) -> bool:
	var effect := str(card.get("effect", ""))
	if effect == "card_bundle":
		for part: Dictionary in card.get("components", []):
			var component := part.duplicate()
			component.target=card.get("target","global")
			component.character_id=card.get("character_id","")
			if _has_runtime_gain(component):return true
		return false
	var scalar_caps := {"skill_cooldown_add":["skill_cooldown_reduction",.40],"skill_area_add":["skill_area_bonus",.65],"skill_duration_add":["skill_duration_bonus",.80],"energy_gain_add":["energy_gain_bonus",.40],"reaction_damage_add":["reaction_damage_bonus",1.0],"reaction_radius_add":["reaction_radius_bonus",100.0],"execute_threshold_add":["execute_threshold",.18],"death_burst_add":["death_burst_ratio",.12],"elite_damage_add":["elite_damage_bonus",.75],"kill_frenzy_add":["kill_frenzy_step",.03],"luck_add":["luck",1.5]}
	if scalar_caps.has(effect):
		var rule:Array=scalar_caps[effect]
		return float(combat_limits.get(rule[0],0))<float(rule[1])-.0001
	if effect=="crystal_heal":return float(combat_limits.get("base_hp",0))<float(combat_limits.get("base_max_hp",12))
	var hero_caps := {"range_flat":["range",600],"squad_range_flat":["range",600],"armor_flat":["armor",240],"squad_armor_flat":["armor",240],"move_speed_flat":["speed",260],"projectile_count_add":["projectile_count",5],"pierce_add":["pierce",3],"chain_add":["chain_count",3],"squad_chain":["chain_count",3],"blast_add":["blast_radius",140],"echo_add":["echo_ratio",.45],"crit_flat":["crit_chance",.85],"squad_crit_flat":["crit_chance",.85]}
	if not hero_caps.has(effect) and not CardEffects.LEVEL_LIMITS.has(effect) and effect not in ["attack_rate_multiplier","squad_rate_multiplier"]:return true
	for hero:Dictionary in combat_heroes:
		if str(card.get("character_id",""))!="" and str(hero.character_id)!=str(card.character_id):continue
		if effect in ["attack_rate_multiplier","squad_rate_multiplier"]:
			# Temporary tempo will expire, so it must not hide a permanent rate upgrade.
			var permanent_rate:=float(hero.rate)-float(hero.base_rate)*float(hero.get("tempo_bonus",0))
			if permanent_rate<minf(5.0,float(hero.base_rate)*3.0)-.0001:return true
		elif CardEffects.LEVEL_LIMITS.has(effect):
			if effect=="lethal_tempo" and float(hero.rate)-float(hero.base_rate)*float(hero.get("tempo_bonus",0))>=minf(5.0,float(hero.base_rate)*3.0)-.0001:continue
			if CardEffects.level(hero,effect)<int(CardEffects.LEVEL_LIMITS[effect]):return true
		else:
			var rule:Array=hero_caps[effect]
			if float(hero.get(rule[0],0))<float(rule[1])-.0001:return true
	return false

func _character_is_present(character_id: String, run) -> bool:
	if character_id in run.squad or character_id in run.temporary_assists:
		return true
	for card: Dictionary in cards:
		if card.get("effect", "") == "deploy_reinforcement" and str(card.get("value", "")) == character_id and int(run.buff_levels.get(card.id, 0)) > 0:
			return true
	return false

func _reinforcement_count(run) -> int:
	var count := 0
	for card: Dictionary in cards:
		if card.get("effect", "") == "deploy_reinforcement" and int(run.buff_levels.get(card.id, 0)) > 0:
			count += 1
	return count

func draw_three(run) -> Array[Dictionary]:
	rerolls_left = MAX_REROLLS
	seen_this_offer.clear()
	_roll_three(run)
	_record_offer()
	return offered.duplicate(true)

func reroll(run) -> bool:
	if rerolls_left <= 0 or offered.is_empty():
		return false
	var previous := offered.duplicate(true)
	var previous_rng := rng.state
	_roll_three(run, seen_this_offer)
	if offered.size() != previous.size():
		offered.assign(previous)
		rng.state = previous_rng
		return false
	rerolls_left -= 1
	_record_offer()
	return true

func _record_offer() -> void:
	offer_revision += 1
	for card: Dictionary in offered:
		if str(card.id) not in seen_this_offer:
			seen_this_offer.append(str(card.id))

func _roll_three(run, avoid: Array[String] = []) -> void:
	var candidates: Array[Dictionary] = []
	for card: Dictionary in cards:
		if eligible(card, run):
			candidates.append(card)
	offered.clear()
	if run.crystal_level == 2 and run.traveler_element == "none":
		var element_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if card.get("effect", "") == "assign_traveler_element":
				element_cards.append(card)
		if not element_cards.is_empty():
			var guaranteed: Dictionary = _take_weighted_preferred(element_cards, run, avoid)
			offered.append(card_for_level(guaranteed, int(run.buff_levels.get(guaranteed.id, 0)) + 1))
			candidates.erase(guaranteed)
	if run.crystal_level % 10 == 0:
		var mythic_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if card.get("rarity", "common") == "mythic":
				mythic_cards.append(card)
		if not mythic_cards.is_empty():
			var guaranteed_mythic: Dictionary = _take_weighted_preferred(mythic_cards, run, avoid)
			offered.append(card_for_level(guaranteed_mythic, int(run.buff_levels.get(guaranteed_mythic.id, 0)) + 1))
			candidates.erase(guaranteed_mythic)
	if run.crystal_level % 3 == 0:
		var mechanic_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if bool(card.get("mechanic", false)):
				mechanic_cards.append(card)
		if not mechanic_cards.is_empty():
			var guaranteed_mechanic: Dictionary = _take_weighted_preferred(mechanic_cards, run, avoid)
			offered.append(card_for_level(guaranteed_mechanic, int(run.buff_levels.get(guaranteed_mechanic.id, 0)) + 1))
			candidates.erase(guaranteed_mechanic)
	# Regular device offers let a plant build develop without changing the existing card template.
	if run.device_cards_enabled and run.crystal_level % 4 == 0 and offered.size() < 3:
		var device_cards: Array[Dictionary] = []
		for card: Dictionary in candidates:
			if str(card.get("family", "")) == "device":
				device_cards.append(card)
		if not device_cards.is_empty():
			var guaranteed_device: Dictionary = _take_weighted_preferred(device_cards, run, avoid)
			offered.append(card_for_level(guaranteed_device, int(run.buff_levels.get(guaranteed_device.id, 0)) + 1))
			candidates.erase(guaranteed_device)
	while offered.size() < 3 and not candidates.is_empty():
		var selected: Dictionary = _take_weighted_preferred(candidates, run, avoid)
		offered.append(card_for_level(selected, int(run.buff_levels.get(selected.id, 0)) + 1))
		candidates.erase(selected)

func draw(sim) -> void:
	combat_heroes.assign(sim.heroes)
	combat_limits.clear()
	for key:String in ["skill_cooldown_reduction","skill_area_bonus","skill_duration_bonus","energy_gain_bonus","reaction_damage_bonus","reaction_radius_bonus","execute_threshold","death_burst_ratio","elite_damage_bonus","kill_frenzy_step","base_hp","base_max_hp"]:
		combat_limits[key]=sim.get(key)
	combat_limits.luck=sim.run_state.luck
	draw_three(sim.run_state)

func _take_weighted_preferred(pool: Array[Dictionary], run, avoid: Array[String]) -> Dictionary:
	var fresh: Array[Dictionary] = []
	for card: Dictionary in pool:
		if str(card.id) not in avoid:
			fresh.append(card)
	return _take_weighted(fresh if not fresh.is_empty() else pool, run)

func adjusted_weight(card: Dictionary, run) -> float:
	var base_weight := maxf(1.0, float(card.get("weight", 1)))
	# Lucky runs shift the odds visibly while every rarity retains a nonzero chance.
	var luck := minf(1.5, maxf(0.0, float(run.luck)))
	var multiplier: float = {
		"common": maxf(0.45, 1.0 - luck * 0.30),
		"rare": 1.0 + luck * 0.35,
		"epic": 1.0 + luck * 1.0,
		"legendary": 1.0 + luck * 1.80,
		"mythic": 1.0 + luck * 2.60,
	}.get(str(card.get("rarity", "common")), 1.0)
	var level := int(run.buff_levels.get(str(card.get("id", "")), 0))
	var focus := 1.45 if level > 0 else 1.0
	for recipe:Dictionary in Synergies.RECIPES:
		if str(card.id) in recipe.cards and not run.card_synergies.has(recipe.id):
			for partner:String in recipe.cards:
				if partner!=str(card.id) and int(run.buff_levels.get(partner,0))>0:focus*=1.30
	return base_weight * multiplier * focus

static func card_for_level(source: Dictionary, next_level: int) -> Dictionary:
	# Start from canonical values, including when handed a previously scaled offer.
	var card := source.duplicate(true)
	var scales: Array = card.get("upgrade_scales", [1.0])
	var scale := float(scales[clampi(next_level - 1, 0, scales.size() - 1)]) if not scales.is_empty() else 1.0
	var value: Variant = card.get("_base_value", card.get("value", 0))
	card._base_value = value
	if (value is float or value is int) and str(card.get("effect","")) not in DISCRETE_EFFECTS:
		card.value = float(value) * scale
	var components: Array = card.get("_base_components", card.get("components", []))
	if not components.is_empty():
		card._base_components = components.duplicate(true)
		card.components = components.duplicate(true)
		for component: Dictionary in card.components:
			if str(component.get("effect","")) not in DISCRETE_EFFECTS:
				component.value = float(component.get("value", 0)) * scale
	card.next_level = next_level
	card.upgrade_scale = scale
	return card

func _take_weighted(pool: Array[Dictionary], run) -> Dictionary:
	var total := 0.0
	for card: Dictionary in pool:
		total += adjusted_weight(card, run)
	var roll := rng.randf_range(0.0, total)
	for card: Dictionary in pool:
		roll -= adjusted_weight(card, run)
		if roll <= 0:
			return card
	return pool.back()

func apply_element(run, element: String) -> bool:
	if element not in ELEMENTS:
		return false
	if run.traveler_element != "none" and run.traveler_element != element:
		return false
	run.traveler_element = element
	return true

func apply_card(card: Dictionary, run, target_hero_id: int = -1) -> bool:
	if not eligible(card, run):
		return false
	if card.get("target", "global") == "character" and str(card.get("character_id", "")).is_empty() and target_hero_id < 0:
		return false
	if card.get("effect", "") == "assign_traveler_element" and not apply_element(run, str(card.value)):
		return false
	if card.get("effect", "") == "luck_add":
		var actual := card_for_level(card, int(run.buff_levels.get(card.id, 0)) + 1)
		run.luck = minf(1.5,run.luck + float(actual.get("value", 0.0)))
	if card.get("effect", "") == "dual_element_mythic":
		var choices: Array = ELEMENTS.filter(func(element: String) -> bool: return element != run.traveler_element)
		run.traveler_secondary_element = choices[rng.randi_range(0, choices.size() - 1)]
	if card.get("effect", "") == "grant_relic":
		run.grant_relic(str(card.get("value", "")))
	run.buff_levels[card.id] = int(run.buff_levels.get(card.id, 0)) + 1
	run.rebuild_tags(cards)
	if card.get("rarity", "common") == "legendary":
		run.legendary_count += 1
	if card.get("rarity", "common") == "mythic":
		run.mythic_count += 1
	offered.clear()
	return true

func take(index: int, sim, target_hero_id: int = -1) -> bool:
	if index < 0 or index >= offered.size():
		return false
	var card: Dictionary = card_for_level(offered[index], int(sim.run_state.buff_levels.get(offered[index].id, 0)) + 1)
	if card.get("target", "global") == "character" and str(card.get("character_id", "")).is_empty() and (target_hero_id < 0 or target_hero_id >= sim.heroes.size()):
		return false
	if not apply_card(card, sim.run_state, target_hero_id):
		return false
	levels = sim.run_state.buff_levels
	var picked_name := str(card.get("name", card.id))
	if target_hero_id >= 0 and card.get("target", "global") == "character":
		picked_name += " · " + str(sim.heroes[target_hero_id].get("name", "角色"))
	history.append(picked_name)
	sim.apply_v2_card_effect(card, target_hero_id)
	Synergies.refresh(sim)
	rerolls_left = 0
	return true

func preview(card: Dictionary, sim) -> String:
	if str(card.get("family", "")) == "device":
		return str(card.get("summary", card.get("description", "强化机关")))
	var actual := card_for_level(card, int(sim.run_state.buff_levels.get(str(card.get("id", "")), 0)) + 1)
	if str(actual.get("effect", "")) == "card_bundle":
		var parts: Array[String] = []
		for component: Dictionary in actual.get("components", []):
			parts.append(_effect_line(component, sim))
		return _remember_offer_text(card, ("选定角色：" if actual.get("target", "global") == "character" else "全队：") + "；".join(parts))
	return _remember_offer_text(card, _effect_line(actual, sim))

static func _remember_offer_text(card: Dictionary, text: String) -> String:
	# UI descriptions and the large summary both show this purchase's real gain.
	# Canonical database rows remain unchanged when previewed in the compendium.
	if card.has("next_level"):
		card.summary = text
		card.description = "本次升级：%s。最高 %d 级。" % [text, int(card.get("max_stacks", 1))]
		if float(card.get("upgrade_scale", 1.0)) < 1.0:
			card.description += "本级基础收益为首级的 %d%%。" % roundi(float(card.upgrade_scale) * 100.0)
		elif float(card.get("upgrade_scale",1.0))>1.0:
			card.description += "本级连续数值收益为首级的 %d%%；机制等级单独计算。" % roundi(float(card.upgrade_scale)*100.0)
	return text

static func _number(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value

static func _effect_line(card: Dictionary, sim) -> String:
	var effect := str(card.get("effect", ""))
	var raw: Variant = card.get("value", 0)
	var value := float(raw) if raw is int or raw is float else 0.0
	var scalar_caps:Dictionary={"skill_cooldown_add":["skill_cooldown_reduction",.40],"skill_area_add":["skill_area_bonus",.65],"skill_duration_add":["skill_duration_bonus",.80],"energy_gain_add":["energy_gain_bonus",.40],"reaction_damage_add":["reaction_damage_bonus",1.0],"reaction_radius_add":["reaction_radius_bonus",100.0],"execute_threshold_add":["execute_threshold",.18],"death_burst_add":["death_burst_ratio",.12],"elite_damage_add":["elite_damage_bonus",.75],"kill_frenzy_add":["kill_frenzy_step",.03]}
	if scalar_caps.has(effect):
		var rule:Array=scalar_caps[effect]
		value=minf(value,maxf(0.0,float(rule[1])-float(sim.get(rule[0]))))
	var percent := _number(value * 100.0)
	match effect:
		"assign_traveler_element": return "旅行者本关获得%s元素" % sim.element_name(str(raw))
		"attack_multiplier", "squad_attack_multiplier": return "攻击 +%s%%" % percent
		"health_multiplier", "squad_health_multiplier": return "生命上限 +%s%%，回复新增生命" % percent
		"attack_rate_multiplier", "squad_rate_multiplier": return "攻速 +%s%%" % percent
		"range_flat", "squad_range_flat": return "射程 +%s" % _number(value)
		"armor_flat", "squad_armor_flat": return "防御 +%s" % _number(value)
		"crit_flat", "squad_crit_flat": return "暴击率 +%s%%" % percent
		"move_speed_flat": return "移速 +%s" % _number(value)
		"projectile_count_add": return "弹道 +%d（每角色最高 5）" % int(value)
		"pierce_add": return "贯穿 +%d（最高 3）" % int(value)
		"chain_add", "squad_chain": return "连锁 +%d（最高 3）" % int(value)
		"blast_add": return "普攻爆炸半径 +%s" % _number(value)
		"echo_add": return "普攻追加 %s%% 追击伤害" % percent
		"skill_power_add": return "Q／E 伤害 +%s%%" % percent
		"energy_gain_add": return "战斗能量获取 +%s%%" % percent
		"skill_cooldown_add": return "技能冷却减少 %s%%（累计最高 40%%）" % percent
		"skill_area_add": return "范围技能半径 +%s%%" % percent
		"skill_duration_add": return "持续技能时间 +%s%%" % percent
		"reaction_damage_add": return "元素反应伤害 +%s%%" % percent
		"reaction_radius_add": return "元素反应半径 +%s" % _number(value)
		"opening_strike": return "停攻 3 秒后的第一击额外 +%s%% 伤害" % _number(value * CardEffects.PASSIVE_COEFFICIENTS.opening_strike*100.0)
		"third_strike": return "每第三次攻击额外 +%s%% 伤害" % _number(value * CardEffects.PASSIVE_COEFFICIENTS.third_strike*100.0)
		"counter_ready": return "受击后的下一击额外 +%s%% 伤害" % _number(value * CardEffects.PASSIVE_COEFFICIENTS.counter_ready*100.0)
		"distant_strike": return "攻击 250 距离外敌人额外 +%s%% 伤害" % _number(value * 20.0)
		"desperate_guard": return "生命低于 30%% 时额外减伤 %s%%" % _number(value * 15.0)
		"attack_mend": return "每次攻击回复 %s 生命" % _number(value*CardEffects.PASSIVE_COEFFICIENTS.attack_mend)
		"lethal_tempo": return "每击攻速 +7%／级，最高 +45%／级；停攻 3 秒重置"
		"conqueror": return "连续 6 击后伤害 +30%／级，每击回复 3／级；停攻 3 秒重置"
		"heartsteel": return "首次命中每名敌人生命上限 +4／级；累计成长最高 600"
		"warmogs_armor": return "每 5 秒回复每级 40 生命＋最大生命的 1.5%"
		"solo_leveling": return "经验 +35%／级；最高 +70%"
		"last_stand": return "生命低于 30% 时伤害 +25%／级"
		"orbit_add": return "飞剑 1／2／3 级进化 3／6／9 把；4 级解锁剑阵风暴"
		"orbit_spell_add": return "法术环 1／2／3 级进化 2／3／4 个，伤害与半径同步成长"
		"evolving_fireball": return "陨石 2／3／4 级分别解锁三落点、大范围、终极冲击"
		"grant_relic": return str(card.get("summary", "获得本局遗物规则"))
		"deploy_reinforcement": return "增加 1 名场上角色；队伍最多 3 人"
		"execute_threshold_add": return "处决线 +%s%%（最高 18%%）" % percent
		"death_burst_add": return "死亡爆破造成敌人最大生命 %s%% 伤害" % percent
		"elite_damage_add": return "精英与首领伤害 +%s%%" % percent
		"kill_frenzy_add": return "每 10 击杀攻速 +%s%%；累计最高 +30%%" % percent
		"crystal_health_flat": return "水晶生命上限与当前生命 +%s" % _number(value)
		"crystal_heal": return "水晶立即回复 %s 生命" % _number(value)
		"luck_add": return "幸运 +%.2f，%.2f → %.2f；明显提升高阶卡权重" % [minf(value,maxf(0.0,1.5-float(sim.run_state.luck))),float(sim.run_state.luck),minf(1.5,float(sim.run_state.luck)+value)]
		"support_barrage", "support_crossfire", "support_heal", "support_finale":
			var support: Dictionary = sim.supports.get(effect, {})
			var power := minf(300.0,value if support.is_empty() else float(support.power) + value * 0.65)
			var interval := float(card.get("interval", 8.0)) if support.is_empty() else maxf(2.5, float(support.interval) * 0.88)
			interval = minf(interval, float(card.get("support_interval_cap", interval)))
			var support_tags := int(sim.run_state.tag_counts.get("支援", 0))
			var next_tag_level := mini(3, (support_tags + card.get("tags", []).count("支援")) / 3)
			var tag_delta := maxi(0, next_tag_level - int(sim.tag_synergy_levels.get("支援", 0)))
			interval = maxf(2.5, interval * pow(.94, tag_delta))
			if effect == "support_heal":
				power*=_synergy_after(card,sim,"healing_tide",1.35)
				return "每 %.1f 秒全队回复 %s，水晶回复 %d" % [interval, _number(power), ceili(power * 0.35)]
			if effect == "support_finale":
				var volleys := 1 if support.is_empty() else mini(3, int(support.get("stacks", 1)) + 1)
				return "每 %.1f 秒全场 %d 轮，每轮 %s、总伤害 %s" % [interval, volleys, _number(power * sim.SUPPORT_DAMAGE_SCALE), _number(power * sim.SUPPORT_DAMAGE_SCALE * volleys)]
			power*=_synergy_after(card,sim,"cross_barrage",1.45)
			return "每 %.1f 秒%s，基础伤害 %s" % [interval, "落点炮击" if effect == "support_barrage" else ("横向扫射" if effect == "support_crossfire" else "全场支援"), _number(power * sim.SUPPORT_DAMAGE_SCALE)]
	return str(card.get("summary", card.get("description", "获得强化")))

static func _synergy_after(card:Dictionary,sim,id:String,multiplier:float)->float:
	if sim.run_state.card_synergies.has(id):return multiplier
	for recipe:Dictionary in Synergies.RECIPES:
		if str(recipe.id)!=id or str(card.get("id","")) not in recipe.cards:continue
		var ready:=true
		for partner:String in recipe.cards:
			if partner!=str(card.id) and int(sim.run_state.buff_levels.get(partner,0))<=0:ready=false
		if ready:return multiplier
	return 1.0
