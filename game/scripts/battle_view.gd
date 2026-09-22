extends Node2D
signal stage_exit_finished
## All effects are cosmetic; gameplay remains in CombatSimulation.
const Stage = preload("res://scripts/stage_projection.gd")
const STAGE_VISUAL = preload("res://data/stage_visual_profile.tres")
const UI_LAYOUT = preload("res://data/ui_layout_profile.tres")
const RED_MOON_WARNING_SECONDS := 1.35
const RED_MOON_IMPACT_SECONDS := 1.55
const CROSSFIRE_WARNING_SECONDS := 0.85
const CROSSFIRE_IMPACT_SECONDS := 1.18
const TIDAL_WARNING_SECONDS := 0.65
const TIDAL_EFFECT_SECONDS := 1.80
const TIDAL_TRAVEL_FRACTION := 0.43
const SYLPHIE_GUST_SECONDS := 1.28
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
const WIND_TORNADO_ATLAS = preload("res://assets/vfx/custom/wind_tornado.png")
const FIREBALL_FLIGHT_ATLAS = preload("res://assets/vfx/custom/fireball_flight.png")
const FIREBALL_IMPACT_ATLAS = preload("res://assets/vfx/custom/fireball_impact.png")
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
var sheet_effects
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
		var visual_quality: float = sim.performance_budget.quality_for_load(sim.enemies.size(), sim.projectiles.size() + sim.enemy_projectiles.size(), effects.size())
		reduced_effects = minf(sim.performance_budget.quality_scale, visual_quality) < 0.75
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
	if sim == null or (sim.enemies.size() < 40 and effects.size() < 72):
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
func _signature_visual(hero_index: int, ability_kind: String) -> String:
	if sim == null or hero_index < 0 or hero_index >= sim.heroes.size():
		return ""
	var character_id := str(sim.heroes[hero_index].get("character_id", ""))
	if character_id == "hero_02" and ability_kind == "anemo_domain":
		return "anemo_domain"
	if character_id == "hero_07" and ability_kind in ["sonic_wave", "fate_symphony"]:
		return ability_kind
	if character_id == "hero_08" and ability_kind in ["frost_bloom", "frozen_forest"]:
		return "emilia_" + ability_kind
	if character_id == "hero_06" and ability_kind in ["arcane_lance", "chimera"]:
		return "amiya_" + ability_kind
	if character_id == "hero_04" and ability_kind in ["healing_surge", "storm_field"]:
		return "roxy_" + ability_kind
	if character_id == "hero_10" and ability_kind in ["wind_cut", "renewing_breeze"]:
		return "fengjin_" + ability_kind
	if character_id == "hero_13" and ability_kind in ["thread_shelter", "needle_barrage"]:
		return "gwen_" + ability_kind
	if character_id == "hero_01" and ability_kind in ["columbia_tide_ring", "columbia_tidal_benediction"]:
		return ability_kind
	if character_id == "hero_03" and ability_kind in ["salon_summon", "hydro_fanfare"]:
		return "furina_" + ability_kind
	return ""

func accept_events(batch: Array[Dictionary]) -> void:
	for event in batch:
		if sim != null and sim.endless_mode and event.has("pos") and str(event.get("kind", "")) not in ["boss_arrival", "boss_phase", "arena_event", "lost", "won", "crossfire", "support_heal"] and not _render_point_visible(Vector2(event.pos), 260.0):
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
		if event.kind == "skill_cast" and str(event.get("value", "")) == "静风疗愈":
			var cast_hero: Dictionary = sim.heroes[int(event.hero_id)]
			var cast_radius: float = float(cast_hero.get("active_skill", {}).get("radius", 170.0)) * (1.0 + sim.skill_area_bonus)
			effects.append(effect_pool.acquire({"kind":"sylphie_gust_cast","pos":event.pos,"hero_id":event.hero_id,"radius":cast_radius}, maxf(0.24, float(event.get("hit_delay", 0.331)))))
			continue
		if event.kind == "skill_impact" and str(event.get("ability_kind", "")) == "heal_gust":
			var gust_event: Dictionary = event.duplicate(true)
			gust_event.kind = "sylphie_gust"
			effects.append(effect_pool.acquire(gust_event, SYLPHIE_GUST_SECONDS))
			continue
		if event.kind in ["skill_cast", "ultimate_cast"] and sim != null:
			var caster_index := int(event.get("hero_id", -1))
			if caster_index >= 0 and caster_index < sim.heroes.size():
				var caster: Dictionary = sim.heroes[caster_index]
				var cast_ability: Dictionary = caster.get("ultimate", {}) if event.kind == "ultimate_cast" else caster.get("active_skill", {})
				var cast_kind := str(cast_ability.get("kind", ""))
				var visual_kind := _signature_visual(caster_index, cast_kind)
				if not visual_kind.is_empty():
					var cast_center: Vector2 = Vector2(event.pos) if Sim.SELF_CENTERED_ABILITY_KINDS.has(cast_kind) else Vector2(event.get("target", event.pos))
					var cast_event := {"kind":visual_kind + "_cast", "pos":cast_center, "caster_pos":event.pos, "radius":float(cast_ability.get("radius", 180.0)) * (1.0 + sim.skill_area_bonus)}
					effects.append(effect_pool.acquire(cast_event, maxf(0.24, float(event.get("hit_delay", 0.35)))))
					continue
		if event.kind in ["skill_impact", "ultimate_impact"]:
			var impact_kind := str(event.get("ability_kind", ""))
			var impact_visual := _signature_visual(int(event.get("hero_id", -1)), impact_kind)
			if not impact_visual.is_empty():
				var dedicated_event: Dictionary = event.duplicate(true)
				dedicated_event.kind = impact_visual + "_impact"
				dedicated_event.caster_pos = sim.heroes[int(event.hero_id)].pos
				effects.append(effect_pool.acquire(dedicated_event, 1.50 if impact_visual in ["fate_symphony", "emilia_frozen_forest", "amiya_chimera", "roxy_storm_field", "fengjin_renewing_breeze", "gwen_needle_barrage", "columbia_tide_ring", "columbia_tidal_benediction", "furina_hydro_fanfare"] else 1.18))
				if impact_visual == "furina_hydro_fanfare":
					var fanfare_allies: Array[int] = []
					for ally: Dictionary in sim.heroes:
						if bool(ally.get("deployed", false)) and ally.hp > 0.0:
							fanfare_allies.append(int(ally.id))
					effects.append(effect_pool.acquire({"kind":"furina_fanfare_allies","pos":dedicated_event.caster_pos,"ally_ids":fanfare_allies}, 3.4))
				if impact_visual == "columbia_tidal_benediction":
					var blessing: Dictionary = sim.skill_effects.back() if not sim.skill_effects.is_empty() else {}
					if str(blessing.get("kind", "")) == "columbia_attack_blessing":
						effects.append(effect_pool.acquire({"kind":"columbia_blessing_links","pos":dedicated_event.caster_pos,"hero_id":event.hero_id,"ally_ids":blessing.get("ally_ids", [])}, 25.0))
				if impact_visual == "gwen_thread_shelter":
					var recipients: Array[int] = []
					for ally: Dictionary in sim.heroes:
						if bool(ally.get("deployed", false)) and ally.hp > 0.0 and sim.is_in_ability_area(Vector2(dedicated_event.caster_pos), Vector2(ally.pos), float(dedicated_event.radius)):
							recipients.append(int(ally.id))
					effects.append(effect_pool.acquire({"kind":"gwen_shelter_aura","pos":dedicated_event.caster_pos,"ally_ids":recipients}, 5.0))
				continue
		if event.kind == "vfx_cue" and (str(event.get("value", "")) == "heal_gust" or not _signature_visual(int(event.get("hero_id", -1)), str(event.get("value", ""))).is_empty()):
			continue
		if sim != null and event.kind in ["skill_cast", "skill_impact"] and event.has("traveler_element"):
			var traveler_visual := event.duplicate(true)
			traveler_visual.kind = "traveler_" + str(event.traveler_element) + ("_cast" if event.kind == "skill_cast" else "_impact")
			traveler_visual.pos = event.get("target", event.pos) if event.kind == "skill_cast" else event.pos
			traveler_visual.radius = sim.traveler_skill_radius() * (1.0 + sim.skill_area_bonus)
			effects.append(effect_pool.acquire(traveler_visual, maxf(0.34, float(event.get("hit_delay", 0.34))) if event.kind == "skill_cast" else 1.25))
			continue
		if event.kind == "skill_electro" and event.has("target_positions"):
			effects.append(effect_pool.acquire({"kind":"traveler_electro_chains","pos":event.pos,"target_positions":event.target_positions,"radius":sim.traveler_skill_radius() * (1.0 + sim.skill_area_bonus)}, 1.05))
			continue
		if event.kind in ["skill_none", "skill_electro", "skill_pyro", "skill_hydro", "skill_geo", "skill_cryo"]:
			continue
		if event.kind == "fengjin_wind_row":
			effects.append(effect_pool.acquire(event.duplicate(true), 0.42))
			continue
		if event.kind == "gwen_needle_hit":
			effects.append(effect_pool.acquire(event.duplicate(true), 0.38))
			continue
		if str(event.kind).begins_with("rift_"):
			var lifetime := 1.12 if event.kind == "rift_storm" else (0.72 if event.kind in ["rift_laser", "rift_overhead"] else 0.48)
			effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
			continue
		if str(event.kind).begins_with("slime_"):
			var lifetime := 1.38 if event.kind in ["slime_reflux", "slime_court", "slime_court_final"] else (0.92 if event.kind in ["slime_bounce", "slime_burst"] else 0.68)
			effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
			continue
		if str(event.kind).begins_with("galio_"):
			var lifetime := 1.65 if event.kind == "galio_entrance" else (1.35 if event.kind in ["galio_winds", "galio_durand"] else 0.95)
			effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
			shake_trauma = minf(1.0, shake_trauma + float({"galio_entrance":0.78,"galio_punch":0.52,"galio_winds":0.28,"galio_winds_pulse":0.14,"galio_durand":0.42,"galio_guard":0.24}.get(str(event.kind),0.0)))
			continue
		if str(event.kind).begins_with("kindred_"):
			var lifetime := 5.15 if event.kind == "kindred_respite" else (2.10 if event.kind == "kindred_hunt" else (1.80 if event.kind == "kindred_wolf" else (1.30 if event.kind in ["kindred_dance", "kindred_dread"] else 0.95)))
			effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
			var kindred_trauma: float = float({"kindred_dance":0.24,"kindred_wolf":0.48,"kindred_wolf_strike":0.20,"kindred_dread":0.34,"kindred_hunt":0.72,"kindred_arrow_hit":0.12,"kindred_respite":0.58,"kindred_respite_end":0.46}.get(str(event.kind),0.0))
			shake_trauma = minf(1.0, shake_trauma + kindred_trauma)
			continue
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
			"barrage", "crossfire":
				# Support strikes remain legible even when optional particles are culled.
				var lifetime := RED_MOON_IMPACT_SECONDS if event.kind == "barrage" else CROSSFIRE_IMPACT_SECONDS
				effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
				shake_trauma = minf(1.0, shake_trauma + (0.42 if event.kind == "barrage" else 0.18))
			"support_heal":
				effects.append(effect_pool.acquire(event.duplicate(true), TIDAL_EFFECT_SECONDS))
			"fireball_fall", "fireball_impact":
				var active_fireballs := effects.filter(func(fx: Dictionary) -> bool: return str(fx.get("kind", "")).begins_with("fireball_"))
				if active_fireballs.size() < 8 and (sim == null or sim.performance_budget.can_spawn_cosmetic(str(event.kind), effects.size())):
					var lifetime := float(event.get("duration", 0.72)) if event.kind == "fireball_fall" else 33.0 / 24.0
					effects.append(effect_pool.acquire(event.duplicate(true), lifetime))
			"hit", "critical", "death", "move", "formation", "hurt", "down", "heal", "arena_event", "vaporize", "melt", "overloaded", "superconduct", "electro_charged", "frozen", "swirl", "crystallize", "element_burst", "shatter", "swirl_spread", "slash", "splash", "multishot", "pierce", "chain", "echo", "death_burst", "frenzy", "kill_streak", "reinforcement", "finale", "shield_hit", "shield_break", "knockback", "crystal_guard", "enemy_heal", "enemy_guard", "goblin_spawn", "split", "enemy_duplicate", "enemy_blink", "enemy_volatile", "skill_suppressed", "boss_move", "contract_complete", "boss_phase", "weather_pulse", "trap_pulse", "boss_pulse", "boss_summon", "enemy_shot", "reward_taken", "element_attuned", "skill_none", "skill_anemo", "skill_electro", "skill_pyro", "skill_hydro", "skill_geo", "skill_cryo", "geo_hit", "geo_break", "mechanism_pulse", "terrain_hit", "terrain_break", "deploy", "recall", "dodge", "skill_cast", "skill_impact", "vfx_cue", "ultimate_cast", "ultimate_impact", "synced_impact", "orbit_hit", "orbit_storm", "tag_synergy", "relic_awaken", "revive":
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
				var effect_cap: int = sim.performance_budget.effect_cap() if sim != null and sim.performance_budget != null else 240
				while effects.size() > effect_cap:
					effect_pool.release(effects.pop_front())
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
		if str(zone.get("kind", "")) in ["wind_cut_rows", "columbia_attack_blessing"]:
			continue
		if _render_point_visible(Vector2(zone.get("pos", Vector2.ZERO)), 180.0 + _skill_zone_radius(zone)):
			_draw_skill_zone(zone)
	for construct: Dictionary in sim.geo_constructs:
		if _render_point_visible(Vector2(construct.get("pos", Vector2.ZERO)), 140.0):
			_draw_geo_construct(construct)
	if skill_targeting:
		_draw_skill_preview()
	if selected_id >= 0:
		var hero: Dictionary = sim.heroes[selected_id]
		if hero.hp > 0 and bool(hero.get("deployed", true)):
			var showing_wind_rows: bool = str(hero.get("active_skill", {}).get("kind", "")) == "wind_cut" and ((skill_targeting and not skill_preview_ultimate) or sim.skill_effects.any(func(zone: Dictionary) -> bool: return str(zone.get("kind", "")) == "wind_cut_rows" and int(zone.get("hero_id", -1)) == selected_id))
			if not showing_wind_rows:
				_draw_range_indicator(hero)
	for hero in sim.heroes:
		if hero.hp > 0 and hero.pos.distance_to(hero.target) > 3.0:
			draw_dashed_line(world_to_screen(hero.pos), world_to_screen(hero.target), Color(hero.color, 0.6), 1.0, 7.0)
			_ground_circle(hero.target, 13.0, Color(hero.color))
	_draw_red_moon_warning()
	_draw_crossfire_warning()
	_draw_tidal_warning()
	# Combat effects and projectiles belong behind every unit silhouette.
	if sheet_effects != null:
		sheet_effects.draw_behind_units(self)
	for hazard: Dictionary in sim.enemy_hazards:
		if _render_point_visible(Vector2(hazard.get("pos", Vector2.ZERO)), 180.0):
			if str(hazard.get("kind", "")).begins_with("galio_"):
				_draw_galio_hazard(hazard)
			elif str(hazard.get("kind", "")).begins_with("kindred_"):
				_draw_kindred_hazard(hazard)
			else:
				_draw_slime_hazard(hazard)
	for projectile in sim.projectiles:
		if _render_point_visible(Vector2(projectile.get("pos", Vector2.ZERO)), 120.0):
			_draw_projectile(projectile)
	for projectile: Dictionary in sim.enemy_projectiles:
		if float(projectile.get("delay", 0.0)) > 0.0:
			continue
		if _render_point_visible(Vector2(projectile.pos), 120.0):
			var projectile_kind := str(projectile.get("kind", ""))
			if projectile_kind in ["slime_glob", "slime_image"]:
				_draw_slime_projectile(projectile)
				continue
			if projectile_kind in ["kindred_arrow", "kindred_dread_arrow"]:
				_draw_kindred_projectile(projectile)
				continue
			var point := world_to_screen(Vector2(projectile.pos)) + Vector2(0, -17)
			var orb: bool = projectile_kind == "rift_orb"
			var enraged_orb := orb and bool(projectile.get("enraged", false))
			var size := (19.0 if enraged_orb else (13.0 if orb else 8.0)) * world_depth_scale(Vector2(projectile.pos))
			var outer := Color(0.72, 0.02, 0.08, 0.30) if enraged_orb else Color(0.35, 0.08, 0.65, 0.24 if orb else 0.12)
			var middle := Color(0.92, 0.05, 0.12, 0.62) if enraged_orb else Color(0.40, 0.15, 0.75, 0.45)
			var core := Color(1.0, 0.14, 0.20, 0.98) if enraged_orb else Color(0.67, 0.35, 1.0, 0.98)
			draw_circle(point, size + 8.0, outer)
			draw_circle(point, size + 4.0, middle)
			draw_circle(point, size, core)
			draw_circle(point + Vector2(-2, -2), size * 0.38, Color(0.96, 0.88, 1.0, 0.98))
	for effect in effects:
		if effect.kind not in ["crossfire", "support_heal", "columbia_blessing_links", "rift_laser", "rift_overhead"] and not _render_point_visible(Vector2(effect.get("pos", Vector2.ZERO)), 180.0):
			continue
		if str(effect.kind).begins_with("rift_"):
			_draw_rift_boss_effect(effect)
			continue
		if str(effect.kind).begins_with("slime_"):
			_draw_slime_boss_effect(effect)
			continue
		if str(effect.kind).begins_with("galio_"):
			_draw_galio_boss_effect(effect)
			continue
		if str(effect.kind).begins_with("kindred_"):
			_draw_kindred_boss_effect(effect)
			continue
		if effect.kind == "fireball_fall":
			_draw_falling_fireball(effect)
			continue
		if effect.kind == "crossfire":
			_draw_crossfire_impact(effect)
			continue
		if effect.kind == "support_heal":
			_draw_tidal_heal(effect)
			continue
		if effect.kind in ["sylphie_gust_cast", "sylphie_gust"]:
			_draw_sylphie_gust(effect)
			continue
		if str(effect.kind) in ["anemo_domain_cast", "anemo_domain_impact", "sonic_wave_cast", "sonic_wave_impact", "fate_symphony_cast", "fate_symphony_impact", "emilia_frost_bloom_cast", "emilia_frost_bloom_impact", "emilia_frozen_forest_cast", "emilia_frozen_forest_impact", "amiya_arcane_lance_cast", "amiya_arcane_lance_impact", "amiya_chimera_cast", "amiya_chimera_impact", "roxy_healing_surge_cast", "roxy_healing_surge_impact", "roxy_storm_field_cast", "roxy_storm_field_impact", "fengjin_wind_cut_cast", "fengjin_wind_cut_impact", "fengjin_renewing_breeze_cast", "fengjin_renewing_breeze_impact", "gwen_thread_shelter_cast", "gwen_thread_shelter_impact", "gwen_needle_barrage_cast", "gwen_needle_barrage_impact", "columbia_tide_ring_cast", "columbia_tide_ring_impact", "columbia_tidal_benediction_cast", "columbia_tidal_benediction_impact", "furina_salon_summon_cast", "furina_salon_summon_impact", "furina_hydro_fanfare_cast", "furina_hydro_fanfare_impact"]:
			_draw_dedicated_ability(effect)
			continue
		if effect.kind == "gwen_shelter_aura":
			_draw_gwen_shelter_aura(effect)
			continue
		if effect.kind == "columbia_blessing_links":
			_draw_columbia_blessing_links(effect)
			continue
		if effect.kind == "traveler_electro_chains":
			_draw_traveler_electro_chains(effect)
			continue
		if str(effect.kind).begins_with("traveler_"):
			_draw_traveler_ability(effect)
			continue
		if effect.kind == "fengjin_wind_row":
			_draw_fengjin_wind_row(effect)
			continue
		if effect.kind == "furina_fanfare_allies":
			_draw_furina_fanfare_allies(effect)
			continue
		if effect.kind == "gwen_needle_hit":
			_draw_gwen_needle_hit(effect)
			continue
		if effect.kind in ["skill_impact", "ultimate_impact"] and effect.has("radius"):
			_draw_ability_impact(effect)
			continue
		var point: Vector2 = world_to_screen(effect.pos)
		var scale_factor: float = world_depth_scale(effect.pos)
		draw_set_transform(point, 0, Vector2(scale_factor, scale_factor))
		var visual: Dictionary = effect.duplicate()
		if effect.kind == "barrage":
			visual.red_moon_radii = sim.support_barrage_screen_radii(Vector2(effect.pos), float(effect.get("radius", 105.0))) / scale_factor
			visual.red_moon_scale = scale_factor
		visual.pos = Vector2.ZERO
		_draw_effect(visual)
		draw_set_transform(Vector2.ZERO)
	var actors: Array[Dictionary] = []
	var render_world := visible_world_rect().grow(180.0) if sim.endless_mode else WORLD
	for enemy in sim.enemies:
		if str(enemy.get("kind", "")) == "boss_galio" and not bool(enemy.get("galio_revealed", true)):
			continue
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
			var boss_attack := str(enemy.get("kind", "")).begins_with("boss_")
			_draw_warning_reticle(center, radius, ratio, float(enemy.get("warning_timer", 0.0)), boss_attack, "⚠ 首领攻击" if boss_attack else "")
		if bool(enemy.get("special_pending", false)):
			if str(enemy.get("kind", "")) == "boss_01" and str(enemy.get("special_move", "")).begins_with("rift_"):
				_draw_rift_boss_warning(enemy)
				continue
			if str(enemy.get("kind", "")) == "boss_02" and str(enemy.get("special_move", "")).begins_with("slime_"):
				_draw_slime_boss_warning(enemy)
				continue
			if str(enemy.get("kind", "")) == "boss_03" and str(enemy.get("special_move", "")).begins_with("kindred_"):
				_draw_kindred_boss_warning(enemy)
				continue
			if str(enemy.get("kind", "")) == "boss_galio" and str(enemy.get("special_move", "")).begins_with("galio_"):
				_draw_galio_boss_warning(enemy)
				continue
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

