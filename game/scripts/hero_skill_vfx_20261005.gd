extends RefCounted
## Rendering only: endpoints, timing, areas and recipients remain simulation-owned.
const Stage = preload("res://scripts/stage_projection.gd")
const Skills = preload("res://scripts/hero_signature_skills.gd")
const GLOW = preload("res://assets/vfx/combat_20261005/orb_glow.png")
const TRACE = preload("res://assets/vfx/combat_20261005/shot_glow.png")
const SALON_SHEET = preload("res://assets/vfx/hero_skills_20261005/furina_salon_familiars_v2.png")
const SALON_REGIONS: Array[Rect2] = [Rect2(90,91,605,583),Rect2(933,77,337,598),Rect2(1486,202,601,464)]
const WAVE_DARK := Color("#163d97")
const WATER := Color("#58cbf9")
const WATER_DEEP := Color("#337ede")
const SILK := Color("#72efd8")
const WHITE := Color("#f2ffff")
const SKILLS := ["salon_summon", "hydro_fanfare", "thread_shelter", "needle_barrage"]

static func handles_ability(hero: Dictionary, ability: Dictionary) -> bool:
	var character := str(hero.get("character_id", ""))
	return (character == "hero_03" and str(ability.get("kind", "")) in ["salon_summon", "hydro_fanfare"]) or (character == "hero_13" and str(ability.get("kind", "")) in ["thread_shelter", "needle_barrage"])

static func _lean(view) -> bool:
	return bool(view.reduced_effects) or view.sim.enemies.size() > 90

static func _age(effect: Dictionary) -> float:
	return maxf(0.0, float(effect.get("total", 1.0)) - float(effect.get("life", 1.0)))

static func _screen_direction(view, world: Vector2, direction: Vector2) -> Vector2:
	var result: Vector2 = (view.world_to_screen(world + direction.normalized() * 18.0) - view.world_to_screen(world)).normalized()
	return Vector2.RIGHT if result.is_zero_approx() else result

static func ground_point(view, center: Vector2, radius: float, angle: float, spread: float = 1.0) -> Vector2:
	var radii: Vector2 = view.sim.ability_area_screen_radii(center, radius) * spread
	if not view.sim.endless_mode:
		var world_origin := Stage.ground_center(center)
		var world_radii := Stage.ground_world_radii(center, radii)
		return view.world_to_screen(world_origin + Vector2(cos(angle) * world_radii.x, sin(angle) * world_radii.y))
	return view.world_to_screen(center) + Vector2(0, 8) + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)

static func ground_path(view, center: Vector2, radius: float, start: float = 0.0, span: float = TAU, spread: float = 1.0, segments: int = 32) -> PackedVector2Array:
	var path := PackedVector2Array()
	for index in segments + 1:
		path.append(ground_point(view, center, radius, start + span * float(index) / float(segments), spread))
	return path

static func _ground_arc(view, center: Vector2, radius: float, start: float, span: float, spread: float, color: Color, alpha: float, width: float = 1.1, glow: bool = false) -> void:
	if alpha <= 0.005 or spread <= 0.001: return
	var path := ground_path(view, center, radius, start, span, spread, 14 if absf(span) < PI else 36)
	if glow and not _lean(view): view.draw_polyline(path, Color(color, alpha * .12), width + 4.0, true)
	view.draw_polyline(path, Color(color, alpha), width, not _lean(view))

static func _glow(view, point: Vector2, size: Vector2, color: Color, alpha: float) -> void:
	if alpha <= 0.008 or _lean(view): return
	if view.has_method("emit_glow"):
		view.emit_glow(GLOW, point, size, color, alpha)
	else:
		view.draw_texture_rect(GLOW, Rect2(point - size * .5, size), false, Color(color, alpha))

