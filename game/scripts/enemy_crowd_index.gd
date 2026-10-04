extends RefCounted
## Frame-local body and reserved-slot neighborhoods. Dictionaries remain live;
## movement updates cell membership before the next unit takes its turn.
const CELL_SIZE:=96.0
var active:=false
var bodies:Dictionary={}
var slots:Dictionary={}
var body_cells:Dictionary={}
var slot_cells:Dictionary={}
var lanes:Dictionary={}
var lanes_ready:=false
const TERRAIN_CELL_SIZE:=192.0
var terrain_cells:Dictionary={}
var terrain_rows:Array[Dictionary]=[]

func begin(enemies:Array) -> void:
	active=true
	bodies.clear();slots.clear();body_cells.clear();slot_cells.clear()
	invalidate_lanes()
	for enemy:Dictionary in enemies:
		if float(enemy.hp)>0.0:
			update_body(enemy)
			update_slot(enemy)

func finish() -> void:
	active=false

func prepare_terrain(sim) -> void:
	terrain_cells.clear();terrain_rows.clear()
	for feature:Dictionary in sim.terrain_features:
		if not sim._feature_blocks(feature):continue
		var bounds:Rect2=sim._feature_collision_rect(feature)
		# Point collision also supports authored grid cells; segment collision
		# continues to use its original rect/ellipse narrow-phase geometry.
		for cell:Variant in feature.get("grid_cells",[]):bounds=bounds.merge(Rect2(cell))
		var index:=terrain_rows.size()
		terrain_rows.append({"feature":feature,"bounds":bounds})
		var low:=Vector2i(floori(bounds.position.x/TERRAIN_CELL_SIZE),floori(bounds.position.y/TERRAIN_CELL_SIZE))
		var high:=Vector2i(floori(bounds.end.x/TERRAIN_CELL_SIZE),floori(bounds.end.y/TERRAIN_CELL_SIZE))
		for y in range(low.y,high.y+1):
			for x in range(low.x,high.x+1):
				var key:=Vector2i(x,y)
				if not terrain_cells.has(key):terrain_cells[key]=[]
				terrain_cells[key].append(index)

func terrain_candidates(from:Vector2,to:Vector2,radius:float) -> Array[Dictionary]:
	var bounds:=Rect2(from,Vector2.ZERO).expand(to).grow(radius)
	var low:=Vector2i(floori(bounds.position.x/TERRAIN_CELL_SIZE),floori(bounds.position.y/TERRAIN_CELL_SIZE))
	var high:=Vector2i(floori(bounds.end.x/TERRAIN_CELL_SIZE),floori(bounds.end.y/TERRAIN_CELL_SIZE))
	var found:Dictionary={}
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var key:=Vector2i(x,y)
			for index:int in terrain_cells.get(key,[]):found[index]=true
	# Keep authored ordering when several obstacles intersect a step.
	var indices:=found.keys();indices.sort()
	var result:Array[Dictionary]=[]
	for index:int in indices:
		var row:Dictionary=terrain_rows[index]
		if bounds.intersects(row.bounds,true):result.append(row.feature)
	return result

func invalidate_lanes() -> void:
	lanes.clear();lanes_ready=false

func _cell(point:Vector2) -> Vector2i:
	return Vector2i(floori(point.x/CELL_SIZE),floori(point.y/CELL_SIZE))

func _put(enemy:Dictionary,point:Vector2,grid:Dictionary,membership:Dictionary) -> void:
	var id:=int(enemy.id)
	var cell:=_cell(point)
	if membership.has(id):
		var previous:Vector2i=membership[id]
		if previous==cell:return
		var old:Array=grid[previous]
		old.erase(enemy)
		if old.is_empty():grid.erase(previous)
	if not grid.has(cell):grid[cell]=[]
	grid[cell].append(enemy)
	membership[id]=cell

func update_body(enemy:Dictionary) -> void:
	if active and not bool(enemy.get("flying",false)):
		_put(enemy,enemy.pos,bodies,body_cells)

func update_slot(enemy:Dictionary) -> void:
	if active and enemy.has("melee_slot_pos"):
		_put(enemy,enemy.melee_slot_pos,slots,slot_cells)

func nearby(point:Vector2,reservations:bool=false) -> Array:
	var result:Array=[]
	var grid:Dictionary=slots if reservations else bodies
	var low:=_cell(point-Vector2(84,84))
	var high:=_cell(point+Vector2(84,84))
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var cell:=Vector2i(x,y)
			if grid.has(cell):result.append_array(grid[cell])
	return result
