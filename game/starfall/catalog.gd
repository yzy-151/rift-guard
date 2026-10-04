class_name StarfallCatalog
extends RefCounted

const WORLD: Rect2 = Rect2(140, 160, 1640, 960)
const CORE: Vector2 = Vector2(960, 600)
const HERO_SPEED: float = 235.0
const HERO_HP: float = 160.0
const HERO_DAMAGE: float = 24.0
const HERO_ATTACK_INTERVAL: float = 0.82
const HERO_PROJECTILE_SPEED: float = 660.0
const CORE_HP: float = 800.0
const DASH_SPEED: float = 900.0
const DASH_DURATION: float = 0.20
const DASH_COOLDOWN: float = 2.6
const MAX_ENEMIES: int = 80
const MAX_PROJECTILES: int = 160
const MAX_PICKUPS: int = 120
const MAX_HAZARDS: int = 80
const MAX_EVENTS: int = 300

static func heroes() -> Array[Dictionary]:
	return [
		_h("traveler", "旅行者", "逐星之剑", "gold", Color("f5d482"), "星芒穿透敌阵，适合精准突围。", "星轨横扫", "向前斩出三道星芒，贯穿敌人。", "天星裁决", "星芒环状爆发，贯穿周围敌人。", 7.0, "needle", "star_blades"),
		_h("hero_01", "哥伦比亚", "绯月咏叹", "fire", Color("ef8898"), "以延迟绽放的月焰封锁战场。", "绯月绽放", "目标区域连续绽放月焰。", "终夜咏叹", "围绕自身引爆六朵绯月。", 9.0, "orb", "moon_bloom"),
		_h("hero_02", "希露菲", "翠风旅伴", "wind", Color("98e8bb"), "清风推开敌群，为队伍恢复生命。", "翠风涟漪", "击退周围敌人，并治疗队友。", "风之庇护", "大型旋风守护全队，大幅恢复生命。", 10.0, "leaf", "wind_heal"),
		_h("hero_03", "芙宁娜", "潮汐舞台", "water", Color("7ecbfa"), "水环持续护卫，潮汐滋养队伍。", "水色圆舞", "水环打击周围敌人，并治疗队友。", "万众欢宴", "潮汐横扫周围，治愈所有伙伴。", 10.0, "bubble", "water_ring"),
		_h("hero_04", "洛琪希", "深蓝魔导师", "water", Color("a2b7ff"), "远距离水弹与定点暴雨控制阵线。", "暴雨术", "在目标位置落下三轮暴雨。", "苍蓝洪流", "大范围洪流冲击并减速敌群。", 8.0, "orb", "rain"),
		_h("hero_06", "阿米娅", "余烬之誓", "fire", Color("ffbd89"), "烈焰沿前方爆发，擅长清理密集敌人。", "余烬连爆", "沿瞄准方向触发三段爆破。", "赤霄燎原", "前方大范围连续爆破。", 8.0, "ember", "fire_line"),
		_h("hero_07", "丰川祥子", "雷鸣乐章", "lightning", Color("cab0ff"), "连锁电弧在敌群之间跳跃。", "雷鸣和弦", "电弧连锁打击最多六名敌人。", "命运终章", "双重雷暴连锁贯穿战场。", 8.5, "spark", "chain"),
		_h("hero_08", "艾米莉亚", "霜花守护", "frost", Color("b8efff"), "冻结推进路线，为队伍创造空间。", "霜花领域", "目标区域持续降下冰霜并冻结敌人。", "永冻花园", "大范围冰霜爆发，长时间冻结敌群。", 9.0, "shard", "frost_zone"),
		_h("hero_10", "风堇", "天穹信使", "wind", Color("aedee5"), "移动的龙卷风卷走沿途敌群。", "流风之径", "释放向前移动的龙卷风。", "天穹回响", "释放三道强力龙卷风。", 7.5, "leaf", "tornado"),
		_h("hero_13", "格温", "金线织梦", "gold", Color("e8c4f9"), "扇形金针近距离爆发，剪断包围。", "星线剪裁", "扇形放出七枚穿透金针。", "千针织梦", "环形放出大量穿透金针。", 7.0, "needle", "needles")
	]

static func _h(id: String, name: String, title: String, element: String, color: Color, description: String, q_name: String, q_desc: String, e_name: String, e_desc: String, cooldown: float, style: String, skill: String) -> Dictionary:
	return {"id": id, "name": name, "title": title, "element": element, "color": color, "description": description, "q_name": q_name, "q_desc": q_desc, "e_name": e_name, "e_desc": e_desc, "q_cooldown": cooldown, "attack_style": style, "skill": skill, "assets": "res://assets/characters/sequences/" + id + "/", "hp": HERO_HP, "damage": HERO_DAMAGE, "speed": HERO_SPEED, "attack_interval": HERO_ATTACK_INTERVAL}

static func hero(id: String) -> Dictionary:
	for entry in heroes():
		if entry.id == id:
			return entry
	return heroes()[0]

