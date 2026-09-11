extends Node2D
signal stage_exit_finished
## All effects are cosmetic; gameplay remains in CombatSimulation.
const Stage = preload("res://scripts/stage_projection.gd")
const WORLD = Rect2(40, 140, 1200, 440)
const Sim = preload("res://scripts/combat_simulation.gd")
const ReusableEffectPool = preload("res://scripts/reusable_effect_pool.gd")
const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")
const INK = Color("#0c1017")
const TEAL = Color("#8fdbc8")
const RED = Color("#d66769")
var sim
var selected_id: int = 0
var reduced_effects: bool = false
var effects: Array[Dictionary] = []
var effect_pool = ReusableEffectPool.new()
var clock: float = 0.0
var shot_flashes: Dictionary = {}
var hero_attack_visuals: Dictionary = {}
var hero_down_visuals: Dictionary = {}
var projectile_trails: Dictionary = {}
var sprite_pivots: Dictionary = {}
var enemy_visual_textures: Dictionary = {}
var route_previews: Dictionary = {}
var spawn_portals: Dictionary = {}
var current_actor_transform := Transform2D.IDENTITY
var stage_exit_active := false
var stage_exit_phase := ""
var stage_exit_timer := 0.0
var stage_exit_character_id := ""
var stage_exit_character_name := ""
var stage_exit_element := ""
var stage_exit_newcomer_pos := Vector2(1125, 360)
const STAGE_EXIT_DOOR := Vector2(1135, 360)
const STAGE_EXIT_MEET := Vector2(930, 360)
var base_flash: float = 0.0
var shake_trauma: float = 0.0
var skill_targeting: bool = false
var deploy_preview_active: bool = false
var deploy_preview_id: int = -1
var deploy_preview_point: Vector2 = Vector2.ZERO
var skill_point: Vector2 = Vector2(760, 360)
var camera_center: Vector2 = Vector2(640, 360)
var atlas: Texture2D = preload("res://assets/tiny-dungeon.png")
var hell_stage_one: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0002.png")
var hell_stage_two: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0003.png")
var hell_stage_three: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0005.png")
var crystal_texture: Texture2D = preload("res://assets/world/crystal-growth.svg")
var furina_texture: Texture2D = preload("res://assets/characters/furina/furina-chibi-v1-alpha.png")
var traveler_idle_atlas: Texture2D = preload("res://assets/characters/traveler_v18/idle.png")
var traveler_run_atlas: Texture2D = preload("res://assets/characters/traveler_v18/run.png")
var traveler_attack_atlas: Texture2D = preload("res://assets/characters/traveler_v18/attack.png")
var traveler_death_atlas: Texture2D = preload("res://assets/characters/traveler_v18/death.png")
var hilichurl_run_atlas: Texture2D = preload("res://assets/enemies/hilichurl_v18/run.png")
const TRAVELER_CELL := 288.0
const TRAVELER_FRAMES := 48
const MONSTER_CELL := 256.0
const MONSTER_FRAMES := 30
const HERO_FOOT_OFFSET := 8.0
const ENEMY_FOOT_OFFSET := 12.0
var furina_actor
var font: SystemFont
var slash_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_01.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_02.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_03.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_04.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_05.png"),
	preload("res://assets/vfx/third_party/cethiel_weapon_slash/files/Alternative 1/1/Alternative_1_06.png")
]
var muzzle_fire_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_1.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_2.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Fire/Muzzle Large Fire_3.png")
]
var muzzle_ion_frames: Array[Texture2D] = [
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_1.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_2.png"),
	preload("res://assets/vfx/third_party/reactorcore_muzzle/files/RC Art - Muzzle Effects/Sprites/Muzzle Large Ion/Muzzle Large Ion_3.png")
]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_pivots = SpriteAnchor.load_catalog()
	_load_enemy_visuals()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	build_furina_actor()

func _load_enemy_visuals() -> void:
	enemy_visual_textures.clear()
	if sim == null or sim.database == null:
		return
	for enemy_id: String in sim.database.enemy_visuals:
		var definition: Dictionary = sim.database.enemy_visuals[enemy_id]
		var texture: Resource = ResourceLoader.load(str(definition.get("sprite", "")))
		if texture is Texture2D:
			enemy_visual_textures[enemy_id] = texture

func advance(dt: float) -> void:
	clock += dt
	if sim != null and sim.endless_mode and not sim.heroes.is_empty():
		camera_center = camera_center.lerp(sim.heroes[0].pos, 1.0 - exp(-dt * 7.0))
	if stage_exit_active:
		_advance_stage_exit(dt)
	for id in shot_flashes:
		shot_flashes[id] = maxf(0.0, shot_flashes[id] - dt)
	for id in hero_attack_visuals.keys():
		hero_attack_visuals[id].elapsed = float(hero_attack_visuals[id].elapsed) + dt
		if float(hero_attack_visuals[id].elapsed) >= float(hero_attack_visuals[id].duration):
			hero_attack_visuals.erase(id)
	if sim != null:
		for hero: Dictionary in sim.heroes:
			if hero.hp <= 0.0:
				hero_down_visuals[hero.id] = float(hero_down_visuals.get(hero.id, 0.0)) + dt
			else:
				hero_down_visuals.erase(hero.id)
		_update_projectile_trails()
	base_flash = maxf(0.0, base_flash - dt)
	shake_trauma = maxf(0.0, shake_trauma - dt * 3.8)
	position = Vector2(sin(clock * 91.0), cos(clock * 73.0)) * shake_trauma * 5.0
	if sim != null and sim.performance_budget != null:
		reduced_effects = sim.performance_budget.quality_scale < 0.75
	var live_effects: Array[Dictionary] = []
	for effect: Dictionary in effects:
		effect.life -= dt
		if effect.life > 0.0: live_effects.append(effect)
		else: effect_pool.release(effect)
	effects = live_effects
	for route_id: String in route_previews.keys():
		route_previews[route_id].life = float(route_previews[route_id].life) - dt
		if float(route_previews[route_id].life) <= 0.0:
			route_previews.erase(route_id)
	for route_id: String in spawn_portals.keys():
		spawn_portals[route_id].life = float(spawn_portals[route_id].life) - dt
		if float(spawn_portals[route_id].life) <= 0.0:
			spawn_portals.erase(route_id)
	sync_furina_actor(dt)
	queue_redraw()

func world_to_screen(point: Vector2) -> Vector2:
	if sim != null and sim.endless_mode:
		return point - camera_center + Vector2(640, 360)
	return Stage.project(point)

func screen_to_world(point: Vector2) -> Vector2:
	if sim != null and sim.endless_mode:
		return point + camera_center - Vector2(640, 360)
	return Stage.unproject(point)

func world_depth_scale(point: Vector2) -> float:
	return 1.0 if sim != null and sim.endless_mode else Stage.depth_scale(point)

func build_furina_actor() -> void:
	if furina_actor != null:
		return
	furina_actor = preload("res://scripts/furina_frame_actor.gd").new()
	add_child(furina_actor)
	call_deferred("sync_furina_actor")

func sync_furina_actor(dt: float = 0.0) -> void:
	if furina_actor == null or sim == null:
		return
	for hero: Dictionary in sim.heroes:
		if hero.get("character_id", "") == "hero_03" and bool(hero.get("deployed", true)):
			furina_actor.visible = true
			var shot_life: float = shot_flashes.get(hero.id, 0.0)
			furina_actor.sync(hero, world_to_screen(hero.pos), world_depth_scale(hero.pos), shot_life, reduced_effects, dt)
			return
	furina_actor.visible = false

func accept_events(batch: Array[Dictionary]) -> void:
	for event in batch:
		match event.kind:
			"route_warning":
				var route_id := str(event.get("route_id", "main"))
				var total := maxf(0.8, float(event.get("lead_time", 3.2)))
				route_previews[route_id] = {"life": total, "total": total, "flying": bool(event.get("flying", false)), "boss": bool(event.get("boss", false)), "enemy_id": str(event.get("enemy_id", "grunt")), "count": int(event.get("count", 1))}
				var route: Array = sim.stage_route(route_id)
				if not route.is_empty():
					spawn_portals[route_id] = {"pos": route[0], "life": total + 0.9, "total": total + 0.9}
			"route_spawn":
				var route_id := str(event.get("route_id", "main"))
				spawn_portals[route_id] = {"pos": event.pos, "life": 1.15, "total": 1.15}
			"shot":
				shot_flashes[event.hero_id] = 0.12
				var hero: Dictionary = sim.heroes[event.hero_id]
				var attack_duration := clampf(0.72 / maxf(0.55, float(hero.rate)), 0.22, 0.72)
				hero_attack_visuals[event.hero_id] = {"elapsed": 0.0, "duration": attack_duration, "start_frame": 18}
				if effects.size() < 260:
					var facing := float(hero.get("facing", 1.0))
					effects.append(effect_pool.acquire({"kind":"muzzle","pos":event.pos+Vector2(25.0*facing,-20),"value":1 if hero.get("element","")=="electro" else 0,"element":hero.get("element","")},0.16))
			"hit", "critical", "death", "move", "formation", "hurt", "down", "heal", "vaporize", "melt", "overloaded", "superconduct", "electro_charged", "frozen", "swirl", "crystallize", "element_burst", "shatter", "swirl_spread", "slash", "splash", "multishot", "pierce", "chain", "echo", "death_burst", "frenzy", "kill_streak", "reinforcement", "support_heal", "crossfire", "finale", "barrage", "shield_hit", "shield_break", "knockback", "crystal_guard", "enemy_heal", "enemy_guard", "split", "enemy_duplicate", "enemy_blink", "enemy_volatile", "skill_suppressed", "boss_move", "contract_complete", "boss_phase", "weather_pulse", "trap_pulse", "boss_pulse", "boss_summon", "enemy_shot", "reward_taken", "element_attuned", "skill_none", "skill_anemo", "skill_electro", "skill_pyro", "skill_hydro", "skill_geo", "skill_cryo", "geo_hit", "geo_break", "mechanism_pulse", "terrain_hit", "terrain_break", "deploy", "recall", "dodge", "skill_cast", "skill_impact", "vfx_cue", "ultimate_cast", "ultimate_impact", "synced_impact", "orbit_hit", "orbit_storm", "tag_synergy", "relic_awaken", "revive":
				if effects.size() >= (sim.performance_budget.effect_cap() if sim != null else 320) and event.kind in ["hit", "death", "move", "muzzle"]:
					continue
				var visual_event: Dictionary = event.duplicate(true)
				var effect_duration := 0.6
				if str(event.kind).begins_with("skill_"):
					effect_duration = 1.05
				elif event.kind == "slash":
					effect_duration = 0.42
				effects.append(effect_pool.acquire(visual_event,effect_duration))
				if str(event.kind).begins_with("skill_"):
					for hero: Dictionary in sim.heroes:
						if hero.get("character_id", "") == "traveler" and hero.hp > 0.0:
							hero_attack_visuals[hero.id] = {"elapsed": 0.0, "duration": 0.82, "start_frame": 0}
				if event.kind in ["death_burst", "crossfire", "finale", "barrage", "boss_pulse", "boss_move", "boss_phase", "enemy_volatile", "orbit_storm", "ultimate_impact", "skill_pyro", "skill_electro", "geo_break", "kill_streak"]:
					shake_trauma = minf(1.0, shake_trauma + 0.42)
				elif event.kind in ["hit", "slash", "chain"]:
					shake_trauma = minf(0.42, shake_trauma + 0.045)
			"leak":
				base_flash = 0.3

