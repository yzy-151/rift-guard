extends Node2D
signal stage_exit_finished
## All effects are cosmetic; gameplay remains in CombatSimulation.
const Stage = preload("res://scripts/stage_projection.gd")
const STAGE_VISUAL = preload("res://data/stage_visual_profile.tres")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const WORLD = Rect2(40, 140, 1200, 440)
const ENDLESS_PLAYFIELD_SCREEN = Rect2(16, 88, 1248, 490)
const Sim = preload("res://scripts/combat_simulation.gd")
const ReusableEffectPool = preload("res://scripts/reusable_effect_pool.gd")
const SpriteAnchor = preload("res://scripts/sprite_anchor.gd")
const UnitVisualActor = preload("res://scripts/unit_visual_actor.gd")
const CharacterSequenceLibrary = preload("res://scripts/character_sequence_library.gd")
const EnemySequenceLibrary = preload("res://scripts/enemy_sequence_library.gd")
const CombatFeedbackDirector = preload("res://scripts/combat_feedback_director.gd")
const StageSurfaceRenderer = preload("res://scripts/stage_surface_renderer.gd")
const VfxPipeline = preload("res://scripts/vfx_pipeline.gd")
const VFX_FLARE = preload("res://assets/vfx/third_party/kenney_particle/flare_01.png")
const VFX_SPARK = preload("res://assets/vfx/third_party/kenney_particle/spark_05.png")
const VFX_MAGIC = preload("res://assets/vfx/third_party/kenney_particle/magic_01.png")
const VFX_TRACE = preload("res://assets/vfx/third_party/kenney_particle/trace_05.png")
const TILE_HAZARD = preload("res://assets/world/terrain_tiles_v64/target_EXPORT0001.png")
const TILE_HIGH_GROUND = preload("res://assets/world/terrain_tiles_v64/pentaGraphic 1.png")
const TILE_LOW_GROUND = preload("res://assets/world/terrain_tiles_v64/PORTAL0012.png")
const TILE_ATTACK_GROUND = preload("res://assets/world/terrain_tiles_v64/huge_vfx0002.png")
const TILE_BLOCKED = preload("res://assets/world/terrain_tiles_v64/labLaser0002.png")
## 无尽模式墙体与大门素材（石块 / 锁箱 / 铁箱，来源见 assets/world/endless/README.md）
const WALL_STONES: Array[Texture2D] = [
	preload("res://assets/world/endless/stone_wall_a.png"),
	preload("res://assets/world/endless/stone_wall_b.png"),
	preload("res://assets/world/endless/stone_wall_c.png"),
]
## 石块素材里"整块"和"只有顶面"的区域（纵向叠放只裁顶面）
const WALL_STONE_FULL := Rect2(11, 10, 78, 83)
const WALL_STONE_TOP := Rect2(11, 10, 78, 48)
## 纵向墙块距收紧系数：小于 1 表示靠下的块压住上一块的底缘，只露顶面
const WALL_STACK_TIGHTNESS := 0.82
## 横墙上的门 = 锁箱；竖墙上的门 = 铁箱
const GATE_CHEST_TEXTURE = preload("res://assets/world/endless/gate_chest_h.png")
const GATE_CHEST_FULL := Rect2(3, 3, 93, 92)
const GATE_CRATE_TEXTURE = preload("res://assets/world/endless/gate_crate_v.png")
const GATE_CRATE_FULL := Rect2(1, 1, 78, 83)
const ENDLESS_FLOOR_TILES: Array[Texture2D] = [
	preload("res://assets/world/endless/helltaker/labFloor0001.png"),
	preload("res://assets/world/endless/helltaker/labFloor0002.png"),
	preload("res://assets/world/endless/helltaker/labFloor0003.png"),
	preload("res://assets/world/endless/helltaker/labFloor0004.png"),
	preload("res://assets/world/endless/helltaker/labFloor0005.png"),
	preload("res://assets/world/endless/helltaker/labFloor0006.png"),
	preload("res://assets/world/endless/helltaker/labFloor0007.png"),
	preload("res://assets/world/endless/helltaker/labFloor0008.png"),
]
const ENDLESS_BOSS_FLOOR = preload("res://assets/world/endless/helltaker/bossFloor.png")
const CHAPTER1_STAGE_IDS := ["stage_01"]
const CHAPTER1_BLEND_SHADER = preload("res://shaders/chapter1_scene_blend.gdshader")

const INK = Color("#0c1017")
const TEAL = Color("#8fdbc8")
const RED = Color("#d66769")
var sim
var chapter1_blend_material: ShaderMaterial
var selected_id: int = 0
var reduced_effects: bool = false
var effects: Array[Dictionary] = []
var effect_pool = ReusableEffectPool.new()
var clock: float = 0.0
var shot_flashes: Dictionary = {}
var hero_attack_visuals: Dictionary = {}
var departing_recruit: Dictionary = {}
var hero_down_visuals: Dictionary = {}
var enemy_death_visuals: Array[Dictionary] = []
var projectile_trails: Dictionary = {}
var redraw_accumulator: float = 0.0
var stage_tile_cache: Array[Dictionary] = []
var stage_tile_cache_id := ""
var stage_decal_cache: Array[PackedVector2Array] = []
var sprite_pivots: Dictionary = {}
var enemy_visual_textures: Dictionary = {}
var unit_visual_actors: Dictionary = {}
var character_sequences = CharacterSequenceLibrary.new()
var enemy_sequences = EnemySequenceLibrary.new()
var feedback_director = CombatFeedbackDirector.new()
var surface_renderer = StageSurfaceRenderer.new()
var debug_visual_matrix: Array[Dictionary] = []
var debug_anchor_error_max := 0.0
var debug_damage_shape_error_max := 0.0
var debug_route_overlap_alpha := 0.30
var debug_telegraphs_visible := true
var debug_portal_phases: Array[String] = []
var debug_stage_layer_order: Array[String] = []
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
var skill_preview_ultimate: bool = false
var deploy_preview_active: bool = false
var deploy_preview_id: int = -1
var deploy_preview_point: Vector2 = Vector2.ZERO
var deploy_preview_valid := false
var skill_point: Vector2 = Vector2(760, 360)
var camera_center: Vector2 = Vector2(640, 360)
var atlas: Texture2D = preload("res://assets/tiny-dungeon.png")
var stage_background_1: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0001.png")
var stage_background_2: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0002.png")
var stage_background_3: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0003.png")
var stage_background_4: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0004.png")
var stage_background_5: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0005.png")
var stage_background_6: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0006.png")
var stage_background_7: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0007.png")
var stage_background_8: Texture2D = preload("res://assets/helltaker/backgrounds/chapterBG0008.png")
var crystal_texture: Texture2D = preload("res://assets/world/crystal-growth.svg")
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
	chapter1_blend_material = ShaderMaterial.new()
	chapter1_blend_material.shader = CHAPTER1_BLEND_SHADER
	_update_chapter1_material()
	sprite_pivots = SpriteAnchor.load_catalog()
	_load_enemy_visuals()
	feedback_director.setup(sim.database if sim != null else null)
	_build_visual_matrix()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	_build_stage_tile_cache(sim.current_stage_id if sim != null else "stage_01")

func _update_chapter1_material() -> void:
	if _is_chapter_one_stage():
		if material != chapter1_blend_material:
			material = chapter1_blend_material
	elif material != null:
		material = null

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
	_update_chapter1_material()
	clock += dt
	_sync_unit_visuals(dt)
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
	var living_deaths: Array[Dictionary] = []
	for death_visual: Dictionary in enemy_death_visuals:
		death_visual.elapsed = float(death_visual.get("elapsed", 0.0)) + dt
		if float(death_visual.elapsed) <= float(death_visual.get("total", 0.6)):
			living_deaths.append(death_visual)
	enemy_death_visuals = living_deaths
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
	redraw_accumulator += dt
	var redraw_interval := 1.0 / (30.0 if reduced_effects else 60.0)
	if redraw_accumulator >= redraw_interval:
		redraw_accumulator = fmod(redraw_accumulator, redraw_interval)
		queue_redraw()

func play_recruit_departure(character_id: String, start_point: Vector2) -> void:
	if character_sequences.texture(character_id, "run") == null:
		return
	var target := Vector2(100, 365)
	var started_at := Time.get_ticks_msec()
	departing_recruit = {"character_id": character_id, "pos": start_point, "frame": 0}
	while true:
		var elapsed := float(Time.get_ticks_msec() - started_at) / 1000.0
		var progress := clampf(elapsed / 1.35, 0.0, 1.0)
		departing_recruit.pos = start_point.lerp(target, progress)
		departing_recruit.frame = character_sequences.frame_at_time(character_id, "run", elapsed)
		queue_redraw()
		if progress >= 1.0:
			break
		await get_tree().process_frame
	departing_recruit.clear()
	queue_redraw()

func world_to_screen(point: Vector2) -> Vector2:
	if sim != null and sim.endless_mode:
		return point - camera_center + ENDLESS_PLAYFIELD_SCREEN.get_center()
	return Stage.project(point)

func screen_to_world(point: Vector2) -> Vector2:
	if sim != null and sim.endless_mode:
		return point + camera_center - ENDLESS_PLAYFIELD_SCREEN.get_center()
	return Stage.unproject(point)

func visible_world_rect() -> Rect2:
	if sim != null and sim.endless_mode:
		return Rect2(screen_to_world(ENDLESS_PLAYFIELD_SCREEN.position), ENDLESS_PLAYFIELD_SCREEN.size)
	return WORLD

func world_depth_scale(point: Vector2) -> float:
	return 1.0 if sim != null and sim.endless_mode else Stage.depth_scale(point)

func _render_point_visible(point: Vector2, margin: float = 160.0) -> bool:
	return sim == null or not sim.endless_mode or visible_world_rect().grow(margin).has_point(point)


func _is_chapter_one_stage() -> bool:
	return sim != null and str(sim.current_stage_id) in CHAPTER1_STAGE_IDS

func _build_visual_matrix() -> void:
	debug_visual_matrix.clear()
	if sim == null or sim.database == null:
		return
	for character_id: String in sim.database.characters:
		debug_visual_matrix.append({"character_id":character_id,"facing":-1.0})
		debug_visual_matrix.append({"character_id":character_id,"facing":1.0})

func _sync_unit_visuals(dt: float) -> void:
	if sim == null:
		return
	for hero: Dictionary in sim.heroes:
		var id := str(hero.get("character_id", ""))
		if not unit_visual_actors.has(id):
			var actor = UnitVisualActor.new()
			actor.setup(id, sim.database.animation_profiles.get(id, {}))
			unit_visual_actors[id] = actor
		unit_visual_actors[id].sync(hero, dt)

func visual_sample(hero: Dictionary) -> Dictionary:
	var id := str(hero.get("character_id", ""))
	return unit_visual_actors[id].sample() if unit_visual_actors.has(id) else {"scale":Vector2.ONE,"offset":Vector2.ZERO}

func _dense_vfx_group(kind: String) -> String:
	if kind in ["hit", "critical", "slash", "splash", "chain", "pierce", "multishot", "orbit_hit"]:
		return "impact"
	if kind in ["vaporize", "melt", "overloaded", "superconduct", "electro_charged", "swirl", "crystallize", "shatter", "swirl_spread"]:
		return "reaction"
	return ""

