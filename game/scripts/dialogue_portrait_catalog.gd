extends RefCounted

const CATALOG_PATH := "res://data/dialogue_portraits.json"
const DEFAULT_EXPRESSION := {
	"阿米娅": "微笑",
	"艾米莉亚": "微笑",
	"丰川祥子": "冷淡",
	"风堇": "自信",
	"芙宁娜": "傲娇",
	"格温": "惊讶",
	"哥伦比亚": "微笑",
	"洛琪希": "不悦",
}
const EXPRESSION_CUES := [
	{"expression": "羞恼", "words": ["羞恼", "脸红又", "别看", "不许看"]},
	{"expression": "害羞", "words": ["害羞", "脸红", "红着脸", "不好意思", "悄悄", "低下头"]},
	{"expression": "生气", "words": ["生气", "怒", "发火", "吼", "闭嘴", "不准", "不许"]},
	{"expression": "警惕", "words": ["警惕", "戒备", "小心", "危险", "守住"]},
	{"expression": "惊讶", "words": ["惊讶", "震惊", "突然", "什么？！", "怎么会", "等等"]},
	{"expression": "不安", "words": ["不安", "担心", "害怕", "恐怕", "颤抖"]},
	{"expression": "委屈", "words": ["委屈", "难过", "哭", "失去", "没能", "对不起"]},
	{"expression": "思考", "words": ["思考", "考虑", "推理", "想了想", "若是"]},
	{"expression": "自信", "words": ["自信", "交给我", "出发吧", "能做到"]},
	{"expression": "得意", "words": ["得意", "哼", "赢了", "漂亮"]},
	{"expression": "傲娇", "words": ["傲娇", "才不是", "别误会", "勉强"]},
	{"expression": "冷淡", "words": ["冷淡", "冷声", "面无表情", "平静地"]},
	{"expression": "微笑", "words": ["微笑", "笑了", "谢谢", "放心"]},
]

var portraits: Dictionary = {}

func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		portraits = parsed.get("portraits", {})

func has_speaker(speaker: String) -> bool:
	return portraits.has(_normalized_speaker(speaker))

func resolve_line(line: Dictionary) -> String:
	var original: String = str(line.get("portrait", ""))
	if bool(line.get("portrait_locked", false)) and ResourceLoader.exists(original):
		return original
	var speaker: String = _normalized_speaker(str(line.get("speaker", "")))
	if not portraits.has(speaker):
		return original
	var available: Dictionary = portraits[speaker]
	var explicit_expression: String = str(line.get("expression", ""))
	if available.has(explicit_expression):
		return str(available[explicit_expression])
	var dialogue_text: String = str(line.get("text", ""))
	for cue: Dictionary in EXPRESSION_CUES:
		var expression: String = str(cue["expression"])
		if not available.has(expression):
			continue
		for word: String in cue["words"]:
			if dialogue_text.contains(word):
				return str(available[expression])
	var fallback: String = str(DEFAULT_EXPRESSION.get(speaker, ""))
	if available.has(fallback):
		return str(available[fallback])
	return str(available.values()[0]) if not available.is_empty() else original

func _normalized_speaker(speaker: String) -> String:
	return "哥伦比亚" if speaker == "少女" else speaker