func _rift_ellipse(point: Vector2, radii: Vector2, alpha: float, fill: float) -> void:
	var vertices := PackedVector2Array()
	for step in 65:
		var angle := TAU * float(step) / 64.0
		vertices.append(point + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(vertices, Color(0.39, 0.10, 0.75, fill))
	draw_polyline(vertices, Color(0.72, 0.42, 1.0, alpha), 3.0, true)


func _rift_laser_ribbon(source: Vector2, target: Vector2, radius: float, alpha: float, strike: bool) -> void:
	var direction := (target - source).normalized()
	if direction.length_squared() < 0.01:
		return
	var side := direction.orthogonal() * radius
	var corners := PackedVector2Array([world_to_screen(source + side), world_to_screen(source - side), world_to_screen(target - side), world_to_screen(target + side)])
	draw_colored_polygon(corners, Color(0.49, 0.12, 0.83, alpha * (0.72 if strike else 0.18)))
	draw_polyline(PackedVector2Array([corners[0], corners[3], corners[2], corners[1], corners[0]]), Color(0.78, 0.48, 1.0, alpha), 3.0, true)
	if strike:
		draw_line(world_to_screen(source), world_to_screen(target), Color(0.96, 0.86, 1.0, alpha), 11.0, true)


func _draw_rift_boss_warning(enemy: Dictionary) -> void:
	var move := str(enemy.get("special_move", ""))
	var points: Array = enemy.get("special_warning_positions", [])
	if points.is_empty():
		return
	var progress := 1.0 - clampf(float(enemy.get("special_warning", 0.0)) / maxf(0.01, float(enemy.get("special_warning_total", 1.0))), 0.0, 1.0)
	var pulse := 0.70 + 0.30 * sin(clock * 14.0)
	var radius := float(enemy.get("special_warning_radius", 100.0))
	var enraged := int(enemy.get("boss_phase", 1)) >= 3
	if move == "rift_laser":
		for target_value: Variant in points:
			_rift_laser_ribbon(Vector2(enemy.pos), Vector2(target_value), radius, (0.44 + progress * 0.5) * pulse, false)
	elif move == "rift_orbs":
		var point := world_to_screen(Vector2(enemy.pos))
		var orb_count := 18 if enraged else 10
		var orb_color := Color(1.0, 0.08, 0.15, 0.55 + progress * 0.40) if enraged else Color(0.70, 0.32, 1.0, 0.52 + progress * 0.38)
		for orb in orb_count:
			var angle := float(orb) * TAU / float(orb_count) + clock * 1.8
			var orb_pos := point + Vector2.from_angle(angle) * ((48.0 if enraged else 34.0) + 8.0 * progress)
			draw_circle(orb_pos, 8.0 if enraged else 5.5, orb_color)
		for hero: Dictionary in sim.heroes:
			if bool(hero.get("deployed", false)) and hero.hp > 0.0:
				draw_dashed_line(point, world_to_screen(Vector2(hero.pos)), Color(0.72, 0.40, 1.0, 0.18 + progress * 0.28), 1.5, 12.0, true)
	elif move == "rift_storm":
		var point := Vector2(points[0])
		var screen := world_to_screen(point) + Vector2(0, 8)
		var radii: Vector2 = sim.ability_area_screen_radii(point, radius)
		var ring_count := 5 if enraged else 4
		for ring in ring_count:
			var ring_scale := (float(ring + 1) / float(ring_count)) * (0.72 + progress * 0.28)
			_rift_ellipse(screen, radii * ring_scale, (0.40 + progress * 0.5) * pulse, 0.025 + progress * 0.025)
	else:
		for value: Variant in points:
			var point: Vector2 = value
			var radii: Vector2 = sim.ability_area_screen_radii(point, radius)
			_rift_ellipse(world_to_screen(point) + Vector2(0, 8), radii, (0.48 + progress * 0.45) * pulse, 0.07 + progress * 0.11)
			if move == "rift_overhead":
				draw_line(world_to_screen(point) + Vector2(0, -170), world_to_screen(point), Color(0.74, 0.46, 1.0, 0.22 + progress * 0.4), 2.0, true)


func _draw_rift_boss_effect(effect: Dictionary) -> void:
	var alpha := clampf(float(effect.get("life", 0.0)) / maxf(0.01, float(effect.get("total", 0.5))), 0.0, 1.0)
	match str(effect.kind):
		"rift_laser":
			for target_value: Variant in effect.get("targets", [effect.get("target", effect.pos)]):
				_rift_laser_ribbon(Vector2(effect.pos), Vector2(target_value), float(effect.get("radius", 64.0)), alpha, true)
		"rift_overhead":
			for value: Variant in effect.get("points", []):
				var point: Vector2 = value
				var screen := world_to_screen(point)
				_rift_ellipse(screen + Vector2(0, 8), sim.ability_area_screen_radii(point, float(effect.get("radius", 92.0))), alpha, 0.20 * alpha)
				var beam_scale := 1.65 if int(effect.get("phase", 1)) >= 3 else 1.0
				draw_line(screen + Vector2(0, -280), screen, Color(0.85, 0.58, 1.0, alpha), (16.0 * alpha + 2.0) * beam_scale, true)
				draw_line(screen + Vector2(0, -280), screen, Color(0.99, 0.93, 1.0, alpha), (5.0 * alpha + 1.0) * beam_scale, true)
		"rift_storm":
			var point: Vector2 = effect.pos
			var screen := world_to_screen(point)
			var radii: Vector2 = sim.ability_area_screen_radii(point, float(effect.get("radius", 240.0)))
			var elapsed_ratio := 1.0 - alpha
			var ring_count := int(effect.get("rings", 4))
			for ring in ring_count:
				var wave := clampf(elapsed_ratio * 1.35 - float(ring) * 0.16, 0.0, 1.0)
				if wave <= 0.0:
					continue
				var wave_alpha := sin(wave * PI) * 0.95
				_rift_ellipse(screen + Vector2(0, 8), radii * wave, wave_alpha, 0.045 * wave_alpha)
			for bolt in 14:
				var angle := float(bolt) * TAU / 14.0 + clock * 0.3
				var wave_radius := radii * clampf(elapsed_ratio * 1.18, 0.12, 1.0)
				var edge := screen + Vector2(cos(angle) * wave_radius.x, sin(angle) * wave_radius.y)
				draw_line(screen, edge, Color(0.76, 0.45, 1.0, alpha * 0.46), 2.4, true)
		"rift_arc":
			var source := world_to_screen(Vector2(effect.pos)) + Vector2(0, -35)
			var target := world_to_screen(Vector2(effect.target)) + Vector2(0, -24)
			var mid := (source + target) * 0.5 + Vector2(0, -16)
			draw_polyline(PackedVector2Array([source, mid, target]), Color(0.85, 0.64, 1.0, alpha), 6.0, true)
		"rift_orbs":
			var point := world_to_screen(Vector2(effect.pos))
			var orb_count := int(effect.get("count", 10))
			var enraged := bool(effect.get("enraged", false))
			for orb in orb_count:
				var angle := float(orb) * TAU / float(orb_count) + clock
				draw_circle(point + Vector2.from_angle(angle) * (54.0 if enraged else 42.0), 10.0 if enraged else 7.0, Color(1.0, 0.08, 0.15, alpha) if enraged else Color(0.69, 0.31, 1.0, alpha))
		"rift_orb_hit":
			var point := world_to_screen(Vector2(effect.pos))
			var radii: Vector2 = sim.ability_area_screen_radii(Vector2(effect.pos), float(effect.get("radius", 62.0)))
			_rift_ellipse(point + Vector2(0, 8), radii * (1.1 - alpha * 0.1), alpha, alpha * 0.16)



func _kindred_ellipse(center: Vector2, radii: Vector2, color: Color, alpha: float, width: float = 3.0, fill_alpha: float = 0.0) -> void:
	var points := PackedVector2Array()
	for index in 65:
		var angle := float(index) * TAU / 64.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	if fill_alpha > 0.0:
		var fill := points.duplicate()
		fill.resize(64)
		draw_colored_polygon(fill, Color(color, fill_alpha))
	draw_polyline(points, Color(color, alpha), width, true)


func _galio_curve_points(start: Vector2, control: Vector2, finish: Vector2, progress: float = 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var limit := maxi(1, floori(28.0 * clampf(progress, 0.0, 1.0)))
	for step in range(limit + 1):
		var t := float(step) / 28.0
		var inverse := 1.0 - t
		points.append(start * inverse * inverse + control * 2.0 * inverse * t + finish * t * t)
	return points

func _draw_galio_silhouette(center: Vector2, scale_factor: float, alpha: float, wing_lift: float = 0.0) -> void:
	var violet := Color("#d6b1ff")
	var gold := Color("#f5d976")
	var wing_span := 86.0 * scale_factor
	var wing_rise := (66.0 + wing_lift * 42.0) * scale_factor
	draw_circle(center + Vector2(0, 28) * scale_factor, 34.0 * scale_factor, Color(0.06, 0.03, 0.12, 0.38 * alpha))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-12,-42) * scale_factor,
		center + Vector2(-wing_span,-wing_rise),
		center + Vector2(-58,-6) * scale_factor,
		center + Vector2(-94,24) * scale_factor,
		center + Vector2(-20,30) * scale_factor
	]), Color(violet, 0.78 * alpha))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(12,-42) * scale_factor,
		center + Vector2(wing_span,-wing_rise),
		center + Vector2(58,-6) * scale_factor,
		center + Vector2(94,24) * scale_factor,
		center + Vector2(20,30) * scale_factor
	]), Color(violet, 0.78 * alpha))
	draw_circle(center + Vector2(0,-22) * scale_factor, 31.0 * scale_factor, Color(0.20, 0.13, 0.30, alpha))
	draw_arc(center + Vector2(0,-22) * scale_factor, 32.0 * scale_factor, -2.85, -0.29, 34, Color(gold, alpha), 6.0 * scale_factor, true)
	draw_line(center + Vector2(-22,9) * scale_factor, center + Vector2(-42,45) * scale_factor, Color(gold, alpha), 10.0 * scale_factor, true)
	draw_line(center + Vector2(22,9) * scale_factor, center + Vector2(42,45) * scale_factor, Color(gold, alpha), 10.0 * scale_factor, true)

func _draw_galio_boss_warning(enemy: Dictionary) -> void:
	var move := str(enemy.get("special_move", ""))
	var points: Array = enemy.get("special_warning_positions", [])
	if points.is_empty():
		return
	var progress := 1.0 - clampf(float(enemy.get("special_warning", 0.0)) / maxf(0.01, float(enemy.get("special_warning_total", 1.0))), 0.0, 1.0)
	var center := world_to_screen(Vector2(points[0])) + Vector2(0, 8)
	var source := world_to_screen(Vector2(enemy.pos)) + Vector2(0, -25)
	var radius := float(enemy.get("special_warning_radius", 220.0))
	var radii: Vector2 = sim.ability_area_screen_radii(Vector2(points[0]), radius)
	var violet := Color("#b989ff")
	var gold := Color("#f5d976")
	var pulse := 0.68 + sin(clock * 16.0) * 0.32
	if move == "galio_entrance":
		var takeoff := world_to_screen(Vector2(enemy.get("galio_takeoff_pos", enemy.pos))) + Vector2(0, -25)
		var flight_point := takeoff
		var flight_scale := 1.0
		var wing_lift := 0.0
		if progress < 0.36:
			var rise := smoothstep(0.0, 0.36, progress)
			flight_point = takeoff.lerp(takeoff + Vector2(0, -300), rise)
			flight_scale = lerpf(1.0, 0.72, rise)
			wing_lift = rise
		else:
			var fall := smoothstep(0.36, 1.0, progress)
			flight_point = (center + Vector2(0, -455)).lerp(center, fall)
			flight_scale = lerpf(0.70, 1.18, fall)
			wing_lift = 1.0 - fall
		_draw_galio_silhouette(flight_point, flight_scale, 0.96, wing_lift)
		_kindred_ellipse(center, radii, violet, (0.48 + progress * 0.44) * pulse, 5.0, 0.055 + progress * 0.10)
		for ring in 4:
			var ring_scale := clampf(1.28 - progress * 0.30 - ring * 0.13, 0.58, 1.25)
			_kindred_ellipse(center, radii * ring_scale, gold, 0.20 + progress * 0.46, 2.5)
		for ray in 16:
			var angle := float(ray) * TAU / 16.0
			var inner := center + Vector2(cos(angle) * radii.x * 0.18, sin(angle) * radii.y * 0.18)
			var outer := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			draw_line(inner, outer, Color(gold, 0.18 + progress * 0.66), 3.0, true)
		draw_circle(center + Vector2(0, 18), 28.0 + progress * 82.0, Color(0.04, 0.02, 0.09, 0.20 * progress))
		return
	if move == "galio_punch":
		var direction := (center - source).normalized()
		if direction.length_squared() < 0.01:
			direction = Vector2.LEFT
		var finish := source + direction * 560.0
		var side := direction.orthogonal() * (42.0 + progress * 34.0)
		var danger := Color("#ff183f")
		var hot := Color("#ffb06b")
		draw_colored_polygon(PackedVector2Array([source+side,source-side,finish-side,finish+side]), Color(danger, 0.16 + progress * 0.22))
		for stripe in 9:
			var stripe_center := source.lerp(finish, 0.08 + stripe * 0.105)
			var stripe_side := side * (0.74 + 0.18 * sin(clock * 9.0 + stripe))
			draw_line(stripe_center - stripe_side, stripe_center + stripe_side, Color(danger, 0.17 + progress * 0.35), 7.0, true)
		draw_polyline(PackedVector2Array([source+side,finish+side,finish-side,source-side,source+side]), Color(danger, 0.82 + pulse * 0.18), 7.0, true)
		draw_line(source, finish, Color(hot, 0.24 + progress * 0.68), 4.0 + progress * 5.0, true)
		for mark in 7:
			var point := source.lerp(finish, 0.13 + mark * 0.12)
			var chevron := direction.orthogonal() * (13.0 + progress * 8.0)
			draw_polyline(PackedVector2Array([point-direction*20.0+chevron, point, point-direction*20.0-chevron]), Color(hot, 0.48 + progress * 0.48), 4.0, true)
		draw_circle(finish, 22.0 + progress * 18.0, Color(danger, 0.22 + progress * 0.36))
		return
	if move == "galio_winds":
		_kindred_ellipse(center, radii, violet, 0.52 + progress * 0.38, 4.0, 0.05 + progress * 0.06)
		var travel := clampf(progress * 1.10, 0.0, 1.0)
		var direction := (center - source).normalized()
		var perpendicular := direction.orthogonal()
		for side_sign in [-1.0, 1.0]:
			var begin: Vector2 = source + perpendicular * 64.0 * float(side_sign)
			var control: Vector2 = source.lerp(center, 0.50) + perpendicular * 155.0 * float(side_sign) - direction * 35.0
			var curve := _galio_curve_points(begin, control, center, travel)
			draw_polyline(curve, Color(violet, 0.24 + progress * 0.58), 11.0, true)
			draw_polyline(curve, Color(gold, 0.38 + progress * 0.56), 3.0, true)
			if curve.size() > 0:
				draw_circle(curve[-1], 8.0 + progress * 5.0, Color("#efe7ff", 0.72))
		return
	if move == "galio_durand":
		var expansion := 0.10 + smoothstep(0.0, 1.0, progress) * 0.90
		for echo in 3:
			var echo_scale := maxf(0.08, expansion - echo * 0.12)
			_kindred_ellipse(center, radii * echo_scale, violet if echo % 2 == 0 else gold, (0.44 + progress * 0.42) * (1.0 - echo * 0.18), 6.0 - echo)
		_kindred_ellipse(center, radii * expansion, gold, 0.72 + progress * 0.24, 8.0, 0.08 + progress * 0.08)
		for wing in [-1.0, 1.0]:
			var wing_size := expansion
			draw_polyline(PackedVector2Array([center,center+Vector2(wing*radii.x*0.42,-radii.y*0.48)*wing_size,center+Vector2(wing*radii.x*0.78,0)*wing_size,center+Vector2(wing*radii.x*0.46,radii.y*0.42)*wing_size]),Color(gold,0.46+progress*0.46),7.0,true)
		return
	_kindred_ellipse(center, radii, violet, (0.58 + progress * 0.38) * pulse, 5.0, 0.08 + progress * 0.10)

func _draw_galio_hazard(hazard: Dictionary) -> void:
	var center := world_to_screen(Vector2(hazard.pos)) + Vector2(0, 8)
	var radii: Vector2 = sim.ability_area_screen_radii(Vector2(hazard.pos), float(hazard.get("radius", 175.0)))
	var delay := float(hazard.get("delay", 0.0))
	if delay > 0.0:
		var source := world_to_screen(Vector2(hazard.get("source", hazard.pos))) + Vector2(0, -24)
		var travel_total := maxf(0.01, float(hazard.get("travel_total", 0.72)))
		var travel := 1.0 - clampf(delay / travel_total, 0.0, 1.0)
		var direction := (center - source).normalized()
		var perpendicular := direction.orthogonal()
		for side_sign in [-1.0, 1.0]:
			var begin: Vector2 = source + perpendicular * 62.0 * float(side_sign)
			var control: Vector2 = source.lerp(center, 0.48) + perpendicular * 150.0 * float(side_sign)
			var curve := _galio_curve_points(begin, control, center, travel)
			draw_polyline(curve, Color("#b989ff", 0.70), 13.0, true)
			draw_polyline(curve, Color("#f5d976", 0.92), 3.4, true)
			if curve.size() > 0:
				draw_circle(curve[-1], 10.0, Color("#f4ecff", 0.92))
		return
	var life_ratio := clampf(float(hazard.get("life", 0.0)) / maxf(0.01,float(hazard.get("total", 1.0))),0.0,1.0)
	_kindred_ellipse(center,radii,Color("#b989ff"),0.72*life_ratio,4.0,0.08*life_ratio)
	for spiral in 6:
		var phase := fposmod(clock*0.44+spiral/6.0,1.0)
		_kindred_ellipse(center,radii*(0.18+phase*0.78),Color("#efd57a"),sin(phase*PI)*0.42*life_ratio,2.0)

