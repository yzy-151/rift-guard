"""Prepare the Amiya / eight-visible-stages revision, retaining authored branches."""
import json, shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
G = ROOT / 'game'
QA = ROOT / 'qa/release-20261106-r2'
QA.mkdir(exist_ok=True)

def read(p): return json.loads((G / p).read_text(encoding='utf8'))
def save(p, value): (G / p).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
def replace(p, old, new):
    path = ROOT / p
    text = path.read_text(encoding='utf8')
    assert old in text, (p, old[:80])
    path.write_text(text.replace(old, new), encoding='utf8')

src = Path('C:/Users/23081/.codex/generated_images/01a07077-c74f-78e1-b26b-a99f36054fcf')
art = G / 'assets/ui/release_20261106'
shutil.copy2(src/'exec-3d0f7694-37e1-415a-9047-519e6c94bdaf.png', art/'icon.png')
shutil.copy2(src/'exec-75ecc709-0328-4537-a7ce-6c45d7835831.png', art/'splash.png')
# File-format conversion for Windows icon resources; no image content edits.
Image.open(art/'icon.png').save(art/'icon.ico', sizes=[(s,s) for s in [16,24,32,48,64,128,256]])
modes = read('data/v2/modes.json')
modes[0]['display_stage_ids'] = ['stage_%02d'%i for i in range(1,9)]
save('data/v2/modes.json', modes)

replace('game/scripts/stage_select_panel.gd', 'var ids: Array = database.modes.get("rift_watch", {}).get("stage_ids", [])\n\tfor i', 'var mode: Dictionary = database.modes.get("rift_watch", {})\n\tvar ids: Array = mode.get("display_stage_ids", mode.get("stage_ids", []))\n\tfor i')
replace('game/scripts/stage_select_panel.gd', 'Vector2(150 + col * 335, 210 + row * 310)', 'UI_LAYOUT.mission_stage_grid_origin + Vector2(col, row) * UI_LAYOUT.mission_stage_grid_step')
replace('game/scripts/stage_select_panel.gd', 'Vector2(1.15, 1.15)', 'UI_LAYOUT.mission_stage_card_scale')
replace('game/scripts/stage_select_panel.gd', '"🔒  LOCKED", 18', '"暂未开放" if _is_release_locked(id) else "尚未解锁", 18')
replace('game/scripts/stage_select_panel.gd', '"出发剧情   →", 11', '"后续章节 · 敬请期待" if _is_release_locked(id) else "出发剧情   →", 11')
replace('game/scripts/stage_select_panel.gd', 'Color(0.36,0.34,0.36,1)', 'Color(0.68,0.65,0.68,1)')
replace('game/scripts/stage_select_panel.gd', 'Color(0.42,0.39,0.42,1)', 'Color(0.68,0.65,0.68,1)')
replace('game/scripts/stage_select_panel.gd', 'if not unlocked: status.text = "档案封锁 · 先通关前一区域"', 'if _is_release_locked(id): status.text = "试玩区域外 · 本版本不可解锁"\n\t\telif not unlocked: status.text = "档案封锁 · 先通关前一区域"')
replace('game/scripts/stage_select_panel.gd', 'func _is_unlocked(id: String) -> bool:', 'func _is_release_locked(id: String) -> bool:\n\treturn id != "stage_endless" and id not in database.modes.get("rift_watch", {}).get("stage_ids", [])\n\nfunc _is_unlocked(id: String) -> bool:')
replace('game/data/ui_layout_profile.tres', 'mission_release_notice_rect = Rect2(190, 550, 930, 68)', 'mission_release_notice_rect = Rect2(62, 664, 1156, 50)')
replace('game/data/ui_layout_profile.tres', 'mission_roster_rect = Rect2(190, 143, 930, 48)', 'mission_roster_rect = Rect2(62, 112, 1156, 48)')
replace('game/scripts/rift_ui_layout_profile.gd', '@export var mission_release_notice_rect', '@export var mission_stage_grid_origin := Vector2(50, 164)\n@export var mission_stage_grid_step := Vector2(300, 248)\n@export var mission_stage_card_scale := Vector2(0.92, 0.92)\n@export var mission_release_notice_rect')
replace('game/scripts/release_boot.gd', '世界裂开了，队友倒是凑齐了。', '门后是冒险，还是另一份加班？')

