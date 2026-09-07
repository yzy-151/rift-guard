extends RefCounted

const HEROES = [
	{"name": "磐石", "role": "近战守卫", "element": "", "hp": 280.0, "armor": 40.0, "damage": 23.0, "rate": 1.2, "range": 96.0, "speed": 195.0, "block": 2, "pos": Vector2(505, 360), "color": "#c5bd96", "tile": Vector2(0, 112)},
	{"name": "灰烬", "role": "火系射手", "element": "fire", "hp": 110.0, "armor": 5.0, "damage": 32.0, "rate": 1.5, "range": 300.0, "speed": 230.0, "block": 0, "pos": Vector2(375, 295), "color": "#eaaa7d", "tile": Vector2(16, 112)},
	{"name": "芙宁娜", "role": "水系辅助", "element": "water", "hp": 135.0, "armor": 10.0, "damage": 16.0, "rate": 1.1, "range": 310.0, "speed": 220.0, "block": 0, "pos": Vector2(345, 430), "color": "#83c7e8", "tile": Vector2(48, 112), "visual": "furina"}
]
const ENEMIES = {
	"grunt": {"name": "裂隙兽", "hp": 95.0, "armor": 0.0, "speed": 54.0, "damage": 15.0, "rate": 1.0, "leak": 12, "color": "#bd8e94", "size": 48.0},
	"runner": {"name": "疾行兽", "hp": 62.0, "armor": 0.0, "speed": 95.0, "damage": 10.0, "rate": 1.3, "leak": 10, "color": "#e6c77b", "size": 39.0},
	"armored": {"name": "重甲兽", "hp": 185.0, "armor": 85.0, "speed": 35.0, "damage": 27.0, "rate": 0.85, "leak": 24, "color": "#b19fc9", "size": 62.0}
	,"boss_01": {"name": "裂隙统领", "hp": 2400.0, "armor": 110.0, "speed": 24.0, "damage": 45.0, "rate": 0.7, "leak": 100, "color": "#d05b78", "size": 92.0}
}
# Fixed encounters make changes in positioning directly comparable.
const WAVES = [
	["grunt", "grunt", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt"],
	["runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt", "armored", "runner"],
	["armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "runner", "armored", "grunt", "runner", "armored", "grunt", "runner", "armored"],
	["runner", "armored", "runner", "grunt", "armored", "runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored"],
	["armored", "runner", "runner", "grunt", "armored", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored", "runner", "runner", "armored", "grunt", "runner", "armored", "runner", "armored"]
]
