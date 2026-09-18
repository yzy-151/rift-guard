extends CanvasLayer

signal confirmed(squad: Array[String])
signal cancelled
const Preview = preload("res://scripts/character_breath_preview.gd")
const CARD_SKIN_RED = preload("res://assets/ui/rift_v2/components/mode_card_red.png")
const CARD_SKIN_GRAY = preload("res://assets/ui/rift_v2/components/mode_card_gray.png")
const BUTTON_SKIN = preload("res://assets/ui/rift_v2/components/button0003.png")
const LEIGAI_FONT = preload("res://assets/fonts/Leigai.ttf")
const WHITE := Color("#f3e9df")
const MUTED := Color("#a69098")
const ACCENT := Color("#ff5668")
const ELEMENT_COLORS := {"none":Color("#e9d7ad"),"anemo":Color("#63e6c0"),"electro":Color("#bf83ff"),"pyro":Color("#ff745c"),"hydro":Color("#5ab8ff"),"geo":Color("#e8b94d"),"cryo":Color("#9de7f2")}

var root: Control
var frame: Panel
var title: Label
var subtitle: Label
var count_label: Label
var confirm_button: Button
var back_button: Button
var buttons: Dictionary = {}
var state_labels: Dictionary = {}
var previews: Dictionary = {}
var card_panels: Dictionary = {}
var card_frames: Dictionary = {}
var grid_scroll: ScrollContainer
var grid_host: Control
var character_order: Array[String] = []
var database
var progress
var hud
var selected: Array[String] = []
var next_stage_id := ""
var detail_panel: Panel
var detail_preview
var detail_name: Label
var detail_role: Label
var detail_stats: VBoxContainer
var detail_skill_title: Label
var detail_skill_body: Label
var detail_ultimate_title: Label
var detail_ultimate_body: Label
var detail_confirm: Button
var detail_close: Button
var detail_id := ""
var select_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer

func build(owner_hud, game_database, state) -> void:
	hud = owner_hud; database = game_database; progress = state; layer = 45
	root = Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.theme = owner_hud.get_child(0).theme; add_child(root)
	var bg := ColorRect.new(); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); bg.color = Color("#08070b"); root.add_child(bg)
	var glow := ColorRect.new(); glow.position = Vector2(0,0); glow.size = Vector2(1280,720); glow.color = Color(0.18,0.015,0.045,0.20); root.add_child(glow)
	frame = Panel.new(); frame.position = Vector2(34,18); frame.size = Vector2(1212,684); frame.add_theme_stylebox_override("panel", _panel_style(Color("#8e4758"),2)); root.add_child(frame)
	hud.label(frame, Vector2(28,16), Vector2(600,18), "P A R T Y   /   裂 隙 编 队", 11, ACCENT)
	title = hud.label(frame, Vector2(28,38), Vector2(720,36), "选择下一关出战角色", 27, WHITE)
	subtitle = hud.label(frame, Vector2(28,76), Vector2(850,20), "旅行者固定出战 · 最多选择三名角色 · 点击卡片查看详情", 12, MUTED)
	count_label = hud.label(frame, Vector2(930,42), Vector2(220,28), "", 16, ACCENT); count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rule := ColorRect.new(); rule.position = Vector2(28,112); rule.size = Vector2(1156,2); rule.color = Color("#9d4657"); frame.add_child(rule)
	grid_scroll = ScrollContainer.new(); grid_scroll.position = Vector2(28,130); grid_scroll.size = Vector2(1156,426); grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO; grid_scroll.clip_contents = true; frame.add_child(grid_scroll)
	grid_host = Control.new(); for id: String in database.characters: character_order.append(id)
	character_order.sort_custom(func(a: String, b: String) -> bool:
		var a_unlocked := _is_character_unlocked(a); var b_unlocked := _is_character_unlocked(b)
		return a_unlocked if a_unlocked != b_unlocked else a.naturalnocasecmp_to(b) < 0)
	var rows := ceili(float(character_order.size()) / 4.0); grid_host.custom_minimum_size = Vector2(1138, rows * 158 + maxi(0,rows-1)*14 + 8); grid_scroll.add_child(grid_host)
	for i in character_order.size(): _build_character_card(character_order[i], i)
	back_button = _button(frame, Rect2(28,588,546,50), "←  返回上一级", true); back_button.pressed.connect(func(): root.hide(); cancelled.emit())
	confirm_button = _button(frame, Rect2(609,588,546,50), "确认编队并进入下一关  →", true); confirm_button.add_theme_font_size_override("font_size",16); confirm_button.pressed.connect(confirm)
	_build_detail()
	select_sound = AudioStreamPlayer.new(); select_sound.stream = preload("res://assets/helltaker/audio/button_chapter_highlight_01.wav"); select_sound.bus="SFX"; select_sound.volume_db=-7; add_child(select_sound)
	confirm_sound = AudioStreamPlayer.new(); confirm_sound.stream = preload("res://assets/helltaker/audio/button_chapter_confirm_01.wav"); confirm_sound.bus="SFX"; confirm_sound.volume_db=-3; add_child(confirm_sound)
	root.hide()

