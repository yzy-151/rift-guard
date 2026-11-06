extends CanvasLayer
signal continue_campaign
signal enter_endless
const LAYOUT=preload("res://data/ui_layout_profile.tres")
var root:Control
func build(hud, final_chapter: bool = false):
 layer=60;root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(root)
 var veil=ColorRect.new();veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);veil.color=Color(0.02,0.01,0.04,0.90);root.add_child(veil)
 var frame=hud.panel(root,LAYOUT.stage_clear_choice_rect,Color("17111c"),Color("cf627d"))
 hud.label(frame,Vector2(30,25),Vector2(570,45),"三章完成 · 感谢游玩" if final_chapter else "防线已守住 · 下一步",27,Color.WHITE)
 hud.label(frame,Vector2(30,86),Vector2(570,65),"本次试玩到此结束，后续章节暂未开放。\n可返回主菜单，或携带当前构筑挑战无尽。" if final_chapter else "继续剧情：下一关重新构筑\n转入无尽：保留当前队伍与卡牌，挑战生存极限",17,Color("e4c9d1"))
 var a=hud.button(frame,Rect2(30,177,260,50),"返回主菜单" if final_chapter else "继续关卡",true)
 var b=hud.button(frame,Rect2(310,177,260,50),"携带构筑进入无尽",false)
 a.pressed.connect(func():root.hide();continue_campaign.emit())
 b.pressed.connect(func():root.hide();enter_endless.emit())
func is_open()->bool:return root!=null and root.visible