func caption(point: Vector2, text: String, color: Color, size: int = 12) -> void:
	draw_string(font, point, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw() -> void:
	if sim == null or font == null:
		return
	_draw_stage()
	_draw_enemy_telegraphs()
	if not sim.endless_mode:
		_draw_base_projected()
		_draw_spawn_portals()
		if stage_exit_active:
			_draw_stage_exit()
	_draw_orbitals()
	if deploy_preview_active:
		_draw_deploy_preview()
	for zone: Dictionary in sim.skill_effects:
		_draw_skill_zone(zone)
	for construct: Dictionary in sim.geo_constructs:
		_draw_geo_construct(construct)
	if skill_targeting:
		_draw_skill_preview()
	if selected_id >= 0:
		var hero: Dictionary = sim.heroes[selected_id]
		if hero.hp > 0 and bool(hero.get("deployed", true)):
			_draw_range_indicator(hero)
	for hero in sim.heroes:
		if hero.hp > 0 and hero.pos.distance_to(hero.target) > 3.0:
			draw_dashed_line(world_to_screen(hero.pos), world_to_screen(hero.target), Color(hero.color, 0.6), 1.0, 7.0)
			_ground_circle(hero.target, 13.0, Color(hero.color))
	var actors: Array[Dictionary] = []
	for enemy in sim.enemies:
		actors.append({"unit": enemy, "hero": false})
	for hero in sim.heroes:
		if bool(hero.get("deployed", true)):
			actors.append({"unit": hero, "hero": true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.unit.pos.y < b.unit.pos.y)
	for actor in actors:
		var unit: Dictionary = actor.unit
		var point: Vector2 = world_to_screen(unit.pos)
		var scale_factor: float = world_depth_scale(unit.pos)
		current_actor_transform = Transform2D(Vector2(scale_factor, 0.0), Vector2(0.0, scale_factor), point)
		draw_set_transform_matrix(current_actor_transform)
		var shadow_foot := Vector2(0.0, HERO_FOOT_OFFSET if actor.hero else ENEMY_FOOT_OFFSET)
		draw_ellipse_shadow(shadow_foot - Vector2(0.0, 9.0), 28.0 if actor.hero else unit.size * 0.48, Color(0, 0, 0, 0.5))
		draw_set_transform_matrix(current_actor_transform)
		var visual: Dictionary = unit.duplicate()
		visual.pos = Vector2.ZERO
		if actor.hero:
			_draw_hero(visual)
		else:
			_draw_enemy(visual)
		draw_set_transform(Vector2.ZERO)
	for projectile in sim.projectiles:
		_draw_projectile(projectile)
	for effect in effects:
		var point: Vector2 = world_to_screen(effect.pos)
		var scale_factor: float = world_depth_scale(effect.pos)
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		var visual: Dictionary = effect.duplicate()
		visual.pos = Vector2.ZERO
		_draw_effect(visual)
		draw_set_transform(Vector2.ZERO)
	if not sim.endless_mode:
		# Foreground parapet gives the stage a solid front edge.
		var front := PackedVector2Array([world_to_screen(Vector2(40, 580)), world_to_screen(Vector2(1240, 580)), Vector2(1240, 609), Vector2(40, 609)])
		draw_colored_polygon(front, Color("#151018"))
		draw_line(front[0], front[1], Color("#725054"), 2.0)
		caption(Vector2(47, 595), "C I T A D E L   /   0 1", Color("#a68b91"), 11)
		caption(Vector2(960, 594), "敌军推进方向   ←", Color("#c99593"), 12)
	if sim.state == "between":
		caption(Vector2(548, 127), "队伍休整  %.1fs" % sim.wave_timer, TEAL, 16)

func begin_stage_exit(character_id: String, character_name: String, element: String) -> void:
	stage_exit_active = true
	stage_exit_phase = "opening"
	stage_exit_timer = 0.0
	stage_exit_character_id = character_id
	stage_exit_character_name = character_name
	stage_exit_element = element
	stage_exit_newcomer_pos = STAGE_EXIT_DOOR
	spawn_portals["stage_exit"] = {"pos": STAGE_EXIT_DOOR, "life": 999.0, "total": 999.0}
	queue_redraw()

func reset_transients() -> void:
	route_previews.clear()
	spawn_portals.clear()
	stage_exit_active = false
	stage_exit_phase = ""
	stage_exit_timer = 0.0

func _advance_stage_exit(dt: float) -> void:
	stage_exit_timer += dt
	if stage_exit_phase == "opening":
		var progress := clampf(stage_exit_timer / 1.0, 0.0, 1.0)
		stage_exit_newcomer_pos = STAGE_EXIT_DOOR.lerp(STAGE_EXIT_MEET, progress)
		if progress >= 1.0:
			stage_exit_phase = "waiting"
			stage_exit_timer = 0.0
	elif stage_exit_phase == "waiting" and not sim.heroes.is_empty():
		if sim.heroes[0].pos.distance_to(STAGE_EXIT_MEET) <= 78.0:
			stage_exit_phase = "departing"
			stage_exit_timer = 0.0
			sim.heroes[0].target = STAGE_EXIT_DOOR + Vector2(-18, 0)
	elif stage_exit_phase == "departing":
		stage_exit_newcomer_pos = STAGE_EXIT_MEET.lerp(STAGE_EXIT_DOOR, clampf(stage_exit_timer / 1.35, 0.0, 1.0))
		if stage_exit_timer >= 1.35:
			stage_exit_active = false
			spawn_portals.erase("stage_exit")
			stage_exit_finished.emit()

func _draw_stage_exit() -> void:
	var door := world_to_screen(STAGE_EXIT_DOOR)
	var open_ratio := clampf(stage_exit_timer / 0.75, 0.0, 1.0) if stage_exit_phase == "opening" else 1.0
	var half_width := 34.0 * open_ratio
	var gate := PackedVector2Array([
		door + Vector2(-half_width, 10), door + Vector2(-half_width, -74),
		door + Vector2(-half_width * 0.56, -96), door + Vector2(0, -110),
		door + Vector2(half_width * 0.56, -96), door + Vector2(half_width, -74),
		door + Vector2(half_width, 10)
	])
	draw_colored_polygon(gate, Color(0.10, 0.025, 0.06, 0.66))
	draw_polyline(gate, Color("#ff6b7d"), 4.0, true)
	draw_line(door + Vector2(-half_width - 9, 12), door + Vector2(half_width + 9, 12), Color("#ff9aa6"), 5.0, true)
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([door + Vector2(side * (half_width + 5), 10), door + Vector2(side * (half_width + 13), 10), door + Vector2(side * (half_width + 11), -66), door + Vector2(side * (half_width + 4), -76)]), Color("#542536"))
	var actor := world_to_screen(stage_exit_newcomer_pos)
	draw_ellipse_shadow(actor, 20.0, Color(0, 0, 0, 0.55))
	var aura_color := element_color(stage_exit_element)
	draw_circle(actor + Vector2(0, -19), 30.0 + sin(clock * 4.0) * 1.5, Color(aura_color, 0.10))
	draw_arc(actor + Vector2(0, 5), 24.0, clock, clock + PI * 1.55, 28, Color(aura_color, 0.86), 2.2, true)
	if stage_exit_character_id == "hero_03":
		draw_texture_rect(furina_texture, Rect2(actor + Vector2(-27, -69), Vector2(54, 72)), false, Color.WHITE)
	else:
		var atlas_index := maxi(0, int(stage_exit_character_id.trim_prefix("hero_")) - 1)
		var tile := Vector2(atlas_index * 16, 112)
		draw_texture_rect_region(atlas, Rect2(actor + Vector2(-27, -51), Vector2(54, 54)), Rect2(tile, Vector2(16, 16)), Color.WHITE)
	caption(actor + Vector2(-27, -76), stage_exit_character_name, aura_color, 14)
	var instruction := "%s已解锁，正在进入下一关" % stage_exit_character_name if stage_exit_phase == "departing" else "右键移动旅行者，前往迎接 %s" % stage_exit_character_name
	caption(Vector2(410, 132), instruction, Color("#ffe5df"), 18)
	if stage_exit_phase == "waiting" and not sim.heroes.is_empty():
		draw_dashed_line(world_to_screen(sim.heroes[0].pos), actor, Color(1.0, 0.62, 0.67, 0.62), 2.0, 10.0, true)

func _draw_enemy_telegraphs() -> void:
	for enemy: Dictionary in sim.enemies:
		if bool(enemy.get("attack_pending", false)):
			var center := world_to_screen(enemy.get("warning_pos", enemy.pos))
			var radius := float(enemy.get("warning_radius", 60.0)) * 0.62 * world_depth_scale(enemy.pos)
			var ratio := clampf(float(enemy.get("warning_timer", 0.0)) / 1.05, 0.0, 1.0)
			draw_circle(center, radius, Color(0.95, 0.12, 0.18, 0.10 + (1.0-ratio)*0.16))
			draw_arc(center, radius, -PI*0.5, -PI*0.5 + TAU*(1.0-ratio), 48, Color("#ff5267"), 4.0, true)
			draw_line(world_to_screen(enemy.pos), center, Color(1.0,0.25,0.32,0.52), 2.0, true)
		if bool(enemy.get("special_pending", false)):
			for warning_point: Variant in enemy.get("special_warning_positions", [enemy.pos]):
				var center := world_to_screen(warning_point)
				var source := world_to_screen(enemy.pos)
				var radius := float(enemy.get("special_warning_radius",150.0))*0.62*world_depth_scale(warning_point)
				var shape := str(enemy.get("special_warning_shape","circle"))
				var danger := Color(0.88,0.06,0.14,0.16)
				if shape in ["line","rectangle","multi_line"]:
					var direction: Vector2 = (center-source).normalized()
					var side := direction.orthogonal()*(20.0 if shape=="line" else 32.0)
					var lane := PackedVector2Array([source+side,source-side,center-side,center+side])
					draw_colored_polygon(lane,danger)
					draw_polyline(PackedVector2Array([source+side,center+side,center-side,source-side]),Color("#ff4158"),4.0,true)
					if shape=="multi_line":
						for offset in [-58.0,58.0]:
							draw_line(source+side.normalized()*offset,center+side.normalized()*offset,Color(1.0,0.25,0.34,0.56),18.0,true)
				elif shape=="cross":
					draw_rect(Rect2(center-Vector2(radius,24),Vector2(radius*2.0,48)),danger,true)
					draw_rect(Rect2(center-Vector2(24,radius),Vector2(48,radius*2.0)),danger,true)
					draw_line(center-Vector2(radius,0),center+Vector2(radius,0),Color("#ff4158"),4.0,true)
					draw_line(center-Vector2(0,radius),center+Vector2(0,radius),Color("#ff4158"),4.0,true)
				elif shape in ["fan","cone"]:
					var direction: Vector2 = (center-source).normalized()
					var length := radius*1.45
					var fan := PackedVector2Array([source,source+direction.rotated(-0.90)*length,source+direction.rotated(0.90)*length])
					draw_colored_polygon(fan,danger)
					draw_polyline(PackedVector2Array([fan[0],fan[1],fan[2],fan[0]]),Color("#ff4158"),4.0,true)
				elif shape=="checker":
					for gx in range(-2,3):
						for gy in range(-2,3):
							if (gx+gy)%2==0:
								draw_rect(Rect2(center+Vector2(gx*42.0,gy*31.0)-Vector2(20,14),Vector2(40,28)),danger,true)
				elif shape=="donut":
					draw_circle(center,radius,danger)
					draw_circle(center,radius*0.38,Color(0.04,0.03,0.06,0.78))
					draw_arc(center,radius*0.38,0,TAU,48,Color("#ff9aa9"),3.0,true)
				elif shape=="spiral":
					for arc_index in 4:
						draw_arc(center,radius*(0.28+arc_index*0.19),clock*2.0+arc_index*0.9,clock*2.0+arc_index*0.9+PI*1.55,44,Color(1.0,0.18,0.30,0.74),5.0-arc_index*0.6,true)
				else:
					draw_circle(center, radius, danger)
					draw_arc(center, radius, clock*2.0, clock*2.0+PI*1.65, 64, Color("#ff334f"), 5.0, true)
				caption(center+Vector2(-74,-radius-12),str(enemy.get("special_move_name","BOSS 危险预警")),Color("#fff0ef"),14)

func _draw_orbitals() -> void:
	for orbital: Dictionary in sim.orbitals:
		var hero_id := int(orbital.get("hero_id",-1))
		if hero_id < 0 or hero_id >= sim.heroes.size():
			continue
		var hero: Dictionary = sim.heroes[hero_id]
		if not bool(hero.get("deployed",false)):
			continue
		var center := world_to_screen(hero.pos)+Vector2(0,-22)
		var radius := float(orbital.get("radius",150.0))*0.38
		var count := maxi(1,int(orbital.get("count",1)))
		var visual := str(orbital.get("visual","spell"))
		for i in count:
			var angle := clock*2.8+i*TAU/count
			var point := center+Vector2(cos(angle)*radius,sin(angle)*radius*0.36)
			var color := element_color(str(orbital.get("element","")))
			if visual == "blade":
				_draw_vertical_orbit_blade(point, color, angle)
			else:
				var direction := Vector2.from_angle(angle+PI*0.5)
				draw_line(point-direction*12.0,point+direction*12.0,color,4.0,true)
				draw_circle(point,3.0,Color.WHITE)

func _draw_vertical_orbit_blade(point: Vector2, color: Color, orbit_angle: float) -> void:
	var pulse := 1.0 + sin(clock*5.0+orbit_angle)*0.06
	var tip := point+Vector2(0,-18.0*pulse)
	var shoulder_left := point+Vector2(-5.0,-7.0)
	var shoulder_right := point+Vector2(5.0,-7.0)
	var base := point+Vector2(0,9.0)
	draw_colored_polygon(PackedVector2Array([tip,shoulder_right,base,shoulder_left]),Color(color,0.92))
	draw_polyline(PackedVector2Array([tip,shoulder_right,base,shoulder_left,tip]),Color.WHITE,1.4,true)
	draw_line(point+Vector2(-7,9),point+Vector2(7,9),Color("#ffe9bd"),3.0,true)
	draw_line(point+Vector2(0,9),point+Vector2(0,16),Color("#7d593e"),3.2,true)
	draw_circle(point,22.0,Color(color,0.055))

func _draw_deploy_preview() -> void:
	var point := world_to_screen(deploy_preview_point)
	var allowed: bool = (sim.ENDLESS_ARENA if sim.endless_mode else sim.MOVE_AREA).has_point(deploy_preview_point)
	var color := Color("#69f0c2") if allowed else Color("#ff5267")
	draw_circle(point,34.0,Color(color,0.16))
	draw_arc(point,34.0,0,TAU,48,color,3.0,true)
	draw_line(point-Vector2(18,0),point+Vector2(18,0),color,2.0,true)
	draw_line(point-Vector2(0,18),point+Vector2(0,18),color,2.0,true)
	caption(point+Vector2(-50,-54),"松开放置角色" if allowed else "不可部署",color,13)

func _draw_skill_preview() -> void:
	if selected_id < 0 or selected_id >= sim.heroes.size():
		return
	var hero: Dictionary = sim.heroes[selected_id]
	var element: String = str(hero.get("element", "none"))
	var color: Color = element_color(element)
	var ability: Dictionary = hero.get("active_skill", {})
	var radius: float = float(ability.get("radius", 170.0)) * (1.0 + sim.skill_area_bonus)
	var center := world_to_screen(skill_point)
	var hero_center := world_to_screen(hero.pos)
	var radius_x := radius * 0.62 * world_depth_scale(skill_point)
	var radius_y := radius_x * 0.32
	var targeting := str(ability.get("targeting","point"))
	if targeting == "line":
		var direction := (center-hero_center).normalized()
		var side := direction.orthogonal()*28.0
		var length := maxf(120.0,radius_x*1.8)
		var polygon := PackedVector2Array([hero_center+side,hero_center-side,hero_center+direction*length-side,hero_center+direction*length+side])
		draw_colored_polygon(polygon,Color(color,0.14))
		draw_polyline(PackedVector2Array([hero_center+side,hero_center+direction*length+side,hero_center+direction*length-side,hero_center-side]),Color(color,0.9),2.5,true)
	elif targeting == "cone":
		var direction := (center-hero_center).normalized()
		var polygon := PackedVector2Array([hero_center,hero_center+direction.rotated(-0.48)*radius_x*1.6,hero_center+direction.rotated(0.48)*radius_x*1.6])
		draw_colored_polygon(polygon,Color(color,0.14))
		draw_polyline(PackedVector2Array([polygon[0],polygon[1],polygon[2],polygon[0]]),Color(color,0.9),2.5,true)
	else:
		var points := PackedVector2Array()
		for i in 64:
			var angle := i * TAU / 64.0
			points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
		draw_colored_polygon(points, Color(color, 0.12))
		for segment in 12:
			var start := segment * TAU / 12.0 + clock * 0.35
			draw_arc(center, radius_x, start, start + 0.28, 5, Color(color, 0.95), 2.4, true)
	draw_circle(center, 6.0 + sin(clock * 6.0) * 1.5, Color(color, 0.9))
	caption(center + Vector2(-58, -radius_y - 18), sim.hero_skill_name(selected_id), color, 15)

func _draw_skill_zone(zone: Dictionary) -> void:
	var center := world_to_screen(zone.pos)
	var pulse := sin(clock * 7.0) * 5.0
	if zone.kind == "anemo_tornado":
		for ring in 5:
			draw_arc(center + Vector2(0, -20 - ring * 12), 24.0 + ring * 9.0 + pulse, -2.8 + clock * 2.0, 2.4 + clock * 2.0, 28, Color(0.42, 0.95, 0.78, 0.68 - ring * 0.08), 3.5, true)
		for mote in 8:
			var angle := clock * 3.0 + mote * TAU / 8.0
			var point := center + Vector2(cos(angle) * (38 + mote * 3), sin(angle) * 16 - 42 - mote * 3)
			draw_circle(point, 3.0, Color("#d5fff0"))
	elif zone.kind == "hydro_field":
		draw_circle(center, 65.0 + pulse, Color(0.25, 0.67, 1.0, 0.08))
		for ring in 3:
			draw_arc(center, 42.0 + ring * 22.0 + pulse, 0, TAU, 42, Color(0.35, 0.75, 1.0, 0.42 - ring * 0.08), 2.0, true)
	elif zone.kind in ["cryo_field","frozen_forest"]:
		for spoke in 12:
			var direction := Vector2.from_angle(spoke * TAU / 12.0)
			draw_line(center + direction * 12.0, center + direction * (78.0 + pulse), Color(0.68, 0.93, 1.0, 0.38), 2.0, true)
		draw_arc(center, 82.0 + pulse, 0, TAU, 48, Color(0.72, 0.96, 1.0, 0.56), 2.4, true)
	elif zone.kind in ["anemo_domain","gate_field","storm_field"]:
		var zone_color := Color("#6ce8c2") if zone.kind != "storm_field" else Color("#65bfff")
		draw_circle(center,72.0+pulse,Color(zone_color,0.08))
		for arc_index in 3:
			draw_arc(center,36.0+arc_index*22.0+pulse,clock*(1.2+arc_index*0.3),clock*(1.2+arc_index*0.3)+PI*1.45,40,Color(zone_color,0.58-arc_index*0.1),2.6,true)

func _draw_geo_construct(construct: Dictionary) -> void:
	var center := world_to_screen(construct.pos)
	var depth := world_depth_scale(construct.pos)
	draw_set_transform(center, 0, Vector2(depth, depth))
	draw_ellipse_shadow(Vector2.ZERO, 34.0, Color(0, 0, 0, 0.52))
	var stone := PackedVector2Array([Vector2(-31, 8), Vector2(-24, -48), Vector2(-6, -78), Vector2(19, -66), Vector2(34, -28), Vector2(28, 10)])
	draw_colored_polygon(stone, Color("#5b4631"))
	draw_polyline(PackedVector2Array([stone[0], stone[1], stone[2], stone[3], stone[4], stone[5], stone[0]]), Color("#e7bd5b"), 3.0, true)
	draw_line(Vector2(-8, -62), Vector2(13, -22), Color("#ffd978"), 3.0, true)
	draw_line(Vector2(13, -22), Vector2(-4, -4), Color("#ffd978"), 3.0, true)
	var ratio := clampf(float(construct.hp) / float(construct.max_hp), 0.0, 1.0)
	draw_rect(Rect2(-30, 17, 60, 5), Color("#352a27"))
	draw_rect(Rect2(-30, 17, 60 * ratio, 5), Color("#efc75f"))
	draw_set_transform(Vector2.ZERO)

func _ground_circle(point: Vector2, radius: float, color: Color) -> void:
	for i in 40:
		draw_line(world_to_screen(point + Vector2.from_angle(i * TAU / 40) * radius), world_to_screen(point + Vector2.from_angle((i + 1) * TAU / 40) * radius), color, 1.3, true)

func _draw_range_indicator(hero: Dictionary) -> void:
	var center: Vector2 = world_to_screen(hero.pos) + Vector2(0, 8)
	var color := Color(hero.color)
	var radii: Vector2 = sim.attack_range_screen_radii(hero)
	var points := PackedVector2Array()
	for i in 64:
		var angle: float = float(i) * TAU / 64.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, Color(color, 0.055))
	points.append(points[0])
	draw_polyline(points, Color(color, 0.58), 1.8, true)
	for segment in 16:
		var start: float = float(segment) * TAU / 16.0 + 0.035
		var finish: float = start + TAU / 16.0 * 0.46
		var arc_points := PackedVector2Array()
		for step in 5:
			var angle: float = lerpf(start, finish, float(step) / 4.0)
			arc_points.append(center + Vector2(cos(angle) * radii.x * 0.92, sin(angle) * radii.y * 0.92))
		draw_polyline(arc_points, Color(color, 0.30), 1.0, true)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var edge := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var tangent := Vector2(-sin(angle), cos(angle) * radii.y / radii.x).normalized()
		draw_line(edge - tangent * 5.0, edge + tangent * 5.0, Color(color, 0.85), 2.0, true)
	draw_arc(center, 12.0, 0, TAU, 32, Color(color, 0.28), 1.2, true)

