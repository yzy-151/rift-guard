extends Node2D
## Original Helltaker pieces, on the same square grid used by the puzzle rules.

const Sequences = preload("res://scripts/character_sequence_library.gd")
const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")
const MANIFEST := "res://assets/world/home_helltaker_20261008/manifest.json"
const EXPANSION := "res://assets/world/home_expansion_20261009/manifest.json"
const FONT = preload("res://assets/fonts/TiejiliSC-Regular.ttf")

var owner_panel
var sequences = Sequences.new()
var assets: Dictionary = {}
var backgrounds: Dictionary = {}
var textures: Dictionary = {}

func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if data is Dictionary:
		assets = data.get("assets", {})
		backgrounds = data.get("backgrounds", {})
	var expansion:Variant=JSON.parse_string(FileAccess.get_file_as_string(EXPANSION))
	if expansion is Dictionary:backgrounds.merge(expansion.get("backgrounds",{}))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	if owner_panel == null or owner_panel.grid.room.is_empty(): return
	var grid = owner_panel.grid
	var tile: float = owner_panel.cell_size
	var rows: Array = grid.room.get("grid", [])
	var background:Dictionary=backgrounds.get(grid.room_id,{})
	var path:String=str(background.get("path",""))
	if not path.is_empty():
		if not textures.has(path): textures[path]=load(path)
		draw_texture_rect_region(textures[path],owner_panel.background_rect,owner_panel.background_region)
	var objects: Array[Dictionary] = []
	for cell:Vector2i in grid.spikes:
		if not _in_view(owner_panel.cell_center(cell)):continue
		_asset("spikes_on" if grid.phase==0 else "spikes_off",owner_panel.cell_center(cell))
	for cell: Vector2i in grid.blocks: objects.append({"kind":"block","cell":cell})
	for enemy: Dictionary in grid.enemies: objects.append({"kind":"enemy","cell":enemy.pos,"hp":enemy.hp})
	for cell: Vector2i in grid.keys: objects.append({"kind":"key","cell":cell})
	for portal: Dictionary in grid.room.get("portals",[]):
		if bool(portal.get("hidden",false)) or (str(portal.get("id",""))=="exit" and not grid.room.get("encounter",{}).is_empty()):continue
		objects.append({"kind":"door","cell":Vector2i(int(portal.pos[0]),int(portal.pos[1])),"data":portal})
	for facility: Dictionary in grid.room.get("facilities",[]):
		objects.append({"kind":"facility","cell":Vector2i(int(facility.pos[0]),int(facility.pos[1])),"data":facility})
	for npc: Dictionary in owner_panel.npcs: objects.append({"kind":"actor","cell":npc.cell,"data":npc})
	objects.append({"kind":"player","cell":grid.player})
	objects.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
		var ay: float = float(a.cell.y)
		var by: float = float(b.cell.y)
		if a.kind=="player": ay = (owner_panel.player_pos.y-owner_panel.grid_origin.y)/tile-1.0
		if b.kind=="player": by = (owner_panel.player_pos.y-owner_panel.grid_origin.y)/tile-1.0
		if not is_equal_approx(ay,by):return ay<by
		# Visitors are a visual goal, so a pushed stone in the same logical cell
		# must not paint over their face; puzzle occupancy itself is unchanged.
		if a.kind=="actor" and bool(a.data.get("visitor",false)):return false
		if b.kind=="actor" and bool(b.data.get("visitor",false)):return true
		return str(a.kind)<str(b.kind))
	var target: Dictionary = owner_panel.interaction_target()
	for item: Dictionary in objects:
		var foot := _foot(item.cell)
		if not _in_view(foot):continue
		match str(item.kind):
			"block":
				if not owner_panel.block_motion.is_empty() and item.cell==owner_panel.block_motion.to:
					foot = _foot(owner_panel.block_motion.from).lerp(foot,owner_panel.motion_progress())
				_shadow(foot+Vector2(0,tile*.50), tile*.36, tile*.10)
				_asset("block",foot)
			"enemy":
				_shadow(foot+Vector2(0,tile*.50),tile*.34,tile*.10)
				var frame := int(owner_panel.elapsed*12)
				var enemy_foot := foot
				if owner_panel.feedback_left>0 and owner_panel.last_action.get("enemy_pos",Vector2i(-1,-1))==item.cell:
					enemy_foot.x += sin(owner_panel.feedback_left*65)*4
				_asset("enemy_hit" if int(item.hp)<2 else "enemy_idle",enemy_foot,Color.WHITE,frame)
			"key":
				_asset("key",foot+Vector2(0,-7+sin(owner_panel.elapsed*3)*3),Color.WHITE,int(owner_panel.elapsed*12))
			"door":
				var unlocked: bool = str(grid.room.get("kind","hub"))=="hub" or grid.has_key or not bool(item.data.get("requires_key",false))
				if not bool(item.data.get("baked",false)):
					_asset("portal",foot,Color.WHITE if unlocked else Color("#9a5264"),int(owner_panel.elapsed*12))
				_label("出口" if str(grid.room.get("kind","hub"))=="puzzle" else str(item.data.get("name","门"))+(" ✓" if owner_panel.completed.has(str(item.data.get("target",""))) else ""),foot+Vector2(0,-tile*1.20),target.get("id","")==item.data.id)
			"facility":
				if not bool(item.data.get("baked",false)):
					_asset(str(item.data.id) if assets.has(str(item.data.id)) else "door_closed",foot)
				_label(str(item.data.name),foot+Vector2(0,-tile*.70),target.get("id","")==item.data.id)
			"actor":
				var npc: Dictionary = item.data
				foot=owner_panel.cell_foot(item.cell)
				_shadow(foot,tile*.29,tile*.08)
				_character(str(npc.id),"idle",foot,1.0 if owner_panel.player_pos.x>foot.x else -1.0)
				if target.get("id","")==npc.id or bool(npc.get("visitor",false)):
					_label(str(npc.name),foot+Vector2(0,-tile*1.52),grid.won or target.get("id","")==npc.id)
			"player":
				foot = owner_panel.player_pos
				_shadow(foot,tile*.29,tile*.08)
				var state := "run" if owner_panel.moving else "idle"
				if owner_panel.feedback_left>.07 and str(owner_panel.last_action.get("kind",""))=="kick": state="attack"
				_character("traveler",state,foot,owner_panel.facing)
	# A short direction slash only accompanies an actual kick; no false damage area.
	if owner_panel.feedback_left>0 and str(owner_panel.last_action.get("kind",""))=="kick":
		var p := _foot(Vector2i(owner_panel.last_action.get("enemy_pos",grid.player)))
		var alpha: float = owner_panel.feedback_left/.18
		draw_line(p+Vector2(-9,-26),p+Vector2(11,-42),Color(1,.91,.76,alpha),4,true)

