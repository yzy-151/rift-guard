extends CanvasLayer

signal interact_requested(character_id: String)
signal facility_requested(facility_id: String)
signal exit_requested
signal sound_played(path: String, gain_db: float)

const GridState = preload("res://scripts/home_grid_state.gd")
const GridView = preload("res://scripts/home_grid_view.gd")
const Sequences = preload("res://scripts/character_sequence_library.gd")
const SidebarSurface = preload("res://scripts/home_sidebar_surface.gd")
const UI_SKIN = preload("res://data/ui_skin_profile.tres")
const MOTION = preload("res://scripts/poster_motion.gd")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const DISPLAY_FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")
const HOVER_AUDIO = preload("res://assets/helltaker/audio/button_dialogue_highlight_01.wav")
const CONFIRM_AUDIO = preload("res://assets/helltaker/audio/button_dialogue_confirm_01.wav")
const PROGRESS_PATH := "user://home_puzzles.cfg"
const VIEW_WIDTH := 1280.0
const VIEW_HEIGHT := 720.0
const MOTION_TIME := .14
const REPEAT_TIME := .18

var root: Control
var map
var map_clip:Control
var interior: Node2D
var prompt: Label
var prompt_panel: Panel
var exit_button: Button
var hud
var database
var compendium
var sequences = Sequences.new()
var grid = GridState.new()
var npcs: Array[Dictionary] = []
var player_pos := Vector2.ZERO
var grid_origin := Vector2.ZERO
var cell_size := 60.0
var camera_x := 0.0
var camera_source_y := 0.0
var background_rect := Rect2()
var background_region := Rect2()
var elapsed := 0.0
var moving := false
var facing := 1.0
var busy := false
var touch_axis := Vector2.ZERO
var hover_sound: AudioStreamPlayer
var confirm_sound: AudioStreamPlayer
var action_sound: AudioStreamPlayer
var sound_paths: Dictionary = {}
var sound_cache: Dictionary = {}
var motion_from := Vector2.ZERO
var motion_left := 0.0
var walk_repeat := 0.0
var block_motion: Dictionary = {}
var last_action: Dictionary = {}
var feedback_left := 0.0
var sidebar: Control
var portrait: TextureRect
var unit_label: Label
var objective_label: Label
var result_home_button: Button
var result_visit_button: Button
var visiting_encounter := false
var room_title: Label
var step_label: Label
var step_caption: Label
var detail_label: Label
var key_label: Label
var room_help: Label
var undo_button: Button
var restart_button: Button
var wait_button: Button
var result_panel: Panel
var result_title: Label
var result_detail: Label
var result_button: Button
var result_signature := ""
var completed: Dictionary = {}
var progress_path: String = PROGRESS_PATH
var hub_return_cell := Vector2i(8,4)
var entrance_tween: Tween