static func _diamond(view, point: Vector2, direction: Vector2, length: float, width: float, color: Color, alpha: float) -> void:
	if alpha <= .008 or length <= .1: return
	var side := direction.orthogonal()
	view.draw_colored_polygon(PackedVector2Array([point + direction * length, point + side * width, point - direction * length * .65, point - side * width]), Color(color, alpha))
	view.draw_line(point - direction * length * .42, point + direction * length * .84, Color(WHITE, alpha * .86), .85, true)

static func _droplet(view, point: Vector2, direction: Vector2, size: float, alpha: float) -> void:
	_diamond(view, point, direction, size * 1.3, size * .40, WATER, alpha * .78)

static func _water_crystal(view, point: Vector2, direction: Vector2, length: float, width: float, alpha: float) -> void:
	# Filled asymmetric facets, not an outline or a circular sprite stamp.
	var side := direction.orthogonal()
	var shape := PackedVector2Array([point + direction * length, point + direction * length * .24 + side * width, point - direction * length * .73 + side * width * .66, point - direction * length, point - direction * length * .48 - side * width * .89, point + direction * length * .38 - side * width * .75])
	view.draw_colored_polygon(shape, Color(WATER, alpha * .91))
	view.draw_colored_polygon(PackedVector2Array([point + direction * length * .83, point + side * width * .76, point - direction * length * .74, point - side * width * .63]), Color(WATER.lightened(.56), alpha * .95))
	view.draw_colored_polygon(PackedVector2Array([point + direction * length * .77, point + side * width * .18, point - direction * length * .32, point - side * width * .29]), Color(WHITE, alpha))
	view.draw_line(shape[0], shape[1], Color(WHITE, alpha * .86), .95, true)
	view.draw_line(shape[4], shape[5], Color(WHITE, alpha * .64), .85, true)

static func _needle(view, point: Vector2, direction: Vector2, alpha: float, phase: float = 0.0) -> void:
	var side := direction.orthogonal()
	if not _lean(view):
		_glow(view, point - direction * 14.0, Vector2(48, 14), SILK, alpha * .25)
		view.draw_line(point - direction * 52.0, point - direction * 8.0, Color(SILK, alpha * .14), 4.5, true)
	view.draw_line(point - direction * 47.0, point - direction * 13.0, Color(SILK, alpha * .54), 1.0, true)
	view.draw_colored_polygon(PackedVector2Array([point, point - direction * 23.0 + side * 1.65, point - direction * 32.0, point - direction * 23.0 - side * 1.65]), Color(WHITE, alpha))
	view.draw_line(point - direction * 28.0, point, Color(WHITE, alpha), .95, true)
	var eye := point - direction * 28.0
	view.draw_arc(eye, 2.0, direction.angle(), direction.angle() + TAU, 10, Color(SILK, alpha * .74), .8, true)
	if not _lean(view):
		var thread := PackedVector2Array()
		for index in 7:
			var t := float(index) / 6.0
			thread.append(point - direction * (32.0 + t * 30.0) + side * sin(t * 6.0 + phase) * 1.8 * t)
		view.draw_polyline(thread, Color(SILK, alpha * .38), .85, true)

static func _water_shot(view, shot: Dictionary, alpha: float) -> void:
	var world := Vector2(shot.pos)
	var direction := _screen_direction(view, world, Vector2(shot.target) - Vector2(shot.source))
	var point: Vector2 = view.world_to_screen(world) + Vector2(0, -10)
	var index := int(shot.get("index", 0))
	var tail := point - direction * (22.0 + index * 4.0)
	if not _lean(view): view.draw_line(tail, point, Color(WATER, alpha * .14), 6.0, true)
	view.draw_line(tail, point, Color(WATER.lightened(.45), alpha * .64), 1.3, true)
	_glow(view, point, Vector2(40 + index * 5, 30 + index * 3), WATER, alpha * .51)
	_water_crystal(view, point, direction, 11.0 + index * 1.6, 7.0 + index * .65, alpha)
	view.draw_circle(point - direction * 1.2, 2.6 + index * .45, Color(WHITE, alpha * .97))

