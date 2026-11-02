extends Panel
## A static character-led pause poster. Content changes only when its data changes.
const PortraitCatalog = preload("res://scripts/dialogue_portrait_catalog.gd")
const Icons = preload("res://scripts/content/generated_icon_catalog.gd")
const CHINESE = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const INK := Color("#111014")
const RED := Color("#c52c49")
const PAPER := Color("#f2e9dc")
const YELLOW := Color("#ffc848")
const MUTED := Color("#b7a5a7")

var actions: Dictionary = {}
var status: Label
var hero_name: Label
var hero_role: Label
var standing: TextureRect
var hero_rows: Array[Dictionary] = []
var chips: Array[Dictionary] = []
var chip_details: Array[Dictionary] = []
var build_scroll: ScrollContainer
var build_host: HBoxContainer
var build_empty: Control
var build_count: Label
var resonance: Label
var english: SystemFont
var hud
var catalog = PortraitCatalog.new()
var texture_cache: Dictionary = {}
var content_key := ""
var build_key := ""
var render_revision := 0
var focus_order: Array[Button] = []

class ActionPlate extends Button:
	var english := ""
	var role := "paper"
	var display_font: Font
	var hint := ""
	func _draw() -> void:
		var focus := has_focus() or is_hovered()
		var fill := Color("#ffc848") if role == "primary" else (Color("#c52c49") if role == "red" else Color("#f2e9dc"))
		if is_pressed(): fill = fill.darkened(0.14)
		var points := PackedVector2Array([Vector2(12,0),Vector2(size.x,0),Vector2(size.x-10,size.y),Vector2(0,size.y)])
		draw_colored_polygon(points, Color("#08070a"))
		var inside := PackedVector2Array([Vector2(15,3),Vector2(size.x-4,3),Vector2(size.x-13,size.y-4),Vector2(4,size.y-4)])
		draw_colored_polygon(inside, fill)
		if focus:
			var line := points.duplicate(); line.append(points[0])
			draw_polyline(line,Color("#ffc848") if role != "primary" else Color("#fff9eb"),3.0,true)
		var ink := Color("#f2e9dc") if role == "red" else Color("#111014")
		var font_size := 51 if role == "primary" else 36
		draw_string(display_font,Vector2(23,size.y-15),english,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,ink)
		var body_font := get_theme_font("font")
		var text_size := 22 if role == "primary" else 18
		var width := body_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size).x
		draw_string(body_font,Vector2(size.x-width-24,28),text,HORIZONTAL_ALIGNMENT_LEFT,-1,text_size,ink)
		if not hint.is_empty():
			var hint_width := body_font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
			draw_string(body_font,Vector2(size.x-hint_width-23,size.y-13),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10,ink)

class EmptyBuild extends Control:
	func _draw() -> void:
		for i in 2:
			var p := Vector2(12+i*11,7-i*3)
			var points := PackedVector2Array([p,p+Vector2(23,-2),p+Vector2(19,34),p+Vector2(-4,36),p])
			draw_colored_polygon(points,Color("#32222a"))
			draw_polyline(points,Color("#c52c49"),2.0,true)
		draw_line(Vector2(36,19),Vector2(36,31),Color("#ffc848"),2.0)
		draw_line(Vector2(30,25),Vector2(42,25),Color("#ffc848"),2.0)

