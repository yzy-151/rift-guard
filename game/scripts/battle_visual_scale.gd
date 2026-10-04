extends RefCounted
## Display dimensions only. Never use these values for damage or movement.
const ORIGINAL_DOWN_ONLY := ["grunt", "runner", "armored", "ranged", "buffer", "charger", "shielded", "hilichurl_brute", "rift_bat", "troop_melee", "troop_ranged", "troop_cannon"]
const HERO_ATLAS_SIZE := 116.0
const ENEMY_ATLAS_SIZES := {
	"grunt": 96.0, "runner": 86.0, "armored": 110.0, "ranged": 94.0,
	"buffer": 102.0, "charger": 114.0, "shielded": 184.0,
	"splitter": 138.0, "hilichurl_brute": 188.0, "troop_cannon": 100.0,
	"troop_melee": 72.0, "troop_ranged": 72.0, "rift_bat": 72.0,
	"originium_bug": 68.0, "boss_01": 322.0, "boss_02": 210.0,
	"boss_03": 204.0, "boss_galio": 184.0,
}
# Alpha bounds measured from original run atlases. In particular the commander
# occupies only 54 percent of its cell: its 322px cell is a 175px silhouette.
const BODY_HEIGHT_RATIO := {
	"grunt":0.77,"runner":0.81,"armored":0.80,"ranged":0.71,"buffer":0.83,
	"charger":0.71,"shielded":0.71,"splitter":0.74,"hilichurl_brute":0.66,
	"troop_cannon":0.56,"troop_melee":0.50,"troop_ranged":0.57,
	"rift_bat":0.58,"originium_bug":0.46,"boss_01":0.545,"boss_02":0.86,
}

static func enemy_size(kind: String, original: float) -> float:
	return float(ENEMY_ATLAS_SIZES.get(kind, minf(original, 92.0)))

static func enemy_height(kind: String, original: float) -> float:
	return enemy_size(kind, original) * float(BODY_HEIGHT_RATIO.get(kind, 0.82))

static func hero_pick_rect(foot: Vector2) -> Rect2:
	return Rect2(foot + Vector2(-28, -96), Vector2(56, 106))