static func _water_burst(view, world: Vector2, radius: float, progress: float, strength: float = 1.0, index: int = 0) -> void:
	var alpha := pow(1.0 - clampf(progress, 0.0, 1.0), 1.6) * strength
	if alpha <= .008: return
	var point: Vector2 = view.world_to_screen(world) + Vector2(0, -9)
	_glow(view, point, Vector2(45, 34) * (1.0 + progress * .3), WATER, alpha * .55)
	if progress < .3:
		var core := (1.0 - progress / .3) * 5.0
		view.draw_circle(point, maxf(.25, core), Color(WHITE, alpha))
		_water_crystal(view, point, Vector2.UP, core * 1.8, maxf(.25, core), alpha)
	# Separate spray starts outside the victim's filled sprite silhouette;
	# the central glow stays at the actual hit, and every shard remains in its area.
	var spread := .45 + progress * .55
	# Only a faint ground ripple remains; separated filled spray carries the impact.
	_ground_arc(view, world, radius, float(index) * .3, PI * 1.3, spread, WATER, alpha * .19, .85, false)
	var count := 4 if _lean(view) else 8
	for particle in count:
		var angle := TAU * float(particle) / float(count) + float(index) * .3
		var p := ground_point(view, world, radius, angle, spread * (.50 + particle % 3 * .09)) - Vector2(0, sin(progress * PI) * (11.0 + particle % 3 * 5.0))
		var direction := Vector2.from_angle(angle - PI * .5)
		var length := (6.0 + particle % 3 * 2.2) * (1.0 - progress * .69)
		_water_crystal(view, p, direction, length, length * .52, minf(1.0, sqrt(alpha) * .88))
		if particle % 2 == 0: _glow(view, p, Vector2(20, 15), WATER, sqrt(alpha) * .32)

static func _needle_impact(view, effect: Dictionary) -> void:
	var progress := clampf(_age(effect) / .25, 0.0, 1.0)
	var alpha := pow(1.0 - progress, 1.7)
	if alpha <= .008: return
	var world := Vector2(effect.pos)
	var world_direction := Vector2(effect.get("direction", Vector2(effect.pos) - Vector2(effect.get("source", Vector2(effect.pos) - Vector2.RIGHT))))
	var direction := _screen_direction(view, world, world_direction)
	var side := direction.orthogonal()
	var point: Vector2 = view.world_to_screen(world) + Vector2(0, -12)
	_glow(view, point, Vector2(30, 17), SILK, alpha * .48)
	view.draw_line(point - direction * (7.0 + progress * 12.0), point + direction * (12.0 + progress * 22.0), Color(WHITE, alpha), 1.25, true)
	for index in (3 if _lean(view) else 5):
		var d := (direction + side * (float(index) - 2.0) * .45).normalized()
		var p := point + d * (6.0 + progress * 23.0)
		_diamond(view, p, d, 5.0 * (1.0 - progress), 1.15, SILK, alpha * .8)

static func needle_preview_outline(view, hero: Dictionary, ability: Dictionary, target: Vector2) -> PackedVector2Array:
	var source := Vector2(hero.pos)
	var direction := (target - source).normalized()
	if direction.is_zero_approx(): direction = Vector2.RIGHT
	var normal := direction.orthogonal()
	var radius := _ability_radius(view, ability)
	var end := source + direction * radius
	var launch := source - direction * 20.0
	var converge := source + direction * 125.0
	var polygon := PackedVector2Array()
	for point: Vector2 in [launch + normal * 80.0, converge + normal * 18.0, end + normal * 18.0, end - normal * 18.0, converge - normal * 18.0, launch - normal * 80.0, launch + normal * 80.0]:
		polygon.append(view.world_to_screen(point))
	return polygon