stories = read('data/authored_story.json')
# Keep the author's jokes, portraits, links, unlocks and bad ends intact.
polish = {
 'n_muqzf5le_zgmfr':'嗯？旅行者？你也是找厕所时推错了门，然后发现门没了吗？',
 'n_mutxol0a_6894t':'我在附近只找到这把水壶。来都来了，先烧点水——总不能连热水都没有吧。',
 'n_mutxph0w_obciu':'怎么样，来杯开水充充饥？水神亲自烧的。',
 'n_mutxv2cs_bf6ya':'我当然爱干净……等等，你夸的是我，还是这壶水？',
 'n_mutxwqwn_39ol7':'算了，先一起找出口。那颗水晶像个路标，别让怪物拆了——还有，看到厕所记得叫我。',
 'n_mutxyjmv_doe21':'竟敢拒绝水神亲手烧的水！这段不算，重来！',
 'n_mutx6u50_9jzk3':'嗯？黄毛。刚才忙着剪怪物，还没来得及问：你是哪条路的？',
 'n_muty7h17_n5pa3':'我正好缺个射手。你是伊泽瑞尔？伊？泽？瑞？尔？',
 'n_mutya5su_z2m2m':'走就走。先说好，我刚才只是路过帮忙，现在才算入队。',
 'n_mutyeq1w_dfdvv':'好的，开拓者，我申请入队。名字以后再对，前面有个东西正拿炮瞄我们。'
}
for key in ['mode1_opening', 'mode1_won']:
    for node in stories[key]['nodes']:
        if node['id'] in polish: node['text'] = polish[node['id']]

portraits = read('data/dialogue_portraits.json')['portraits']
def scene(rows, question, options):
    def line(id, speaker, expression, text, next):
        return dict(id=id,type='line',speaker=speaker,expression=expression,portrait=portraits[speaker][expression],text=text,next=next)
    nodes=[line('l'+str(i),*row,'l'+str(i+1) if i<len(rows)-1 else 'pick') for i,row in enumerate(rows)]
    speaker,expression,text=question
    nodes.append(dict(id='pick',type='choice',speaker=speaker,expression=expression,portrait=portraits[speaker][expression],text=text,options=[dict(text=o[0],next='reply'+str(i)) for i,o in enumerate(options)]))
    for i,o in enumerate(options): nodes.append(line('reply'+str(i),speaker,expression,o[1],'done'))
    nodes.append(dict(id='done',type='ending',status='success',note='继续冒险',comics=[]))
    return dict(start='l0',nodes=nodes)
stories['mode1_stage2_opening']=scene([
 ('格温','惊讶','「赤潮回廊，禁止喧哗」。那个扛炮的识字吗？'),
 ('芙宁娜','傲娇','这是第二幕的开场礼炮。只要我们走得够快，它就算欢送。'),
 ('格温','羞恼','它转过来了。现在算追悼。'),
 ('芙宁娜','思考','先守住水晶。植物摆开，队伍散开……水壶放哪儿比较安全？')],
 ('格温','羞恼','你真打算一路拎着它？'),[
 ('当然。打完还得喝口热的。','行，那就一起保住它。我们这支队伍，总得有一个真正的输出是热水。'),
 ('放我身后，别让它抢前排。','好。坚果顶前面，水壶当后勤。别把这两个岗位弄反了。')])
stories['mode1_stage2_won']=scene([
 ('格温','惊讶','炮停了，水壶也还在。我们到底是在护送谁？'),
 ('芙宁娜','傲娇','当然是大家。只不过水壶从头到尾没有抱怨，是位优秀的队员。'),
 ('格温','羞恼','那给它发工资。前面的路通了——怎么还有狼叫？'),
 ('芙宁娜','思考','一只羊、一只狼。旁边那尊石像刚才是不是动了一下？')],
 ('格温','惊讶','出口就在它们后面。还走吗？'),[
 ('都把水烧开了，总得喝完这趟。','有道理，但别烫得上头。下一关重新选卡，先把队伍配好。'),
 ('走。听见狼叫，总比听见催稿强。','你负责看路，我负责剪挡路的。至于那尊石像……先别站它正下面。')])