func _draw_galio_boss_effect(effect: Dictionary) -> void:
	var kind := str(effect.get("kind", ""))
	var center := world_to_screen(Vector2(effect.get("pos", Vector2.ZERO))) + Vector2(0, 8)
	var radius := float(effect.get("radius", 190.0))
	var radii: Vector2 = sim.ability_area_screen_radii(Vector2(effect.get("pos", Vector2.ZERO)), radius)
	var alpha := clampf(float(effect.get("life", 0.0)) / maxf(0.01,float(effect.get("total", 1.0))),0.0,1.0)
	var elapsed := 1.0 - alpha
	var violet := Color("#b989ff")
	var gold := Color("#f5d976")
	if kind in ["galio_entrance","galio_guard"]:
		for ring in 6:
			var wave := fposmod(elapsed*1.65+ring*0.14,1.0)
			_kindred_ellipse(center,radii*(0.12+wave*0.94),gold,sin(wave*PI)*0.86,8.0-ring*0.8,0.035*alpha)
		for wing in [-1.0,1.0]:
			draw_polyline(PackedVector2Array([center,center+Vector2(wing*82,-112),center+Vector2(wing*166,-28),center+Vector2(wing*106,66)]),Color(violet,0.86*alpha),15.0,true)
	elif kind == "galio_punch":
		var source := world_to_screen(Vector2(effect.get("source", effect.get("pos",Vector2.ZERO))))
		draw_line(source,center,Color("#ff173f",0.44*alpha),44.0,true)
		draw_line(source,center,Color("#ffb06b",0.96*alpha),12.0,true)
	elif kind in ["galio_winds","galio_winds_pulse"]:
		var source := world_to_screen(Vector2(effect.get("source", effect.get("pos", Vector2.ZERO)))) + Vector2(0, -24)
		if elapsed < 0.52 and kind == "galio_winds":
			var travel := elapsed / 0.52
			var direction := (center - source).normalized()
			var perpendicular := direction.orthogonal()
			for side_sign in [-1.0, 1.0]:
				var curve := _galio_curve_points(source + perpendicular * 62.0 * float(side_sign), source.lerp(center, 0.5) + perpendicular * 150.0 * float(side_sign), center, travel)
				draw_polyline(curve, Color(violet, 0.78 * alpha), 12.0, true)
				draw_polyline(curve, Color(gold, 0.94 * alpha), 3.0, true)
		else:
			for spiral in 6:
				var phase := fposmod(elapsed+spiral/6.0,1.0)
				draw_arc(center,radii.x*(0.22+phase*0.72),clock*2.0+spiral,clock*2.0+spiral+PI*1.5,42,Color(violet,sin(phase*PI)*0.76*alpha),5.0,true)
	elif kind == "galio_durand":
		var expansion := minf(1.0, 0.14 + elapsed * 1.15)
		_kindred_ellipse(center,radii*expansion,gold,0.90*alpha,9.0,0.13*alpha)
		_kindred_ellipse(center,radii*maxf(0.08,expansion-0.18),violet,0.76*alpha,5.0)


func _draw_kindred_boss_warning(enemy: Dictionary) -> void:
	var move := str(enemy.get("special_move", ""))
	var points: Array = enemy.get("special_warning_positions", [])
	if points.is_empty():
		return
	var progress := 1.0 - clampf(float(enemy.get("special_warning", 0.0)) / maxf(0.01, float(enemy.get("special_warning_total", 1.0))), 0.0, 1.0)
	var pulse := 0.66 + sin(clock * 15.0) * 0.34
	var snap := pow(progress, 2.2)
	var radius := float(enemy.get("special_warning_radius", 110.0))
	var source := world_to_screen(Vector2(enemy.pos)) + Vector2(0, -28)
	var spirit := Color("#eaffff")
	var wolf := Color("#b878ff")
	if move == "kindred_hunt":
		for fan_index in 9:
			var angle := lerpf(-0.72, 0.72, float(fan_index) / 8.0)
			var finish := source + Vector2.LEFT.rotated(angle) * (690.0 + snap * 90.0)
			var side := Vector2.LEFT.rotated(angle).orthogonal() * (11.0 + progress * 10.0)
			draw_colored_polygon(PackedVector2Array([source, finish + side, finish - side]), Color(wolf, 0.025 + progress * 0.065))
			draw_dashed_line(source, finish, Color(spirit, (0.18 + progress * 0.62) * pulse), 2.0 + progress * 2.8, 12.0 - progress * 4.0, true)
			for chevron in 3:
				var chevron_pos := source.lerp(finish, 0.30 + float(chevron) * 0.20)
				var direction := (finish - source).normalized()
				var wing := direction.orthogonal() * 8.0
				draw_polyline(PackedVector2Array([chevron_pos-direction*12.0+wing,chevron_pos,chevron_pos-direction*12.0-wing]),Color(spirit,0.28+progress*0.52),2.2,true)
		for ring in 3:
			draw_arc(source, 38.0 + ring * 15.0 + snap * 18.0, -2.78, 2.78, 48, Color(wolf, (0.34 - ring * 0.07) * pulse), 3.0, true)
		return
	for index in points.size():
		var point: Vector2 = points[index]
		var center := world_to_screen(point) + Vector2(0, 8)
		var radii: Vector2 = sim.ability_area_screen_radii(point, radius)
		var color := wolf if move in ["kindred_wolf", "kindred_dread"] else spirit
		_kindred_ellipse(center, radii, color, (0.55 + progress * 0.42) * pulse, 4.0 + progress * 2.0, 0.055 + progress * 0.105)
		for ring in 3:
			var ring_scale := 1.34 - progress * 0.34 - float(ring) * 0.10
			_kindred_ellipse(center, radii * ring_scale, color, (0.16 + progress * 0.38) * (1.0-float(ring)*0.18), 2.0)
		for spoke in 8:
			var angle := float(spoke) * TAU / 8.0 + clock * (0.18 if spoke % 2 == 0 else -0.13)
			var inner := center + Vector2(cos(angle) * radii.x * 0.76, sin(angle) * radii.y * 0.76)
			var outer := center + Vector2(cos(angle) * radii.x * 1.02, sin(angle) * radii.y * 1.02)
			draw_line(inner, outer, Color(color, 0.34 + progress * 0.48), 3.0, true)
		if move == "kindred_dance":
			draw_dashed_line(source, center, Color(spirit, 0.42 + progress * 0.50), 3.2, 9.0, true)
			for arrow in 5:
				var offset := Vector2(-42.0 + arrow * 21.0, -radii.y * (0.88 - progress * 0.42))
				draw_line(center + offset, center + offset + Vector2(0, 34.0 + progress * 24.0), Color(spirit, 0.86), 3.2, true)
		elif move == "kindred_wolf":
			for claw in 6:
				var angle := clock * 0.90 + claw * TAU / 6.0
				var claw_pos := center + Vector2(cos(angle) * radii.x * 0.64, sin(angle) * radii.y * 0.62)
				for slash in 3:
					draw_arc(claw_pos+Vector2((slash-1)*6.0,0),16.0+progress*8.0,angle-1.2,angle+1.2,16,Color(wolf,0.68+progress*0.26),3.2,true)
		elif move == "kindred_dread":
			for mark in 3:
				var y := -58.0 + mark * 29.0
				var active := mark <= floori(progress * 3.0)
				draw_colored_polygon(PackedVector2Array([center+Vector2(-18,y),center+Vector2(0,y+17),center+Vector2(18,y)]),Color(wolf,(0.88 if active else 0.20)*pulse))
			draw_arc(center, radii.x*0.43, -2.75, -0.39, 32, Color(spirit,0.40+progress*0.48),4.0,true)


func _draw_kindred_projectile(projectile: Dictionary) -> void:
	var point := world_to_screen(Vector2(projectile.pos)) + Vector2(0, -20)
	var direction := Vector2.LEFT
	var target_id := int(projectile.get("target_id", -1))
	if sim != null and target_id >= 0 and target_id < sim.heroes.size():
		direction = (world_to_screen(Vector2(sim.heroes[target_id].pos)) - point).normalized()
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT
	var dread := str(projectile.get("kind", "")) == "kindred_dread_arrow"
	var phase := int(projectile.get("phase", 1))
	var color := Color("#c06cff") if dread else Color("#ecffff")
	var length := 54.0 if dread else (42.0 if phase >= 3 else 36.0)
	var tail := point - direction * length
	var side := direction.orthogonal()
	for trail in 3:
		var trail_offset := side * (float(trail)-1.0) * (5.0 if dread else 3.5)
		draw_line(tail-direction*float(trail)*9.0+trail_offset, point+direction*10.0, Color(color,0.30+float(2-trail)*0.20), 7.0-float(trail)*1.7, true)
	draw_line(tail, tail + side * 11.0 + direction * 13.0, Color(color, 0.96), 3.2, true)
	draw_line(tail, tail - side * 11.0 + direction * 13.0, Color(color, 0.96), 3.2, true)
	draw_colored_polygon(PackedVector2Array([point+direction*16.0,point-direction*4.0+side*9.0,point-direction*4.0-side*9.0]),Color(color,0.98))
	draw_circle(point, 20.0 if dread else 14.0, Color(color, 0.13))
	draw_arc(point, 16.0 if dread else 11.0, clock*4.0, clock*4.0+4.4, 20, Color(color,0.78),2.0,true)
	if dread:
		var stack := int(projectile.get("dread_stack",1))
		for mark in stack:
			draw_circle(tail-direction*(8.0+mark*9.0),3.5+mark,Color(color,0.72))


func _draw_kindred_hazard(hazard: Dictionary) -> void:
	var center_world := Vector2(hazard.pos)
	var center := world_to_screen(center_world) + Vector2(0, 8)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, float(hazard.get("radius", 240.0)))
	var total := maxf(0.1, float(hazard.get("total", 4.0)))
	var life_ratio := clampf(float(hazard.get("life", 0.0)) / total, 0.0, 1.0)
	var pulse := fposmod((1.0-life_ratio)*5.2, 1.0)
	_kindred_ellipse(center, radii, Color("#9f52ff"), 0.78*life_ratio, 5.0, 0.14*life_ratio)
	for ring in 4:
		var wave := fposmod(pulse+float(ring)*0.22,1.0)
		_kindred_ellipse(center,radii*(0.18+0.82*wave),Color("#e8d7ff"),sin(wave*PI)*0.72*life_ratio,2.8+float(ring)*0.4)
	for paw in 8:
		var angle := float(paw)*TAU/8.0-clock*0.52
		var paw_pos := center+Vector2(cos(angle)*radii.x*0.70,sin(angle)*radii.y*0.70)
		draw_circle(paw_pos,7.0,Color(0.74,0.34,1.0,0.62*life_ratio))
		for toe in 3:
			draw_circle(paw_pos+Vector2(-7.0+toe*7.0,-7.0),2.8,Color(0.94,0.86,1.0,0.76*life_ratio))
	var wolf_scale := 1.0+sin(clock*4.6)*0.08
	var wolf_head := PackedVector2Array([center+Vector2(-52,-20)*wolf_scale,center+Vector2(-34,-58)*wolf_scale,center+Vector2(-8,-38)*wolf_scale,center+Vector2(0,-50)*wolf_scale,center+Vector2(8,-38)*wolf_scale,center+Vector2(34,-58)*wolf_scale,center+Vector2(52,-20)*wolf_scale,center+Vector2(30,34)*wolf_scale,center+Vector2(0,55)*wolf_scale,center+Vector2(-30,34)*wolf_scale])
	draw_colored_polygon(wolf_head,Color(0.18,0.03,0.28,0.42*life_ratio))
	var wolf_outline := wolf_head.duplicate()
	wolf_outline.append(wolf_head[0])
	draw_polyline(wolf_outline,Color(0.76,0.47,1.0,0.70*life_ratio),3.0,true)
	draw_circle(center+Vector2(-17,-10),5.5,Color(0.92,0.84,1.0,0.92*life_ratio))
	draw_circle(center+Vector2(17,-10),5.5,Color(0.92,0.84,1.0,0.92*life_ratio))


func _draw_kindred_boss_effect(effect: Dictionary) -> void:
	var alpha := clampf(float(effect.get("life", 0.0)) / maxf(0.01, float(effect.get("total", 0.8))), 0.0, 1.0)
	var elapsed := 1.0-alpha
	var kind := str(effect.kind)
	var center_world := Vector2(effect.pos)
	var center := world_to_screen(center_world)+Vector2(0,8)
	if kind == "kindred_respite":
		var radius := float(effect.get("radius",285.0))
		var radii: Vector2 = sim.ability_area_screen_radii(center_world,radius)
		_kindred_ellipse(center,radii,Color("#f4ffff"),0.94,6.0,0.16)
		for ring in 6:
			var wave := fposmod(elapsed*3.6+float(ring)/6.0,1.0)
			_kindred_ellipse(center,radii*(0.18+wave*0.82),Color("#c59aff"),sin(wave*PI)*0.66,2.0+float(ring%2))
		for rune in 12:
			var angle := float(rune)*TAU/12.0+clock*0.12
			var rune_pos := center+Vector2(cos(angle)*radii.x*0.88,sin(angle)*radii.y*0.88)
			draw_circle(rune_pos,7.0+sin(clock*4.0+rune)*2.0,Color(0.92,1.0,1.0,0.72))
			draw_line(rune_pos,rune_pos+Vector2(0,-24.0),Color(0.82,0.64,1.0,0.46),3.0,true)
		draw_circle(center,34.0+sin(clock*3.6)*7.0,Color(0.90,1.0,1.0,0.30))
		draw_arc(center,52.0,-2.8,2.8,44,Color("#ffffff",0.9),5.0,true)
	elif kind == "kindred_respite_end":
		var radii: Vector2 = sim.ability_area_screen_radii(center_world,float(effect.get("radius",285.0)))
		for ring in 3:
			_kindred_ellipse(center,radii*(0.24+elapsed*(0.88+ring*0.12)),Color("#ffffff"),sin(elapsed*PI)*alpha*(1.0-ring*0.18),7.0-ring*1.5,0.055*alpha)
		for ray in 18:
			var angle := float(ray)*TAU/18.0
			draw_line(center+Vector2.from_angle(angle)*35.0,center+Vector2(cos(angle)*radii.x,sin(angle)*radii.y)*(0.55+elapsed*0.55),Color(0.90,0.78,1.0,alpha*0.70),3.0,true)
	elif kind == "kindred_protect":
		for ring in 3:
			draw_arc(center-Vector2(0,18),32.0+elapsed*(18.0+ring*8.0),0,TAU,40,Color("#efffff",alpha*(0.95-ring*0.20)),5.0-ring,true)
	elif kind == "kindred_dance":
		var volleys := int(effect.get("volleys",3))
		for point_value: Variant in effect.get("points",[]):
			var target := world_to_screen(Vector2(point_value))+Vector2(0,8)
			for trail in volleys:
				var offset := Vector2(0,(float(trail)-float(volleys-1)*0.5)*12.0)
				draw_line(center+offset,target+offset,Color(0.88,1.0,1.0,alpha*(0.32+trail*0.10)),3.0+float(trail%2),true)
				draw_circle(target+offset,8.0+elapsed*18.0,Color(0.88,1.0,1.0,alpha*0.12))
		for ribbon in 6:
			draw_arc(center,22.0+elapsed*78.0+ribbon*9.0,-3.0+ribbon*0.20,-0.1+ribbon*0.20,32,Color(0.86,1.0,1.0,alpha*(0.88-ribbon*0.10)),4.0-float(ribbon%2),true)
	elif kind == "kindred_wolf":
		var radii: Vector2 = sim.ability_area_screen_radii(center_world,float(effect.get("radius",275.0)))
		for ring in 4:
			_kindred_ellipse(center,radii*(0.18+elapsed*(0.82+ring*0.08)),Color("#ad62ff"),sin(elapsed*PI)*alpha*(0.96-ring*0.14),7.0-ring,0.12*alpha)
		for claw in 12:
			var angle := float(claw)*TAU/12.0
			var claw_pos := center+Vector2(cos(angle)*radii.x*elapsed,sin(angle)*radii.y*elapsed)
			draw_line(claw_pos-Vector2.from_angle(angle)*18.0,claw_pos+Vector2.from_angle(angle)*20.0,Color(0.88,0.74,1.0,alpha),4.0,true)
	elif kind == "kindred_wolf_strike":
		var radii: Vector2 = sim.ability_area_screen_radii(center_world,float(effect.get("radius",275.0)))
		_kindred_ellipse(center,radii*(0.42+elapsed*0.62),Color("#d9b7ff"),alpha*0.94,8.0,0.12*alpha)
		for slash in 9:
			var angle := float(slash)*TAU/9.0+clock*0.4
			var slash_center := center+Vector2(cos(angle)*radii.x*0.58,sin(angle)*radii.y*0.58)
			draw_line(slash_center-Vector2(16,24),slash_center+Vector2(16,24),Color(0.90,0.74,1.0,alpha),5.0,true)
	elif kind == "kindred_dread":
		var target := world_to_screen(Vector2(effect.get("target",effect.pos)))+Vector2(0,8)
		draw_colored_polygon(PackedVector2Array([center,target+Vector2(28,-18),target+Vector2(-28,18)]),Color(0.36,0.04,0.52,alpha*0.12))
		draw_dashed_line(center,target,Color("#c77cff",alpha*0.96),5.0,8.0,true)
		for mark in 3:
			draw_arc(target,30.0+mark*17.0+elapsed*22.0,-2.7,-0.45,32,Color("#ead7ff",alpha*(0.98-mark*0.15)),5.0-mark*0.7,true)
			var mark_y := -48.0+mark*30.0
			draw_colored_polygon(PackedVector2Array([target+Vector2(-17,mark_y),target+Vector2(0,mark_y+18),target+Vector2(17,mark_y)]),Color(0.78,0.40,1.0,alpha))
	elif kind == "kindred_hunt":
		var count := int(effect.get("count",18))
		for ring in 3:
			draw_arc(center,40.0+elapsed*(95.0+ring*38.0),-2.9,2.9,56,Color(0.84,0.59,1.0,alpha*(0.72-ring*0.16)),6.0-ring,true)
		for arrow in mini(count,32):
			var angle := lerpf(-0.90,0.90,float(arrow%11)/10.0)+sin(elapsed*PI+arrow)*0.035
			var start := center+Vector2.LEFT.rotated(angle)*(34.0+elapsed*110.0+float(arrow%3)*10.0)
			var finish := center+Vector2.LEFT.rotated(angle)*(220.0+elapsed*460.0)
			draw_line(start,finish,Color("#efffff",alpha*(0.52+float(arrow%3)*0.18)),3.0+float(arrow%2)*1.5,true)
			draw_line(finish,finish-Vector2.LEFT.rotated(angle)*22.0+Vector2.LEFT.rotated(angle).orthogonal()*9.0,Color("#c883ff",alpha),3.0,true)
			draw_line(finish,finish-Vector2.LEFT.rotated(angle)*22.0-Vector2.LEFT.rotated(angle).orthogonal()*9.0,Color("#c883ff",alpha),3.0,true)
	elif kind == "kindred_arrow_hit":
		var color := Color("#c16cff") if bool(effect.get("dread",false)) else Color("#efffff")
		for ring in 2:
			draw_arc(center,12.0+elapsed*(42.0+ring*20.0),0,TAU,32,Color(color,alpha*(0.92-ring*0.24)),5.0-ring,true)
		for shard in 14:
			var angle := float(shard)*TAU/14.0
			draw_line(center+Vector2.from_angle(angle)*elapsed*10.0,center+Vector2.from_angle(angle)*(20.0+elapsed*54.0),Color(color,alpha),4.0 if shard%2==0 else 2.5,true)


func _slime_element_color(element: String) -> Color:
	return {"pyro":Color("#ff624c"),"hydro":Color("#42cfff"),"electro":Color("#b970ff"),"cryo":Color("#a9efff"),"anemo":Color("#67efc4")}.get(element, Color("#ff7dc8"))


func _slime_ellipse(center: Vector2, radii: Vector2, color: Color, alpha: float, width: float = 3.0) -> void:
	var points := PackedVector2Array()
	for index in 48:
		var angle := float(index) * TAU / 48.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	points.append(points[0])
	draw_polyline(points, Color(color, alpha), width, true)


func _draw_slime_boss_warning(enemy: Dictionary) -> void:
	var move := str(enemy.get("special_move", ""))
	var points: Array = enemy.get("special_warning_positions", [])
	if points.is_empty():
		return
	var progress := 1.0 - clampf(float(enemy.get("special_warning", 0.0)) / maxf(0.01, float(enemy.get("special_warning_total", 1.0))), 0.0, 1.0)
	var pulse := 0.72 + 0.28 * sin(clock * 12.0)
	var radius := float(enemy.get("special_warning_radius", 100.0))
	var source := world_to_screen(Vector2(enemy.pos)) + Vector2(0, -22)
	var phase := int(enemy.get("boss_phase", 1))
	if move == "slime_reflux":
		var radii: Vector2 = sim.ability_area_screen_radii(Vector2(enemy.pos), radius)
		for ring in 5:
			var scale := fposmod(progress * 1.4 + float(ring) / 5.0, 1.0)
			_slime_ellipse(world_to_screen(Vector2(enemy.pos)) + Vector2(0, 8), radii * (1.0 - scale * 0.72), Color("#ff77cf"), (0.22 + scale * 0.56) * pulse, 2.0 + progress * 2.0)
		for spoke in 12:
			var angle := float(spoke) * TAU / 12.0 + clock * 0.35
			var edge := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			draw_line(world_to_screen(Vector2(enemy.pos)) + edge, world_to_screen(Vector2(enemy.pos)) + edge * 0.30, Color(0.35,0.95,0.90,0.18+progress*0.34), 2.0, true)
		return
	for index in points.size():
		var point: Vector2 = points[index]
		var screen := world_to_screen(point) + Vector2(0, 8)
		var radii: Vector2 = sim.ability_area_screen_radii(point, radius)
		var element_color := _slime_element_color(["pyro","hydro","electro","cryo","anemo"][index % 5])
		_slime_ellipse(screen, radii * (0.88 + progress * 0.12), element_color, (0.42 + progress * 0.5) * pulse, 3.0)
		if move == "slime_bounce":
			var control := (source + screen) * 0.5 + Vector2(0, -115.0 - index * 7.0)
			var arc := PackedVector2Array()
			for step in 17:
				var t := float(step) / 16.0
				arc.append(source * (1.0-t)*(1.0-t) + control * 2.0*(1.0-t)*t + screen*t*t)
			draw_polyline(arc, Color(element_color, 0.28 + progress * 0.48), 3.0, true)
			for tooth in 3:
				var x := -18.0 + tooth * 18.0
				draw_colored_polygon(PackedVector2Array([screen+Vector2(x-7,2),screen+Vector2(x,-12-progress*10),screen+Vector2(x+7,2)]),Color(element_color,0.38+progress*0.44))
		elif move == "slime_burst":
			draw_circle(screen, 7.0 + 5.0 * pulse, Color(element_color, 0.66))
			draw_dashed_line(source, screen, Color(element_color, 0.26 + progress * 0.36), 1.5, 10.0, true)
		elif move == "slime_court":
			var orbit_angle := clock * (2.2 if phase >= 2 else 1.6) + float(index) * TAU / float(points.size())
			var court_pos := source + Vector2(cos(orbit_angle) * 72.0, sin(orbit_angle) * 30.0)
			draw_circle(court_pos, 10.0, Color(element_color, 0.76))
			draw_circle(court_pos+Vector2(-3,-2), 2.5, Color.WHITE)
			draw_dashed_line(court_pos, screen, Color(element_color, 0.24 + progress * 0.42), 2.0, 12.0, true)


