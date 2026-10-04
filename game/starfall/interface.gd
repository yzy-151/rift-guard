extends Control
## Native Controls: all actions go through signals; no combat state is mutated here.
signal action(name: String, value: Variant)

const Catalog = preload("res://starfall/catalog.gd")
const Glyph = preload("res://starfall/glyph.gd")
const INK = Color("10192d")
const PANEL = Color("18263e")
const GOLD = Color("efcf88")
const WHITE = Color("f1f2ee")
const MUTED = Color("9eafc5")
const MINT = Color("81e0c5")
const CORAL = Color("ef809b")
var page := ""
var mode := "campaign"
var squad: Array = ["traveler", "hero_03", "hero_08"]
var selected_info := "traveler"
var root: Control
var hud: Control
var overlay: Control
var labels: Dictionary = {}
var bars: Dictionary = {}
var hero_buttons: Array[Button] = []
var notice: Label
var notice_time := 0.0
var font: SystemFont = SystemFont.new()
var title_font: Font = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
var display_font: Font = preload("res://assets/helltaker/fonts/CrimsonPro-Medium.ttf")
var theme_resource: Theme
var draft_serial := 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	theme_resource = Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 18
	theme_resource.set_color("font_color", "Label", WHITE)
	theme_resource.set_color("font_color", "Button", WHITE)
	theme = theme_resource
	root = _layer("Pages")
	hud = _layer("BattleHUD")
	overlay = _layer("Modal")
	notice = _label(self, "", Rect2(350, 125, 580, 48), 25, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.visible = false

func _layer(node_name: String) -> Control:
	var c := Control.new()
	c.name = node_name
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c

func _clear(c: Control) -> void:
	for child in c.get_children():
		c.remove_child(child)
		child.queue_free()

func style(bg: Color, border: Color = Color("3a4c64"), radius: int = 16, width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.015, 0.025, 0.06, 0.32)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 4)
	return s

func _panel(parent: Node, rect: Rect2, bg: Color = PANEL, border: Color = Color("3a4c64"), radius: int = 16) -> Panel:
	var p := Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.add_theme_stylebox_override("panel", style(bg, border, radius))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p

func _label(parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.position = rect.position
	l.size = rect.size
	l.add_theme_font_size_override("font_size", font_size)
	if font_size >= 32:
		l.add_theme_font_override("font", title_font)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _body(parent: Node, text: String, rect: Rect2, font_size: int = 18, color: Color = MUTED) -> Label:
	var l := _label(parent, text, rect, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return l

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, accent: Color = MINT, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.position = rect.position
	b.size = rect.size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 21 if primary else 18)
	b.add_theme_color_override("font_color", INK if primary else WHITE)
	b.add_theme_color_override("font_hover_color", INK if primary else accent)
	b.add_theme_color_override("font_pressed_color", INK if primary else WHITE)
	b.add_theme_color_override("font_focus_color", INK if primary else accent)
	b.add_theme_stylebox_override("normal", style(accent if primary else PANEL, accent if primary else Color("42546f"), 12))
	b.add_theme_stylebox_override("hover", style(accent.lightened(0.13) if primary else Color("263c57"), accent, 12, 2))
	b.add_theme_stylebox_override("pressed", style(accent.darkened(0.1) if primary else Color("334761"), accent, 12))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), GOLD, 12, 2))
	b.add_theme_stylebox_override("disabled", style(Color("182235"), Color("2a364b"), 12))
	b.pressed.connect(func():
		action.emit("ui_click", null)
		callback.call())
	b.mouse_entered.connect(func():
		b.pivot_offset = b.size / 2.0
		var tween := b.create_tween()
		tween.tween_property(b, "scale", Vector2.ONE * 1.025, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.14))
	parent.add_child(b)
	return b

func _portrait(parent: Node, id: String, rect: Rect2, alpha: float = 1.0) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var path := "res://assets/characters/sequences/%s/portrait.png" % id
	if ResourceLoader.exists(path):
		t.texture = load(path)
	t.position = rect.position
	t.size = rect.size
	t.modulate.a = alpha
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t

func _bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.position = rect.position
	b.size = rect.size
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := style(Color("0b1426"), Color("34465e"), 3)
	var fill := style(color, color, 3, 0)
	for box in [background,fill]:
		box.content_margin_left = 0
		box.content_margin_right = 0
		box.content_margin_top = 0
		box.content_margin_bottom = 0
		box.shadow_size = 0
	b.add_theme_stylebox_override("background", background)
	b.add_theme_stylebox_override("fill", fill)
	b.custom_minimum_size = Vector2.ZERO
	b.size = rect.size
	parent.add_child(b)
	b.size = rect.size
	return b

