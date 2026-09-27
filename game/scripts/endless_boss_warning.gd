extends RefCounted
const LAYOUT=preload("res://data/ui_layout_profile.tres")
static func draw(v,seconds:float) -> void:
 var age:=10.0-seconds
 var pulse:=0.5+0.5*sin(age*TAU*(1.0 if seconds>3 else 2.0))
 var area:Rect2=LAYOUT.battle_expedition_warning_rect
 var enter:=clampf(age/0.22,0,1)
 var intro:=clampf(1.0-age/1.1,0,1)
 # One dark red impact, then edge pulses; the player's combat area stays readable.
 v.draw_rect(Rect2(0,88,1280,490),Color(0.22,0.0,0.035,intro*0.45))
 for i in 5:
  var alpha:=0.035+0.06*pulse
  v.draw_rect(Rect2(i*7,88+i*5,1280-i*14,490-i*10),Color(0.9,0.035,0.07,alpha),false,7)
 var banner:=Rect2(Vector2(640-area.size.x*enter/2,area.position.y),Vector2(area.size.x*enter,area.size.y))
 v.draw_rect(banner,Color(0.035,0.006,0.014,0.94))
 if enter<0.98:return
 v.draw_rect(Rect2(area.position+Vector2(0,12),Vector2(8,area.size.y-24)),Color("ee2948"))
 v.draw_rect(Rect2(area.position+Vector2(area.size.x-8,12),Vector2(8,area.size.y-24)),Color("ee2948"))
 for i in int(area.size.x/28):
  var x:float=area.position.x+i*28+fposmod(age*35,28)
  if x+14>area.end.x:continue
  v.draw_line(Vector2(x,area.position.y+2),Vector2(x+12,area.position.y+11),Color("b72d43"),7)
  v.draw_line(Vector2(x,area.end.y-11),Vector2(x+12,area.end.y-2),Color("b72d43"),7)
 v.caption(area.position+Vector2(28,35),"D A N G E R   /   B O S S   I N C O M I N G",Color("eb5160"),15)
 v.caption(area.position+Vector2(27,82),"首 领 即 将 降 临",Color("ffe8df"),38)
 v.caption(area.position+Vector2(30,107),"高危目标接近  /  立即做好战斗准备",Color("d59a9f"),14)
 var counter:=str(ceili(seconds)).pad_zeros(2)
 v.caption(area.position+Vector2(area.size.x-141,91),counter,Color("ff5267"),70)
 v.draw_line(area.position+Vector2(29,area.size.y-17),area.position+Vector2(29+(area.size.x-215)*seconds/10,area.size.y-17),Color("ed3c57"),3)
