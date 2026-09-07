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
	"boss_01": {"name": "裂隙统领", "hp": 3600.0, "armor": 125.0, "speed": 25.0, "damage": 58.0, "rate": 0.8, "leak": 100, "color": "#d05b78", "size": 102.0, "shield": 700.0, "boss_pulse": 7.0}
}
# Fixed encounters make changes in positioning directly comparable.
const WAVES = [
	["grunt", "grunt", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt"],
	["runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "grunt", "armored", "runner"],
	["armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "runner", "armored", "grunt", "runner", "armored", "grunt", "runner", "armored"],
	["runner", "armored", "runner", "grunt", "armored", "runner", "grunt", "armored", "runner", "grunt", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored"],
	["armored", "runner", "runner", "grunt", "armored", "runner", "armored", "grunt", "runner", "armored", "runner", "grunt", "armored", "runner", "runner", "armored", "grunt", "runner", "armored", "runner", "armored"]
]