static func _ability_radius(view, ability: Dictionary) -> float:
	var radius := float(ability.get("radius", 170.0)) * (1.0 + float(view.sim.skill_area_bonus))
	if str(ability.get("kind", "")) in ["hydro_fanfare", "needle_barrage"] and view.sim.run_state.equipped_relics.has("relic_resonant_core"):
		radius *= 1.2
	return radius

static func draw_preview(view, hero: Dictionary, ability: Dictionary, target: Vector2) -> bool:
	if not handles_ability(hero, ability): return false
	var kind := str(ability.kind)
	if kind == "needle_barrage":
		var outline := needle_preview_outline(view, hero, ability, target)
		view.draw_colored_polygon(outline, Color(SILK, .045))
		view.draw_polyline(outline, Color(SILK, .78), 1.05, true)
		return true
	var center := Vector2(hero.pos) if kind in ["thread_shelter", "hydro_fanfare"] else Skills.target_point(view.sim, hero, ability, target)
	var radius := _ability_radius(view, ability)
	var color := SILK if kind == "thread_shelter" else WATER
	_ground_arc(view, center, radius, 0, TAU, 1.0, color, .69, 1.15)
	for index in 4:
		var p := ground_point(view, center, radius, float(index) * PI * .5)
		view.draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Color(WHITE, .76), 1.25, true)
	if kind == "salon_summon":
		var preview_zone := {"pos":center, "area":radius, "elapsed":0.0}
		for index in 3: salon_actor(view, view.world_to_screen(Skills.salon_position(preview_zone, index)) + Vector2(0, -10), index, .5)
	return true

static func salon_actor(view, point: Vector2, index: int, alpha: float, elapsed: float = -1.0, facing: float = 1.0, attack: float = 0.0) -> void:
	if alpha <= .01: return
	var phase: float = view.clock if elapsed < 0.0 else elapsed
	var species := posmod(index, 3)
	var region := SALON_REGIONS[species]
	var height: float = [53.0,58.0,52.0][species]
	var width := region.size.x / region.size.y * height
	var recoil := sin(clampf(attack,0.0,1.0) * PI)
	var direction := -1.0 if facing < 0.0 else 1.0
	var floating := sin(phase * 2.15 + species * 1.9) * 3.0
	var pivot := point + Vector2(-direction * recoil * 4.0,floating + recoil * 1.5)
	_glow(view,pivot-Vector2(0,height*.45),Vector2(width+12,height+10),WATER,alpha*.17)
	var lean := (sin(phase*1.35+species)*.042-recoil*.10)*direction
	var turn_width := (.94 + sin(phase*.75+species)*.06)*(1.0-recoil*.07)
	view.draw_set_transform(pivot,lean,Vector2(direction*turn_width,1.0+recoil*.05))
	view.draw_texture_rect_region(SALON_SHEET,Rect2(-width*.5,-height+5,width,height),region,Color(1,1,1,alpha))
	view.draw_set_transform(Vector2.ZERO)
	# The ground contact remains tiny; the generated solid silhouette carries identity.
	view.draw_arc(point+Vector2(0,8),width*.29,0,PI,14,Color(WATER,alpha*.25),.9,true)

static func _water_curtain(view, center: Vector2, radius: float, phase: float, alpha: float) -> void:
	for sector in (2 if _lean(view) else 3):
		var angle := phase + float(sector) * TAU / 3.0
		var base := ground_path(view,center,radius,angle,.90,.97,10)
		var rim := PackedVector2Array()
		var mid := PackedVector2Array()
		for index in base.size():
			var crest := sin(float(index)/float(base.size()-1)*PI)
			var height := 8.0+crest*17.0
			rim.append(base[index]-Vector2(0,height))
			mid.append(base[index]-Vector2(0,height*.42))
		for index in base.size()-1:
			if absf(base[index].x-base[index+1].x)<=.035: continue
			if not _lean(view):
				view.draw_colored_polygon(PackedVector2Array([base[index],base[index+1],mid[index+1],mid[index]]),Color(WAVE_DARK,alpha*.70))
			view.draw_colored_polygon(PackedVector2Array([mid[index],mid[index+1],rim[index+1],rim[index]]),Color(WATER,alpha*.60))
		view.draw_polyline(rim,Color(WHITE,alpha*.71),1.55,true)
		view.draw_polyline(mid,Color(WATER_DEEP,alpha*.67),1.0,true)
		if not _lean(view):
			for index in [3,7]:
				_water_crystal(view,rim[index]-Vector2(0,4),Vector2.UP,4.0,2.3,alpha*.58)
				_glow(view,rim[index],Vector2(24,18),WATER,alpha*.28)

