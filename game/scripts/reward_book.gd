extends RefCounted
## Dedicated reward RNG; combat never consumes this stream.
const Catalog = preload("res://scripts/combat_catalog.gd")
const CARDS = [
	{"id": "bulwark", "name": "不动壁垒", "target": 0, "max": 1, "tag": "阻挡", "desc": "磐石能同时拦住更多敌人，减轻其他通道的漏怪压力。"},
	{"id": "plating", "name": "复合装甲", "target": 0, "max": 2, "tag": "防御", "desc": "磐石防御增加 20，站住更久才能守住防线。"},
	{"id": "sweep", "name": "横扫重击", "target": 0, "max": 1, "tag": "攻击变化", "desc": "近战命中后，对目标附近 75 范围其他敌人造成 50% 物理伤害。"},
	{"id": "ember", "name": "炽热弹芯", "target": 1, "max": 3, "tag": "攻击", "desc": "灰烬攻击增加初始攻击的 20%，也提高蒸发命中的伤害。"},
	{"id": "rapid", "name": "快速装填", "target": 1, "max": 3, "tag": "攻速", "desc": "灰烬攻速增加初始攻速的 20%，攻速最多 3 次/秒。"},
	{"id": "farshot", "name": "远距瞄具", "target": 1, "max": 2, "tag": "射程", "desc": "灰烬射程增加 45，更早攻击远处敌人。"},
	{"id": "burst", "name": "爆裂弹", "target": 1, "max": 1, "tag": "攻击变化", "desc": "火弹命中后，对周围 65 范围其他敌人造成 50% 物理溅射，不额外挂火。"},
	{"id": "water_power", "name": "激流", "target": 2, "max": 3, "tag": "攻击", "desc": "涟漪攻击增加初始攻击的 25%，挂水也能打出伤害。"},
	{"id": "mend", "name": "丰沛泉水", "target": 2, "max": 2, "tag": "治疗", "desc": "涟漪每次自动治疗增加 10 点，优先照顾范围内血量比例最低的队友。"},
	{"id": "prayer", "name": "回春节拍", "target": 2, "max": 2, "tag": "治疗", "desc": "涟漪自动治疗间隔缩短 0.5 秒。"},
	{"id": "chill", "name": "迟滞水流", "target": 2, "max": 1, "tag": "控制", "desc": "水弹直接命中使目标减速 30%，持续 2 秒，重复命中刷新时间。"},
	{"id": "alchemy", "name": "高压蒸发", "target": -1, "max": 2, "tag": "元素", "desc": "蒸发伤害倍率提高 0.25，火水配合更加致命。"},
	{"id": "lingering", "name": "元素余韵", "target": -1, "max": 2, "tag": "元素", "desc": "元素附着时间延长 1.5 秒，为下一次交替命中留下空间。"},
	{"id": "rally", "name": "协同火力", "target": -1, "max": 3, "tag": "全队", "desc": "全队攻击各增加自身初始攻击的 10%。"},
	{"id": "march", "name": "迅捷部署", "target": -1, "max": 2, "tag": "移动", "desc": "全队移动速度增加 30，重新布防时更快回到射击状态。"},
	{"id": "vitality", "name": "坚韧意志", "target": -1, "max": 2, "tag": "生命", "desc": "全队生命上限增加初始生命的 20%，同时回复等量生命。"},
	{"id": "repair", "name": "紧急修复", "target": -1, "max": 99, "tag": "基地", "desc": "基地立即回复 30 点生命，最多恢复到 100。"},
	{"id": "recovery", "name": "战地整备", "target": -1, "max": 2, "tag": "恢复", "desc": "以后每个非终局节点结束，存活队员额外回复 15% 生命上限。"}
]
const FALLBACKS = [
	{"id": "reserve_attack", "name": "备用弹药", "target": -1, "max": 0, "tag": "补给", "desc": "全队攻击增加 3，可重复获得。"},
	{"id": "reserve_health", "name": "应急护具", "target": -1, "max": 0, "tag": "补给", "desc": "全队生命上限与当前生命增加 15，可重复获得。"},
	{"id": "reserve_armor", "name": "加固衬板", "target": -1, "max": 0, "tag": "补给", "desc": "全队防御增加 5，可重复获得。"}
]
var rng := RandomNumberGenerator.new()
var levels: Dictionary = {}
var offered: Array[Dictionary] = []
var history: Array[String] = []

func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value

func eligible(card: Dictionary, sim) -> bool:
	if card.max > 0 and levels.get(card.id, 0) >= card.max:
		return false
	if card.target >= 0 and card.target >= sim.heroes.size():
		return false
	if card.id == "repair" and sim.base_hp >= 100:
		return false
	if card.id == "recovery" and sim.wave >= Catalog.WAVES.size() - 1:
		return false
	if card.id in ["alchemy", "lingering"]:
		if not sim.heroes.any(func(h: Dictionary) -> bool: return h.element == "fire") or not sim.heroes.any(func(h: Dictionary) -> bool: return h.element == "water"):
			return false
	if card.target == 1 and sim.heroes[1].element != "fire":
		return false
	if card.target == 2 and sim.heroes[2].element != "water":
		return false
	return true