func _try_merge_dense_vfx(event: Dictionary) -> bool:
	if sim == null or sim.enemies.size() < 60:
		return false
	var group := _dense_vfx_group(str(event.get("kind", "")))
	if group.is_empty():
		return false
	var radius := 78.0 if sim.enemies.size() < 100 else 104.0
	for index in range(effects.size() - 1, -1, -1):
		var existing: Dictionary = effects[index]
		if str(existing.get("merge_group", "")) != group:
			continue
		if Vector2(existing.get("pos", Vector2.ZERO)).distance_to(Vector2(event.get("pos", Vector2.ZERO))) > radius:
			continue
		existing.life = maxf(float(existing.get("life", 0.0)), 0.16)
		if event.get("value", 0) is int or event.get("value", 0) is float:
			existing.value = float(existing.get("value", 0.0)) + float(event.get("value", 0.0))
		effects[index] = existing
		return true
	return false
func accept_events(batch: Array[Dictionary]) -> void:
	for event in batch:
		if sim != null and sim.endless_mode and event.has("pos") and str(event.get("kind", "")) not in ["boss_arrival", "boss_phase", "arena_event", "lost", "won"] and not _render_point_visible(Vector2(event.pos), 260.0):
			continue
		if event.kind == "death" and enemy_sequences.has_enemy(str(event.get("enemy_kind", ""))) and enemy_death_visuals.size() < (24 if sim != null and sim.enemies.size() >= 100 else 48):
			var enemy_id := str(event.enemy_kind)
			enemy_death_visuals.append({
				"kind": enemy_id,
				"pos": Vector2(event.pos),
				"facing": float(event.get("facing", -1.0)),
				"size": float(event.get("size", 48.0)),
				"elapsed": 0.0,
				"total": enemy_sequences.duration(enemy_id, "down") + 0.16,
			})
		var feedback: Dictionary = feedback_director.observe(event)
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
				var attack_duration := maxf(1.0 / 60.0, float(event.get("duration", 1.0 / maxf(0.1, float(hero.rate)))))
				hero_attack_visuals[event.hero_id] = {"elapsed": 0.0, "duration": attack_duration}
				if sim == null or sim.performance_budget.can_spawn_cosmetic("muzzle", effects.size()):
					var facing := float(hero.get("facing", 1.0))
					effects.append(effect_pool.acquire({"kind":"muzzle","pos":event.pos+Vector2(25.0*facing,-20),"value":1 if hero.get("element","")=="electro" else 0,"element":hero.get("element","") ,"style":str(event.get("style", hero.get("attack_style", "standard")))},0.16))
			"hit", "critical", "death", "move", "formation", "hurt", "down", "heal", "arena_event", "vaporize", "melt", "overloaded", "superconduct", "electro_charged", "frozen", "swirl", "crystallize", "element_burst", "shatter", "swirl_spread", "slash", "splash", "multishot", "pierce", "chain", "echo", "death_burst", "frenzy", "kill_streak", "reinforcement", "support_heal", "crossfire", "finale", "barrage", "shield_hit", "shield_break", "knockback", "crystal_guard", "enemy_heal", "enemy_guard", "goblin_spawn", "split", "enemy_duplicate", "enemy_blink", "enemy_volatile", "skill_suppressed", "boss_move", "contract_complete", "boss_phase", "weather_pulse", "trap_pulse", "boss_pulse", "boss_summon", "enemy_shot", "reward_taken", "element_attuned", "skill_none", "skill_anemo", "skill_electro", "skill_pyro", "skill_hydro", "skill_geo", "skill_cryo", "geo_hit", "geo_break", "mechanism_pulse", "terrain_hit", "terrain_break", "deploy", "recall", "dodge", "skill_cast", "skill_impact", "vfx_cue", "ultimate_cast", "ultimate_impact", "synced_impact", "orbit_hit", "orbit_storm", "tag_synergy", "relic_awaken", "revive":
				if _try_merge_dense_vfx(event):
					continue
				if sim != null and not sim.performance_budget.can_spawn_cosmetic(str(event.kind), effects.size()):
					continue
				var visual_event: Dictionary = event.duplicate(true)
				visual_event.merge_group = _dense_vfx_group(str(event.kind))
				if event.kind == "enemy_shot":
					visual_event.direction = Vector2(event.get("target", event.pos)) - Vector2(event.pos)
					visual_event.target = Vector2(event.get("target", event.pos))
				visual_event.feedback_theme = feedback.theme
				visual_event.feedback_theme_id = feedback.theme_id
				var effect_duration := float(event.get("duration", 0.6))
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
	_draw_arena_events()
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
		if _render_point_visible(Vector2(zone.get("pos", Vector2.ZERO)), 180.0):
			_draw_skill_zone(zone)
	for construct: Dictionary in sim.geo_constructs:
		if _render_point_visible(Vector2(construct.get("pos", Vector2.ZERO)), 140.0):
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
	var render_world := visible_world_rect().grow(180.0) if sim.endless_mode else WORLD
	for enemy in sim.enemies:
		if render_world.has_point(enemy.pos):
			actors.append({"unit": enemy, "hero": false, "death": false})
	for death_visual: Dictionary in enemy_death_visuals:
		if render_world.has_point(death_visual.pos):
			actors.append({"unit": death_visual, "hero": false, "death": true})
	for hero in sim.heroes:
		if bool(hero.get("deployed", true)) and render_world.has_point(hero.pos):
			actors.append({"unit": hero, "hero": true})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.unit.pos.y < b.unit.pos.y)
	for actor in actors:
		var unit: Dictionary = actor.unit
		var point: Vector2 = world_to_screen(unit.pos)
		var scale_factor: float = world_depth_scale(unit.pos)
		current_actor_transform = Transform2D(Vector2(scale_factor, 0.0), Vector2(0.0, scale_factor), point)
		draw_set_transform_matrix(current_actor_transform)
		var shadow_foot := Vector2(0.0, HERO_FOOT_OFFSET if actor.hero else ENEMY_FOOT_OFFSET)
		var keep_shadow := bool(actor.hero) or not reduced_effects or str(unit.get("kind", "")).begins_with("boss_") or int(unit.get("id", 0)) % 2 == 0
		if keep_shadow:
			draw_ellipse_shadow(shadow_foot - Vector2(0.0, 9.0), 28.0 if actor.hero else unit.size * 0.48, Color(0, 0, 0, 0.5))
		draw_set_transform_matrix(current_actor_transform)
		var visual: Dictionary = unit.duplicate()
		visual.pos = Vector2.ZERO
		if actor.hero:
			_draw_hero(visual)
		elif bool(actor.get("death", false)):
			_draw_enemy_death_visual(visual)
		else:
			_draw_enemy(visual)
		draw_set_transform(Vector2.ZERO)
	if not departing_recruit.is_empty():
		_draw_departing_recruit()
	for projectile in sim.projectiles:
		if _render_point_visible(Vector2(projectile.get("pos", Vector2.ZERO)), 120.0):
			_draw_projectile(projectile)
	for projectile: Dictionary in sim.enemy_projectiles:
		if _render_point_visible(Vector2(projectile.pos), 120.0):
			var point := world_to_screen(Vector2(projectile.pos)) + Vector2(0, -17)
			var size := 8.0 * world_depth_scale(Vector2(projectile.pos))
			draw_circle(point, size + 4.0, Color(0.26, 0.12, 0.42, 0.38))
			draw_circle(point, size, Color(0.60, 0.38, 0.88, 0.95))
			draw_circle(point + Vector2(-2, -2), size * 0.38, Color(0.94, 0.86, 1.0, 0.96))
	for effect in effects:
		if not _render_point_visible(Vector2(effect.get("pos", Vector2.ZERO)), 180.0):
			continue
		var point: Vector2 = world_to_screen(effect.pos)
		var scale_factor: float = world_depth_scale(effect.pos)
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		var visual: Dictionary = effect.duplicate()
		visual.pos = Vector2.ZERO
		_draw_effect(visual)
		draw_set_transform(Vector2.ZERO)
	_draw_stage_foreground()
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
	if character_sequences.has_character(stage_exit_character_id):
		var newcomer_texture := character_sequences.texture(stage_exit_character_id, "idle")
		if newcomer_texture != null:
			var newcomer_source := character_sequences.source_rect(stage_exit_character_id, "idle", 0)
			var newcomer_size := minf(108.0, character_sequences.display_size(stage_exit_character_id))
			_draw_anchored_texture_region(newcomer_texture, actor + Vector2(0, 8), Vector2.ONE * newcomer_size, character_sequences.cell(stage_exit_character_id), character_sequences.pivot(stage_exit_character_id), -1.0, 1.0, newcomer_source, Color.WHITE)
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
		var warning_world: Vector2 = enemy.get("warning_pos", enemy.pos)
		if bool(enemy.get("attack_pending", false)) and float(enemy.get("attack_range", 0.0)) > 0.0 and _render_point_visible(warning_world, 120.0):
			var center := world_to_screen(warning_world)
			var radius := float(enemy.get("warning_radius", 60.0)) * 0.62 * world_depth_scale(enemy.pos)
			var ratio := clampf(float(enemy.get("warning_timer", 0.0)) / 1.05, 0.0, 1.0)
			draw_circle(center, radius, Color(0.95, 0.12, 0.18, 0.10 + (1.0-ratio)*0.16))
			draw_arc(center, radius, -PI*0.5, -PI*0.5 + TAU*(1.0-ratio), 48, Color("#ff5267"), 4.0, true)
			draw_line(world_to_screen(enemy.pos), center, Color(1.0,0.25,0.32,0.52), 2.0, true)
			_draw_warning_reticle(center, radius, ratio, float(enemy.get("warning_timer", 0.0)), false)
		if bool(enemy.get("special_pending", false)):
			for warning_point: Variant in enemy.get("special_warning_positions", [enemy.pos]):
				if not _render_point_visible(Vector2(warning_point), 220.0):
					continue
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
				var special_total := maxf(0.01, float(enemy.get("special_warning_total", 1.8)))
				var special_ratio := clampf(float(enemy.get("special_warning", 0.0)) / special_total, 0.0, 1.0)
				_draw_warning_reticle(center, radius, special_ratio, float(enemy.get("special_warning", 0.0)), true, str(enemy.get("special_move_name", "BOSS SKILL")))