func _build_character_card(id: String, index: int) -> void:
	var data: Dictionary = database.characters[id]; var col := index % 4; var row := int(index / 4)
	var rect := Rect2(Vector2(col*282,row*172),Vector2(268,158)); var item: Button = hud.button(grid_host,rect,"",true); item.position=rect.position; item.size=rect.size; item.name="Squad_"+id
	for s in ["normal","hover","pressed","focus","disabled"]: item.add_theme_stylebox_override(s,StyleBoxEmpty.new())
	buttons[id]=item
	var panel:=Panel.new(); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); item.add_child(panel); card_panels[id]=panel
	var frame_skin:=TextureRect.new()
	frame_skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_skin.texture=CARD_SKIN_GRAY
	frame_skin.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	frame_skin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame_skin.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame_skin.modulate=Color(1,1,1,0.34)
	panel.add_child(frame_skin)
	card_frames[id]=frame_skin
	var element:=str(data.get("element","none")); var color:Color=ELEMENT_COLORS.get(element,WHITE)
	var preview=Preview.new(); preview.position=Vector2(24,25); preview.size=Vector2(88,108); panel.add_child(preview); preview.configure(id,database.assets.get(str(data.get("asset_key","")),{}),color,not _is_character_unlocked(id)); previews[id]=preview
	var badge: Label = hud.label(panel,Vector2(122,27),Vector2(30,22),_element_glyph(element),11,color); badge.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hud.label(panel,Vector2(155,26),Vector2(88,24),str(data.get("name",id)),15,color)
	var divider:=ColorRect.new(); divider.position=Vector2(122,55); divider.size=Vector2(121,1); divider.color=Color(color,0.35); panel.add_child(divider)
	hud.label(panel,Vector2(122,64),Vector2(121,18),str(data.get("role","战斗成员")),9,WHITE)
	hud.label(panel,Vector2(122,87),Vector2(121,18),"HP %d · ATK %d"%[int(data.get("max_hp",0)),int(data.get("attack",0))],8,MUTED)
	var state: Label = hud.label(panel,Vector2(122,116),Vector2(121,17),"",9,ACCENT); state.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; state_labels[id]=state
	item.pressed.connect(_open_detail.bind(id)); item.mouse_entered.connect(_card_hover.bind(id,true)); item.mouse_exited.connect(_card_hover.bind(id,false)); item.gui_input.connect(_card_scroll_input)

func _build_detail() -> void:
	detail_panel=Panel.new(); detail_panel.position=Vector2(52,32); detail_panel.size=Vector2(1108,620); detail_panel.add_theme_stylebox_override("panel",_panel_style(Color("#ff5a6d"),3)); detail_panel.hide(); frame.add_child(detail_panel)
	hud.label(detail_panel,Vector2(32,20),Vector2(620,18),"O P E R A T O R   /   角 色 档 案",11,ACCENT)
	detail_name=hud.label(detail_panel,Vector2(430,45),Vector2(500,38),"",28,WHITE)
	detail_role=hud.label(detail_panel,Vector2(430,83),Vector2(500,22),"",13,MUTED)
	var preview_card:=Panel.new(); preview_card.position=Vector2(30,52); preview_card.size=Vector2(360,480); preview_card.add_theme_stylebox_override("panel",_panel_style(Color("#76515b"),2)); detail_panel.add_child(preview_card)
	detail_preview=Preview.new(); detail_preview.position=Vector2(18,18); detail_preview.size=Vector2(324,444); preview_card.add_child(detail_preview)
	detail_stats=VBoxContainer.new(); detail_stats.position=Vector2(430,125); detail_stats.size=Vector2(620,230); detail_stats.add_theme_constant_override("separation",8); detail_panel.add_child(detail_stats)
	var q_icon:=_ability_icon(detail_panel,Vector2(430,372),"Q",Color("#ff6173")); detail_skill_title=hud.label(detail_panel,Vector2(486,370),Vector2(560,24),"",15,WHITE); detail_skill_body=hud.label(detail_panel,Vector2(486,397),Vector2(560,48),"",11,MUTED); detail_skill_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var e_icon:=_ability_icon(detail_panel,Vector2(430,458),"E",Color("#f2c86f")); detail_ultimate_title=hud.label(detail_panel,Vector2(486,456),Vector2(560,24),"",15,WHITE); detail_ultimate_body=hud.label(detail_panel,Vector2(486,483),Vector2(560,48),"",11,MUTED); detail_ultimate_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	detail_close=_button(detail_panel,Rect2(30,546,500,50),"←  返回角色列表",false); detail_close.pressed.connect(func(): detail_panel.hide())
	detail_confirm=_button(detail_panel,Rect2(556,546,500,50),"确认选择  →",true); detail_confirm.pressed.connect(_confirm_detail)