static func _fanfare_release(view, center: Vector2, radius: float, age: float) -> void:
	var progress := clampf(age/.50,0.0,1.0)
	if progress >= 1.0: return
	var alpha := 1.0-smoothstep(.42,1.0,progress)
	var spread := .36+smoothstep(0.0,.85,progress)*.64
	var count := 18 if _lean(view) else 30
	var base := ground_path(view,center,radius,0,TAU,spread,count)
	var rim := PackedVector2Array()
	var middle := PackedVector2Array()
	for index in base.size():
		var theta := float(index)*TAU/float(count)
		var height := (24.0+pow(sin(theta*3.0+progress*2.3),2.0)*25.0)*(.55+sin(progress*PI)*.45)
		rim.append(base[index]-Vector2(0,height))
		middle.append(base[index]-Vector2(0,height*.48))
	for index in base.size()-1:
		if absf(base[index].x-base[index+1].x)<=.035: continue
		view.draw_colored_polygon(PackedVector2Array([base[index],base[index+1],middle[index+1],middle[index]]),Color(WAVE_DARK,alpha*.64))
		view.draw_colored_polygon(PackedVector2Array([middle[index],middle[index+1],rim[index+1],rim[index]]),Color(WATER,alpha*.76))
	view.draw_polyline(rim,Color(WHITE,alpha*.97),2.25,true)
	var blade_count := 4 if _lean(view) else 8
	for index in blade_count:
		var theta := float(index)*TAU/float(blade_count)
		var foot := ground_point(view,center,radius,theta,spread*.84)
		var height := (26.0+index%3*9.0)*sin(progress*PI)
		if height < .3: continue
		var half_width := 7.0+index%2*3.0
		var tip := foot+Vector2(sin(theta)*5.0,-height)
		view.draw_colored_polygon(PackedVector2Array([foot-Vector2(half_width,0),foot+Vector2(-3,-height*.45),tip,foot+Vector2(half_width,0)]),Color(WATER_DEEP,alpha*.92))
		view.draw_colored_polygon(PackedVector2Array([foot-Vector2(half_width*.55,0),tip+Vector2(1,2),foot+Vector2(half_width*.8,0)]),Color(WATER.lightened(.15),alpha*.96))
		view.draw_line(foot-Vector2(half_width*.5,0),tip,Color(WHITE,alpha*.96),1.55,true)
		_water_crystal(view,tip-Vector2(0,7+progress*10),Vector2.UP,5.2*(1.0-progress*.55),3.0,alpha*.86)
		_glow(view,tip,Vector2(32,25),WATER,alpha*.54)

static func _shelter_mark(view, world: Vector2, alpha: float, phase: float) -> void:
	var foot: Vector2 = view.world_to_screen(world) + Vector2(0, 8)
	_glow(view, foot - Vector2(0, 11), Vector2(46, 39), SILK, alpha * .16)
	for side in [-1.0, 1.0]:
		var seam := PackedVector2Array([foot + Vector2(side * 17, -1), foot + Vector2(side * 21, -14), foot + Vector2(side * 12, -29), foot + Vector2(side * 5, -31)])
		view.draw_polyline(seam, Color(SILK, alpha * .63), 1.1, true)
		var glint := foot + Vector2(side * 19, -11 + sin(phase) * 2)
		_diamond(view, glint, Vector2.UP, 2.5, .75, WHITE, alpha * .64)
	view.draw_arc(foot, 13.0, 0, PI, 18, Color(SILK, alpha * .38), 1.0, true)