func _draw_warning_reticle(center: Vector2, radius: float, ratio: float, seconds: float, boss: bool, title: String = "") -> void:
	var color := Color("#ff8b9a") if boss else Color("#ff5267")
	var ring_radius := radius + (10.0 if boss else 6.0)
	draw_arc(center, ring_radius, 0.0, TAU, 64, Color(color, 0.42), 1.5 if not boss else 2.4, true)
	draw_arc(center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - ratio), 64, Color(color, 0.96), 4.0 if not boss else 6.0, true)
	for tick in 8:
		var angle := tick * TAU / 8.0
		var direction := Vector2.from_angle(angle)
		draw_line(center + direction * (ring_radius - 4.0), center + direction * (ring_radius + 7.0), Color(color, 0.86), 2.0, true)
	draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), Color(color, 0.72), 1.4, true)
	draw_line(center + Vector2(0, -10), center + Vector2(0, 10), Color(color, 0.72), 1.4, true)
	caption(center + Vector2(-13, 5), "%.1f" % maxf(0.0, seconds), Color("#fff4ee"), 15 if boss else 12)
	if boss and not title.is_empty():
		caption(center + Vector2(-minf(92.0, title.length() * 5.5), -ring_radius - 13.0), title, Color("#ffd2d8"), 13)

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
	var allowed: bool = deploy_preview_valid
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
	var ability: Dictionary = hero.get("ultimate", {}) if skill_preview_ultimate else hero.get("active_skill", {})
	var radius: float = float(ability.get("radius", 170.0)) * (1.0 + sim.skill_area_bonus)
	var center := world_to_screen(skill_point)
	var hero_center := world_to_screen(hero.pos)
	var radius_x := radius * 0.62 * world_depth_scale(skill_point)
	var radius_y := radius_x * 0.32
	var points := PackedVector2Array()
	for i in 64:
		var angle := i * TAU / 64.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
	draw_colored_polygon(points, Color(color, 0.16 if skill_preview_ultimate else 0.11))
	for ring in 3:
		var ring_scale := 1.0 - float(ring) * 0.14
		draw_set_transform(center, 0.0, Vector2(1.0, radius_y / maxf(1.0, radius_x)))
		draw_arc(Vector2.ZERO, radius_x * ring_scale, 0.0, TAU, 64, Color(color, 0.82 - ring * 0.20), 2.8 if ring == 0 else 1.2, true)
		draw_set_transform(Vector2.ZERO)
	for segment in 12:
		var angle := segment * TAU / 12.0 + clock * (0.46 if skill_preview_ultimate else 0.28)
		var a := center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		var b := center + Vector2(cos(angle + 0.18) * radius_x, sin(angle + 0.18) * radius_y)
		draw_line(a, b, Color(color, 0.96), 3.0, true)
	draw_dashed_line(hero_center, center, Color(color, 0.52), 1.5, 10.0, true)
	draw_circle(center, 7.0 + sin(clock * 6.0) * 1.5, Color(color, 0.92))
	draw_line(center - Vector2(15, 0), center + Vector2(15, 0), Color.WHITE, 1.4, true)
	draw_line(center - Vector2(0, 10), center + Vector2(0, 10), Color.WHITE, 1.4, true)
	var title: String = sim.hero_ultimate_name(selected_id) if skill_preview_ultimate else sim.hero_skill_name(selected_id)
	var key_hint := "E · 终结技落点" if skill_preview_ultimate else "Q · 战技落点"
	caption(center + Vector2(-72, -radius_y - 38), key_hint, Color.WHITE, 12)
	caption(center + Vector2(-72, -radius_y - 20), title, color, 15)

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

func _build_stage_tile_cache(stage_id: String = "stage_01") -> void:
	stage_tile_cache.clear()
	stage_decal_cache.clear()
	stage_tile_cache_id = stage_id
	var palette: Dictionary = STAGE_VISUAL.palette(stage_id)
	var tile_a: Color = palette.get("tile_a", Color("#3d3440"))
	var tile_b: Color = palette.get("tile_b", Color("#342d37"))
	for row in 11:
		for col in 20:
			var rect := Rect2(40 + col * 60, 140 + row * 40, 60, 40)
			var tile_color := tile_a if (row + col) % 2 == 0 else tile_b
			stage_tile_cache.append({"polygon": Stage.polygon(rect.grow(-1)), "color": tile_color})
	for i in 18:
		var world := Vector2(88 + (i * 173) % 1080, 174 + (i * 97) % 338)
		var point := world_to_screen(world)
		var turn := Vector2(12 + (i % 3) * 3, -4 + (i % 4) * 2)
		stage_decal_cache.append(PackedVector2Array([point, point + turn, point + turn + Vector2(10 + (i % 2) * 5, 6), point + turn + Vector2(25, 3)]))

func _draw_stage() -> void:
	debug_stage_layer_order.clear()
	if sim.endless_mode:
		_draw_endless_stage()
		# Endless uses its own wide arena renderer, then reuses the data-driven
		# terrain pass so walls, junctions and destructible doors stay editable in
		# stages.json and participate in the same visual layer contract.
		debug_stage_layer_order.assign(surface_renderer.STAGE_LAYER_ORDER.slice(0, 4))
		_draw_stage_terrain({}, {})
		_stage_layer("architecture")
		return
	if stage_tile_cache_id != sim.current_stage_id:
		_build_stage_tile_cache(sim.current_stage_id)
	var theme: Dictionary = surface_renderer.stage_theme(sim.current_stage_id)
	var palette: Dictionary = STAGE_VISUAL.palette(sim.current_stage_id)
	_draw_stage_backdrop(theme, palette)
	_draw_stage_atmosphere(theme, palette)
	_draw_stage_ground(theme, palette)
	_draw_stage_routes(theme, palette)
	_draw_stage_terrain(theme, palette)
	_draw_stage_architecture(theme, palette)

func _stage_background(stage_id: String) -> Texture2D:
	match int(surface_renderer.stage_theme(stage_id).get("background", 1)):
		2: return stage_background_2
		3: return stage_background_3
		4: return stage_background_4
		5: return stage_background_5
		6: return stage_background_6
		7: return stage_background_7
		8: return stage_background_8
	return stage_background_1

func _stage_layer(name: String) -> void:
	debug_stage_layer_order.append(name)

func _draw_stage_backdrop(theme: Dictionary, palette: Dictionary) -> void:
	_stage_layer("backdrop")
	if _is_chapter_one_stage():
		# Keep the non-playable canvas quiet. Grass is reserved for the exact
		# battle rectangle in the ground pass instead of being composited over a
		# second scenic image.
		draw_rect(Rect2(0, 0, 1280, 720), Color("#11161a"))
		draw_rect(Rect2(0, 0, 1280, 84), Color("#090b0e"))
		draw_rect(Rect2(0, 580, 1280, 140), Color("#080a0d"))
		return
	var background := _stage_background(sim.current_stage_id)
	var accent: Color = palette.get("accent", Color("#c45a68"))
	draw_texture_rect(background, Rect2(0, 0, 1280, 720), false, STAGE_VISUAL.backdrop_tint.lerp(accent.lightened(0.46), 0.09))
	draw_rect(Rect2(0, 0, 1280, 720), STAGE_VISUAL.stage_veil)
	draw_rect(Rect2(0, 82, 1032, 622), STAGE_VISUAL.arena_overlay)
func _draw_stage_atmosphere(theme: Dictionary, palette: Dictionary) -> void:
	_stage_layer("atmosphere")
	var accent: Color = palette.get("accent", Color("#c45a68"))
	if _is_chapter_one_stage():
		for band in 3:
			var drift := fmod(clock * (3.0 + band) + band * 360.0, 1620.0)
			var y := 275.0 + band * 34.0
			draw_colored_polygon(PackedVector2Array([Vector2(-360 + drift, y), Vector2(90 + drift, y - 18), Vector2(510 + drift, y + 18), Vector2(30 + drift, y + 38)]), Color(0.84, 0.94, 0.82, 0.035 + band * 0.01))
		return
	var fog := float(theme.get("fog", 0.45))
	for band in 4:
		var drift := fmod(clock * (5.0 + band * 2.2) + band * 250.0, 1510.0)
		var y := 146.0 + band * 35.0
		draw_colored_polygon(PackedVector2Array([Vector2(-310 + drift, y), Vector2(140 + drift, y - 23), Vector2(520 + drift, y + 30), Vector2(30 + drift, y + 55)]), Color(accent, (0.025 + band * 0.008) * fog))
	for i in 14:
		var x: float = i * 100 - 40
		var top: float = 105 + (i % 3) * 12
		var silhouette := Color("#302532").lerp(accent.darkened(0.68), 0.20)
		draw_rect(Rect2(x, top, 66, 100), silhouette)
		draw_colored_polygon(PackedVector2Array([Vector2(x - 7, top), Vector2(x + 33, top - 26), Vector2(x + 73, top)]), silhouette)

func _draw_stage_ground(theme: Dictionary, palette: Dictionary) -> void:
	_stage_layer("ground")
	var floor_color: Color = palette.get("floor", Color("#302832"))
	var accent: Color = palette.get("accent", Color("#c45a68"))
	if _is_chapter_one_stage():
		var playfield: Rect2 = UI_LAYOUT.battle_playfield_rect
		var ground_rect := playfield
		var ground_size := STAGE_VISUAL.chapter1_ground.get_size()
		var crop_height := ground_size.x * ground_rect.size.y / ground_rect.size.x
		var crop_y := clampf((ground_size.y - crop_height) * 0.50, 0.0, maxf(0.0, ground_size.y - crop_height))
		var source := Rect2(0.0, crop_y, ground_size.x, minf(crop_height, ground_size.y))
		draw_texture_rect_region(STAGE_VISUAL.chapter1_ground, ground_rect, source, Color(0.88, 0.94, 0.84, 1.0), false, true)
		draw_rect(ground_rect, Color(0.018, 0.045, 0.018, 0.10))
		_draw_chapter_one_grid()
		draw_colored_polygon(Stage.polygon(Sim.MOVE_AREA), Color(accent, 0.012))
		var chapter_border := Stage.polygon(Sim.MOVE_AREA)
		chapter_border.append(chapter_border[0])
		draw_polyline(chapter_border, Color("#e6efd1", 0.36), 1.5, true)
		draw_rect(ground_rect, Color("#d43b50", 0.72), false, 2.0)
		return
	var floor := Stage.polygon(WORLD)
	floor_color.a = 0.94
	draw_colored_polygon(floor, floor_color)
	for tile: Dictionary in stage_tile_cache:
		draw_colored_polygon(tile.polygon, tile.color)
	_draw_ground_motif(str(theme.get("tile_style", "brick")), accent)
	_draw_floor_decals(accent)
	draw_colored_polygon(Stage.polygon(Sim.MOVE_AREA), Color(accent, 0.045))
	var border := Stage.polygon(Sim.MOVE_AREA)
	border.append(border[0])
	draw_polyline(border, Color(accent, 0.38), 1.3, true)
	draw_rect(ENDLESS_PLAYFIELD_SCREEN, Color(0.02, 0.01, 0.025, 0.24), false, 7.0)

func _draw_chapter_one_grid() -> void:
	for world_y in range(140, 581, 40):
		for world_x in range(40, 1240, 60):
			var cell := Rect2(world_x, world_y, 60, 40)
			var checker := int(world_x / 60 + world_y / 40)
			draw_colored_polygon(Stage.polygon(cell), Color(0.12, 0.22, 0.08, 0.10 if checker % 2 == 0 else 0.045))
	var major := Color(0.10, 0.19, 0.07, 0.46)
	var minor := Color(0.13, 0.25, 0.09, 0.29)
	for world_y in range(140, 581, 40):
		var a := world_to_screen(Vector2(40, world_y))
		var b := world_to_screen(Vector2(1240, world_y))
		draw_line(a, b, major if (world_y - 140) % 80 == 0 else minor, 1.15, true)
	for world_x in range(40, 1241, 60):
		var points := PackedVector2Array()
		for world_y in range(140, 581, 30):
			points.append(world_to_screen(Vector2(world_x, world_y)))
		if points.size() > 1:
			draw_polyline(points, major if (world_x - 40) % 120 == 0 else minor, 1.15, true)