func _ability_icon(parent:Control,pos:Vector2,key:String,color:Color)->Panel:
	var p:=Panel.new(); p.position=pos; p.size=Vector2(44,44); p.add_theme_stylebox_override("panel",_panel_style(color,2)); parent.add_child(p); var l: Label = hud.label(p,Vector2.ZERO,p.size,key,20,color); l.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; l.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; return p

func _is_character_ready(id:String)->bool:
	var data: Dictionary = database.characters.get(id,{})
	return bool(data.get("content_ready",false))

func _is_character_unlocked(id:String)->bool:
	return _is_character_ready(id) and progress.unlocked_characters.has(id)

func _open_detail(id:String)->void:
	if not _is_character_unlocked(id): return
	_play_confirm(); detail_id=id; var data:Dictionary=database.characters[id]; var color:Color=ELEMENT_COLORS.get(str(data.get("element","none")),WHITE)
	detail_name.text="%s  /  %s"%[str(data.get("name",id)),_element_name(str(data.get("element","none")))]
	detail_name.add_theme_color_override("font_color",color); detail_role.text=str(data.get("role","战斗成员"))
	detail_preview.configure(id,database.assets.get(str(data.get("asset_key","")),{}),color,false)
	for child in detail_stats.get_children(): child.queue_free()
	var stats=[{"n":"生命","v":float(data.get("max_hp",1)),"m":900.0},{"n":"攻击","v":float(data.get("attack",1)),"m":80.0},{"n":"护甲","v":float(data.get("armor",1)),"m":80.0},{"n":"射程","v":float(data.get("attack_range",1)),"m":500.0},{"n":"攻速","v":float(data.get("attack_rate",1)),"m":2.5},{"n":"移速","v":float(data.get("move_speed",1)),"m":150.0}]
	for stat in stats: _add_stat_bar(str(stat.n),float(stat.v),float(stat.m),color)
	var skill:Dictionary=data.get("active_skill",{}); var ultimate:Dictionary=data.get("ultimate",{})
	detail_skill_title.text="Q · "+str(skill.get("name","主动战技")); detail_skill_body.text=_ability_description(skill,false)
	detail_ultimate_title.text="E · "+str(ultimate.get("name","终结技")); detail_ultimate_body.text=_ability_description(ultimate,true)
	detail_confirm.text="移出队伍" if id in selected and id!="traveler" else ("已固定出战" if id=="traveler" else "确认选择")
	detail_confirm.disabled=id=="traveler"; detail_panel.show(); detail_close.grab_focus()

func _add_stat_bar(stat_name:String,value:float,maximum:float,color:Color)->void:
	var row:=Control.new(); row.custom_minimum_size=Vector2(610,28); detail_stats.add_child(row)
	var name_label: Label = hud.label(row,Vector2(0,1),Vector2(72,26),stat_name,12,WHITE); name_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; name_label.add_theme_font_override("font",LEIGAI_FONT)
	var track:=ProgressBar.new(); track.position=Vector2(78,5); track.size=Vector2(420,18); track.min_value=0; track.max_value=maximum; track.value=minf(value,maximum); track.show_percentage=false
	var bg:=StyleBoxFlat.new(); bg.bg_color=Color("#21171e"); bg.corner_radius_top_left=3; bg.corner_radius_top_right=3; bg.corner_radius_bottom_left=3; bg.corner_radius_bottom_right=3
	var fill:=StyleBoxFlat.new(); fill.bg_color=Color(color,0.82); fill.corner_radius_top_left=3; fill.corner_radius_top_right=3; fill.corner_radius_bottom_left=3; fill.corner_radius_bottom_right=3
	track.add_theme_stylebox_override("background",bg); track.add_theme_stylebox_override("fill",fill); row.add_child(track)
	var value_label: Label = hud.label(row,Vector2(510,1),Vector2(92,26),("%.2f"%value if stat_name=="攻速" else "%d"%roundi(value)),12,color); value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; value_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; value_label.add_theme_font_override("font",LEIGAI_FONT)