static func _fanfare_mark(view, world: Vector2, alpha: float, phase: float) -> void:
	var foot: Vector2 = view.world_to_screen(world) + Vector2(0, 8)
	for index in 3:
		var angle := phase + float(index) * TAU / 3.0
		var point := foot + Vector2(cos(angle) * 15.0, sin(angle) * 5.0 - 9.0)
		_droplet(view, point, Vector2.UP, 2.0, alpha * .63)

static func draw_event(view, effect: Dictionary) -> bool:
	var kind := str(effect.get("kind", ""))
	if kind in ["signature_needle_hit", "gwen_needle_hit"]:
		_needle_impact(view, effect)
		return true
	if kind == "signature_needle_volley":
		var alpha := 1.0 - smoothstep(.02, .18, _age(effect))
		var point: Vector2 = view.world_to_screen(effect.pos) + Vector2(0, -14)
		_glow(view, point, Vector2(30, 19), SILK, alpha * .48)
		for index in 3: _diamond(view, point + Vector2(6 + index * 4, (index - 1) * 4), Vector2.RIGHT, 3.0, 1.0, WHITE, alpha * .75)
		return true
	if kind == "signature_salon_hit":
		_water_burst(view, Vector2(effect.pos), float(effect.get("radius", 38.0)), clampf(_age(effect) / .36, 0.0, 1.0), .8, int(effect.get("index", 0)))
		return true
	if kind == "signature_heal":
		var progress := clampf(_age(effect) / .47, 0.0, 1.0)
		var alpha := 1.0 - progress
		for target in effect.get("targets", []):
			_fanfare_mark(view, Vector2(target), alpha, float(view.clock) * .6)
			var point: Vector2 = view.world_to_screen(Vector2(target)) + Vector2(0, -8)
			_glow(view, point, Vector2(24, 20), WATER, alpha * .26)
			for index in 3: _droplet(view, point + Vector2((index - 1) * 7.0, -progress * 18.0 - index * 4), Vector2.UP, 2.4 * (1.0 - progress), alpha)
		return true
	if kind in ["gwen_shelter_aura", "furina_fanfare_allies"]:
		var alpha := smoothstep(0.0, .45, float(effect.life)) * smoothstep(0.0, .20, _age(effect))
		if kind == "furina_fanfare_allies": alpha *= 1.0 - smoothstep(.22, .72, _age(effect))
		var owner_id := int(effect.get("hero_id", -1))
		var center := Vector2(view.sim.heroes[owner_id].pos) if owner_id >= 0 and owner_id < view.sim.heroes.size() else Vector2(effect.pos)
		var radius := float(effect.get("radius", 340.0))
		for value in effect.get("ally_ids", []):
			var id := int(value)
			if id < 0 or id >= view.sim.heroes.size(): continue
			var hero: Dictionary = view.sim.heroes[id]
			if float(hero.hp) <= 0.0 or not bool(hero.get("deployed", false)): continue
			if kind == "gwen_shelter_aura":
				if float(hero.get("invulnerable_timer", 0.0)) > 0.0: _shelter_mark(view, Vector2(hero.pos), alpha, view.clock * 3.0)
			else:
				if view.sim.is_in_ability_area(center, Vector2(hero.pos), radius): _fanfare_mark(view, Vector2(hero.pos), alpha * .72, view.clock * .8)
		return true
	if not kind.begins_with("gwen_") and not kind.begins_with("furina_"): return false
	var base := kind.trim_suffix("_cast").trim_suffix("_impact")
	if base not in ["gwen_thread_shelter", "gwen_needle_barrage", "furina_salon_summon", "furina_hydro_fanfare"]: return false
	var casting := kind.ends_with("_cast")
	var progress := clampf(_age(effect) / maxf(.01, float(effect.get("total", 1.0))), 0.0, 1.0)
	var alpha := sin(progress * PI * .75) if casting else 1.0 - smoothstep(.06, .43, _age(effect))
	var center := Vector2(effect.pos)
	var radius := float(effect.get("radius", 260.0))
	var source := Vector2(effect.get("caster_pos", center))
	if base == "gwen_needle_barrage":
		if casting:
			var direction := (center - source).normalized()
			if direction.is_zero_approx(): direction = Vector2.RIGHT
			var side := direction.orthogonal()
			for index in 5:
				var offset: float = [0.0, -34.0, 34.0, -62.0, 62.0][index]
				var world := source - direction * (23.0 + (1.0 - progress) * 15.0) + side * offset
				_needle(view, view.world_to_screen(world) + Vector2(0, -14), _screen_direction(view, world, direction), alpha * .65, view.clock * 3 + index)
		return true # Live shot state renders the actual volley, never a second fake impact ring.
	if base == "gwen_thread_shelter":
		_ground_arc(view, center, radius, -.8 + progress * .6, 1.3, 1.0, SILK, alpha * .62, 1.0, true)
		_ground_arc(view, center, radius, PI - .8 + progress * .6, 1.3, 1.0, WHITE, alpha * .5, .9)
		if not casting:
			for index in 4:
				var point := ground_point(view, center, radius, float(index) * PI * .5, .8)
				_diamond(view, point - Vector2(0, 4), Vector2.UP, 3.0, 1.0, SILK, alpha * .68)
		return true
	if base == "furina_salon_summon":
		if casting:
			_ground_arc(view, center, radius, view.clock * .6, PI * 1.1, .96, WATER, alpha * .43, 1.05)
			var anticipated := {"pos":center, "area":radius, "elapsed":0.0}
			for index in 3:
				var point: Vector2 = view.world_to_screen(Skills.salon_position(anticipated, index)) + Vector2(0, -10)
				salon_actor(view, point, index, alpha * .64)
				_glow(view, point - Vector2(0, 6), Vector2(39, 28), WATER, alpha * .42)
				_water_crystal(view, point - Vector2(0, 5), Vector2.UP, 5.0, 3.4, alpha * .85)
		else:
			_water_burst(view, center, radius, clampf(_age(effect) / .40, 0.0, 1.0), .52)
		return true
	if not casting: return true # The live signature zone owns the entire release.
	# Fanfare opens from the real footprint; the persistent water curtain lives in zone state.
	_ground_arc(view, center, radius, 0, TAU, .16 + minf(1.0, progress * 4.0) * .84, WATER, alpha * .66, 1.2, true)
	if casting:
		# All solid effects render behind actors, so charge beside the hand rather
		# than behind the opaque torso; the face and the true footprint stay clear.
		var point: Vector2 = view.world_to_screen(source) + Vector2(42, -26)
		_glow(view, point, Vector2(49, 37), WATER, alpha * .66)
		_water_crystal(view, point, Vector2.UP, 9.0 + progress * 3.0, 6.3, alpha)
		for index in 3:
			var offset := Vector2.from_angle(view.clock * 2 + index * TAU / 3) * Vector2(23, 12)
			_water_crystal(view, point + offset, Vector2.UP, 4.3, 2.5, alpha * .72)
	# Signature skills do not emit ultimate_impact; the live zone owns its release.
	# Consume legacy impact events without duplicating the same release burst.
	return true