func _draw_ground_motif(style: String, accent: Color) -> void:
	match style:
		"corridor":
			for lane_y in [220.0, 360.0, 500.0]:
				draw_line(world_to_screen(Vector2(120, lane_y)), world_to_screen(Vector2(1160, lane_y)), Color(accent, 0.12), 3.0, true)
				for seal in 6:
					var point := world_to_screen(Vector2(210 + seal * 170, lane_y))
					draw_arc(point, 9.0, 0, TAU, 6, Color(accent, 0.13), 1.5, true)
		"shard":
			for i in 16:
				var center := world_to_screen(Vector2(120 + (i * 193) % 1040, 185 + (i * 83) % 335))
				draw_polyline(PackedVector2Array([center + Vector2(-7, 8), center + Vector2(0, -12 - i % 3 * 3), center + Vector2(8, 8)]), Color(accent, 0.14), 1.6, true)
		"bridge":
			for x in [230.0, 510.0, 790.0, 1070.0]:
				var top := world_to_screen(Vector2(x, 160))
				var bottom := world_to_screen(Vector2(x, 555))
				draw_line(top, bottom, Color(accent, 0.10), 4.0, true)
				draw_line(top + Vector2(-18, 0), bottom + Vector2(18, 0), Color(accent, 0.06), 1.5, true)
		"furnace":
			for i in 12:
				var center := world_to_screen(Vector2(135 + (i % 6) * 190, 220 + (i / 6) * 210))
				draw_rect(Rect2(center - Vector2(35, 15), Vector2(70, 30)), Color(accent, 0.045), false, 2.0)
				for rivet in [-1.0, 1.0]:
					draw_circle(center + Vector2(rivet * 27, -9), 2.0, Color(accent, 0.18))
		"gear":
			for i in 7:
				var center := world_to_screen(Vector2(150 + i * 165, 225 + (i % 3) * 115))
				draw_arc(center, 18.0 + i % 2 * 8.0, i * 0.4, i * 0.4 + PI * 1.62, 12, Color(accent, 0.14), 2.0, true)
				for tooth in 6:
					var direction := Vector2.from_angle(tooth * TAU / 6.0 + i * 0.2)
					draw_line(center + direction * 15.0, center + direction * 25.0, Color(accent, 0.10), 2.0, true)
		"ice":
			for i in 13:
				var root := world_to_screen(Vector2(105 + (i * 211) % 1080, 185 + (i * 97) % 345))
				var branch := Vector2(24 + i % 3 * 8, -9 + i % 4 * 6)
				draw_polyline(PackedVector2Array([root, root + branch, root + branch + Vector2(13, -11), root + branch + Vector2(27, 5)]), Color(accent, 0.17), 1.8, true)
		"siege":
			for y in [205.0, 345.0, 485.0]:
				var a := world_to_screen(Vector2(120, y))
				var b := world_to_screen(Vector2(1160, y))
				draw_dashed_line(a, b, Color(accent, 0.10), 2.0, 18.0, true)
			for x in [350.0, 690.0, 1030.0]:
				var center := world_to_screen(Vector2(x, 365))
				draw_arc(center, 25.0, 0, TAU, 4, Color(accent, 0.14), 2.2, true)
		_:
			for world in [Vector2(220, 240), Vector2(610, 410), Vector2(1010, 250)]:
				var center := world_to_screen(world)
				draw_arc(center, 16.0, PI * 0.25, PI * 1.75, 6, Color(accent, 0.12), 1.7, true)

func _draw_stage_routes(_theme: Dictionary, _palette: Dictionary) -> void:
	_stage_layer("routes")
	var routes: Dictionary = sim.stage_routes()
	for route_id: String in routes:
		var route: Array = routes[route_id]
		if route.size() < 2:
			continue
		_draw_route_bed(route, route_id)
		if route_previews.has(route_id):
			_draw_route_preview(route, route_previews[route_id], route_id)

func _draw_stage_terrain(_theme: Dictionary, _palette: Dictionary) -> void:
	_stage_layer("terrain")
	_draw_terrain_features()

func _draw_stage_architecture(theme: Dictionary, palette: Dictionary) -> void:
	_stage_layer("architecture")
	var accent: Color = palette.get("accent", Color("#c45a68"))
	if _is_chapter_one_stage():
		caption(Vector2(34, 82), "M O N D S T A D T   /   蒙 德 城 郊", Color(accent.lightened(0.20), 0.82), 11)
		return
	var motif := str(theme.get("motif", "rampart"))
	for i in 12:
		var ground := world_to_screen(Vector2(45 + i * 105, 140))
		var wall := Color("#3e303c").lerp(accent.darkened(0.62), 0.24)
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 48)), wall)
		draw_rect(Rect2(ground - Vector2(17, 48), Vector2(62, 5)), Color(accent, 0.32))
	_draw_stage_motif(motif, accent)
	caption(Vector2(43, 122), "%s  /  %s" % [str(theme.get("title", "裂隙战场")), motif.to_upper()], Color(accent.lightened(0.32), 0.88), 13)

func _draw_stage_motif(motif: String, accent: Color) -> void:
	match motif:
		"gallery":
			pass
		"nest":
			for i in 9:
				var root := Vector2(90 + i * 118, 248 + (i % 2) * 42)
				draw_colored_polygon(PackedVector2Array([root + Vector2(-14, 20), root + Vector2(0, -48 - i % 3 * 12), root + Vector2(16, 20)]), Color(accent, 0.19))
		"skybridge":
			for x in [170.0, 470.0, 770.0]:
				draw_line(Vector2(x, 174), Vector2(x + 150, 174), Color(accent, 0.28), 8.0, true)
				for cable in 4:
					draw_line(Vector2(x + cable * 46, 174), Vector2(x + cable * 46 + 20, 221), Color(accent, 0.13), 2.0, true)
		"forge":
			for i in 6:
				var furnace := Vector2(120 + i * 175, 220 + (i % 2) * 25)
				draw_rect(Rect2(furnace - Vector2(28, 42), Vector2(56, 74)), Color("#21171a"))
				draw_arc(furnace + Vector2(0, 10), 18.0, PI, TAU, 20, Color(accent, 0.85), 5.0, true)
				draw_circle(furnace + Vector2(0, 10), 10.0 + sin(clock * 5.0 + i) * 2.0, Color(accent, 0.22))
		"clock":
			for i in 4:
				var gear := Vector2(180 + i * 250, 230 + (i % 2) * 55)
				draw_arc(gear, 34.0 + i % 2 * 10.0, clock * (0.10 + i * 0.02), TAU + clock * (0.10 + i * 0.02), 12, Color(accent, 0.34), 5.0, true)
				for tooth in 8:
					var direction := Vector2.from_angle(tooth * TAU / 8.0 + clock * 0.10)
					draw_line(gear + direction * 29.0, gear + direction * 43.0, Color(accent, 0.28), 4.0, true)
		"frost":
			for i in 10:
				var base := Vector2(70 + i * 112, 298 + (i % 3) * 37)
				draw_colored_polygon(PackedVector2Array([base + Vector2(-13, 20), base + Vector2(0, -34 - i % 4 * 9), base + Vector2(13, 20)]), Color(accent, 0.25))
				draw_line(base + Vector2(0, -26), base + Vector2(0, 12), Color(accent.lightened(0.42), 0.50), 2.0, true)
		"eclipse":
			var eclipse := Vector2(760, 176)
			draw_circle(eclipse, 82.0, Color("#09070b"))
			draw_arc(eclipse, 88.0 + sin(clock * 0.7) * 3.0, 0, TAU, 72, Color(accent, 0.36), 8.0, true)
			for ray in 12:
				var direction := Vector2.from_angle(ray * TAU / 12.0)
				draw_line(eclipse + direction * 96.0, eclipse + direction * 122.0, Color(accent, 0.13), 3.0, true)
		_:
			for x in [180.0, 470.0, 760.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(x, 255), Vector2(x + 18, 178), Vector2(x + 36, 255)]), Color(accent, 0.17))

func _draw_stage_foreground() -> void:
	if debug_stage_layer_order.is_empty() or debug_stage_layer_order[-1] != "foreground":
		_stage_layer("foreground")
	if sim.endless_mode:
		for edge in 4:
			draw_rect(Rect2(edge * 4, edge * 4, 1280 - edge * 8, 720 - edge * 8), Color(0.03, 0.008, 0.025, 0.08), false, 4.0)
		return
	if _is_chapter_one_stage():
		var chapter_accent: Color = STAGE_VISUAL.palette(sim.current_stage_id).get("accent", Color("#72d8b7"))
		draw_line(Vector2(16, 578), Vector2(1264, 578), Color(chapter_accent, 0.42), 2.0, true)
		caption(Vector2(42, 571), "CHAPTER I  ·  蒙德城郊", Color(chapter_accent.lightened(0.18), 0.72), 9)
		return
	var palette := STAGE_VISUAL.palette(sim.current_stage_id)
	var floor_color: Color = palette.get("floor", Color("#302832"))
	var accent: Color = palette.get("accent", Color("#c45a68"))
	var front := PackedVector2Array([world_to_screen(Vector2(40, 580)), world_to_screen(Vector2(1240, 580)), Vector2(1240, 718), Vector2(40, 718)])
	draw_colored_polygon(front, STAGE_VISUAL.foreground_color.lerp(floor_color, 0.24))
	draw_line(front[0], front[1], Color(accent, 0.58), 2.4, true)
	for i in 15:
		var rubble_x := 45.0 + i * 76.0
		var rubble_h := 7.0 + float((i * 17) % 15)
		draw_colored_polygon(PackedVector2Array([Vector2(rubble_x, 704), Vector2(rubble_x + 18, 704 - rubble_h), Vector2(rubble_x + 42, 704), Vector2(rubble_x + 25, 718)]), floor_color.darkened(0.28))
		draw_line(Vector2(rubble_x + 3, 704), Vector2(rubble_x + 18, 704 - rubble_h), Color(accent, 0.28), 1.0, true)
	_draw_foreground_embers(accent)
	caption(Vector2(47, 702), "C I T A D E L   /   %s" % sim.current_stage_id.trim_prefix("stage_"), Color(accent.lightened(0.28), 0.72), 10)
	caption(Vector2(840, 702), "敌军推进方向   ←", Color(accent.lightened(0.25), 0.78), 11)

func _draw_floor_decals(accent: Color) -> void:
	for crack: PackedVector2Array in stage_decal_cache:
		draw_polyline(crack, Color(accent, 0.10), 1.1, true)
	for world in [Vector2(175, 245), Vector2(585, 445), Vector2(1005, 265)]:
		var center := world_to_screen(world)
		draw_arc(center, 22.0, 0.18, PI * 1.45, 14, Color(accent, 0.09), 1.2, true)
		draw_line(center + Vector2(-13, 8), center + Vector2(18, -5), Color(accent, 0.07), 1.0, true)

func _draw_foreground_embers(accent: Color) -> void:
	if reduced_effects:
		return
	for i in 9:
		var travel := fmod(clock * (18.0 + i * 1.7) + i * 53.0, 118.0)
		var x := 58.0 + float((i * 137) % 930)
		var point := Vector2(x + sin(clock * 1.7 + i) * 7.0, 708.0 - travel)
		var ember := STAGE_VISUAL.ember_color.lerp(accent, 0.35)
		draw_circle(point, 1.4 + float(i % 3) * 0.45, Color(ember, 0.12 * (1.0 - travel / 118.0)))