func _confirm_detail()->void:
	if detail_id.is_empty() or detail_id=="traveler": return
	if detail_id in selected: selected.erase(detail_id)
	elif selected.size()<3: selected.append(detail_id)
	_refresh(); detail_panel.hide()

func open(stage_id:String,current_squad:Array[String],newly_unlocked:Array=[])->void:
	next_stage_id=stage_id
	for value in newly_unlocked:
		var id:=str(value)
		if not id.is_empty() and _is_character_ready(id): progress.unlocked_characters[id]=true
	progress.save_progress(); selected=["traveler"]
	for id in current_squad:
		if id!="traveler" and _is_character_unlocked(id) and selected.size()<3: selected.append(id)
	var stage:Dictionary=database.stages.get(stage_id,{}); title.text="下一关：%s"%stage.get("name",stage_id); subtitle.text="旅行者固定出战 · 最多选择三名角色 · 点击卡片查看详情"
	grid_scroll.scroll_vertical=0; detail_panel.hide(); _refresh(); root.show(); confirm_button.grab_focus()
func confirm()->void:
	if selected.is_empty() or selected.size()>3 or "traveler" not in selected:return
	root.hide(); confirmed.emit(selected.duplicate())
func activate_at(point:Vector2)->bool:
	if not is_open():return false
	if detail_panel.visible:
		if detail_close.get_global_rect().has_point(point):_play_confirm();detail_panel.hide();return true
		if not detail_confirm.disabled and detail_confirm.get_global_rect().has_point(point):_play_confirm();_confirm_detail();return true
		return true
	if back_button.get_global_rect().has_point(point):_play_confirm();root.hide();cancelled.emit();return true
	if not confirm_button.disabled and confirm_button.get_global_rect().has_point(point):_play_confirm();confirm();return true
	for id:String in buttons:
		if not buttons[id].disabled and buttons[id].get_global_rect().has_point(point):_open_detail(id);return true
	return false
func is_open()->bool:return root!=null and root.visible
func _refresh()->void:
	count_label.text="出战  %d / 3"%selected.size(); confirm_button.disabled=selected.is_empty() or selected.size()>3
	for id:String in buttons:
		var known: bool = _is_character_unlocked(id); buttons[id].disabled=not known; var chosen:=id in selected
		card_frames[id].texture=CARD_SKIN_RED if chosen else CARD_SKIN_GRAY; card_frames[id].modulate=Color.WHITE if chosen else (Color(0.82,0.82,0.84,0.78) if known else Color(0.32,0.31,0.33,0.20)); state_labels[id].text="◆ 出战中" if chosen else ("点击查看详情" if known else "LOCKED / 未解锁"); state_labels[id].add_theme_color_override("font_color",ACCENT if chosen else MUTED); previews[id].set_locked(not known); buttons[id].modulate=Color.WHITE if known else Color(0.38,0.35,0.37,1)
func _layout_character_cards()->void:
	var ordered: Array[String] = []
	for id: String in buttons: ordered.append(id)
	ordered.sort_custom(func(a: String, b: String) -> bool:
		var a_unlocked := _is_character_unlocked(a); var b_unlocked := _is_character_unlocked(b)
		return a_unlocked if a_unlocked != b_unlocked else a.naturalnocasecmp_to(b) < 0)
	for index in ordered.size():
		buttons[ordered[index]].position = Vector2((index % 4) * 282, int(index / 4) * 172)
func _button(parent:Control,rect:Rect2,text_value:String,primary:bool)->Button:
	var b: Button = hud.button(parent,rect,text_value,false)
	for state in ["normal","hover","pressed","focus","disabled"]: b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var skin:=TextureRect.new(); skin.texture=BUTTON_SKIN; skin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); skin.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; skin.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; skin.mouse_filter=Control.MOUSE_FILTER_IGNORE; skin.modulate=Color("#ff526a") if primary else Color("#9b5663"); b.add_child(skin); b.move_child(skin,0)
	b.mouse_entered.connect(func(): _play_select(); skin.modulate=Color.WHITE)
	b.mouse_exited.connect(func(): skin.modulate=Color("#ff526a") if primary else Color("#9b5663"))
	b.pressed.connect(_play_confirm)
	return b
