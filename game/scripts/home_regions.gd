extends RefCounted
## Authored exploration places; social visitors never grant combat unlocks.
const ORDER: Array[String] = ["base", "harbor", "garden"]
const INFO := {
	"base": {"name":"守望基地", "subtitle":"灯还亮着，就总有人会回来。", "accent":"#ff526a"},
	"harbor": {"name":"雾灯港 · 午夜营业", "subtitle":"离岸的船载走委托，留下没讲完的故事。", "accent":"#70dcca"},
	"garden": {"name":"月影温室 · 云上花房", "subtitle":"花朵禁止许愿。管理员本人可以商量。", "accent":"#d1adff"},
}
static func portals(region: String) -> Array[Dictionary]:
	match region:
		"base": return [{"id":"harbor", "name":"雾灯港", "x":2460.0, "action":"前往雾灯港", "arrival_x":180.0}]
		"harbor": return [{"id":"base", "name":"基地回廊", "x":85.0, "action":"返回守望基地", "arrival_x":2320.0}, {"id":"garden", "name":"温室升降梯", "x":2440.0, "action":"前往月影温室", "arrival_x":185.0}]
		"garden": return [{"id":"harbor", "name":"港口升降梯", "x":85.0, "action":"返回雾灯港", "arrival_x":2300.0}]
	return []
static func residents(region: String) -> Array[Dictionary]:
	match region:
		"harbor": return [{"id":"hero_03", "pos":Vector2(600,540)}, {"id":"hero_04", "pos":Vector2(1230,500)}, {"id":"hero_07", "pos":Vector2(1890,554)}]
		"garden": return [{"id":"hero_02", "pos":Vector2(525,516)}, {"id":"hero_08", "pos":Vector2(1000,565)}, {"id":"hero_10", "pos":Vector2(1550,506)}, {"id":"hero_13", "pos":Vector2(2070,556)}]
	return []
static func story_key(region: String, character: String) -> String:
	return "explore_%s_%s" % [region, character]
static func _encounter(region: String, id: String, speaker: String, lead: String, problem: String, good: String, answer: String, silly: String, response: String) -> Array:
	var portrait := "res://assets/characters/sequences/%s/portrait.png" % id
	return [
		{"portrait":portrait, "speaker":speaker, "text":lead},
		{"portrait":portrait, "speaker":speaker, "text":problem, "choices":[
			{"text":good, "response_speaker":speaker, "response":answer, "home_success":true, "home_region_story":story_key(region,id)},
			{"text":silly, "response_speaker":speaker, "response":response, "home_success":false, "home_region_story":story_key(region,id), "home_reason":"你很有创造力。下次请把创造力留给没有保险丝的东西。"},
		]},
	]
static func stories() -> Dictionary:
	return {
		story_key("harbor","hero_03"):_encounter("harbor","hero_03","芙宁娜","这座露天剧场只有三只海鸥买票。两只逃票，剩下一只在吃票。","不过，幕布都升起来了。你愿意当今晚的第四位观众吗？","我坐第一排。谢幕时记得看这里。","那可说好了！今晚这一场，不许用‘顺路’来形容。","把海鸥抓来审判，先追缴票款。","伟大的审判官，海鸥刚刚判处你的头发立即执行。"),
		story_key("harbor","hero_04"):_encounter("harbor","hero_04","洛琪希","港口的天气预报写着‘晴’，雨却下进了售货机。有人建议我给云上一堂礼仪课。","我想在这儿开一间小小的魔法教室。第一堂课，从什么开始？","先教怎样停下来。再教怎样让雨落下。","很好。能收住力量的人，才有资格说自己学会了。温室就在东边的升降梯上，下次一起去吧。","先教十倍威力。屋顶没了就不会漏雨。","你的教室预算很勇敢。请替港口的屋顶向财政部道歉。"),
		story_key("harbor","hero_07"):_encounter("harbor","hero_07","丰川祥子","旧钢琴搬来时少了一个键，调律师说它正好可以负责‘沉默’。","如果今晚只弹给一个人听，那个人会觉得寂寞吗？","留一个座位给我，弹到你愿意停下。","……那就别在最后一个音还没落下时鼓掌。我会记得你坐在哪里。","把缺的键涂成金色，宣布这是限定款。","很好，你被任命为营销总监。钢琴说它现在想辞职。"),
		story_key("garden","hero_02"):_encounter("garden","hero_02","希露菲","这些花见到生人就装睡。只有那盆蒲公英，每天坚持向吊灯发起远征。","我想让这里成为大家能好好休息的地方，而不是另一处战场。","我来搬花盆。你先坐下休息一会儿。","那我就把最安静的位置留给你。我们可以一起什么也不着急做。","给花盆装履带，让它们自己去追太阳。","刚才那盆蒲公英听见了。现在它要求配发头盔。"),
		story_key("garden","hero_08"):_encounter("garden","hero_08","艾米莉亚","我给结冰的池塘堆了一个小精灵。大家都说它像一只对加班很有意见的土豆。","要不要给它起个名字？别太威风，它会当真的。","叫它‘明天再说’。今晚大家都该休息。","呵呵，它听起来会成为很可靠的值夜班伙伴。你也别总是把事情留给自己。","叫‘终焉冻土毁灭神’，然后让它看门。","它刚把欢迎牌冻裂了。现在你得向新来的客人解释，门神其实很害羞。"),
		story_key("garden","hero_10"):_encounter("garden","hero_10","风堇","来得正好，我在给云朵量体温。那一朵坚持说自己只是有一点社交焦虑。","你走过那么多地方，有没有哪一刻觉得，停下来也没有关系？","现在。这里有你，也有愿意等人的风。","那今天的处方就是：慢慢呼吸，坐一会儿。剩下的路，等风也准备好了再走。","让云做二十组俯卧撑，肯定立刻晴天。","患者提出投诉：它没有手。你的治疗方案被小伊卡正式驳回。"),
		story_key("garden","hero_13"):_encounter("garden","hero_13","格温","我在替温室缝一块新窗帘。风一直偷看，所以我给它留了一个特别小的洞。","你觉得窗帘上该绣什么？它会是每天回家第一眼看见的东西。","绣每个人留下的一小段故事，慢慢补齐。","好呀！那你的那一格先空着。等你想好了，我会一直留着线。","绣‘禁止迟到’，再给月亮办一张考勤卡。","月亮刚申请了三十天弹性工作。你看，它连印章都只盖了一半。"),
	}