func _terrain_screen_rect(area: Rect2) -> Rect2:
	if sim.endless_mode:
		return Rect2(world_to_screen(area.position), area.size)
	var polygon := Stage.polygon(area)
	var left := minf(polygon[0].x, polygon[3].x)
	var top := minf(polygon[0].y, polygon[1].y)
	var right := maxf(polygon[1].x, polygon[2].x)
	var bottom := maxf(polygon[2].y, polygon[3].y)
	return Rect2(left, top, right - left, bottom - top)

func _terrain_polygon(area: Rect2) -> PackedVector2Array:
	if not sim.endless_mode:
		return Stage.polygon(area)
	var screen := _terrain_screen_rect(area)
	return PackedVector2Array([screen.position, Vector2(screen.end.x, screen.position.y), screen.end, Vector2(screen.position.x, screen.end.y)])

## 用整数网格把一块贴图拼满目标矩形，自动挑最不变形的 cols x rows 组合。
func _stitch_cells(source: Rect2, target: Rect2, max_cells: int = 64) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	if target.size.x <= 0.0 or target.size.y <= 0.0 or source.size.x <= 0.0 or source.size.y <= 0.0:
		return cells
	var aspect := source.size.x / source.size.y
	var best_cols := 1
	var best_rows := 1
	var best_error := INF
	for cols in range(1, 13):
		for rows in range(1, 13):
			if cols * rows > max_cells:
				continue
			var cell := Vector2(target.size.x / float(cols), target.size.y / float(rows))
			var error := absf(log((cell.x / cell.y) / aspect)) + 0.05 * float(cols * rows)
			if error < best_error:
				best_error = error
				best_cols = cols
				best_rows = rows
	var cell_size := Vector2(target.size.x / float(best_cols), target.size.y / float(best_rows))
	for row in best_rows:
		for column in best_cols:
			cells.append(Rect2(target.position + Vector2(column * cell_size.x, row * cell_size.y), cell_size))
	return cells

## 无尽模式墙体：横墙铺整块石块，竖墙只露顶面、靠下的压在上面、块距收紧。
func _draw_endless_wall(target: Rect2) -> void:
	if target.size.y > target.size.x:
		_draw_endless_wall_column(target)
		return
	var cells := _stitch_cells(WALL_STONE_FULL, target)
	for index in cells.size():
		draw_texture_rect_region(WALL_STONES[index % WALL_STONES.size()], cells[index], WALL_STONE_FULL)

## 纵墙格位：只露顶面、块距收紧、底边贴齐地块，靠下的块后画因此压住上一块的底缘。
func _wall_column_cells(target: Rect2) -> Array[Rect2]:
	var band := WALL_STONE_TOP
	var block_height := target.size.x * band.size.y / band.size.x
	var rows := maxi(1, int(round(target.size.y / maxf(8.0, block_height * WALL_STACK_TIGHTNESS))))
	var pitch := target.size.y / float(rows)
	var top := target.end.y - block_height - float(rows - 1) * pitch
	var cells: Array[Rect2] = []
	for index in rows:
		cells.append(Rect2(target.position.x, top + float(index) * pitch, target.size.x, block_height))
	return cells

func _draw_endless_wall_column(target: Rect2) -> void:
	var band := WALL_STONE_TOP
	var cells := _wall_column_cells(target)
	for index in cells.size():
		draw_texture_rect_region(WALL_STONES[index % WALL_STONES.size()], cells[index], band)

## 无尽模式可破坏大门：横墙上的门用锁箱，竖墙上的门用铁箱。
func _gate_asset(target: Rect2) -> Array:
	if target.size.y > target.size.x:
		return [GATE_CRATE_TEXTURE, GATE_CRATE_FULL]
	return [GATE_CHEST_TEXTURE, GATE_CHEST_FULL]

func _draw_endless_gate(target: Rect2) -> void:
	var asset := _gate_asset(target)
	for cell: Rect2 in _stitch_cells(asset[1], target):
		draw_texture_rect_region(asset[0], cell, asset[1])

func _grounded_feature_rect(screen_area: Rect2, scale: Vector2, ground_offset: float = 0.0) -> Rect2:
	var size := screen_area.size * scale
	var ground_y := screen_area.end.y + ground_offset
	return Rect2(Vector2(screen_area.get_center().x - size.x * 0.5, ground_y - size.y), size)

func _draw_chapter_one_terrain_feature(kind: String, area: Rect2, center: Vector2, feature: Dictionary) -> bool:
	var screen_area := _terrain_screen_rect(area)
	if kind == "high_ground":
		var high_rect := _grounded_feature_rect(screen_area, Vector2(0.90, 1.0), 4.0)
		draw_texture_rect(STAGE_VISUAL.chapter1_high_platform, high_rect, false, Color("#eef7d7"))
		caption(Vector2(high_rect.position.x + 10, high_rect.end.y + 12), "高台 · 伤害+22% · 射程+38%", Color("#f3f1c8"), 8)
		return true
	if kind == "moving_platform":
		var moving_rect := Rect2(Vector2.ZERO, screen_area.size * Vector2(0.92, 1.15))
		moving_rect.position = Vector2(screen_area.get_center().x - moving_rect.size.x * 0.5, screen_area.end.y - moving_rect.size.y)
		draw_ellipse_shadow(Vector2(moving_rect.get_center().x, moving_rect.end.y - 9.0), moving_rect.size.x * 0.42, Color(0, 0, 0, 0.34))
		draw_texture_rect(STAGE_VISUAL.chapter1_moving_platform, moving_rect, false, Color.WHITE)
		caption(Vector2(moving_rect.position.x + 8, moving_rect.end.y + 13), "载人移动 · 射程强化", Color("#a9f2d4"), 8)
		return true
	if kind == "low_ground":
		var low_rect := screen_area.grow(5.0)
		draw_texture_rect(STAGE_VISUAL.chapter1_lowland, low_rect, false, Color.WHITE)
		caption(Vector2(low_rect.position.x + 12, low_rect.get_center().y), "沼泽减速 28%", Color("#e4dfae"), 9)
		return true
	if kind == "conveyor":
		draw_colored_polygon(_terrain_polygon(area), Color(0.28, 0.62, 0.42, 0.11))
		for arrow in 4:
			var arrow_center := screen_area.position + Vector2(28.0 + arrow * screen_area.size.x / 4.3, screen_area.size.y * 0.52)
			draw_polyline(PackedVector2Array([arrow_center + Vector2(10, -6), arrow_center, arrow_center + Vector2(10, 6)]), Color("#d4f4b8", 0.38), 2.0, true)
		return true
	if kind == "trap":
		var pulse := 0.72 + sin(clock * 3.2) * 0.16
		draw_circle(center, minf(screen_area.size.x, screen_area.size.y) * 0.34, Color(0.58, 0.40, 0.90, 0.08 * pulse))
		draw_arc(center, minf(screen_area.size.x, screen_area.size.y) * 0.30, 0, TAU, 24, Color(0.72, 0.56, 1.0, 0.34 * pulse), 2.0, true)
		return true
	if kind == "blocked":
		var bush_rect := _grounded_feature_rect(screen_area, Vector2(1.06, 1.08), 3.0)
		var bush_ground := Vector2(bush_rect.get_center().x, bush_rect.end.y - 5.0)
		draw_ellipse_shadow(bush_ground - Vector2(0, 9), bush_rect.size.x * 0.31, Color(0, 0, 0, 0.31))
		draw_texture_rect(STAGE_VISUAL.chapter1_bush, bush_rect, false, Color.WHITE)
		return true
	if kind == "mechanism":
		var active: bool = sim.heroes.any(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false)) and hero.hp > 0.0 and area.grow(95.0).has_point(hero.pos))
		var glow := Color("#8ff0cb") if active else Color("#719b89")
		var mechanism_rect := Rect2(center + Vector2(-28, -76), Vector2(56, 100))
		draw_circle(center + Vector2(0, -28), 28.0 + sin(clock * 4.0) * 3.0, Color(glow, 0.10 if active else 0.04))
		draw_texture_rect(STAGE_VISUAL.chapter1_mechanism, mechanism_rect, false, Color.WHITE if active else Color(0.72, 0.76, 0.72, 1.0))
		caption(center + Vector2(-47, 34), "超远程支援 · 5.5秒" if active else "角色靠近后启动", glow, 8)
		return true
	if kind in ["shortcut", "door", "one_way"]:
		var broken := kind != "one_way" and float(feature.get("hp", 0.0)) <= 0.0
		if broken:
			draw_dashed_line(Vector2(screen_area.position.x, screen_area.end.y), screen_area.end, Color("#8ee6a6"), 2.0, 7.0, true)
			caption(center + Vector2(-34, 4), "通道已开启", Color("#9af0b8"), 9)
			return true
		var barricade_rect := _grounded_feature_rect(screen_area, Vector2(1.12, 1.10), 4.0)
		draw_texture_rect(STAGE_VISUAL.chapter1_barricade, barricade_rect, false, Color.WHITE)
		if kind != "one_way":
			var hp_ratio := clampf(float(feature.get("hp", 0.0)) / maxf(1.0, float(feature.get("max_hp", 1.0))), 0.0, 1.0)
			draw_rect(Rect2(center + Vector2(-30, -38), Vector2(60, 4)), Color("#293020"))
			draw_rect(Rect2(center + Vector2(-30, -38), Vector2(60 * hp_ratio, 4)), Color("#f0c46a"))
			caption(center + Vector2(-35, 34), "战技可破坏", Color("#ffe59a"), 8)
		return true
	return false
func _terrain_cells(feature: Dictionary) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	for value: Variant in feature.get("grid_cells", []):
		if value is Rect2:
			cells.append(value)
	if cells.is_empty():
		var area: Rect2 = feature.get("area", Rect2())
		if area.size != Vector2.ZERO:
			cells.append(area)
	return cells

func _terrain_tile_active(area: Rect2) -> bool:
	return sim.heroes.any(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false)) and hero.hp > 0.0 and area.has_point(hero.pos))

func _draw_effect_tiles(texture: Texture2D, feature: Dictionary, tint: Color = Color.WHITE) -> void:
	var source_size := Vector2(texture.get_size())
	for cell: Rect2 in _terrain_cells(feature):
		var screen_cell := _terrain_screen_rect(cell)
		var active := _terrain_tile_active(cell)
		var fit_scale := minf(screen_cell.size.x * 0.84 / maxf(1.0, source_size.x), screen_cell.size.y * 0.86 / maxf(1.0, source_size.y))
		var draw_size := source_size * fit_scale * (1.10 if active else 1.0)
		var draw_rect := Rect2(screen_cell.get_center() - draw_size * 0.5, draw_size)
		if active:
			draw_circle(screen_cell.get_center(), minf(draw_size.x, draw_size.y) * 0.52, Color(0.48, 0.03, 0.06, 0.20))
		draw_texture_rect(texture, draw_rect, false, Color("#7e202b") if active else tint)