func build(owner_hud) -> void:
	hud = owner_hud
	position = Vector2(55,28); size = Vector2(1170,664)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_STOP
	english = SystemFont.new()
	english.font_names = PackedStringArray(["Impact","Arial Narrow","Arial"])
	english.font_weight = 800
	var pause_title := _label(self,Rect2(26,-5,510,117),"PAUSE",96,PAPER)
	pause_title.add_theme_font_override("font",english)
	pause_title.rotation = -0.035
	var slogan := _label(self,Rect2(604,18,510,51),"暂时喘口气",39,PAPER,true)
	slogan.rotation = -0.025
	status = _label(self,Rect2(604,75,514,34),"",12,MUTED)
	status.clip_text = true
	var portrait_clip := Control.new()
	portrait_clip.position=Vector2(23,112); portrait_clip.size=Vector2(545,331)
	portrait_clip.clip_contents=true; portrait_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(portrait_clip)
	standing = TextureRect.new(); standing.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	standing.stretch_mode=TextureRect.STRETCH_SCALE; standing.mouse_filter=Control.MOUSE_FILTER_IGNORE
	portrait_clip.add_child(standing)
	var nameplate:=Panel.new(); nameplate.position=Vector2(24,403); nameplate.size=Vector2(532,39)
	var name_style:=StyleBoxFlat.new(); name_style.bg_color=INK
	nameplate.add_theme_stylebox_override("panel",name_style)
	nameplate.mouse_filter=Control.MOUSE_FILTER_IGNORE; nameplate.z_index=1; add_child(nameplate)
	hero_name=_label(self,Rect2(42,407,164,33),"",24,PAPER,true)
	hero_name.clip_text=true
	hero_name.z_index=2
	hero_role=_label(self,Rect2(214,414,324,24),"",14,MUTED)
	hero_role.clip_text=true; hero_role.z_index=2
	build_count=_label(self,Rect2(32,445,156,18),"",11,YELLOW)
	resonance=_label(self,Rect2(190,445,358,18),"",10,MUTED); resonance.clip_text=true
	build_scroll=ScrollContainer.new(); build_scroll.position=Vector2(29,468); build_scroll.size=Vector2(536,57)
	build_scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	build_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_AUTO
	build_scroll.clip_contents=true; add_child(build_scroll)
	build_scroll.get_h_scroll_bar().focus_mode=Control.FOCUS_NONE
	build_host=HBoxContainer.new(); build_host.add_theme_constant_override("separation",8); build_scroll.add_child(build_host)
	build_empty=EmptyBuild.new(); build_empty.position=build_scroll.position; build_empty.size=build_scroll.size
	build_empty.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(build_empty)
	_label(build_empty,Rect2(66,1,440,22),"还没有强化 · 下一张牌，就在前方",14,PAPER,true)
	_label(build_empty,Rect2(67,25,438,18),"继续战斗，击杀升级后选择你的构筑。",10,MUTED)
	_action("continue",Rect2(622,122,499,76),"继续战斗","RESUME","primary",-0.025,"空格 / Esc")
	_action("settings",Rect2(617,216,242,65),"设置","SETUP","paper",-0.025,"F10")
	_action("restart",Rect2(879,210,242,65),"重开","RETRY","red",0.025,"R")
	_action("squad",Rect2(617,298,242,65),"编队","SQUAD","paper",-0.025,"F3")
	_action("stages",Rect2(879,292,242,65),"关卡","STAGES","red",0.025,"F4")
	_action("compendium",Rect2(617,380,242,65),"图鉴","GALLERY","red",-0.025)
	_action("map",Rect2(879,374,242,65),"路线","ROUTE","paper",0.025)
	_action("menu",Rect2(645,462,464,56),"主菜单","MENU","paper",-0.020)
	focus_order.assign([actions["continue"],actions.settings,actions.restart,actions.squad,actions.stages,actions.compendium,actions.map,actions.menu])
	for i in focus_order.size():
		var action := focus_order[i]
		action.focus_next=focus_order[(i+1)%focus_order.size()].get_path()
		action.focus_previous=focus_order[posmod(i-1,focus_order.size())].get_path()
	for i in 3: _build_hero_row(i)
	hide()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),INK)
	# One character cutout sits on authored diagonal geometry, not a box column.
	draw_colored_polygon(PackedVector2Array([Vector2(15,20),Vector2(548,0),Vector2(516,434),Vector2(8,457)]),RED)
	draw_colored_polygon(PackedVector2Array([Vector2(27,105),Vector2(175,99),Vector2(90,431),Vector2(14,437)]),PAPER)
	draw_colored_polygon(PackedVector2Array([Vector2(434,103),Vector2(556,92),Vector2(519,437),Vector2(408,446)]),Color("#811d36"))
	for i in 5:
		var x:=574.0+i*17
		draw_line(Vector2(x,105),Vector2(x-28,493),Color("#242127"),5.0)
	draw_rect(Rect2(24,403,532,39),Color("#111014"))
	draw_line(Vector2(26,535),Vector2(1138,535),PAPER,2.0)
	draw_line(Vector2(24,659),Vector2(1140,659),RED,3.0)