func _draw_stage() -> void:
	if sim.endless_mode:
		_draw_endless_stage()
		return
	var backgrounds := {"stage_01": hell_stage_one, "stage_02": hell_stage_two, "stage_03": hell_stage_three}
	var hell_background: Texture2D = backgrounds.get(sim.current_stage_id, hell_stage_one)
	draw_texture_rect(hell_background, Rect2(0, 0, 1280, 720), false, Color.WHITE)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.05, 0.02, 0.06, 0.42))
	draw_rect(Rect2(0, 94, 1280, 512), Color(0.13, 0.08, 0.16, 0.72))
	# Distant skyline, behind the wall.
	for i in 14:
		var x: float = i * 100 - 40
		var top: float = 105 + (i % 3) * 12
		draw_rect(Rect2(x, top, 66, 100), Color("#302532"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, top), Vector2(x + 33, top - 26), Vector2(x + 73, top)]), Color("#302532"))
	var floor: PackedVector2Array = Stage.polygon(WORLD)
	draw_colored_polygon(floor, Color(0.19, 0.15, 0.20, 0.90))
	# Alternating stone tiles with perspective-correct seams.
	for row in 11:
		for col in 20:
			var rect := Rect2(40 + col * 60, 140 + row * 40, 60, 40)
			var tile_color := Color("#39313b") if (row + col) % 2 == 0 else Color("#342d37")
			draw_colored_polygon(Stage.polygon(rect.grow(-1)), tile_color)
	_draw_terrain_features()
	draw_colored_polygon(Stage.polygon(Sim.MOVE_AREA), Color(0.67, 0.28, 0.32, 0.10))
	var border: PackedVector2Array = Stage.polygon(Sim.MOVE_AREA)
	border.append(border[0])
	draw_polyline(border, Color("#9a5961"), 1.4, true)
	var routes: Dictionary = sim.stage_routes()
	for route_id: String in routes:
		var route: Array = routes[route_id]
		if route.size() < 2:
			continue
		_draw_route_bed(route)
		if route_previews.has(route_id):
			_draw_route_preview(route, route_previews[route_id])
	# Rear wall has height independent of the floor projection.
	for i in 12:
		var ground: Vector2 = world_to_screen(Vector2(45 + i * 105, 140))
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 48)), Color("#3e303c"))
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 5)), Color("#69505a"))
		draw_colored_polygon(PackedVector2Array([ground + Vector2(-5, 0), ground + Vector2(-5, -28), ground + Vector2(14, -40), ground + Vector2(33, -28), ground + Vector2(33, 0)]), Color("#211923"))
	for point in [Vector2(220, 145), Vector2(670, 145), Vector2(1120, 145)]:
		var screen: Vector2 = world_to_screen(point)
		draw_line(screen, screen + Vector2(0, -45), Color("#89737a"), 4)
		draw_circle(screen + Vector2(0, -46), 5, Color("#e8967c"))
		if not reduced_effects:
			draw_circle(screen + Vector2(0, -46), 12 + sin(clock * 2) * 1.5, Color(0.9, 0.4, 0.3, 0.1))
	caption(world_to_screen(Vector2(205, 525)), "全域机动区", Color("#c79398"), 12)