func _draw_terrain_features() -> void:	for feature: Dictionary in sim.terrain_features:
		var area: Rect2 = feature.get("area", Rect2())
		if area.size == Vector2.ZERO:
			continue
		var kind := str(feature.get("type", ""))
		var polygon := _terrain_polygon(area)
		var center := world_to_screen(area.get_center())
		if _is_chapter_one_stage() and _draw_chapter_one_terrain_feature(kind, area, center, feature):
			continue
		if kind == "junction":
			var screen_area := _terrain_screen_rect(area)
			var layout := str(feature.get("layout", "cross"))
			draw_rect(screen_area, Color(0.18, 0.08, 0.12, 0.18), true)
			draw_rect(screen_area, Color(0.88, 0.30, 0.40, 0.22), false, 2.0)
			var arm := minf(screen_area.size.x, screen_area.size.y) * 0.28
			draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), Color(0.94, 0.38, 0.46, 0.24), 12.0, true)
			if layout in ["t", "cross"]:
				draw_line(center, center + Vector2(0, arm if layout == "t" else arm), Color(0.94, 0.38, 0.46, 0.24), 12.0, true)
			if layout == "cross":
				draw_line(center, center - Vector2(0, arm), Color(0.94, 0.38, 0.46, 0.24), 12.0, true)
			elif layout == "dual":
				draw_line(center - Vector2(arm, 18), center + Vector2(arm, 18), Color(0.94, 0.38, 0.46, 0.20), 7.0, true)
			caption(center + Vector2(-38, -16), str(feature.get("label", "路口")), Color("#d98291"), 9)
		elif kind == "high_ground":
			_draw_effect_tiles(TILE_HIGH_GROUND, feature)
		elif kind == "low_ground":
			_draw_effect_tiles(TILE_LOW_GROUND, feature)
		elif kind == "trap":
			_draw_effect_tiles(TILE_HAZARD, feature)
		elif kind == "attack_ground":
			_draw_effect_tiles(TILE_ATTACK_GROUND, feature)
		elif kind == "blocked":
			if sim.endless_mode: _draw_endless_wall(_terrain_screen_rect(area))
			else: _draw_effect_tiles(TILE_BLOCKED, feature)
		elif kind in ["shortcut", "door"] and sim.endless_mode:
			if float(feature.get("hp", 0.0)) > 0.0: _draw_endless_gate(_terrain_screen_rect(area))

func _draw_endless_stage() -> void:
	draw_texture_rect(stage_background_8, Rect2(0, 0, 1280, 720), false, Color(0.34, 0.24, 0.30, 1.0))
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.035, 0.018, 0.045, 0.69))
	# 100×100 Helltaker floor modules are placed as squares, preserving their original ratio.
	var top_left := screen_to_world(ENDLESS_PLAYFIELD_SCREEN.position)
	var bottom_right := screen_to_world(ENDLESS_PLAYFIELD_SCREEN.end)
	var cell := 100.0
	var first_x := floorf(top_left.x / cell) * cell
	var first_y := floorf(top_left.y / cell) * cell
	for x in range(int(first_x), int(bottom_right.x + cell), int(cell)):
		for y in range(int(first_y), int(bottom_right.y + cell), int(cell)):
			var tile_index := posmod(floori(x / cell) * 3 + floori(y / cell) * 5, ENDLESS_FLOOR_TILES.size())
			var tile_rect := Rect2(world_to_screen(Vector2(x, y)), Vector2(cell, cell))
			draw_texture_rect(ENDLESS_FLOOR_TILES[tile_index], tile_rect, false, Color(0.63, 0.48, 0.55, 0.92))
			draw_rect(tile_rect, Color(0.16, 0.025, 0.06, 0.13))
	# The central contract dais uses the matching square boss-floor module.
	var dais_center := world_to_screen(Sim.ENDLESS_ARENA.get_center())
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var dais_rect := Rect2(dais_center + Vector2(dx * cell, dy * cell) - Vector2(cell * 0.5, cell * 0.5), Vector2(cell, cell))
			draw_texture_rect(ENDLESS_BOSS_FLOOR, dais_rect, false, Color(0.72, 0.52, 0.58, 0.88))
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
	var chapter_ground := point + Vector2(0, 44)
	if not _is_chapter_one_stage():
		draw_ellipse_shadow(point + Vector2(0, 15), 52.0, Color(0, 0, 0, 0.40))
	var tint: Color = RED if base_flash > 0.0 and not reduced_effects else Color("#b9f3d6")
	var glow := 0.75 + sin(clock * 3.4) * 0.18
	draw_circle(point + Vector2(0, -38), 44.0 + glow * 7.0, Color(tint, 0.055))
	draw_circle(point + Vector2(0, -38), 30.0 + glow * 5.0, Color(tint, 0.10))
	draw_arc(point + Vector2(0, -38), 38.0, -clock * 0.7, TAU - clock * 0.7, 40, Color(tint, 0.42), 2.0, true)
	if _is_chapter_one_stage():
		var crystal_modulate := Color("#ff8f94") if base_flash > 0.0 and not reduced_effects else Color.WHITE
		draw_texture_rect(STAGE_VISUAL.chapter1_crystal, Rect2(Vector2(point.x - 88.0, chapter_ground.y - 307.0), Vector2(176, 307)), false, crystal_modulate)
	else:
		draw_texture_rect(crystal_texture, Rect2(point + Vector2(-38, -105), Vector2(76, 120)), false, tint)
		draw_colored_polygon(PackedVector2Array([point + Vector2(-43, 17), point + Vector2(-29, 5), point + Vector2(29, 5), point + Vector2(43, 17), point + Vector2(31, 31), point + Vector2(-31, 31)]), Color("#382934"))
		draw_polyline(PackedVector2Array([point + Vector2(-43, 17), point + Vector2(-29, 5), point + Vector2(29, 5), point + Vector2(43, 17)]), Color("#a06d7b"), 2.0, true)
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83, 6)), Color("#243026"))
	draw_rect(Rect2(point + Vector2(-40, 46), Vector2(83 * sim.base_hp / maxf(1.0, sim.base_max_hp), 6)), tint)
	caption(point + Vector2(-42, 72), "风神像核心" if _is_chapter_one_stage() else "基地核心", tint, 12)
func _draw_route_bed(route: Array, route_id: String = "main") -> void:
	var material: Dictionary = surface_renderer.route_material(route_id)
	var color: Color = material.color
	for i in range(route.size() - 1):
		var a := world_to_screen(route[i])
		var b := world_to_screen(route[i + 1])
		draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(color.darkened(0.62), 0.055), 9.0, true)
		draw_line(a, b, Color(color, 0.065), 2.4, true)
		draw_line(a, b, Color(color.lightened(0.26), 0.045), 1.0, true)
		var length := a.distance_to(b)
		var steps := maxi(1, floori(length / 82.0))
		for step in steps:
			var point := a.lerp(b, (float(step) + 0.5) / float(steps))
			var direction := (b - a).normalized()
			var side := direction.rotated(PI * 0.5)
			draw_line(point - side * 8.0, point + side * 8.0, Color(color, 0.050), 1.0, true)
			draw_circle(point, 1.8, Color(color, 0.085))

func _draw_route_preview(route: Array, preview: Dictionary, route_id: String = "main") -> void:
	var material: Dictionary = surface_renderer.route_material(route_id, bool(preview.get("flying", false)), bool(preview.get("boss", false)))
	var color: Color = material.color
	var pulse := 0.68 + sin(clock * 7.0) * 0.16
	var width := float(material.width)
	for i in range(route.size() - 1):
		var a := world_to_screen(route[i])
		var b := world_to_screen(route[i + 1])
		draw_line(a, b, Color(color, 0.035 + pulse * 0.045), width + 7.0, true)
		draw_dashed_line(a, b, Color(color, pulse * 0.76), width, 22.0, true)
	for sample: Dictionary in surface_renderer.route_samples(route, clock, 8 if bool(preview.get("boss", false)) else 6, 0.18):
		var point := world_to_screen(sample.point)
		var ahead := world_to_screen(sample.point + sample.tangent * 12.0)
		var direction := (ahead - point).normalized()
		var side := direction.rotated(PI * 0.5)
		var head := PackedVector2Array([point + direction * 11.0, point - direction * 8.0 + side * 6.0, point - direction * 3.0, point - direction * 8.0 - side * 6.0])
		draw_colored_polygon(head, Color(color, 0.86 + pulse * 0.12))
		draw_circle(point - direction * 16.0, 3.0 + pulse, Color(color, 0.28))
	var first := world_to_screen(route[0])
	var enemy_name: String = str({"grunt": "裂隙兽", "runner": "疾行兽", "armored": "重甲兽", "flyer": "空袭兽", "ranged": "射手", "buffer": "增幅者", "shielded": "盾卫", "charger": "冲锋兽", "healer": "愈疗者", "splitter": "分裂体", "warder": "结界师", "boss_01": "裂隙统领", "boss_02": "深渊母巢"}.get(str(preview.get("enemy_id", "grunt")), "敌军"))
	var warning := "BOSS · %s" % enemy_name if bool(preview.get("boss", false)) else "%s ×%d" % [enemy_name, int(preview.get("count", 1))]
	caption(first + Vector2(-72, -58), warning, color, 13)

func _draw_spawn_portals() -> void:
	debug_portal_phases.clear()
	for route_id: String in spawn_portals:
		var portal: Dictionary = spawn_portals[route_id]
		var point := world_to_screen(portal.pos) + Vector2(0, -23)
		var visual: Dictionary = surface_renderer.portal_visual(float(portal.life), float(portal.total), clock, route_id.hash() % 17)
		debug_portal_phases.append(str(visual.phase))
		var alpha := float(visual.alpha)
		var color := Color("#ffd36e") if route_id == "stage_exit" else Color("#f24b6a")
		draw_set_transform(point, clock * (0.24 if visual.phase == "active" else 0.12), visual.scale)
		draw_circle(Vector2.ZERO, float(visual.ring), Color(0.22, 0.008, 0.055, 0.52 * alpha))
		draw_arc(Vector2.ZERO, float(visual.ring) + 5.0, float(visual.gap), TAU - float(visual.gap), 48, Color(color, 0.96 * alpha), 5.0, true)
		draw_arc(Vector2.ZERO, float(visual.ring) - 7.0, -clock * 1.8, TAU - clock * 1.8, 32, Color(1.0, 0.72, 0.77, 0.76 * alpha), 2.0, true)
		for spark in 8:
			var angle := clock * 2.4 + spark * TAU / 8.0
			draw_circle(Vector2.from_angle(angle) * (float(visual.ring) + spark % 2 * 8.0), 2.2, Color(color, alpha))
		draw_set_transform(Vector2.ZERO)