func _draw_slime_projectile(projectile: Dictionary) -> void:
	var point := world_to_screen(Vector2(projectile.pos)) + Vector2(0, -18)
	var color := _slime_element_color(str(projectile.get("element", "hydro")))
	var court := str(projectile.get("kind", "")) == "slime_image"
	var size := (16.0 if court else 11.0) * world_depth_scale(Vector2(projectile.pos))
	draw_circle(point, size + 8.0, Color(color, 0.16))
	draw_circle(point, size, Color(color, 0.90))
	draw_circle(point + Vector2(-size*0.30,-size*0.22), size*0.27, Color(1,1,1,0.86))
	if court:
		for tooth in 3:
			var x := -size * 0.62 + float(tooth) * size * 0.62
			draw_colored_polygon(PackedVector2Array([point+Vector2(x-4,-size*0.72),point+Vector2(x,-size*1.25),point+Vector2(x+4,-size*0.72)]),Color(color,0.92))


func _draw_slime_hazard(hazard: Dictionary) -> void:
	var kind := str(hazard.get("kind", ""))
	var center := world_to_screen(Vector2(hazard.pos)) + Vector2(0, 8)
	var radii: Vector2 = sim.ability_area_screen_radii(Vector2(hazard.pos), float(hazard.get("radius", 90.0)))
	var phase := fposmod(clock * 0.52 + float(Vector2(hazard.pos).x) * 0.001, 1.0)
	if kind == "slime_pool":
		var color := _slime_element_color(str(hazard.get("element", "hydro")))
		var life_alpha := clampf(float(hazard.get("life", 0.0)) / 0.45, 0.0, 1.0)
		var polygon := PackedVector2Array()
		for index in 40:
			var angle := float(index) * TAU / 40.0
			var wobble := 0.92 + sin(angle*5.0+clock*4.0)*0.06
			polygon.append(center + Vector2(cos(angle)*radii.x*wobble,sin(angle)*radii.y*wobble))
		draw_colored_polygon(polygon, Color(color, 0.12 * life_alpha))
		polygon.append(polygon[0])
		draw_polyline(polygon, Color(color, 0.58 * life_alpha), 2.4, true)
		for bubble in 5:
			var angle := float(bubble) * TAU / 5.0 + clock * 0.5
			var bubble_pos := center + Vector2(cos(angle)*radii.x*0.55,sin(angle)*radii.y*0.48)
			draw_circle(bubble_pos, 3.0 + sin(clock*4.0+bubble)*1.2, Color(color,0.52*life_alpha))
	elif kind in ["slime_bounce_impact", "slime_court_final"] and float(hazard.get("delay", 0.0)) <= 0.0:
		_slime_ellipse(center, radii * (0.65 + phase * 0.35), Color("#ff73c7"), 0.38, 3.0)


func _draw_slime_boss_effect(effect: Dictionary) -> void:
	var alpha := clampf(float(effect.get("life", 0.0)) / maxf(0.01, float(effect.get("total", 0.7))), 0.0, 1.0)
	var elapsed := 1.0 - alpha
	var kind := str(effect.kind)
	var center := world_to_screen(Vector2(effect.pos)) + Vector2(0, 8)
	var phase := int(effect.get("phase", 1))
	if kind == "slime_attack":
		var target := world_to_screen(Vector2(effect.get("target", effect.pos))) + Vector2(0, -18)
		var control := (center + target) * 0.5 + Vector2(0, -55)
		var arc := PackedVector2Array()
		for step in 18:
			var t := float(step) / 17.0
			arc.append(center * (1.0-t)*(1.0-t) + control * 2.0*(1.0-t)*t + target*t*t)
		draw_polyline(arc, Color(0.45, 1.0, 0.82, alpha), 9.0 * sin(elapsed * PI) + 2.0, true)
		draw_circle(target, 10.0 + elapsed * 24.0, Color(1.0, 0.35, 0.72, alpha * 0.35))
		_slime_ellipse(target, Vector2(42, 19) * (0.35 + elapsed), Color("#ff70c5"), sin(elapsed * PI) * 0.92, 4.0)
	elif kind in ["slime_bounce", "slime_burst", "slime_court"]:
		var launch_color := Color("#ff75c9") if phase >= 2 else Color("#5de3db")
		for ring in 3:
			draw_arc(center, 30.0 + elapsed*65.0 + ring*12.0, clock+ring*1.1, clock+ring*1.1+PI*1.35, 32, Color(launch_color,alpha*(0.52-ring*0.10)), 3.0, true)
	if kind == "slime_reflux":
		var radii: Vector2 = sim.ability_area_screen_radii(Vector2(effect.pos), float(effect.get("radius", 300.0)))
		for ring in 7:
			var wave := clampf(elapsed * 1.5 - float(ring)*0.10, 0.0, 1.0)
			_slime_ellipse(center, radii*(1.0-wave*0.82), Color("#ff64c3"), sin(wave*PI)*0.82, 3.2)
		draw_circle(center, 18.0 + elapsed*32.0, Color(0.35,0.95,0.86,alpha*0.34))
	elif kind in ["slime_bounce_hit", "slime_court_final"]:
		var radii: Vector2 = sim.ability_area_screen_radii(Vector2(effect.pos), float(effect.get("radius", 110.0)))
		_slime_ellipse(center, radii*(0.35+elapsed*0.78), Color("#ff5dbf"), sin(elapsed*PI)*0.95, 5.0)
		for shard in 12:
			var angle := float(shard)*TAU/12.0
			var start := center+Vector2(cos(angle)*radii.x*elapsed*0.35,sin(angle)*radii.y*elapsed*0.35)
			var finish := center+Vector2(cos(angle)*radii.x*elapsed,sin(angle)*radii.y*elapsed)
			draw_line(start,finish,Color(0.98,0.75,0.30,alpha),3.0,true)
	elif kind in ["slime_glob_hit", "slime_court_hit"]:
		var color := _slime_element_color(str(effect.get("element", "hydro")))
		var radii: Vector2 = sim.ability_area_screen_radii(Vector2(effect.pos), float(effect.get("radius", 90.0)))
		_slime_ellipse(center,radii*(0.32+elapsed*0.72),color,sin(elapsed*PI)*0.92,4.0)
		for drop in 8:
			var angle := float(drop)*TAU/8.0+clock*0.15
			var drop_pos := center+Vector2(cos(angle)*radii.x*elapsed,sin(angle)*radii.y*elapsed)
			draw_circle(drop_pos,4.0+3.0*alpha,Color(color,alpha*0.78))


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
	if boss:
		caption(center + Vector2(-11, -ring_radius - 35.0), "⚠", Color("#ffcf42"), 22)
		if not title.is_empty():
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
		var orbital_fade := smoothstep(0.0, 0.85, maxf(0.0, float(orbital.get("life", 0.0))))
		for i in count:
			var angle := clock*2.8+i*TAU/count
			var point := center+Vector2(cos(angle)*radius,sin(angle)*radius*0.36)
			var color := element_color(str(orbital.get("element","")))
			if visual == "blade":
				_draw_vertical_orbit_blade(point, color, angle, orbital_fade)
			elif visual == "salon":
				_draw_furina_salon_companion(point, i, orbital_fade)
			else:
				var direction := Vector2.from_angle(angle+PI*0.5)
				draw_line(point-direction*12.0,point+direction*12.0,Color(color,orbital_fade),4.0,true)
				draw_circle(point,3.0,Color(1.0,1.0,1.0,orbital_fade))

func _draw_vertical_orbit_blade(point: Vector2, color: Color, orbit_angle: float, fade: float = 1.0) -> void:
	var pulse := 1.0 + sin(clock*5.0+orbit_angle)*0.06
	var tip := point+Vector2(0,-18.0*pulse)
	var shoulder_left := point+Vector2(-5.0,-7.0)
	var shoulder_right := point+Vector2(5.0,-7.0)
	var base := point+Vector2(0,9.0)
	draw_colored_polygon(PackedVector2Array([tip,shoulder_right,base,shoulder_left]),Color(color,0.92*fade))
	draw_polyline(PackedVector2Array([tip,shoulder_right,base,shoulder_left,tip]),Color(1.0,1.0,1.0,fade),1.4,true)
	draw_line(point+Vector2(-7,9),point+Vector2(7,9),Color(Color("#ffe9bd"),fade),3.0,true)
	draw_line(point+Vector2(0,9),point+Vector2(0,16),Color(Color("#7d593e"),fade),3.2,true)
	draw_circle(point,22.0,Color(color,0.055*fade))

func _draw_deploy_preview() -> void:
	var point := world_to_screen(deploy_preview_point)
	var allowed: bool = deploy_preview_valid
	var color := Color("#69f0c2") if allowed else Color("#ff5267")
	draw_circle(point,34.0,Color(color,0.16))
	draw_arc(point,34.0,0,TAU,48,color,3.0,true)
	draw_line(point-Vector2(18,0),point+Vector2(18,0),color,2.0,true)
	draw_line(point-Vector2(0,18),point+Vector2(0,18),color,2.0,true)
	caption(point+Vector2(-50,-54),"松开放置角色" if allowed else "不可部署",color,13)

func _ability_ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 49:
		var angle := float(index) * TAU / 48.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _draw_skill_area_ellipse(center_world: Vector2, radius: float, color: Color, strength: float = 1.0, spread: float = 1.0) -> void:
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius) * spread
	var points := _ability_ellipse_points(center, radii)
	var fill := points.duplicate()
	fill.resize(48)
	draw_colored_polygon(fill, Color(color, 0.085 * strength))
	draw_polyline(points, Color(color, 0.76 * strength), 2.3, true)
	for segment in 12:
		var start := float(segment) * TAU / 12.0 + 0.03
		var band := PackedVector2Array()
		for step in 5:
			var angle := start + float(step) * 0.092
			band.append(center + Vector2(cos(angle) * radii.x * 0.89, sin(angle) * radii.y * 0.89))
		draw_polyline(band, Color(color.lightened(0.29), 0.37 * strength), 1.3, true)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var edge := center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var tangent := Vector2(-sin(angle), cos(angle) * radii.y / maxf(1.0, radii.x)).normalized()
		draw_line(edge - tangent * 4.0, edge + tangent * 4.0, Color(color.lightened(0.28), 0.74 * strength), 1.7, true)

func _draw_skill_preview() -> void:
	if selected_id < 0 or selected_id >= sim.heroes.size():
		return
	var hero: Dictionary = sim.heroes[selected_id]
	var color: Color = element_color(str(hero.get("element", "none")))
	var ability: Dictionary = hero.get("ultimate", {}) if skill_preview_ultimate else hero.get("active_skill", {})
	var radius: float = float(ability.get("radius", 170.0)) * (1.0 + sim.skill_area_bonus)
	if str(hero.get("character_id", "")) == "traveler" and not skill_preview_ultimate:
		radius = sim.traveler_skill_radius() * (1.0 + sim.skill_area_bonus)
	var ability_kind := str(ability.get("kind", ""))
	if ability_kind == "wind_cut":
		_draw_fengjin_row_lanes(Vector2(hero.pos), color, 0.76)
		return
	if Sim.GLOBAL_TEAM_ABILITY_KINDS.has(ability_kind):
		caption(world_to_screen(Vector2(hero.pos)) + Vector2(-58.0, -72.0), "全队增益 · 无距离限制", color, 15)
		return
	var self_area: bool = Sim.SELF_CENTERED_ABILITY_KINDS.has(ability_kind)
	var center_world: Vector2 = Vector2(hero.pos) if self_area else skill_point
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	_draw_skill_area_ellipse(center_world, radius, color, 1.18 if skill_preview_ultimate else 0.94)
	if not self_area:
		draw_dashed_line(world_to_screen(hero.pos), center, Color(color, 0.45), 1.3, 10.0, true)
	var title: String = sim.hero_ultimate_name(selected_id) if skill_preview_ultimate else sim.hero_skill_name(selected_id)
	var key_hint := "E · 终结技范围" if skill_preview_ultimate else "Q · 战技范围"
	caption(center + Vector2(-70, -radii.y - 32), key_hint, Color.WHITE, 12)
	caption(center + Vector2(-70, -radii.y - 14), title, color, 15)

func _skill_zone_radius(zone: Dictionary) -> float:
	if zone.kind in ["renewing_breeze", "needle_barrage", "columbia_tide_ring"]:
		return float(zone.get("area", 170.0))
	var base_radius := float({"anemo_tornado":135.0, "hydro_field":250.0, "cryo_field":225.0, "burning_ground":105.0, "anemo_domain":180.0, "gate_field":180.0, "storm_field":190.0, "frozen_forest":210.0}.get(str(zone.kind), 160.0))
	return base_radius * float(zone.get("area", 1.0))

func _draw_skill_zone(zone: Dictionary) -> void:
	var center_world := Vector2(zone.pos)
	if str(zone.get("visual", "")) == "columbia_tide_ring":
		var owner_id := int(zone.get("hero_id", -1))
		if owner_id >= 0 and owner_id < sim.heroes.size():
			center_world = Vector2(sim.heroes[owner_id].pos)
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radius := _skill_zone_radius(zone)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	var pulse := sin(clock * 4.8) * 0.018
	var zone_color: Color = {
		"anemo_tornado": Color("#6fe5be"), "anemo_domain": Color("#6fe5be"), "renewing_breeze": Color("#8ce5b0"),
		"hydro_field": Color("#69c5fa"), "storm_field": Color("#6aa8ef"), "cryo_field": Color("#b6eefa"),
		"frozen_forest": Color("#d4efff"), "burning_ground": Color("#ef8d63"),
		"gate_field": Color("#b6a8fa"), "needle_barrage": Color("#d9c0f0"), "columbia_tide_ring": Color("#4bcaf0")
	}.get(str(zone.kind), Color("#9adace"))
	var zone_fade := smoothstep(0.0, 1.0, maxf(0.0, float(zone.get("life", 0.0))))
	if str(zone.get("visual", "")) in ["columbia_blessing", "traveler_hydro", "traveler_cryo"]:
		_draw_dedicated_zone(zone, center, radii)
		return
	if str(zone.get("visual", "")) != "gwen_needles":
		_draw_skill_area_ellipse(center_world, radius, zone_color, 0.70 * zone_fade, 1.0 + pulse)
	if str(zone.get("visual", "")) in ["sylphie_domain", "saki_score_q", "saki_score_e", "emilia_forest", "roxy_storm", "fengjin_breeze", "gwen_needles", "maiden_forest", "furina_fanfare", "columbia_tide_ring"]:
		_draw_dedicated_zone(zone, center, radii)
		return
	if zone.kind == "anemo_tornado":
		var total_life := maxf(0.1, float(zone.get("total_life", 4.2)))
		var remaining := maxf(0.0, float(zone.get("life", 0.0)))
		var tail_time := 19.0 / 24.0
		var frame := 0
		if remaining <= tail_time:
			frame = clampi(80 + floori((tail_time - remaining) * 24.0), 80, 98)
		else:
			frame = posmod(floori((total_life - remaining) * 24.0), 80)
		var size := 248.0 * clampf(world_depth_scale(zone.pos), 0.8, 1.25)
		_draw_video_atlas_frame(WIND_TORNADO_ATLAS, 10, 256, frame, Rect2(center + Vector2(-size * 0.5, -size * 0.91), Vector2.ONE * size), Color(1.0, 1.0, 1.0, zone_fade))
	elif zone.kind in ["anemo_domain", "renewing_breeze", "storm_field", "hydro_field", "gate_field"]:
		for ribbon in 3:
			var trail := PackedVector2Array()
			var offset_y := (float(ribbon) - 1.0) * radii.y * 0.36
			for index in 15:
				var phase := float(index) / 14.0
				var x := lerpf(-radii.x * 0.76, radii.x * 0.76, phase)
				var y := offset_y + sin(phase * TAU + clock * 1.8 + ribbon) * radii.y * 0.09
				trail.append(center + Vector2(x, y))
			draw_polyline(trail, Color(zone_color.lightened(0.28), 0.24 * zone_fade), 1.6, true)
	elif zone.kind in ["cryo_field", "frozen_forest", "needle_barrage", "burning_ground"]:
		for shard in 8:
			var angle := float(shard) * TAU / 8.0 + clock * 0.16
			var direction := Vector2(cos(angle) * radii.x * 0.60, sin(angle) * radii.y * 0.60)
			draw_line(center + direction * 0.66, center + direction, Color(zone_color.lightened(0.2), 0.42 * zone_fade), 2.0, true)

func _draw_video_atlas_frame(texture: Texture2D, columns: int, cell: int, frame: int, destination: Rect2, tint: Color = Color.WHITE) -> void:
	var source := Rect2(Vector2(frame % columns, frame / columns) * cell, Vector2.ONE * cell)
	draw_texture_rect_region(texture, destination, source, tint)

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
		caption(Vector2(high_rect.position.x + 10, high_rect.end.y + 12), "高台 · 射程×2", Color("#f3f1c8"), 8)
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
		caption(Vector2(low_rect.position.x + 12, low_rect.get_center().y), "沼泽减速 70%", Color("#e4dfae"), 9)
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