func build(owner_hud, game_database, progress) -> void:
	hud=owner_hud;database=game_database;compendium=progress;layer=15
	root=Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme=owner_hud.get_child(0).theme
	root.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(root)
	var background:=ColorRect.new()
	background.color=Color("#03031a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(background)
	map_clip=Control.new();map_clip.position=UI_LAYOUT.mode_home_board_rect.position;map_clip.size=UI_LAYOUT.mode_home_board_rect.size
	map_clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(map_clip)
	map=GridView.new();map.owner_panel=self;map.position=-map_clip.position;map_clip.add_child(map)
	interior=map
	sidebar=SidebarSurface.new()
	sidebar.position=UI_LAYOUT.mode_home_sidebar_rect.position;sidebar.size=UI_LAYOUT.mode_home_sidebar_rect.size
	root.add_child(sidebar)
	var top:=_panel(UI_LAYOUT.mode_home_header_rect,Color("#09090b"),Color("#e41b48"),2)
	_text(top,UI_LAYOUT.mode_home_brand_rect.position,UI_LAYOUT.mode_home_brand_rect.size,"裂隙客厅",30,Color("#fff2df"))
	_text(top,UI_LAYOUT.mode_home_brand_hint_rect.position,UI_LAYOUT.mode_home_brand_hint_rect.size,"HOME / HELLTAKER",12,Color("#e73e60"))
	room_title=_text(top,UI_LAYOUT.mode_home_room_title_rect.position,UI_LAYOUT.mode_home_room_title_rect.size,"",26,Color("#fff2df"))
	exit_button=_button(top,UI_LAYOUT.mode_home_exit_rect,"返回 / Esc",func():_back())
	step_label=_side_text(UI_LAYOUT.mode_home_steps_rect,"",56,Color("#ffcf43"))
	step_caption=_side_text(UI_LAYOUT.mode_home_steps_hint_rect,"",14,Color("#e85874"))
	unit_label=_side_text(UI_LAYOUT.mode_home_status_unit_rect,"",18,Color("#fff2df"))
	objective_label=_side_text(UI_LAYOUT.mode_home_objective_rect,"",16,Color("#fff2df"))
	key_label=_side_text(UI_LAYOUT.mode_home_progress_rect,"",15,Color("#ffcf43"))
	portrait=TextureRect.new()
	portrait.position=UI_LAYOUT.mode_home_amiya_rect.position-sidebar.position;portrait.size=UI_LAYOUT.mode_home_amiya_rect.size
	portrait.texture=UI_SKIN.mode_home_portrait;portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter=Control.MOUSE_FILTER_IGNORE;sidebar.add_child(portrait)
	var nameplate_fill:=ColorRect.new()
	nameplate_fill.color=Color("#fff2df");nameplate_fill.position=UI_LAYOUT.mode_home_nameplate_rect.position-sidebar.position
	nameplate_fill.size=UI_LAYOUT.mode_home_nameplate_rect.size;nameplate_fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;sidebar.add_child(nameplate_fill)
	var nameplate:=_side_text(UI_LAYOUT.mode_home_nameplate_rect,"阿米娅 / AMIYA",16,Color("#09090e"))
	nameplate.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	detail_label=_side_text(UI_LAYOUT.mode_home_description_rect,"",15,Color("#ded5d0"))
	detail_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	room_help=_side_text(UI_LAYOUT.mode_home_help_rect,"",13,Color("#b4a4ad"))
	room_help.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var footer:=_panel(UI_LAYOUT.mode_home_footer_rect,Color("#09090b"),Color("#6d283a"),1)
	_text(footer,UI_LAYOUT.mode_home_footer_text_rect.position,UI_LAYOUT.mode_home_footer_text_rect.size,"WASD / 方向键  ·  F 交互  ·  Z 撤销  ·  R 重来  ·  空格 等一拍",16,Color("#fff2df"))
	prompt_panel=_panel(UI_LAYOUT.mode_home_interaction_rect,Color("#08080a"),Color("#ffcd48"),1)
	prompt=_text(prompt_panel,UI_LAYOUT.mode_home_interaction_text_rect.position,UI_LAYOUT.mode_home_interaction_text_rect.size,"",18,Color("#ffe196"))
	prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;prompt_panel.hide()
	undo_button=_button(root,UI_LAYOUT.mode_home_undo_rect,"撤销 [Z]",func():undo_turn())
	restart_button=_button(root,UI_LAYOUT.mode_home_retry_rect,"重来 [R]",func():restart_room())
	wait_button=_button(root,UI_LAYOUT.mode_home_wait_rect,"等一拍 [空格]",func():wait_turn())
	result_panel=_panel(UI_LAYOUT.mode_home_result_rect,Color("#09090b"),Color("#e41b48"),5)
	result_title=_text(result_panel,UI_LAYOUT.mode_home_result_title_rect.position,UI_LAYOUT.mode_home_result_title_rect.size,"",38,Color("#ffcf43"))
	result_detail=_text(result_panel,UI_LAYOUT.mode_home_result_detail_rect.position,UI_LAYOUT.mode_home_result_detail_rect.size,"",19,Color("#fff2df"))
	result_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	result_button=_button(result_panel,UI_LAYOUT.mode_home_result_action_rect,"",func():
		if grid.failed:restart_room()
		else:next_room())
	result_home_button=_button(result_panel,UI_LAYOUT.mode_home_result_home_rect,"回客厅 [Esc]",func():
		if str(grid.room.get("next_room","")).is_empty() and grid.won:restart_room()
		else:return_to_hub())
	result_visit_button=_button(result_panel,UI_LAYOUT.mode_home_result_visit_rect,"",func():visit_encounter())
	result_panel.hide()
	hover_sound=AudioStreamPlayer.new();hover_sound.stream=HOVER_AUDIO;hover_sound.bus="SFX";add_child(hover_sound)
	confirm_sound=AudioStreamPlayer.new();confirm_sound.stream=CONFIRM_AUDIO;confirm_sound.bus="SFX";add_child(confirm_sound)
	action_sound=AudioStreamPlayer.new();action_sound.bus="SFX";add_child(action_sound)
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(GridView.MANIFEST))
	if manifest is Dictionary: sound_paths=manifest.get("audio",{})
	var app=get_parent()
	if not str(app.get("qa_storage_path")).is_empty():progress_path=str(app.get("qa_storage_path")).path_join("home_puzzles.cfg")
	var saved:=ConfigFile.new()
	if saved.load(progress_path)==OK:
		for id in saved.get_section_keys("completed"): completed[id]=int(saved.get_value("completed",id,0))
	load_room("hub",false)
	root.hide()

