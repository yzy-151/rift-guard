"""Rebuild portrait dialogue so only NPCs speak on portrait pages.

The HOME rows keep each resident's five original encounter themes and the existing
success/failure reasons; comic actions live outside the portrait dialogue.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game" / "data"

# key | NPC opening | NPC question | spoken good reply | spoken bad reply
HOME_ROWS = """
home_hero_01_0|这块水晶今天不唱了。它是不是也想请一天假？|如果我敲碎它，能听见最后一个音吗？|别敲。安静也可以是一首歌，我陪你等。|敲吧，静音键哪有拆机快。
home_hero_01_1|雾里这扇门，是我刚刚画出来的。|你也想知道门后是什么？我还没决定。|不知道也没关系，我在门前陪你。|既然你画的，你总该把门后攻略背出来吧？
home_hero_01_2|小鸟听我的歌，哨兵却快听不见警报了。|你说，副歌该往哪儿放？|把歌声压低一点，给警报留个主唱位。|警报只会哔哔，继续唱到它闭嘴。
home_hero_01_3|今晚没有宴会，我却写了一张请柬。|这张空白请柬要寄给谁？|寄给今晚一个人吃饭的人，座位现在就有。|先收着吧，等场面大一点再邀请。
home_hero_01_4|有颗星很久没人抬头看了。|它会不会以为自己已经熄灭？|别催人看星星，我先陪他坐一会儿。|我替他看见了，你把星星开亮一点。
home_hero_02_0|护盾术还差一遍。我的手指倒是已经申请下班。|如果我现在停下，谁来挡下一次攻击？|你先喝口茶，我陪你守这一班。|手指还能动就继续练，熟练度最重要。
home_hero_02_1|这件披风是我缝的，好像肩膀太紧了。|现在送出去，会不会被嫌弃？|先问穿它的人舒不舒服，改起来也来得及。|别问，直接给他穿上，惊喜比较重要。
home_hero_02_2|他们说我不用去前面，站在后面就好。|你也觉得我只能被保护吗？|我想和你并肩，前后由你自己选。|你别上前线，我替你把位置安排好了。
home_hero_02_3|饭做多了，那个空位还没人回来。|要不要等到整锅都凉了？|给他留一份热的，我们先吃，你也别饿着。|就这样等着吧，大家陪你一起饿。
home_hero_02_4|新同伴不想说名字，我不想逼他。|介绍他时，应该怎么说？|先说这是我们的同伴，名字等他想说再说。|名字都不报，我怎么把他录进队伍？
home_hero_03_0|舞台搭好了，灯也亮了。偏偏我现在想坐在台下。|你会不会觉得主演临阵脱逃很丢脸？|今晚我陪你坐观众席，票钱算我的。|你必须上台，主角怎么可以休息？
home_hero_03_1|新甜点出炉。外形像冠军奖杯，味道我还不敢保证。|你敢给我真实的评价吗？|我尝一口就说实话，你也不许记仇。|很完美，我连吃都不用吃就知道。
home_hero_03_2|剧本把我的结局写好了，还替我签了名。|你要替我写一个更漂亮的吗？|笔还给你，结尾由你自己说。|我给你写个万人鼓掌的大团圆，别改了。
home_hero_03_3|票只卖出去一张。第一排那个小孩坐得比评委还直。|一人的演出，也算首演吗？|算。我就是第二位观众，开演吧。|先取消，等观众人数凑够再说。
home_hero_03_4|这段录像把我笑场的地方都剪掉了。|你想看完美版，还是那个真的我？|我想看你笑场的那一版。|把失误全删掉，观众只配看完美。
home_hero_04_0|我在术式里故意留了一处缺口，学生们都等着我补。|你也打算替他们把答案写完吗？|先让他们说缺口会造成什么，再一起补。|我直接把标准答案抄上去，效率第一。
home_hero_04_1|这页公式我还没验证。老师也有不会的题，真不体面。|你会把它当成标准答案讲出去吗？|你我一起验证，问号留着也不丢人。|放心，我会写成定论，替你撑场面。
home_hero_04_2|学生会施法，却说不清为什么。考核明天就到。|要补一夜术语，还是换种办法？|让他用最简单的话讲给我听。|术语越复杂越像高手，让他连夜背。
home_hero_04_3|第一次独自旅行时，我也怕得睡不着。|你是不是也以为老师从来不害怕？|我想听听你后来怎么迈出第一步。|老师也会怕？这个人设不该崩啊。
home_hero_04_4|药已经起效，病人刚睡着。旁边却催我加量。|你会再灌一瓶吗？|先看他的呼吸和反应，药又不是冲排行榜。|剂量翻倍，康复速度也该翻倍吧。
home_hero_06_0|值夜的同伴把求助写得比脚注还小。|我该当众替他说出来吗？|先私下问他愿不愿意让我帮忙。|我替他在全基地广播，省得他开口。
home_hero_06_1|计划书把全部风险签在我一个人名下。|负责人是不是就该这样？|你可以负责，也可以请大家一起看风险。|你是负责人，全签了就算解决了。
home_hero_06_2|门外有伤员，药只够紧急处理。|敌方的人也要分到这份药吗？|先止血救命，身份等人活下来再问。|他站错队了，让他等我们的药用完。
home_hero_06_3|老队员当众质疑我的安排，大家都在看我。|你会替我把争论压下去吗？|让他把担心讲完，你也有权解释。|我替你吼回去，谁敢质疑你就是反派。
home_hero_06_4|纪念牌上只留了称号那一栏。|一个人的名字，能不能比功绩更重要？|先写他的名字，再问家人想留下些什么。|写最高荣誉吧，名字反而不够响亮。
home_hero_07_0|舞台灯还差一盏没校准。|你要说我强迫症，还是帮我看一眼？|我帮你看，但你也得吃晚饭。|有一点误差就全部重来，饭先取消。
home_hero_07_1|旧曲谱被人改了一个和弦，改的人说是帮我。|你听见的，是错误还是另一个可能？|先让我听原版，再听你真正想弹的。|既然是好意，你就该直接接受。
home_hero_07_2|邀请函写好了，我又撕掉。|旧友若真的来，我该先说什么？|不用准备完美开场，先说你想见她。|别寄，免得旧账又来抢主舞台。
home_hero_07_3|最后一段我让所有人停下。没有错音。|你听见少了什么吗？|没有错音，却少了你的呼吸。我们再来。|没错就过，你的感觉不算证据。
home_hero_07_4|演出费用和我自己的饭钱写在同一页。|你想帮忙，也会先问我吗？|我先问你愿意怎么分担，再一起算。|我直接替你付了，你别再逞强。
home_hero_08_0|那个孩子躲在门边，我手里的礼物像一份通缉令。|我现在靠近，会不会吓到他？|我把礼物放这儿，等他愿意再拿。|我把他拉过来，解释清楚就好了。
home_hero_08_1|有人误会我，我已经准备好道歉。|明明不是我做的，道歉会不会更快？|你可以先听他怕什么，不必认下没做的事。|先道歉吧，谁让你看起来像坏人。
home_hero_08_2|冬夜的花快冻坏了，我想立刻升温。|一口气暖到夏天，会不会比较好？|慢慢升温吧，花也需要适应。|直接开最大火力，花都该谢谢你。
home_hero_08_3|那封信又把我和可怕的传说写在一起。|我该把每一句都解释清楚吗？|你可以说自己的话，不必替传说答辩。|逐字反驳吧，不然他们永远不信。
home_hero_08_4|点心烤焦一点点。我想把整盘藏起来。|你确定不会笑我吗？|我想尝一块，焦边也能配茶。|藏吧，不完美的东西别端出来。
home_hero_10_0|伤员说不疼，却把袖口攥得发白。|我该相信他的嘴，还是先看他的手？|先问他最怕哪里疼，别急着替他答。|既然他说不疼，病历写没事就好。
home_hero_10_1|药箱里有强效药，也有普通热敷。|每个人都用强效的，听起来很公平吧？|先看症状再给药，公平不是每人一大勺。|强效药都倒上，省得被说偏心。
home_hero_10_2|病床旁的名牌还是空的。|有人提议只写编号，这样省事。|写他们愿意被叫的名字，编号留给药箱。|病号统一编号，叫错名字也没关系。
home_hero_10_3|我值了两个夜班，第三个也能撑。|你是不是来劝我继续当英雄？|我替你守这一班，你先睡一会儿。|还有人需要你，睡觉等通关再说。
home_hero_10_4|病人快康复了，我把庆祝的小花藏在袖子里。|他却说现在还不敢高兴。|那就慢慢等，庆祝可以晚一点。|都快好了，你别扫兴，马上庆祝。
home_hero_13_0|这件旧外套的线脚歪得像醉酒的小蛇。|你会把它们全拆掉吗？|先告诉我是谁缝的，再决定留哪一针。|我全部拆了，整齐才叫修好。
home_hero_13_1|小布偶两边不对称，左眼还比右眼凶。|你觉得它必须改成一样吗？|别改，它看着像会替人守夜。|对称才叫可爱，先返工再送人。
home_hero_13_2|我用圣霭挡住窗外阴影，结果队友连路都看不见了。|雾是不是开得太认真？|给大家留条能看清脚下的路。|越看不见越安全，把雾铺满整层。
home_hero_13_3|这颗纽扣会发光，远行时可以认路。|可暗处的敌人也会看见光。|让它只在需要时亮，别替主人暴露位置。|一直亮着吧，危险来了也能被看见。
home_hero_13_4|披肩还能修，主人却说想把它收起来。|你觉得我应该劝他继续穿吗？|我先问他想留住什么，再决定怎么缝。|能修就必须修，他舍不得就替他决定。
home_hero_05_0|谢幕词最后一句听着像一辈子的承诺。|我不想让听众误会，也不想让他们失望。|把今晚的真心唱出来，不必许下永远。|直接说永远陪伴，大家最爱听这个。
home_hero_05_1|门外有人跟不上合唱，还躲着话筒。|我能听见他的声音，却不该替他开口。|给他留一个能加入的空拍。|直接点名吧，害羞的人都需要推一把。
home_hero_05_2|花已经枯了，寄花的人却攒了很久。|我该感谢这束花，还是假装它还新鲜？|告诉他这份心意我收到了。|枯花拍照不好看，换一束再回信。
home_hero_05_3|彩排唱错一段，我没有停下整首歌。|你会把那一秒剪得干干净净吗？|把它留着吧，那是大家一起接住的。|错音必须隐藏，不然谁还信你会唱。
home_hero_05_4|这首歌很轻，有人值守，有人刚能睡下。|我该让每个人都听见吗？|唱给想听的人，别把睡着的人叫醒。|全基地广播，不听就算不给你面子。
home_hero_09_0|两段旋律在我耳边抢开头，像两个群聊同时艾特我。|你能听出谁该先说吗？|先让最小声的那段说完。|谁响谁赢，直接把音量推满。
home_hero_09_1|她说自己的声音难听，我拿着话筒犹豫了。|递过去会不会像强迫她表演？|问她想不想试，我可以陪着唱。|话筒塞给她，习惯就不怕了。
home_hero_09_2|雨把谱纸淋成了水彩，里面有大家写给我的音。|你会只誊清我自己的那一行吗？|先把每个人的旋律都留住。|别人的音太乱，只保留你的主旋律。
home_hero_09_3|庆典只剩一支旧麦克风，杂音比我还会抢戏。|可我不想换掉它，你猜为什么？|它陪你唱过第一首吧，先听听它还能不能用。|旧的就该淘汰，我给你换最新款。
home_hero_09_4|他们练的是不同的歌，却都怕打扰对方。|能让两首歌都有自己的位置吗？|给两边留段轮唱，不用争同一拍。|选一个主唱吧，另一边先闭麦。
home_hero_11_0|报告写得很全，治疗者一栏却空着。|谁来承认自己也需要休息？|先把你的名字写上，治疗者也是人。|那栏空着挺好，医生本来就不准倒下。
home_hero_11_1|Mon3tr挡着门，里面其实没有敌人。|你要叫我命令它退开吗？|先问它在担心什么，我和你一起看。|它又不是人，直接让它让开。
home_hero_11_2|这份结论是错的，我把批注留在桌上。|你希望我替谁把错误藏起来？|别藏，先把后果说清楚，再一起改。|谁写错就把名字擦掉，问题也就没了。
home_hero_11_3|诊室灯还亮着，病例还有三份。|你如果劝我睡觉，最好拿出比口号更好的理由。|我来整理一份，你先休息十分钟。|通宵很酷，等把自己熬倒再算加班。
home_hero_11_4|方案未经验证，队伍催我签字。|时间确实紧，可错误也不会因着急变正确。|先做最小范围验证，再决定是否推进。|先签了再说，出事以后再补报告。
home_hero_12_0|地图显示直线最近，可沿途店铺全关了。|你是想最快到，还是能活着回来？|绕一下，补给与回程都算路程。|走直线，饿了让导航给我充电。
home_hero_12_1|邦布送来一段坏掉的语音，背景里像有求救。|你会直接定位，还是先确认声音来源？|先核对背景声，别把救援送进陷阱。|信号响了就是求救，先冲再想。
home_hero_12_2|我和哥哥都说能接夜班，排班表快被我们吵穿了。|你是不是要选个赢家？|你们轮流守，谁累了就喊我。|你们再争一会儿，反正我不用值班。
home_hero_12_3|邦布总在错误时间送来热饮，它却认真记着上次的指令。|你觉得它是笨，还是我的指令过期？|先改指令，别让它替旧时间背锅。|叫它再跑十遍，总会跑对的。
home_hero_12_4|地图上有条从没人报告回程的小路。|好走得像免费的游戏礼包，你敢接吗？|先找返回记录，再让探路的人带信标。|这么省时的路，不走才亏。
"""

HOME = {}
for raw in HOME_ROWS.strip().splitlines():
    key, first, second, good, bad = raw.split("|")
    HOME[key] = (first, second, good, bad)


def build_home():
    outcomes = json.loads((ROOT / "tools" / "home_story_outcomes.json").read_text(encoding="utf-8"))
    result = {}
    for key, (first, second, good, bad) in HOME.items():
        outcome = outcomes[key]
        name = outcome["speaker"]
        portrait = outcome["portrait"]
        choices = [
            {"text": good, "response_speaker": name, "response_portrait": portrait,
             "response": outcome["good_response"], "home_success": True},
            {"text": bad, "response_speaker": name, "response_portrait": portrait,
             "response": outcome["bad_response"], "home_success": False,
             "home_reason": outcome["bad_reason"]},
        ]
        result[key] = [
            {"portrait": portrait, "speaker": name, "text": first},
            {"portrait": portrait, "speaker": name, "text": second, "choices": choices},
        ]
    # A few conversations keep the deeper decision tree; every branch remains spoken aloud.
    roxy = result["home_hero_04_0"][-1]["choices"][0]
    roxy.pop("home_success")
    roxy["response"] = "嗯。可要是连我也答不上来呢？"
    roxy["follow_up"] = [{"portrait": result["home_hero_04_0"][0]["portrait"],
        "speaker": "洛琪希", "text": "前辈，你会允许老师在学生面前说‘我不知道’吗？", "choices": [
        {"text": "当然。一起求证比装懂更像老师。", "response_speaker": "洛琪希", "response": "那下节课请你坐第一排。不会的题，我们一起解。", "home_success": True},
        {"text": "老师怎么能不会？你先编个答案。", "response_speaker": "洛琪希", "response": "不行。编出来的答案会害学生把错误当真。", "home_success": False,
         "home_reason": "把老师的面子放在学生的理解之上。"},
    ]}]
    columbina = result["home_hero_01_0"][-1]["choices"][0]
    columbina.pop("home_success")
    columbina["response"] = "那你会在安静的时候，继续听我说话吗？"
    columbina["follow_up"] = [{"portrait": result["home_hero_01_0"][0]["portrait"],
        "speaker": "哥伦比亚", "text": "如果我今天一句也不说，你会留下吗？", "choices": [
        {"text": "会。沉默也算我们一起过的时间。", "response_speaker": "哥伦比亚", "response": "那就先不敲它。你听，风替我们补上了空拍。", "home_success": True},
        {"text": "那我替你把所有话说完。", "response_speaker": "哥伦比亚", "response": "不必。我的沉默不需要别人代言。", "home_success": False,
         "home_reason": "把沉默误当成需要替人填满的空白。"},
    ]}]
    gwen = result["home_hero_13_0"][-1]["choices"][0]
    gwen.pop("home_success")
    gwen["response"] = "是旧友缝的。线很歪，可我舍不得拆。"
    gwen["follow_up"] = [{"portrait": result["home_hero_13_0"][0]["portrait"],
        "speaker": "格温", "text": "内衬里还有一行字，线快磨没了。你会怎么补？", "choices": [
        {"text": "先把字读完，再决定从哪一针开始。", "response_speaker": "格温", "response": "好。上面写着‘记得回来’。你会留下自己的线吗？", "follow_up": [
            {"portrait": result["home_hero_13_0"][0]["portrait"], "speaker": "格温", "text": "这一次，你想把新线缝在哪儿？", "choices": [
                {"text": "缝在旧字旁边，别盖住它。", "response_speaker": "格温", "response": "嗯。是一起补，不是谁把谁覆盖掉。", "home_success": True},
                {"text": "盖上我的名字，这件衣服才像新的。", "response_speaker": "格温", "response": "不行。你那一针把想回来的人擦掉了。", "home_success": False,
                 "home_reason": "用自己的署名盖掉了旧友留下的记忆。"},
            ]}]},
        {"text": "字磨没了就算了，整片内衬换新。", "response_speaker": "格温", "response": "不行。你连那句话是什么都没问。", "home_success": False,
         "home_reason": "在理解旧物记忆前擅自抹掉痕迹。"},
    ]}]
    return result


def build_story():
    old = json.loads((DATA / "story.json").read_text(encoding="utf-8"))
    result = {}
    for key, lines in old.items():
        clean = []
        for row in lines:
            if row.get("speaker") in ("你", "旅行者", "旁白"):
                if row.get("choices") and clean:
                    clean[-1]["choices"] = row["choices"]
                continue
            clean.append(row)
        result[key] = clean
    roxy_portrait = "res://assets/helltaker/dialogue_portraits/洛琪希_不悦_重绘统一服装.png"
    result["mode1_opening"] = [
        {"portrait": roxy_portrait, "speaker": "洛琪希", "text": "嗯？这是什么地方？"},
        {"portrait": roxy_portrait, "speaker": "洛琪希", "text": "唔，又传送到奇怪的地方了吗？"},
        {"portrait": roxy_portrait, "speaker": "洛琪希", "text": "前辈，你知道格雷拉特家怎么走吗？我来应聘家庭教师。", "choices": [
            {"text": "什么……雷……拉拉？管不了这么多了，跟我走吧！", "response_speaker": "洛琪希", "response_portrait": roxy_portrait,
             "response": "诶？？格雷拉特家是这个方向吧？算了，我先跟你走。", "intro_outcome": "success",
             "result": "lucky_start", "effect": {"type": "luck", "value": 0.08}, "story_flag": "defense_route", "campaign_node": "c1_elite"},
            {"text": "洛琪希小姐，我们被魔族包围了！", "response_speaker": "洛琪希", "response_portrait": roxy_portrait,
             "response": "我姑且也是魔族哦。连这都不知道，带路就免了。", "intro_outcome": "roxy_departure",
             "result": "roxy_departure"},
        ]},
    ]
    result["opening"] = [
        {"portrait": "res://assets/characters/sequences/hero_02/portrait.png", "speaker": "希露菲", "text": "我也被卷进来了。系统把水晶塞给我们，售后服务只写了两个字：自救。"},
        {"portrait": "res://assets/characters/sequences/hero_07/portrait.png", "speaker": "丰川祥子", "text": "既然它把我们当演员，就请它先付演出费。现在，守住水晶。"},
    ]
    for key, rows in result.items():
        if key.startswith("mode1_stage") and key.endswith("_won") and rows:
            rows[-1]["text"] = rows[-1]["text"].replace(" 下一扇门开了。你要继续追，还是去荒原加演？", "") + " 下一扇门开了。你要继续追，还是去荒原加演？"
            for option in rows[-1].get("choices", []):
                if option.get("result") == "continue_campaign":
                    option["text"] = "继续往里追，我要找那个给我们写剧本的人。"
                    option["response"] = "好。下一道门我陪你进，别把回来的路忘了。"
                else:
                    option["text"] = "去无尽荒原吧，换个地方打破它的剧本。"
                    option["response"] = "荒原？那就换个舞台，别忘了把队伍带齐。"
                option["response_speaker"] = rows[-1]["speaker"]
                option["response_portrait"] = rows[-1]["portrait"]
        for row in rows:
            for option in row.get("choices", []):
                if key == "mode1_won":
                    option["text"] = ("继续追进去，我想知道谁把我们卷进来了。" if option.get("result") == "continue_campaign" else "带着现在的队伍去荒原加演，怎么样？")
                elif key == "branch_sylphiette":
                    option["text"] = ("你守住队伍，我去核实求救信号。" if option.get("result") == "bond_guard" else "我们一起去，但先约好撤回的时间。")
                response = str(option.get("response", ""))
                if "：" in response:
                    option["response"] = response.rsplit("：", 1)[1]
                if option.get("response_speaker") in ("你", "旅行者", "旁白"):
                    option["response_speaker"] = row["speaker"]
                    option["response_portrait"] = row["portrait"]
    stage_lines = {
        "mode1_stage2_opening": [
            "门从里面锁上了。很周到，怕我们临阵退票。",
            "左右两路同时来。我有个冒昧的建议：先活着，再评价门锁的品味。",
            "好。从这一拍开始，怪物负责跑错节奏，我们负责让它们停下来。",
        ],
        "mode1_stage3_opening": [
            "这母巢的走廊连后台都绕晕了。你站这么近，是想替我挡怪，还是想抢我的台词？",
            "结晶的位置每过一关就变一次。我教学生算过概率，可没教过概率本人作弊。",
            "那就给它一场没排练过的演出。诸位，记得给自己留谢幕的路。",
        ],
        "mode1_stage4_opening": [
            "这里每条路都问我想留下谁。真奇怪，我明明没买过单程票。",
            "风已经把回程标好了。要是你迷路，我就把你的名字喊成导航语音。",
        ],
        "mode1_stage5_opening": [
            "地砖快被烤成补丁了。我带了针，谁带灭火器？",
            "没有灭火器。先别踩发亮的裂缝；我不想给你的靴子上补习班。",
        ],
        "mode1_stage6_opening": [
            "钟楼把昨天的报时又放了一遍。连时间都在申请返场费。",
            "返场是我的工作！它再抢拍，我就给它一张差评票。",
        ],
        "mode1_stage7_opening": [
            "我的手指冻得像能弹钢琴了。问题是我根本不会弹。大家先检查有没有冻伤。",
            "我能治冻伤，治不了冲动。你要冲之前，先让我知道去哪儿接你。",
        ],
        "mode1_stage8_opening": [
            "天黑得像有人把亮度调到零。水晶还亮着，说明不是我们欠了电费。",
            "最后一关。请别对系统表演英勇牺牲，它买不起我们的演出。",
            "谢幕以后一起回家吃点心。谁缺席，我就把他的那份吃掉。",
        ],
        "mode1_stage2_won": ["门又开了。要追进去，还是去荒原练习如何跟门讲道理？"],
        "mode1_stage3_won": ["母巢终于谢幕。下一幕在门里，荒原也在招手；你想先去哪儿？"],
        "mode1_stage4_won": ["这次真的有第三条路。下一扇门和荒原，你想先听谁唱？"],
        "mode1_stage5_won": ["熔炉停了，我的针还没用完。下一扇门还是荒原，哪边更需要补？"],
        "mode1_stage6_won": ["钟声终于肯闭嘴了。门与荒原都在等下一拍，你来起头。"],
        "mode1_stage7_won": ["冰路融开了。门已经开着，荒原也不远；你想先去哪儿？"],
    }
    for scene_key, texts in stage_lines.items():
        assert len(result[scene_key]) == len(texts)
        for line, line_text in zip(result[scene_key], texts):
            line["text"] = line_text
    return result


def write(name, data):
    (DATA / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    assert len(HOME) == 65, len(HOME)
    write("home_stories.json", build_home())
    write("story.json", build_story())
    print("rewrote 65 home scenes and 25 campaign scenes")