func _label(parent: Node, rect: Rect2, text: String, font_size: int, color: Color, display: bool=false) -> Label:
	var item: Label=hud.label(parent,rect.position,rect.size,text,font_size,color)
	if display: item.add_theme_font_override("font",CHINESE)
	return item

func _action(id: String, rect: Rect2, title: String, latin: String, role: String, angle: float, hint: String="") -> void:
	var action:=ActionPlate.new(); action.position=rect.position; action.size=rect.size
	action.text=title; action.english=latin; action.role=role; action.display_font=english; action.hint=hint
	action.rotation=angle; action.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	action.add_theme_font_override("font",CHINESE)
	for state: String in ["normal","hover","pressed","focus","disabled"]:
		action.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state: String in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		action.add_theme_color_override(state,Color.TRANSPARENT)
	action.mouse_entered.connect(action.queue_redraw); action.mouse_exited.connect(action.queue_redraw)
	action.focus_entered.connect(action.queue_redraw); action.focus_exited.connect(action.queue_redraw)
	action.button_down.connect(action.queue_redraw); action.button_up.connect(action.queue_redraw)
	action.set_meta("dialogue_sound",true); add_child(action); actions[id]=action

func _build_hero_row(index: int) -> void:
	var row:=Panel.new(); row.position=Vector2(29+index*371,549); row.size=Vector2(352,96)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("#201b22"); style.border_width_left=3; style.border_color=RED
	row.add_theme_stylebox_override("panel",style); row.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(row)
	var portrait:=TextureRect.new(); portrait.position=Vector2(5,7); portrait.size=Vector2(63,82)
	portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE; row.add_child(portrait)
	var name_label:=_label(row,Rect2(75,3,263,23),"",17,PAPER,true); name_label.clip_text=true
	var hp:=_label(row,Rect2(76,27,256,22),"",14,YELLOW)
	var bar: ProgressBar=hud._meter(row,Rect2(76,51,259,3),YELLOW)
	var bg:=StyleBoxFlat.new(); bg.bg_color=Color("#4d3039")
	bar.add_theme_stylebox_override("background",bg)
	var stats:=_label(row,Rect2(76,57,270,37),"",12,MUTED)
	hero_rows.append({"portrait":portrait,"name":name_label,"hp":hp,"bar":bar,"stats":stats})

func _chip() -> Dictionary:
	var panel:=Panel.new(); panel.custom_minimum_size=Vector2(132,45)
	var style:=StyleBoxFlat.new(); style.bg_color=Color("#282028"); style.border_width_bottom=2; style.border_color=RED
	panel.add_theme_stylebox_override("panel",style); build_host.add_child(panel)
	var icon:=TextureRect.new(); icon.position=Vector2(5,9); icon.size=Vector2(29,29)
	icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(icon)
	var name_label:=_label(panel,Rect2(40,4,86,21),"",11,PAPER); name_label.clip_text=true
	var level:=_label(panel,Rect2(41,26,87,15),"",10,YELLOW)
	var item:={"panel":panel,"icon":icon,"name":name_label,"level":level}; chips.append(item); return item