func _draw_terrain_features() -> void:
	for feature: Dictionary in sim.terrain_features:
		var area: Rect2 = feature.get("area", Rect2())
		if area.size == Vector2.ZERO:
			continue
		var kind := str(feature.get("type", ""))
		var polygon := Stage.polygon(area)
		var center := world_to_screen(area.get_center())
		if kind == "high_ground":
			var lowered := PackedVector2Array()
			for point in polygon:
				lowered.append(point + Vector2(0, 10))
			draw_colored_polygon(lowered, Color("#17131d"))
			draw_colored_polygon(polygon, Color(0.30, 0.25, 0.34, 0.96))
			draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[0]]), Color("#c2a0ca"), 2.0, true)
			for i in 3:
				var mark := center + Vector2(-34 + i * 34, 2)
				draw_polyline(PackedVector2Array([mark + Vector2(-7, 5), mark + Vector2(0, -3), mark + Vector2(7, 5)]), Color(0.84, 0.70, 0.88, 0.72), 2.0, true)
			caption(center + Vector2(-34, -18), "高台 · 攻击/射程强化", Color("#e6c9e9"), 10)
		elif kind == "low_ground":
			draw_colored_polygon(polygon, Color(0.12, 0.16, 0.22, 0.84))
			draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[0]]), Color("#56829a"), 2.0, true)
			for i in 4:
				draw_line(polygon[0].lerp(polygon[3], float(i + 1) / 5.0), polygon[1].lerp(polygon[2], float(i + 1) / 5.0), Color(0.33, 0.57, 0.68, 0.22), 2.0, true)
			caption(center + Vector2(-28, -8), "洼地 · 减速", Color("#88bfd4"), 10)
		elif kind == "blocked":
			draw_colored_polygon(polygon, Color(0.22, 0.07, 0.10, 0.92))
			draw_polyline(PackedVector2Array([polygon[0], polygon[2], polygon[1], polygon[3], polygon[0]]), Color("#c34d60"), 3.0, true)
			caption(center + Vector2(-26, -7), "不可通行", Color("#ff8795"), 10)
		elif kind == "mechanism":
			var active: bool = sim.heroes.any(func(hero: Dictionary) -> bool: return hero.hp > 0.0 and area.grow(95.0).has_point(hero.pos))
			var glow := Color("#ffbd62") if active else Color("#9c727a")
			draw_colored_polygon(polygon, Color(glow, 0.12 if active else 0.07))
			draw_arc(center, 24.0 + sin(clock * 4.0) * 3.0, clock, clock + PI * 1.65, 6, Color(glow, 0.82), 3.0, true)
			draw_arc(center, 12.0, -clock * 1.5, TAU - clock * 1.5, 6, Color(glow, 0.90), 2.0, true)
			if active:
				draw_arc(center, float(feature.get("radius", 180.0)) * 0.38, 0, TAU, 48, Color(glow, 0.10), 2.0, true)
			caption(center + Vector2(-28, 37), "火力机关" if active else "靠近启动", glow, 10)
		elif kind == "shortcut":
			var broken := bool(feature.get("broken", false))
			if broken:
				draw_colored_polygon(polygon, Color(0.25, 0.72, 0.52, 0.08))
				draw_dashed_line(polygon[0], polygon[1], Color("#66d49d"), 2.0, 7.0, true)
				caption(center + Vector2(-33, -6), "捷径已开启", Color("#83e1b2"), 10)
			else:
				draw_colored_polygon(polygon, Color(0.25, 0.13, 0.10, 0.92))
				for i in 4:
					var x := lerpf(polygon[0].x, polygon[1].x, float(i + 1) / 5.0)
					draw_line(Vector2(x, polygon[0].y), Vector2(x, polygon[3].y), Color("#df8c5d"), 4.0, true)
				var hp_ratio := clampf(float(feature.get("hp", 0.0)) / maxf(1.0, float(feature.get("max_hp", 1.0))), 0.0, 1.0)
				draw_rect(Rect2(center + Vector2(-31, -28), Vector2(62, 4)), Color("#291d20"))
				draw_rect(Rect2(center + Vector2(-31, -28), Vector2(62 * hp_ratio, 4)), Color("#f2aa65"))
				caption(center + Vector2(-39, 27), "战技可破坏", Color("#ffc181"), 10)

func _draw_endless_stage() -> void:
	draw_texture_rect(hell_stage_three, Rect2(0, 0, 1280, 720), false, Color(0.34, 0.24, 0.30, 1.0))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.018, 0.045, 0.69))
	# Broad overlapping slabs remove the old black checkerboard while retaining navigation scale.
	var top_left := screen_to_world(Vector2.ZERO)
	var bottom_right := screen_to_world(Vector2(1280, 720))
	var cell := 192.0
	var first_x := floorf(top_left.x / cell) * cell
	var first_y := floorf(top_left.y / cell) * cell
	for x in range(int(first_x), int(bottom_right.x + cell), int(cell)):
		for y in range(int(first_y), int(bottom_right.y + cell), int(cell)):
			var checker := posmod(floori(x / cell) + floori(y / cell), 4)
			var tile_color: Color = [Color("#302630"), Color("#352932"), Color("#2f252f"), Color("#392b33")][checker]
			draw_rect(Rect2(world_to_screen(Vector2(x - 1, y - 1)), Vector2(cell + 2, cell + 2)), tile_color)
			var seed := absi(x * 13 + y * 7)
			var crack := world_to_screen(Vector2(x + 28 + seed % 88, y + 34 + seed % 61))
			draw_polyline(PackedVector2Array([crack, crack + Vector2(17, 5), crack + Vector2(26, 18), crack + Vector2(42, 22)]), Color(0.86, 0.49, 0.50, 0.08), 1.5, true)
	var center := world_to_screen(Sim.ENDLESS_ARENA.get_center())
	for radius in [220.0, 360.0, 515.0]:
		draw_arc(center, radius + sin(clock * 0.8 + radius) * 3.0, 0, TAU, 112, Color(0.88, 0.34, 0.42, 0.075), 3.0, true)
	for i in 24:
		var angle := float(i) * TAU / 24.0
		var radius := 210.0 + float((i * 83) % 330)
		var rune := world_to_screen(Sim.ENDLESS_ARENA.get_center() + Vector2.from_angle(angle) * radius)
		var glow := 0.12 + sin(clock * 1.8 + i * 0.7) * 0.045
		draw_arc(rune, 11.0 + float(i % 4) * 3.0, angle + clock * 0.04, angle + PI * 1.42 + clock * 0.04, 18, Color(0.96, 0.40, 0.46, glow), 2.0, true)
		if i % 4 == 0:
			draw_circle(rune, 3.0, Color(1.0, 0.69, 0.62, 0.18))
	var arena_screen := Rect2(world_to_screen(Sim.ENDLESS_ARENA.position), Sim.ENDLESS_ARENA.size)
	draw_rect(arena_screen, Color(0.92, 0.37, 0.43, 0.34), false, 3.0)
	# Soft frame and ember bands guide focus toward the playable center.
	for edge in 5:
		draw_rect(Rect2(edge * 5, edge * 5, 1280 - edge * 10, 720 - edge * 10), Color(0.02, 0.008, 0.02, 0.07), false, 5.0)
	caption(Vector2(36, 126), "E N D L E S S   F I E L D   /   猩红荒原", Color("#dcb1ad"), 12)

func _draw_base_projected() -> void:
	var point: Vector2 = world_to_screen(Vector2(100, 365))
	draw_ellipse_shadow(point + Vector2(0, 15), 52, Color(0, 0, 0, 0.48))
	var tint: Color = RED if base_flash > 0.0 and not reduced_effects else Color("#e3b7ba")
	var glow := 0.75 + sin(clock * 3.4) * 0.18
	draw_circle(point + Vector2(0, -38), 44.0 + glow * 7.0, Color(tint, 0.055))
	draw_circle(point + Vector2(0, -38), 30.0 + glow * 5.0, Color(tint, 0.10))
	draw_arc(point + Vector2(0, -38), 38.0, -clock * 0.7, TAU - clock * 0.7, 40, Color(tint, 0.42), 2.0, true)
	draw_texture_rect(crystal_texture, Rect2(point + Vector2(-38, -105), Vector2(76, 120)), false, tint)
	draw_colored_polygon(PackedVector2Array([point + Vector2(-43, 17), point + Vector2(-29, 5), point + Vector2(29, 5), point + Vector2(43, 17), point + Vector2(31, 31), point + Vector2(-31, 31)]), Color("#382934"))
	draw_polyline(PackedVector2Array([point + Vector2(-43, 17), point + Vector2(-29, 5), point + Vector2(29, 5), point + Vector2(43, 17)]), Color("#a06d7b"), 2.0, true)
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83, 6)), Color("#241d26"))
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83 * sim.base_hp / maxf(1.0, sim.base_max_hp), 6)), tint)
	caption(point + Vector2(-35, 72), "基地核心", tint, 13)

func _draw_route_bed(route: Array) -> void:
	for i in range(route.size() - 1):
		var a := world_to_screen(route[i])
		var b := world_to_screen(route[i + 1])
		# A narrow worn-stone seam hints navigation without drawing a black rail over the map.
		draw_line(a, b, Color(0.19, 0.13, 0.17, 0.34), 12.0, true)
		draw_line(a, b, Color(0.64, 0.39, 0.39, 0.14), 7.0, true)
		var length := a.distance_to(b)
		var steps := maxi(1, floori(length / 54.0))
		for step in steps:
			var t := (float(step) + 0.5) / float(steps)
			var point := a.lerp(b, t)
			var direction := (b - a).normalized()
			draw_line(point - direction.rotated(PI * 0.5) * 4.0, point + direction.rotated(PI * 0.5) * 4.0, Color(0.83, 0.58, 0.54, 0.10), 1.0, true)

func _draw_route_preview(route: Array, preview: Dictionary) -> void:
	var color := Color("#f4d878") if bool(preview.get("flying", false)) else Color("#ff8b75")
	var pulse := 0.68 + sin(clock * 7.0) * 0.16
	var width := 6.0 if bool(preview.get("boss", false)) else 4.0
	for i in range(route.size() - 1):
		var a := world_to_screen(route[i])
		var b := world_to_screen(route[i + 1])
		draw_line(a, b, Color(color, 0.05 + pulse * 0.07), width + 10.0, true)
		draw_dashed_line(a, b, Color(color, pulse * 0.84), width, 15.0, true)
		var direction := (b - a).normalized()
		var side := direction.rotated(PI * 0.5)
		for marker in 3:
			var phase := fposmod(clock * 0.72 + marker / 3.0 + i * 0.11, 1.0)
			var point := a.lerp(b, phase)
			var head := PackedVector2Array([point + direction * 9.0, point - direction * 10.0 + side * 7.0, point - direction * 5.0, point - direction * 10.0 - side * 7.0])
			draw_colored_polygon(head, Color(color, 0.82 + pulse * 0.16))
			draw_circle(point - direction * 19.0, 3.5 + pulse * 1.5, Color(color, 0.34))
			draw_line(point - direction * 15.0, point - direction * 32.0, Color(color, 0.24), 3.0, true)
	var first := world_to_screen(route[0])
	var enemy_name: String = str({"grunt": "裂隙兽", "runner": "疾行兽", "armored": "重甲兽", "flyer": "空袭兽", "ranged": "射手", "buffer": "增幅者", "shielded": "盾卫", "charger": "冲锋兽", "healer": "愈疗者", "splitter": "分裂体", "warder": "结界师", "boss_01": "裂隙统领", "boss_02": "深渊母巢"}.get(str(preview.get("enemy_id", "grunt")), "敌军"))
	var warning := "BOSS · %s" % enemy_name if bool(preview.get("boss", false)) else "%s ×%d" % [enemy_name, int(preview.get("count", 1))]
	caption(first + Vector2(-72, -58), warning, color, 13)

func _draw_spawn_portals() -> void:
	for route_id: String in spawn_portals:
		var portal: Dictionary = spawn_portals[route_id]
		var point := world_to_screen(portal.pos) + Vector2(0, -23)
		var ratio := clampf(float(portal.life) / maxf(0.01, float(portal.total)), 0.0, 1.0)
		var pulse := 1.0 + sin(clock * 10.0 + route_id.hash() % 7) * 0.10
		draw_set_transform(point, clock * 0.18, Vector2(0.62, 1.0) * pulse)
		draw_circle(Vector2.ZERO, 31.0, Color(0.28, 0.015, 0.06, 0.42 * ratio))
		draw_arc(Vector2.ZERO, 36.0, 0, TAU, 48, Color(0.94, 0.23, 0.38, 0.95 * ratio), 5.0, true)
		draw_arc(Vector2.ZERO, 25.0, -clock * 2.0, TAU - clock * 2.0, 32, Color(1.0, 0.68, 0.72, 0.86 * ratio), 2.0, true)
		for spark in 6:
			var angle := clock * 2.4 + spark * TAU / 6.0
			draw_circle(Vector2.from_angle(angle) * (31.0 + spark % 2 * 8.0), 2.5, Color(1.0, 0.55, 0.63, ratio))
		draw_set_transform(Vector2.ZERO)