func _panel(rect:Rect2,fill:Color,line:Color,width:int) -> Panel:
	var control:=Panel.new();control.position=rect.position;control.size=rect.size
	var style:=StyleBoxFlat.new();style.bg_color=fill;style.border_color=line;style.set_border_width_all(width)
	control.add_theme_stylebox_override("panel",style);control.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(control)
	return control

func _text(parent:Node,point:Vector2,size:Vector2,value:String,font_size:int,color:Color) -> Label:
	var label:Label=hud.label(parent,point,size,value,font_size,color)
	label.add_theme_font_override("font",DISPLAY_FONT)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return label

func _side_text(rect:Rect2,value:String,font_size:int,color:Color) -> Label:
	return _text(sidebar,rect.position-UI_LAYOUT.mode_home_sidebar_rect.position,rect.size,value,font_size,color)

func _button(parent:Node,rect:Rect2,text:String,action:Callable) -> Button:
	var button:Button=hud.button(parent,rect,text,false)
	var normal:=StyleBoxFlat.new();normal.bg_color=Color("#fff2df");normal.set_border_width_all(2);normal.border_color=Color("#09090b")
	var hover:StyleBoxFlat=normal.duplicate();hover.bg_color=Color("#ffcf43")
	var pressed:StyleBoxFlat=normal.duplicate();pressed.bg_color=Color("#df1745")
	button.add_theme_stylebox_override("normal",normal);button.add_theme_stylebox_override("hover",hover);button.add_theme_stylebox_override("pressed",pressed)
	button.add_theme_font_override("font",DISPLAY_FONT);button.add_theme_font_size_override("font_size",17)
	button.add_theme_color_override("font_color",Color("#0a090b"));button.add_theme_color_override("font_hover_color",Color("#0a090b"));button.add_theme_color_override("font_pressed_color",Color("#fff2df"))
	button.pressed.connect(action)
	button.mouse_entered.connect(func():
		if is_instance_valid(hover_sound):hover_sound.play())
	return button

func load_room(id:String,animate:bool=true) -> bool:
	if not grid.load_room(id):return false
	busy=false;touch_axis=Vector2.ZERO;walk_repeat=REPEAT_TIME;motion_left=0;moving=false;block_motion.clear();last_action.clear();feedback_left=0
	refresh_residents();_update_camera();result_signature="";_update_ui()
	if animate and root.visible:_entrance()
	return true

func refresh_residents() -> void:
	npcs.clear();grid.blocked_cells.clear()
	if grid.room_id=="hub":
		var unlocked:Array[String]=[]
		for id:String in database.characters:
			if id!="traveler" and compendium.unlocked_characters.has(id) and bool(database.characters[id].get("content_ready",false)) and sequences.has_character(id):unlocked.append(id)
		unlocked.sort()
		var slots:Array=grid.room.get("resident_slots",[])
		for index in mini(unlocked.size(),slots.size()):
			var id:=unlocked[index];var cell:=Vector2i(int(slots[index][0]),int(slots[index][1]))
			npcs.append({"id":id,"name":str(database.characters[id].get("name",id)),"cell":cell,"pos":cell_foot(cell)})
			grid.blocked_cells.append(cell)
	else:
		var encounter:Dictionary=grid.room.get("encounter",{})
		var id:String=str(encounter.get("id",""))
		if database.characters.has(id) and sequences.has_character(id):
			var cell:Vector2i=_cell(encounter.get("cell",[0,0]))
			npcs.append({"id":id,"name":str(database.characters[id].get("name",id)),"cell":cell,"pos":cell_foot(cell),"visitor":true})

	for facility:Dictionary in grid.room.get("facilities",[]):grid.blocked_cells.append(_cell(facility.pos))
	if is_instance_valid(map):map.queue_redraw()