func refresh_content(sim, selected_id: int) -> void:
	var values: Array=[sim.current_stage_id,sim.endless_layout_id,sim.elapsed,sim.kills,sim.enemies.size(),sim.run_state.crystal_level,sim.run_state.buff_levels,sim.run_state.active_resonances,selected_id,sim.contract_status()]
	for hero: Dictionary in sim.heroes.slice(0,3):
		values.append([hero.name,hero.character_id,hero.role,hero.hp,hero.max_hp,hero.damage,hero.rate,hero.range,hero.armor,hero.speed,hero.deployed,hero.get("element","none"),hero.get("secondary_element",""),hero.get("projectile_count",1)])
	var next_key:=str(values)
	if content_key==next_key: return
	content_key=next_key; render_revision+=1
	var stage: Dictionary=sim.database.stages.get(sim.current_stage_id,{}) if sim.database!=null else {}
	var seconds:=floori(sim.elapsed) if sim.endless_mode else ceili(sim.stage_runtime.remaining_seconds())
	status.text="%s · %s %02d:%02d\nLv.%d · 击退 %d · 在场敌人 %d" %[str(stage.get("name",sim.current_stage_id)),"生存" if sim.endless_mode else "剩余",seconds/60,seconds%60,sim.run_state.crystal_level,sim.kills,sim.enemies.size()]
	status.tooltip_text="契约 · "+sim.contract_status()
	var index:=clampi(selected_id,0,maxi(0,sim.heroes.size()-1))
	if not sim.heroes.is_empty():
		var hero: Dictionary=sim.heroes[index]
		var id:=str(hero.get("character_id",""))
		if not texture_cache.has(id):
			var path:=catalog.resolve_line({"speaker":str(hero.name),"text":"暂时休息一下。"})
			texture_cache[id]=load(path) if not path.is_empty() and ResourceLoader.exists(path) else hud.portrait_texture(hero,sim)
		standing.texture=texture_cache[id]
		if standing.texture!=null:
			var dimensions:=standing.texture.get_size()
			var width:=minf(475.0,dimensions.x*460.0/maxf(1,dimensions.y))
			standing.position=Vector2((545.0-width)*0.5,-5)
			standing.size=Vector2(width,dimensions.y*width/maxf(1,dimensions.x))
		hero_name.text=str(hero.name)
		hero_name.tooltip_text=str(hero.name)+" · "+str(hero.get("role","出战成员"))
		hero_role.text=str(hero.get("role","出战成员")); hero_role.tooltip_text=hero_role.text
	for i in hero_rows.size():
		var row:=hero_rows[i]
		if i>=sim.heroes.size():
			row.portrait.texture=null; row.name.text="空位 · 尚未出战"; row.hp.text="生命 —"; row.bar.value=0; row.stats.text="选择角色后，这里会显示当前数值。"; continue
		var hero: Dictionary=sim.heroes[i]
		row.portrait.texture=hud.portrait_texture(hero,sim)
		var state:="倒地" if hero.hp<=0 else ("出战" if bool(hero.deployed) else "待命")
		row.name.text=str(hero.name)+" · "+state
		row.name.tooltip_text=str(hero.name)+" · "+str(hero.role)
		row.hp.text="生命 %d / %d" %[ceili(hero.hp),ceili(hero.max_hp)]
		row.bar.max_value=maxf(1,hero.max_hp); row.bar.value=hero.hp
		row.stats.text="攻击 %.0f · 攻速 %.2f · 射程 %.0f\n护甲 %.0f · 移速 %.0f · 弹道 ×%d" %[hero.damage,hero.rate,hero.range,hero.armor,hero.speed,int(hero.get("projectile_count",1))]
		row.portrait.modulate=Color("#746167") if hero.hp<=0 else Color.WHITE
	resonance.text=hud.resonance_summary(sim)
	resonance.tooltip_text=resonance.text
	_refresh_build(sim)

func _refresh_build(sim) -> void:
	var next_key:=str(sim.run_state.buff_levels)
	if build_key==next_key: return
	build_key=next_key; chip_details.clear()
	var ids: Array=sim.run_state.buff_levels.keys(); ids.sort()
	var cards: Dictionary={}
	for card: Dictionary in sim.database.cards: cards[str(card.id)]=card
	build_count.text="已有强化 ×%d" %ids.size()
	build_scroll.visible=not ids.is_empty(); build_empty.visible=ids.is_empty()
	for i in maxi(ids.size(),chips.size()):
		if i>=chips.size(): _chip()
		var item:=chips[i]; item.panel.visible=i<ids.size()
		if i>=ids.size(): continue
		var id:=str(ids[i]); var card: Dictionary=cards.get(id,{"id":id,"name":id})
		item.name.text=str(card.name); item.level.text="Lv.%d" %int(sim.run_state.buff_levels[id])
		item.icon.texture=Icons.card_texture(card)
		item.panel.tooltip_text=str(card.name)+" · "+str(item.level.text)+"\n"+str(card.get("description",""))
		chip_details.append({"id":id,"name":str(card.name),"level":int(sim.run_state.buff_levels[id]),"icon":item.icon.texture})