func draw_ellipse_shadow(pos: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		points.append(pos + Vector2(0, 9) + Vector2(cos(i * TAU / 32) * radius, sin(i * TAU / 32) * radius * 0.28))
	draw_colored_polygon(points, color)

func _draw_base() -> void:
	var tint: Color = RED if base_flash > 0.0 and not reduced_effects else TEAL
	draw_rect(Rect2(73, 255, 63, 216), Color("#1b2933"))
	draw_rect(Rect2(73, 255, 63, 216), Color("#51656c"), false, 2)
	for y in range(269, 460, 23):
		draw_line(Vector2(78, y), Vector2(129, y), Color("#2b3c45"), 1)
	draw_rect(Rect2(85, 302, 39, 100), Color("#0c151c"))
	draw_colored_polygon(PackedVector2Array([Vector2(104, 315), Vector2(119, 352), Vector2(104, 389), Vector2(89, 352)]), tint)
	draw_line(Vector2(104, 326), Vector2(104, 378), Color("#e4f4e7"), 2)
	draw_rect(Rect2(62, 474, 87, 8), Color("#27343d"))
	draw_rect(Rect2(62, 474, 87 * sim.base_hp / maxf(1.0, sim.base_max_hp), 8), tint)
	caption(Vector2(71, 505), "基地核心", Color("#b2c0c8"), 13)
	draw_rect(Rect2(118, 220, 2, 312), Color(0.65, 0.78, 0.74, 0.14))

func _draw_portal() -> void:
	draw_rect(Rect2(1192, 226, 22, 285), Color("#39252e"))
	for lane in Sim.LANES:
		draw_arc(Vector2(1195, lane), 26, -PI / 2, PI / 2, 24, Color("#c66571"), 2)
		draw_arc(Vector2(1195, lane), 32 + sin(clock * 2) * 2, PI / 2, 3 * PI / 2, 24, Color("#50333f"), 1)
	caption(Vector2(1113, 208), "裂隙 / RIFT", Color("#c27b85"), 13)

func _draw_hero(hero: Dictionary) -> void:
	var down: bool = hero.hp <= 0
	var color := Color(hero.color)
	var is_furina: bool = hero.get("visual", "") == "furina"
	var is_traveler: bool = hero.get("character_id", "") == "traveler"
	var bob: float = 0.0 if down or is_traveler else sin(clock * (14.0 if hero.moving else 3.0)) * (3.0 if hero.moving else 1.0)
	if selected_id == hero.id:
		draw_arc(hero.pos + Vector2(0, 8), 31 if is_traveler else 29, 0, TAU, 36, color, 2)
	var tint := Color("#67717a") if down else Color.WHITE
	var traveler_element: String = str(hero.get("element", "")) if is_traveler else ""
	if traveler_element != "":
		var aura_color: Color = element_color(traveler_element)
		draw_circle(hero.pos + Vector2(0, -20), 31.0 + sin(clock * 3.0) * 2.0, Color(aura_color, 0.11))
		draw_arc(hero.pos + Vector2(0, 7), 31.0, clock * 0.7, clock * 0.7 + PI * 1.45, 30, Color(aura_color, 0.82), 2.2, true)
		caption(hero.pos + Vector2(-9, -128 if is_traveler else -72), element_glyph(traveler_element), aura_color, 16)
	if hero.flash > 0 and not reduced_effects:
		tint = Color("#fff0eb")
	if is_furina:
		if shot_flashes.get(hero.id, 0.0) > 0.0 and not reduced_effects:
			var pulse: float = shot_flashes.get(hero.id, 0.0) / 0.12
			draw_circle(hero.pos + Vector2(30, -35), 7.0 + pulse * 5.0, Color(0.52, 0.88, 1.0, 0.16))
			draw_arc(hero.pos + Vector2(30, -35), 9.0 + pulse * 7.0, -1.25, 1.25, 16, Color("#a9ecff"), 2.0, true)
	elif is_traveler:
		_draw_traveler(hero, tint, down)
	else:
		var facing := float(hero.get("facing", 1.0))
		_draw_anchored_texture_region(atlas, hero.pos + Vector2(0, HERO_FOOT_OFFSET + bob), Vector2(58, 58), Vector2(16, 16), Vector2(8, 16), facing, 1.0, Rect2(hero.tile, Vector2(16, 16)), tint)
	if not down:
		if hero.block > 0 and not is_traveler:
			draw_rect(Rect2(hero.pos + Vector2(17, -24), Vector2(16, 25)), Color("#a8a687"))
			draw_rect(Rect2(hero.pos + Vector2(21, -21), Vector2(8, 18)), Color("#445b5e"))
		elif not is_furina and not is_traveler:
			draw_circle(hero.pos + Vector2(29, -16 + bob), 5, color)
			if shot_flashes.get(hero.id, 0.0) > 0 and not reduced_effects:
				draw_circle(hero.pos + Vector2(37, -16), 8, color)
	var tall_visual := is_furina or is_traveler
	var label_y: float = -132.0 if is_traveler else (-108.0 if is_furina else -65.0)
	var health_y: float = -120.0 if is_traveler else (-96.0 if is_furina else -53.0)
	caption(hero.pos + Vector2(-29, label_y), "%d %s" % [hero.id + 1, hero.name], color, 13)
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50, 4)), Color("#303942"))
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50 * hero.hp / hero.max_hp, 4)), color)
	if down:
		caption(hero.pos + Vector2(-24, 30), "已倒地", RED, 12)
	elif hero.moving:
		caption(hero.pos + Vector2(-24, 30), "移动中", Color("#91a4ad"), 12)
	elif hero.block > 0:
		caption(hero.pos + Vector2(-28, 30), "阻挡 %d/%d" % [hero.blocked, hero.block], color, 12)

func _draw_traveler(hero: Dictionary, tint: Color, down: bool) -> void:
	var texture := traveler_idle_atlas
	var pivot_profile := "traveler_idle"
	var frame := posmod(floori(clock * 24.0), TRAVELER_FRAMES)
	if down:
		texture = traveler_death_atlas
		pivot_profile = "traveler_down"
		frame = mini(TRAVELER_FRAMES - 1, floori(float(hero_down_visuals.get(hero.id, 0.0)) * 30.0))
	elif hero_attack_visuals.has(hero.id):
		texture = traveler_attack_atlas
		pivot_profile = "traveler_attack"
		var state: Dictionary = hero_attack_visuals[hero.id]
		var phase := clampf(float(state.elapsed) / maxf(0.01, float(state.duration)), 0.0, 1.0)
		var start_frame := int(state.get("start_frame", 18))
		frame = clampi(start_frame + floori(phase * float(TRAVELER_FRAMES - 1 - start_frame)), start_frame, TRAVELER_FRAMES - 1)
	elif hero.moving:
		texture = traveler_run_atlas
		pivot_profile = "traveler_run"
		frame = posmod(floori(clock * 24.0), TRAVELER_FRAMES)
	var hit_strength := clampf(float(hero.flash) / 0.12, 0.0, 1.0) if not reduced_effects else 0.0
	var width := 132.0 * (1.0 + hit_strength * 0.13)
	var height := 132.0 * (1.0 - hit_strength * 0.10)
	var foot: Vector2 = hero.pos + Vector2(0, HERO_FOOT_OFFSET)
	var facing := float(hero.get("facing", 1.0))
	var pivot := SpriteAnchor.pivot(sprite_pivots, pivot_profile, frame, Vector2(TRAVELER_CELL * 0.5, 270.0))
	var source := Rect2((frame % 8) * TRAVELER_CELL, floori(frame / 8.0) * TRAVELER_CELL, TRAVELER_CELL, TRAVELER_CELL)
	if not reduced_effects:
		draw_circle(hero.pos + Vector2(0, -35), 36.0 + sin(clock * 2.2) * 2.0, Color(1.0, 0.76, 0.48, 0.055))
	_draw_anchored_texture_region(texture, foot, Vector2(width, height), Vector2(TRAVELER_CELL, TRAVELER_CELL), pivot, facing, 1.0, source, tint)

func _draw_furina(hero: Dictionary, tint: Color, bob: float, down: bool) -> void:
	if down:
		draw_texture_rect(furina_texture, Rect2(hero.pos + Vector2(-40, -29), Vector2(80, 42)), false, tint)
		return
	var attacking: bool = shot_flashes.get(hero.id, 0.0) > 0.0
	var stride: float = sin(clock * 14.0) if hero.moving else 0.0
	var width: float = 55.0 + absf(stride) * 2.0 + (5.0 if attacking else 0.0)
	var height: float = 94.0 - absf(stride) * 3.0 - (4.0 if attacking else 0.0)
	var origin: Vector2 = hero.pos + Vector2(-width * 0.5 + (4.0 if attacking else 0.0), -height + 9.0 + bob)
	if not reduced_effects:
		draw_circle(hero.pos + Vector2(0, -27), 29.0 + sin(clock * 2.4) * 2.0, Color(0.32, 0.73, 0.92, 0.08))
	draw_texture_rect(furina_texture, Rect2(origin, Vector2(width, height)), false, tint)
	if attacking and not reduced_effects:
		draw_arc(hero.pos + Vector2(29, -45), 10.0, -1.2, 1.2, 14, Color("#a9ecff"), 2.2, true)

