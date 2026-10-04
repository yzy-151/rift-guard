extends RefCounted
## Manual workshop orders navigate to their own goal, independently of the
## hero pursuit fields used by autonomous endless enemies.

static func clear(enemy:Dictionary) -> void:
	for key:String in ["workshop_nav_field","workshop_nav_revision","workshop_nav_goal","workshop_waypoint"]:enemy.erase(key)

static func waypoint(sim,enemy:Dictionary,goal:Vector2,radius:float) -> Vector2:
	var current:=Vector2(enemy.pos)
	if not sim.terrain_line_blocked(current,goal,radius):
		enemy.erase("workshop_waypoint")
		return goal
	if int(enemy.get("workshop_nav_revision",-1))!=sim.endless_nav_revision or Vector2(enemy.get("workshop_nav_goal",Vector2.INF))!=goal:
		clear(enemy)
		var target_cell:Vector2i=sim._nearest_open_endless_nav_cell(goal,radius)
		if not sim._endless_nav_cell_open(target_cell):return current
		var distances:=PackedInt32Array()
		distances.resize(sim.endless_nav_columns*sim.endless_nav_rows);distances.fill(-1)
		var target_index:int=sim._endless_nav_index(target_cell)
		distances[target_index]=0
		var queue:Array[int]=[target_index];var cursor:=0
		while cursor<queue.size():
			var index:=queue[cursor];cursor+=1
			var cell:=Vector2i(index%sim.endless_nav_columns,index/sim.endless_nav_columns)
			for offset:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next:=cell+offset
				if not sim._endless_nav_cell_open(next):continue
				var next_index:int=sim._endless_nav_index(next)
				if distances[next_index]>=0:continue
				distances[next_index]=distances[index]+1;queue.append(next_index)
		enemy.workshop_nav_field=distances
		enemy.workshop_nav_revision=sim.endless_nav_revision
		enemy.workshop_nav_goal=goal
	if enemy.has("workshop_waypoint"):
		var cached:=Vector2(enemy.workshop_waypoint)
		if current.distance_squared_to(cached)>4.0 and not sim.terrain_line_blocked(current,cached,radius):return cached
		enemy.erase("workshop_waypoint")
	var field:PackedInt32Array=enemy.workshop_nav_field
	var cell:Vector2i=sim._nearest_open_endless_nav_cell(current,radius)
	if not sim._endless_nav_cell_open(cell):return current
	var remaining:=field[sim._endless_nav_index(cell)]
	if remaining<0:return current
	var best:=remaining
	var result:=current
	for offset:Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var next:=cell+offset
		if not sim._endless_nav_cell_open(next):continue
		var next_distance:=field[sim._endless_nav_index(next)]
		if next_distance<0 or next_distance>=best:continue
		var candidate:Vector2=sim._endless_nav_cell_center(next)
		if sim.terrain_line_blocked(current,candidate,radius):continue
		best=next_distance;result=candidate
	if result==current:
		var center:Vector2=sim._endless_nav_cell_center(cell)
		if not sim.terrain_line_blocked(current,center,radius):result=center
	if result!=current:enemy.workshop_waypoint=result
	return result