func _veil(parent: Node, alpha: float = 0.76) -> void:
	var c := ColorRect.new()
	c.color = Color(0.027, 0.046, 0.088, alpha)
	c.size = Vector2(1280,720)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(c)

func show_title(records: Dictionary) -> void:
	page = "title"
	_clear(root)
	_clear(overlay)
	hud.hide()
	root.show()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.035,0.065,0.12,0.96), Color(0.035,0.065,0.12,0.82), Color(0.035,0.065,0.12,0.0)])
	gradient.offsets = PackedFloat32Array([0.0,0.46,1.0])
	var gt := GradientTexture2D.new()
	gt.gradient = gradient
	gt.fill_from = Vector2.ZERO
	gt.fill_to = Vector2(1,0)
	var shade := TextureRect.new()
	shade.texture = gt
	shade.size = Vector2(1000,720)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_label(root, "✦  S T A R F A L L  C H R O N I C L E S", Rect2(76,76,620,28), 17, GOLD)
	_label(root, "裂隙守望", Rect2(70,140,650,108), 82, WHITE)
	var en := _label(root, "RIFT GUARD", Rect2(79,247,440,42), 33, GOLD)
	en.add_theme_font_override("font", display_font)
	_label(root, "夜幕降临，星光未眠。", Rect2(80,309,520,34), 24, WHITE)
	_body(root, "召集三位同行者，守住最后一座月泉。\n在每一次选择中，点亮属于你的战斗流派。", Rect2(80,359,500,65), 19, MUTED)
	_button(root, "开启星夜远征    →", Rect2(80,458,320,66), func(): show_party("campaign"), GOLD, true)
	_button(root, "无尽回响", Rect2(80,543,152,48), func(): show_party("endless"), MINT)
	_button(root, "设置", Rect2(248,543,152,48), func(): action.emit("settings", "title"))
	_label(root, "远征胜利  %d    /    无尽最高  %d 波" % [int(records.get("wins",0)), int(records.get("best_wave",0))], Rect2(80,626,480,28), 16, MUTED)
	_button(root, "返回主菜单", Rect2(1040,628,160,40), func(): action.emit("legacy", null), MUTED)
	_label(root, "星夜守望", Rect2(1020,76,185,30), 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(root, "WASD 移动 · Q / E 技能 · Shift 闪避", Rect2(730,674,490,24), 15, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	root.modulate.a = 0.0
	create_tween().tween_property(root,"modulate:a",1.0,0.45)

func show_party(selected_mode: String) -> void:
	mode = selected_mode
	page = "party"
	_clear(root)
	_clear(overlay)
	root.show()
	_veil(root, 0.88)
	_label(root,"同行者",Rect2(52,33,400,58),40,WHITE)
	_label(root,"选择三位伙伴，让不同的元素彼此呼应。",Rect2(55,93,790,32),19,MUTED)
	_button(root,"← 返回",Rect2(1080,48,145,43),func():action.emit("title",null))
	var roster: Array = Catalog.heroes()
	for i in range(roster.size()):
		var h: Dictionary = roster[i]
		var id: String = h.id
		var x := 54.0 + (i % 5) * 164.0
		var y := 151.0 + floori(i/5.0) * 199.0
		var col: Color = h.color
		var chosen := squad.has(id)
		var card := _button(root,"",Rect2(x,y,150,183),func():
			selected_info = id
			if squad.has(id): squad.erase(id)
			elif squad.size()<3: squad.append(id)
			else: toast("已选满三人，先取消一位伙伴")
			show_party(mode), col)
		card.tooltip_text = str(h.description) + "\nQ：" + str(h.q_name) + "\nE：" + str(h.e_name)
		if chosen:
			card.add_theme_stylebox_override("normal",style(Color("253b52"),col,14,2))
		_portrait(card,id,Rect2(10,6,130,128),1.0 if chosen else 0.77)
		_label(card,str(h.name),Rect2(5,132,140,28),20,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
		_label(card,"%d  已编入" % (squad.find(id)+1) if chosen else str(h.title),Rect2(5,159,140,20),13,col,HORIZONTAL_ALIGNMENT_CENTER)
	var h: Dictionary = Catalog.hero(selected_info)
	_panel(root,Rect2(905,150,320,389),Color("142138"),Color("4f6179"),20)
	_label(root,str(h.name),Rect2(930,173,270,48),32,h.color)
	_label(root,str(h.title),Rect2(931,222,260,25),17,GOLD)
	_body(root,str(h.description),Rect2(931,260,267,60),17,MUTED)
	_label(root,"Q  " + str(h.q_name),Rect2(931,327,270,30),20,WHITE)
	_body(root,str(h.q_desc),Rect2(931,363,263,50),16,MUTED)
	_label(root,"E  " + str(h.e_name),Rect2(931,426,270,30),20,WHITE)
	_body(root,str(h.e_desc),Rect2(931,462,263,56),16,MUTED)
	_panel(root,Rect2(54,575,1171,98),Color("152239"),Color("40546b"))
	_label(root,"星夜远征  /  三幕 · 九波 · 首领战" if mode=="campaign" else "无尽回响  /  随波次成长的裂隙",Rect2(77,589,760,29),23,GOLD)
	_label(root,"自动普攻  ·  1 / 2 / 3 切换领队  ·  Q 技能 / E 终结技  ·  Shift 闪避",Rect2(77,632,795,25),16,MUTED)
	var launch := _button(root,"出发  %d / 3   →" % squad.size(),Rect2(985,594,216,60),func():action.emit("start",{"mode":mode,"squad":squad.duplicate()}),MINT,true)
	launch.disabled = squad.size()!=3

func build_hud(sim) -> void:
	page = "battle"
	root.hide()
	_clear(overlay)
	_clear(hud)
	labels.clear()
	bars.clear()
	hero_buttons.clear()
	hud.show()
	_panel(hud,Rect2(22,20,278,83),Color(0.05,0.085,0.15,0.94),Color("435875"),15)
	_label(hud,"✦ 月泉",Rect2(39,28,130,30),22,GOLD)
	labels.core = _label(hud,"",Rect2(160,31,123,24),16,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	bars.core = _bar(hud,Rect2(40,68,242,10),MINT)
	_panel(hud,Rect2(472,20,336,80),Color(0.05,0.085,0.15,0.93),Color("53637a"),18)
	labels.wave = _label(hud,"",Rect2(480,29,320,27),21,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	labels.time = _label(hud,"",Rect2(480,62,320,23),15,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	labels.stats = _label(hud,"",Rect2(957,23,214,29),18,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	_button(hud,"Ⅱ",Rect2(1200,20,54,45),func():action.emit("pause",null),GOLD)
	labels.combo = _label(hud,"",Rect2(985,64,264,44),30,MINT,HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(sim.heroes.size()):
		var h: Dictionary = sim.heroes[i]
		var id: String = h.character_id
		var col: Color = Catalog.hero(id).color
		var x := 22.0+i*151.0
		var b := _button(hud,"",Rect2(x,594,140,91),func():action.emit("select",i),col)
		hero_buttons.append(b)
		_portrait(b,id,Rect2(0,-11,69,91))
		_label(b,str(i+1),Rect2(5,4,19,20),14,GOLD)
		_label(b,str(h.name),Rect2(66,10,73,25),15,WHITE)
		bars["hp%d"%i] = _bar(b,Rect2(66,45,60,6),col)
		bars["energy%d"%i] = _bar(b,Rect2(66,61,60,4),GOLD)
		labels["hp%d"%i] = _label(b,"",Rect2(65,69,65,15),11,MUTED)
	_panel(hud,Rect2(906,590,349,95),Color(0.05,0.085,0.15,0.95),Color("425875"),16)
	for i in range(3):
		var key: String = ["q","e","dash"][i]
		var b := _button(hud,"",Rect2(918+i*109,600,100,74),func():action.emit(key,null),[MINT,GOLD,WHITE][i])
		labels[key] = _label(b,"",Rect2(0,8,100,30),22,[MINT,GOLD,WHITE][i],HORIZONTAL_ALIGNMENT_CENTER)
		labels[key+"_name"] = _label(b,"",Rect2(3,45,94,20),13,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	labels.hint = _label(hud,"WASD 移动  ·  右键移动  ·  自动普攻",Rect2(498,650,385,28),15,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	labels.level = _label(hud,"",Rect2(503,605,380,34),20,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	bars.xp = _bar(hud,Rect2(22,700,1233,5),GOLD)
	labels.boss = _label(hud,"",Rect2(460,107,360,25),18,CORAL,HORIZONTAL_ALIGNMENT_CENTER)
	bars.boss = _bar(hud,Rect2(490,138,300,7),CORAL)
	update_hud(sim)

func update_hud(sim) -> void:
	if not hud.visible or labels.is_empty(): return
	bars.core.value = sim.core_hp / sim.max_core_hp * 100.0
	labels.core.text = "%d / %d" % [sim.core_hp,sim.max_core_hp]
	var act: int = mini(3,ceili(sim.wave/3.0))
	labels.wave.text = "%s  ·  第 %d 波" % [["月泉初醒","深夜来客","长夜将明"][act-1] if sim.mode=="campaign" else "无尽回响",sim.wave]
	labels.time.text = "%02d:%02d   /   %s" % [int(sim.time)/60,int(sim.time)%60,"首领来袭" if sim.wave%3==0 else "下一波 %02ds" % maxi(0,ceili(sim.wave_duration-sim.wave_time))]
	labels.stats.text = "星币 %d    击破 %d" % [sim.coins,sim.kills]
	labels.combo.text = "%d 连击" % sim.combo if sim.combo>=5 else ""
	bars.xp.value = sim.xp / maxf(1.0,sim.xp_needed) * 100.0
	labels.level.text = "✦  Lv.%d   星屑 %d / %d" % [sim.level,sim.xp,sim.xp_needed]
	for i in range(sim.heroes.size()):
		var h: Dictionary = sim.heroes[i]
		bars["hp%d"%i].value = h.hp/h.max_hp*100.0
		bars["energy%d"%i].value = h.energy
		labels["hp%d"%i].text = "%d/%d" % [h.hp,h.max_hp] if h.hp>0 else "倒下"
		hero_buttons[i].modulate.a = 1.0 if i==sim.selected else 0.68
	var h: Dictionary = sim.heroes[sim.selected]
	var def: Dictionary = Catalog.hero(h.character_id)
	labels.q.text = "Q  %0.1f" % h.q_cd if h.q_cd>0 else "Q  就绪"
	labels.q_name.text = str(def.q_name)
	labels.e.text = "E  %d%%" % h.energy if h.energy<100 else "E  满盈"
	labels.e_name.text = str(def.e_name)
	labels.dash.text = "%0.1fs" % h.dash_cd if h.dash_cd>0 else "Shift"
	labels.dash_name.text = "闪避"
	var boss: Dictionary = {}
	for e in sim.enemies:
		if e.kind=="boss_01" and e.hp>0: boss = e; break
	labels.boss.visible = not boss.is_empty()
	bars.boss.visible = not boss.is_empty()
	if not boss.is_empty():
		labels.boss.text = "裂隙统领  ·  %d%%" % int(boss.hp / boss.max_hp * 100.0)
		bars.boss.value = boss.hp / boss.max_hp * 100.0

func show_draft(sim) -> void:
	page = "upgrade"
	_clear(overlay)
	_veil(overlay)
	_label(overlay,"拾起一颗星，改变下一场战斗。",Rect2(180,73,920,58),35,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"星屑共鸣  /  等级 %d  /  选择一项，本局持续生效" % sim.level,Rect2(200,132,880,30),18,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	for i in range(sim.upgrade_choices.size()):
		var u: Dictionary = sim.upgrade_choices[i]
		var color: Color = u.get("color",MINT)
		var x := 195.0 + 305.0*i
		var card := _button(overlay,"",Rect2(x,212,280,328),func():action.emit("upgrade",str(u.id)),color)
		_panel(card,Rect2(91,29,98,98),Color("243951"),color,49)
		var emblem := Glyph.new()
		emblem.icon = str(u.get("icon","star"))
		emblem.color = color
		emblem.position = Vector2(98,36)
		emblem.size = Vector2(84,84)
		card.add_child(emblem)
		_label(card,str({"common":"星辉祝福","rare":"月华祝福","epic":"星辰奇迹"}.get(u.get("rarity","common"),"星辉祝福")),Rect2(15,137,250,26),14,color,HORIZONTAL_ALIGNMENT_CENTER)
		_label(card,str(u.name),Rect2(14,177,252,39),27,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
		_body(card,str(u.description),Rect2(28,232,224,69),18,MUTED)
		card.modulate.a = 0.0
		var target := card.position
		card.position.y += 22
		var tween := create_tween().set_parallel(true)
		tween.tween_property(card,"modulate:a",1.0,0.3).set_delay(i*0.07)
		tween.tween_property(card,"position",target,0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i*0.07)
	_button(overlay,"重绘星象  ↻",Rect2(498,587,284,50),func():action.emit("reroll",null),GOLD)
	_label(overlay,"每次选择可重绘一次  ·  点击星卡确认",Rect2(315,653,650,25),16,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func close_modal() -> void:
	_clear(overlay)
	page = "battle"

func show_loading() -> void:
	page = "loading"
	_clear(overlay)
	_veil(overlay,0.84)
	_label(overlay,"✦",Rect2(560,246,160,82),64,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"点亮月泉…",Rect2(390,349,500,54),34,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"同行者正在集合",Rect2(390,414,500,30),19,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func show_pause() -> void:
	page = "pause"
	_clear(overlay)
	_veil(overlay,0.65)
	_panel(overlay,Rect2(443,143,394,438),Color("142138"),Color("718092"),23)
	_label(overlay,"星光暂歇",Rect2(480,178,320,60),38,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"深呼吸，月泉仍在等你。",Rect2(472,243,336,28),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_button(overlay,"继续守望",Rect2(493,308,294,57),func():action.emit("resume",null),GOLD,true)
	_button(overlay,"设置",Rect2(493,383,294,50),func():action.emit("settings","pause"))
	_button(overlay,"结束本局，返回营地",Rect2(493,452,294,50),func():action.emit("abandon",null),CORAL)
	_label(overlay,"Esc / Space 继续",Rect2(493,527,294,26),15,MUTED,HORIZONTAL_ALIGNMENT_CENTER)

func show_settings(settings: Dictionary, origin: String) -> void:
	page = "settings"
	_clear(overlay)
	_veil(overlay,0.8)
	_panel(overlay,Rect2(350,85,580,550),Color("142138"),Color("61738a"),24)
	_label(overlay,"旅途偏好",Rect2(388,113,490,60),37,WHITE)
	_label(overlay,"音量",Rect2(390,197,240,34),21,GOLD)
	var slider := HSlider.new()
	slider.position = Vector2(390,252)
	slider.size = Vector2(495,24)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = settings.get("volume",65)
	overlay.add_child(slider)
	slider.value_changed.connect(func(v):action.emit("setting",{"key":"volume","value":v}))
	var toggles := [["reduced_fx","简化特效","减少粒子与闪光，保留攻击预警"],["shake","镜头震动","受击、重击与终结技的力度反馈"],["fullscreen","全屏显示","也可以按 F11 随时切换"]]
	for i in range(toggles.size()):
		var row: Array = toggles[i]
		var check := CheckButton.new()
		check.position = Vector2(386,309+i*76)
		check.size = Vector2(500,32)
		check.text = str(row[1])
		check.button_pressed = bool(settings.get(row[0],false))
		check.add_theme_color_override("font_color",WHITE)
		check.toggled.connect(func(v): action.emit("setting",{"key":str(row[0]),"value":v}))
		overlay.add_child(check)
		_label(overlay,str(row[2]),Rect2(392,342+i*76,490,25),15,MUTED)
	_button(overlay,"保存并返回",Rect2(609,562,278,45),func():action.emit("settings_back",origin),GOLD,true)

func show_result(sim, record: bool) -> void:
	page = "result"
	_clear(overlay)
	_veil(overlay,0.82)
	var won: bool = sim.phase=="won"
	_label(overlay,"✦",Rect2(560,48,160,84),64,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"今夜，星光长明。" if won else "星光未灭，再赴长夜。",Rect2(170,134,940,66),44,WHITE,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"远征完成" if won else "守望结束",Rect2(200,207,880,34),23,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	_panel(overlay,Rect2(265,283,750,217),Color("192a42"),Color("65758a"),23)
	var values: Array = ["%02d:%02d"%[int(sim.time)/60,int(sim.time)%60],str(sim.kills),str(sim.wave),str(sim.best_combo)]
	var names: Array = ["守望时间","击破敌人","抵达波次","最高连击"]
	for i in range(4):
		_label(overlay,values[i],Rect2(289+i*179,316,160,63),42,GOLD if i==2 else WHITE,HORIZONTAL_ALIGNMENT_CENTER)
		_label(overlay,names[i],Rect2(289+i*179,385,160,30),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_label(overlay,"新的无尽纪录" if record else "星币 %d  ·  共鸣等级 %d  ·  %d 种祝福" % [sim.coins,sim.level,sim.upgrades.size()],Rect2(298,447,683,27),18,MINT,HORIZONTAL_ALIGNMENT_CENTER)
	_button(overlay,"再次出发",Rect2(375,546,250,62),func():action.emit("retry",null),GOLD,true)
	_button(overlay,"返回营地",Rect2(653,546,250,62),func():action.emit("title",null),MINT)

func toast(text: String) -> void:
	notice.text = text
	notice.visible = true
	notice_time = 2.5
	notice.modulate.a = 1.0

func _process(dt: float) -> void:
	if notice_time>0:
		notice_time -= dt
		notice.modulate.a = minf(1.0,notice_time*2.0)
		if notice_time<=0: notice.hide()