stories['mode1_stage3_opening']=scene([
 ('格温','惊讶','那只羊身边跟着狼。这地方连宠物关系都很复杂。'),
 ('芙宁娜','思考','千珏。看见窄射线就让路，不要三个人排成一串给它练箭。'),
 ('格温','羞恼','你刚才说的石像呢？'),
 ('芙宁娜','惊讶','加里奥……在上面！它和千珏是一伙的。地上亮起大范围预警，就赶紧挪开！')],
 ('格温','羞恼','还有什么贵重物品需要我照看？'),[
 ('我。活着的旅行者很贵。','知道了。你先学会躲，我尽量不让你变成售后问题。'),
 ('水壶。它还没发过工资。','行。你守水晶，我找机会剪它们，水壶继续保持情绪稳定。')])
stories['mode1_final_won']=scene([
 ('格温','惊讶','羊不射箭了，石像也落稳了。谁去问问它们让不让路？'),
 ('芙宁娜','思考','不用问。门上写着：「后续区域暂未开放」。下面还有小字。'),
 ('格温','羞恼','「请勿用剪刀提前解锁」。这告示是不是刚贴的？'),
 ('芙宁娜','傲娇','那就暂时谢幕！三个人、一颗水晶、一壶热水，全部安全撤场。')],
 ('格温','羞恼','后面的路先记着。现在回去，还是去无尽模式再打一会儿？'),[
 ('回去喝茶。这壶水都等三关了。','好。这回你找杯子，我看着门。别又一推就推到别的游戏里。'),
 ('牌都凑好了，我还没打够。','那就去无尽。下一页选携带构筑，水壶也算加班——但别指望它替你输出。')])
save('data/authored_story.json', stories)
comics=read('data/campaign_comics.json')
comics['mode1_opening'][2]['text']='你的房间里多了一道裂隙。\n你确认了一眼：这次不是房东装修。然后还是推开了门。'
comics['mode1_opening'][3]['text']='门不见了。好消息是，迷路的似乎不止你一个。'
comics['mode1_opening'][4]['text']='一位自称水神的少女提着烧水壶。\n出口还没找到，热水倒是有了。'
comics['mode1_won'][0]['text']='黏糊糊的怪物终于倒下。\n你检查了披风，决定把清洗问题留给明天的自己。'
comics['mode1_won'][1]['text']='刚才在场上帮忙的裁缝，已经先一步等在出口。\n她看了看你的黄头发，似乎认错了人。'
comics['mode1_stage2_opening'][0]['text']='格温正式入队，三个人终于凑齐。\n前面的牌子写着「禁止喧哗」，牌子后面有人架起了炮。'
comics['mode1_stage2_won'][0]['text']='炮声停下，通往深处的路露了出来。\n远处的狼嚎提醒你：安静只是换班，不是下班。'
comics['mode1_stage3_opening'][0]['text']='出口前，一只羊和一只狼挡住了去路。\n头顶的影子越来越大，水壶里荡起一圈涟漪。'
comics['mode1_final_won'][0]['text']='水晶还亮着，三个人也都还在。\n更深处的门暂时封闭。至少这次，门没有凭空消失。'
for key in ['mode1_opening','mode1_won']:
    for original in stories[key].get('comics',[]):
        for page in comics[key]:
            if original['image']==page['image']: original['text']=page['text']
save('data/authored_story.json',stories)
save('data/campaign_comics.json',comics)
replace('game/project.godot','2026.11.6.1','2026.11.6.2')
replace('game/export_presets.cfg','2026.11.6.1','2026.11.6.2')
replace('game/export_presets.cfg','version/code=20261106','version/code=20261107')
replace('game/export_presets.cfg','builds/release-20261106/','builds/release-20261106-r2/')
for filename in ['export_three_chapter_release.py','configure_release_exports.py']:
    path=ROOT/'tools'/filename
    text=path.read_text(encoding='utf8').replace('qa/release-20261106','qa/release-20261106-r2').replace('builds/release-20261106','builds/release-20261106-r2').replace('2026.11.6.1','2026.11.6.2')
    if filename=='configure_release_exports.py':text=text.replace("version/code=20261106'","version/code=20261107'")
    path.write_text(text,encoding='utf8')
(ROOT/'builds/release-20261106-r2').mkdir(exist_ok=True)
print('Revision prepared')