func _draw_arena_events() -> void:
	if sim == null or sim.stage_runtime == null:
		return
	for event: Dictionary in sim.stage_runtime.arena_events:
		var center := world_to_screen(Vector2(event.get("source", Vector2(640,360))))
		var ratio := clampf(float(event.get("life",0.0)) / maxf(0.01,float(event.get("total",1.0))),0.0,1.0)
		var radius := float(event.get("radius",160.0)) * (0.82 + sin(clock*3.0)*0.03)
		var color := Color(str(event.get("color","#ff776e")))
		var kind := str(event.get("type","hazard"))
		draw_circle(center,radius,Color(color,0.035+0.035*ratio))
		draw_arc(center,radius,clock*0.25,TAU+clock*0.25,64,Color(color,0.58*ratio),3.0,true)
		if kind in ["artillery_grid","carpet_grid","shield_wall","break_terrain"]:
			for offset in [-0.66,-0.22,0.22,0.66]:
				draw_line(center+Vector2(offset*radius,-radius*0.72),center+Vector2(offset*radius,radius*0.72),Color(color,0.18*ratio),2.0,true)
				draw_line(center+Vector2(-radius*0.72,offset*radius),center+Vector2(radius*0.72,offset*radius),Color(color,0.18*ratio),2.0,true)
		else:
			for ray in 8:
				var angle := clock*0.35+ray*TAU/8.0
				draw_line(center+Vector2.from_angle(angle)*radius*0.38,center+Vector2.from_angle(angle)*radius,Color(color,0.18*ratio),2.0,true)
		caption(center+Vector2(-72,-radius-12),kind.replace("_"," ").to_upper(),Color(color,0.82*ratio),11)

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
	var character_id := str(hero.get("character_id", ""))
	var is_traveler: bool = character_id == "traveler"
	var has_sequence := character_sequences.has_character(character_id)
	var bob: float = 0.0 if down or is_traveler or has_sequence else sin(clock * (14.0 if hero.moving else 3.0)) * (3.0 if hero.moving else 1.0)
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
	if has_sequence:
		_draw_sequence_hero(hero, tint, down)
	elif is_traveler:
		_draw_traveler(hero, tint, down)
	else:
		var facing := float(hero.get("facing", 1.0))
		var sample := visual_sample(hero)
		var motion_scale: Vector2 = sample.get("scale", Vector2.ONE)
		var motion_offset: Vector2 = sample.get("offset", Vector2.ZERO)
		_draw_anchored_texture_region(atlas, hero.pos + Vector2(0, HERO_FOOT_OFFSET + bob) + motion_offset, Vector2(58, 58) * motion_scale, Vector2(16, 16), Vector2(8, 16), facing, 1.0, Rect2(hero.tile, Vector2(16, 16)), tint)
	if not down:
		if hero.block > 0 and not is_traveler:
			draw_rect(Rect2(hero.pos + Vector2(17, -24), Vector2(16, 25)), Color("#a8a687"))
			draw_rect(Rect2(hero.pos + Vector2(21, -21), Vector2(8, 18)), Color("#445b5e"))
		elif not is_traveler:
			draw_circle(hero.pos + Vector2(29, -16 + bob), 5, color)
			if shot_flashes.get(hero.id, 0.0) > 0 and not reduced_effects:
				draw_circle(hero.pos + Vector2(37, -16), 8, color)
	var tall_visual := has_sequence or is_traveler
	var label_y: float = -146.0 if has_sequence else (-132.0 if is_traveler else -65.0)
	var health_y: float = -134.0 if has_sequence else (-120.0 if is_traveler else -53.0)
	caption(hero.pos + Vector2(-29, label_y), "%d %s" % [hero.id + 1, hero.name], color, 13)
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50, 4)), Color("#303942"))
	draw_rect(Rect2(hero.pos + Vector2(-25, health_y), Vector2(50 * hero.hp / hero.max_hp, 4)), color)
	if down:
		caption(hero.pos + Vector2(-24, 30), "已倒地", RED, 12)
	elif hero.moving:
		caption(hero.pos + Vector2(-24, 30), "移动中", Color("#91a4ad"), 12)
	elif hero.block > 0:
		caption(hero.pos + Vector2(-28, 30), "阻挡 %d/%d" % [hero.blocked, hero.block], color, 12)

func _draw_sequence_hero(hero: Dictionary, tint: Color, down: bool) -> void:
	var character_id := str(hero.get("character_id", ""))
	var runtime_state := "idle"
	var frame := 0
	var sample := visual_sample(hero)
	if down:
		runtime_state = "down"
		frame = character_sequences.frame_at_time(character_id, runtime_state, float(hero_down_visuals.get(hero.id, 0.0)))
	elif hero_attack_visuals.has(hero.id):
		runtime_state = "attack"
		var attack_visual: Dictionary = hero_attack_visuals[hero.id]
		var attack_phase := clampf(float(attack_visual.elapsed) / maxf(0.01, float(attack_visual.duration)), 0.0, 0.999999)
		frame = character_sequences.frame_at_phase(character_id, runtime_state, attack_phase)
	else:
		runtime_state = "run" if bool(hero.get("moving", false)) else str(sample.get("state", "idle"))
		if runtime_state not in ["idle", "run", "attack", "skill", "ultimate", "hurt"]:
			runtime_state = "idle"
		frame = character_sequences.frame_at_phase(character_id, runtime_state, float(sample.get("phase", 0.0)))
	var texture := character_sequences.texture(character_id, runtime_state)
	if texture == null:
		return
	var source := character_sequences.source_rect(character_id, runtime_state, frame)
	var cell := character_sequences.cell(character_id)
	var pivot := character_sequences.pivot(character_id)
	var base_size := character_sequences.display_size(character_id)
	var hit_strength := clampf(float(hero.get("flash", 0.0)) / 0.12, 0.0, 1.0) if not reduced_effects else 0.0
	var display_size := Vector2(base_size * (1.0 + hit_strength * 0.10), base_size * (1.0 - hit_strength * 0.08))
	var foot := Vector2(hero.pos) + Vector2(0.0, HERO_FOOT_OFFSET)
	_draw_anchored_texture_region(texture, foot, display_size, cell, pivot, float(hero.get("facing", 1.0)), 1.0, source, tint)

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