func _in_view(point:Vector2) -> bool:
	return not bool(owner_panel.grid.room.get("scrolling",false)) or owner_panel.background_rect.grow(owner_panel.cell_size*.3).has_point(point)

func _foot(cell:Vector2i) -> Vector2:
	return owner_panel.cell_center(cell)

func _asset(key:String,anchor:Vector2,color:Color=Color.WHITE,frame:int=0) -> void:
	var definition: Dictionary = assets.get(key,{})
	var frames: Array = definition.get("frames",[])
	var path: String = str(frames[posmod(frame,frames.size())]) if not frames.is_empty() else str(definition.get("path",""))
	if path.is_empty(): return
	if not textures.has(path): textures[path]=load(path)
	var texture: Texture2D = textures[path]
	if texture==null: return
	var ratio: float = owner_panel.cell_size/float(definition.get("pixels_per_cell",100))
	var pivot: Array = definition.get("pivot",[texture.get_width()*.5,texture.get_height()*.5])
	var offset := Vector2(float(pivot[0]),float(pivot[1]))*ratio
	if definition.has("region"):
		var crop:Array=definition.region
		var region:=Rect2(float(crop[0]),float(crop[1]),float(crop[2]),float(crop[3]))
		draw_texture_rect_region(texture,Rect2(anchor-offset,region.size*ratio),region,color)
	else:
		draw_texture_rect(texture,Rect2(anchor-offset,texture.get_size()*ratio),false,color)

func _character(id:String,state:String,foot:Vector2,facing:float) -> void:
	var texture: Texture2D = sequences.texture(id,state)
	if texture==null: return
	var size: float = owner_panel.cell_size*1.83
	var placement: Dictionary = SpriteAnchor.placement(Vector2.ONE*size,sequences.cell(id),sequences.pivot(id),facing)
	draw_set_transform(foot,0,Vector2(float(placement.flip_x),1))
	draw_texture_rect_region(texture,placement.rect,sequences.source_rect(id,state,sequences.frame_at_time(id,state,owner_panel.elapsed)))
	draw_set_transform(Vector2.ZERO)

func _shadow(foot:Vector2,rx:float,ry:float) -> void:
	var points:=PackedVector2Array()
	for i in 24:
		var angle:float=TAU*float(i)/24
		points.append(foot+Vector2(cos(angle)*rx,sin(angle)*ry))
	draw_colored_polygon(points,Color(0,0,0,.36))

func _label(text:String,p:Vector2,active:bool) -> void:
	var font_size:=16
	var size:=FONT.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var origin:=p-Vector2(size.x*.5,0)
	draw_string_outline(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,5,Color("#0c080a"))
	draw_string(FONT,origin,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("#ffd24f") if active else Color("#f8eddd"))