func _draw_effect_tiles(texture: Texture2D, feature: Dictionary, buff_tile: bool = false) -> void:
	var source_size := Vector2(texture.get_size())
	for cell: Rect2 in _terrain_cells(feature):
		var screen_cell := _terrain_screen_rect(cell)
		var active := buff_tile and _terrain_tile_active(cell)
		var pulse := 0.5 + 0.5 * sin(clock * 5.2)
		var fit_scale := minf(screen_cell.size.x * 0.84 / maxf(1.0, source_size.x), screen_cell.size.y * 0.86 / maxf(1.0, source_size.y))
		var draw_size := source_size * fit_scale * (1.08 + pulse * 0.12 if active else 1.0)
		var draw_rect := Rect2(screen_cell.get_center() - draw_size * 0.5, draw_size)
		if active:
			var glow_radius := minf(screen_cell.size.x, screen_cell.size.y) * (0.36 + pulse * 0.08)
			draw_circle(screen_cell.get_center(), glow_radius, Color(0.92, 0.08, 0.15, 0.16 + pulse * 0.14))
			draw_arc(screen_cell.get_center(), glow_radius * 0.88, 0.0, TAU, 32, Color(1.0, 0.23, 0.28, 0.35 + pulse * 0.36), 2.5, true)
		draw_texture_rect(texture, draw_rect, false, Color("#ff5966") if active else Color.WHITE)

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
			_draw_effect_tiles(TILE_HIGH_GROUND, feature, true)
		elif kind == "low_ground":
			_draw_effect_tiles(TILE_LOW_GROUND, feature)
		elif kind == "trap":
			_draw_effect_tiles(TILE_HAZARD, feature)
		elif kind == "attack_ground":
			_draw_effect_tiles(TILE_ATTACK_GROUND, feature, true)
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
	if not str(enemy.kind).begins_with("boss_"):
		var ratio: float = clampf(float(enemy.hp) / float(enemy.max_hp), 0, 1)
		draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44, 4)), Color("#302b32"))
		draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 2), Vector2(44 * ratio, 4)), RED)
		if float(enemy.get("max_shield", 0.0)) > 0.0 and float(enemy.get("shield", 0.0)) > 0.0:
			var shield_ratio: float = float(enemy.shield) / float(enemy.max_shield)
			draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 8), Vector2(44, 3)), Color("#24394e"))
			draw_rect(Rect2(enemy.pos + Vector2(-22, -side - 8), Vector2(44 * shield_ratio, 3)), Color("#66c8ff"))
			draw_arc(enemy.pos + Vector2(0, -20 + bob), side * 0.48, -2.7, 0.35, 22, Color(0.45, 0.82, 1.0, 0.72), 2.5, true)
	if sim.endless_mode and int(enemy.get("level", 0)) > 0:
		caption(enemy.pos + Vector2(-21, -side - 13), "Lv.%d" % int(enemy.level), Color("#f2c7ad"), 9)
	if enemy.kind == "buffer":
		draw_arc(enemy.pos + Vector2(0, -20), 30.0 + sin(clock * 2.0) * 3.0, 0, TAU, 32, Color(0.85, 0.42, 0.95, 0.5), 2.0, true)
		caption(enemy.pos + Vector2(-7, 27), "增", Color("#cf7fda"), 12)
	elif enemy.kind == "shielded":
		caption(enemy.pos + Vector2(-7, 27), "盾", Color("#76a6d8"), 12)
	elif str(enemy.kind).begins_with("boss_"):
		var style := str(enemy.get("boss_style", "commander"))
		var phase := int(enemy.get("boss_phase", 1))
		var pulse := sin(clock * (2.2 + phase * 0.35))
		var boss_color: Color = {"rift": Color("#a36bff"), "commander": Color("#ff6686"), "brood": Color("#df61bd"), "kindred": Color("#dffcff"), "storm": Color("#66d9ff"), "bulwark": Color("#e3bd62"), "artillery": Color("#ff8456"), "chronophage": Color("#9b7cff"), "galio": Color("#d6b1ff")}.get(style, Color("#ff6686"))
		if str(enemy.kind) not in ["boss_01", "boss_02", "boss_03"]:
			draw_arc(body, 48.0 + pulse * 3.0 + phase * 2.0, 0, TAU, 36, Color(boss_color, 0.82), 3.0 + phase * 0.7, true)
			for phase_mark in phase:
				var mark_angle := -PI * 0.5 + phase_mark * TAU / maxf(1.0, phase)
				draw_circle(body + Vector2.from_angle(mark_angle) * 55.0, 4.0, boss_color)
		match style:
			"rift":
				pass
			"brood":
				if str(enemy.kind) != "boss_02":
					for sac in 3:
						draw_circle(body + Vector2(-25 + sac * 25, 20 + sin(clock * 3.0 + sac) * 4.0), 13.0, Color(boss_color, 0.58))
			"galio":
				var wing_span := 74.0 + pulse * 4.0
				draw_colored_polygon(PackedVector2Array([body+Vector2(-12,-42),body+Vector2(-wing_span,-68),body+Vector2(-54,-8),body+Vector2(-86,22),body+Vector2(-20,28)]),Color(boss_color,0.72))
				draw_colored_polygon(PackedVector2Array([body+Vector2(12,-42),body+Vector2(wing_span,-68),body+Vector2(54,-8),body+Vector2(86,22),body+Vector2(20,28)]),Color(boss_color,0.72))
				draw_circle(body+Vector2(0,-22),30.0,Color("#32214d"))
				draw_arc(body+Vector2(0,-22),31.0,-2.85,-0.29,34,Color("#f5d976"),6.0,true)
				draw_line(body+Vector2(-22,9),body+Vector2(-42,43),Color("#e6c36d"),10.0,true)
				draw_line(body+Vector2(22,9),body+Vector2(42,43),Color("#e6c36d"),10.0,true)
			"kindred":
				var bow_center := body + Vector2(-8.0, -10.0)
				draw_arc(bow_center, 47.0 + pulse * 2.0, -1.24, 1.24, 32, Color("#f0ffff"), 5.0, true)
				draw_line(bow_center + Vector2(15,-44), bow_center + Vector2(15,44), Color("#adc8dc"), 2.0, true)
				draw_line(bow_center + Vector2(-34,0), bow_center + Vector2(54,0), Color("#f5ffff"), 3.0, true)
				var wolf_pos := body + Vector2(cos(clock*1.4)*52.0, -30.0 + sin(clock*1.4)*18.0)
				draw_circle(wolf_pos, 18.0, Color(0.47,0.28,0.72,0.28))
				draw_colored_polygon(PackedVector2Array([wolf_pos+Vector2(-18,8),wolf_pos+Vector2(-8,-18),wolf_pos,wolf_pos+Vector2(10,-16),wolf_pos+Vector2(20,8),wolf_pos+Vector2(0,16)]),Color(0.70,0.54,0.94,0.55))
				draw_circle(wolf_pos+Vector2(-6,-2),2.5,Color("#f4ffff"))
				draw_circle(wolf_pos+Vector2(6,-2),2.5,Color("#f4ffff"))
				if bool(enemy.get("kindred_respite_active", false)):
					var respite_center := Vector2(enemy.get("kindred_respite_center", enemy.pos))
					_kindred_ellipse(world_to_screen(respite_center)+Vector2(0,8), sim.ability_area_screen_radii(respite_center,float(enemy.get("kindred_respite_radius",285.0))), Color("#f2ffff"),0.82,4.0,0.08)
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
		var boss_name: String = {"rift": "裂隙统领", "commander": "统领", "brood": "史莱姆王", "kindred": "永猎双子", "storm": "风暴", "bulwark": "壁垒", "artillery": "炮台", "chronophage": "噬时", "galio": "正义巨像"}.get(style, "统领")
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
	if enemy_id == "boss_01" and bool(enemy.get("special_pending", false)):
		state = _rift_boss_sequence_state(str(enemy.get("special_move", "")))
	var frame := 0
	if enemy_id == "boss_01" and bool(enemy.get("special_pending", false)):
		frame = enemy_sequences.frame_at_time(enemy_id, state, maxf(0.0, float(enemy.get("special_warning_total", 0.0)) - float(enemy.get("special_warning", 0.0))))
	elif enemy_id == "boss_01" and bool(enemy.get("attack_pending", false)):
		frame = enemy_sequences.frame_at_time(enemy_id, state, 47.0 / 24.0 - float(enemy.get("warning_timer", 0.0)))
	elif state == "attack" and not bool(enemy.get("attack_pending", false)) and not bool(enemy.get("special_pending", false)):
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

func _rift_boss_sequence_state(move: String) -> String:
	return {"rift_laser":"skill1", "rift_orbs":"skill4", "rift_overhead":"skill3", "rift_storm":"skill2"}.get(move, "attack")

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

func _draw_falling_fireball(effect: Dictionary) -> void:
	var fall_total := maxf(0.1, float(effect.get("total", 0.72)))
	var progress := clampf(1.0 - float(effect.life) / fall_total, 0.0, 1.0)
	# The sprite itself points 45 degrees down-right; its flight path uses the same angle.
	var offset := Vector2(-260.0, -300.0).lerp(Vector2(0.0, -40.0), progress * progress)
	var depth := world_depth_scale(effect.pos)
	var point := world_to_screen(effect.pos) + offset * depth
	var size := lerpf(55.0, 92.0, progress)
	var flight_direction := Vector2(1.0, 1.0).normalized()
	draw_set_transform(point, 0.0, Vector2.ONE * depth)
	draw_line(-flight_direction * (size * 0.7), -flight_direction * (size * 0.26), Color(1.0, 0.38, 0.08, 0.56), 9.0, true)
	_draw_video_atlas_frame(FIREBALL_FLIGHT_ATLAS, 6, 128, posmod(floori(progress * fall_total * 24.0), 18), Rect2(Vector2.ONE * -size * 0.5, Vector2.ONE * size))
	draw_set_transform(Vector2.ZERO)

func _red_moon_ellipse_points(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in 64:
		var angle := float(index) * TAU / 64.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points

func _draw_red_moon_ellipse(center: Vector2, radii: Vector2, alpha: float, fill_alpha: float, width: float) -> void:
	var points := _red_moon_ellipse_points(center, radii)
	draw_colored_polygon(points, Color(0.42, 0.012, 0.055, fill_alpha))
	points.append(points[0])
	draw_polyline(points, Color(1.0, 0.17, 0.22, alpha), width, true)
	for segment in 16:
		var start_angle := float(segment) * TAU / 16.0 + 0.035
		var arc_points := PackedVector2Array()
		for step in 5:
			var angle := start_angle + float(step) * TAU / 16.0 * 0.115
			arc_points.append(center + Vector2(cos(angle) * radii.x * 0.91, sin(angle) * radii.y * 0.91))
		draw_polyline(arc_points, Color(1.0, 0.55, 0.45, alpha * 0.46), maxf(1.0, width * 0.38), true)

func _draw_red_moon_disc(center: Vector2, radius: float, alpha: float, phase: float) -> void:
	if alpha <= 0.0:
		return
	draw_circle(center, radius * 1.55, Color(0.75, 0.015, 0.07, alpha * 0.20))
	draw_circle(center, radius, Color(0.98, 0.07, 0.12, alpha * 0.94))
	draw_circle(center + Vector2(radius * 0.36, -radius * 0.16), radius * 0.81, Color(0.08, 0.025, 0.08, alpha * 0.98))
	draw_arc(center, radius, -PI * 0.76 + phase * 0.22, PI * 0.58 + phase * 0.22, 36, Color(1.0, 0.72, 0.60, alpha * 0.92), 3.0, true)
	if not reduced_effects:
		draw_arc(center, radius * 1.35, phase * 1.1, phase * 1.1 + PI * 0.62, 22, Color(1.0, 0.29, 0.30, alpha * 0.56), 1.5, true)

func _draw_red_moon_warning() -> void:
	if not sim.supports.has("support_barrage"):
		return
	var support: Dictionary = sim.supports["support_barrage"]
	var time_left := float(support.get("timer", 99.0))
	if time_left <= 0.0 or time_left > RED_MOON_WARNING_SECONDS:
		return
	var target: Dictionary = {}
	for enemy: Dictionary in sim.enemies:
		if enemy.hp <= 0.0:
			continue
		if target.is_empty() or enemy.hp > float(target.hp):
			target = enemy
	if target.is_empty() and not support.has("target_point"):
		return
	var world_point := Vector2(support.get("target_point", target.get("pos", Vector2.ZERO)))
	if not _render_point_visible(world_point, 150.0):
		return
	var point := world_to_screen(world_point) + Vector2(0, 8)
	var radii: Vector2 = sim.support_barrage_screen_radii(world_point, float(support.get("radius", 105.0)))
	var progress := 1.0 - time_left / RED_MOON_WARNING_SECONDS
	var pulse := 0.80 + 0.20 * sin(clock * 17.0)
	_draw_red_moon_ellipse(point, radii, 0.40 + progress * 0.50, 0.09 + progress * 0.11, 2.0 + progress * 0.7)
	_draw_red_moon_ellipse(point, radii * (0.85 - progress * 0.40), 0.16 + progress * 0.28 * pulse, 0.0, 1.3)
	for mark in 12:
		var angle := float(mark) * TAU / 12.0
		var edge := point + Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var direction := Vector2(cos(angle), sin(angle) * 0.40).normalized()
		draw_line(edge + direction * 2.0, edge + direction * (13.0 if mark % 3 == 0 else 7.0), Color(1.0, 0.38, 0.40, 0.50 + progress * 0.38), 2.0, true)
	var moon_alpha := smoothstep(0.05, 0.65, progress)
	var moon_size := 27.0 * world_depth_scale(world_point) * lerpf(0.64, 1.0, progress)
	var moon_point := point + Vector2(0, (-202.5 - progress * 58.5) * world_depth_scale(world_point))
	_draw_red_moon_disc(moon_point, moon_size, moon_alpha, clock)
	if progress > 0.65:
		draw_line(moon_point + Vector2(0, moon_size), point, Color(1.0, 0.18, 0.23, (progress - 0.65) * 0.52), 2.0, true)

func _draw_red_moon_impact(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", RED_MOON_IMPACT_SECONDS)))
	var elapsed := total - float(effect.life)
	var scale_factor := maxf(0.1, float(effect.get("red_moon_scale", 1.0)))
	var radii := Vector2(effect.get("red_moon_radii", Vector2(float(effect.get("radius", 105.0)), float(effect.get("radius", 105.0)) * 0.40)))
	var ground := Vector2(0.0, 8.0 / scale_factor)
	var moon := Vector2(0.0, -261.0)
	var moon_alpha := 1.0 - smoothstep(0.82, 1.35, elapsed)
	_draw_red_moon_disc(moon + Vector2(0, -elapsed * 9.0), 27.0, moon_alpha, clock)
	var beam_alpha := smoothstep(0.0, 0.16, elapsed) * (1.0 - smoothstep(0.78, 1.12, elapsed))
	if beam_alpha > 0.0:
		var reach := smoothstep(0.0, 0.17, elapsed)
		var beam_bottom := lerpf(-244.0, ground.y, reach)
		var flicker := 0.89 + 0.11 * sin(elapsed * 31.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-38, -252), Vector2(38, -252), Vector2(46, beam_bottom), Vector2(-46, beam_bottom)]), Color(0.82, 0.02, 0.08, beam_alpha * 0.60 * flicker))
		draw_colored_polygon(PackedVector2Array([Vector2(-12, -252), Vector2(12, -252), Vector2(16, beam_bottom), Vector2(-16, beam_bottom)]), Color(1.0, 0.75, 0.63, beam_alpha * 0.85 * flicker))
		_draw_red_moon_ellipse(ground, radii * 0.38, beam_alpha * 0.66, beam_alpha * 0.25, 4.0)
	var expansion := clampf((elapsed - 0.10) / 1.05, 0.0, 1.0)
	var shock_alpha := 1.0 - smoothstep(0.54, 1.47, elapsed)
	_draw_red_moon_ellipse(ground, radii, shock_alpha * 0.42, (1.0 - elapsed / total) * 0.11, 1.7)
	_draw_red_moon_ellipse(ground, radii * (0.17 + expansion * 0.83), shock_alpha * 0.95, shock_alpha * 0.08, 7.0 - expansion * 3.5)
	if reduced_effects:
		return
	for shard in 8:
		var angle := float(shard) * TAU / 8.0 + 0.23
		var start := ground + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * (0.18 + expansion * 0.42)
		var finish := ground + Vector2(cos(angle) * radii.x, sin(angle) * radii.y) * (0.30 + expansion * 0.64)
		draw_line(start, finish, Color(1.0, 0.38, 0.27, shock_alpha * 0.65), 2.5, true)

func _crossfire_field_edges(lane_y: float, half_width: float) -> Array[Vector2]:
	var field := visible_world_rect() if sim != null and sim.endless_mode else Sim.MOVE_AREA
	var bounds := Rect2(field.position.x, lane_y - half_width, field.size.x, half_width * 2.0)
	return [
		world_to_screen(Vector2(bounds.position.x, lane_y - half_width)),
		world_to_screen(Vector2(bounds.end.x, lane_y - half_width)),
		world_to_screen(Vector2(bounds.end.x, lane_y + half_width)),
		world_to_screen(Vector2(bounds.position.x, lane_y + half_width)),
	]

func _draw_crossfire_warning() -> void:
	if not sim.supports.has("support_crossfire") or sim.enemies.is_empty():
		return
	var support: Dictionary = sim.supports["support_crossfire"]
	var time_left := float(support.get("timer", 99.0))
	if time_left <= 0.0 or time_left > CROSSFIRE_WARNING_SECONDS:
		return
	var lane_y := float(support.get("lane_y", sim.enemies[0].pos.y))
	var edges := _crossfire_field_edges(lane_y, 58.0)
	var progress := 1.0 - time_left / CROSSFIRE_WARNING_SECONDS
	draw_colored_polygon(PackedVector2Array(edges), Color(0.36, 0.16, 0.025, 0.07 + progress * 0.07))
	for boundary in [0, 2]:
		var first: Vector2 = edges[boundary]
		var second: Vector2 = edges[(boundary + 1) % 4]
		draw_dashed_line(first, second, Color(1.0, 0.64, 0.24, 0.45 + progress * 0.30), 2.0, 13.0, true)
	var upper_left := edges[0].lerp(edges[3], 0.18)
	var lower_right := edges[1].lerp(edges[2], 0.82)
	var upper_right := edges[1].lerp(edges[2], 0.18)
	var lower_left := edges[0].lerp(edges[3], 0.82)
	draw_dashed_line(upper_left, lower_right, Color(1.0, 0.45, 0.18, 0.22 + progress * 0.28), 1.6, 16.0, true)
	draw_dashed_line(upper_right, lower_left, Color(1.0, 0.45, 0.18, 0.22 + progress * 0.28), 1.6, 16.0, true)
	var approach := progress * 0.20
	for path in [Vector2(0.0, 1.0), Vector2(1.0, 0.0)]:
		var start: Vector2 = upper_left if path.x == 0.0 else upper_right
		var end: Vector2 = lower_right if path.x == 0.0 else lower_left
		var arrow := start.lerp(end, approach)
		draw_circle(arrow, 7.0 + progress * 2.0, Color(1.0, 0.65, 0.29, 0.52 + progress * 0.33))

