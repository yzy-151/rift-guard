extends CanvasLayer

signal node_chosen(node_id: String)
signal closed

const TYPE_NAMES := {"combat":"战斗","story":"剧情","elite":"精英","shop":"商店","rest":"休整","recruit":"招募","hidden":"隐藏","boss":"首领"}
const TYPE_COLORS := {"combat":Color("#e59aa4"),"story":Color("#bc91d9"),"elite":Color("#f0b45f"),"shop":Color("#6fd6bd"),"rest":Color("#80b9e8"),"recruit":Color("#f09bbf"),"hidden":Color("#8f78bb"),"boss":Color("#ff536a")}

var root: Control
var hud
var database
var run_state
var buttons: Dictionary = {}
var node_rows: Dictionary = {}
var title: Label
var detail: Label
var frame: Panel
var map_layer: Control
var active_chapter_id := ""

func build(owner_hud, game_database, state) -> void:
	hud=owner_hud; database=game_database; run_state=state; layer=45
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.theme=owner_hud.get_child(0).theme; add_child(root)
	var backdrop:=TextureRect.new(); backdrop.texture=preload("res://assets/helltaker/backgrounds/chapterBG0008.png"); backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; backdrop.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED; root.add_child(backdrop)
	var veil:=ColorRect.new(); veil.color=Color(0.025,0.012,0.022,0.87); veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); veil.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(veil)
	frame=hud.panel(root,Rect2(62,40,1156,640),Color("#171119"),Color("#a34c60")); hud.ornament(frame,Rect2(-18,-18,1192,676))
	hud.label(frame,Vector2(34,20),Vector2(600,20),"R O U T E   /   裂 隙 路 线",11,Color("#e3a2a5"))
	title=hud.label(frame,Vector2(34,48),Vector2(720,40),"裂隙路线",29,Color("#f3e9df"))
	detail=hud.label(frame,Vector2(34,92),Vector2(1080,42),"",12,Color("#b9a6ad")); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var close_button:Button=hud.button(frame,Rect2(1025,28,92,42),"关闭",false); close_button.pressed.connect(close)
	map_layer=Control.new(); map_layer.position=Vector2.ZERO; map_layer.size=frame.size; frame.add_child(map_layer)
	root.hide()

func _current_chapter() -> Dictionary:
	var chapters:Array=database.campaign_map.get("chapters",[])
	for chapter:Dictionary in chapters:
		if chapter.get("nodes",[]).any(func(node:Dictionary)->bool:return str(node.get("id",""))==str(run_state.current_node)):
			return chapter
	return chapters[0] if not chapters.is_empty() else {}

func _build_nodes() -> void:
	for child:Node in map_layer.get_children(): child.queue_free()
	buttons.clear(); node_rows.clear()
	var chapter:=_current_chapter()
	active_chapter_id=str(chapter.get("id","")); title.text=str(chapter.get("name","裂隙路线"))+" · 分支路线"
	var nodes:Array=chapter.get("nodes",[])
	var positions:=[Vector2(78,235),Vector2(302,150),Vector2(302,330),Vector2(530,120),Vector2(530,360),Vector2(756,235),Vector2(756,410),Vector2(970,235)]
	for i in nodes.size():
		var node:Dictionary=nodes[i]; var id:=str(node.id); node_rows[id]=node; var kind:=str(node.get("type","combat"))
		var button:Button=hud.button(map_layer,Rect2(positions[i],Vector2(154,78)),"%s\n%s"%[TYPE_NAMES.get(kind,kind),_node_label(node)],false)
		button.add_theme_color_override("font_color",TYPE_COLORS.get(kind,Color.WHITE)); button.mouse_entered.connect(_show_detail.bind(id)); button.pressed.connect(_choose.bind(id)); buttons[id]=button
	for node:Dictionary in nodes:
		for next_id:Variant in node.get("next",[]):
			if buttons.has(str(node.id)) and buttons.has(str(next_id)):
				var line:=Line2D.new(); line.width=2.0; line.default_color=Color(0.72,0.33,0.40,0.45); line.points=PackedVector2Array([buttons[str(node.id)].position+buttons[str(node.id)].size*0.5,buttons[str(next_id)].position+buttons[str(next_id)].size*0.5]); map_layer.add_child(line); map_layer.move_child(line,0)

func _node_label(node:Dictionary)->String:
	if node.has("stage_id"): return str(database.stages.get(str(node.stage_id),{}).get("name",node.stage_id))
	if node.has("unlock"): return "解锁 "+str(database.characters.get(str(node.unlock),{}).get("name","角色"))
	return {"story":"命运抉择","shop":"补给交换","rest":"恢复整备"}.get(str(node.get("type","")),"未知节点")

func open()->void:
	var chapter:=_current_chapter()
	if active_chapter_id!=str(chapter.get("id","")): _build_nodes()
	refresh(); root.show()

func close()->void: root.hide(); closed.emit()
func is_open()->bool: return root!=null and root.visible

func refresh()->void:
	if buttons.is_empty(): _build_nodes()
	var current:=str(run_state.current_node); var allowed:Array=node_rows.get(current,{}).get("next",[]).duplicate()
	if current not in run_state.completed_nodes: allowed.append(current)
	for id:String in buttons:
		var completed: bool = id in run_state.completed_nodes; var available: bool = id in allowed; buttons[id].set_meta("route_available",available); buttons[id].modulate=Color("#c5b8bd") if not available else (Color("#8ee8c4") if completed else Color.WHITE)
	detail.text="当前位置：%s · 当前章节 %s · 可前往节点会高亮。"%[_node_label(node_rows.get(current,{})),active_chapter_id]

func _show_detail(id:String)->void:
	var node:Dictionary=node_rows.get(id,{}); detail.text="%s / %s · %s"%[TYPE_NAMES.get(str(node.get("type","")),"节点"),_node_label(node),"已完成" if id in run_state.completed_nodes else ("可进入" if bool(buttons[id].get_meta("route_available",false)) else "路线尚未解锁")]

func _choose(id:String)->void:
	if buttons.has(id) and bool(buttons[id].get_meta("route_available",false)): node_chosen.emit(id)