func open() -> void:
	busy=false;visiting_encounter=false;refresh_residents();_update_camera();root.show();_update_ui();_entrance()

func close() -> void:
	touch_axis=Vector2.ZERO;moving=false;motion_left=0;block_motion.clear();player_pos=_player_foot()
	if entrance_tween!=null and entrance_tween.is_valid():entrance_tween.kill()
	MOTION.reset(sidebar)
	map.position=-map_clip.position;map.modulate=Color.WHITE;root.hide()

func is_open() -> bool:
	return root!=null and root.visible

func cell_center(cell:Vector2i) -> Vector2:
	return grid_origin+(Vector2(cell)+Vector2(.5,.5))*cell_size

func cell_foot(cell:Vector2i) -> Vector2:
	return cell_center(cell)+Vector2(0,cell_size*.50)

func _player_foot() -> Vector2:
	var cell:Vector2i=grid.player
	var encounter:Dictionary=grid.room.get("encounter",{})
	if grid.won and not encounter.is_empty() and _cell(encounter.get("cell",[-1,-1]))==cell:
		cell=Vector2i(last_action.get("from",cell))
	return cell_foot(cell)

func _cell(value:Array) -> Vector2i:
	return Vector2i(int(value[0]),int(value[1]))

func _update_camera(reset_player:bool=true) -> void:
	var rows:Array=grid.room.get("grid",[])
	if rows.is_empty():return
	var previous_origin:=grid_origin
	var source:Array=grid.room.get("source_view",[0,0,1920,1080])
	background_region=Rect2(float(source[0]),float(source[1]),float(source[2]),float(source[3]))
	var board:Rect2=UI_LAYOUT.mode_home_board_rect
	var origin:Array=grid.room.get("source_origin",[0,0])
	if bool(grid.room.get("scrolling",false)):
		background_region.size.y=minf(background_region.size.y,960)
		var target_y:float=float(origin[1])+(float(grid.player.y)+1)*float(grid.room.get("source_cell",100))-background_region.size.y*.62
		if reset_player:camera_source_y=clampf(target_y,float(source[1]),float(source[1])+float(source[3])-background_region.size.y)
		background_region.position.y=camera_source_y
	var ratio:float=minf(board.size.x/background_region.size.x,board.size.y/background_region.size.y)
	background_rect=Rect2(board.position+(board.size-background_region.size*ratio)*.5,background_region.size*ratio)
	cell_size=float(grid.room.get("source_cell",100))*ratio
	grid_origin=background_rect.position+(Vector2(float(origin[0]),float(origin[1]))-background_region.position)*ratio
	camera_x=0
	map_clip.clip_contents=bool(grid.room.get("scrolling",false))
	if reset_player:map.position=-map_clip.position;player_pos=_player_foot()
	else:
		var delta:=grid_origin-previous_origin
		player_pos+=delta;motion_from+=delta
	for npc:Dictionary in npcs:npc.pos=cell_foot(npc.cell)

func _follow_camera(dt:float) -> void:
	if not bool(grid.room.get("scrolling",false)):return
	var source:Array=grid.room.source_view
	var origin:Array=grid.room.source_origin
	var target_y:float=float(origin[1])+(float(grid.player.y)+1)*float(grid.room.get("source_cell",100))-960*.62
	target_y=clampf(target_y,float(source[1]),float(source[1])+float(source[3])-960)
	camera_source_y=lerpf(camera_source_y,target_y,1-exp(-10*dt))
	_update_camera(false)

func nearest_resident() -> Dictionary:
	for npc:Dictionary in npcs:
		if absi(grid.player.x-npc.cell.x)+absi(grid.player.y-npc.cell.y)<=1:return npc
	return {}