func _draw_enemy(enemy: Dictionary) -> void:
	var flying: bool = bool(enemy.get("flying", false))
	var bob: float = sin(clock * (8.0 if not flying else 5.0) + enemy.id) * (2.0 if not flying else 7.0) - (22.0 if flying else 0.0)
	var tint := Color("#fff5e5") if enemy.flash > 0 and not reduced_effects else Color(enemy.color)
	var side: float = enemy.size
	var body: Vector2 = enemy.pos + Vector2(0, -18 + bob)
	# Distinct moving silhouettes remain readable even after replacement art is supplied.
	match str(enemy.kind):
		"runner":
			for trail in 3:
				draw_line(body + Vector2(12 + trail * 7, -8 + trail * 8), body + Vector2(37 + trail * 8, -8 + trail * 8), Color(0.95, 0.72, 0.34, 0.42 - trail * 0.10), 3.0, true)
		"flyer":
			var flap := 8.0 + sin(clock * 10.0 + enemy.id) * 6.0
			draw_colored_polygon(PackedVector2Array([body + Vector2(-8, -7), body + Vector2(-42, -flap), body + Vector2(-28, 11), body]), Color(0.32, 0.78, 0.82, 0.78))
			draw_colored_polygon(PackedVector2Array([body + Vector2(8, -7), body + Vector2(42, -flap), body + Vector2(28, 11), body]), Color(0.32, 0.78, 0.82, 0.78))
		"ranged":
			draw_arc(body + Vector2(-9, 0), 30.0, -1.15, 1.15, 16, Color("#ffad82"), 4.0, true)
			draw_line(body + Vector2(-20, -27), body + Vector2(-20, 27), Color("#ffe0b8"), 2.0, true)
		"buffer":
			for rune in 3:
				var angle := clock * 2.2 + rune * TAU / 3.0
				var rune_pos: Vector2 = body + Vector2.from_angle(angle) * 34.0
				draw_colored_polygon(PackedVector2Array([rune_pos + Vector2(0, -6), rune_pos + Vector2(5, 3), rune_pos + Vector2(-5, 3)]), Color("#e18df0"))
		"shielded":
			var shield := PackedVector2Array([body + Vector2(-38, -28), body + Vector2(-13, -35), body + Vector2(-9, 22), body + Vector2(-28, 36), body + Vector2(-43, 17)])
			draw_colored_polygon(shield, Color("#385b78"))
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), Color("#91d1ef"), 3.0, true)
		"charger":
			for trail in 4:
				draw_line(body + Vector2(20 + trail * 5, -18 + trail * 11), body + Vector2(64 + trail * 8, -18 + trail * 11), Color(1.0, 0.38, 0.24, 0.46 - trail * 0.08), 4.0, true)
			draw_colored_polygon(PackedVector2Array([body + Vector2(-14, -24), body + Vector2(-38, -45), body + Vector2(-29, -12)]), Color("#ff895f"))
		"healer":
			draw_line(body + Vector2(-29, 0), body + Vector2(29, 0), Color("#8cf0b1"), 7.0, true)
			draw_line(body + Vector2(0, -29), body + Vector2(0, 29), Color("#8cf0b1"), 7.0, true)
		"splitter":
			draw_circle(body + Vector2(-24, 9), 15.0 + sin(clock * 5.0) * 2.0, Color(0.77, 0.30, 0.58, 0.70))
			draw_circle(body + Vector2(24, -4), 13.0 - sin(clock * 5.0) * 2.0, Color(0.90, 0.45, 0.67, 0.70))
		"warder":
			for ring in 2:
				draw_arc(body, 31.0 + ring * 8.0 + sin(clock * 3.0) * 2.0, clock * (1.0 if ring == 0 else -1.0), TAU + clock * (1.0 if ring == 0 else -1.0), 6, Color(0.55, 0.67, 1.0, 0.52), 2.5, true)
	var visual_id := str(enemy.kind)
	if enemy_visual_textures.has(visual_id):
		_draw_slime_enemy(enemy, sim.database.enemy_visuals[visual_id], enemy_visual_textures[visual_id], bob)
	elif visual_id in ["grunt", "runner", "charger"]:
		_draw_animated_enemy(enemy, tint, bob)
	else:
		var facing := float(enemy.get("facing", -1.0))
		_draw_anchored_texture_region(atlas, enemy.pos + Vector2(0, ENEMY_FOOT_OFFSET + bob), Vector2(side, side), Vector2(16, 16), Vector2(8, 16), facing, -1.0, Rect2(0, 144, 16, 16), tint)
	var ratio: float = clampf(float(enemy.hp) / float(enemy.max_hp), 0, 1)
	draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44, 4)), Color("#302b32"))
	draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44 * ratio, 4)), RED)
	if float(enemy.get("max_shield", 0.0)) > 0.0 and float(enemy.get("shield", 0.0)) > 0.0:
		var shield_ratio: float = float(enemy.shield) / float(enemy.max_shield)
		draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 8), Vector2(44, 3)), Color("#24394e"))
		draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 8), Vector2(44 * shield_ratio, 3)), Color("#66c8ff"))
		draw_arc(enemy.pos + Vector2(0, -20 + bob), side * 0.48, -2.7, 0.35, 22, Color(0.45, 0.82, 1.0, 0.72), 2.5, true)
	if enemy.kind == "armored":
		draw_arc(enemy.pos + Vector2(0, -18), 24, -PI * 0.4, PI * 0.4, 12, Color("#c5b2e3"), 3)
		caption(enemy.pos + Vector2(-7, 27), "甲", Color("#c5b2e3"), 12)
	elif enemy.kind == "runner":
		caption(enemy.pos + Vector2(-7, 27), "疾", Color("#e6c77b"), 12)
	elif enemy.kind == "flyer":
		draw_polyline(PackedVector2Array([enemy.pos + Vector2(-31, -25 + bob), enemy.pos + Vector2(-12, -15 + bob), enemy.pos + Vector2(0, -31 + bob), enemy.pos + Vector2(12, -15 + bob), enemy.pos + Vector2(31, -25 + bob)]), Color("#9ef1ed"), 3.0, true)
		caption(enemy.pos + Vector2(-7, 27), "空", Color("#80d7d7"), 12)
	elif enemy.kind == "ranged":
		draw_line(enemy.pos + Vector2(-27, -15), enemy.pos + Vector2(25, -15), Color("#ffab88"), 3.0, true)
		caption(enemy.pos + Vector2(-7, 27), "远", Color("#e58b73"), 12)
	elif enemy.kind == "buffer":
		draw_arc(enemy.pos + Vector2(0, -20), 30.0 + sin(clock * 2.0) * 3.0, 0, TAU, 32, Color(0.85, 0.42, 0.95, 0.5), 2.0, true)
		caption(enemy.pos + Vector2(-7, 27), "增", Color("#cf7fda"), 12)
	elif enemy.kind == "shielded":
		caption(enemy.pos + Vector2(-7, 27), "盾", Color("#76a6d8"), 12)
	elif enemy.kind == "charger":
		draw_line(enemy.pos + Vector2(-34, -18), enemy.pos + Vector2(28, -18), Color("#ff8b61"), 4.0, true)
		caption(enemy.pos + Vector2(-7, 27), "冲", Color("#ef795b"), 12)
	elif enemy.kind == "healer":
		draw_arc(enemy.pos + Vector2(0, -20), 27.0 + sin(clock * 3.0) * 3.0, 0, TAU, 28, Color(0.45, 0.95, 0.66, 0.6), 2.0, true)
		caption(enemy.pos + Vector2(-7, 27), "疗", Color("#75d6a2"), 12)
	elif enemy.kind == "splitter":
		caption(enemy.pos + Vector2(-7, 27), "裂", Color("#d77aa9"), 12)
	elif enemy.kind == "warder":
		draw_arc(enemy.pos + Vector2(0, -20), 31.0, 0, TAU, 6, Color(0.55, 0.67, 1.0, 0.72), 2.5, true)
		caption(enemy.pos + Vector2(-7, 27), "护", Color("#8ba4e8"), 12)
	elif str(enemy.kind).begins_with("boss_"):
		var style := str(enemy.get("boss_style", "commander"))
		var phase := int(enemy.get("boss_phase", 1))
		var pulse := sin(clock * (2.2 + phase * 0.35))
		var boss_color: Color = {"commander": Color("#ff6686"), "brood": Color("#df61bd"), "storm": Color("#66d9ff"), "bulwark": Color("#e3bd62"), "artillery": Color("#ff8456"), "chronophage": Color("#9b7cff")}.get(style, Color("#ff6686"))
		draw_arc(body, 48.0 + pulse * 3.0 + phase * 2.0, 0, TAU, 36, Color(boss_color, 0.82), 3.0 + phase * 0.7, true)
		for phase_mark in phase:
			var mark_angle := -PI * 0.5 + phase_mark * TAU / maxf(1.0, phase)
			draw_circle(body + Vector2.from_angle(mark_angle) * 55.0, 4.0, boss_color)
		match style:
			"brood":
				for sac in 3:
					draw_circle(body + Vector2(-25 + sac * 25, 20 + sin(clock * 3.0 + sac) * 4.0), 13.0, Color(boss_color, 0.58))
			"storm":
				for bolt in 3:
					var x := -34.0 + bolt * 34.0
					draw_polyline(PackedVector2Array([body + Vector2(x, -43), body + Vector2(x + 10, -24), body + Vector2(x - 2, -8), body + Vector2(x + 14, 12)]), boss_color, 3.0, true)
			"bulwark":
				var wall := PackedVector2Array([body + Vector2(-45, -38), body + Vector2(-12, -51), body + Vector2(34, -33), body + Vector2(42, 27), body + Vector2(0, 47), body + Vector2(-43, 25), body + Vector2(-45, -38)])
				draw_polyline(wall, boss_color, 6.0, true)
			"artillery":
				draw_line(body + Vector2(-8, -30), body + Vector2(58, -54), boss_color, 13.0, true)
				draw_circle(body + Vector2(61, -55), 10.0 + pulse * 2.0, Color("#fff0bd"))
			"chronophage":
				for hand in 3:
					var angle := clock * (1.4 + hand * 0.25) + hand * TAU / 3.0
					draw_line(body, body + Vector2.from_angle(angle) * (34.0 + hand * 6.0), boss_color, 3.0, true)
				draw_circle(body, 9.0, Color("#171019"))
			_:
				for crown in 3:
					draw_colored_polygon(PackedVector2Array([body + Vector2(-34 + crown * 34, -38), body + Vector2(-22 + crown * 34, -63), body + Vector2(-10 + crown * 34, -38)]), boss_color)
		var boss_name: String = {"commander": "统领", "brood": "母巢", "storm": "风暴", "bulwark": "壁垒", "artillery": "炮台", "chronophage": "噬时"}.get(style, "统领")
		caption(enemy.pos + Vector2(-18, 36), boss_name + " · P%d" % phase, boss_color, 14)

	if enemy.haste_timer > 0:
		draw_arc(enemy.pos + Vector2(0, -18), side * 0.54, 0, TAU, 28, Color(0.86, 0.45, 0.95, 0.42), 2.0, true)
	if enemy.blocked_by >= 0:
		draw_line(enemy.pos + Vector2(-24, 10), enemy.pos + Vector2(24, 10), Color("#c5bd96"), 2)
	if enemy.slow_timer > 0:
		caption(enemy.pos + Vector2(19, 27), "缓", Color("#83c7e8"), 12)
	if float(enemy.get("frozen_timer", 0.0)) > 0.0:
		draw_arc(enemy.pos + Vector2(0, -18), side * 0.58, 0, TAU, 8, Color(0.66, 0.93, 1.0, 0.86), 3.0, true)
	if enemy.aura != "":
		var aura_element: String = sim.normalize_element(str(enemy.aura))
		var color := element_color(aura_element)
		draw_circle(enemy.pos + Vector2(30, -side), 11, Color("#10202b"))
		caption(enemy.pos + Vector2(24, -side + 5), element_glyph(aura_element), color, 12)

func _update_projectile_trails() -> void:
	if sim == null:
		projectile_trails.clear()
		return
	var active := {}
	for projectile: Dictionary in sim.projectiles:
		var key := int(projectile.get("visual_id", projectile.get("source_id", 0) * 100000 + projectile.get("target_id", 0)))
		active[key] = true
		var history: Array = projectile_trails.get(key, [])
		var current := Vector2(projectile.pos)
		if history.is_empty() or Vector2(history[-1]).distance_to(current) > 1.0:
			history.append(current)
		while history.size() > 11:
			history.pop_front()
		projectile_trails[key] = history
	for key in projectile_trails.keys():
		if not active.has(key):
			projectile_trails.erase(key)

func _draw_projectile(projectile: Dictionary) -> void:
	var key := int(projectile.get("visual_id", projectile.get("source_id", 0) * 100000 + projectile.get("target_id", 0)))
	var history: Array = projectile_trails.get(key, [])
	var point := world_to_screen(Vector2(projectile.pos)) + Vector2(0, -18)
	var direction := Vector2.RIGHT
	if history.size() >= 2:
		direction = (world_to_screen(Vector2(history[-1])) - world_to_screen(Vector2(history[-2]))).normalized()
	else:
		var target: Dictionary = sim.find_enemy(int(projectile.get("target_id", -1)))
		if not target.is_empty():
			direction = (world_to_screen(target.pos) - point).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.RIGHT
	var element := str(projectile.get("element", ""))
	var color := element_color(element)
	for i in range(maxi(0, history.size() - 1)):
		var a := world_to_screen(Vector2(history[i])) + Vector2(0, -18)
		var b := world_to_screen(Vector2(history[i + 1])) + Vector2(0, -18)
		var age := float(i + 1) / maxf(1.0, float(history.size()))
		draw_line(a, b, Color(color, age * 0.13), 13.0 * age, true)
		draw_line(a, b, Color(color.lightened(0.32), age * 0.68), 2.2 + age * 2.2, true)
	draw_set_transform(point, direction.angle(), Vector2.ONE)
	var critical_scale := 1.35 if bool(projectile.get("critical", false)) else 1.0
	draw_circle(Vector2.ZERO, 12.0 * critical_scale, Color(color, 0.10))
	draw_circle(Vector2.ZERO, 6.2 * critical_scale, Color(color, 0.42))
	match element:
		"pyro":
			draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(-7, -9), Vector2(-2, 0), Vector2(-10, 8)]), Color(color, 0.92))
			draw_circle(Vector2(4, 0), 3.2, Color("#fff1b8"))
		"hydro":
			draw_circle(Vector2.ZERO, 7.2, Color(color, 0.72))
			draw_arc(Vector2.ZERO, 10.0, -1.8, 1.8, 18, Color("#e7fbff"), 2.0, true)
			draw_circle(Vector2(2, -3), 2.0, Color.WHITE)
		"electro":
			draw_polyline(PackedVector2Array([Vector2(-13, 4), Vector2(-5, -5), Vector2(0, 3), Vector2(7, -7), Vector2(14, 0)]), Color("#f7e8ff"), 3.6, true)
			draw_polyline(PackedVector2Array([Vector2(-8, 8), Vector2(0, 1), Vector2(5, 8)]), color, 2.4, true)
		"cryo":
			var shard := PackedVector2Array([Vector2(14, 0), Vector2(-3, -7), Vector2(-10, 0), Vector2(-3, 7)])
			draw_colored_polygon(shard, Color(color, 0.82))
			draw_polyline(PackedVector2Array([shard[0], shard[1], shard[2], shard[3], shard[0]]), Color("#f2ffff"), 1.8, true)
		"anemo":
			for ring in 2:
				draw_arc(Vector2(-2, 0), 7.0 + ring * 4.0, -1.35 + ring, 1.4 + ring, 18, Color(color, 0.92 - ring * 0.28), 2.5, true)
			draw_line(Vector2(-9, 0), Vector2(14, 0), Color("#e9fff6"), 2.0, true)
		"geo":
			var crystal := PackedVector2Array([Vector2(13, 0), Vector2(2, -8), Vector2(-10, -4), Vector2(-8, 6), Vector2(3, 8)])
			draw_colored_polygon(crystal, Color(color, 0.88))
			draw_polyline(PackedVector2Array([crystal[0], crystal[1], crystal[2], crystal[3], crystal[4], crystal[0]]), Color("#fff0b0"), 1.8, true)
		_:
			var wave := PackedVector2Array()
			for i in 9:
				var angle := lerpf(-0.95, 0.95, float(i) / 8.0)
				wave.append(Vector2(cos(angle) * 13.0, sin(angle) * 10.0))
			draw_polyline(wave, Color("#fff3c6"), 4.0, true)
			draw_polyline(wave, Color.WHITE, 1.3, true)
	draw_set_transform(Vector2.ZERO)

func _draw_animated_enemy(enemy: Dictionary, tint: Color, bob: float) -> void:
	var speed_scale := 1.28 if str(enemy.kind) in ["runner", "charger"] else 1.0
	var frame := posmod(floori(clock * 20.0 * speed_scale + enemy.id * 3.0), MONSTER_FRAMES)
	var visual_size := clampf(float(enemy.size) * 2.14, 86.0, 124.0)
	if str(enemy.kind) == "runner":
		visual_size *= 0.92
	var foot: Vector2 = enemy.pos + Vector2(0, ENEMY_FOOT_OFFSET + bob * 0.35)
	var facing := float(enemy.get("facing", -1.0))
	var pivot := SpriteAnchor.pivot(sprite_pivots, "hilichurl_run", frame, Vector2(MONSTER_CELL * 0.5, 242.0))
	var source := Rect2((frame % 6) * MONSTER_CELL, floori(frame / 6.0) * MONSTER_CELL, MONSTER_CELL, MONSTER_CELL)
	var art_tint := Color("#fff0e8") if enemy.flash > 0 and not reduced_effects else Color.WHITE
	_draw_anchored_texture_region(hilichurl_run_atlas, foot, Vector2.ONE * visual_size, Vector2.ONE * MONSTER_CELL, pivot, facing, 1.0, source, art_tint)