func draw(sim) -> void:
	offered.clear()
	var pool: Array[Dictionary] = []
	for card in CARDS:
		if eligible(card, sim):
			pool.append(card)
	for card in FALLBACKS:
		if pool.size() >= 3:
			break
		pool.append(card)
	for i in 3:
		var index: int = rng.randi_range(0, pool.size() - 1)
		offered.append(pool[index].duplicate(true))
		pool.remove_at(index)

func take(index: int, sim) -> bool:
	if index < 0 or index >= offered.size():
		return false
	var card: Dictionary = offered[index]
	if not eligible(card, sim):
		return false
	# Invalidate the offer before applying any effects or emitting events.
	offered.clear()
	levels[card.id] = int(levels.get(card.id, 0)) + 1
	history.append(card.name)
	apply(card.id, sim)
	return true

func increase_health(hero: Dictionary, amount: float) -> void:
	hero.max_hp += amount
	if hero.hp > 0:
		hero.hp = minf(hero.max_hp, hero.hp + amount)

func apply(id: String, sim) -> void:
	match id:
		"bulwark": sim.heroes[0].block += 1
		"plating": sim.heroes[0].armor += 20.0
		"sweep": sim.heroes[0].cleave = true
		"ember": sim.heroes[1].damage += sim.heroes[1].base_damage * 0.2
		"rapid": sim.heroes[1].rate = minf(3, sim.heroes[1].rate + sim.heroes[1].base_rate * 0.2)
		"farshot": sim.heroes[1].range += 45.0
		"burst": sim.heroes[1].splash = true
		"water_power": sim.heroes[2].damage += sim.heroes[2].base_damage * 0.25
		"mend": sim.heal_amount += 10.0
		"prayer": sim.heal_interval = maxf(1.0, sim.heal_interval - 0.5)
		"chill": sim.heroes[2].slow = true
		"alchemy": sim.vapor_multiplier += 0.25
		"lingering": sim.aura_duration += 1.5
		"rally":
			for h in sim.heroes: h.damage += h.base_damage * 0.1
		"march":
			for h in sim.heroes: h.speed += 30
		"vitality":
			for h in sim.heroes: increase_health(h, h.base_hp * 0.2)
		"repair": sim.base_hp = mini(100, sim.base_hp + 30)
		"recovery": sim.regroup_ratio += 0.15
		"reserve_attack":
			for h in sim.heroes: h.damage += 3
		"reserve_health":
			for h in sim.heroes: increase_health(h, 15)
		"reserve_armor":
			for h in sim.heroes: h.armor += 5

func preview(card: Dictionary, sim) -> String:
	var h: Dictionary = sim.heroes[card.target] if card.target >= 0 else {}
	match card.id:
		"bulwark": return "阻挡上限  %d → %d" % [h.block, h.block + 1]
		"plating": return "防御  %.0f → %.0f" % [h.armor, h.armor + 20]
		"sweep": return "单体近战 → 75 范围劈砍"
		"ember": return "攻击  %.1f → %.1f" % [h.damage, h.damage + h.base_damage * 0.2]
		"rapid": return "攻速  %.1f → %.1f /秒" % [h.rate, minf(3, h.rate + h.base_rate * 0.2)]
		"farshot": return "射程  %.0f → %.0f" % [h.range, h.range + 45]
		"burst": return "单体火弹 → 65 范围溅射"
		"water_power": return "攻击  %.1f → %.1f" % [h.damage, h.damage + h.base_damage * 0.25]
		"mend": return "治疗量  %.0f → %.0f" % [sim.heal_amount, sim.heal_amount + 10]
		"prayer": return "治疗间隔  %.1f → %.1f 秒" % [sim.heal_interval, maxf(1, sim.heal_interval - 0.5)]
		"chill": return "水弹附加 30% 减速 / 2 秒"
		"alchemy": return "蒸发  ×%.2f → ×%.2f" % [sim.vapor_multiplier, sim.vapor_multiplier + 0.25]
		"lingering": return "附着  %.1f → %.1f 秒" % [sim.aura_duration, sim.aura_duration + 1.5]
		"rally": return "全队各 +10% 初始攻击"
		"march": return "全队移速 +30"
		"vitality": return "全队各 +20% 初始生命"
		"repair": return "基地  %d → %d" % [sim.base_hp, mini(100, sim.base_hp + 30)]
		"recovery": return "波末回复  %.0f%% → %.0f%%" % [sim.regroup_ratio * 100, (sim.regroup_ratio + 0.15) * 100]
	return card.desc
