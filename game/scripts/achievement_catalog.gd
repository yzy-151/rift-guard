extends RefCounted

const ICON_PLACEHOLDER := "res://assets/ui/icons/temporary/card_question.svg"
const ICON_DIR := "res://assets/ui/achievement_icons/"

const ITEMS: Array[Dictionary] = [
	{"id":"first_watch","name":"初次守望","description":"首次完成任意普通关卡。","group":"征途","tier":"bronze"},
	{"id":"damage_king","name":"伤害大王","description":"在无尽模式累计造成 9,999,999 点伤害。","group":"无尽","tier":"legendary"},
	{"id":"card_master","name":"卡牌大师","description":"发现全部不同类型的卡牌。","group":"收藏","tier":"legendary"},
	{"id":"perfect_guard","name":"完美守卫","description":"以基地 12/12 生命完成普通关卡。","group":"征途","tier":"gold"},
	{"id":"last_crystal","name":"最后一格","description":"以基地仅剩 1 点生命完成普通关卡。","group":"征途","tier":"gold"},
	{"id":"hundred_slayer","name":"百人斩","description":"单局击败 100 名敌人。","group":"战斗","tier":"silver"},
	{"id":"thousand_army","name":"千军破","description":"在一局无尽模式中击败 1,000 名敌人。","group":"无尽","tier":"gold"},
	{"id":"night_watch","name":"不眠守望","description":"单局无尽模式坚持 15 分钟。","group":"无尽","tier":"gold"},
	{"id":"five_crowns","name":"五王陨落","description":"累计击败 5 名 Boss。","group":"Boss","tier":"gold"},
	{"id":"full_squad","name":"全员出击","description":"三名角色在同一局中都造成过伤害。","group":"编队","tier":"silver"},
	{"id":"skill_storm","name":"战技倾泻","description":"单局累计释放 50 次 Q 战技。","group":"战斗","tier":"silver"},
	{"id":"ultimate_finale","name":"终极谢幕","description":"单局累计释放 20 次 E 终极技能。","group":"战斗","tier":"gold"},
	{"id":"crystal_overclock","name":"水晶超频","description":"单局将水晶提升至 Lv.20。","group":"成长","tier":"gold"},
	{"id":"stack_ten","name":"层层加码","description":"单局将任意卡牌叠加至 Lv.10。","group":"构筑","tier":"silver"},
	{"id":"four_rarities","name":"四阶齐鸣","description":"单局构筑同时拥有普通、稀有、史诗与传奇卡牌。","group":"构筑","tier":"gold"},
	{"id":"legend_collector","name":"传奇收藏家","description":"发现 15 张传奇卡牌。","group":"收藏","tier":"gold"},
	{"id":"roster_complete","name":"全员到齐","description":"解锁所有已完成角色。","group":"收藏","tier":"legendary"},
	{"id":"eight_fronts","name":"八区守望","description":"完成裂隙守望全部八个区域。","group":"征途","tier":"legendary"},
	{"id":"boss_archive","name":"统领档案","description":"遭遇全部已实装 Boss。","group":"Boss","tier":"gold"},
	{"id":"war_archive","name":"战报满载","description":"保存 20 份最终构筑战报。","group":"收藏","tier":"silver"},
	{"id":"speed_clear","name":"雷霆通关","description":"在 4 分钟内完成任意普通关卡。","group":"征途","tier":"gold"},
	{"id":"endless_marathon","name":"无尽长夜","description":"单局无尽模式坚持 30 分钟。","group":"无尽","tier":"legendary"},
	{"id":"million_firepower","name":"百万火力","description":"单局累计造成 1,000,000 点伤害。","group":"战斗","tier":"gold"},
	{"id":"cold_start","name":"冷启动","description":"在幸运值不高于 0.05 时完成普通关卡。","group":"挑战","tier":"silver"},
	{"id":"energy_overflow","name":"能量溢出","description":"单局任意角色的最高能量达到 300。","group":"成长","tier":"silver"},
	{"id":"solo_army","name":"一人成军","description":"单名角色单局造成 500,000 伤害且占全队伤害 80% 以上。","group":"编队","tier":"gold"},
	{"id":"balanced_team","name":"三位一体","description":"三名角色单局伤害占比都达到 20%。","group":"编队","tier":"gold"},
	{"id":"thirty_buffs","name":"武装到牙齿","description":"单局拥有 30 种不同强化。","group":"构筑","tier":"legendary"},
	{"id":"five_legends","name":"五重传奇","description":"单局构筑拥有 5 张不同传奇卡牌。","group":"构筑","tier":"legendary"},
	{"id":"true_guardian","name":"真正的守望者","description":"完成蚀日围城。","group":"征途","tier":"legendary"},
]

static func by_id(id: String) -> Dictionary:
	for item: Dictionary in ITEMS:
		if str(item.id) == id:
			return item
	return {}

static func tier_color(tier: String) -> Color:
	return {"bronze":Color("#c98263"),"silver":Color("#b9c4cf"),"gold":Color("#f0bd52"),"legendary":Color("#ef5470")}.get(tier, Color("#b9c4cf"))

static func tier_name(tier: String) -> String:
	return {"bronze":"铜","silver":"银","gold":"金","legendary":"传奇"}.get(tier, "成就")

static func icon_path(id: String) -> String:
	var item := by_id(id)
	if item.is_empty():
		return ICON_PLACEHOLDER
	var path := "%s%s.png" % [ICON_DIR, str(item.get("name", ""))]
	return path if ResourceLoader.exists(path) else ICON_PLACEHOLDER