func _draw_crossfire_impact(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", CROSSFIRE_IMPACT_SECONDS)))
	var elapsed := total - float(effect.life)
	var lane_y := float(effect.get("lane_y", Vector2(effect.pos).y))
	var edges := _crossfire_field_edges(lane_y, float(effect.get("lane_half_width", 58.0)))
	var upper_left := edges[0].lerp(edges[3], 0.18)
	var lower_right := edges[1].lerp(edges[2], 0.82)
	var upper_right := edges[1].lerp(edges[2], 0.18)
	var lower_left := edges[0].lerp(edges[3], 0.82)
	var fade := 1.0 - smoothstep(0.68, total, elapsed)
	draw_colored_polygon(PackedVector2Array(edges), Color(0.53, 0.18, 0.025, 0.13 * fade))
	var travel := smoothstep(0.0, 0.66, elapsed)
	for path in [0, 1]:
		var start: Vector2 = upper_left if path == 0 else upper_right
		var end: Vector2 = lower_right if path == 0 else lower_left
		draw_line(start, end, Color(0.98, 0.31, 0.065, 0.24 * fade), 10.0, true)
		draw_line(start, end, Color(1.0, 0.73, 0.30, 0.32 * fade), 2.3, true)
		var head := start.lerp(end, travel)
		var tail := start.lerp(end, maxf(0.0, travel - 0.24))
		draw_line(tail, head, Color(1.0, 0.39, 0.08, 0.70 * fade), 14.0, true)
		draw_line(tail, head, Color(1.0, 0.91, 0.58, 0.96 * fade), 4.0, true)
		draw_circle(head, 9.0, Color(1.0, 0.63, 0.20, 0.80 * fade))
		draw_circle(head, 4.0, Color(1.0, 0.96, 0.74, 0.95 * fade))
	var crossing := upper_left.lerp(lower_right, 0.5)
	var sparks := smoothstep(0.25, 0.38, elapsed) * (1.0 - smoothstep(0.64, 1.07, elapsed))
	if sparks <= 0.0:
		return
	draw_circle(crossing, 17.0 + sparks * 9.0, Color(1.0, 0.55, 0.20, 0.28 * sparks))
	if reduced_effects:
		return
	for ray in 8:
		var direction := Vector2.from_angle(float(ray) * TAU / 8.0)
		draw_line(crossing + direction * 10.0, crossing + direction * (26.0 + sparks * 17.0), Color(1.0, 0.79, 0.39, 0.75 * sparks), 2.0, true)

func _draw_dedicated_arc(center: Vector2, radii: Vector2, start: float, sweep: float, color: Color, width: float = 2.0) -> void:
	var points := PackedVector2Array()
	for step in 25:
		var angle := start + sweep * float(step) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_polyline(points, color, width, true)

func _draw_score_note(point: Vector2, color: Color, size: float = 1.0) -> void:
	var oval := PackedVector2Array()
	for step in 13:
		var angle := float(step) * TAU / 12.0
		oval.append(point + Vector2(cos(angle) * 5.0, sin(angle) * 3.2) * size)
	draw_colored_polygon(oval, color)
	draw_line(point + Vector2(4.0, 0.0) * size, point + Vector2(4.0, -19.0) * size, color, 2.2 * size, true)
	draw_line(point + Vector2(4.0, -19.0) * size, point + Vector2(13.0, -14.0) * size, color, 2.0 * size, true)

func _draw_inward_spiral(center: Vector2, radii: Vector2, motion: float, alpha: float, density: float = 1.0) -> void:
	for arm in 3:
		var strand := PackedVector2Array()
		var phase := float(arm) * TAU / 3.0 - motion * 1.35
		for step in 37:
			var t := float(step) / 36.0
			var angle := phase + t * TAU * 1.30
			var inward := (0.86 - t * 0.74) * density
			strand.append(center + Vector2(cos(angle) * radii.x * inward, sin(angle) * radii.y * inward))
		draw_polyline(strand, Color(0.22, 0.82, 0.66, alpha * 0.16), 6.2, true)
		draw_polyline(strand, Color(0.78, 1.0, 0.89, alpha * 0.63), 1.9, true)
		var bead_t := fposmod(motion * 0.62 + float(arm) * 0.34, 1.0)
		var bead_index := clampi(floori(bead_t * 36.0), 0, 36)
		var bead: Vector2 = strand[bead_index]
		draw_circle(bead, 3.2, Color(0.80, 1.0, 0.88, alpha * 0.82))
	_draw_dedicated_arc(center, Vector2(15.0, 6.0) * density, 0.0, TAU, Color(0.70, 1.0, 0.86, alpha * 0.48), 1.5)

func _draw_ice_branches(center: Vector2, radii: Vector2, motion: float, alpha: float, growth: float = 1.0) -> void:
	for root in 10:
		var angle := float(root) * TAU / 10.0 + 0.09
		var direction := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var side := Vector2(-sin(angle) * radii.x, cos(angle) * radii.y)
		var stem_start := center + direction * 0.14
		var junction := center + direction * (0.43 * growth)
		var tip := center + direction * (0.80 * growth)
		draw_line(stem_start, tip, Color(0.46, 0.78, 0.98, alpha * 0.25), 5.0, true)
		draw_line(stem_start, tip, Color(0.89, 0.98, 1.0, alpha * 0.74), 1.7, true)
		for fork in [-1.0, 1.0]:
			var branch_tip: Vector2 = junction + direction * (0.15 * growth) + side * (0.16 * growth * float(fork))
			draw_line(junction, branch_tip, Color(0.75, 0.95, 1.0, alpha * 0.65), 1.45, true)
		var glint := 0.35 + 0.3 * sin(motion * 3.4 + root * 1.5)
		draw_circle(tip, 2.2, Color(0.88, 0.99, 1.0, alpha * glint))

func _draw_emilia_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var forest := str(effect.kind).begins_with("emilia_frozen_forest")
	var radius := float(effect.get("radius", 200.0))
	var ice := Color("#b9ebff") if forest else Color("#81d9ff")
	_draw_skill_area_ellipse(center_world, radius, ice, strength * (0.84 if forest else 0.70), 1.0)
	if forest:
		var growth := (0.22 + progress * 0.47) if casting else minf(1.0, 0.38 + progress * 1.15)
		_draw_ice_branches(center, radii, clock, strength, growth)
		for ring in 2:
			var spread := clampf((0.26 + progress * 0.72) - ring * 0.19, 0.10, 0.96)
			_draw_dedicated_arc(center, radii * spread, PI * 0.05, PI * 0.9, Color(0.80, 0.96, 1.0, strength * 0.42), 1.8)
		return
	var bloom := (0.12 + progress * 0.36) if casting else minf(0.77, 0.18 + progress * 1.05)
	for petal in 6:
		var angle := float(petal) * TAU / 6.0 + PI / 6.0
		var direction := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var side := Vector2(-sin(angle) * radii.x, cos(angle) * radii.y)
		var base := center + direction * (bloom * 0.13)
		var tip := center + direction * bloom
		var left := center + direction * (bloom * 0.50) + side * (bloom * 0.19)
		var right := center + direction * (bloom * 0.50) - side * (bloom * 0.19)
		var crystal := PackedVector2Array([base, left, tip, right])
		draw_colored_polygon(crystal, Color(0.42, 0.81, 1.0, strength * 0.19))
		draw_polyline(PackedVector2Array([base, left, tip, right, base]), Color(0.91, 0.99, 1.0, strength * 0.71), 1.7, true)
		draw_line(base, tip, Color(0.71, 0.94, 1.0, strength * 0.53), 1.3, true)
	if not casting:
		_draw_dedicated_arc(center, radii * minf(0.96, 0.30 + progress * 0.95), 0.0, TAU, Color(0.83, 0.98, 1.0, strength * 0.57), 1.8)

func _draw_amiya_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var chimera := str(effect.kind).begins_with("amiya_chimera")
	var radius := float(effect.get("radius", 160.0))
	var violet := Color("#a078ec") if chimera else Color("#ba9cff")
	_draw_skill_area_ellipse(center_world, radius, violet, strength * (0.78 if chimera else 0.63), 1.0)
	if chimera:
		for seal in 1 if casting else 2:
			var spread := 0.33 + float(seal) * 0.30 + (progress * 0.18 if not casting else progress * 0.22)
			_draw_dedicated_arc(center, radii * spread, clock * (0.37 if seal == 0 else -0.29), PI * 1.74, Color(0.78, 0.46, 1.0, strength * 0.57), 2.1)
		for blade in 10:
			var angle := float(blade) * TAU / 10.0 + clock * 0.18
			var ray := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			var side := Vector2(-sin(angle) * radii.x, cos(angle) * radii.y)
			var base := center + ray * 0.48
			var tip := center + ray * (0.72 if casting else 0.86)
			draw_colored_polygon(PackedVector2Array([base + side * 0.05, tip, base - side * 0.05]), Color(0.55, 0.30, 0.78, strength * 0.40))
			draw_line(base, tip, Color(0.89, 0.62, 1.0, strength * 0.47), 1.3, true)
		var eye := PackedVector2Array([center + Vector2(-22.0, 0.0), center + Vector2(0.0, -9.0), center + Vector2(22.0, 0.0), center + Vector2(0.0, 9.0)])
		draw_colored_polygon(eye, Color(0.26, 0.13, 0.41, strength * 0.55))
		draw_polyline(PackedVector2Array([eye[0], eye[1], eye[2], eye[3], eye[0]]), Color(0.96, 0.64, 1.0, strength * 0.84), 1.8, true)
		draw_circle(center, 4.0 + 2.0 * sin(clock * 5.0), Color(1.0, 0.39, 0.69, strength * 0.84))
		if not casting:
			var caster := world_to_screen(Vector2(effect.get("caster_pos", center_world))) + Vector2(0.0, 8.0)
			_draw_dedicated_arc(caster, Vector2(30.0, 12.0), 0.0, TAU, Color(0.91, 0.37, 0.71, strength * 0.73), 1.8)
		return
	var caster := world_to_screen(Vector2(effect.get("caster_pos", center_world))) + Vector2(0.0, -13.0)
	var front := progress if casting else minf(1.0, 0.39 + progress * 1.22)
	for lance in 3:
		var offset := (float(lance) - 1.0) * 18.0
		var origin := caster + Vector2(0.0, offset)
		var terminal := origin.lerp(center + Vector2(0.0, offset * 0.24), front)
		var zig := PackedVector2Array([origin, origin.lerp(terminal, 0.28) + Vector2(3.0, -5.0 + offset * 0.2), origin.lerp(terminal, 0.58) + Vector2(-4.0, 6.0 - offset * 0.15), terminal])
		draw_polyline(zig, Color(0.38, 0.13, 0.60, strength * 0.25), 6.0, true)
		draw_polyline(zig, Color(0.91, 0.73, 1.0, strength * 0.75), 2.0, true)
	if not casting:
		for shard in 8:
			var angle := float(shard) * TAU / 8.0
			var ray := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
			var spear := PackedVector2Array([center + ray * 0.30, center + ray * 0.61 + ray.orthogonal() * 0.07, center + ray * 0.83])
			draw_polyline(spear, Color(0.88, 0.66, 1.0, strength * 0.60), 1.6, true)

func _draw_roxy_storm(center: Vector2, radii: Vector2, motion: float, alpha: float) -> void:
	for bank in 3:
		var spread := 0.32 + float(bank) * 0.22
		var start := motion * (0.24 if bank % 2 == 0 else -0.19) + float(bank) * 1.7
		_draw_dedicated_arc(center, radii * spread, start, PI * 1.44, Color(0.42, 0.75, 1.0, alpha * (0.46 - bank * 0.08)), 2.1)
	for bolt in 6:
		var phase := float(bolt) * 1.21 + floorf(motion * 4.5) * 0.57
		var x := sin(phase) * radii.x * 0.63
		var y := cos(phase * 1.31) * radii.y * 0.46
		var point := center + Vector2(x, y)
		var flicker := 0.55 + 0.45 * sin(motion * 13.0 + float(bolt) * 2.3)
		var zig := PackedVector2Array([point + Vector2(-10.0, -14.0), point + Vector2(0.0, -3.0), point + Vector2(-4.0, 2.0), point + Vector2(10.0, 15.0)])
		draw_polyline(zig, Color(0.29, 0.55, 0.95, alpha * flicker * 0.18), 6.0, true)
		draw_polyline(zig, Color(0.85, 0.95, 1.0, alpha * flicker * 0.72), 1.9, true)
	for drop in 9:
		var angle := float(drop) * TAU / 9.0 + motion * 0.22
		var spot := center + Vector2(cos(angle) * radii.x * 0.67, sin(angle) * radii.y * 0.67)
		draw_line(spot + Vector2(-3.0, -5.0), spot + Vector2(3.0, 5.0), Color(0.52, 0.84, 1.0, alpha * 0.29), 1.2, true)

func _draw_roxy_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var storm := str(effect.kind).begins_with("roxy_storm_field")
	var radius := float(effect.get("radius", 230.0))
	var water := Color("#78cfff") if storm else Color("#6be5dd")
	_draw_skill_area_ellipse(center_world, radius, water, strength * 0.73, 1.0)
	if storm:
		_draw_roxy_storm(center, radii * (0.46 + progress * 0.36 if casting else 1.0), clock, strength)
		if not casting:
			var front := minf(0.96, 0.22 + progress * 1.20)
			_draw_dedicated_arc(center, radii * front, 0.0, TAU, Color(0.84, 0.97, 1.0, strength * 0.64), 2.0)
		return
	var spread := (0.22 + progress * 0.28) if casting else minf(0.90, 0.28 + progress * 1.10)
	for ripple in 2:
		var size := maxf(0.11, spread - float(ripple) * 0.21)
		_draw_dedicated_arc(center, radii * size, 0.0, TAU, Color(0.69, 1.0, 0.96, strength * (0.67 - ripple * 0.22)), 1.9)
	for branch in 6:
		var angle := float(branch) * TAU / 6.0 + clock * 0.22
		var ray := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		var point := center + ray * spread * 0.74
		var side := Vector2(-sin(angle), cos(angle))
		draw_colored_polygon(PackedVector2Array([point + ray.normalized() * 10.0, point + side * 3.2, point - ray.normalized() * 7.0, point - side * 3.2]), Color(0.72, 1.0, 0.98, strength * 0.52))
	if casting:
		return
	for ally: Dictionary in sim.heroes:
		if not bool(ally.get("deployed", false)) or ally.hp <= 0.0 or not sim.is_in_ability_area(center_world, Vector2(ally.pos), radius):
			continue
		var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
		var stream := PackedVector2Array()
		for step in 13:
			var t := float(step) / 12.0
			stream.append(center.lerp(foot, t) + Vector2(0.0, -15.0 * sin(t * PI)))
		draw_polyline(stream, Color(0.50, 0.91, 0.91, strength * 0.34), 1.7, true)
		_draw_dedicated_arc(foot, Vector2(26.0, 10.0) * (0.67 + progress * 0.26), 0.0, TAU, Color(0.77, 1.0, 0.96, strength * 0.75), 1.6)

func _draw_fengjin_leaf(point: Vector2, direction: Vector2, size: float, alpha: float) -> void:
	var tangent := direction.orthogonal()
	draw_colored_polygon(PackedVector2Array([point + direction * size, point + tangent * size * 0.36, point - direction * size * 0.67, point - tangent * size * 0.36]), Color(0.72, 1.0, 0.78, alpha * 0.66))
	draw_line(point - direction * size * 0.57, point + direction * size * 0.80, Color(0.96, 1.0, 0.88, alpha * 0.84), 1.1, true)

func _draw_fengjin_row_lanes(center_world: Vector2, color: Color, alpha: float) -> void:
	var center_row := clampi(floori((center_world.y - Sim.GRID_ORIGIN.y) / Sim.GRID_CELL_SIZE.y), 1, Sim.GRID_ROWS - 2)
	var left_x: float = sim.active_view_rect.position.x if sim.endless_mode else Sim.GRID_ORIGIN.x
	var right_x: float = sim.active_view_rect.end.x if sim.endless_mode else Sim.GRID_ORIGIN.x + Sim.GRID_COLUMNS * Sim.GRID_CELL_SIZE.x
	for offset in [-1, 0, 1]:
		var y: float = Sim.GRID_ORIGIN.y + (center_row + offset + 0.5) * Sim.GRID_CELL_SIZE.y
		var left := world_to_screen(Vector2(left_x, y)) + Vector2(0.0, 8.0)
		var right := world_to_screen(Vector2(right_x, y)) + Vector2(0.0, 8.0)
		draw_line(left, right, Color(color, alpha * 0.21), 9.0, true)
		draw_line(left, right, Color(color.lightened(0.36), alpha * 0.64), 2.2, true)

func _draw_fengjin_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var healing := str(effect.kind).begins_with("fengjin_renewing_breeze")
	var radius := float(effect.get("radius", 200.0))
	var breeze := Color("#8deac0") if healing else Color("#62e5b2")
	if healing:
		_draw_skill_area_ellipse(center_world, radius, breeze, strength * 0.66, 1.0)
		var spread := (0.18 + progress * 0.38) if casting else minf(0.92, 0.21 + progress * 1.17)
		for ring in 2:
			var size := maxf(0.10, spread - float(ring) * 0.20)
			_draw_dedicated_arc(center, radii * size, PI * 0.06, PI * 1.90, Color(0.73, 1.0, 0.84, strength * (0.66 - ring * 0.22)), 2.0)
		for leaf in 8:
			var angle := float(leaf) * TAU / 8.0 + clock * 0.45
			var place := center + Vector2(cos(angle) * radii.x * spread * 0.78, sin(angle) * radii.y * spread * 0.78)
			_draw_fengjin_leaf(place, Vector2.from_angle(angle + PI * 0.33), 6.8, strength)
		if not casting:
			for ally: Dictionary in sim.heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0 and sim.is_in_ability_area(center_world, Vector2(ally.pos), radius):
					var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
					_draw_dedicated_arc(foot, Vector2(25.0, 9.0), 0.0, TAU, Color(0.77, 1.0, 0.83, strength * 0.52), 1.5)
		return
	_draw_fengjin_row_lanes(center_world, breeze, strength * (0.48 if casting else 0.72))

func _draw_fengjin_wind_row(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 0.42)))
	var progress := clampf(1.0 - float(effect.life) / total, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.68, 1.0, progress)
	var row := int(effect.get("row_index", int(effect.get("center_row", 5)) + int(effect.get("pulse_index", 1)) - 1))
	var y: float = Sim.GRID_ORIGIN.y + (row + 0.5) * Sim.GRID_CELL_SIZE.y
	var left := world_to_screen(Vector2(float(effect.get("left_x", Sim.GRID_ORIGIN.x)), y)) + Vector2(0.0, 8.0)
	var right := world_to_screen(Vector2(float(effect.get("right_x", Sim.GRID_ORIGIN.x + Sim.GRID_COLUMNS * Sim.GRID_CELL_SIZE.x)), y)) + Vector2(0.0, 8.0)
	var tip := left.lerp(right, minf(1.0, progress * 1.42))
	var trail_start := maxf(left.x, tip.x - (right.x - left.x) * 0.30)
	var ribbon := PackedVector2Array()
	for segment in 13:
		var fraction := float(segment) / 12.0
		var x := lerpf(trail_start, tip.x, fraction)
		var wobble := sin(fraction * TAU * 2.0 - progress * 11.0) * (1.0 - fraction) * 4.0
		ribbon.append(Vector2(x, tip.y + wobble))
	draw_line(left, right, Color(0.27, 0.80, 0.58, alpha * 0.13), 8.0, true)
	draw_polyline(ribbon, Color(0.28, 0.88, 0.64, alpha * 0.42), 12.0, true)
	draw_polyline(ribbon, Color(0.91, 1.0, 0.88, alpha * 0.91), 3.0, true)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(22.0, 0.0), tip + Vector2(-11.0, -10.0), tip + Vector2(-3.0, 0.0), tip + Vector2(-11.0, 10.0)]), Color(0.88, 1.0, 0.88, alpha * 0.95))
	for feather in 5:
		var fraction := 0.18 + float(feather) * 0.16
		var x := lerpf(trail_start, tip.x, fraction)
		var direction := -1.0 if feather % 2 == 0 else 1.0
		draw_line(Vector2(x, tip.y + direction * 3.0), Vector2(x - 14.0, tip.y + direction * (8.0 + feather)), Color(0.72, 1.0, 0.84, alpha * 0.56), 2.0, true)
	for value in effect.get("target_positions", []):
		var foot := world_to_screen(Vector2(value)) + Vector2(0.0, 7.0)
		_draw_dedicated_arc(foot, Vector2(23.0, 9.0) * (0.62 + progress * 0.60), 0.0, TAU, Color(0.75, 1.0, 0.83, alpha * 0.59), 1.6)

func _draw_fengjin_breeze_zone(zone: Dictionary, center: Vector2, radii: Vector2, alpha: float) -> void:
	for ring in 2:
		var spread := fposmod(clock * 0.43 + float(ring) * 0.51, 1.0)
		_draw_dedicated_arc(center, radii * (0.19 + spread * 0.72), 0.0, TAU, Color(0.76, 1.0, 0.82, alpha * (1.0 - spread) * 0.36), 1.6)
	for leaf in 8:
		var angle := float(leaf) * TAU / 8.0 + clock * 0.31
		var place := center + Vector2(cos(angle) * radii.x * 0.65, sin(angle) * radii.y * 0.65)
		_draw_fengjin_leaf(place, Vector2.from_angle(angle + PI * 0.35), 5.8, alpha * 0.77)
	var center_world := Vector2(zone.pos)
	for ally: Dictionary in sim.heroes:
		if bool(ally.get("deployed", false)) and ally.hp > 0.0 and sim.is_in_ability_area(center_world, Vector2(ally.pos), float(zone.area)):
			var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
			_draw_dedicated_arc(foot, Vector2(25.0, 9.0) * (0.85 + 0.06 * sin(clock * 3.0)), 0.0, TAU, Color(0.82, 1.0, 0.83, alpha * 0.38), 1.3)

func _draw_gwen_thread_mark(foot: Vector2, alpha: float, size: float = 1.0) -> void:
	var radii := Vector2(28.0, 11.0) * size
	_draw_dedicated_arc(foot, radii, 0.0, TAU, Color(0.97, 0.83, 0.96, alpha * 0.72), 1.7)
	for stitch in [-1.0, 0.0, 1.0]:
		var x: float = float(stitch) * radii.x * 0.46
		draw_line(foot + Vector2(x - 7.0 * size, -radii.y * 0.62), foot + Vector2(x + 7.0 * size, radii.y * 0.62), Color(1.0, 0.92, 0.99, alpha * 0.53), 1.2, true)
	draw_circle(foot + Vector2(0.0, -radii.y * 0.24), 2.8 * size, Color(1.0, 0.89, 0.96, alpha * 0.82))

func _draw_gwen_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var shelter := str(effect.kind).begins_with("gwen_thread_shelter")
	var radius := float(effect.get("radius", 255.0))
	var silk := Color("#efd7ef") if shelter else Color("#eda6d7")
	if shelter:
		_draw_skill_area_ellipse(center_world, radius, silk, strength * 0.76, 1.0)
	if shelter:
		var weave := (0.25 + progress * 0.29) if casting else minf(0.92, 0.38 + progress * 0.85)
		for stitch in 7:
			var phase := float(stitch) / 6.0
			var x := lerpf(-radii.x * weave, radii.x * weave, phase)
			var height := sqrt(maxf(0.0, 1.0 - pow(x / maxf(1.0, radii.x), 2.0))) * radii.y * weave
			draw_line(center + Vector2(x - 7.0, -height * 0.69), center + Vector2(x + 7.0, height * 0.69), Color(1.0, 0.92, 0.98, strength * 0.39), 1.2, true)
		if not casting:
			for ally: Dictionary in sim.heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0 and sim.is_in_ability_area(center_world, Vector2(ally.pos), radius):
					_draw_gwen_thread_mark(world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0), strength)
		return
	var pin_reveal := clampf(progress * 1.42, 0.0, 1.0) if casting else 1.0
	_draw_gwen_boundary_pins(center, radii, pin_reveal, strength)
	if not casting:
		var spread := clampf(progress * 3.0, 0.06, 1.0)
		_draw_dedicated_arc(center, radii * spread * 0.95, 0.0, TAU, Color(1.0, 0.82, 0.95, strength * 0.74), 3.0)
		_draw_dedicated_arc(center, radii * spread * 0.76, 0.0, TAU, Color(0.91, 0.65, 0.85, strength * 0.31), 1.5)