func _draw_slime_enemy(enemy: Dictionary, definition: Dictionary, texture: Texture2D, bob: float) -> void:
	var phase := clock * (7.8 if str(enemy.kind) == "charger" else 5.6) + float(enemy.id) * 0.73
	var lift := maxf(0.0, sin(phase))
	var landing := pow(1.0 - lift, 5.0)
	var width_scale := 1.0 + landing * 0.10
	var height_scale := 1.0 - landing * 0.12 + lift * 0.05
	if bool(enemy.get("attack_pending", false)) or bool(enemy.get("special_pending", false)):
		var windup := 0.5 + sin(clock * 18.0 + float(enemy.id)) * 0.5
		width_scale += 0.08 * windup
		height_scale -= 0.10 * windup
	if float(enemy.get("flash", 0.0)) > 0.0:
		width_scale += 0.16
		height_scale -= 0.14
	var base_size := float(definition.get("display_size", enemy.size * 2.0))
	var display_size := Vector2(base_size * width_scale, base_size * height_scale)
	var foot: Vector2 = Vector2(enemy.pos) + Vector2(0.0, ENEMY_FOOT_OFFSET + bob * 0.25 - lift * 9.0)
	var pivot_value: Array = definition.get("pivot", [256.0, 480.0])
	var pivot := Vector2(float(pivot_value[0]), float(pivot_value[1]))
	var art_tint := Color("#fff0e8") if float(enemy.get("flash",0.0)) > 0.0 and not reduced_effects else Color.WHITE
	_draw_anchored_texture_region(texture, foot, display_size, texture.get_size(), pivot, float(enemy.get("facing", -1.0)), float(definition.get("native_facing", 1.0)), Rect2(Vector2.ZERO, texture.get_size()), art_tint)

func _draw_anchored_texture_region(texture: Texture2D, anchor: Vector2, display_size: Vector2, source_size: Vector2, source_pivot: Vector2, facing: float, native_facing: float, source: Rect2, tint: Color) -> void:
	var placement_data := SpriteAnchor.placement(display_size, source_size, source_pivot, facing, native_facing)
	var local_transform := Transform2D(Vector2(float(placement_data.flip_x), 0.0), Vector2(0.0, 1.0), anchor)
	draw_set_transform_matrix(current_actor_transform * local_transform)
	draw_texture_rect_region(texture, placement_data.rect, source, tint)
	draw_set_transform_matrix(current_actor_transform)

func _draw_effect(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 0.6)))
	var t: float = clampf(1.0 - float(effect.life) / total, 0.0, 1.0)
	var fade: float = clampf(float(effect.life) / minf(0.18, total), 0.0, 1.0)
	if effect.kind == "muzzle" and not reduced_effects:
		var frames: Array[Texture2D] = muzzle_ion_frames if int(effect.value) == 1 else muzzle_fire_frames
		var muzzle_t: float = 1.0 - effect.life / 0.16
		var muzzle_index: int = clampi(floori(muzzle_t * frames.size()), 0, frames.size() - 1)
		draw_texture_rect(frames[muzzle_index], Rect2(effect.pos + Vector2(-32, -32), Vector2(64, 64)), false, Color.WHITE)
	elif effect.kind == "slash":
		if reduced_effects:
			var slash_color := element_color(str(effect.get("element", "")))
			draw_polyline(_arc_polyline(effect.pos, 62.0, -1.05, 1.05, 0.70, float(effect.get("angle", 0.0))), Color(slash_color, fade), 5.0, true)
		else:
			_draw_melee_slash(effect, t, fade)
	elif effect.kind in ["vaporize", "melt", "overloaded", "superconduct", "electro_charged", "frozen", "swirl", "crystallize", "element_burst", "shatter", "swirl_spread"]:
		var reaction_names := {"vaporize": "蒸发", "melt": "融化", "overloaded": "超载", "superconduct": "超导", "electro_charged": "感电", "frozen": "冻结", "swirl": "扩散", "swirl_spread": "扩散传播", "crystallize": "结晶", "shatter": "碎冰", "element_burst": "元素爆发"}
		var reaction_colors := {"vaporize": Color("#ffd082"), "melt": Color("#ffb28e"), "overloaded": Color("#ff7188"), "superconduct": Color("#b9a2ff"), "electro_charged": Color("#82bcff"), "frozen": Color("#b9f2ff"), "swirl": Color("#7ef0c5"), "swirl_spread": Color("#7ef0c5"), "crystallize": Color("#f3ca62"), "shatter": Color("#e8fbff"), "element_burst": Color("#ffffff")}
		var reaction_color: Color = Color(reaction_colors.get(effect.kind, Color.WHITE), fade)
		caption(effect.pos + Vector2(-27, -76 - t * 22), str(reaction_names.get(effect.kind, effect.kind)), reaction_color, 17)
		if not reduced_effects:
			draw_arc(effect.pos + Vector2(0, -17), 14 + t * 38, 0, TAU, 32, Color(reaction_color, fade * 0.7), 2.5)
	elif effect.kind in ["heal", "hurt"]:
		var healing: bool = effect.kind == "heal"
		var color := Color(0.5, 0.95, 0.73, fade) if healing else Color(1, 0.5, 0.5, fade)
		caption(effect.pos + Vector2(13, -35 - t * 30), ("+" if healing else "-") + str(effect.value), color, 15)
	elif effect.kind == "splash":
		if not reduced_effects:
			draw_arc(effect.pos, 15 + t * 50, 0, TAU, 32, Color(1, 0.7, 0.4, fade * 0.5), 2)
	elif effect.kind in ["chain", "pierce", "echo", "multishot"]:
		var accent := Color(0.73, 0.52, 1.0, fade) if effect.kind == "chain" else Color(1.0, 0.88, 0.56, fade)
		draw_arc(effect.pos + Vector2(0, -15), 9 + t * 34, -0.8, 0.8, 18, accent, 3.0, true)
		for ray in 4:
			var angle: float = -0.7 + ray * 0.45
			draw_line(effect.pos + Vector2.from_angle(angle) * 8.0, effect.pos + Vector2.from_angle(angle) * (24.0 + t * 28.0), accent, 2.0, true)
	elif effect.kind in ["barrage", "crossfire", "finale", "death_burst", "boss_summon", "enemy_volatile", "boss_move", "boss_phase", "ultimate_impact"]:
		var blast_color := Color(1.0, 0.30, 0.26, fade)
		for ring in 3:
			draw_arc(effect.pos, 18.0 + ring * 16.0 + t * 52.0, 0, TAU, 40, Color(blast_color, fade * (0.72 - ring * 0.16)), 4.0 - ring, true)
		for ray in 12:
			var direction := Vector2.from_angle(ray * TAU / 12.0)
			draw_line(effect.pos + direction * (9.0 + t * 25.0), effect.pos + direction * (30.0 + t * 85.0), Color(1.0, 0.76, 0.42, fade), 3.0, true)
		if effect.kind == "boss_phase":
			caption(effect.pos + Vector2(-72, -112 - t * 30), "PHASE %d · %s" % [int(effect.value), str(effect.get("name", "BOSS"))], Color(1.0, 0.66, 0.76, fade), 21)
		elif effect.kind == "boss_move":
			caption(effect.pos + Vector2(-80, -108 - t * 26), str(effect.get("name", effect.value)), Color(1.0, 0.62, 0.68, fade), 19)
		elif effect.kind == "enemy_volatile":
			caption(effect.pos + Vector2(-38, -86 - t * 22), "爆裂", Color(1.0, 0.48, 0.30, fade), 18)
	elif effect.kind in ["support_heal", "reinforcement", "frenzy", "contract_complete"]:
		var support_color := Color(0.48, 0.95, 0.79, fade)
		draw_arc(effect.pos, 16 + t * 62, 0, TAU, 40, support_color, 3.0, true)
		var support_text := "战术契约完成 · %s" % str(effect.get("reward", "")) if effect.kind == "contract_complete" else ("支援接入" if effect.kind != "frenzy" else "战意升级")
		caption(effect.pos + Vector2(-88, -58 - t * 20), support_text, support_color, 18)
	elif effect.kind == "kill_streak":
		var streak_color := Color(1.0, 0.35, 0.30, fade)
		caption(effect.pos + Vector2(-72, -105 - t * 38), "%d 连杀" % int(effect.value), streak_color, 28)
		if not reduced_effects:
			for ring in 3:
				draw_arc(effect.pos + Vector2(0, -18), 22.0 + ring * 15.0 + t * 58.0, 0, TAU, 36, Color(streak_color, fade * (0.8 - ring * 0.18)), 4.0 - ring, true)
	elif effect.kind == "hit":
		var impact_size := 19 if int(effect.value) >= 200 else 16
		var impact_color := element_color(str(effect.get("element", "")))
		caption(effect.pos + Vector2(-8, -31 - t * 34), str(effect.value), Color(impact_color.lightened(0.38), fade), impact_size)
		if not reduced_effects:
			draw_circle(effect.pos, 12.0 * (1.0 - t), Color.WHITE, false, 3.0, true)
			draw_arc(effect.pos, 10.0 + t * 42.0, -2.65, 0.75, 28, Color(impact_color, fade * 0.82), 4.2 * (1.0 - t) + 1.2, true)
			for i in 10:
				var angle := i * TAU / 10.0 + float(effect.pos.x as int % 7) * 0.07
				var direction := Vector2.from_angle(angle)
				var start := 5.0 + t * (12.0 + i % 3 * 4.0)
				var finish := start + 11.0 + (i % 4) * 5.0
				draw_line(effect.pos + direction * start, effect.pos + direction * finish, Color(impact_color.lightened(0.28), fade * 0.90), 3.2 - (i % 3) * 0.5, true)
	elif effect.kind == "critical":
		var critical_color := Color(1.0, 0.46, 0.22, fade)
		caption(effect.pos + Vector2(-54, -82 - t * 42), "CRITICAL  %d" % int(effect.value), critical_color, 23)
		draw_circle(effect.pos, 22.0 * (1.0 - t), Color(1.0, 0.92, 0.66, fade * 0.25))
		for ring in 2:
			draw_arc(effect.pos, 18.0 + ring * 13.0 + t * 54.0, ring * 1.4, ring * 1.4 + PI * 1.55, 34, Color(critical_color, fade * (0.90 - ring * 0.25)), 5.0 - ring * 1.5, true)
		for ray in 14:
			var direction := Vector2.from_angle(ray * TAU / 14.0 + 0.12)
			var side := direction.rotated(PI * 0.5)
			var tip: Vector2 = effect.pos + direction * (42.0 + t * 62.0)
			draw_colored_polygon(PackedVector2Array([effect.pos + direction * (8.0 + t * 18.0), tip + side * 2.4, tip - side * 2.4]), Color(critical_color, fade * 0.88))
	elif effect.kind == "shield_hit":
		caption(effect.pos + Vector2(-18, -65 - t * 24), "护盾 -%d" % int(effect.value), Color(0.48, 0.82, 1.0, fade), 14)
		draw_arc(effect.pos + Vector2(0, -18), 20 + t * 42, -2.7, 0.35, 24, Color(0.48, 0.82, 1.0, fade), 3.0, true)
	elif effect.kind == "shield_break":
		caption(effect.pos + Vector2(-38, -78 - t * 28), "BREAK", Color(0.72, 0.94, 1.0, fade), 20)
		for shard in 9:
			var direction := Vector2.from_angle(-2.8 + shard * 0.38)
			draw_line(effect.pos + direction * 19.0, effect.pos + direction * (42.0 + t * 48.0), Color(0.52, 0.84, 1.0, fade), 3.0, true)
	elif effect.kind in ["crystal_guard", "enemy_guard", "enemy_heal", "split", "enemy_duplicate"]:
		var helpful: bool = effect.kind in ["crystal_guard", "enemy_heal"]
		var status_color := Color(0.50, 0.95, 0.70, fade) if helpful else Color(0.55, 0.68, 1.0, fade)
		var status_name: String = str({"crystal_guard": "结晶护盾", "enemy_guard": "敌方加盾", "enemy_heal": "敌方治疗", "split": "分裂", "enemy_duplicate": "镜像增殖"}.get(effect.kind, effect.kind))
		draw_arc(effect.pos + Vector2(0, -18), 18 + t * 48, 0, TAU, 24, status_color, 3.0, true)
		caption(effect.pos + Vector2(-38, -70 - t * 20), status_name, status_color, 15)
	elif effect.kind == "boss_pulse":
		for ring in 4:
			draw_arc(effect.pos, 24.0 + ring * 22.0 + t * 95.0, 0, TAU, 48, Color(1.0, 0.20, 0.38, fade * (0.8 - ring * 0.14)), 4.0, true)
		caption(effect.pos + Vector2(-48, -105 - t * 35), "裂隙震荡", Color(1.0, 0.55, 0.66, fade), 20)
	elif effect.kind == "enemy_shot":
		draw_line(effect.pos + Vector2(0, -22), effect.pos + Vector2(-120, -8), Color(1.0, 0.42, 0.30, fade), 3.0, true)
		draw_circle(effect.pos + Vector2(-120.0 * t, -20.0 + t * 12.0), 4.0, Color(1.0, 0.8, 0.55, fade))
	elif effect.kind == "reward_taken":
		var mythic := str(effect.get("rarity", "")) == "mythic"
		var reward_color := Color(1.0, 0.38, 0.68, fade) if mythic else Color(1.0, 0.86, 0.54, fade)
		caption(effect.pos + Vector2(-100 if mythic else -70, -104 - t * 28), ("神话降临 · " if mythic else "强化装载 · ") + str(effect.value), reward_color, 24 if mythic else 18)
		if mythic:
			for ring in 4:
				draw_arc(effect.pos + Vector2(0, -20), 26.0 + ring * 18.0 + t * 56.0, clock + ring, clock + ring + PI * 1.4, 36, Color(reward_color, fade * (0.9 - ring * 0.16)), 4.0 - ring * 0.5, true)
	elif effect.kind == "element_attuned":
		var attuned_color: Color = Color(element_color(str(effect.value)), fade)
		for ring in 3:
			draw_arc(effect.pos + Vector2(0, -20), 22.0 + ring * 13.0 + t * 38.0, 0, TAU, 40, attuned_color, 3.0, true)
		caption(effect.pos + Vector2(-28, -105 - t * 20), element_glyph(str(effect.value)) + "元素共鸣", attuned_color, 19)
	elif effect.kind.begins_with("skill_"):
		var element: String = str(effect.kind).trim_prefix("skill_")
		_draw_element_skill(effect.pos, element, t, fade)
		var label_color := element_color(element) if element != "none" else Color("#ffe4a3")
		caption(effect.pos + Vector2(-58, -122 - t * 30), _skill_display_name(element), Color(label_color, fade), 20)
	elif effect.kind in ["geo_hit", "geo_break"]:
		var geo_color := Color(1.0, 0.76, 0.31, fade)
		for shard in 7:
			var direction := Vector2.from_angle(-2.8 + shard * 0.45)
			draw_line(effect.pos + direction * 8.0, effect.pos + direction * (22.0 + t * 45.0), geo_color, 3.0, true)
	elif effect.kind in ["mechanism_pulse", "weather_pulse", "trap_pulse", "terrain_hit", "terrain_break", "formation", "knockback"]:
		var terrain_color := Color(1.0, 0.69, 0.30, fade) if effect.kind != "formation" else Color(0.46, 0.95, 0.77, fade)
		for ring in 3:
			draw_arc(effect.pos, 14.0 + ring * 15.0 + t * 52.0, 0, TAU, 36, Color(terrain_color, fade * (0.75 - ring * 0.16)), 3.0, true)
		if effect.kind == "terrain_break": caption(effect.pos + Vector2(-42, -62), "捷径开启", terrain_color, 17)
		elif effect.kind == "formation": caption(effect.pos + Vector2(-42, -62), "全队移动", terrain_color, 17)
		elif effect.kind == "weather_pulse": caption(effect.pos + Vector2(-42, -62), "天气脉冲", terrain_color, 15)
		elif effect.kind == "trap_pulse": caption(effect.pos + Vector2(-32, -62), "陷阱", terrain_color, 15)
	elif effect.kind in ["enemy_blink", "skill_suppressed", "vfx_cue"]:
		var cue_color := Color(0.78, 0.42, 1.0, fade) if effect.kind != "skill_suppressed" else Color(1.0, 0.34, 0.45, fade)
		for ring in 3:
			draw_arc(effect.pos, 12.0 + ring * 13.0 + t * 50.0, t * 2.0 + ring, t * 2.0 + ring + PI * 1.45, 30, Color(cue_color, fade * (0.86 - ring * 0.19)), 3.5 - ring * 0.6, true)
		if effect.kind == "enemy_blink": caption(effect.pos + Vector2(-28, -70 - t * 18), "闪现", cue_color, 15)
		elif effect.kind == "skill_suppressed": caption(effect.pos + Vector2(-38, -70 - t * 18), "技能封锁", cue_color, 15)
	elif effect.kind in ["death", "down"]:
		if not reduced_effects:
			draw_arc(effect.pos, 10 + t * 27, 0, TAU, 24, Color(0.8, 0.4, 0.42, fade * 0.6), 1.5)
	elif effect.kind == "move":
		draw_arc(effect.pos, 7 + t * 19, 0, TAU, 24, Color(0.55, 0.86, 0.78, fade), 1.5)