func _button_style(fill:Color,border:Color)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=fill;s.border_color=border;s.set_border_width_all(2);s.corner_radius_top_left=4;s.corner_radius_top_right=4;s.corner_radius_bottom_left=4;s.corner_radius_bottom_right=4;return s
func _panel_style(border:Color,width:int)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color(0.045,0.023,0.034,0.98);s.border_color=border;s.set_border_width_all(width);s.corner_radius_top_left=5;s.corner_radius_top_right=5;s.corner_radius_bottom_left=5;s.corner_radius_bottom_right=5;return s
func _card_style(border:Color,selected_state:bool)->StyleBoxFlat:
	var s:=_panel_style(border,3 if selected_state else 1);s.bg_color=Color("#140c12");s.shadow_color=Color(ACCENT,0.25 if selected_state else 0.0);s.shadow_size=7 if selected_state else 0;return s
func _card_hover(id:String,entered:bool)->void:
	if not _is_character_unlocked(id): return
	if entered:
		buttons[id].grab_focus(); _play_select(); card_frames[id].modulate=Color.WHITE
	else:
		card_frames[id].modulate=Color.WHITE if id in selected else Color(0.82,0.82,0.84,0.78)

func _card_scroll_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		grid_scroll.scroll_vertical = maxi(0, grid_scroll.scroll_vertical - 96)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		grid_scroll.scroll_vertical += 96

func _ability_description(data:Dictionary,is_ultimate:bool)->String:
	var kind:=str(data.get("kind",""))
	var effect: String = str({
		"blade_wave":"斩出贯穿剑气并击退沿途敌人",
		"cryo_chord":"冰霜和弦冻结并削弱范围内目标",
		"heal_gust":"治疗队友并赋予短暂风盾与加速",
		"salon_summon":"召唤沙龙成员持续追击并附着水元素",
		"hydro_burst":"引爆水浪造成范围伤害与水元素附着",
		"sonic_wave":"奏出灼热音浪，造成火元素范围伤害并击退敌人",
		"arcane_lance":"发射高穿透源石长枪压制直线目标",
		"frost_bloom":"绽放冰花冻结区域并持续造成冰伤",
		"echo_shot":"发射回响弹并在目标间追加弹射",
		"tribbie_gate":"部署量子门，使弹道复制并折跃攻击",
		"mon3tr":"召唤 Mon3tr 冲锋拦截并撕裂敌阵",
		"bangboo":"呼叫邦布协同射击并标记高威胁目标",
		"starfall":"召唤星落轰击大范围并造成强击退",
		"frozen_forest":"展开冻结领域，持续冰封并造成多段伤害",
		"anemo_domain":"展开风域，持续牵引敌人并强化队友",
		"hydro_fanfare":"进入万众狂欢，强化全队并引爆水元素",
		"storm_field":"召唤雷暴领域，连续落雷触发感电",
		"team_concert":"开启团队演唱会，大幅强化攻速与暴击",
		"chimera":"释放奇美拉进行范围碾压与持续压制",
		"fate_symphony":"引燃焰色交响领域并强化全队暴击",
		"encore":"触发安可，复制近期支援并提升弹道数量",
		"trinity_field":"展开三重共鸣领域，复制攻击与元素反应",
		"meltdown":"命令 Mon3tr 熔毁，造成巨额范围爆发",
		"network_overdrive":"全域超频邦布网络，提升射速并齐射"
	}.get(kind,"释放角色专属能力并改变战场局势"))
	var power:=int(data.get("power",0)); var radius:=int(data.get("radius",0))
	if is_ultimate:
		return "%s。威力 %d%% · 范围 %d · 能量 %d · 冷却 %.1fs"%[effect,power,radius,int(data.get("energy_cost",0)),float(data.get("cooldown",0.0))]
	return "%s。威力 %d%% · 范围 %d · 冷却 %.1fs"%[effect,power,radius,float(data.get("cooldown",0.0))]

func _play_select()->void:
	if select_sound!=null:select_sound.stop();select_sound.play()
func _play_confirm()->void:
	if confirm_sound!=null:confirm_sound.stop();confirm_sound.play()
func _element_name(element:String)->String:return {"none":"无元素","anemo":"风元素","electro":"雷元素","pyro":"火元素","hydro":"水元素","geo":"岩元素","cryo":"冰元素"}.get(element,element)
func _element_glyph(element:String)->String:return {"none":"无","anemo":"风","electro":"雷","pyro":"火","hydro":"水","geo":"岩","cryo":"冰"}.get(element,"?")