static func draw_zone(view, zone: Dictionary) -> bool:
	var kind := str(zone.get("kind", ""))
	var visual := str(zone.get("visual", ""))
	if kind not in ["salon_summon", "hydro_fanfare", "needle_barrage"] and visual not in ["gwen_needles", "furina_fanfare"]: return false
	var elapsed := float(zone.get("elapsed", maxf(0.0, 12.0 - float(zone.get("life", 0.0)))))
	var center := Vector2(zone.pos)
	var radius := float(zone.get("area", 260.0))
	if kind == "hydro_fanfare" and elapsed < .50 and not bool(zone.get("cancelled",false)):
		_fanfare_release(view,center,radius,elapsed)
	var alpha := smoothstep(0.0, .16, elapsed) * smoothstep(0.0, .45, float(zone.get("life", 0.0)))
	if bool(zone.get("cancelled", false)): alpha *= clampf(float(zone.life) / .4, 0.0, 1.0)
	if alpha <= .008: return true
	if kind == "needle_barrage" and (visual != "gwen_needles" or bool(zone.get("signature", false))):
		var direction := Vector2(zone.get("direction", Vector2.RIGHT))
		for shot: Dictionary in zone.get("shots", []):
			var fade := 1.0 - smoothstep(0.0, .12, elapsed - float(shot.get("ended_at", elapsed))) if bool(shot.get("done", false)) else 1.0
			if fade <= .01: continue
			var world := Vector2(shot.pos)
			_needle(view, view.world_to_screen(world) + Vector2(0, -14), _screen_direction(view, world, direction), alpha * fade, elapsed * 8.0 + int(shot.get("index", 0)))
		return true
	if kind == "salon_summon":
		_ground_arc(view, center, radius, 0, TAU, 1.0, WATER, alpha * .19, .9)
		for index in 3:
			var world := Skills.salon_position(zone, index)
			var point: Vector2 = view.world_to_screen(world) + Vector2(0,-10)
			var facing := 1.0
			var attack := 0.0
			for shot: Dictionary in zone.get("shots",[]):
				if int(shot.get("index",-1)) != index: continue
				facing = signf(Vector2(shot.target).x-world.x)
				attack = maxf(attack,1.0-clampf(float(shot.get("age",0.0))/.28,0.0,1.0))
			salon_actor(view,point,index,alpha,elapsed,facing,attack)
		for shot: Dictionary in zone.get("shots", []):
			if not bool(shot.get("done", false)): _water_shot(view, shot, alpha)
		return true
	if kind == "hydro_fanfare" or visual == "furina_fanfare":
		_ground_arc(view, center, radius, 0, TAU, 1.0, WATER, alpha * .23, .9)
		_water_curtain(view, center, radius, elapsed * .60, alpha)
		# Every two seconds follows the actual heal cadence rather than a permanent bright strobe.
		var beat := fposmod(elapsed, 2.0)
		if beat < .43:
			_ground_arc(view, center, radius, 0, TAU, .26 + beat / .43 * .74, WHITE, alpha * (1.0 - beat / .43) * .26, .85)
		for hero: Dictionary in view.sim.heroes:
			if float(hero.hp) > 0.0 and bool(hero.get("deployed", false)) and view.sim.is_in_ability_area(center, Vector2(hero.pos), radius):
				_fanfare_mark(view, Vector2(hero.pos), alpha * .48, elapsed * .8)
		return true
	# Legacy stationary needle zone fallback, kept understated and constrained to its true ellipse.
	_ground_arc(view, center, radius, elapsed * .6, 1.1, 1.0, SILK, alpha * .33, .95)
	return true

static func draw_orbit(view, orbital: Dictionary, hero: Dictionary) -> bool:
	if str(orbital.get("visual", "")) != "salon": return false
	var count := mini(12, maxi(1, int(orbital.get("count", 1))))
	var fade := smoothstep(0.0, .45, float(orbital.get("life", 0.0)))
	for index in count:
		var angle: float = view.clock * 2.8 + float(index) * TAU / float(count)
		var point := ground_point(view, Vector2(hero.pos), float(orbital.get("radius", 230.0)), angle)
		salon_actor(view, point, index, fade * .9)
	return true