func nearest_facility() -> Dictionary:
	for row:Dictionary in grid.room.get("facilities",[]):
		var cell:=_cell(row.pos)
		if absi(grid.player.x-cell.x)+absi(grid.player.y-cell.y)<=1:return row
	return {}

func interaction_target() -> Dictionary:
	if busy or grid.won or grid.failed or grid.room_id!="hub":return {}
	var facility:=nearest_facility()
	if not facility.is_empty():return facility
	for portal:Dictionary in grid.room.get("portals",[]):
		var cell:=_cell(portal.pos)
		if absi(grid.player.x-cell.x)+absi(grid.player.y-cell.y)<=1:
			var target:Dictionary=portal.duplicate();target["portal"]=true;return target
	return nearest_resident() if grid.room_id=="hub" else {}

func interact_active_target() -> void:
	if not is_open() or not _input_enabled():return
	var target:=interaction_target()
	if target.is_empty():return
	confirm_sound.play()
	if bool(target.get("portal",false)):
		if grid.room_id=="hub":
			hub_return_cell=grid.player;_play("door_open");load_room(route_destination(str(target.target)))
		return
	busy=true;moving=false;touch_axis=Vector2.ZERO
	if target.has("action"):facility_requested.emit(str(target.id))
	else:interact_requested.emit(str(target.id))

func _input_enabled() -> bool:
	if busy:return false
	var app=get_parent()
	if bool(app.get("campaign_prelude_active")) or bool(app.story.active):return false
	for key:String in ["settings_panel","compendium_panel","stage_select_panel","squad_panel","mode_select_panel"]:
		var panel=app.get(key)
		if panel!=null and panel.is_open():return false
	return true

func handle_input(event:InputEvent) -> bool:
	if not is_open():return false
	if not _input_enabled():return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:_back();return true
			KEY_F,KEY_ENTER:
				if grid.won:
					if event.keycode==KEY_F:visit_encounter()
					else:next_room()
				elif grid.failed:restart_room()
				else:interact_active_target()
				return true
			KEY_Z,KEY_BACKSPACE:undo_turn();return true
			KEY_R:restart_room();return true
			KEY_SPACE:wait_turn();return true
			KEY_A,KEY_LEFT:_try_step(Vector2i.LEFT);return true
			KEY_D,KEY_RIGHT:_try_step(Vector2i.RIGHT);return true
			KEY_W,KEY_UP:_try_step(Vector2i.UP);return true
			KEY_S,KEY_DOWN:_try_step(Vector2i.DOWN);return true
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var cell:=Vector2i(((event.position-grid_origin)/cell_size).floor())
		var delta:Vector2i=cell-grid.player
		if absi(delta.x)+absi(delta.y)==1:
			var target:=interaction_target()
			if not target.is_empty() and ((target.has("pos") and target.pos is Array and _cell(target.pos)==cell) or target.get("cell",Vector2i(-1,-1))==cell):interact_active_target()
			else:_try_step(delta)
			return true
	return event is InputEventKey and event.keycode in [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]

func _process(dt:float) -> void:
	if not is_open() or not _input_enabled():return
	_follow_camera(dt)
	elapsed+=dt;feedback_left=maxf(0,feedback_left-dt);walk_repeat=maxf(0,walk_repeat-dt)
	if motion_left>0:
		motion_left=maxf(0,motion_left-dt);player_pos=motion_from.lerp(_player_foot(),motion_progress())
		if motion_left<=0:moving=false;block_motion.clear()
	var axis:=touch_axis
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):axis.x-=1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):axis.x+=1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):axis.y-=1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):axis.y+=1
	move_player(axis,dt);map.queue_redraw();_update_ui()

func move_player(axis:Vector2,_dt:float) -> void:
	if not is_open() or not _input_enabled() or axis.length_squared()<.04 or walk_repeat>0:return
	var direction:=Vector2i(int(signf(axis.x)),0) if absf(axis.x)>=absf(axis.y) else Vector2i(0,int(signf(axis.y)))
	_try_step(direction)

