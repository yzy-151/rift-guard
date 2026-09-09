extends RefCounted

const HEROES = [
	{"name": "磐石", "role": "近战守卫", "element": "", "hp": 280.0, "armor": 40.0, "damage": 23.0, "rate": 1.2, "range": 96.0, "speed": 195.0, "block": 2, "pos": Vector2(505, 360), "color": "#c5bd96", "tile": Vector2(0, 112)},
	{"name": "灰烬", "role": "火系射手", "element": "fire", "hp": 110.0, "armor": 5.0, "damage": 32.0, "rate": 1.5, "range": 300.0, "speed": 230.0, "block": 0, "pos": Vector2(375, 295), "color": "#eaaa7d", "tile": Vector2(16, 112)},
	{"name": "芙宁娜", "role": "水系辅助", "element": "water", "hp": 135.0, "armor": 10.0, "damage": 16.0, "rate": 1.1, "range": 310.0, "speed": 220.0, "block": 0, "pos": Vector2(345, 430), "color": "#83c7e8", "tile": Vector2(48, 112), "visual": "furina"}
]
const ENEMIES = {
	"grunt": {"name": "裂隙兽", "hp": 95.0, "armor": 0.0, "speed": 54.0, "damage": 15.0, "rate": 1.0, "leak": 8, "color": "#bd8e94", "size": 48.0},
	"runner": {"name": "疾行兽", "hp": 62.0, "armor": 0.0, "speed": 95.0, "damage": 10.0, "rate": 1.3, "leak": 6, "color": "#e6c77b", "size": 39.0},
	"armored": {"name": "重甲兽", "hp": 185.0, "armor": 85.0, "speed": 35.0, "damage": 27.0, "rate": 0.85, "leak": 15, "color": "#b19fc9", "size": 62.0},
	"flyer": {"name": "浮空猎手", "hp": 88.0, "armor": 8.0, "speed": 78.0, "damage": 12.0, "rate": 1.15, "leak": 9, "color": "#80d7d7", "size": 43.0, "flying": true},
	"ranged": {"name": "蚀骨弩手", "hp": 128.0, "armor": 12.0, "speed": 43.0, "damage": 21.0, "rate": 0.72, "leak": 12, "color": "#e58b73", "size": 48.0, "attack_range": 275.0},
	"buffer": {"name": "咏唱祭司", "hp": 155.0, "armor": 18.0, "speed": 38.0, "damage": 9.0, "rate": 0.65, "leak": 14, "color": "#cf7fda", "size": 54.0, "aura_radius": 155.0},
	"shielded": {"name": "壁垒卫士", "hp": 210.0, "armor": 38.0, "speed": 31.0, "damage": 31.0, "rate": 0.78, "leak": 20, "color": "#76a6d8", "size": 66.0, "shield": 180.0},
	"charger": {"name": "裂蹄冲锋者", "hp": 145.0, "armor": 18.0, "speed": 48.0, "damage": 34.0, "rate": 0.92, "leak": 16, "color": "#ef795b", "size": 58.0, "charge_multiplier": 2.15},
	"healer": {"name": "血契医师", "hp": 175.0, "armor": 14.0, "speed": 34.0, "damage": 10.0, "rate": 0.62, "leak": 16, "color": "#75d6a2", "size": 55.0, "heal_radius": 190.0, "heal_interval": 5.5},
	"splitter": {"name": "孳生母体", "hp": 240.0, "armor": 26.0, "speed": 32.0, "damage": 20.0, "rate": 0.82, "leak": 22, "color": "#d77aa9", "size": 72.0, "split_count": 2},
	"warder": {"name": "黑曜司祭", "hp": 205.0, "armor": 32.0, "speed": 30.0, "damage": 15.0, "rate": 0.70, "leak": 19, "color": "#8ba4e8", "size": 62.0, "ward_radius": 205.0, "ward_interval": 6.5},
	"boss_01": {"name": "裂隙统领", "hp": 5200.0, "armor": 130.0, "speed": 27.0, "damage": 66.0, "rate": 0.82, "leak": 100, "color": "#d05b78", "size": 104.0, "shield": 900.0, "boss_pulse": 6.6, "boss_style": "commander", "phase_minion": "charger"},
	"boss_02": {"name": "黑曜母巢", "hp": 6300.0, "armor": 145.0, "speed": 22.0, "damage": 58.0, "rate": 0.74, "leak": 100, "color": "#9a4f92", "size": 118.0, "shield": 1100.0, "boss_pulse": 6.0, "boss_style": "brood", "summon_count": 4, "summon_limit": 12, "phase_minion": "splitter"},
	"boss_03": {"name": "苍穹风暴", "hp": 5600.0, "armor": 95.0, "speed": 38.0, "damage": 60.0, "rate": 0.92, "leak": 100, "color": "#66c9d8", "size": 108.0, "shield": 650.0, "boss_pulse": 5.4, "boss_style": "storm", "flying": true, "phase_minion": "flyer"},
	"boss_04": {"name": "万仞壁垒", "hp": 7600.0, "armor": 210.0, "speed": 18.0, "damage": 78.0, "rate": 0.66, "leak": 100, "color": "#d5ac58", "size": 124.0, "shield": 2200.0, "boss_pulse": 6.8, "boss_style": "bulwark", "phase_shield_restore": 0.72, "phase_minion": "warder"},
	"boss_05": {"name": "熔核炮台", "hp": 6100.0, "armor": 125.0, "speed": 24.0, "damage": 92.0, "rate": 0.58, "leak": 100, "color": "#ef704f", "size": 114.0, "shield": 800.0, "boss_pulse": 5.0, "boss_style": "artillery", "attack_range": 440.0, "phase_minion": "ranged"},
	"boss_06": {"name": "噬时魔像", "hp": 6800.0, "armor": 155.0, "speed": 31.0, "damage": 72.0, "rate": 1.02, "leak": 100, "color": "#9878e8", "size": 120.0, "shield": 1050.0, "boss_pulse": 4.8, "boss_style": "chronophage", "life_steal": 0.55, "phase_minion": "healer"}
}
# Fixed encounters make changes in positioning directly comparable.
const WAVES = [
	["grunt", "grunt", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt"],
	["runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt", "armored", "runner"],
	["armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "runner", "armored", "grunt", "runner", "armored", "grunt", "runner", "armored"],
	["runner", "armored", "runner", "grunt", "armored", "runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored"],
	["armored", "runner", "runner", "grunt", "armored", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored", "runner", "runner", "armored", "grunt", "runner", "armored", "runner", "armored"]
]