func _draw_gwen_boundary_pins(center: Vector2, radii: Vector2, reveal: float, alpha: float) -> void:
	for pin in 8:
		var born := clampf((reveal * 8.0 - float(pin)) * 1.5, 0.0, 1.0)
		if born <= 0.0:
			continue
		var angle := float(pin) * TAU / 8.0 - PI * 0.5
		var point := center + Vector2(cos(angle) * radii.x * 0.92, sin(angle) * radii.y * 0.92)
		var height := 18.0 * born
		var stem := point + Vector2(0.0, -height)
		draw_circle(point, 6.0 * born, Color(0.93, 0.43, 0.72, alpha * born * 0.12))
		draw_colored_polygon(PackedVector2Array([stem + Vector2(0.0, -4.0), stem + Vector2(3.0, 5.0), point, stem + Vector2(-3.0, 5.0)]), Color(0.99, 0.91, 0.98, alpha * born))
		draw_line(stem + Vector2(0.0, 2.0), point, Color(0.73, 0.44, 0.71, alpha * born), 2.0, true)
		_draw_dedicated_arc(point + Vector2(0.0, 3.0), Vector2(7.0, 3.0) * born, 0.0, TAU, Color(0.96, 0.70, 0.91, alpha * born * 0.54), 1.1)

func _draw_gwen_shelter_aura(effect: Dictionary) -> void:
	var life := maxf(0.0, float(effect.get("life", 0.0)))
	var alpha := smoothstep(0.0, 1.0, life) * (0.73 + 0.08 * sin(clock * 4.0))
	for recipient in effect.get("ally_ids", []):
		var index := int(recipient)
		if index < 0 or index >= sim.heroes.size():
			continue
		var ally: Dictionary = sim.heroes[index]
		if not bool(ally.get("deployed", false)) or ally.hp <= 0.0:
			continue
		_draw_gwen_thread_mark(world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0), alpha)

func _draw_gwen_needle_hit(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 0.38)))
	var progress := clampf(1.0 - float(effect.life) / total, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.61, 1.0, progress)
	var source := world_to_screen(Vector2(effect.get("source", effect.pos))) + Vector2(0.0, -20.0)
	var target := world_to_screen(Vector2(effect.pos)) + Vector2(0.0, -8.0)
	var needle_id := int(effect.get("needle_index", 0))
	var mid := source.lerp(target, 0.5) + Vector2(0.0, -24.0 - float(needle_id % 3) * 8.0)
	var travel := minf(1.0, progress * 1.85)
	var point := source.lerp(mid, travel * 2.0) if travel <= 0.5 else mid.lerp(target, (travel - 0.5) * 2.0)
	var direction := (target - source).normalized()
	var side := direction.orthogonal()
	draw_line(point - direction * 25.0, point, Color(0.92, 0.64, 0.87, alpha * 0.30), 3.3, true)
	draw_colored_polygon(PackedVector2Array([point + direction * 11.0, point - direction * 8.0 + side * 2.5, point - direction * 8.0 - side * 2.5]), Color(1.0, 0.92, 0.99, alpha * 0.93))
	if travel >= 0.92:
		_draw_dedicated_arc(target, Vector2(11.0, 4.0) * (0.65 + progress * 0.75), 0.0, TAU, Color(1.0, 0.78, 0.94, alpha * 0.46), 1.4)

func _draw_gwen_needle_zone(zone: Dictionary, center: Vector2, radii: Vector2, alpha: float) -> void:
	_draw_gwen_boundary_pins(center, radii, 1.0, alpha)
	var elapsed := maxf(0.0, 2.0 - float(zone.get("life", 0.0)))
	var spread := clampf(elapsed / 0.52, 0.04, 1.0)
	var wave_alpha := alpha * (1.0 - smoothstep(0.78, 1.0, elapsed / 2.0))
	_draw_dedicated_arc(center, radii * spread * 0.94, 0.0, TAU, Color(1.0, 0.83, 0.96, wave_alpha * 0.75), 3.0)
	_draw_dedicated_arc(center, radii * spread * 0.73, 0.0, TAU, Color(0.91, 0.59, 0.85, wave_alpha * 0.33), 1.4)
	for spoke in 8:
		var angle := float(spoke) * TAU / 8.0 - PI * 0.5
		var ray := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
		draw_line(center + ray * maxf(0.0, spread - 0.25), center + ray * spread, Color(1.0, 0.83, 0.95, wave_alpha * 0.29), 1.1, true)

func _draw_maiden_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var forest := str(effect.kind).begins_with("maiden_frozen_forest")
	var radius := float(effect.get("radius", 185.0))
	_draw_skill_area_ellipse(center_world, radius, Color("#a4eaff") if forest else Color("#c8f5ff"), strength * 0.66, 1.0)
	if forest:
		var growth := (0.23 + progress * 0.38) if casting else minf(1.0, 0.30 + progress * 1.15)
		_draw_ice_branches(center, radii, clock * 0.38, strength * 0.63, growth)
		var moon := center + Vector2(-radii.x * 0.13, -radii.y * 0.37)
		draw_arc(moon, 20.0 * growth, PI * 0.18, PI * 1.82, 28, Color(0.88, 0.98, 1.0, strength * 0.80), 2.6, true)
		draw_arc(moon + Vector2(7.0, -3.0), 17.0 * growth, PI * 0.08, PI * 1.66, 26, Color(0.58, 0.84, 1.0, strength * 0.42), 1.4, true)
		for star in 7:
			var angle := float(star) * TAU / 7.0 + clock * 0.12
			var place := center + Vector2(cos(angle) * radii.x * growth * 0.68, sin(angle) * radii.y * growth * 0.68)
			draw_line(place + Vector2(-4.0, 0.0), place + Vector2(4.0, 0.0), Color(0.87, 0.99, 1.0, strength * 0.49), 1.2, true)
			draw_line(place + Vector2(0.0, -4.0), place + Vector2(0.0, 4.0), Color(0.87, 0.99, 1.0, strength * 0.49), 1.2, true)
		return
	var spread := (0.26 + progress * 0.48) if casting else minf(0.93, 0.34 + progress * 1.13)
	for line in 5:
		var row_y := (float(line) - 2.0) * radii.y * 0.14
		var points := PackedVector2Array()
		for step in 17:
			var t := float(step) / 16.0
			points.append(center + Vector2(lerpf(-radii.x * spread, radii.x * spread, t), row_y + sin(t * PI * 2.0 + progress * 3.2) * radii.y * 0.035))
		draw_polyline(points, Color(0.72, 0.94, 1.0, strength * 0.34), 1.3, true)
	for note in 5:
		var step_progress := fposmod(progress * 0.65 + float(note) * 0.19, 1.0)
		var position := center + Vector2(lerpf(-radii.x * spread, radii.x * spread, step_progress), (float(note % 5) - 2.0) * radii.y * 0.14 - sin(step_progress * PI) * 7.0)
		_draw_score_note(position, Color(0.91, 1.0, 1.0, strength * 0.82), 0.48)
	if not casting:
		for snow in 6:
			var angle := float(snow) * TAU / 6.0 + progress * 0.45
			var point := center + Vector2(cos(angle) * radii.x * spread * 0.72, sin(angle) * radii.y * spread * 0.72)
			draw_line(point + Vector2(-6.0, 0.0), point + Vector2(6.0, 0.0), Color(0.93, 1.0, 1.0, strength * 0.58), 1.5, true)
			draw_line(point + Vector2(0.0, -6.0), point + Vector2(0.0, 6.0), Color(0.93, 1.0, 1.0, strength * 0.58), 1.5, true)

func _draw_maiden_forest_zone(center: Vector2, radii: Vector2, alpha: float) -> void:
	_draw_ice_branches(center, radii, clock * 0.35, alpha * 0.53)
	for note in 6:
		var angle := float(note) * TAU / 6.0 + clock * 0.22
		var place := center + Vector2(cos(angle) * radii.x * 0.67, sin(angle) * radii.y * 0.67)
		_draw_score_note(place + Vector2(0.0, sin(clock * 1.7 + note) * 4.0), Color(0.88, 0.98, 1.0, alpha * 0.40), 0.38)

func _draw_columbia_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var blessing := str(effect.kind).begins_with("columbia_tidal_benediction")
	if blessing:
		if casting:
			_draw_tidal_ellipse(center, Vector2(32.0, 12.0) * (0.55 + progress * 0.42), strength * 0.56)
		return
	_draw_skill_area_ellipse(center_world, float(effect.get("radius", 210.0)), Color("#48c9ef"), strength * 0.72, 0.24 + progress * 0.65)
	for stream in 3:
		var spread := clampf(progress * 0.77 - float(stream) * 0.18 + 0.26, 0.11, 0.92)
		_draw_dedicated_arc(center, radii * spread, PI * 0.07, PI * 1.83, Color(0.72, 0.98, 1.0, strength * (0.70 - float(stream) * 0.14)), 2.3)

func _draw_columbia_tide_zone(zone: Dictionary, center: Vector2, radii: Vector2, alpha: float) -> void:
	var beat := fposmod(clock / 0.8, 1.0)
	for ring in 3:
		var spread := fposmod(beat + float(ring) / 3.0, 1.0)
		_draw_dedicated_arc(center, radii * (0.18 + spread * 0.80), 0.0, TAU, Color(0.56, 0.91, 1.0, alpha * (1.0 - spread) * 0.70), 2.4 - spread)
	for drop in 8:
		var angle := float(drop) * TAU / 8.0 + clock * 0.46
		var point := center + Vector2(cos(angle) * radii.x * 0.71, sin(angle) * radii.y * 0.71)
		draw_circle(point, 2.7, Color(0.80, 1.0, 1.0, alpha * 0.52))

func _draw_columbia_blessing_links(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 25.0)))
	var elapsed := total - float(effect.life)
	var fade := clampf(float(effect.life) / 0.8, 0.0, 1.0)
	var travel_seconds := 1.35
	var source_id := int(effect.get("hero_id", -1))
	if source_id < 0 or source_id >= sim.heroes.size():
		return
	var source := world_to_screen(Vector2(sim.heroes[source_id].pos)) + Vector2(0.0, 8.0)
	if elapsed < travel_seconds:
		_draw_tidal_ellipse(source, Vector2(27.0, 10.0) * (0.86 + sin(elapsed * 5.0) * 0.08), fade * 0.53)
	for ally_id in effect.get("ally_ids", []):
		var index := int(ally_id)
		if index < 0 or index >= sim.heroes.size() or sim.heroes[index].hp <= 0.0:
			continue
		var foot := world_to_screen(Vector2(sim.heroes[index].pos)) + Vector2(0.0, 8.0)
		var arrival_time := 0.0 if index == source_id else travel_seconds
		if elapsed < travel_seconds and index != source_id:
			var travel := clampf(elapsed / travel_seconds, 0.0, 1.0)
			var route := PackedVector2Array()
			for segment in 25:
				var fraction := float(segment) / 24.0
				route.append(source.lerp(foot, fraction) + Vector2(0.0, -30.0 * sin(fraction * PI)))
			var link_fade := 1.0 - smoothstep(0.94, 1.0, travel)
			draw_polyline(route, Color(0.29, 0.82, 0.91, fade * link_fade * 0.34), 2.2, true)
			for bead in 3:
				var bead_progress := travel - float(bead) * 0.085
				if bead_progress < 0.0:
					continue
				var bead_pos: Vector2 = route[mini(24, floori(bead_progress * 24.0))]
				var bead_alpha := fade * link_fade * (1.0 - float(bead) * 0.25)
				draw_circle(bead_pos, 8.0 - float(bead) * 1.4, Color(0.23, 0.79, 0.88, bead_alpha * 0.24))
				draw_circle(bead_pos, 4.5 - float(bead) * 0.8, Color(0.86, 1.0, 0.97, bead_alpha))
		if elapsed >= arrival_time:
			var arrived := elapsed - arrival_time
			if arrived < 1.15:
				var spread := clampf(arrived / 1.15, 0.0, 1.0)
				_draw_tidal_ellipse(foot, Vector2(54.0, 19.0) * (0.18 + spread * 1.02), fade * (1.0 - spread * 0.53))
			var ripple := fposmod(arrived * 0.55 + float(index) * 0.12, 1.0)
			_draw_dedicated_arc(foot, Vector2(30.0, 11.0) * (0.55 + ripple * 0.48), 0.0, TAU, Color(0.60, 0.94, 1.0, fade * (1.0 - ripple) * 0.32), 1.6)

func _draw_furina_ability(effect: Dictionary, center_world: Vector2, center: Vector2, radii: Vector2, progress: float, strength: float, casting: bool) -> void:
	var fanfare := str(effect.kind).begins_with("furina_hydro_fanfare")
	var color := Color("#83d9ff") if fanfare else Color("#a2e8fc")
	_draw_skill_area_ellipse(center_world, float(effect.get("radius", 190.0)), color, strength * 0.63, 1.0)
	var opening := (0.20 + progress * 0.38) if casting else minf(0.95, 0.28 + progress * 1.16)
	for curtain in [-1.0, 1.0]:
		var side := float(curtain)
		var upper := center + Vector2(side * radii.x * opening * 0.62, -radii.y * opening * 0.70)
		var lower := center + Vector2(side * radii.x * opening * 0.82, radii.y * opening * 0.30)
		_draw_dedicated_arc(center + Vector2(side * radii.x * opening * 0.35, -radii.y * 0.16), Vector2(radii.x * opening * 0.29, radii.y * opening * 0.64), PI * (0.95 if side > 0.0 else -0.03), PI * 0.96, Color(0.79, 0.94, 1.0, strength * 0.50), 1.8)
		draw_line(upper, lower, Color(0.56, 0.78, 1.0, strength * 0.35), 2.0, true)
	if fanfare:
		for ray in 7:
			var phase := float(ray) * TAU / 7.0 - PI * 0.5
			var point := center + Vector2(cos(phase) * radii.x * opening * 0.58, sin(phase) * radii.y * opening * 0.58)
			draw_line(point, point + Vector2(cos(phase) * 11.0, sin(phase) * 8.0 - 9.0), Color(0.91, 0.98, 1.0, strength * 0.48), 1.2, true)
		if not casting:
			for ally: Dictionary in sim.heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0:
					_draw_furina_footlight(world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0), strength * 0.72, progress)
	else:
		for companion in 3:
			var angle := float(companion) * TAU / 3.0 - PI * 0.5
			var point := center + Vector2(cos(angle) * radii.x * opening * 0.64, sin(angle) * radii.y * opening * 0.64)
			_draw_furina_salon_companion(point, companion, strength * clampf(progress * 3.0, 0.0, 1.0))

func _draw_furina_salon_companion(point: Vector2, index: int, alpha: float) -> void:
	var shell := Color(0.48, 0.79, 0.97, alpha * 0.72)
	var glint := Color(0.92, 0.99, 1.0, alpha * 0.94)
	_draw_dedicated_arc(point + Vector2(0.0, 5.0), Vector2(15.0, 5.0), 0.0, TAU, Color(0.54, 0.87, 1.0, alpha * 0.34), 1.2)
	if index == 0:
		draw_colored_polygon(PackedVector2Array([point + Vector2(-10.0, 2.0), point + Vector2(-4.0, -9.0), point + Vector2(6.0, -9.0), point + Vector2(11.0, 2.0)]), shell)
		draw_line(point + Vector2(-7.0, -2.0), point + Vector2(-15.0, -9.0), glint, 2.0, true)
		draw_line(point + Vector2(7.0, -2.0), point + Vector2(15.0, -9.0), glint, 2.0, true)
	elif index == 1:
		draw_circle(point + Vector2(0.0, -6.0), 8.0, shell)
		for tentacle in [-1.0, 0.0, 1.0]:
			var x: float = float(tentacle) * 6.0
			draw_line(point + Vector2(x, -3.0), point + Vector2(x * 1.3, 8.0), glint, 1.5, true)
	else:
		draw_arc(point + Vector2(-1.0, -5.0), 9.0, PI * 0.23, PI * 1.72, 22, shell, 5.0, true)
		draw_colored_polygon(PackedVector2Array([point + Vector2(3.0, -14.0), point + Vector2(13.0, -8.0), point + Vector2(3.0, -4.0)]), glint)
	draw_circle(point + Vector2(-3.0, -7.0), 1.8, glint)

func _draw_furina_footlight(foot: Vector2, alpha: float, progress: float) -> void:
	_draw_dedicated_arc(foot, Vector2(28.0, 11.0) * (0.78 + progress * 0.25), 0.0, TAU, Color(0.69, 0.92, 1.0, alpha * 0.68), 1.8)
	for ripple in 3:
		var angle := float(ripple) * TAU / 3.0 + clock * 0.36
		var point := foot + Vector2(cos(angle) * 20.0, sin(angle) * 6.0 - 11.0 - progress * 8.0)
		draw_circle(point, 2.4, Color(0.89, 0.99, 1.0, alpha * 0.57))

func _draw_furina_fanfare_allies(effect: Dictionary) -> void:
	var total := maxf(0.1, float(effect.get("total", 3.4)))
	var progress := clampf(1.0 - float(effect.life) / total, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.72, 1.0, progress)
	for value in effect.get("ally_ids", []):
		var index := int(value)
		if index >= 0 and index < sim.heroes.size():
			var ally: Dictionary = sim.heroes[index]
			if bool(ally.get("deployed", false)) and ally.hp > 0.0:
				_draw_furina_footlight(world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0), alpha, progress)

func _draw_furina_fanfare_zone(center: Vector2, radii: Vector2, alpha: float) -> void:
	for ripple in 3:
		var spread := fposmod(clock * 0.46 + float(ripple) / 3.0, 1.0)
		_draw_dedicated_arc(center, radii * (0.18 + spread * 0.78), 0.0, TAU, Color(0.75, 0.94, 1.0, alpha * (1.0 - spread) * 0.41), 1.4)
	for light in 7:
		var angle := float(light) * TAU / 7.0 + clock * 0.13
		var point := center + Vector2(cos(angle) * radii.x * 0.74, sin(angle) * radii.y * 0.74)
		draw_circle(point + Vector2(0.0, sin(clock * 2.0 + light) * 4.0), 2.6, Color(0.90, 0.99, 1.0, alpha * 0.42))

func _draw_traveler_ability(effect: Dictionary) -> void:
	var kind := str(effect.kind)
	var casting := kind.ends_with("_cast")
	var element := kind.trim_prefix("traveler_").trim_suffix("_cast").trim_suffix("_impact")
	var total := maxf(0.01, float(effect.get("total", 1.25)))
	var progress := clampf((total - float(effect.life)) / total, 0.0, 1.0)
	var alpha := (0.27 + progress * 0.50) if casting else 1.0 - smoothstep(0.62, 1.0, progress)
	var center_world := Vector2(effect.pos)
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radius := float(effect.get("radius", 170.0))
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	var color := element_color(element)
	if element == "none":
		color = Color("#ffe6ac")
	_draw_skill_area_ellipse(center_world, radius, color, alpha * 0.55, (0.46 + progress * 0.44) if not casting else 0.74)
	match element:
		"none":
			for blade in 3:
				var offset := (float(blade) - 1.0) * radii.y * 0.31
				var slash := PackedVector2Array()
				for step in 17:
					var t := float(step) / 16.0
					var x := lerpf(-radii.x * 0.83, radii.x * 0.83, t)
					slash.append(center + Vector2(x, offset - sin(t * PI) * radii.y * 0.30))
				draw_polyline(slash, Color(1.0, 0.80, 0.35, alpha * 0.20), 8.0, true)
				draw_polyline(slash, Color(1.0, 0.99, 0.80, alpha * 0.80), 2.5, true)
		"electro":
			for fork in 8:
				var angle := float(fork) * TAU / 8.0 + clock * 0.38
				var end := center + Vector2(cos(angle) * radii.x * 0.86, sin(angle) * radii.y * 0.86)
				var middle := center.lerp(end, 0.56) + Vector2.from_angle(angle + PI * 0.5) * 8.0
				draw_polyline(PackedVector2Array([center, middle, end]), Color(0.72, 0.59, 1.0, alpha * 0.55), 2.1, true)
				if not casting:
					draw_circle(end, 3.7, Color(0.94, 0.89, 1.0, alpha * 0.82))
		"pyro":
			var fall := clampf((progress - 0.05) * 2.1, 0.0, 1.0)
			if not casting:
				for ember in 9:
					var angle := float(ember) * TAU / 9.0 + 0.28
					var direction := Vector2(cos(angle) * radii.x, sin(angle) * radii.y)
					var tip := center + direction * (0.20 + fall * 0.78)
					var side := direction.orthogonal().normalized()
					draw_colored_polygon(PackedVector2Array([tip + direction.normalized() * 11.0, tip - direction.normalized() * 16.0 + side * 5.0, tip - direction.normalized() * 16.0 - side * 5.0]), Color(1.0, 0.49, 0.18, alpha * 0.57))
				_draw_dedicated_arc(center, radii * (0.20 + fall * 0.76), 0.0, TAU, Color(1.0, 0.83, 0.47, alpha * 0.73), 2.8)
			else:
				var falling := center + Vector2(-radii.x * 0.24, -105.0 * (1.0 - progress))
				draw_circle(falling, 8.0 + progress * 7.0, Color(1.0, 0.64, 0.27, alpha * 0.78))
		"hydro":
			for wave in 3:
				var spread := fposmod(progress * (0.38 if casting else 0.87) + float(wave) / 3.0, 1.0)
				_draw_dedicated_arc(center, radii * (0.15 + spread * 0.84), 0.0, TAU, Color(0.64, 0.94, 1.0, alpha * (1.0 - spread) * 0.68), 2.1)
			if not casting:
				for ally: Dictionary in sim.heroes:
					if bool(ally.get("deployed", false)) and ally.hp > 0.0:
						var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
						_draw_dedicated_arc(foot, Vector2(27.0, 10.0) * (0.55 + progress * 0.55), 0.0, TAU, Color(0.74, 1.0, 0.98, alpha * 0.66), 1.7)
		"geo":
			var growth := (0.34 + progress * 0.53) if casting else (0.72 + progress * 0.26)
			for edge in 6:
				var first := center + Vector2(cos(float(edge) * TAU / 6.0) * radii.x, sin(float(edge) * TAU / 6.0) * radii.y) * growth
				var second := center + Vector2(cos(float(edge + 1) * TAU / 6.0) * radii.x, sin(float(edge + 1) * TAU / 6.0) * radii.y) * growth
				draw_line(first, second, Color(1.0, 0.82, 0.47, alpha * 0.77), 2.6, true)
			if not casting:
				for shard in 5:
					var x := (float(shard) - 2.0) * radii.x * 0.34
					var top := center + Vector2(x, -radii.y * (0.76 - progress * 0.30))
					draw_colored_polygon(PackedVector2Array([top, top + Vector2(-6.0, 15.0), top + Vector2(5.0, 11.0)]), Color(0.98, 0.78, 0.41, alpha * 0.59))
		"cryo":
			_draw_ice_branches(center, radii, clock * 0.44, alpha * 0.82, 0.35 + progress * 0.65)
			for orbit in 2:
				var spread := clampf(progress * 0.74 - float(orbit) * 0.25 + 0.31, 0.12, 0.92)
				_draw_dedicated_arc(center, radii * spread, 0.0, TAU, Color(0.79, 0.96, 1.0, alpha * (0.68 - orbit * 0.21)), 2.0)