func _try_step(direction:Vector2i) -> void:
	if motion_left>0 or grid.failed or grid.won:return
	if direction.x!=0:facing=float(direction.x)
	motion_from=player_pos;last_action=grid.step(direction);walk_repeat=REPEAT_TIME
	var kind:=str(last_action.get("action_kind",last_action.kind))
	if bool(last_action.moved):motion_left=MOTION_TIME;moving=true
	if last_action.has("block_to"):block_motion={"from":last_action.block_from,"to":last_action.block_to}
	if kind=="kick":feedback_left=.18;_play("enemy_die" if last_action.get("enemy_removed",false) else "enemy_kick")
	elif kind=="push":_play("stone_move")
	elif kind in ["move","key"]:_play("step")
	elif last_action.get("reason","")=="key_required":_play("door_locked")
	if bool(last_action.get("key_collected",false)):_play("key")
	if int(last_action.get("trap_damage",0))>0:feedback_left=.18;_play("spikes")
	if grid.won:_play("door_open");_record_clear()
	_update_ui();map.queue_redraw()

func motion_progress() -> float:
	var t:=1-clampf(motion_left/MOTION_TIME,0,1)
	return t*t*(3-2*t)

func wait_turn() -> void:
	if not _input_enabled() or motion_left>0 or grid.room_id=="hub" or grid.failed or grid.won:return
	last_action=grid.wait_turn();walk_repeat=REPEAT_TIME;_play("step")
	if int(last_action.get("trap_damage",0))>0:_play("spikes")
	_update_ui();map.queue_redraw()

func undo_turn() -> void:
	if not _input_enabled() or not grid.undo():return
	motion_left=0;moving=false;block_motion.clear();last_action.clear();feedback_left=0;_update_camera()
	confirm_sound.play();_update_ui();map.queue_redraw()

func restart_room() -> void:
	if not _input_enabled():return
	grid.restart();motion_left=0;moving=false;block_motion.clear();last_action.clear();feedback_left=0;walk_repeat=REPEAT_TIME;_update_camera()
	confirm_sound.play();result_signature="";_update_ui();map.queue_redraw()

func puzzle_count() -> int:
	var count:=0
	for room:Dictionary in grid.rooms.values():
		if str(room.get("kind",""))=="puzzle":count+=1
	return count

func completed_count() -> int:
	var count:=0
	for id:String in completed:
		if grid.rooms.has(id) and str(grid.rooms[id].get("kind",""))=="puzzle":count+=1
	return count

func route_destination(start:String) -> String:
	var id:=start
	var seen:Dictionary={}
	while grid.rooms.has(id) and completed.has(id) and not seen.has(id):
		seen[id]=true
		var next:String=str(grid.rooms[id].get("next_room",""))
		if next.is_empty():return start
		id=next
	return id

func next_room() -> void:
	if not _input_enabled() or not grid.won:return
	var next:String=str(grid.room.get("next_room",""))
	if next.is_empty():return_to_hub()
	else:_play("door_open");load_room(next)

func visit_encounter() -> void:
	if not _input_enabled() or not grid.won:return
	var id:String=str(grid.room.get("encounter",{}).get("id",""))
	if not database.characters.has(id):return
	busy=true;visiting_encounter=true;moving=false;touch_axis=Vector2.ZERO
	confirm_sound.play();interact_requested.emit(id)

func return_to_hub() -> void:
	if not _input_enabled():return
	load_room("hub");grid.player=hub_return_cell;player_pos=_player_foot();_update_ui();map.queue_redraw()

func _back() -> void:
	if not _input_enabled():return
	confirm_sound.play()
	if grid.room_id!="hub":return_to_hub()
	else:exit_requested.emit()