static func enemy(kind: String) -> Dictionary:
	var entries: Dictionary = {
		"grunt": {"name": "丘丘人", "hp": 90.0, "speed": 82.0, "damage": 13.0, "radius": 20.0, "xp": 7.0, "color": Color("c59c74"), "interval": 1.9},
		"runner": {"name": "疾行哥布林", "hp": 67.0, "speed": 116.0, "damage": 15.0, "radius": 17.0, "xp": 9.0, "color": Color("c6df91"), "interval": 3.2},
		"ranged": {"name": "丘丘弓手", "hp": 72.0, "speed": 67.0, "damage": 11.0, "radius": 20.0, "xp": 11.0, "color": Color("ebbb90"), "interval": 3.1},
		"buffer": {"name": "丘丘萨满", "hp": 88.0, "speed": 50.0, "damage": 7.0, "radius": 21.0, "xp": 14.0, "color": Color("b9e3bc"), "interval": 4.0},
		"armored": {"name": "铁甲守卫", "hp": 235.0, "speed": 43.0, "damage": 23.0, "radius": 28.0, "xp": 19.0, "color": Color("b8bcc9"), "interval": 3.8},
		"splitter": {"name": "哥布林茅房", "hp": 165.0, "speed": 24.0, "damage": 10.0, "radius": 28.0, "xp": 22.0, "color": Color("d6b182"), "interval": 5.8},
		"boss_01": {"name": "裂隙统领", "hp": 2600.0, "speed": 34.0, "damage": 25.0, "radius": 49.0, "xp": 160.0, "color": Color("f799a9"), "interval": 3.4}
	}
	var result: Dictionary = entries.get(kind, entries.grunt).duplicate(true)
	result["kind"] = kind if entries.has(kind) else "grunt"
	return result

static func upgrades() -> Array[Dictionary]:
	return [
		_u("power", "星辉磨刃", "全队伤害 +18%", "common", "blade", 8, Color("f4d58d")),
		_u("haste", "轻盈节拍", "全队普通攻击速度 +14%", "common", "speed", 6, Color("a6ddbe")),
		_u("multishot", "双星同行", "普通攻击额外发射 1 枚弹体", "epic", "stars", 3, Color("c9b8f3")),
		_u("vitality", "生生不息", "全队最大生命 +30，并恢复 30 生命", "common", "heart", 6, Color("efb0b4")),
		_u("lifesteal", "饮露之刃", "命中敌人恢复造成伤害的 2% 生命", "rare", "drop", 4, Color("e7a1af")),
		_u("magnet", "星尘引力", "拾取范围 +65，经验值获取 +10%", "common", "orbit", 5, Color("94d7eb")),
		_u("cooldown", "时光轻语", "主动技能冷却缩短 9%", "rare", "clock", 5, Color("b7c7fa")),
		_u("regen", "归林气息", "全队每秒恢复 0.7 生命", "rare", "leaf", 5, Color("a8dab0")),
		_u("core_repair", "月井重生", "月井恢复 150 耐久，最大耐久 +60", "common", "well", 8, Color("a9e7e2")),
		_u("crit", "会心星芒", "全队暴击率 +8%，暴击造成双倍伤害", "rare", "spark", 6, Color("f7d19c")),
		_u("pierce", "破阵之矢", "普通弹体额外穿透 1 名敌人", "rare", "arrow", 3, Color("cad9f3")),
		_u("stride", "巡风足音", "移动速度 +9%，冲刺冷却缩短 7%", "common", "wing", 4, Color("b5e4c2")),
		_u("energy", "满盈之月", "能量获取 +25%，立即获得 20 能量", "rare", "moon", 4, Color("e8ddb0")),
		_u("water_bond", "潮汐共鸣", "水系伤害 +30%，水系治疗 +25%", "rare", "water", 4, Color("88cffa")),
		_u("frost_bond", "霜花共鸣", "冰系伤害 +30%，冰霜减速更持久", "rare", "frost", 4, Color("b8efff")),
		_u("fire_bond", "绯焰共鸣", "火系伤害 +30%，技能爆破范围 +12%", "rare", "fire", 4, Color("f5b097")),
		_u("wind_bond", "流风共鸣", "风系伤害 +30%，击退距离 +25%", "rare", "wind", 4, Color("abe3c2")),
		_u("lightning_bond", "雷鸣共鸣", "雷系伤害 +30%，连锁额外命中 1 名敌人", "rare", "bolt", 4, Color("d2b8fa")),
		_u("gold_bond", "星芒共鸣", "金系伤害 +30%，星针额外穿透 1 名敌人", "rare", "star", 4, Color("f7d78e")),
		_u("respite", "旅途补给", "全队恢复 40 生命，月井恢复 60 耐久", "common", "potion", 999999, Color("cce5bc")),
		_u("stardust", "珍藏星砂", "获得 30 星砂，全队获得 12 能量", "common", "coin", 999999, Color("f4d99a")),
		_u("training", "远行见闻", "全队伤害 +3%，可重复选择", "common", "star", 999999, Color("dfd2a8")),
		_u("resolve", "坚守之心", "全队受到伤害降低 6%（最多 36%）", "rare", "shield", 6, Color("bfcddd"))
	]

static func _u(id: String, name: String, description: String, rarity: String, icon: String, cap: int, color: Color) -> Dictionary:
	return {"id": id, "name": name, "description": description, "rarity": rarity, "icon": icon, "max_stacks": cap, "color": color}