func _draw_traveler_lingering_zone(zone: Dictionary, center: Vector2, radii: Vector2, alpha: float) -> void:
	var hydro := str(zone.get("visual", "")) == "traveler_hydro"
	if hydro:
		for ring in 3:
			var spread := fposmod(clock * 0.38 + float(ring) / 3.0, 1.0)
			_draw_dedicated_arc(center, radii * (0.25 + spread * 0.70), 0.0, TAU, Color(0.60, 0.93, 1.0, alpha * (1.0 - spread) * 0.39), 1.5)
	else:
		_draw_ice_branches(center, radii, clock * 0.22, alpha * 0.35)

func _draw_traveler_electro_chains(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 1.05)))
	var progress := clampf(1.0 - float(effect.life) / total, 0.0, 1.0)
	var alpha := 1.0 - smoothstep(0.58, 1.0, progress)
	var source := world_to_screen(Vector2(effect.pos)) + Vector2(0.0, 8.0)
	for value in effect.get("target_positions", []):
		var target := world_to_screen(Vector2(value)) + Vector2(0.0, 8.0)
		var side := (target - source).orthogonal().normalized()
		var path := PackedVector2Array([source, source.lerp(target, 0.31) + side * 11.0, source.lerp(target, 0.65) - side * 9.0, target])
		draw_polyline(path, Color(0.47, 0.36, 1.0, alpha * 0.28), 8.0, true)
		draw_polyline(path, Color(0.91, 0.82, 1.0, alpha * 0.84), 2.5, true)
		draw_circle(target, 5.0, Color(0.94, 0.90, 1.0, alpha * 0.77))

func _draw_dedicated_ability(effect: Dictionary) -> void:
	var kind := str(effect.kind)
	var casting := kind.ends_with("_cast")
	var total := maxf(0.01, float(effect.get("total", 1.0)))
	var progress := clampf((total - float(effect.life)) / total, 0.0, 1.0)
	var strength := (0.30 + progress * 0.55) if casting else 1.0 - smoothstep(0.56, 1.0, progress)
	var center_world := Vector2(effect.pos)
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radius := float(effect.get("radius", 180.0))
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	if kind.begins_with("anemo_domain"):
		_draw_skill_area_ellipse(center_world, radius, Color("#69e6be"), strength * 0.64, 1.0)
		_draw_inward_spiral(center, radii, clock, strength, 1.0 if casting else 1.35)
		return
	if kind.begins_with("emilia_"):
		_draw_emilia_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("amiya_"):
		_draw_amiya_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("roxy_"):
		_draw_roxy_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("fengjin_"):
		_draw_fengjin_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("gwen_"):
		_draw_gwen_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("columbia_"):
		_draw_columbia_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	if kind.begins_with("furina_"):
		_draw_furina_ability(effect, center_world, center, radii, progress, strength, casting)
		return
	var grand := kind.begins_with("fate_symphony")
	var fire := Color("#ff7d57") if grand else Color("#ffae66")
	_draw_skill_area_ellipse(center_world, radius, fire, strength * (0.72 if grand else 0.60), 1.0)
	var front := (0.19 + progress * 0.77) if not casting else (0.13 + progress * 0.40)
	for ring in 2 if grand else 1:
		var spread := clampf(front - float(ring) * 0.16, 0.06, 0.97)
		_draw_dedicated_arc(center, radii * spread, PI * 0.04, PI * 0.91, Color(fire.lightened(0.25), strength * 0.74), 3.0 if grand else 2.4)
		_draw_dedicated_arc(center, radii * spread, PI * 1.04, PI * 0.91, Color(fire.lightened(0.20), strength * 0.53), 2.0)
	for stave in 5:
		var y := (float(stave) - 2.0) * radii.y * (0.16 if grand else 0.18)
		var offset := sin(progress * 8.0 + stave * 0.52) * radii.y * 0.045
		draw_line(center + Vector2(-radii.x * 0.74, y + offset), center + Vector2(radii.x * 0.74, y + offset), Color(fire, strength * (0.22 if grand else 0.34)), 1.2, true)
	if not reduced_effects:
		for note_index in 4 if grand else 2:
			var x := radii.x * (-0.55 + float(note_index) * (0.34 if grand else 0.68))
			var y := radii.y * sin(float(note_index) * 1.7 + progress * 3.0) * 0.42
			_draw_score_note(center + Vector2(x, y), Color(1.0, 0.89 if grand else 0.67, 0.56, strength * 0.82), 0.77 if grand else 0.65)
	if not casting and not reduced_effects:
		for ember in 12 if grand else 6:
			var angle := float(ember) * TAU / (12.0 if grand else 6.0) + progress * (0.24 if grand else -0.16)
			var base := center + Vector2(cos(angle) * radii.x * 0.76, sin(angle) * radii.y * 0.76)
			var drift := Vector2(cos(angle), sin(angle) * 0.4).normalized()
			var side := drift.orthogonal()
			var ember_size := (8.0 if grand else 5.0) * (0.70 + 0.30 * sin(progress * PI))
			draw_colored_polygon(PackedVector2Array([base + drift * ember_size * 1.5, base + side * ember_size * 0.34, base - drift * ember_size * 0.78, base - side * ember_size * 0.34]), Color(1.0, 0.55 if grand else 0.72, 0.28, strength * 0.55))
	if grand and not casting:
		for ally: Dictionary in sim.heroes:
			if not bool(ally.get("deployed", false)) or ally.hp <= 0.0:
				continue
			var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
			_draw_dedicated_arc(foot, Vector2(28.0, 10.0), 0.0, TAU, Color(1.0, 0.69, 0.32, strength * 0.70), 1.7)
			_draw_score_note(foot + Vector2(13.0, -24.0 - progress * 10.0), Color(1.0, 0.86, 0.47, strength * 0.90), 0.5)

func _draw_dedicated_zone(zone: Dictionary, center: Vector2, radii: Vector2) -> void:
	var visual := str(zone.get("visual", ""))
	var remaining := float(zone.get("life", 0.0))
	var total := 12.0 if visual in ["emilia_forest", "fengjin_breeze", "maiden_forest"] else (10.0 if visual == "furina_fanfare" else (2.0 if visual == "gwen_needles" else (9.0 if visual == "roxy_storm" else (7.0 if visual == "sylphie_domain" else (10.0 if visual == "saki_score_e" else 5.0)))))
	var alpha := clampf(remaining / 0.75, 0.0, 1.0) * (0.45 + 0.55 * clampf((total - remaining) / 0.65, 0.0, 1.0))
	if visual == "sylphie_domain":
		_draw_inward_spiral(center, radii, clock, alpha * 0.76, 0.92)
		return
	if visual == "emilia_forest":
		_draw_ice_branches(center, radii, clock, alpha * 0.70)
		return
	if visual == "roxy_storm":
		_draw_roxy_storm(center, radii, clock, alpha * 0.72)
		return
	if visual == "fengjin_breeze":
		_draw_fengjin_breeze_zone(zone, center, radii, alpha)
		return
	if visual == "gwen_needles":
		_draw_gwen_needle_zone(zone, center, radii, alpha)
		return
	if visual == "columbia_tide_ring":
		_draw_columbia_tide_zone(zone, center, radii, alpha)
		return
	if visual == "columbia_blessing":
		return
	if visual in ["traveler_hydro", "traveler_cryo"]:
		_draw_traveler_lingering_zone(zone, center, radii, alpha)
		return
	if visual == "furina_fanfare":
		_draw_furina_fanfare_zone(center, radii, alpha)
		return
	var fire := Color("#ff744d") if visual == "saki_score_e" else Color("#ffab61")
	for stave in 5:
		var y := (float(stave) - 2.0) * radii.y * 0.18
		draw_line(center + Vector2(-radii.x * 0.70, y), center + Vector2(radii.x * 0.70, y), Color(fire, alpha * 0.25), 1.25, true)
	for note_index in 4 if visual == "saki_score_e" else 2:
		var x := radii.x * (-0.54 + float(note_index) * (0.35 if visual == "saki_score_e" else 0.72))
		var y := radii.y * sin(clock * 1.6 + note_index * 1.6) * 0.38
		_draw_score_note(center + Vector2(x, y), Color(fire.lightened(0.32), alpha * 0.65), 0.57)

func _draw_tidal_ellipse(center: Vector2, radii: Vector2, alpha: float) -> void:
	var outline := PackedVector2Array()
	for index in 49:
		var angle := float(index) * TAU / 48.0
		outline.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	var fill := outline.duplicate()
	fill.resize(48)
	draw_colored_polygon(fill, Color(0.17, 0.66, 0.73, alpha * 0.17))
	draw_polyline(outline, Color(0.45, 0.94, 0.95, alpha * 0.82), 2.0, true)
	for segment in 8:
		var phase := float(segment) * TAU / 8.0
		var arc := PackedVector2Array()
		for step in 5:
			var angle := phase + 0.48 * float(step) / 4.0
			arc.append(center + Vector2(cos(angle) * radii.x * 0.88, sin(angle) * radii.y * 0.88))
		draw_polyline(arc, Color(0.81, 1.0, 0.98, alpha * 0.46), 1.2, true)

func _draw_tidal_footprint(hero: Dictionary, progress: float, alpha: float) -> void:
	var center := world_to_screen(Vector2(hero.pos)) + Vector2(0.0, 8.0)
	var size := 0.16 + 0.065 * smoothstep(0.0, 0.85, progress)
	var radii: Vector2 = sim.attack_range_screen_radii(hero) * size
	radii.x = minf(radii.x, 68.0)
	radii.y = minf(radii.y, 27.0)
	_draw_tidal_ellipse(center, radii, alpha)

func _draw_tidal_warning() -> void:
	if not sim.supports.has("support_heal") or sim.endless_mode:
		return
	var remaining := float(sim.supports["support_heal"].get("timer", 99.0))
	if remaining <= 0.0 or remaining > TIDAL_WARNING_SECONDS:
		return
	var progress := 1.0 - remaining / TIDAL_WARNING_SECONDS
	var core := world_to_screen(Vector2(100.0, 365.0)) + Vector2(0.0, 8.0)
	_draw_tidal_ellipse(core, Vector2(24.0, 9.0) * (0.75 + progress * 0.35), 0.24 + progress * 0.32)

func _draw_tidal_heal(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", TIDAL_EFFECT_SECONDS)))
	var elapsed := total - float(effect.life)
	var progress := clampf(elapsed / total, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.83, 1.0, progress)
	var travel := clampf(progress / TIDAL_TRAVEL_FRACTION, 0.0, 1.0)
	if not sim.endless_mode:
		var core := world_to_screen(Vector2(100.0, 365.0))
		_draw_tidal_ellipse(core + Vector2(0.0, 8.0), Vector2(38.0, 14.0) * (0.74 + travel * 0.26), fade * 0.56)
	var hero_ids: Array = effect.get("hero_ids", [])
	for hero_id in hero_ids:
		var index := int(hero_id)
		if index < 0 or index >= sim.heroes.size():
			continue
		var hero: Dictionary = sim.heroes[index]
		if not bool(hero.get("deployed", false)) or hero.hp <= 0.0:
			continue
		if not sim.endless_mode:
			var source := world_to_screen(Vector2(100.0, 365.0))
			var destination := world_to_screen(Vector2(hero.pos)) + Vector2(0.0, 8.0)
			var route := PackedVector2Array()
			for segment in 25:
				var fraction := float(segment) / 24.0
				route.append(source.lerp(destination, fraction) + Vector2(0.0, -35.0 * sin(fraction * PI)))
			draw_polyline(route, Color(0.29, 0.82, 0.91, fade * 0.34), 2.1, true)
			if progress < TIDAL_TRAVEL_FRACTION:
				var bead_pos: Vector2 = route[mini(24, floori(travel * 24.0))]
				draw_circle(bead_pos, 8.0, Color(0.23, 0.79, 0.88, fade * 0.25))
				draw_circle(bead_pos, 4.6, Color(0.86, 1.0, 0.97, fade))
		if progress >= TIDAL_TRAVEL_FRACTION:
			var arrival := (progress - TIDAL_TRAVEL_FRACTION) / (1.0 - TIDAL_TRAVEL_FRACTION)
			_draw_tidal_footprint(hero, arrival, fade * (0.72 + 0.28 * sin(arrival * PI)))

func _draw_sylphie_gust(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", SYLPHIE_GUST_SECONDS)))
	var elapsed := total - float(effect.life)
	var progress := clampf(elapsed / total, 0.0, 1.0)
	var casting := str(effect.kind) == "sylphie_gust_cast"
	var radius := float(effect.get("radius", 170.0))
	var center_world := Vector2(effect.pos)
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	var fade := 0.34 + progress * 0.46 if casting else 1.0 - smoothstep(0.83, total, elapsed)
	var spread := 0.29 + progress * 0.26 if casting else minf(1.0, 0.48 + progress * 1.38)
	_draw_skill_area_ellipse(center_world, radius, Color("#6de7ab"), fade, spread)
	var flower := 9.0 + (7.0 if casting else 14.0) * sin(progress * PI)
	for petal in 6:
		var angle := float(petal) * TAU / 6.0 + elapsed * 1.2
		var forward := Vector2(cos(angle) * flower, sin(angle) * flower * 0.42)
		var tangent := Vector2(-sin(angle), cos(angle) * 0.42).normalized()
		var tip := center + forward * 1.65
		var root := center + forward * 0.43
		var leaf := PackedVector2Array([root - tangent * 3.0, tip, root + tangent * 3.0, center + forward * 0.8])
		draw_colored_polygon(leaf, Color(0.66, 1.0, 0.81, fade * 0.60))
	if casting or reduced_effects:
		return
	for band in 3:
		var y_offset := (float(band) - 1.0) * radii.y * 0.32
		var lane := PackedVector2Array()
		for step in 25:
			var t := float(step) / 24.0
			var x := lerpf(-radii.x * 0.82, radii.x * 0.82, t)
			var y := y_offset + sin(t * TAU * 1.25 - progress * 7.0 + band * 0.9) * radii.y * 0.19
			lane.append(center + Vector2(x, y))
		draw_polyline(lane, Color(0.35, 0.82, 0.62, fade * 0.16), 6.0, true)
		draw_polyline(lane, Color(0.88, 1.0, 0.86, fade * 0.75), 2.1, true)
		var head := mini(24, floori(progress * 24.0))
		var direction := (lane[mini(24, head + 1)] - lane[maxi(0, head - 1)]).normalized()
		var side := direction.orthogonal()
		var point := lane[head]
		draw_colored_polygon(PackedVector2Array([point + direction * 11.0, point - direction * 4.0 + side * 3.5, point - direction * 4.0 - side * 3.5]), Color(0.93, 1.0, 0.83, fade * 0.85))
	for ally: Dictionary in sim.heroes:
		if not bool(ally.get("deployed", false)) or ally.hp <= 0.0 or not sim.is_in_ability_area(center_world, Vector2(ally.pos), radius):
			continue
		var foot := world_to_screen(Vector2(ally.pos)) + Vector2(0.0, 8.0)
		var scale_factor := world_depth_scale(Vector2(ally.pos))
		var underfoot := Vector2(28.0, 10.0) * scale_factor * (0.8 + progress * 0.2)
		draw_polyline(_ability_ellipse_points(foot, underfoot), Color(0.63, 1.0, 0.78, fade * 0.72), 1.8, true)
		for leaf_index in 4:
			var phase := float(leaf_index) * TAU / 4.0 + elapsed * 2.4
			var rise := 18.0 + progress * 28.0 + float(leaf_index % 2) * 11.0
			var leaf_center := foot + Vector2(cos(phase) * 17.0 * scale_factor, -rise * scale_factor)
			var tip := leaf_center + Vector2(5.5, -7.5) * scale_factor
			draw_colored_polygon(PackedVector2Array([leaf_center - Vector2(4.0, 0.0) * scale_factor, tip, leaf_center + Vector2(2.0, 4.0) * scale_factor]), Color(0.74, 1.0, 0.79, fade * 0.82))

func _draw_ability_impact(effect: Dictionary) -> void:
	var total := maxf(0.01, float(effect.get("total", 0.6)))
	var elapsed := total - float(effect.life)
	var progress := clampf(elapsed / total, 0.0, 1.0)
	var fade := 1.0 - smoothstep(0.56, 1.0, progress)
	var center_world := Vector2(effect.pos)
	var radius := float(effect.get("radius", 170.0))
	var color := element_color(str(effect.get("element", "none")))
	if Sim.GLOBAL_TEAM_ABILITY_KINDS.has(str(effect.get("ability_kind", ""))):
		for ally: Dictionary in sim.heroes:
			if bool(ally.get("deployed", false)) and ally.hp > 0.0:
				_draw_skill_area_ellipse(Vector2(ally.pos), 35.0, color, fade * 0.68, minf(1.0, 0.38 + progress * 1.4))
		return
	_draw_skill_area_ellipse(center_world, radius, color, fade, minf(1.0, 0.32 + progress * 1.38))
	if reduced_effects:
		return
	var center := world_to_screen(center_world) + Vector2(0.0, 8.0)
	var radii: Vector2 = sim.ability_area_screen_radii(center_world, radius)
	for sweep in 3:
		var track := PackedVector2Array()
		var offset := (float(sweep) - 1.0) * radii.y * 0.30
		for step in 17:
			var t := float(step) / 16.0
			track.append(center + Vector2(lerpf(-radii.x * 0.68, radii.x * 0.68, t), offset + sin(t * TAU + progress * 7.0 + sweep) * radii.y * 0.08))
		draw_polyline(track, Color(color.lightened(0.30), fade * 0.40), 1.7, true)

func _draw_effect(effect: Dictionary) -> void:
	if effect.kind == "barrage":
		_draw_red_moon_impact(effect)
		return
	if effect.kind == "fireball_impact":
		var impact_frame := clampi(floori((float(effect.get("total", 33.0 / 24.0)) - float(effect.life)) * 24.0), 0, 32)
		var radius := float(effect.get("radius", 190.0))
		var size := radius * 2.25
		var fade := 1.0 if impact_frame < 9 else clampf(float(32 - impact_frame) / 23.0, 0.0, 1.0)
		_draw_video_atlas_frame(FIREBALL_IMPACT_ATLAS, 8, 256, impact_frame, Rect2(-size * 0.5, -size * 0.69, size, size), Color(1.0, 1.0, 1.0, fade))
		return
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
	elif effect.kind in ["crossfire", "finale", "death_burst", "boss_summon", "enemy_volatile", "boss_move", "boss_phase"]:
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
	elif effect.kind in ["reinforcement", "frenzy", "contract_complete"]:
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