func _update_ui() -> void:
	var at_home:bool=grid.room_id=="hub"
	var total:int=puzzle_count()
	room_title.text=str(grid.room.get("name",""))+"  /  "+("HOME" if at_home else "ROOM "+grid.room_id.substr(7))
	step_label.text="HOME" if at_home else "%02d"%grid.steps_remaining
	step_caption.text="裂隙闲逛 / FREE WALK" if at_home else "剩余步数 / STEPS LEFT"
	unit_label.text="" if at_home else "步"
	objective_label.text="%d 位住客 · 3 条路线"%npcs.size() if at_home else ("钥匙到手 · 出发" if grid.has_key else ("拿到钥匙再出门" if not grid.keys.is_empty() else "穿过机关 · 找到出口"))
	key_label.text="地图完成 %02d / %02d"%[completed_count(),total] if at_home else "地图 %02d / %02d  ·  地刺%s"%[int(grid.room_id.substr(7)),total,"亮" if grid.phase==0 else "灭"]
	sidebar.progress=float(completed_count())/maxi(1,total) if at_home else float(maxi(0,int(grid.room.steps)-grid.steps_remaining))/maxi(1,int(grid.room.steps))
	sidebar.queue_redraw()
	detail_label.text="三扇门，各有一条路。\n角色和家具都能靠近互动。" if at_home else str(grid.room.get("subtitle","")).replace("，","，\n")
	room_help.text="靠近按 F · 走路不用计步\n通关记录最佳消耗步数" if at_home else "亮地刺多扣 2 步 · 空格等一拍\nZ 撤销 · R 重来 · Esc 回家"
	undo_button.visible=not at_home;restart_button.visible=not at_home;wait_button.visible=not at_home
	undo_button.disabled=grid.history.is_empty()
	exit_button.text="返回 [Esc]" if at_home else "回家 [Esc]"
	var target:=interaction_target();prompt_panel.visible=at_home and not target.is_empty()
	if not target.is_empty():
		prompt.text="[F]  "+("进入 "+str(grid.rooms.get(route_destination(str(target.get("target",""))),{}).get("name",target.name)) if target.get("portal",false) else str(target.name)+(" · 对话" if not target.has("action") else " · 打开"))
	var signature:String=grid.room_id+str(grid.won)+str(grid.failed)
	if signature==result_signature:return
	result_signature=signature;result_panel.visible=grid.won or grid.failed
	result_visit_button.hide();result_home_button.visible=grid.won
	if grid.won:
		var next:String=str(grid.room.get("next_room",""))
		var encounter:Dictionary=grid.room.get("encounter",{})
		var id:String=str(encounter.get("id",""))
		result_title.text="路通了。 / CLEAR"
		result_detail.text="用了 %d 步，参考最佳 %d 步。\n"%[int(grid.room.steps)-grid.steps_remaining,int(grid.room.get("par",0))]+("下一站："+str(grid.rooms.get(next,{}).get("name","")) if not next.is_empty() else "这条路线已走到底，回去喝杯水。")
		result_button.text="继续探索 [Enter]" if not next.is_empty() else "回到客厅 [Enter]"
		result_home_button.text="回客厅 [Esc]" if not next.is_empty() else "再走一次 [R]"
		if database.characters.has(id):
			result_visit_button.text="和 "+str(database.characters[id].get("name",id))+" 聊两句 [F]"
			result_visit_button.show()
	elif grid.failed:
		result_title.text="步数用光了。 / OOPS"
		result_detail.text="按 Z 撤销一步，或按 R 重来。\n石块只能推一块，地刺亮时别急着踩。"
		result_button.text="再试一次 [Enter]"

func _record_clear() -> void:
	var cost:int=int(grid.room.get("steps",0))-grid.steps_remaining
	completed[grid.room_id]=mini(cost,int(completed.get(grid.room_id,cost)))
	if bool(get_parent().get("test_mode")):return
	var file:=ConfigFile.new()
	for id in completed:file.set_value("completed",id,int(completed[id]))
	file.save(progress_path)

func _play(key:String) -> void:
	var value:Variant=sound_paths.get(key,"")
	var path:String=str(value[0]) if value is Array and not value.is_empty() else str(value)
	if path.is_empty():return
	if not sound_cache.has(path):sound_cache[path]=load(path)
	action_sound.stream=sound_cache[path];action_sound.volume_db=-5;action_sound.play()
	sound_played.emit(path,action_sound.volume_db)

func _entrance() -> void:
	if entrance_tween!=null and entrance_tween.is_valid():entrance_tween.kill()
	MOTION.enter(sidebar,[{"node":sidebar,"offset":Vector2(-16,0)}],bool(hud.reduced))
	map.position=-map_clip.position+Vector2(0,10);map.modulate.a=0
	entrance_tween=create_tween().set_parallel(true)
	entrance_tween.tween_property(map,"position",-map_clip.position,.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	entrance_tween.tween_property(map,"modulate:a",1.0,.20)