func _draw_enemy(enemy: Dictionary) -> void:
	var flying: bool = bool(enemy.get("flying", false))
	var bob: float = sin(clock * (8.0 if not flying else 5.0) + enemy.id) * (2.0 if not flying else 7.0) - (22.0 if flying else 0.0)
	var tint := Color("#fff5e5") if enemy.flash > 0 and not reduced_effects else Color(enemy.color)
	var side: float = maxf(float(enemy.size), enemy_sequences.display_size(str(enemy.kind)) * 0.72) if enemy_sequences.has_enemy(str(enemy.kind)) else float(enemy.size)
	var body: Vector2 = enemy.pos + Vector2(0, -18 + bob)
	# Only gameplay-critical support and shield states receive extra markers.
	# Movement class, flight and range are communicated by the animation itself.
	match str(enemy.kind):
		"buffer":
			for rune in 3:
				var angle := clock * 2.2 + rune * TAU / 3.0
				var rune_pos: Vector2 = body + Vector2.from_angle(angle) * 34.0
				draw_colored_polygon(PackedVector2Array([rune_pos + Vector2(0, -6), rune_pos + Vector2(5, 3), rune_pos + Vector2(-5, 3)]), Color("#e18df0"))
		"shielded":
			var shield := PackedVector2Array([body + Vector2(-38, -28), body + Vector2(-13, -35), body + Vector2(-9, 22), body + Vector2(-28, 36), body + Vector2(-43, 17)])
			draw_colored_polygon(shield, Color("#385b78"))
			draw_polyline(PackedVector2Array([shield[0], shield[1], shield[2], shield[3], shield[4], shield[0]]), Color("#91d1ef"), 3.0, true)
	var visual_id := str(enemy.kind)
	if enemy_sequences.has_enemy(visual_id):
		_draw_sequence_enemy(enemy, bob)
	elif enemy_visual_textures.has(visual_id):
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
	if enemy.kind == "buffer":
		draw_arc(enemy.pos + Vector2(0, -20), 30.0 + sin(clock * 2.0) * 3.0, 0, TAU, 32, Color(0.85, 0.42, 0.95, 0.5), 2.0, true)
		caption(enemy.pos + Vector2(-7, 27), "增", Color("#cf7fda"), 12)
	elif enemy.kind == "shielded":
		caption(enemy.pos + Vector2(-7, 27), "盾", Color("#76a6d8"), 12)
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
		while history.size() > (7 if reduced_effects else 11):
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
	var attack_style := str(projectile.get("style", "standard"))
	var color := element_color(element)
	for i in range(maxi(0, history.size() - 1)):
		var a := world_to_screen(Vector2(history[i])) + Vector2(0, -18)
		var b := world_to_screen(Vector2(history[i + 1])) + Vector2(0, -18)
		var age := float(i + 1) / maxf(1.0, float(history.size()))
		draw_line(a, b, Color(color, age * 0.11), 17.0 * age, true)
		draw_line(a, b, Color(color, age * 0.30), 7.0 * age, true)
		draw_line(a, b, Color(color.lightened(0.42), age * 0.86), 1.8 + age * 2.2, true)
	if not reduced_effects:
		var flare_size := 28.0 if not bool(projectile.get("critical", false)) else 40.0
		draw_texture_rect(VFX_FLARE, Rect2(point - Vector2.ONE * flare_size * 0.5, Vector2.ONE * flare_size), false, Color(color.lightened(0.35), 0.78))
	draw_set_transform(point, direction.angle(), Vector2.ONE)
	if not reduced_effects:
		draw_texture_rect(VFX_TRACE, Rect2(-38, -7, 46, 14), false, Color(color, 0.52))
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
	match attack_style:
		"music_note":
			draw_circle(Vector2(-2, 4), 5.0, Color(color.lightened(0.35), 0.95), false, 2.4, true)
			draw_line(Vector2(2, 3), Vector2(2, -13), Color.WHITE, 2.6, true)
			draw_line(Vector2(2, -13), Vector2(10, -10), Color(color.lightened(0.42), 0.95), 2.4, true)
		"arcane_lance":
			draw_colored_polygon(PackedVector2Array([Vector2(22, 0), Vector2(-9, -6), Vector2(-17, 0), Vector2(-9, 6)]), Color(color.lightened(0.32), 0.92))
			draw_line(Vector2(-20, 0), Vector2(22, 0), Color.WHITE, 2.2, true)
		"hydro_salon", "tidal_orb":
			for orbit in 3:
				var orbit_angle := clock * (2.4 + orbit * 0.35) + orbit * TAU / 3.0
				draw_circle(Vector2.from_angle(orbit_angle) * (10.0 + orbit * 2.0), 2.8, Color(color.lightened(0.38), 0.88))
		"wind_seed", "quantum_gate":
			for ring in 2:
				draw_arc(Vector2.ZERO, 10.0 + ring * 5.0, clock + ring * 1.4, clock + ring * 1.4 + PI * 1.35, 18, Color(color.lightened(0.25), 0.92 - ring * 0.22), 2.4, true)
		"frost_shard", "frost_bloom":
			for shard in 4:
				var shard_dir := Vector2.from_angle(shard * PI * 0.5)
				draw_line(shard_dir * 5.0, shard_dir * 15.0, Color("#f4ffff"), 2.0, true)
		"mon3tr":
			draw_rect(Rect2(-10, -7, 20, 14), Color(color.darkened(0.30), 0.82), true)
			draw_rect(Rect2(-10, -7, 20, 14), Color.WHITE, false, 2.0)
		"ether_shot":
			draw_arc(Vector2.ZERO, 14.0, -1.2, 1.2, 18, Color("#f0d8ff"), 3.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_sequence_enemy(enemy: Dictionary, bob: float) -> void:
	var enemy_id := str(enemy.kind)
	var state := "attack" if bool(enemy.get("attack_pending", false)) or bool(enemy.get("special_pending", false)) or bool(enemy.get("attack_stance", false)) else "run"
	var frame := 0
	if state == "attack" and not bool(enemy.get("attack_pending", false)) and not bool(enemy.get("special_pending", false)):
		frame = enemy_sequences.frame_at_time(enemy_id, state, clock + float(enemy.id) * 0.137)
	elif state == "attack":
		var lead := 1.05 if float(enemy.get("attack_range", 0.0)) > 0.0 else 0.72
		var phase := 1.0 - clampf(float(enemy.get("warning_timer", 0.0)) / lead, 0.0, 1.0)
		frame = enemy_sequences.frame_at_phase(enemy_id, state, phase)
	else:
		frame = enemy_sequences.frame_at_time(enemy_id, state, clock + float(enemy.id) * 0.137)
	var texture := enemy_sequences.texture(enemy_id, state)
	if texture == null:
		return
	var base_size := enemy_sequences.display_size(enemy_id)
	var scale := Vector2.ONE
	if enemy_sequences.procedural(enemy_id) == "spawner_stretch":
		var breathe := sin(clock * 2.6 + float(enemy.id)) * 0.025
		var pulse := clampf(float(enemy.get("spawn_pulse", 0.0)) / 0.55, 0.0, 1.0)
		scale = Vector2(1.0 + breathe + pulse * 0.16, 1.0 - breathe * 0.75 - pulse * 0.11)
	elif float(enemy.get("flash", 0.0)) > 0.0:
		scale = Vector2(1.10, 0.92)
	var foot := Vector2(enemy.pos) + Vector2(0.0, ENEMY_FOOT_OFFSET + bob * 0.22)
	var tint := Color("#fff0e8") if float(enemy.get("flash", 0.0)) > 0.0 and not reduced_effects else Color.WHITE
	_draw_anchored_texture_region(texture, foot, Vector2(base_size, base_size) * scale, enemy_sequences.cell(enemy_id), enemy_sequences.pivot(enemy_id), float(enemy.get("facing", -1.0)), float(enemy_sequences.definition(enemy_id).get("native_facing", 1.0)), enemy_sequences.source_rect(enemy_id, state, frame), tint)

func _draw_enemy_death_visual(enemy: Dictionary) -> void:
	var enemy_id := str(enemy.get("kind", ""))
	if not enemy_sequences.has_enemy(enemy_id):
		return
	var texture := enemy_sequences.texture(enemy_id, "down")
	if texture == null:
		return
	var elapsed := float(enemy.get("elapsed", 0.0))
	var frame := enemy_sequences.frame_at_time(enemy_id, "down", elapsed)
	var base_size := enemy_sequences.display_size(enemy_id)
	var total := float(enemy.get("total", enemy_sequences.duration(enemy_id, "down")))
	var fade := clampf((total - elapsed) / 0.16, 0.0, 1.0) if elapsed > total - 0.16 else 1.0
	_draw_anchored_texture_region(texture, Vector2(enemy.pos) + Vector2(0.0, ENEMY_FOOT_OFFSET), Vector2.ONE * base_size, enemy_sequences.cell(enemy_id), enemy_sequences.pivot(enemy_id), float(enemy.get("facing", -1.0)), float(enemy_sequences.definition(enemy_id).get("native_facing", 1.0)), enemy_sequences.source_rect(enemy_id, "down", frame), Color(1.0, 1.0, 1.0, fade))

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

func _draw_departing_recruit() -> void:
	var character_id := str(departing_recruit.character_id)
	var texture := character_sequences.texture(character_id, "run")
	if texture == null:
		return
	var world_point: Vector2 = departing_recruit.pos
	var screen_point := world_to_screen(world_point)
	var scale_factor := world_depth_scale(world_point)
	current_actor_transform = Transform2D(Vector2(scale_factor, 0.0), Vector2(0.0, scale_factor), screen_point)
	draw_set_transform_matrix(current_actor_transform)
	draw_ellipse_shadow(Vector2(0, HERO_FOOT_OFFSET - 9), 28.0, Color(0, 0, 0, 0.45))
	var display_size := character_sequences.display_size(character_id)
	_draw_anchored_texture_region(texture, Vector2(0, HERO_FOOT_OFFSET), Vector2(display_size, display_size), character_sequences.cell(character_id), character_sequences.pivot(character_id), -1.0, 1.0, character_sequences.source_rect(character_id, "run", int(departing_recruit.frame)), Color.WHITE)
	draw_set_transform(Vector2.ZERO)

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
	if effect.has("feedback_theme") and not reduced_effects:
		var theme: Dictionary = effect.feedback_theme
		var theme_color := VfxPipeline.color_for(theme)
		var accent_color := VfxPipeline.color_for(theme, true)
		draw_arc(effect.pos, 8.0 + t * 34.0, 0.0, TAU, 24, Color(theme_color, fade * (1.0 - t) * 0.72), 3.0, true)
		draw_circle(effect.pos, maxf(1.0, 7.0 * (1.0 - t)), Color(accent_color, fade * 0.82))
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
		var number_lane := float((int(effect.value) + int(effect.pos.x)) % 4) * 8.0
		caption(effect.pos + Vector2(-20 + number_lane, -31 - t * 34 - number_lane * 0.45), str(effect.value), Color(impact_color.lightened(0.38), fade), impact_size)
		if not reduced_effects:
			var impact_extent := 58.0 + t * 34.0
			draw_texture_rect(VFX_FLARE, Rect2(effect.pos - Vector2.ONE * impact_extent * 0.5, Vector2.ONE * impact_extent), false, Color(impact_color.lightened(0.40), fade * (1.0 - t) * 0.88))
			draw_texture_rect(VFX_SPARK, Rect2(effect.pos - Vector2.ONE * impact_extent * 0.62, Vector2.ONE * impact_extent * 1.24), false, Color(impact_color.lightened(0.24), fade * 0.74))
			draw_circle(effect.pos, 12.0 * (1.0 - t), Color.WHITE, false, 3.0, true)
			draw_arc(effect.pos, 10.0 + t * 42.0, -2.65, 0.75, 28, Color(impact_color, fade * 0.82), 4.2 * (1.0 - t) + 1.2, true)
			for i in 10:
				var angle := i * TAU / 10.0 + float(effect.pos.x as int % 7) * 0.07
				var direction := Vector2.from_angle(angle)
				var start := 5.0 + t * (12.0 + i % 3 * 4.0)
				var finish := start + 11.0 + (i % 4) * 5.0
				draw_line(effect.pos + direction * start, effect.pos + direction * finish, Color(impact_color.lightened(0.28), fade * 0.90), 3.2 - (i % 3) * 0.5, true)
			var impact_style := str(effect.get("style", "standard"))
			if impact_style in ["music_note", "hydro_salon", "quantum_gate"]:
				for ring in 2:
					draw_arc(effect.pos, 24.0 + ring * 13.0 + t * 46.0, clock + ring, clock + ring + PI * 1.5, 28, Color(impact_color.lightened(0.30), fade * (0.78 - ring * 0.20)), 3.8 - ring, true)
			elif impact_style in ["arcane_lance", "blade_wave", "mon3tr"]:
				for ray in 6:
					var ray_dir := Vector2.from_angle(ray * TAU / 6.0 + 0.25)
					draw_line(effect.pos + ray_dir * 12.0, effect.pos + ray_dir * (48.0 + t * 54.0), Color(impact_color.lightened(0.44), fade * 0.92), 4.0, true)
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
	elif effect.kind in ["crystal_guard", "enemy_guard", "enemy_heal", "goblin_spawn", "split", "enemy_duplicate"]:
		var helpful: bool = effect.kind in ["crystal_guard", "enemy_heal"]
		var status_color := Color(0.50, 0.95, 0.70, fade) if helpful else Color(0.55, 0.68, 1.0, fade)
		var status_name: String = str({"crystal_guard": "结晶护盾", "enemy_guard": "敌方加盾", "enemy_heal": "敌方治疗", "goblin_spawn": "哥布林出击", "split": "分裂", "enemy_duplicate": "镜像增殖"}.get(effect.kind, effect.kind))
		draw_arc(effect.pos + Vector2(0, -18), 18 + t * 48, 0, TAU, 24, status_color, 3.0, true)
		caption(effect.pos + Vector2(-38, -70 - t * 20), status_name, status_color, 15)
	elif effect.kind == "boss_pulse":
		for ring in 4:
			draw_arc(effect.pos, 24.0 + ring * 22.0 + t * 95.0, 0, TAU, 48, Color(1.0, 0.20, 0.38, fade * (0.8 - ring * 0.14)), 4.0, true)
		caption(effect.pos + Vector2(-48, -105 - t * 35), "裂隙震荡", Color(1.0, 0.55, 0.66, fade), 20)
	elif effect.kind == "enemy_shot":
		var travel: Vector2 = Vector2(effect.get("direction", Vector2.LEFT))
		if travel.length_squared() < 0.1:
			travel = Vector2.LEFT * 80.0
		var start := Vector2(0, -22)
		var landing := travel + Vector2(0, -12)
		var arc_height := clampf(travel.length() * 0.16, 22.0, 58.0)
		var projectile_point := start.lerp(landing, t) + Vector2(0, -sin(t * PI) * arc_height)
		var tangent := (landing - start) + Vector2(0, -cos(t * PI) * arc_height * PI)
		var direction := tangent.normalized()
		var enemy_kind := str(effect.get("enemy_kind", ""))
		draw_ellipse_shadow(landing + Vector2(0, 9), 12.0 * (1.0 - t * 0.4), Color(0, 0, 0, fade * 0.30))
		if enemy_kind == "ranged":
			var side := direction.orthogonal()
			draw_line(projectile_point - direction * 16.0, projectile_point + direction * 12.0, Color(1.0, 0.86, 0.62, fade), 3.2, true)
			draw_colored_polygon(PackedVector2Array([projectile_point + direction * 14.0, projectile_point + side * 5.0, projectile_point - side * 5.0]), Color(1.0, 0.52, 0.30, fade))
		elif enemy_kind == "buffer":
			for ring in 3:
				draw_arc(projectile_point, 7.0 + ring * 4.0, clock * (1.0 + ring * 0.3), clock * (1.0 + ring * 0.3) + PI * 1.55, 18, Color(0.40, 1.0, 0.78, fade * (0.92 - ring * 0.22)), 2.5, true)
			draw_circle(projectile_point, 5.0, Color(0.88, 1.0, 0.96, fade))
		else:
			draw_line(start, projectile_point, Color(1.0, 0.42, 0.30, fade * 0.25), 2.0, true)
			draw_circle(projectile_point, 4.0, Color(1.0, 0.8, 0.55, fade))
		if t > 0.88:
			var impact_alpha := (t - 0.88) / 0.12
			draw_arc(landing, 7.0 + impact_alpha * 18.0, 0, TAU, 22, Color(1.0, 0.48, 0.32, fade * (1.0 - impact_alpha)), 2.5, true)
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
	if not reduced_effects:
		var magic_size := 176.0 + t * 116.0
		draw_texture_rect(VFX_MAGIC, Rect2(center - Vector2.ONE * magic_size * 0.5, Vector2.ONE * magic_size), false, Color(color, fade * (1.0 - t * 0.45) * 0.42))
		var core_size := 74.0 + sin(t * PI) * 42.0
		draw_texture_rect(VFX_FLARE, Rect2(center - Vector2.ONE * core_size * 0.5, Vector2.ONE * core_size), false, Color(color.lightened(0.38), fade * 0.72))
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