func _arc_polyline(center: Vector2, radius: float, start_angle: float, end_angle: float, squash: float = 0.72, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 25:
		var angle := lerpf(start_angle, end_angle, float(index) / 24.0)
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * squash).rotated(rotation))
	return points

func _draw_melee_slash(effect: Dictionary, t: float, fade: float) -> void:
	var element := str(effect.get("element", ""))
	var color := element_color(element)
	var angle := float(effect.get("angle", 0.0))
	var scale_phase := 0.72 + sin(t * PI) * 0.42
	var arc := _arc_polyline(effect.pos, 76.0 * scale_phase, -1.18, 1.18, 0.72, angle)
	var inner := _arc_polyline(effect.pos, 61.0 * scale_phase, -1.05, 1.05, 0.72, angle)
	draw_polyline(arc, Color(color, fade * 0.20), 24.0 * (1.0 - t * 0.35), true)
	draw_polyline(arc, Color(color.lightened(0.24), fade * 0.92), 9.0 * (1.0 - t * 0.25), true)
	draw_polyline(inner, Color(Color.WHITE, fade * 0.96), 2.5, true)
	var frame_index: int = clampi(floori(t * slash_frames.size()), 0, slash_frames.size() - 1)
	var texture_size := 176.0 * scale_phase
	draw_texture_rect(slash_frames[frame_index], Rect2(effect.pos + Vector2(-texture_size * 0.5, -texture_size * 0.62), Vector2(texture_size, texture_size)), false, Color(color.lightened(0.34), fade * 0.48))
	for shard in 9:
		var shard_angle := angle - 1.0 + shard * 0.25
		var direction := Vector2.from_angle(shard_angle)
		var side := direction.rotated(PI * 0.5)
		var start: Vector2 = effect.pos + direction * (24.0 + t * 35.0)
		var tip: Vector2 = effect.pos + direction * (52.0 + t * 78.0)
		draw_colored_polygon(PackedVector2Array([start - side * 2.5, tip, start + side * 2.5]), Color(color.lightened(0.35), fade * 0.86))
	if bool(effect.get("critical", false)):
		draw_circle(effect.pos, 32.0 * (1.0 - t), Color(1.0, 0.88, 0.54, fade * 0.26))
		draw_arc(effect.pos, 36.0 + t * 62.0, 0.0, TAU, 36, Color(1.0, 0.72, 0.36, fade), 5.0, true)

func _draw_element_skill(center: Vector2, element: String, t: float, fade: float) -> void:
	var color := element_color(element) if element != "none" else Color("#ffe4a3")
	draw_circle(center, 48.0 + sin(t * PI) * 26.0, Color(color, fade * 0.12))
	match element:
		"pyro":
			for flame in 10:
				var angle := flame * TAU / 10.0 + t * 0.65
				var direction := Vector2.from_angle(angle)
				var side := direction.rotated(PI * 0.5)
				var root := center + direction * (18.0 + t * 30.0)
				var tip := center + direction * (72.0 + t * 96.0)
				draw_colored_polygon(PackedVector2Array([root - side * 13.0, tip, root + side * 13.0]), Color(color, fade * 0.70))
			draw_circle(center, 28.0 * (1.0 - t * 0.5), Color("#fff0b8"), false, 7.0, true)
		"hydro":
			for wave in 4:
				var radius := 30.0 + wave * 22.0 + t * 62.0
				draw_polyline(_arc_polyline(center + Vector2(0, wave * 4.0), radius, -2.82, -0.16, 0.42, wave * 0.26), Color(color.lightened(0.18 * wave), fade * (0.92 - wave * 0.15)), 7.0 - wave, true)
			for bubble in 9:
				var bubble_pos := center + Vector2.from_angle(bubble * 2.4 + t) * (28.0 + bubble * 8.0 + t * 42.0)
				draw_circle(bubble_pos, 4.0 + bubble % 3 * 2.0, Color(color, fade * 0.75), false, 2.0, true)
		"electro":
			for bolt in 10:
				var direction := Vector2.from_angle(bolt * TAU / 10.0 + t * 0.32)
				var side := direction.rotated(PI * 0.5)
				var start := center + direction * 12.0
				var mid_a := center + direction * (42.0 + t * 35.0) + side * (10.0 if bolt % 2 == 0 else -10.0)
				var mid_b := center + direction * (72.0 + t * 55.0) - side * 8.0
				var tip := center + direction * (112.0 + t * 70.0)
				draw_polyline(PackedVector2Array([start, mid_a, mid_b, tip]), Color(color, fade * 0.40), 9.0, true)
				draw_polyline(PackedVector2Array([start, mid_a, mid_b, tip]), Color("#fff4ff", fade), 2.7, true)
		"cryo":
			for shard in 12:
				var angle := shard * TAU / 12.0
				var direction := Vector2.from_angle(angle)
				var side := direction.rotated(PI * 0.5)
				var base := center + direction * (24.0 + t * 28.0)
				var tip := center + direction * (82.0 + t * 82.0)
				draw_colored_polygon(PackedVector2Array([base - side * 8.0, tip, base + side * 8.0]), Color(color, fade * 0.74))
				draw_line(base, tip, Color("#f4ffff", fade), 2.2, true)
		"anemo":
			for spiral in 5:
				var radius := 34.0 + spiral * 18.0 + t * 66.0
				var rotation := t * 2.1 + spiral * 1.18
				draw_polyline(_arc_polyline(center, radius, -1.35, 1.55, 0.66, rotation), Color(color.lightened(spiral * 0.06), fade * (0.94 - spiral * 0.13)), 8.0 - spiral, true)
		"geo":
			for shard in 8:
				var angle := shard * TAU / 8.0 + 0.39
				var direction := Vector2.from_angle(angle)
				var side := direction.rotated(PI * 0.5)
				var root := center + direction * (26.0 + t * 30.0)
				var tip := center + direction * (80.0 + t * 62.0)
				draw_colored_polygon(PackedVector2Array([root - side * 12.0, tip, root + side * 12.0, center + direction * 10.0]), Color(color, fade * 0.68))
				draw_polyline(PackedVector2Array([root - side * 12.0, tip, root + side * 12.0]), Color("#fff0ad", fade), 2.4, true)
		_:
			for slash in 4:
				var rotation := slash * PI * 0.5 + t * 0.5
				draw_polyline(_arc_polyline(center, 54.0 + slash * 12.0 + t * 58.0, -1.05, 1.05, 0.66, rotation), Color(color, fade * (0.95 - slash * 0.16)), 8.0 - slash, true)
	for ring in 3:
		draw_arc(center, 22.0 + ring * 28.0 + t * 92.0, t * (1.0 + ring), t * (1.0 + ring) + PI * 1.58, 42, Color(color, fade * (0.78 - ring * 0.18)), 4.0 - ring * 0.7, true)


func _skill_display_name(element: String) -> String:
	return {"none": "断空剑阵", "anemo": "苍风龙卷", "electro": "雷霆链狱", "pyro": "烈焰星坠", "hydro": "潮汐回响", "geo": "岩脊构筑", "cryo": "霜华禁锢"}.get(element, "元素爆发")

func element_color(element: String) -> Color:
	return {"anemo": Color("#63e6c0"), "electro": Color("#bf83ff"), "pyro": Color("#ff745c"), "hydro": Color("#5ab8ff"), "geo": Color("#e8b94d"), "cryo": Color("#9de7f2")}.get(element, Color("#f0dfb8"))

func element_glyph(element: String) -> String:
	return {"anemo": "风", "electro": "雷", "pyro": "火", "hydro": "水", "geo": "岩", "cryo": "冰"}.get(element, "")
