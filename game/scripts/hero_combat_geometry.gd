extends RefCounted
## One world-space footprint for aiming, impact checks and persistent fields.
const SHAPES := {
	"blade_wave":"line",
	"columbia_tide_ring":"ring", "heal_gust":"cone", "healing_surge":"line",
	"storm_field":"cross", "chimera":"line", "sonic_wave":"cone",
	"fate_symphony":"lanes", "frost_bloom":"cross", "frozen_forest":"rectangle",
	"renewing_breeze":"rectangle", "needle_barrage":"line", "wind_cut":"rows"
}
const DELIVERY := {"traveler":"melee_cone","hero_01":"homing","hero_02":"boomerang","hero_03":"lob","hero_04":"piercing","hero_06":"homing","hero_07":"fan","hero_08":"piercing","hero_10":"boomerang","hero_13":"melee_cone"}

static func rectangle(center: Vector2, direction: Vector2, length: float, width: float) -> PackedVector2Array:
	var a := direction * length * 0.5
	var b := direction.orthogonal() * width * 0.5
	return PackedVector2Array([center-a-b,center+a-b,center+a+b,center-a+b])

static func geometry(sim, hero: Dictionary, ability: Dictionary, target: Vector2) -> Dictionary:
	var kind := str(ability.get("kind",""))
	var shape := str(ability.get("shape",SHAPES.get(kind,"circle")))
	var origin := Vector2(hero.pos)
	var ultimate: bool=kind==str(hero.get("ultimate",{}).get("kind","")) or (kind.begins_with("traveler_") and kind.ends_with("_e"))
	var area_scale: float=1.0 if kind=="basic_snip" else (1.0+sim.skill_area_bonus)*(1.2 if ultimate and sim.run_state.equipped_relics.has("relic_resonant_core") else 1.0)
	var radius: float = float(ability.get("radius",180.0)) * area_scale
	var direction := (target-origin).normalized()
	if direction.length_squared() < 0.1: direction = Vector2(float(hero.get("facing",1.0)),0)
	var length: float = float(ability.get("length",float(ability.get("radius",180.0)) * 2.0)) * area_scale
	var width: float = float(ability.get("width",maxf(64.0,float(ability.get("radius",180.0)) * 0.42))) * area_scale
	var polygons: Array[PackedVector2Array] = []
	if kind in ["columbia_tide_ring","hydro_fanfare","thread_shelter","heal_gust"]: target = origin
	match shape:
		"line":
			polygons.append(rectangle(origin+direction*length*0.5,direction,length,width))
		"cross":
			polygons.append(rectangle(target,Vector2.RIGHT,length,width))
			polygons.append(rectangle(target,Vector2.DOWN,length,width))
		"rectangle": polygons.append(rectangle(target,Vector2.RIGHT,length,radius))
		"lanes":
			for lane in [-1,0,1]:
				polygons.append(rectangle(origin+direction*length*0.5+direction.orthogonal()*float(lane)*width*1.8,direction,length,width))
		"rows":
			var row := clampi(floori((origin.y-sim.GRID_ORIGIN.y)/sim.GRID_CELL_SIZE.y),1,sim.GRID_ROWS-2)
			var left: float = sim.active_view_rect.position.x if sim.endless_mode else sim.GRID_ORIGIN.x
			var right: float = sim.active_view_rect.end.x if sim.endless_mode else sim.GRID_ORIGIN.x+sim.GRID_COLUMNS*sim.GRID_CELL_SIZE.x
			for offset in [-1,0,1]:
				polygons.append(rectangle(Vector2((left+right)*0.5,sim.GRID_ORIGIN.y+(row+offset+0.5)*sim.GRID_CELL_SIZE.y),Vector2.RIGHT,right-left,sim.GRID_CELL_SIZE.y))
		"cone":
			var fan := PackedVector2Array([origin])
			var spread := deg_to_rad(float(ability.get("angle",84.0))) * 0.5
			for i in 21: fan.append(origin+direction.rotated(lerpf(-spread,spread,i/20.0))*length)
			polygons.append(fan)
		_:
			var circle := PackedVector2Array()
			var radii: Vector2=sim.ability_area_screen_radii(target,radius)
			for i in 48: circle.append(target+Vector2.from_angle(i*TAU/48.0)*radii+(Vector2(0,8) if sim.endless_mode else Vector2.ZERO))
			polygons.append(circle)
	return {"shape":shape,"origin":origin,"target":target,"radius":radius,"width":width,"length":length,"inner_radius":radius*0.28 if shape=="ring" else 0.0,"polygons":polygons}

static func contains(sim, geometry: Dictionary, point: Vector2) -> bool:
	var shape := str(geometry.get("shape","circle"))
	if shape=="cone" and Vector2(geometry.origin).distance_squared_to(point)<=1.0: return true
	if shape in ["circle","ring"]:
		return sim.is_in_ability_area(geometry.target,point,float(geometry.radius)) and (shape!="ring" or not sim.is_in_ability_area(geometry.target,point,float(geometry.inner_radius)))
	for polygon: PackedVector2Array in geometry.polygons:
		if Geometry2D.is_point_in_polygon(point,polygon): return true
	return false

static func hit(sim, hero: Dictionary, geometry: Dictionary, power: float, element: String, control: String = "") -> int:
	var count := 0
	for enemy: Dictionary in sim.enemies.duplicate():
		if enemy.hp<=0 or not sim._ability_target_visible(enemy.pos) or not contains(sim,geometry,enemy.pos): continue
		var bonus := 1.35 if control=="shatter" and float(enemy.get("frozen_timer",0.0))>0 else 1.0
		sim.apply_hit(enemy,power*bonus,element,int(hero.id))
		if control in ["freeze","shatter"]: enemy.frozen_timer=maxf(float(enemy.get("frozen_timer",0.0)),1.6)
		elif control=="pull": enemy.pos=Vector2(enemy.pos).move_toward(geometry.target,32.0)
		elif control=="knockback": sim._push_enemy_grid_cells(enemy,geometry.origin,1)
		count+=1
	return count

static func heal(sim, geometry: Dictionary, amount: float, energy: float = 0.0) -> int:
	var count := 0
	for ally: Dictionary in sim.heroes:
		if ally.hp<=0 or not bool(ally.deployed) or not contains(sim,geometry,ally.pos): continue
		var value := minf(float(ally.max_hp)-float(ally.hp),amount)
		ally.hp+=value
		ally.slime_slow_timer=0.0
		ally.energy=minf(float(ally.max_energy),float(ally.energy)+energy)
		if value>0: sim.events.append({"kind":"heal","pos":ally.pos,"value":ceili(value)})
		count+=1
	return count
