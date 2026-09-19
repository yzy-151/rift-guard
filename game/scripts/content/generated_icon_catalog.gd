extends RefCounted

const CARD_DIR := "res://assets/ui/card_icons_80/"
const SKILL_DIR := "res://assets/ui/character_skills_26/"
const SKILL_FILES := {
	"hero_01": ["少女_Q_静谧圣歌.png", "少女_E_寂月安魂曲.png"],
	"hero_02": ["希露菲_Q_静风疗愈.png", "希露菲_E_无咏风域.png"],
	"hero_03": ["芙宁娜_Q_孤心沙龙.png", "芙宁娜_E_万众狂欢.png"],
	"hero_04": ["洛琪希_Q_水脉疗愈.png", "洛琪希_E_豪雷积层云.png"],
	"hero_05": ["知更鸟_Q_振翅音阶.png", "知更鸟_E_千音迭奏.png"],
	"hero_06": ["阿米娅_Q_精神爆发.png", "阿米娅_E_奇美拉.png"],
	"hero_07": ["丰川祥子_Q_灼热乐章.png", "丰川祥子_E_焰色交响曲.png"],
	"hero_08": ["艾米莉亚_Q_冰晶花.png", "艾米莉亚_E_冰结之森.png"],
	"hero_09": ["萨勒芬妮_Q_高音节拍.png", "萨勒芬妮_E_炫音返场.png"],
	"hero_10": ["风堇_Q_风刃切流.png", "风堇_E_长风复苏.png"],
	"hero_11": ["凯尔希_Q_Mon3tr部署.png", "凯尔希_E_指令·熔毁.png"],
	"hero_12": ["铃_Q_邦布协同.png", "铃_E_绳网超频.png"],
	"hero_13": ["格温_Q_丝缕缠流.png", "格温_E_引针簇射.png"],
}

static func card_path(card: Dictionary) -> String:
	var path := CARD_DIR + str(card.get("name", "")) + ".png"
	return path if ResourceLoader.exists(path) else ""

static func card_texture(card: Dictionary) -> Texture2D:
	var path := card_path(card)
	return ResourceLoader.load(path) as Texture2D if not path.is_empty() else null

static func ability_texture(character_id: String, ultimate: bool) -> Texture2D:
	if not SKILL_FILES.has(character_id):
		return null
	var files: Array = SKILL_FILES[character_id]
	var path := SKILL_DIR + str(files[1 if ultimate else 0])
	return ResourceLoader.load(path) as Texture2D if ResourceLoader.exists(path) else null
