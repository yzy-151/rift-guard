extends RefCounted

var workshop_mode := false
var workshop_auto_attack := true
var workshop_enemy_action := true
var workshop_invulnerable := true

const CardSynergies = preload("res://scripts/rewards/card_synergies.gd")
const Readability = preload("res://scripts/combat_readability.gd")
var last_incoming_hit: Dictionary = {}
var last_leak: Dictionary = {}
var hero_down_causes: Dictionary = {}
var leak_count := 0
var leak_damage := 0

const EnemyTactics = preload("res://scripts/enemy_tactics.gd")
const BattleDevices = preload("res://scripts/battle_devices.gd")
var battle_devices = BattleDevices.new()
var device_shop: Dictionary:
	get: return battle_devices.snapshot(self)
const SUPPORT_DAMAGE_SCALE := 3.0
const TravelerElements = preload("res://scripts/traveler_elements.gd")
## Fixed-step gameplay, independent of scenes and visual effects.
const Rewards = preload("res://scripts/reward_book.gd")
const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CrystalProgression = preload("res://scripts/rewards/crystal_progression.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
const CombatCardEffects = preload("res://scripts/rewards/combat_card_effects.gd")
const StageRuntime = preload("res://scripts/stages/stage_runtime.gd")
const StageProjection = preload("res://scripts/stage_projection.gd")
const CombatTimeline = preload("res://scripts/combat_timeline.gd")
const PerformanceBudget = preload("res://scripts/performance_budget.gd")
const TeamResonance = preload("res://scripts/team_resonance.gd")
const XP_THRESHOLDS = [80, 190, 330, 500]
const Catalog = preload("res://scripts/combat_catalog.gd")
const MOVE_AREA = Rect2(40, 140, 1200, 440)
const GRID_ORIGIN := Vector2(40, 140)
const GRID_CELL_SIZE := Vector2(60, 40)
const GRID_COLUMNS := 20
const GRID_ROWS := 11
const STAGE_EXIT_AREA = Rect2(185, 215, 900, 320)
const EndlessExpedition = preload("res://scripts/endless_expedition.gd")
const ENDLESS_ARENA = EndlessExpedition.ARENA
var expedition = EndlessExpedition.new()
const LANES = [270.0, 360.0, 450.0]
const PROJECTILE_SPEED: float = 720.0
const PROJECTILE_LIFETIME := 4.5
const PROJECTILE_BIN_SIZE := 128.0
const AURA_DURATION: float = 3.0
const REACTION_COOLDOWN: float = 0.5
const HEAL_RANGE: float = 310.0
const HEAL_AMOUNT: float = 22.0
const HeroSignature = preload("res://scripts/hero_signature_skills.gd")
const SELF_CENTERED_ABILITY_KINDS := ["wind_cut", "columbia_tide_ring", "columbia_tidal_benediction", "heal_gust", "thread_shelter", "hydro_fanfare", "team_concert", "encore", "mon3tr", "bangboo", "network_overdrive"]
const GLOBAL_TEAM_ABILITY_KINDS := ["team_concert", "encore", "network_overdrive", "columbia_tidal_benediction"]
const ENDLESS_BOSS_IDS := ["boss_01", "boss_02", "boss_03", "boss_04", "boss_05", "boss_06"]
const ENDLESS_ACTIVE_CAP_EARLY := 42
const ENDLESS_ACTIVE_CAP_LATE := 80
const ENDLESS_NAV_CELL_SIZE := 64.0
const ENDLESS_NAV_CLEARANCE := 48.0
const ENDLESS_NAV_REFRESH := 0.45
const MAX_ENDLESS_ENEMY_PROJECTILES := 200
const MAX_ENDLESS_ENEMY_HAZARDS := 72
const ENDLESS_LOW_TIER_CAP_EARLY := 36
const ENDLESS_LOW_TIER_CAP_LATE := 40
const ENDLESS_HUT_CAP := 2
const ENDLESS_LOW_TIER_IDS := ["grunt", "runner", "slime_pyro", "slime_electro", "slime_anemo", "slime_hydro", "slime_cryo"]
const CAMPAIGN_MINION_BASE_MULTIPLIER := 3.0
const CAMPAIGN_MINION_HEALTH_GROWTH := 1.36
const CAMPAIGN_MINION_DAMAGE_GROWTH := 1.28
const CAMPAIGN_BOSS_HEALTH_MULTIPLIER := 2.5
const CAMPAIGN_BOSS_DAMAGE_MULTIPLIER := 2.5

var rewards
var database
var run_state
var crystal
var card_pool
var stage_runtime
var v2_mode := false
var current_stage_id := "stage_01"
var run_seed: int = 0
var team_xp: int = 0
var team_level: int = 1
var heal_amount: float = HEAL_AMOUNT
var heal_interval: float = 2.6
var aura_duration: float = AURA_DURATION
var vapor_multiplier: float = 1.5
var regroup_ratio: float = 0.2
var state: String = "ready"
var previous_state: String = "running"
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var enemy_lookup: Dictionary = {}
var projectiles: Array[Dictionary] = []
var enemy_projectiles: Array[Dictionary] = []
var enemy_hazards: Array[Dictionary] = []
var pending_stage_spawns: Array[Dictionary] = []
var pending_troop_spawns: Array[Dictionary] = []
var events: Array[Dictionary] = []
var base_hp: int = 100
var base_max_hp: int = 100
var wave: int = 0
var kills: int = 0
var boss_kills: int = 0
var shots_fired: int = 0
var reactions: int = 0
var elapsed: float = 0.0
var spawn_timer: float = 0.0
var spawn_remaining: int = 0
var wave_timer: float = 0.0
var next_id: int = 0
var next_projectile_id: int = 0
var supports: Dictionary = {}
var execute_threshold: float = 0.0
var death_burst_ratio: float = 0.0
var rejected_recruits: Dictionary = {}
var elite_damage_bonus: float = 0.0
var kill_frenzy_step: float = 0.0
var frenzy_milestone: int = 0
var traveler_skill_cooldown: float = 0.0
var traveler_skill_cooldown_max: float = 0.0
var skill_effects: Array[Dictionary] = []
var geo_constructs: Array[Dictionary] = []
var next_construct_id: int = 0
var reaction_damage_bonus: float = 0.0
var reaction_radius_bonus: float = 0.0
var skill_power_bonus: float = 0.0
var skill_cooldown_reduction: float = 0.0
var skill_area_bonus: float = 0.0
var skill_duration_bonus: float = 0.0
var energy_gain_bonus: float = 0.0
var crystal_shield: float = 0.0
var kill_streak: int = 0
var best_streak: int = 0
var kill_streak_timer: float = 0.0
var reward_cooldown: float = 0.0
var debug_reward_resume_state: String = ""
var endless_mode: bool = false
var active_view_rect: Rect2 = ENDLESS_ARENA
var endless_threat_bucket := -1
var endless_spawn_timer: float = 0.0
var troop_convoy_timer: float = 72.0
var endless_next_boss_at: float = 180.0
var endless_boss_index: int = 0
var terrain_features: Array[Dictionary] = []
var formation_mode: String = "hold"
var follow_leader_id: int = 0
var follow_history: Array[Dictionary] = []
var follow_sample_timer := 0.0
var pending_impacts: Array[Dictionary] = []
var orbitals: Array[Dictionary] = []
var tag_synergy_levels: Dictionary = {}
var dodges: int = 0
var damage_source_override: int = -1
var attack_audio_source_override: int = -1
var attack_geometry_cache: Dictionary = {}
var projectile_query_active := false
var projectile_neighbor_cache: Dictionary = {}
var projectile_chain_cache: Dictionary = {}
var projectile_splash_cache: Dictionary = {}
var projectile_enemy_bins: Dictionary = {}
var projectile_bins_ready := false
var projectile_range_cache: Dictionary = {}
var projectile_range_enemies: Dictionary = {}
var hit_feedback_cache: Dictionary = {}
var fireball_level: int = 0
var meteor_timer: float = 4.0
var performance_budget = PerformanceBudget.new()
var culled_spawns: int = 0
var combat_contract: Dictionary = {}
var contract_completed: bool = false
var contract_reward_text: String = ""
var recent_spawn_kinds: Array[String] = []
var enemy_support_scan_timer: float = 0.0
var endless_nav_columns: int = 0
var endless_nav_rows: int = 0
var endless_nav_solid := PackedByteArray()
var endless_nav_fields: Dictionary = {}
var endless_nav_cache: Dictionary = {}
var endless_blocker_bins: Dictionary = {}
var endless_blocker_index_ready := false
var endless_nav_refresh_timer: float = 0.0

func _init(seed_value: int = -1, enable_v2: bool = false) -> void:
	v2_mode = enable_v2
	if v2_mode:
		reset_stage("stage_01", ["traveler"], seed_value)
	else:
		reset(seed_value)

func _resolve_run_seed(seed_value: int) -> int:
	if seed_value >= 0:
		return seed_value
	var fresh_rng := RandomNumberGenerator.new()
	fresh_rng.randomize()
	return fresh_rng.randi_range(0, 2147483646)

func reset(seed_value: int = -1) -> void:
	_reset_projectile_queries()
	endless_mode = false
	endless_threat_bucket = -1
	endless_spawn_timer = 0.0
	troop_convoy_timer = 120.0
	endless_next_boss_at = 180.0
	endless_boss_index = 0
	active_view_rect = ENDLESS_ARENA
	terrain_features.clear()
	formation_mode = "hold"
	follow_leader_id = 0
	follow_history.clear()
	follow_sample_timer = 0.0
	run_seed = _resolve_run_seed(seed_value)
	rewards = Rewards.new(run_seed)
	team_xp = 0
	team_level = 1
	heal_amount = HEAL_AMOUNT
	heal_interval = 2.6
	aura_duration = AURA_DURATION
	vapor_multiplier = 1.5
	regroup_ratio = 0.2
	state = "ready"
	previous_state = "running"
	last_incoming_hit.clear(); last_leak.clear(); hero_down_causes.clear()
	leak_count = 0; leak_damage = 0
	base_hp = 100
	base_max_hp = 100
	wave = 0
	kills = 0
	boss_kills = 0
	shots_fired = 0
	reactions = 0
	elapsed = 0.0
	spawn_timer = 0.0
	spawn_remaining = 0
	wave_timer = 0.0
	next_id = 0
	supports.clear()
	execute_threshold = 0.0
	death_burst_ratio = 0.0
	elite_damage_bonus = 0.0
	kill_frenzy_step = 0.0
	frenzy_milestone = 0
	traveler_skill_cooldown = 0.0
	traveler_skill_cooldown_max = 0.0
	skill_effects.clear()
	geo_constructs.clear()
	pending_impacts.clear()
	orbitals.clear()
	tag_synergy_levels.clear()
	dodges = 0
	damage_source_override = -1
	attack_audio_source_override = -1
	fireball_level = 0
	meteor_timer = 4.0
	performance_budget = PerformanceBudget.new()
	attack_geometry_cache.clear()
	hit_feedback_cache.clear()
	culled_spawns = 0
	combat_contract = {}
	contract_completed = false
	contract_reward_text = ""
	recent_spawn_kinds.clear()
	enemy_support_scan_timer = 0.0
	next_construct_id = 0
	reaction_damage_bonus = 0.0
	reaction_radius_bonus = 0.0
	skill_power_bonus = 0.0
	skill_cooldown_reduction = 0.0
	skill_area_bonus = 0.0
	skill_duration_bonus = 0.0
	energy_gain_bonus = 0.0
	crystal_shield = 0.0
	kill_streak = 0
	best_streak = 0
	kill_streak_timer = 0.0
	reward_cooldown = 0.0
	debug_reward_resume_state = ""
	heroes.clear()
	rejected_recruits.clear()
	enemies.clear()
	enemy_lookup.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_hazards.clear()
	pending_stage_spawns.clear()
	pending_troop_spawns.clear()
	next_projectile_id = 0
	events.clear()
	battle_devices.reset(self)
	battle_devices.enabled = false
	if run_state != null: run_state.device_cards_enabled = false
	for i in Catalog.HEROES.size():
		var h: Dictionary = Catalog.HEROES[i].duplicate(true)
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": false, "splash": false, "slow": false, "slime_slow_timer": 0.0})
		heroes.append(h)

func _balanced_campaign_xp_thresholds(values: Array) -> Array[int]:
	var balanced: Array[int] = []
	for index in values.size():
		var scale := 0.65 if index >= 9 else (0.80 if index >= 5 else 1.0)
		balanced.append(roundi(float(values[index]) * scale))
	return balanced

func reset_stage(stage_id: String, squad_ids: Array[String] = [], seed_value: int = -1) -> void:
	_reset_projectile_queries()
	v2_mode = true
	current_stage_id = stage_id
	endless_mode = stage_id == "stage_endless"
	endless_threat_bucket = -1
	endless_spawn_timer = 0.15
	troop_convoy_timer = 120.0
	endless_next_boss_at = 180.0
	endless_boss_index = 0
	active_view_rect = ENDLESS_ARENA
	database = Database.new()
	if not database.errors.is_empty() or not database.stages.has(stage_id):
		push_error("Cannot start configured stage: " + str(database.errors))
		return
	if run_state == null:
		run_state = RunState.new()
	if not squad_ids.is_empty() and not run_state.set_squad(squad_ids):
		push_error("Invalid squad: " + str(squad_ids))
		return
	run_state.reset_for_stage(stage_id)
	run_state.mode_id = "endless_survival" if endless_mode else "rift_watch"
	var stage_definition: Dictionary = database.stages[stage_id]
	crystal = CrystalProgression.new(_balanced_campaign_xp_thresholds(stage_definition.xp_thresholds) if not endless_mode else stage_definition.xp_thresholds)
	run_seed = _resolve_run_seed(seed_value)
	card_pool = CardPool.new(database.cards, run_seed)
	card_pool.levels = run_state.buff_levels
	rewards = card_pool
	stage_runtime = StageRuntime.new(stage_definition)
	_load_terrain(stage_definition)
	_rebuild_endless_navigation_grid()
	formation_mode = "follow" if endless_mode else "hold"
	follow_leader_id = 0
	follow_history.clear()
	follow_sample_timer = 0.0
	team_xp = 0
	team_level = 1
	state = "ready"
	previous_state = "running"
	last_incoming_hit.clear(); last_leak.clear(); hero_down_causes.clear()
	leak_count = 0; leak_damage = 0
	base_hp = 12
	base_max_hp = 12
	wave = 0
	kills = 0
	boss_kills = 0
	shots_fired = 0
	reactions = 0
	elapsed = 0.0
	spawn_timer = 0.0
	spawn_remaining = 0
	wave_timer = 0.0
	next_id = 0
	supports.clear()
	execute_threshold = 0.0
	death_burst_ratio = 0.0
	elite_damage_bonus = 0.0
	kill_frenzy_step = 0.0
	frenzy_milestone = 0
	traveler_skill_cooldown = 0.0
	traveler_skill_cooldown_max = 0.0
	skill_effects.clear()
	geo_constructs.clear()
	pending_impacts.clear()
	orbitals.clear()
	tag_synergy_levels.clear()
	dodges = 0
	damage_source_override = -1
	attack_audio_source_override = -1
	fireball_level = 0
	meteor_timer = 4.0
	performance_budget = PerformanceBudget.new()
	attack_geometry_cache.clear()
	hit_feedback_cache.clear()
	culled_spawns = 0
	combat_contract = {}
	contract_completed = false
	contract_reward_text = ""
	recent_spawn_kinds.clear()
	enemy_support_scan_timer = 0.0
	combat_contract = {} if endless_mode else database.combat_contracts.get(stage_id, {}).duplicate(true)
	next_construct_id = 0
	reaction_damage_bonus = 0.0
	reaction_radius_bonus = 0.0
	skill_power_bonus = 0.0
	skill_cooldown_reduction = 0.0
	skill_area_bonus = 0.0
	skill_duration_bonus = 0.0
	energy_gain_bonus = 0.0
	crystal_shield = 0.0
	kill_streak = 0
	best_streak = 0
	kill_streak_timer = 0.0
	reward_cooldown = 0.0
	debug_reward_resume_state = ""
	heroes.clear()
	rejected_recruits.clear()
	enemies.clear()
	enemy_lookup.clear()
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_hazards.clear()
	pending_stage_spawns.clear()
	pending_troop_spawns.clear()
	next_projectile_id = 0
	events.clear()
	battle_devices.reset(self)
	var starts := [Vector2(505, 360), Vector2(375, 295), Vector2(345, 430)]
	if endless_mode:
		var center := ENDLESS_ARENA.get_center()
		starts = [center, center + Vector2(-86, -68), center + Vector2(-86, 68)]
	var colors := ["#e9d7ad", "#eaaa7d", "#83c7e8"]
	for i in run_state.squad.size():
		var id: String = run_state.squad[i]
		if not database.characters.has(id):
			push_error("Unknown squad character: " + id)
			continue
		var source: Dictionary = database.characters[id]
		var element: String = "" if source.element == "none" else str(source.element)
		var h := {
			"character_id": id, "name": source.name, "role": source.role, "element": element,
			"secondary_element": run_state.traveler_secondary_element if id == "traveler" and run_state.traveler_secondary_element != "none" else "",
			"hp": float(source.max_hp), "armor": float(source.armor), "damage": float(source.attack),
			"rate": float(source.attack_rate), "range": float(source.attack_range), "speed": float(source.move_speed),
			"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": _nearest_walkable_point(starts[i], 17.0),
			"color": colors[i], "tile": Vector2(i * 16, 112), "visual": "furina" if id == "hero_03" else ""
		}
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": id == "traveler", "cleave_ratio": 0.90, "splash": false, "slow": false, "slime_slow_timer": 0.0, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0, "deployed": endless_mode, "energy": 0.0, "max_energy": float(source.get("ultimate", {}).get("energy_cost", 100.0)), "skill_cooldown": 0.0, "ultimate_cooldown": 0.0, "ultimate_cooldown_max": 0.0, "active_skill": source.get("active_skill", {}).duplicate(true), "ultimate": source.get("ultimate", {}).duplicate(true), "passive": source.get("passive", {}).duplicate(true), "animation_state":"idle", "status_timer":0.0, "damage_reduction":0.0, "damage_done": 0.0, "skill_uses": 0, "ultimate_uses": 0, "max_energy_seen": 0.0, "revived": false, "follow_independent": false})
		_configure_character_identity(h)
		heroes.append(h)
	# First-stage assistance is a deployed guest, never a permanent recruit.
	if stage_id == "stage_01" and not run_state.squad.has("hero_13"):
		_add_reinforcement("hero_13", true)
	_apply_campaign_progression()
	_apply_team_resonances()
	_reset_follow_history()
	expedition = EndlessExpedition.new()
	if endless_mode: expedition.setup(self)

func _apply_campaign_progression() -> void:
	var fortify: int = int(run_state.campaign_perks.get("fortify", 0))
	if fortify > 0:
		base_max_hp += 25 * fortify
		base_hp += 25 * fortify
		for hero: Dictionary in heroes:
			var hp_bonus: float = float(hero.base_hp) * 0.08 * fortify
			hero.max_hp += hp_bonus
			hero.hp += hp_bonus
	var charged_start: int = int(run_state.campaign_perks.get("charged_start", 0))
	if charged_start > 0:
		for hero: Dictionary in heroes:
			hero.energy = minf(float(hero.max_energy), 18.0 * charged_start)
	var elemental_focus: int = int(run_state.campaign_perks.get("elemental_focus", 0))
	if elemental_focus > 0:
		reaction_damage_bonus += 0.12 * elemental_focus
	for relic_id: String in run_state.equipped_relics:
		_apply_relic(relic_id)
	if fortify > 0 or charged_start > 0 or elemental_focus > 0:
		events.append({"kind":"campaign_perk","pos":heroes[0].pos if not heroes.is_empty() else Vector2.ZERO,"value":run_state.campaign_perks.duplicate(true)})

func _apply_team_resonances() -> void:
	var resolved: Array[Dictionary] = TeamResonance.resolve(database.team_resonances, run_state, heroes)
	var active_ids: Array[String] = []
	for resonance: Dictionary in resolved:
		active_ids.append(str(resonance.id))
		var effects: Dictionary = resonance.get("effects", {})
		for hero: Dictionary in heroes:
			var health_bonus: float = float(hero.max_hp) * float(effects.get("health_mult", 0.0))
			hero.max_hp += health_bonus
			hero.hp += health_bonus
			hero.damage *= 1.0 + float(effects.get("attack_mult", 0.0))
			hero.rate *= 1.0 + float(effects.get("rate_mult", 0.0))
			hero.speed *= 1.0 + float(effects.get("move_mult", 0.0))
			hero.crit_chance = clampf(float(hero.get("crit_chance", 0.0)) + float(effects.get("crit_add", 0.0)), 0.0, 0.85)
			hero.energy = minf(float(hero.max_energy), float(hero.energy) + float(effects.get("energy_start", 0.0)))
		reaction_damage_bonus += float(effects.get("reaction_bonus", 0.0))
		crystal_shield += float(effects.get("base_shield", 0.0))
		run_state.luck += float(effects.get("luck_add", 0.0))
	run_state.active_resonances = active_ids
	if not resolved.is_empty():
		events.append({"kind":"team_resonance","pos":heroes[0].pos if not heroes.is_empty() else Vector2.ZERO,"value":active_ids.duplicate()})
func _configure_character_identity(hero: Dictionary) -> void:
	var character_id := str(hero.get("character_id", ""))
	hero.attack_style = "standard"
	match character_id:
		"traveler":
			hero.attack_style = "blade_wave"
			hero.cleave = true
			hero.cleave_ratio = 0.90
			hero.block = maxi(3, int(hero.block))
			hero.crit_chance = maxf(0.08, float(hero.crit_chance))
		"hero_01":
			hero.attack_style = "hydro_salon"
			hero.damage *= 1.18
			hero.pierce = maxi(1, int(hero.pierce))
			hero.slow = false
			hero.crit_chance = maxf(0.12, float(hero.crit_chance))
		"hero_02":
			hero.attack_style = "wind_seed"
			hero.rate *= 1.12
			hero.chain_count = maxi(1, int(hero.chain_count))
			hero.heal_power = maxf(52.0, float(hero.heal_power))
		"hero_03":
			hero.attack_style = "hydro_salon"
			hero.splash = true
			hero.blast_radius = maxf(78.0, float(hero.blast_radius))
			hero.echo_ratio = maxf(0.22, float(hero.echo_ratio))
		"hero_04":
			hero.attack_style = "tidal_orb"
			hero.damage *= 1.28
			hero.rate *= 0.86
			hero.splash = true
			hero.blast_radius = maxf(108.0, float(hero.blast_radius))
		"hero_05":
			hero.attack_style = "music_note"
			hero.damage *= 0.82
			hero.rate *= 1.18
			hero.projectile_count = maxi(2, int(hero.projectile_count))
			hero.echo_ratio = maxf(0.28, float(hero.echo_ratio))
		"hero_06":
			hero.attack_style = "arcane_lance"
			hero.damage *= 1.22
			hero.rate *= 0.90
			hero.pierce = maxi(2, int(hero.pierce))
			hero.crit_chance = maxf(0.18, float(hero.crit_chance))
		"hero_07":
			hero.attack_style = "music_note"
			hero.splash = true
			hero.blast_radius = maxf(82.0, float(hero.blast_radius))
			hero.chain_count = maxi(1, int(hero.chain_count))
		"hero_08":
			hero.attack_style = "frost_bloom"
			var health_gain := float(hero.max_hp) * 0.18
			hero.max_hp += health_gain
			hero.hp += health_gain
			hero.armor += 12.0
			hero.slow = true
			hero.blast_radius = maxf(70.0, float(hero.blast_radius))
		"hero_09":
			hero.attack_style = "music_note"
			hero.rate *= 1.22
			hero.echo_ratio = maxf(0.42, float(hero.echo_ratio))
		"hero_10":
			hero.attack_style = "wind_seed"
			hero.projectile_count = maxi(2, int(hero.projectile_count))
			hero.chain_count = maxi(2, int(hero.chain_count))
		"hero_11":
			hero.attack_style = "mon3tr"
			hero.block = maxi(2, int(hero.block))
			hero.damage_reduction = maxf(0.12, float(hero.damage_reduction))
			hero.splash = true
			hero.blast_radius = maxf(72.0, float(hero.blast_radius))
		"hero_13":
			hero.attack_style = "needle"
			hero.splash = true
			hero.blast_radius = maxf(52.0, float(hero.blast_radius))
		"hero_12":
			hero.attack_style = "ether_shot"
			hero.rate *= 1.25
			hero.chain_count = maxi(3, int(hero.chain_count))
			hero.crit_chance = maxf(0.15, float(hero.crit_chance))
	hero.base_damage = hero.damage
	hero.base_hp = hero.max_hp
	hero.base_rate = hero.rate

func _add_reinforcement(character_id: String, temporary_assist: bool = false) -> bool:
	if heroes.size() >= RunState.MAX_SQUAD_SIZE or not database.characters.has(character_id):
		return false
	var starts := [Vector2(505, 360), Vector2(375, 295), Vector2(345, 430)]
	if endless_mode:
		var center: Vector2 = heroes[0].pos if not heroes.is_empty() else ENDLESS_ARENA.get_center()
		starts = [center, center + Vector2(-86, -68), center + Vector2(-86, 68)]
	var colors := ["#e9d7ad", "#eaaa7d", "#83c7e8"]
	var i: int = heroes.size()
	var source: Dictionary = database.characters[character_id]
	var element: String = "" if source.element == "none" else str(source.element)
	var hero := {
		"character_id": character_id, "name": source.name, "role": source.role, "element": element, "secondary_element": "",
		"hp": float(source.max_hp), "armor": float(source.armor), "damage": float(source.attack),
		"rate": float(source.attack_rate), "range": float(source.attack_range), "speed": float(source.move_speed),
		"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": _nearest_walkable_point(starts[i], 17.0),
		"color": colors[i], "tile": Vector2(i * 16, 112), "visual": "furina" if character_id == "hero_03" else ""
	}
	hero.merge({"id": i, "max_hp": hero.hp, "target": hero.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": hero.damage, "base_hp": hero.hp, "base_rate": hero.rate, "cleave": false, "cleave_ratio": 0.45, "splash": false, "slow": false, "slime_slow_timer": 0.0, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0, "deployed": endless_mode, "energy": 0.0, "max_energy": float(source.get("ultimate", {}).get("energy_cost", 100.0)), "skill_cooldown": 0.0, "ultimate_cooldown": 0.0, "ultimate_cooldown_max": 0.0, "active_skill": source.get("active_skill", {}).duplicate(true), "ultimate": source.get("ultimate", {}).duplicate(true), "passive": source.get("passive", {}).duplicate(true), "animation_state":"idle", "status_timer":0.0, "damage_reduction":0.0, "damage_done": 0.0, "skill_uses": 0, "ultimate_uses": 0, "max_energy_seen": 0.0, "revived": false, "follow_independent": false})
	_configure_character_identity(hero)
	if temporary_assist:
		hero.temporary_assist = true
		hero.deployed = true
		run_state.temporary_assists.append(character_id)
	heroes.append(hero)
	if not temporary_assist:
		events.append({"kind": "reinforcement", "pos": hero.pos, "value": character_id})
	return true

func restart_current_stage() -> void:
	if v2_mode:
		reset_stage(current_stage_id, run_state.squad)
	else:
		reset()

func start() -> void:
	if state != "ready":
		return
	if v2_mode:
		state = "running"
		wave = 1
		events.append({"kind": "stage_start", "value": current_stage_id})
		return
	begin_wave()

func begin_wave() -> void:
	wave += 1
	state = "running"
	spawn_remaining = Catalog.WAVES[wave - 1].size()
	spawn_timer = 0.65
	events.append({"kind": "wave", "value": wave})

func reroll_rewards() -> bool:
	if not v2_mode or state != "reward" or rewards == null:
		return false
	return card_pool.reroll(run_state)

func choose_reward(index: int, target_hero_id: int = -1) -> bool:
	if state != "reward" or index < 0 or index >= rewards.offered.size():
		return false
	var picked: Dictionary = rewards.offered[index]
	var picked_name: String = str(picked.get("name", "强化"))
	var picked_rarity: String = str(picked.get("rarity", "common"))
	var taken: bool = rewards.take(index, self, target_hero_id) if v2_mode else rewards.take(index, self)
	if not taken:
		return false
	if endless_mode and expedition.cards_remaining > 0:
		events.append({"kind":"reward_taken","pos":heroes[0].pos,"value":picked_name,"rarity":picked_rarity})
		expedition.choose_next(self)
		return true
	if not debug_reward_resume_state.is_empty():
		state = debug_reward_resume_state
		debug_reward_resume_state = ""
		events.append({"kind": "reward_taken", "pos": heroes[0].pos if not heroes.is_empty() else Vector2(420, 360), "value": picked_name, "rarity": picked_rarity})
		return true
	if v2_mode:
		crystal.consume_choice(run_state)
		team_level = run_state.crystal_level
		team_xp = run_state.crystal_xp
		reward_cooldown = 14.0
		state = "running"
		events.append({"kind": "reward_taken", "pos": heroes[0].pos if not heroes.is_empty() else Vector2(420, 360), "value": picked_name, "rarity": picked_rarity})
		return true
	state = "between"
	wave_timer = 4.0
	events.append({"kind": "reward_taken", "pos": heroes[0].pos if not heroes.is_empty() else Vector2(420, 360), "value": picked_name, "rarity": picked_rarity})
	return true

func open_reward_or_compensate(consume_levelup: bool = false, resume_state: String = "running") -> bool:
	rewards.draw(self)
	if not rewards.offered.is_empty():
		state="reward"
		return true
	if consume_levelup and v2_mode and run_state.pending_level_ups>0:
		crystal.consume_choice(run_state)
	state=resume_state
	return false

func begin_debug_reward() -> bool:
	if not v2_mode or state != "paused" or rewards == null:
		return false
	if not open_reward_or_compensate(false,"paused"):
		return false
	debug_reward_resume_state = "paused"
	state = "reward"
	events.append({"kind": "debug_reward_opened"})
	return true

func toggle_pause() -> void:
	if state == "paused":
		state = previous_state
	elif state in ["running", "between"]:
		previous_state = state
		state = "paused"

func base_world_position() -> Vector2:
	var visual_id := str(database.stages.get(current_stage_id, {}).get("visual_stage_id", current_stage_id)) if database != null else current_stage_id
	return Vector2(130, 395) if visual_id == "stage_01" else Vector2(100, 365)

func command_workshop_enemy_move(enemy_id: int, point: Vector2) -> bool:
	if not workshop_mode: return false
	var enemy := find_enemy(enemy_id)
	if enemy.is_empty() or float(enemy.get("speed", 0.0)) <= 0.0: return false
	enemy["workshop_move_target"] = point
	return true

func command_move(hero_id: int, point: Vector2, show_feedback: bool = true) -> void:
	if state not in ["running", "between", "stage_exit"] or hero_id < 0 or hero_id >= heroes.size():
		return
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0 or not bool(hero.get("deployed", true)):
		return
	if formation_mode == "follow":
		set_follow_leader(hero_id)
	var area := ENDLESS_ARENA if endless_mode else (STAGE_EXIT_AREA if state == "stage_exit" else MOVE_AREA)
	hero.target = _resolve_walkable_target(Vector2(clampf(point.x, area.position.x, area.end.x), clampf(point.y, area.position.y, area.end.y)))
	if absf(hero.target.x - hero.pos.x) > 1.0:
		hero.facing = 1.0 if hero.target.x > hero.pos.x else -1.0
	if show_feedback:
		events.append({"kind": "move", "pos": hero.target, "hero_id": hero_id})

func command_squad(point: Vector2) -> void:
	if state not in ["running", "between"] or heroes.is_empty():
		return
	formation_mode = "squad"
	var offsets := [Vector2(0, 0), Vector2(-72, -58), Vector2(-72, 58)]
	for i in heroes.size():
		command_move(i, point + offsets[i])
	events.append({"kind": "formation", "pos": point, "value": "squad"})

func set_formation_mode(next_mode: String) -> bool:
	if next_mode not in ["follow", "hold"]:
		return false
	formation_mode = next_mode
	for hero: Dictionary in heroes:
		hero.target = hero.pos
		hero.moving = false
	if next_mode == "follow":
		_reset_follow_history()
	events.append({"kind": "formation", "pos": heroes[0].pos if not heroes.is_empty() else Vector2.ZERO, "value": next_mode})
	return true

func set_follow_leader(hero_id: int) -> bool:
	if hero_id < 0 or hero_id >= heroes.size():
		return false
	var leader: Dictionary = heroes[hero_id]
	if float(leader.get("hp", 0.0)) <= 0.0 or not bool(leader.get("deployed", true)):
		return false
	if endless_mode and follow_leader_id == hero_id:
		return true
	follow_leader_id = hero_id
	for hero: Dictionary in heroes:
		hero.follow_independent = false
	_reset_follow_history()
	return true

func _load_terrain(stage_definition: Dictionary) -> void:
	endless_blocker_index_ready=false
	terrain_features.clear()
	var claimed_grid_cells := {}
	var route_grid_cells := _route_grid_keys(stage_definition)
	var visual_stage_id := str(stage_definition.get("visual_stage_id", current_stage_id))
	for value: Variant in stage_definition.get("terrain", []):
		if not value is Dictionary:
			continue
		var feature: Dictionary = value.duplicate(true)
		var raw_rect: Array = feature.get("rect", [])
		if raw_rect.size() < 4:
			continue
		feature.area = Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		var feature_type := str(feature.get("type", ""))
		# Campaign buff tiles now come only from purchased one-cell devices.
		if not endless_mode and feature_type in ["high_ground", "attack_ground"]:
			continue
		if visual_stage_id != "stage_01" and not endless_mode and feature_type in ["blocked", "trap", "low_ground"]:
			var forbidden_cells: Dictionary = route_grid_cells if feature_type == "blocked" else {}
			feature.grid_cells = _claim_grid_cells(_grid_cells_for_area(feature.area), claimed_grid_cells, feature.area.get_center(), forbidden_cells)
			feature.area = _grid_cells_bounds(feature.grid_cells)
		feature.base_area = feature.area
		feature.clock = 0.0
		feature.timer = minf(1.0, float(feature.get("interval", 4.0)))
		feature.hp = float(feature.get("hp", 0.0))
		feature.max_hp = float(feature.hp)
		terrain_features.append(feature)

func _grid_cells_for_area(area: Rect2) -> Array[Rect2]:
	var first_col := clampi(floori((area.position.x - GRID_ORIGIN.x) / GRID_CELL_SIZE.x), 0, GRID_COLUMNS - 1)
	var last_col := clampi(ceili((area.end.x - GRID_ORIGIN.x) / GRID_CELL_SIZE.x) - 1, 0, GRID_COLUMNS - 1)
	var first_row := clampi(floori((area.position.y - GRID_ORIGIN.y) / GRID_CELL_SIZE.y), 0, GRID_ROWS - 1)
	var last_row := clampi(ceili((area.end.y - GRID_ORIGIN.y) / GRID_CELL_SIZE.y) - 1, 0, GRID_ROWS - 1)
	var cells: Array[Rect2] = []
	for row in range(first_row, last_row + 1):
		for column in range(first_col, last_col + 1):
			cells.append(Rect2(GRID_ORIGIN + Vector2(column * GRID_CELL_SIZE.x, row * GRID_CELL_SIZE.y), GRID_CELL_SIZE))
	return cells

func _grid_cell_key(cell: Rect2) -> String:
	var column := roundi((cell.position.x - GRID_ORIGIN.x) / GRID_CELL_SIZE.x)
	var row := roundi((cell.position.y - GRID_ORIGIN.y) / GRID_CELL_SIZE.y)
	return "%d:%d" % [column, row]

func _route_grid_keys(stage_definition: Dictionary) -> Dictionary:
	var protected := {}
	var configured_routes: Dictionary = stage_definition.get("routes", {})
	for raw_route: Variant in configured_routes.values():
		var points: Array[Vector2] = []
		for raw_point: Variant in raw_route:
			if raw_point is Array and raw_point.size() >= 2:
				points.append(Vector2(float(raw_point[0]), float(raw_point[1])))
		points = _orthogonalize_route(points)
		for index in range(maxi(0, points.size() - 1)):
			for row in GRID_ROWS:
				for column in GRID_COLUMNS:
					var cell := Rect2(GRID_ORIGIN + Vector2(column * GRID_CELL_SIZE.x, row * GRID_CELL_SIZE.y), GRID_CELL_SIZE)
					if _segment_hits_rect(points[index], points[index + 1], cell.grow(20.0)):
						protected[_grid_cell_key(cell)] = true
	return protected

func _claim_grid_cells(candidates: Array[Rect2], claimed: Dictionary, center: Vector2, forbidden: Dictionary = {}) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	for cell: Rect2 in candidates:
		var key := _grid_cell_key(cell)
		if claimed.has(key) or forbidden.has(key):
			continue
		claimed[key] = true
		cells.append(cell)
	if not cells.is_empty():
		return cells
	var alternatives: Array[Rect2] = []
	for row in GRID_ROWS:
		for column in GRID_COLUMNS:
			alternatives.append(Rect2(GRID_ORIGIN + Vector2(column * GRID_CELL_SIZE.x, row * GRID_CELL_SIZE.y), GRID_CELL_SIZE))
	alternatives.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.get_center().distance_squared_to(center) < b.get_center().distance_squared_to(center))
	for cell: Rect2 in alternatives:
		var key := _grid_cell_key(cell)
		if not claimed.has(key) and not forbidden.has(key):
			claimed[key] = true
			return [cell]
	return cells

func _grid_cells_bounds(cells: Array) -> Rect2:
	if cells.is_empty():
		return Rect2()
	var bounds: Rect2 = cells[0]
	for i in range(1, cells.size()):
		bounds = bounds.merge(Rect2(cells[i]))
	return bounds

func _feature_collision_rect(feature: Dictionary) -> Rect2:
	var area := Rect2(feature.get("area", Rect2()))
	var raw_scale: Array = feature.get("collision_scale", [1.0, 1.0])
	var scale := Vector2(float(raw_scale[0]), float(raw_scale[1])) if raw_scale.size() >= 2 else Vector2.ONE
	var raw_offset: Array = feature.get("collision_offset", [0.0, 0.0])
	var offset := Vector2(float(raw_offset[0]), float(raw_offset[1])) if raw_offset.size() >= 2 else Vector2.ZERO
	var size := area.size * scale
	return Rect2(area.get_center() + offset - size * 0.5, size)

func _feature_contains(feature: Dictionary, point: Vector2, radius: float = 0.0) -> bool:
	var grid_cells: Array = feature.get("grid_cells", [])
	if not grid_cells.is_empty():
		for cell: Variant in grid_cells:
			if Rect2(cell).grow(radius).has_point(point):
				return true
		return false
	var collision := _feature_collision_rect(feature)
	if str(feature.get("collision_shape", "rect")) != "ellipse":
		return collision.grow(radius).has_point(point)
	var radii := collision.size * 0.5 + Vector2.ONE * radius
	if radii.x <= 0.0 or radii.y <= 0.0:
		return false
	var normalized := (point - collision.get_center()) / radii
	return normalized.length_squared() <= 1.0

func terrain_feature_at(point: Vector2, kind: String = "") -> Dictionary:
	for feature: Dictionary in terrain_features:
		if not kind.is_empty() and str(feature.get("type", "")) != kind:
			continue
		if _feature_contains(feature, point):
			return feature
	return {}

func terrain_attack_scale(point: Vector2) -> float:
	var feature := terrain_feature_at(point, "attack_ground")
	var base := 1.0 + float(feature.get("attack_bonus", 1.0)) if not feature.is_empty() else 1.0
	return base * battle_devices.scale_at(point, "power")

func terrain_movement_scale(point: Vector2) -> float:
	var feature := terrain_feature_at(point, "low_ground")
	var scale := float(feature.get("speed_scale", 0.30)) if not feature.is_empty() else 1.0
	var weather := terrain_feature_at(point, "weather")
	if not weather.is_empty() and str(weather.get("element", "")) == "cryo":
		scale *= 0.88
	return scale

func _movement_bounds() -> Rect2:
	return ENDLESS_ARENA.grow(-28.0) if endless_mode else MOVE_AREA.grow(-18.0)

func _nearest_walkable_point(point: Vector2, radius: float = 17.0) -> Vector2:
	var bounds := _movement_bounds()
	var origin := Vector2(clampf(point.x, bounds.position.x, bounds.end.x), clampf(point.y, bounds.position.y, bounds.end.y))
	if not _terrain_blocks(origin, radius):
		return origin
	for ring in range(1, 13):
		var distance := float(ring) * 18.0
		for step in range(24):
			var candidate := origin + Vector2.from_angle(TAU * float(step) / 24.0) * distance
			candidate = Vector2(clampf(candidate.x, bounds.position.x, bounds.end.x), clampf(candidate.y, bounds.position.y, bounds.end.y))
			if not _terrain_blocks(candidate, radius):
				return candidate
	return bounds.get_center()

func _resolve_walkable_target(point: Vector2) -> Vector2:
	return _nearest_walkable_point(point, 17.0)

func _feature_blocks(feature: Dictionary) -> bool:
	var kind := str(feature.get("type", ""))
	return kind == "blocked" or (kind in ["shortcut", "door"] and float(feature.get("hp", 0.0)) > 0.0)

func _terrain_blocks(point: Vector2, radius: float = 7.0) -> bool:
	return not _terrain_blocker_at(point, radius).is_empty()

func _terrain_blocker_at(point: Vector2, radius: float = 7.0) -> Dictionary:
	for feature: Dictionary in _blocker_candidates(Rect2(point,Vector2.ZERO).grow(radius)):
		if _feature_blocks(feature) and _feature_contains(feature, point, radius):
			return feature
	return {}

func _segment_hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var delta := to - from
	var t_min := 0.0
	var t_max := 1.0
	if absf(delta.x) < 0.0001:
		if from.x < rect.position.x or from.x > rect.end.x:
			return false
	else:
		var tx1 := (rect.position.x - from.x) / delta.x
		var tx2 := (rect.end.x - from.x) / delta.x
		if tx1 > tx2:
			var swap_x := tx1
			tx1 = tx2
			tx2 = swap_x
		t_min = maxf(t_min, tx1)
		t_max = minf(t_max, tx2)
		if t_min > t_max:
			return false
	if absf(delta.y) < 0.0001:
		return from.y >= rect.position.y and from.y <= rect.end.y
	var ty1 := (rect.position.y - from.y) / delta.y
	var ty2 := (rect.end.y - from.y) / delta.y
	if ty1 > ty2:
		var swap_y := ty1
		ty1 = ty2
		ty2 = swap_y
	t_min = maxf(t_min, ty1)
	t_max = minf(t_max, ty2)
	return t_min <= t_max

func _segment_hits_ellipse(from: Vector2, to: Vector2, ellipse_rect: Rect2, radius: float = 0.0) -> bool:
	var radii := ellipse_rect.size * 0.5 + Vector2.ONE * radius
	if radii.x <= 0.0 or radii.y <= 0.0:
		return false
	var start := (from - ellipse_rect.get_center()) / radii
	var finish := (to - ellipse_rect.get_center()) / radii
	var delta := finish - start
	var length_sq := delta.length_squared()
	var t := clampf(-start.dot(delta) / length_sq, 0.0, 1.0) if length_sq > 0.0001 else 0.0
	return (start + delta * t).length_squared() <= 1.0

func _feature_segment_hits(feature: Dictionary, from: Vector2, to: Vector2, radius: float) -> bool:
	var collision := _feature_collision_rect(feature)
	if str(feature.get("collision_shape", "rect")) == "ellipse":
		return _segment_hits_ellipse(from, to, collision, radius)
	return _segment_hits_rect(from, to, collision.grow(radius))

func _terrain_blocker_on_segment(from: Vector2, to: Vector2, radius: float = 5.0) -> Dictionary:
	for feature: Dictionary in _blocker_candidates(Rect2(from,to-from).abs().grow(radius)):
		if _feature_blocks(feature) and _feature_segment_hits(feature, from, to, radius):
			return feature
	return {}

func terrain_line_blocked(from: Vector2, to: Vector2, radius: float = 5.0) -> bool:
	return not _terrain_blocker_on_segment(from, to, radius).is_empty()

func _move_with_terrain(current: Vector2, target: Vector2, distance: float, radius: float = 16.0) -> Vector2:
	if current.distance_squared_to(target) <= 0.01:
		return current
	var direct := current.move_toward(target, distance)
	var blocker := _terrain_blocker_on_segment(current, direct, radius)
	if blocker.is_empty():
		return direct
	var obstacle: Rect2 = _feature_collision_rect(blocker).grow(radius + 7.0)
	var waypoints := [
		Vector2(obstacle.position.x - 2.0, obstacle.position.y - 2.0),
		Vector2(obstacle.end.x + 2.0, obstacle.position.y - 2.0),
		Vector2(obstacle.position.x - 2.0, obstacle.end.y + 2.0),
		Vector2(obstacle.end.x + 2.0, obstacle.end.y + 2.0),
	]
	waypoints.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return current.distance_to(a) + a.distance_to(target) < current.distance_to(b) + b.distance_to(target))
	for waypoint: Vector2 in waypoints:
		var candidate := current.move_toward(waypoint, distance)
		if _terrain_blocker_on_segment(current, candidate, radius).is_empty():
			return candidate
	return current

func _move_hero_with_terrain(hero: Dictionary, dt: float) -> void:
	# Victory is a cinematic: combat obstacles and slows must not trap the exit.
	if state == "stage_exit":
		hero.pos = Vector2(hero.pos).move_toward(hero.target, maxf(245.0, float(hero.speed)) * dt)
		return
	if _terrain_blocks(hero.pos, 17.0):
		hero.pos = _nearest_walkable_point(hero.pos, 17.0)
		hero.target = hero.pos
	else:
		hero.target = _nearest_walkable_point(hero.target, 17.0)
	var slow_scale := 0.45 if float(hero.get("slime_slow_timer", 0.0)) > 0.0 else 1.0
	var distance := float(hero.speed) * terrain_movement_scale(hero.pos) * slow_scale * dt
	var move_target: Vector2 = hero.target
	if endless_mode:
		move_target = _endless_hero_waypoint(hero,dt)
		if formation_mode=="follow" and int(hero.id)!=_resolve_follow_leader_id():
			var leader_id := _resolve_follow_leader_id()
			if leader_id>=0:
				var gap: float = Vector2(hero.pos).distance_to(heroes[leader_id].pos)
				distance *= lerpf(1.0,1.60,clampf((gap-150.0)/300.0,0.0,1.0))
	var previous: Vector2=hero.pos
	hero.pos = _move_with_terrain(hero.pos, move_target, distance, 17.0)
	if endless_mode and Vector2(hero.pos).distance_squared_to(previous)>.001:
		hero.endless_move_direction=(Vector2(hero.pos)-previous).normalized()
		if absf(float(hero.pos.x)-previous.x)>.1: hero.facing=signf(float(hero.pos.x)-previous.x)

func _reset_follow_history() -> void:
	follow_history.clear()
	follow_sample_timer = 0.0
	var leader_id := _resolve_follow_leader_id()
	if leader_id < 0:
		return
	var leader_pos: Vector2 = heroes[leader_id].pos
	for index in 18:
		follow_history.append({"time": elapsed - 1.7 + index * 0.1, "pos": leader_pos})

func _update_follow_targets(dt: float) -> void:
	if formation_mode != "follow" or heroes.is_empty():
		return
	var leader_id := _resolve_follow_leader_id()
	if leader_id < 0:
		return
	if leader_id != follow_leader_id:
		follow_leader_id = leader_id
		_reset_follow_history()
	var leader: Dictionary = heroes[leader_id]
	follow_sample_timer -= dt
	if follow_sample_timer <= 0.0:
		follow_history.append({"time": elapsed, "pos": Vector2(leader.pos)})
		follow_sample_timer += 0.06
	while follow_history.size() > 2 and float(follow_history[0].time) < elapsed - 2.8:
		follow_history.pop_front()
	var follower_rank := 0
	for i in heroes.size():
		if i == leader_id or float(heroes[i].get("hp", 0.0)) <= 0.0 or not bool(heroes[i].get("deployed", true)):
			continue
		var delayed_time := elapsed - (0.24 + float(follower_rank) * 0.16)
		var delayed_pos: Vector2 = follow_history[0].pos if not follow_history.is_empty() else leader.pos
		for sample: Dictionary in follow_history:
			if float(sample.time) > delayed_time:
				break
			delayed_pos = sample.pos
		var side := -1.0 if follower_rank % 2 == 0 else 1.0
		var row := floori(float(follower_rank) / 2.0)
		var follow_offset := Vector2(-82.0 - row * 20.0, side * (58.0 + row * 18.0))
		if endless_mode:
			# Interpolate the trail and rotate the compact formation with actual travel direction.
			for index in range(1,follow_history.size()):
				var before: Dictionary=follow_history[index-1]
				var after: Dictionary=follow_history[index]
				if float(before.time)<=delayed_time and float(after.time)>=delayed_time:
					delayed_pos=Vector2(before.pos).lerp(Vector2(after.pos),clampf((delayed_time-float(before.time))/maxf(.001,float(after.time)-float(before.time)),0,1))
					break
			var heading: Vector2=leader.get("endless_move_direction",Vector2(float(leader.get("facing",1)),0))
			var ground_heading := Vector2(heading.x,heading.y/.4).normalized()
			var compact := -ground_heading*(66.0+row*22.0)+ground_heading.orthogonal()*side*(44.0+row*12.0)
			follow_offset=Vector2(compact.x,compact.y*.4)
			if terrain_line_blocked(delayed_pos,delayed_pos+follow_offset,17.0): follow_offset=Vector2(-ground_heading.x*38.0,-ground_heading.y*.4*38.0)
		heroes[i].target = _resolve_walkable_target(delayed_pos + follow_offset)
		follower_rank += 1

func _resolve_follow_leader_id() -> int:
	if follow_leader_id >= 0 and follow_leader_id < heroes.size():
		var current: Dictionary = heroes[follow_leader_id]
		if float(current.get("hp", 0.0)) > 0.0 and bool(current.get("deployed", true)):
			return follow_leader_id
	for index in heroes.size():
		var candidate: Dictionary = heroes[index]
		if float(candidate.get("hp", 0.0)) > 0.0 and bool(candidate.get("deployed", true)):
			return index
	return -1

func damage_terrain_shortcuts(center: Vector2, radius: float, damage: float) -> int:
	var broken := 0
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) not in ["shortcut", "door"] or float(feature.get("hp", 0.0)) <= 0.0:
			continue
		if not is_in_ability_area(center, feature.area.get_center(), radius):
			continue
		feature.hp = maxf(0.0, float(feature.hp) - damage)
		events.append({"kind": "terrain_hit", "pos": feature.area.get_center(), "value": ceili(damage)})
		if feature.hp <= 0.0:
			feature.broken = true
			broken += 1
			events.append({"kind": "terrain_break", "pos": feature.area.get_center(), "value": str(feature.get("label", "捷径"))})
	return broken

func _terrain_tick(dt: float) -> void:
	if endless_mode:
		return
	for feature: Dictionary in terrain_features:
		var kind := str(feature.get("type", ""))
		feature.clock = float(feature.get("clock", 0.0)) + dt
		feature.timer = maxf(0.0, float(feature.get("timer", 0.0)) - dt)
		if kind not in ["mechanism", "trap", "weather"] or feature.timer > 0.0:
			continue
		if kind == "weather":
			feature.timer = float(feature.get("pulse_interval", 8.0))
			events.append({"kind":"weather_pulse","pos":feature.area.get_center(),"value":str(feature.get("element","anemo"))})
			continue
		var active: bool = kind == "trap" or heroes.any(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false)) and hero.hp > 0.0 and feature.area.grow(95.0).has_point(hero.pos))
		if not active:
			continue
		var hit_count := 0
		for enemy: Dictionary in enemies.duplicate():
			var in_area: bool = feature.area.has_point(enemy.pos) if kind == "trap" else enemy.pos.distance_to(feature.area.get_center()) <= float(feature.get("radius", 185.0))
			if enemy.hp > 0.0 and in_area:
				apply_hit(enemy, float(feature.get("power", 60.0)), str(feature.get("element", "pyro"))); hit_count += 1
		if kind == "trap":
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and feature.area.has_point(hero.pos):
					damage_hero(int(hero.id), float(feature.get("hero_power", 14.0)), {"source_name":"危险地砖","source_skill":"持续灼伤"}); hit_count += 1
		feature.timer = float(feature.get("interval", 3.5))
		if hit_count > 0:
			events.append({"kind":"trap_pulse" if kind == "trap" else "mechanism_pulse","pos":feature.area.get_center(),"value":hit_count})

func spawn_enemy(point: Vector2, kind: String = "grunt") -> Dictionary:
	projectile_neighbor_cache.clear()
	projectile_chain_cache.clear()
	projectile_range_enemies.clear()
	projectile_splash_cache.clear()
	projectile_enemy_bins.clear()
	projectile_bins_ready = false
	var enemy: Dictionary = Catalog.ENEMIES[kind].duplicate(true)
	if v2_mode and database != null and database.enemy_families.has(kind):
		var family_definition: Dictionary = database.enemy_families[kind]
		enemy.merge({"family":family_definition.get("family", "rift"), "variant":family_definition.get("variant", kind), "behavior":family_definition.get("behavior", "pressure_advance"), "motion":family_definition.get("motion", "elastic_hop"), "visual_family":family_definition.get("visual", kind)}, true)
	if v2_mode and not bool(enemy.get("flying", false)):
		point = _nearest_walkable_point(point, maxf(12.0, float(enemy.get("size", 28.0)) * 0.34))
	enemy.hp *= 1.40
	# Ground pressure is deliberately much higher than airborne pressure.
	if not bool(enemy.get("flying", false)):
		enemy.hp *= 3.0
	var campaign_level := mini(8,maxi(1,floori(elapsed/55.0)+1)) if v2_mode and not endless_mode else maxi(1,wave)
	var campaign_health_scale := 1.0
	var campaign_damage_scale := 1.0
	if not endless_mode:
		if kind.begins_with("boss_"):
			campaign_health_scale = CAMPAIGN_BOSS_HEALTH_MULTIPLIER
			campaign_damage_scale = CAMPAIGN_BOSS_DAMAGE_MULTIPLIER
		elif v2_mode:
			campaign_health_scale=0.75*pow(1.23,campaign_level-1)
			campaign_damage_scale=3.0*pow(1.13,campaign_level-1)
		else:
			campaign_health_scale = CAMPAIGN_MINION_BASE_MULTIPLIER * pow(CAMPAIGN_MINION_HEALTH_GROWTH, campaign_level - 1) * minf(1.0, 0.25 + 0.075 * (campaign_level - 1))
			campaign_damage_scale = CAMPAIGN_MINION_BASE_MULTIPLIER * pow(CAMPAIGN_MINION_DAMAGE_GROWTH, campaign_level - 1)
	enemy.hp *= campaign_health_scale
	enemy.damage *= campaign_damage_scale
	if v2_mode and stage_runtime != null:
		enemy.hp *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		if kind.begins_with("boss_") and not endless_mode:
			enemy.hp *= float(stage_runtime.definition.get("boss_health_multiplier", 1.0))
		enemy.damage *= float(stage_runtime.definition.get("enemy_damage_multiplier", 1.0))
		enemy.speed *= float(stage_runtime.definition.get("enemy_speed_multiplier", 1.0))
		enemy.leak = maxi(1, roundi(float(enemy.leak) * float(stage_runtime.definition.get("enemy_leak_multiplier", 1.0))))
	next_id += 1
	var shield: float = float(enemy.get("shield", 0.0))
	shield *= campaign_health_scale
	if v2_mode and stage_runtime != null:
		shield *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		if kind.begins_with("boss_") and not endless_mode:
			shield *= float(stage_runtime.definition.get("boss_health_multiplier", 1.0))
	var xp_values := {"grunt": 10, "runner": 8, "armored": 22, "flyer": 12, "ranged": 15, "buffer": 24, "shielded": 38, "charger": 20, "healer": 30, "splitter": 42, "warder": 32, "slime_pyro": 11, "slime_electro": 11, "slime_anemo": 12, "slime_hydro": 14, "slime_cryo": 16, "boss_01": 240, "boss_02": 280, "boss_03": 260, "boss_galio": 360, "boss_04": 320, "boss_05": 290, "boss_06": 310}
	var first_special: float = float(enemy.get("boss_pulse", enemy.get("spawn_interval", enemy.get("heal_interval", enemy.get("ward_interval", 0.0)))))
	var intrinsic_element := _intrinsic_enemy_element(kind)
	enemy.merge({"id": next_id, "kind": kind, "level": campaign_level, "pos": point, "facing": -1.0, "max_hp": enemy.hp, "flash": 0.0, "attack_timer": 0.7, "blocked_by": -1, "aura": intrinsic_element, "intrinsic_element": intrinsic_element, "aura_timer": INF if not intrinsic_element.is_empty() else 0.0, "reaction_timer": 0.0, "slow_timer": 0.0, "frozen_timer": 0.0, "haste_timer": 0.0, "shield": shield, "max_shield": shield, "special_timer": first_special, "split_done": false, "boss_phase": 1, "boss_cast_index": 0, "special_move": "pulse", "summons_done": 0, "route_points": [], "route_index": 0, "route_id": "", "xp": int(xp_values.get(kind, 10)), "attack_pending": false, "warning_timer": 0.0, "warning_pos": point, "warning_radius": 58.0, "special_pending": false, "special_warning": 0.0, "affixes": [], "affix_timer": 3.5, "nav_probe_timer": 0.0, "nav_clear": false, "lod_accumulator": fposmod(float(next_id) * 0.037, 0.20), "kindred_respite_used": false, "kindred_respite_active": false, "kindred_respite_timer": 0.0, "kindred_respite_center": point, "kindred_respite_radius": 285.0, "galio_summoned": false})
	if not endless_mode and stage_runtime != null and not kind.begins_with("boss_"):
		enemy.xp = maxi(1,roundi(float(enemy.xp)*float(stage_runtime.definition.get("pacing_xp_multiplier",1))))
		var opening_scale := lerpf(float(stage_runtime.definition.get("opening_health_scale", 1.0)), 1.0, clampf(elapsed / 120.0, 0.0, 1.0))
		enemy.hp *= float(stage_runtime.definition.get("pacing_health_multiplier", 1.0)) * opening_scale
		enemy.max_hp = enemy.hp
	_apply_enemy_affix(enemy)
	EnemyTactics.initialize(enemy)
	if kind == "buffer":
		enemy.spawn_phase = "fall"
		enemy.spawn_timer = 0.55
		enemy.spawn_total = 0.55
		enemy.attack_pending = false
	enemies.append(enemy)
	enemy_lookup[int(enemy.id)] = enemy
	events.append({"kind":"enemy_arrival","enemy_kind":kind,"enemy_id":enemy.id,"pos":point})
	return enemy

func _intrinsic_enemy_element(kind: String) -> String:
	return {
		"slime_pyro":"pyro", "slime_electro":"electro", "slime_anemo":"anemo",
		"slime_hydro":"hydro", "slime_cryo":"cryo"
	}.get(kind, "")

func find_enemy(id: int) -> Dictionary:
	var enemy: Dictionary = enemy_lookup.get(id, {})
	return enemy if not enemy.is_empty() and float(enemy.get("hp", 0.0)) > 0.0 else {}

func _reset_projectile_queries() -> void:
	projectile_query_active=false
	projectile_bins_ready=false
	projectile_enemy_bins.clear()
	projectile_neighbor_cache.clear()
	projectile_chain_cache.clear()
	projectile_range_enemies.clear()
	projectile_splash_cache.clear()
	projectile_range_cache.clear()
	attack_geometry_cache.clear()
	hit_feedback_cache.clear()

func tick(dt: float) -> void:
	attack_geometry_cache.clear()
	projectile_query_active = false
	projectile_bins_ready = false
	projectile_enemy_bins.clear()
	projectile_neighbor_cache.clear()
	projectile_chain_cache.clear()
	projectile_range_enemies.clear()
	projectile_splash_cache.clear()
	projectile_range_cache.clear()
	projectile_range_enemies.clear()
	if reward_cooldown > 0.0:
		reward_cooldown = maxf(0.0, reward_cooldown - dt)
	if not workshop_mode and v2_mode and state == "running" and run_state.pending_level_ups > 0 and reward_cooldown <= 0.0:
		open_reward_or_compensate(true)
	if kill_streak_timer > 0.0:
		kill_streak_timer = maxf(0.0, kill_streak_timer - dt)
		if kill_streak_timer <= 0.0:
			kill_streak = 0
	var projectile_load := projectiles.size() + enemy_projectiles.size() + enemy_hazards.size() * 2 + skill_effects.size()
	performance_budget.sample(dt*1000.0,enemies.size(),projectile_load)
	for hero: Dictionary in heroes:
		if float(hero.get("status_timer",0.0)) > 0.0:
			hero.status_timer = maxf(0.0,float(hero.status_timer)-dt)
			if hero.status_timer <= 0.0: hero.animation_state = "run" if bool(hero.get("moving",false)) else "idle"
	if state not in ["running", "between", "stage_exit"]:
		return
	elapsed += dt
	traveler_skill_cooldown = maxf(0.0, traveler_skill_cooldown - dt)
	_pending_impact_tick(dt)
	_orbital_tick(dt)
	_evolution_tick(dt)
	_update_follow_targets(dt)
	for h in heroes:
		h.blocked = 0
		h.skill_cooldown = maxf(0.0, float(h.get("skill_cooldown", 0.0)) - dt)
		h.ultimate_cooldown = maxf(0.0, float(h.get("ultimate_cooldown", 0.0)) - dt)
		h.flash = maxf(0.0, h.flash - dt)
		h.invulnerable_timer = maxf(0.0, float(h.get("invulnerable_timer", 0.0)) - dt)
		h.slime_slow_timer = maxf(0.0, float(h.get("slime_slow_timer", 0.0)) - dt)
		h.moving = h.hp > 0 and bool(h.get("deployed", true)) and h.pos.distance_to(h.target) > 0.5
		if float(h.get("status_timer",0.0)) <= 0.0: h.animation_state = "run" if h.moving else "idle"
		if h.moving:
			if absf(h.target.x - h.pos.x) > 1.0:
				h.facing = 1.0 if h.target.x > h.pos.x else -1.0
			_move_hero_with_terrain(h, dt)
		h.attack_timer = maxf(0.0, h.attack_timer - dt)
		h.heal_timer = maxf(0.0, h.heal_timer - dt)
		var card_healing: float = CombatCardEffects.tick(h, dt)
		if card_healing > 0.0:
			events.append({"kind": "heal", "pos": h.pos, "value": ceili(card_healing)})
	if state == "stage_exit":
		return
	if state == "between":
		wave_timer -= dt
		if wave_timer <= 0:
			begin_wave()
		return
	if workshop_mode:
		pass # A workshop only contains units placed by the author.
	elif endless_mode:
		_endless_spawn_tick(dt)
	elif v2_mode:
		_stage_spawn_tick(dt)
	else:
		_spawn_tick(dt)
	_troop_spawn_tick(dt)
	_skill_effect_tick(dt)
	_terrain_tick(dt)
	_enemy_tick(dt)
	# One stable spatial snapshot covers plants, hero aiming and all friendly shots.
	# Damage/spawning invalidate it explicitly; movement finished immediately above.
	projectile_query_active = true
	projectile_bins_ready = false
	projectile_enemy_bins.clear()
	_enemy_projectile_tick(dt)
	_enemy_hazard_tick(dt)
	battle_devices.tick(self, dt)
	if endless_mode and not workshop_mode: expedition.tick(self, dt)
	var party_wiped := endless_mode and (heroes.is_empty() or heroes.all(func(hero: Dictionary) -> bool: return float(hero.get("hp", 0.0)) <= 0.0))
	if not workshop_mode and (base_hp <= 0 or party_wiped):
		state = "lost"
		projectiles.clear()
		enemy_projectiles.clear()
		enemy_hazards.clear()
		events.append({"kind": "lost"})
		return
	_hero_tick()
	_projectile_tick(dt)
	_support_tick(dt)
	projectile_query_active = false
	_contract_tick()
	if endless_mode and not workshop_mode: expedition.open_reward(self)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0 or bool(e.get("revive_pending", false)))
	if workshop_mode:
		return
	if v2_mode and not endless_mode:
		if stage_runtime.time_complete and stage_runtime.all_spawns_emitted and pending_stage_spawns.is_empty() and pending_troop_spawns.is_empty() and enemies.is_empty() and projectiles.is_empty() and not pending_impacts.any(func(p: Dictionary) -> bool: return p.kind=="bug_blast"):
			state = "won"
			events.append({"kind": "won"})
		return
	elif not v2_mode and spawn_remaining == 0 and enemies.is_empty() and projectiles.is_empty() and not pending_impacts.any(func(p: Dictionary) -> bool: return p.kind=="bug_blast"):
		if wave == Catalog.WAVES.size():
			state = "won"
			events.append({"kind": "won"})
		else:
			state = "reward"
			wave_timer = 0.0
			for h in heroes:
				h.hp = h.max_hp * 0.5 if h.hp <= 0 else minf(h.max_hp, h.hp + h.max_hp * regroup_ratio)
				h.blocked = 0
			open_reward_or_compensate(false,"between")
			events.append({"kind": "regroup"})


func contract_progress() -> int:
	if combat_contract.is_empty():
		return 0
	match str(combat_contract.get("metric", "kills")):
		"reactions": return reactions
		"survival_time": return floori(elapsed)
		_: return kills

func contract_status() -> String:
	if combat_contract.is_empty():
		return "无战术契约"
	var suffix := "完成" if contract_completed else "%d/%d" % [mini(contract_progress(), int(combat_contract.target)), int(combat_contract.target)]
	return "%s %s" % [str(combat_contract.get("name", "战术契约")), suffix]

func _contract_tick() -> void:
	if contract_completed or combat_contract.is_empty() or contract_progress() < int(combat_contract.get("target", 1)):
		return
	contract_completed = true
	var reward: Dictionary = combat_contract.get("reward", {})
	contract_reward_text = str(reward.get("text", "奖励已获得"))
	match str(reward.get("kind", "")):
		"luck":
			run_state.luck = clampf(run_state.luck + float(reward.get("value", 0.0)), 0.0, 1.5)
		"shield":
			crystal_shield = minf(999.0, crystal_shield + float(reward.get("value", 0.0)))
		"energy":
			for hero: Dictionary in heroes:
				gain_hero_energy(hero,float(reward.get("value",0.0)))
		"heal":
			for hero: Dictionary in heroes:
				hero.hp = minf(float(hero.max_hp), float(hero.hp) + float(hero.max_hp) * float(reward.get("value", 0.0)))
	events.append({"kind":"contract_complete","pos":heroes[0].pos if not heroes.is_empty() else Vector2(640,360),"value":str(combat_contract.get("name","战术契约")),"reward":contract_reward_text})


func _endless_tier() -> int:
	return maxi(1, floori(elapsed / 60.0) + 1)

func _endless_active_cap() -> int:
	var progression := clampf(elapsed / 540.0, 0.0, 1.0)
	var cap := roundi(lerpf(ENDLESS_ACTIVE_CAP_EARLY, ENDLESS_ACTIVE_CAP_LATE, progression))
	if performance_budget.quality_scale <= 0.58:
		cap = mini(cap, 64)
	elif performance_budget.quality_scale < 1.0:
		cap = mini(cap, 80)
	return cap

func _endless_low_tier_cap() -> int:
	var progression := clampf(elapsed / 420.0, 0.0, 1.0)
	return roundi(lerpf(ENDLESS_LOW_TIER_CAP_EARLY, ENDLESS_LOW_TIER_CAP_LATE, progression))

func _endless_phase() -> int:
	# Roster pressure follows survival time even if an earlier boss remains alive.
	return floori(elapsed / 150.0)

func _endless_enemy_level(tier: int) -> int:
	return maxi(1, 1 + floori(pow(maxf(elapsed, 0.0) / 60.0, 2.0) * 0.44))

func _endless_enemy_pool(phase: int) -> Array[String]:
	match phase:
		0:
			return ["grunt", "grunt", "runner", "runner", "originium_bug"]
		1:
			return ["grunt", "runner", "originium_bug", "slime_pyro", "slime_electro", "slime_hydro", "ranged", "rift_bat"]
		2:
			return ["slime_pyro", "slime_electro", "slime_anemo", "slime_hydro", "slime_cryo", "ranged", "rift_bat", "buffer", "charger", "armored", "healer"]
		3:
			return ["buffer", "charger", "armored", "healer", "warder", "ranged", "slime_cryo", "shielded", "hilichurl_brute"]
		_:
			return ["ranged", "troop_ranged", "buffer", "warder", "healer", "shielded", "hilichurl_brute", "charger", "ranged", "troop_cannon"]

func _endless_enemy_scales(tier: int) -> Dictionary:
	var level := _endless_enemy_level(tier)
	var late := maxf(0.0, float(level - 6))
	return {
		"health": 0.75 * pow(1.10, minf(180, level - 1)),
		"damage": 0.80 * pow(1.075, minf(180, level - 1)),
		"speed": minf(1.90, 1.0 + float(level - 1) * 0.012),
		"xp": minf(3.5, 1.0 + float(level - 1) * 0.10),
	}

func _apply_endless_scaling(enemy: Dictionary, tier: int, strength: float = 1.0) -> void:
	var scales := _endless_enemy_scales(tier)
	var health_scale := lerpf(1.0, float(scales.health), strength)
	var damage_scale := lerpf(1.0, float(scales.damage), strength)
	var kind := str(enemy.get("kind", ""))
	enemy.hp *= health_scale
	enemy.max_hp = enemy.hp
	enemy.damage *= damage_scale
	enemy.shield *= health_scale
	enemy.max_shield = enemy.shield
	enemy.speed *= lerpf(1.0, float(scales.speed), strength)
	enemy.xp = maxi(1, roundi(float(enemy.get("xp", 10)) * lerpf(1.0, float(scales.xp), strength)))
	enemy.endless_scale_health = health_scale
	enemy.endless_scale_damage = damage_scale
	enemy.endless_scale_speed = float(scales.speed)
	enemy.level = _endless_enemy_level(tier)
	enemy.endless_rank = tier
	enemy.rate = float(enemy.get("rate",1.0)) * minf(2.6, 1.0 + float(enemy.level) * 0.012)
	if kind == "armored":
		enemy.name = "铁桶僵尸"

func _refresh_endless_threat() -> void:
	var bucket := floori(elapsed/30.0)
	if bucket==endless_threat_bucket:return
	endless_threat_bucket=bucket
	var scales := _endless_enemy_scales(_endless_tier())
	var level := _endless_enemy_level(_endless_tier())
	for enemy: Dictionary in enemies:
		var old_level := int(enemy.get("level",1))
		var hp_ratio := float(scales.health)/maxf(0.01,float(enemy.get("endless_scale_health",1.0)))
		var damage_ratio := float(scales.damage)/maxf(0.01,float(enemy.get("endless_scale_damage",1.0)))
		enemy.hp*=hp_ratio;enemy.max_hp*=hp_ratio
		enemy.shield*=hp_ratio;enemy.max_shield*=hp_ratio
		enemy.damage*=damage_ratio
		enemy.speed*=float(scales.speed)/maxf(0.01,float(enemy.get("endless_scale_speed",1.0)))
		enemy.rate*=minf(2.6,1.0+level*0.012)/minf(2.6,1.0+old_level*0.012)
		if str(enemy.kind).begins_with("boss_"):
			enemy.armor += maxf(0,level-old_level)*0.8
			enemy.boss_phase=maxi(int(enemy.get("boss_phase",1)),mini(3,1+floori(elapsed/300.0)))
		enemy.level=level
		enemy.endless_scale_health=scales.health;enemy.endless_scale_damage=scales.damage;enemy.endless_scale_speed=scales.speed

func _endless_spawn_tick(dt: float) -> void:
	_refresh_endless_threat()
	_spawn_endless_boss_if_due()
	troop_convoy_timer -= dt
	if _endless_phase() <= 2 and troop_convoy_timer <= 0.0 and enemies.size() + 7 <= _endless_active_cap():
		_spawn_endless_troop_group()
		troop_convoy_timer = 120.0
	endless_spawn_timer -= dt
	var active_cap := _endless_active_cap()
	if endless_spawn_timer > 0.0 or enemies.size() >= active_cap:
		return
	var tier := _endless_tier()
	var build_levels := 0
	for level: Variant in run_state.buff_levels.values():
		build_levels += int(level)
	var pool := _endless_enemy_pool(_endless_phase())
	var low_tier_cap := _endless_low_tier_cap()
	var low_tier_count := _endless_kind_count(ENDLESS_LOW_TIER_IDS)
	var hut_count := _endless_kind_count(["splitter"])
	var available_slots := active_cap - enemies.size()
	var batch := mini(available_slots, mini(5, 2 + floori((tier - 1) / 2.0)))
	for i in batch:
		if enemies.size()>=active_cap:break
		var side := (kills + next_id + i * 3) % 4
		var ratio := fposmod(sin(float(next_id + i * 19) * 12.9898) * 43758.5453, 1.0)
		var kind: String = pool[(next_id + i * 5 + tier) % pool.size()]
		if kind == "splitter" and hut_count >= ENDLESS_HUT_CAP:
			kind = _endless_quality_enemy(tier, i)
		if kind in ENDLESS_LOW_TIER_IDS and low_tier_count >= low_tier_cap:
			kind = _endless_quality_enemy(tier, i)
		if kind in ["hilichurl_brute","shielded"] and _endless_kind_count([kind])>=8:
			kind = "grunt" if i%2==0 else "ranged"
		kind = _balanced_spawn_kind(kind)
		if elapsed >= 600.0 and next_id % 7 == 0 and _endless_kind_count(["boss_01"]) < mini(10, 3 + floori((elapsed-600.0)/60.0)):
			kind = "boss_01"
		if kind=="rift_bat" and active_cap-enemies.size()<3: continue
		var point := _endless_interior_spawn_point(side, ratio) if kind == "splitter" else _endless_edge_point(side, ratio)
		var enemy := spawn_enemy(point, kind)
		_apply_endless_scaling(enemy, tier)
		if kind == "boss_01": enemy.endless_commander = true
		if kind=="rift_bat":
			for member in mini(2,maxi(0,active_cap-enemies.size())):
				var wing := spawn_enemy(point+Vector2(22,(member*2-1)*26),"rift_bat")
				_apply_endless_scaling(wing,tier)
		if kind == "splitter":
			hut_count += 1
		elif kind in ENDLESS_LOW_TIER_IDS:
			low_tier_count += 1
		if enemies.size() < 84 or kind not in ENDLESS_LOW_TIER_IDS:
			events.append({"kind": "route_spawn", "pos": point, "route_id": "edge_%d" % side, "flying": bool(enemy.get("flying", false))})
	var tide := fposmod(elapsed, 60.0)
	var interval := 1.5 if tide < 12.0 else (0.55 if tide > 42.0 else 0.95)
	endless_spawn_timer += maxf(0.46, 1.15 * interval / (1.0 + elapsed / 900.0))

func _spawn_endless_troop_group() -> void:
	var group := ["troop_cannon", "troop_melee", "troop_melee", "troop_melee", "troop_ranged", "troop_ranged", "troop_ranged"]
	var tier := _endless_tier()
	var side := posmod(next_id, 4)
	for index in group.size():
		var point := _endless_edge_point(side, 0.32 + float(index) * 0.055)
		var enemy := spawn_enemy(point, group[index])
		_apply_endless_scaling(enemy, tier)
		events.append({"kind":"route_spawn","pos":point,"route_id":"edge_%d" % side,"flying":false})

func _endless_kind_count(kinds: Array) -> int:
	return enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")) in kinds).size()

func _endless_quality_enemy(_tier: int, index: int) -> String:
	var pool := _endless_enemy_pool(_endless_phase()).filter(func(kind: String) -> bool: return kind not in ENDLESS_LOW_TIER_IDS and kind != "splitter")
	if pool.is_empty():
		return "grunt"
	return pool[posmod(next_id + index * 3, pool.size())]

func _endless_interior_spawn_point(side: int, ratio: float) -> Vector2:
	var inner_area := ENDLESS_ARENA.grow(-150.0)
	var candidate := _endless_edge_point(side, ratio).move_toward(ENDLESS_ARENA.get_center(), 210.0)
	candidate.x = clampf(candidate.x, inner_area.position.x, inner_area.end.x)
	candidate.y = clampf(candidate.y, inner_area.position.y, inner_area.end.y)
	if not _terrain_blocks(candidate, 48.0):
		return candidate
	for offset in [Vector2(120, 0), Vector2(-120, 0), Vector2(0, 120), Vector2(0, -120), Vector2(160, 100), Vector2(-160, -100)]:
		var option: Vector2 = candidate + offset
		if inner_area.has_point(option) and not _terrain_blocks(option, 48.0):
			return option
	return ENDLESS_ARENA.get_center()

func _endless_edge_point(side: int, ratio: float) -> Vector2:
	return expedition.spawn_point(self, side, ratio)

func _make_room_for_endless_boss() -> void:
	var active_cap := _endless_active_cap()
	while enemies.size() >= active_cap:
		var removal_index := -1
		for index in enemies.size():
			var candidate: Dictionary = enemies[index]
			if candidate.hp > 0.0 and str(candidate.get("kind", "")) in ENDLESS_LOW_TIER_IDS:
				removal_index = index
				break
		if removal_index < 0:
			for index in enemies.size():
				if not str(enemies[index].get("kind", "")).begins_with("boss_"):
					removal_index = index
					break
		if removal_index < 0:
			return
		var removed_enemy: Dictionary = enemies[removal_index]
		enemy_lookup.erase(int(removed_enemy.get("id", -1)))
		enemies.remove_at(removal_index)
		culled_spawns += 1

func _endless_boss_multipliers(number: int) -> Vector2:
	var n := float(maxi(0, number - 1))
	return Vector2(pow(2.15,n) * (1.0+0.35*n), pow(1.48,n))

func _scale_endless_boss(boss: Dictionary, number: int) -> void:
	_apply_endless_scaling(boss, _endless_tier())
	var scales := _endless_boss_multipliers(number)
	boss.hp *= scales.x; boss.max_hp = boss.hp
	boss.shield *= scales.x; boss.max_shield = boss.shield
	boss.damage *= scales.y
	boss.armor = float(boss.get("armor",0)) + float(boss.level)*0.8
	if boss.has("attack_range"):boss.attack_range *= minf(1.4,1.0+elapsed/2400.0)
	boss.boss_pulse = maxf(2.5, float(boss.get("boss_pulse", 6.0)) / minf(2.4, 1.0+elapsed/700.0))
	boss.boss_phase = mini(3, 1+floori(elapsed/300.0))
	boss.endless_boss_number = number

func _spawn_endless_boss_if_due() -> void:
	while endless_mode and elapsed >= endless_next_boss_at:
		var active_bosses := enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")).begins_with("boss_") and not bool(enemy.get("endless_commander",false))).size()
		if active_bosses >= 2:
			endless_next_boss_at = elapsed + 18.0
			return
		_make_room_for_endless_boss()
		var boss_id: String = ENDLESS_BOSS_IDS[endless_boss_index % ENDLESS_BOSS_IDS.size()]
		var side := endless_boss_index % 4
		var boss := spawn_enemy(_endless_edge_point(side, 0.22 + fposmod(endless_boss_index * 0.31, 0.56)), boss_id)
		var boss_number := endless_boss_index + 1
		_scale_endless_boss(boss, boss_number)
		events.append({"kind": "boss_arrival", "pos": boss.pos, "value": str(boss.name), "enemy_id": boss.id})
		endless_boss_index += 1
		endless_next_boss_at += 150.0

func _spawn_tick(dt: float) -> void:
	spawn_timer -= dt
	if spawn_remaining > 0 and spawn_timer <= 0:
		var encounter: Array = Catalog.WAVES[wave - 1]
		var index: int = encounter.size() - spawn_remaining
		var lane: int = (index + wave - 1) % 3
		spawn_enemy(Vector2(1160, LANES[lane]), encounter[index])
		spawn_remaining -= 1
		spawn_timer += 1.50 - wave * 0.10

func begin_stage_exit() -> void:
	state = "stage_exit"
	formation_mode = "hold"
	for hero in heroes:
		hero.target = hero.pos
	if not heroes.is_empty():
		heroes[0].hp = maxf(1.0, float(heroes[0].hp))
		heroes[0].deployed = true
	projectiles.clear()
	enemy_projectiles.clear()
	enemy_hazards.clear()
	pending_stage_spawns.clear()
	pending_troop_spawns.clear()
	enemies.clear()
	enemy_lookup.clear()
	skill_effects.clear()
	geo_constructs.clear()
	pending_impacts.clear()
	orbitals.clear()
	tag_synergy_levels.clear()
	dodges = 0
	damage_source_override = -1
	attack_audio_source_override = -1
	fireball_level = 0
	meteor_timer = 4.0
	if not heroes.is_empty():
		heroes[0].target = heroes[0].pos

func _stage_spawn_tick(dt: float) -> void:
	var waiting_stage_spawns: Array[Dictionary] = []
	for queued_event: Dictionary in pending_stage_spawns:
		if not _try_spawn_stage_event(queued_event):
			waiting_stage_spawns.append(queued_event)
	pending_stage_spawns = waiting_stage_spawns
	for event: Dictionary in stage_runtime.tick(dt):
		if event.kind == "route_warning":
			events.append(event)
		elif event.kind == "spawn":
			wave = maxi(wave, int(event.get("wave", wave)))
			if not _try_spawn_stage_event(event):
				pending_stage_spawns.append(event.duplicate(true))
		elif event.kind == "boss_wave":
			wave += 1
			var boss_id := str(event.enemy_id)
			var boss := spawn_on_route(boss_id, str(event.route_id))
			events.append({"kind": "wave", "value": wave})
			events.append({"kind": "boss_arrival", "pos": boss.pos, "value": str(boss.get("name", boss_id)), "enemy_id": boss.id})

func _try_spawn_stage_event(event: Dictionary) -> bool:
	if not performance_budget.allow_enemy(enemies.size()):
		return false
	if str(event.get("enemy_id", "")) == "troop_cannon":
		_spawn_troop_group_on_route(str(event.get("route_id", "main")), int(event.get("sequence", 0)))
	elif str(event.get("enemy_id", "")) == "rift_bat":
		if not performance_budget.allow_enemy(enemies.size()+2): return false
		for member in 3:
			spawn_on_route("rift_bat",str(event.get("route_id","main")),int(event.get("sequence",0))+member,true)
	else:
		spawn_on_route(str(event.get("enemy_id", "grunt")), str(event.get("route_id", "main")), int(event.get("sequence", 0)))
	return true

func _spawn_troop_group_on_route(route_id: String, sequence: int) -> void:
	var group := ["troop_cannon", "troop_melee", "troop_melee", "troop_melee", "troop_ranged", "troop_ranged", "troop_ranged"]
	spawn_on_route(group[0], route_id, sequence)
	for index in range(1, group.size()):
		pending_troop_spawns.append({"kind":group[index],"route_id":route_id,"sequence":sequence + index,"delay":float(index) * 1.5})

func _troop_spawn_tick(dt: float) -> void:
	var waiting: Array[Dictionary] = []
	for item: Dictionary in pending_troop_spawns:
		item.delay = float(item.delay) - dt
		if float(item.delay) <= 0.0 and performance_budget.allow_enemy(enemies.size()):
			spawn_on_route(str(item.kind), str(item.route_id), int(item.sequence))
		else:
			item.delay = maxf(0.0, float(item.delay))
			waiting.append(item)
	pending_troop_spawns = waiting

func _balanced_spawn_kind(requested: String) -> String:
	if requested.begins_with("boss_") or requested.begins_with("troop_"):
		return requested
	var elapsed_tier := maxi(1, floori(elapsed / 60.0) + 1)
	var caps := {
		"ranged": 2 + mini(3, floori(elapsed_tier / 2.0)),
		"buffer": 1 + mini(2, floori(elapsed_tier / 3.0)),
		"splitter": 1 if not endless_mode else ENDLESS_HUT_CAP,
		"shielded": 1 + mini(2, floori(elapsed_tier / 3.0)),
		"healer": 1 + mini(2, floori(elapsed_tier / 4.0)),
		"warder": 1 + mini(2, floori(elapsed_tier / 4.0)),
	}
	if endless_mode:
		caps["ranged"] = 12 + mini(12, floori(elapsed/60.0))
		caps["buffer"] = 4; caps["healer"] = 4; caps["warder"] = 4
	var chosen := requested
	var active_same := enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")) == requested).size()
	var repeated := recent_spawn_kinds.size() >= 2 and recent_spawn_kinds[-1] == requested and recent_spawn_kinds[-2] == requested
	if (caps.has(requested) and active_same >= int(caps[requested])) or (endless_mode and repeated):
		var fallback: Array = _endless_enemy_pool(_endless_phase()) if endless_mode else stage_runtime.definition.get("fodder_pool", ["grunt", "runner"])
		fallback = fallback.filter(func(kind: String) -> bool: return kind != requested and not (recent_spawn_kinds.size() > 0 and kind == recent_spawn_kinds[-1]))
		chosen = fallback[posmod(next_id + enemies.size(), fallback.size())] if not fallback.is_empty() else requested
	recent_spawn_kinds.append(chosen)
	while recent_spawn_kinds.size() > 8:
		recent_spawn_kinds.pop_front()
	return chosen
func spawn_on_route(kind: String, route_id: String, sequence: int = 0, keep_kind: bool = false) -> Dictionary:
	if not keep_kind: kind = _balanced_spawn_kind(kind)
	var points := stage_route(route_id)
	var starts := stage_spawn_points(route_id)
	var start: Vector2 = starts[posmod(sequence, starts.size())] if not starts.is_empty() else (points[0] if not points.is_empty() else Vector2(1160, stage_lane_map().get(route_id, LANES[1])))
	if not points.is_empty() and not start.is_equal_approx(points[0]):
		var adjusted: Array[Vector2] = [start]
		adjusted.append_array(points.slice(1))
		points = adjusted
	var enemy := spawn_enemy(start, kind)
	enemy.route_points = points
	enemy.route_index = 1 if points.size() > 1 else 0
	enemy.route_id = route_id
	events.append({"kind": "route_spawn", "pos": start, "route_id": route_id, "flying": bool(enemy.get("flying", false))})
	return enemy

func _rebuild_endless_navigation_grid() -> void:
	endless_nav_cache.clear()
	_rebuild_endless_blocker_index()
	endless_nav_fields.clear()
	endless_nav_refresh_timer = 0.0
	if not endless_mode:
		endless_nav_columns = 0
		endless_nav_rows = 0
		endless_nav_solid.clear()
		return
	endless_nav_columns = ceili(ENDLESS_ARENA.size.x / ENDLESS_NAV_CELL_SIZE)
	endless_nav_rows = ceili(ENDLESS_ARENA.size.y / ENDLESS_NAV_CELL_SIZE)
	endless_nav_solid.resize(endless_nav_columns * endless_nav_rows)
	for row in endless_nav_rows:
		for column in endless_nav_columns:
			var cell := Vector2i(column, row)
			var center := _endless_nav_cell_center(cell)
			endless_nav_solid[_endless_nav_index(cell)] = 1 if _terrain_blocks(center, ENDLESS_NAV_CLEARANCE) else 0

func _endless_nav_index(cell: Vector2i) -> int:
	return cell.y * endless_nav_columns + cell.x

func _endless_nav_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		clampi(floori((point.x - ENDLESS_ARENA.position.x) / ENDLESS_NAV_CELL_SIZE), 0, maxi(0, endless_nav_columns - 1)),
		clampi(floori((point.y - ENDLESS_ARENA.position.y) / ENDLESS_NAV_CELL_SIZE), 0, maxi(0, endless_nav_rows - 1))
	)

func _endless_nav_cell_center(cell: Vector2i) -> Vector2:
	return ENDLESS_ARENA.position + Vector2(cell.x + 0.5, cell.y + 0.5) * ENDLESS_NAV_CELL_SIZE

func _endless_nav_cell_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < endless_nav_columns and cell.y < endless_nav_rows

func _endless_nav_cell_open(cell: Vector2i) -> bool:
	return _endless_nav_cell_valid(cell) and endless_nav_solid[_endless_nav_index(cell)] == 0

func _nearest_open_endless_nav_cell(point: Vector2, radius: float = 0.0) -> Vector2i:
	var origin := _endless_nav_cell(point)
	if _endless_nav_cell_open(origin):
		return origin
	var max_ring := maxi(endless_nav_columns, endless_nav_rows)
	for ring in range(1, max_ring + 1):
		for y in range(origin.y - ring, origin.y + ring + 1):
			for x in range(origin.x - ring, origin.x + ring + 1):
				if abs(x - origin.x) != ring and abs(y - origin.y) != ring:
					continue
				var candidate := Vector2i(x, y)
				if not _endless_nav_cell_open(candidate):
					continue
				if radius > 0.0 and not _terrain_blocker_on_segment(point, _endless_nav_cell_center(candidate), radius).is_empty():
					continue
				return candidate
	return origin

func _endless_nav_distance_field(target_cell: Vector2i) -> PackedInt32Array:
	var cache_key := _endless_nav_index(target_cell)
	if endless_nav_cache.has(cache_key): return endless_nav_cache[cache_key]
	var distances := PackedInt32Array()
	distances.resize(endless_nav_columns*endless_nav_rows); distances.fill(-1)
	if not _endless_nav_cell_open(target_cell): return distances
	distances[cache_key]=0
	var queue: Array[int]=[cache_key]
	var cursor := 0
	while cursor<queue.size():
		var index := queue[cursor]; cursor+=1
		var cell := Vector2i(index%endless_nav_columns,index/endless_nav_columns)
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var adjacent := cell+offset
			if not _endless_nav_cell_open(adjacent): continue
			var adjacent_index := _endless_nav_index(adjacent)
			if distances[adjacent_index]>=0: continue
			distances[adjacent_index]=distances[index]+1; queue.append(adjacent_index)
	if endless_nav_cache.size()>=12: endless_nav_cache.erase(endless_nav_cache.keys()[0])
	endless_nav_cache[cache_key]=distances
	return distances

func _endless_hero_path(origin: Vector2, goal: Vector2) -> Array[Vector2]:
	var path: Array[Vector2]=[]
	var cell := _nearest_open_endless_nav_cell(origin,17.0)
	var target := _nearest_open_endless_nav_cell(goal)
	if not _endless_nav_cell_open(cell) or not _endless_nav_cell_open(target): return path
	var distances := _endless_nav_distance_field(target)
	if distances[_endless_nav_index(cell)]<0: return path
	path.append(_endless_nav_cell_center(cell))
	for step in endless_nav_columns*endless_nav_rows:
		if cell==target: break
		var best := cell
		var distance := distances[_endless_nav_index(cell)]
		var closest := INF
		for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var adjacent := cell+offset
			if not _endless_nav_cell_open(adjacent): continue
			var value := distances[_endless_nav_index(adjacent)]
			var tie := _endless_nav_cell_center(adjacent).distance_squared_to(goal)
			if value>=0 and value<distance and (value<distances[_endless_nav_index(best)] or tie<closest):
				best=adjacent; closest=tie
		if best==cell: break
		cell=best; path.append(_endless_nav_cell_center(cell))
	path.append(goal)
	return path

func _endless_hero_waypoint(hero: Dictionary, dt: float) -> Vector2:
	var origin: Vector2=hero.pos
	var goal: Vector2=hero.target
	if not terrain_line_blocked(origin,goal,17.0):
		hero.erase("endless_move_path")
		return goal
	hero.endless_move_replan=maxf(0,float(hero.get("endless_move_replan",0))-dt)
	var path: Array=hero.get("endless_move_path",[])
	var changed := Vector2(hero.get("endless_move_goal",Vector2.INF)).distance_squared_to(goal)>576.0
	if path.is_empty() or (changed and float(hero.endless_move_replan)<=0):
		path=_endless_hero_path(origin,goal)
		hero.endless_move_path=path; hero.endless_move_goal=goal; hero.endless_move_replan=.18
	while not path.is_empty() and origin.distance_squared_to(Vector2(path[0]))<196.0: path.pop_front()
	if path.is_empty(): return _terrain_detour_waypoint(origin,goal,17.0)
	var farthest := -1
	for index in path.size():
		if not terrain_line_blocked(origin,Vector2(path[index]),17.0): farthest=index
	if farthest<0:
		hero.erase("endless_move_path")
		return _terrain_detour_waypoint(origin,goal,17.0)
	if farthest>0:
		path=path.slice(farthest); hero.endless_move_path=path
	return path[0]

func _rebuild_endless_navigation_fields() -> void:
	endless_nav_fields.clear()
	endless_nav_refresh_timer = ENDLESS_NAV_REFRESH
	if not endless_mode or endless_nav_columns <= 0 or endless_nav_rows <= 0:
		return
	for hero: Dictionary in heroes:
		if not bool(hero.get("deployed",false)) or float(hero.get("hp",0))<=0: continue
		var target_cell := _nearest_open_endless_nav_cell(Vector2(hero.pos))
		if _endless_nav_cell_open(target_cell): endless_nav_fields[int(hero.id)]=_endless_nav_distance_field(target_cell)

func _nearest_active_door_center(point: Vector2) -> Vector2:
	var result := point
	var best_distance := INF
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) != "door" or float(feature.get("hp", 0.0)) <= 0.0:
			continue
		var center := Rect2(feature.area).get_center()
		var distance := point.distance_squared_to(center)
		if distance < best_distance:
			best_distance = distance
			result = center
	return result

func _endless_navigation_waypoint(enemy: Dictionary, destination: Vector2, radius: float) -> Vector2:
	if not terrain_line_blocked(Vector2(enemy.pos), destination, radius):
		return destination
	var target_id := -1
	var closest_distance := INF
	for hero: Dictionary in heroes:
		if not bool(hero.get("deployed", false)) or float(hero.get("hp", 0.0)) <= 0.0:
			continue
		var distance := Vector2(enemy.pos).distance_squared_to(Vector2(hero.pos))
		if distance < closest_distance:
			closest_distance = distance
			target_id = int(hero.id)
	if target_id < 0 or not endless_nav_fields.has(target_id):
		return _terrain_detour_waypoint(Vector2(enemy.pos), destination, radius)
	var distances: PackedInt32Array = endless_nav_fields[target_id]
	var current_cell := _nearest_open_endless_nav_cell(Vector2(enemy.pos), radius)
	if not _endless_nav_cell_open(current_cell):
		return _terrain_detour_waypoint(Vector2(enemy.pos), destination, radius)
	var current_index := _endless_nav_index(current_cell)
	var current_distance := distances[current_index]
	if current_distance < 0:
		var door_target := _nearest_active_door_center(Vector2(enemy.pos))
		return door_target if door_target != Vector2(enemy.pos) else _terrain_detour_waypoint(Vector2(enemy.pos), destination, radius)
	if current_distance <= 1:
		return destination
	var best_cell := current_cell
	var best_distance := current_distance
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var candidate := current_cell + offset
		if not _endless_nav_cell_open(candidate):
			continue
		var candidate_distance := distances[_endless_nav_index(candidate)]
		if candidate_distance < 0 or candidate_distance >= best_distance:
			continue
		var waypoint := _endless_nav_cell_center(candidate)
		if not _terrain_blocker_on_segment(Vector2(enemy.pos), waypoint, radius).is_empty():
			continue
		best_cell = candidate
		best_distance = candidate_distance
	return _endless_nav_cell_center(best_cell) if best_cell != current_cell else _terrain_detour_waypoint(Vector2(enemy.pos), destination, radius)

func _terrain_detour_waypoint(current: Vector2, destination: Vector2, radius: float) -> Vector2:
	var blocker := _terrain_blocker_on_segment(current, destination, radius)
	if blocker.is_empty():
		return destination
	var obstacle := _feature_collision_rect(blocker).grow(radius + 18.0)
	var candidates := [
		Vector2(obstacle.position.x - 8.0, obstacle.position.y - 8.0),
		Vector2(obstacle.end.x + 8.0, obstacle.position.y - 8.0),
		Vector2(obstacle.position.x - 8.0, obstacle.end.y + 8.0),
		Vector2(obstacle.end.x + 8.0, obstacle.end.y + 8.0),
	]
	var usable: Array[Vector2] = []
	for candidate: Vector2 in candidates:
		var navigation_bounds := ENDLESS_ARENA if endless_mode else MOVE_AREA
		if not navigation_bounds.grow(-radius).has_point(candidate):
			continue
		if not _terrain_blocker_at(candidate, radius).is_empty():
			continue
		if not _terrain_blocker_on_segment(current, candidate, radius).is_empty():
			continue
		usable.append(candidate)
	if usable.is_empty():
		return current
	usable.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		var a_penalty := 260.0 if terrain_line_blocked(a, destination, radius) else 0.0
		var b_penalty := 260.0 if terrain_line_blocked(b, destination, radius) else 0.0
		return current.distance_to(a) + a.distance_to(destination) + a_penalty < current.distance_to(b) + b.distance_to(destination) + b_penalty)
	return usable[0]

func _enemy_navigation_target(enemy: Dictionary, destination: Vector2, radius: float, dt: float) -> Vector2:
	enemy.nav_timer = maxf(0.0, float(enemy.get("nav_timer", 0.0)) - dt)
	enemy.nav_probe_timer = maxf(0.0, float(enemy.get("nav_probe_timer", 0.0)) - dt)
	if endless_mode:
		if enemy.has("nav_waypoint"):
			var endless_cached: Vector2 = enemy.nav_waypoint
			if float(enemy.nav_timer) > 0.0 and Vector2(enemy.pos).distance_squared_to(endless_cached) > 324.0:
				return endless_cached
			enemy.erase("nav_waypoint")
		var endless_waypoint := _endless_navigation_waypoint(enemy, destination, radius)
		enemy.nav_waypoint = endless_waypoint
		enemy.nav_timer = 0.24
		return endless_waypoint
	if enemy.has("nav_waypoint"):
		var cached: Vector2 = enemy.nav_waypoint
		if enemy.pos.distance_squared_to(cached) > 324.0 and float(enemy.nav_timer) > 0.0:
			enemy.nav_clear = false
			return cached
		enemy.erase("nav_waypoint")
	if bool(enemy.get("nav_clear", false)) and float(enemy.nav_probe_timer) > 0.0:
		return destination
	enemy.nav_probe_timer = 0.16 + float(int(enemy.get("id", 0)) % 5) * 0.018
	if not terrain_line_blocked(enemy.pos, destination, radius):
		enemy.nav_clear = true
		return destination
	enemy.nav_clear = false
	var waypoint := _terrain_detour_waypoint(enemy.pos, destination, radius)
	if waypoint != enemy.pos:
		enemy.nav_waypoint = waypoint
		enemy.nav_timer = 2.4
	return waypoint

func _nearby_destructible_door(point: Vector2, radius: float) -> Dictionary:
	var nearest: Dictionary = {}
	var best_distance := INF
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) != "door" or float(feature.get("hp", 0.0)) <= 0.0:
			continue
		var area := Rect2(feature.area).grow(radius + 54.0)
		var center := Rect2(feature.area).get_center()
		var distance := point.distance_to(center)
		if area.has_point(point) and distance < best_distance:
			nearest = feature
			best_distance = distance
	return nearest

func _attack_terrain_door(enemy: Dictionary, door: Dictionary) -> void:
	if door.is_empty() or float(enemy.get("attack_timer", 0.0)) > 0.0:
		return
	door.hp = maxf(0.0, float(door.get("hp", 0.0)) - float(enemy.get("damage", 1.0)))
	enemy.attack_timer = 1.0 / maxf(0.1, float(enemy.get("rate", 1.0)))
	var center := Rect2(door.area).get_center()
	events.append({"kind": "terrain_hit" if door.hp > 0.0 else "terrain_break", "pos": center, "value": ceili(float(enemy.get("damage", 1.0)))})
	if door.hp <= 0.0:
		_rebuild_endless_navigation_grid()
		for candidate: Dictionary in enemies:
			candidate.erase("nav_waypoint")
			candidate.nav_timer = 0.0
func _nearest_live_hero(point: Vector2) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for hero: Dictionary in heroes:
		if not bool(hero.get("deployed", false)) or float(hero.get("hp", 0.0)) <= 0.0:
			continue
		var distance := point.distance_squared_to(Vector2(hero.pos))
		if distance < nearest_distance:
			nearest = hero
			nearest_distance = distance
	return nearest

func _advance_enemy_arrivals(dt: float) -> void:
	for enemy: Dictionary in enemies:
		enemy.spawn_just_landed = false
		if float(enemy.get("spawn_timer", 0.0)) <= 0.0: continue
		enemy.spawn_timer = maxf(0.0, float(enemy.spawn_timer)-dt)
		enemy.attack_pending = false
		if float(enemy.spawn_timer) <= 0.0:
			enemy.spawn_phase = "ground"
			enemy.spawn_just_landed = true
			enemy.attack_timer = maxf(float(enemy.attack_timer),0.35)
			events.append({"kind":"shaman_land","pos":enemy.pos,"enemy_id":int(enemy.id),"life":0.30})

func _enemy_tick(dt: float) -> void:
	_advance_enemy_arrivals(dt)
	if workshop_mode and not workshop_enemy_action:
		for enemy: Dictionary in enemies:
			if float(enemy.get("spawn_timer",0.0)) > 0.0 or bool(enemy.get("spawn_just_landed",false)): continue
			if enemy.has("workshop_move_target"):
				var target: Vector2 = enemy.workshop_move_target
				var radius := maxf(12.0, float(enemy.get("size", 28.0)) * 0.34)
				var waypoint := _enemy_navigation_target(enemy, target, radius, dt)
				enemy.pos = _move_with_terrain(enemy.pos, waypoint, float(enemy.speed) * dt, radius)
				enemy.facing = signf(waypoint.x - enemy.pos.x) if absf(waypoint.x - enemy.pos.x) > 1.0 else enemy.get("facing", -1.0)
				if Vector2(enemy.pos).distance_to(target) < 5.0: enemy.erase("workshop_move_target")
		return
	if endless_mode:
		endless_nav_refresh_timer -= dt
		if endless_nav_refresh_timer <= 0.0:
			_rebuild_endless_navigation_fields()
	enemy_support_scan_timer -= dt
	if enemy_support_scan_timer <= 0.0:
		enemy_support_scan_timer = 0.20
		var support_region := active_view_rect.grow(300.0) if endless_mode else MOVE_AREA.grow(500.0)
		for source: Dictionary in enemies:
			if source.hp <= 0 or source.get("kind", "") != "buffer" or float(source.get("spawn_timer", 0.0)) > 0.0 or not support_region.has_point(source.pos):
				continue
			var aura_radius := float(source.get("aura_radius", 0.0))
			var aura_radius_sq := aura_radius * aura_radius
			for ally: Dictionary in enemies:
				if ally.hp > 0 and ally.id != source.id and support_region.has_point(ally.pos) and ally.pos.distance_squared_to(source.pos) <= aura_radius_sq:
					ally.haste_timer = 0.25
	for e in enemies:
		if float(e.get("spawn_timer", 0.0)) > 0.0 or bool(e.get("spawn_just_landed",false)):
			continue # Ground model position stays fixed; only the sprite falls.
		if EnemyTactics.tick_revival(self, e, dt):
			continue
		if e.hp <= 0:
			continue
		e.flash = maxf(0, e.flash - dt)
		e.attack_timer = maxf(0, e.attack_timer - dt)
		e.aura_timer = maxf(0, e.aura_timer - dt)
		e.reaction_timer = maxf(0, e.reaction_timer - dt)
		e.slow_timer = maxf(0, e.slow_timer - dt)
		e.device_slow_timer = maxf(0.0, float(e.get("device_slow_timer", 0.0)) - dt)
		e.frozen_timer = maxf(0, float(e.get("frozen_timer", 0.0)) - dt)
		e.haste_timer = maxf(0, e.haste_timer - dt)
		e.special_timer = maxf(0, float(e.special_timer) - dt)
		if str(e.get("kind", "")) == "boss_03":
			_tick_kindred_respite(e, dt)
			_maybe_summon_galio(e)
		e.spawn_pulse = maxf(0.0, float(e.get("spawn_pulse", 0.0)) - dt)
		e.affix_timer = maxf(0.0, float(e.get("affix_timer", 0.0)) - dt)
		if EnemyTactics.tick(self,e,dt):
			continue
		var offscreen_lod := endless_mode and not str(e.get("kind", "")).begins_with("boss_") and not active_view_rect.grow(220.0).has_point(e.pos)
		var movement_dt := dt
		if offscreen_lod:
			e.lod_accumulator = float(e.get("lod_accumulator", 0.0)) + dt
			if float(e.lod_accumulator) < 0.20:
				continue
			movement_dt = minf(float(e.lod_accumulator), 0.28)
			e.lod_accumulator = 0.0
		else:
			e.lod_accumulator = 0.0
		if "blink" in e.get("affixes", []) and e.affix_timer <= 0.0:
			var blink_target: Vector2 = Vector2(e.pos) + Vector2(-120.0, 0.0)
			e.pos = blink_target if bool(e.get("flying", false)) else _move_with_terrain(e.pos, blink_target, 120.0, maxf(12.0, float(e.get("size", 28.0)) * 0.34))
			e.affix_timer = 5.0
			events.append({"kind":"enemy_blink","pos":e.pos,"value":120})
		elif "aegis" in e.get("affixes", []) and e.affix_timer <= 0.0:
			var guarded := 0
			for ally: Dictionary in enemies:
				if ally.hp > 0.0 and ally.pos.distance_to(e.pos) <= 210.0:
					ally.shield = float(ally.get("shield",0.0))+35.0
					ally.max_shield = maxf(float(ally.get("max_shield",0.0)),float(ally.shield))
					guarded += 1
			e.affix_timer = 5.5
			events.append({"kind":"enemy_guard","pos":e.pos,"value":guarded})
		if str(e.get("kind", "")) == "hilichurl_brute" and not bool(e.get("attack_stance", false)):
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and float(hero.get("hp", 0.0)) > 0.0 and Vector2(e.pos).distance_to(hero.pos) <= 300.0:
					e.attack_stance = true
					e.speed = float(e.speed) * 2.0
					break
		if e.aura_timer <= 0:
			e.aura = str(e.get("intrinsic_element", ""))
			e.aura_timer = INF if not str(e.aura).is_empty() else 0.0
		var speed_scale: float = (0.0 if e.frozen_timer > 0.0 else (0.7 if e.slow_timer > 0 else 1.0)) * (1.35 if e.haste_timer > 0 else 1.0)
		if float(e.get("device_slow_timer", 0.0)) > 0.0:
			speed_scale *= 0.8
		if not bool(e.get("flying", false)):
			speed_scale *= terrain_movement_scale(e.pos)
		if e.get("kind", "") == "charger" and e.pos.x > 650.0 and e.frozen_timer <= 0.0:
			speed_scale *= float(e.get("charge_multiplier", 2.0))
		var route: Array = e.get("route_points", [])
		var route_index: int = int(e.get("route_index", 0))
		var closest_hero: Dictionary = _nearest_live_hero(Vector2(e.pos)) if endless_mode else {}
		var destination: Vector2 = Vector2(closest_hero.pos) if not closest_hero.is_empty() else Vector2(100, e.pos.y)
		if workshop_mode:
			var victim := _nearest_live_hero(Vector2(e.pos))
			destination = Vector2(victim.pos) if not victim.is_empty() else Vector2(e.pos)
			if e.has("workshop_move_target"): destination = Vector2(e.workshop_move_target)
		if not workshop_mode and not endless_mode and not route.is_empty() and route_index < route.size():
			if bool(e.get("flying", false)):
				destination = route[-1]
				route_index = route.size() - 1
			else:
				destination = route[route_index]
		destination = EnemyTactics.bat_destination(self,e,destination)
		var navigation_radius := maxf(12.0, float(e.get("size", 28.0)) * 0.34)
		var route_destination := destination
		if not bool(e.get("flying", false)) and float(e.get("speed", 0.0)) > 0.0:
			destination = _enemy_navigation_target(e, destination, navigation_radius, movement_dt)
		if absf(destination.x - e.pos.x) > 1.0:
			e.facing = 1.0 if destination.x > e.pos.x else -1.0
		var move_distance := float(e.speed) * speed_scale * movement_dt
		var next_pos: Vector2 = e.pos.move_toward(destination, move_distance) if bool(e.get("flying", false)) else _orthogonal_enemy_step(e.pos, destination, move_distance, navigation_radius)
		if str(e.get("kind", "")) in ["boss_01", "boss_galio"] and bool(e.get("special_pending", false)):
			next_pos = e.pos
		var terrain_door: Dictionary = {} if bool(e.get("flying", false)) else _nearby_destructible_door(e.pos, navigation_radius)
		if not terrain_door.is_empty():
			next_pos = e.pos
			_attack_terrain_door(e, terrain_door)
		var one_way := terrain_feature_at(e.pos, "one_way")
		if not one_way.is_empty():
			var raw_direction: Array = one_way.get("direction", [-1, 0])
			var allowed_direction := Vector2(float(raw_direction[0]), float(raw_direction[1])).normalized()
			if (destination - e.pos).normalized().dot(allowed_direction) < 0.0:
				next_pos = e.pos
		if not workshop_mode and not endless_mode and e.pos.distance_to(route_destination) <= maxf(4.0, e.speed * speed_scale * dt + 1.0):
			e.pos = route_destination
			e.route_index = route_index + 1
			route_index += 1
			next_pos = e.pos
		var construct_victim: Dictionary = {}
		if not bool(e.get("flying", false)):
			for construct: Dictionary in geo_constructs:
				if construct.hp <= 0.0 or absf(e.pos.y - construct.pos.y) > 48.0:
					continue
				var touches: bool = Rect2(construct.cell).grow(10.0).has_point(next_pos) if bool(construct.get("device", false)) else next_pos.distance_to(construct.pos) <= 52.0
				if touches:
					construct_victim = construct
					next_pos = e.pos
					break
		var ranged_victim: Dictionary = {}
		if float(e.get("attack_range", 0.0)) > 0.0:
			for h: Dictionary in heroes:
				if bool(h.get("deployed", false)) and h.hp > 0 and e.pos.distance_to(h.pos) <= float(e.attack_range) and (bool(e.get("flying", false)) or not terrain_line_blocked(e.pos, h.pos)):
					if ranged_victim.is_empty() or e.pos.distance_to(h.pos) < e.pos.distance_to(ranged_victim.pos):
						ranged_victim = h
			if not ranged_victim.is_empty():
				next_pos = e.pos
		e.blocked_by = -1
		var nearest_blocker: Dictionary = {}
		var nearest_blocker_distance := INF
		if not bool(e.get("flying", false)):
			for h: Dictionary in heroes:
				if h.hp <= 0 or not bool(h.get("deployed", false)) or (h.moving and not endless_mode) or h.blocked >= h.block:
					continue
				var blocker_distance: float = e.pos.distance_squared_to(h.pos)
				if (blocker_distance <= 43.0 * 43.0 or next_pos.distance_squared_to(h.pos) <= 43.0 * 43.0) and (not endless_mode or blocker_distance < nearest_blocker_distance):
					nearest_blocker = h
					nearest_blocker_distance = blocker_distance
					if not endless_mode:
						break
		if not nearest_blocker.is_empty():
			e.blocked_by = nearest_blocker.id
			nearest_blocker.blocked += 1
			next_pos = e.pos
		e.pos = next_pos
		if workshop_mode and e.has("workshop_move_target") and Vector2(e.pos).distance_to(Vector2(e.workshop_move_target)) < 5.0:
			e.erase("workshop_move_target")
		var victim: Dictionary = ranged_victim
		if not construct_victim.is_empty():
			victim = {}
		if e.blocked_by >= 0:
			victim = heroes[e.blocked_by]
		elif victim.is_empty():
			var nearest_victim_distance := INF
			for h: Dictionary in heroes:
				if not bool(h.get("deployed", false)) or h.hp <= 0:
					continue
				var victim_distance: float = h.pos.distance_squared_to(e.pos)
				if victim_distance <= 33.0 * 33.0 and (not endless_mode or victim_distance < nearest_victim_distance):
					victim = h
					nearest_victim_distance = victim_distance
					if not endless_mode:
						break
		if bool(e.get("attack_pending", false)):
			e.warning_timer = float(e.warning_timer) - dt
			if e.warning_timer <= 0.0:
				_resolve_enemy_warning(e)
		elif not construct_victim.is_empty() and e.attack_timer <= 0:
			_begin_enemy_warning(e, {}, construct_victim)
		elif not victim.is_empty() and e.attack_timer <= 0:
			_begin_enemy_warning(e, victim)
		if bool(e.get("special_pending", false)):
			e.special_warning = float(e.special_warning) - dt
			if e.special_warning <= 0.0:
				e.special_pending = false
				_execute_boss_special(e)
				if endless_mode:e.special_timer = maxf(1.8, float(e.special_timer)/minf(1.8,1.0+elapsed/1200.0))
		elif str(e.get("kind", "")).begins_with("boss_") and e.special_timer <= 0.0:
			var pattern: Dictionary = database.boss_patterns.get(str(e.kind), {}) if database != null else {}
			var phase_rows: Array = pattern.get("phases", [])
			var phase_row: Dictionary = phase_rows[clampi(int(e.get("boss_phase",1))-1,0,phase_rows.size()-1)] if not phase_rows.is_empty() else {}
			var moves: Array = phase_row.get("moves", ["pulse"])
			var cast_index := int(e.get("boss_cast_index", 0))
			var selected_move := str(moves[cast_index % moves.size()]) if not moves.is_empty() else "pulse"
			e.boss_cast_index = cast_index + 1
			e.special_move = selected_move
			var lead := float(phase_row.get("lead",1.35))
			var warning_radius := float(phase_row.get("radius",150.0))
			e.special_pending = true
			e.special_warning = lead
			e.special_warning_total = lead
			e.special_timer = 0.05
			e.special_warning_radius = warning_radius
			e.special_warning_shape = str(phase_row.get("shape","circle"))
			e.special_move_name = str(phase_row.get("name","首领技能"))
			e.special_warning_positions = []
			if str(e.kind) == "boss_01":
				_start_rift_warning(e, selected_move)
			elif str(e.kind) == "boss_02":
				_start_slime_warning(e, selected_move)
			elif str(e.kind) == "boss_03":
				_start_kindred_warning(e, selected_move)
			elif str(e.kind) == "boss_galio":
				_start_galio_warning(e, selected_move)
			else:
				for warned_hero: Dictionary in heroes:
					if bool(warned_hero.get("deployed", false)) and warned_hero.hp > 0.0:
						e.special_warning_positions.append(warned_hero.pos)
						events.append({"kind":"enemy_warning","pos":warned_hero.pos,"source":e.pos,"radius":warning_radius,"life":lead,"boss":true,"shape":e.special_warning_shape,"name":e.special_move_name})
			events.append({"kind":"boss_warning","pos":e.pos,"name":e.special_move_name,"phase":int(e.get("boss_phase",1)),"duration":float(e.special_warning_total),"boss_kind":str(e.kind)})
		elif bool(e.get("spawner", false)) and e.special_timer <= 0.0:
			var spawned := 0
			var local_spawned := enemies.filter(func(candidate: Dictionary) -> bool: return candidate.hp > 0.0 and str(candidate.get("spawned_by", "")) == str(e.id)).size()
			var spawn_capacity := maxi(0, int(e.get("spawn_limit", 5)) - local_spawned)
			if endless_mode:
				spawn_capacity = mini(spawn_capacity, maxi(0, _endless_active_cap() - enemies.size()))
				spawn_capacity = mini(spawn_capacity, maxi(0, _endless_low_tier_cap() - _endless_kind_count(ENDLESS_LOW_TIER_IDS)))
			for spawn_index in mini(int(e.get("spawn_count", 1)), spawn_capacity):
				var offset := Vector2(42.0 + spawn_index * 18.0, -26.0 + spawn_index * 52.0)
				var child := spawn_enemy(Vector2(e.pos) + offset, str(e.get("spawn_kind", "runner")))
				if endless_mode:
					_apply_endless_scaling(child, _endless_tier(), 0.72)
				child.spawned_by = e.id
				child.route_points = Array(e.get("route_points", [])).duplicate()
				child.route_index = int(e.get("route_index", 0))
				child.route_id = str(e.get("route_id", ""))
				spawned += 1
			e.special_timer = float(e.get("spawn_interval", 6.5))
			e.spawn_pulse = 0.55
			if spawned > 0:
				events.append({"kind":"goblin_spawn","pos":e.pos,"value":spawned,"enemy_id":e.id})
		elif e.get("kind", "") in ["healer", "slime_hydro"] and e.special_timer <= 0.0:
			var healed := 0
			for ally: Dictionary in enemies:
				if ally.hp > 0.0 and ally.id != e.id and ally.pos.distance_to(e.pos) <= float(e.get("heal_radius", 190.0)):
					var amount: float = minf(float(ally.max_hp) - float(ally.hp), float(ally.max_hp) * 0.10 + 16.0)
					ally.hp += amount
					healed += ceili(amount)
			e.special_timer = float(e.get("heal_interval", 5.5))
			events.append({"kind": "enemy_heal", "pos": e.pos, "value": healed})
		elif e.get("kind", "") == "warder" and e.special_timer <= 0.0:
			for ally: Dictionary in enemies:
				if ally.hp > 0.0 and ally.id != e.id and ally.pos.distance_to(e.pos) <= float(e.get("ward_radius", 205.0)):
					ally.shield = float(ally.get("shield", 0.0)) + 55.0
					ally.max_shield = maxf(float(ally.get("max_shield", 0.0)), float(ally.shield))
			e.special_timer = float(e.get("ward_interval", 6.5))
			events.append({"kind": "enemy_guard", "pos": e.pos, "value": 55})
		var completed_route: bool = not route.is_empty() and int(e.route_index) >= route.size() and e.pos.distance_to(route[-1]) <= 5.0
		if not workshop_mode and not endless_mode and (completed_route or (route.is_empty() and e.pos.x <= 108.0)):
			e.hp = 0.0
			var leaked: int = mini(base_hp, int(e.leak))
			leak_count += 1; leak_damage += leaked
			last_leak = Readability.source(e, "突破防线")
			last_leak.merge({"victim":"基地","damage":leaked})
			base_hp = maxi(0, base_hp - e.leak)
			events.append({"kind": "leak", "pos": e.pos, "value": e.leak})
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0 or bool(e.get("revive_pending", false)))
	geo_constructs = geo_constructs.filter(func(item: Dictionary) -> bool: return item.hp > 0.0)

func _rift_laser_targets(source: Vector2, aim: Vector2, enraged: bool) -> Array[Vector2]:
	var source_screen: Vector2 = source if endless_mode else StageProjection.project(source)
	var aim_screen: Vector2 = aim if endless_mode else StageProjection.project(aim)
	var screen_direction := (aim_screen - source_screen).normalized()
	if screen_direction.length_squared() < 0.01:
		screen_direction = Vector2.LEFT
	var targets: Array[Vector2] = []
	var angles: Array = [-PI / 3.0, 0.0, PI / 3.0] if enraged else [0.0]
	for angle: float in angles:
		var target_screen := source_screen + screen_direction.rotated(angle) * 1350.0
		targets.append(target_screen if endless_mode else StageProjection.unproject(target_screen))
	return targets


func _start_rift_warning(enemy: Dictionary, move: String) -> void:
	enemy.special_warning_positions = []
	var nearest: Dictionary = _nearest_live_hero(Vector2(enemy.pos))
	var aim: Vector2 = Vector2(nearest.pos) if not nearest.is_empty() else Vector2(enemy.pos) + Vector2(-350.0, 0.0)
	var enraged := int(enemy.get("boss_phase", 1)) >= 3
	var lead := 2.0
	var radius := 200.0
	var shape := "circle"
	var name := "裂隙风暴"
	match move:
		"rift_laser":
			name = "紫电贯穿"
			shape = "line"
			radius = 76.0 if enraged else 64.0
			var direction: Vector2 = (aim - Vector2(enemy.pos)).normalized()
			if direction.length_squared() < 0.01:
				direction = Vector2.LEFT
			aim = Vector2(enemy.pos) + direction * 1300.0
		"rift_orbs":
			name = "追魂法球"
			lead = 27.0 / 24.0
			radius = 132.0 if enraged else 100.0
		"rift_overhead":
			name = "天降裂光"
			radius = 142.0 if enraged else 92.0
		"rift_storm":
			name = "裂隙爆环"
			lead = 45.0 / 24.0
			radius = 680.0 if enraged else 510.0
			aim = Vector2(enemy.pos)
	enemy.special_warning = lead
	enemy.special_warning_total = lead
	enemy.special_warning_shape = shape
	enemy.special_warning_radius = radius
	enemy.special_move_name = name
	if move == "rift_overhead":
		for hero: Dictionary in heroes:
			if bool(hero.get("deployed", false)) and hero.hp > 0.0:
				enemy.special_warning_positions.append(Vector2(hero.pos))
	elif move == "rift_laser":
		enemy.special_warning_positions = _rift_laser_targets(Vector2(enemy.pos), aim, enraged)
	else:
		enemy.special_warning_positions.append(aim)


func _execute_rift_special(enemy: Dictionary, move: String) -> void:
	var points: Array = enemy.get("special_warning_positions", [])
	var center: Vector2 = Vector2(points[points.size() / 2]) if not points.is_empty() else Vector2(enemy.pos)
	var radius := float(enemy.get("special_warning_radius", 200.0))
	var phase := int(enemy.get("boss_phase", 1))
	var enraged := phase >= 3
	var hits := 0
	match move:
		"rift_laser":
			for hero: Dictionary in heroes:
				if not bool(hero.get("deployed", false)) or hero.hp <= 0.0:
					continue
				for target_value: Variant in points:
					if _distance_to_segment(hero.pos, Vector2(enemy.pos), Vector2(target_value)) <= radius:
						damage_hero(int(hero.id), float(enemy.damage) * (1.75 if enraged else 1.25), Readability.source(enemy))
						hits += 1
						break
			events.append({"kind":"rift_laser","pos":enemy.pos,"target":center,"targets":points.duplicate(),"radius":radius,"phase":phase,"hits":hits})
		"rift_orbs":
			var targets: Array[Dictionary] = heroes.filter(func(hero: Dictionary) -> bool: return bool(hero.get("deployed", false)) and hero.hp > 0.0)
			var orb_count := 18 if enraged else 10
			var splash_radius := 86.0 if enraged else 62.0
			if not targets.is_empty():
				targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return Vector2(a.pos).distance_squared_to(enemy.pos) < Vector2(b.pos).distance_squared_to(enemy.pos))
				for index in orb_count:
					var target: Dictionary = targets[index % targets.size()]
					var angle := float(index) * TAU / float(orb_count)
					_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"rift_orb","pos":Vector2(enemy.pos) + Vector2.from_angle(angle) * (44.0 if enraged else 30.0),"target_id":int(target.id),"damage":float(enemy.damage) * (0.38 if enraged else 0.25),"speed":350.0 if enraged else 320.0,"delay":float(index) * (0.075 if enraged else 0.12),"life":5.0,"splash_radius":splash_radius,"enraged":enraged})
			events.append({"kind":"rift_orbs","pos":enemy.pos,"count":orb_count,"phase":phase,"enraged":enraged})
		"rift_overhead":
			for hero: Dictionary in heroes:
				if not bool(hero.get("deployed", false)) or hero.hp <= 0.0:
					continue
				for point_value: Variant in points:
					if is_in_ability_area(Vector2(point_value), Vector2(hero.pos), radius):
						damage_hero(int(hero.id), float(enemy.damage) * (1.90 if enraged else 1.10), Readability.source(enemy))
						hits += 1
						break
			events.append({"kind":"rift_overhead","pos":enemy.pos,"points":points.duplicate(),"radius":radius,"phase":phase,"hits":hits})
		"rift_storm":
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(center, Vector2(hero.pos), radius):
					damage_hero(int(hero.id), float(enemy.damage) * (2.15 if enraged else 1.50), Readability.source(enemy))
					hits += 1
			events.append({"kind":"rift_storm","pos":center,"radius":radius,"rings":5 if enraged else 4,"phase":phase,"hits":hits})
	enemy.special_timer = maxf(3.3, float(enemy.get("boss_pulse", 6.0)) * (0.9 if int(enemy.get("boss_phase", 1)) == 2 else (0.78 if int(enemy.get("boss_phase", 1)) == 3 else 1.0)))


func _slime_live_heroes() -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for hero: Dictionary in heroes:
		if bool(hero.get("deployed", false)) and hero.hp > 0.0:
			live.append(hero)
	return live


func _start_slime_warning(enemy: Dictionary, move: String) -> void:
	var live := _slime_live_heroes()
	var phase := int(enemy.get("boss_phase", 1))
	var empowered := phase >= 2
	var center: Vector2 = Vector2(live[0].pos) if not live.is_empty() else Vector2(enemy.pos) + Vector2.LEFT * 280.0
	if not live.is_empty():
		var nearest := _nearest_live_hero(Vector2(enemy.pos))
		if not nearest.is_empty():
			center = Vector2(nearest.pos)
	var points: Array[Vector2] = []
	var lead := 1.55
	var radius := 120.0
	var shape := "multi_circle"
	var name := "史莱姆王庭"
	match move:
		"slime_bounce":
			name = "王冠弹跳"
			lead = 1.34 if empowered else 1.58
			radius = 138.0 if empowered else 108.0
			var count := 5 if empowered else 3
			for index in count:
				var anchor: Vector2 = Vector2(live[index % live.size()].pos) if not live.is_empty() else center
				var offset := Vector2.from_angle(float(index) * TAU / float(count) + 0.28) * (78.0 if empowered else 54.0)
				points.append(anchor + offset)
		"slime_burst":
			name = "五色黏爆"
			lead = 1.20 if empowered else 1.48
			radius = 112.0 if empowered else 88.0
			var count := 10 if empowered else 5
			for index in count:
				var anchor: Vector2 = Vector2(live[index % live.size()].pos) if not live.is_empty() else center
				var ring := 64.0 + float(index % 3) * 34.0
				points.append(anchor + Vector2.from_angle(float(index) * 2.39996) * ring)
		"slime_reflux":
			name = "吞噬回流"
			lead = 1.48 if empowered else 1.78
			radius = 390.0 if empowered else 300.0
			shape = "donut"
			points.append(Vector2(enemy.pos))
		"slime_court":
			name = "分裂王庭"
			lead = 1.32 if empowered else 1.65
			radius = 116.0 if empowered else 92.0
			var count := 10 if empowered else 5
			for index in count:
				var anchor: Vector2 = Vector2(live[index % live.size()].pos) if not live.is_empty() else center
				points.append(anchor + Vector2.from_angle(float(index) * TAU / float(count)) * (54.0 if empowered else 34.0))
	enemy.special_warning = lead
	enemy.special_warning_total = lead
	enemy.special_warning_radius = radius
	enemy.special_warning_shape = shape
	enemy.special_move_name = name
	enemy.special_warning_positions = points
	for point: Vector2 in points:
		events.append({"kind":"enemy_warning","pos":point,"source":enemy.pos,"radius":radius,"life":lead,"boss":true,"shape":shape,"name":name})


func _execute_slime_special(enemy: Dictionary, move: String) -> void:
	var points: Array = enemy.get("special_warning_positions", [])
	var phase := int(enemy.get("boss_phase", 1))
	var empowered := phase >= 2
	var radius := float(enemy.get("special_warning_radius", 120.0))
	var elements := ["pyro", "hydro", "electro", "cryo", "anemo"]
	match move:
		"slime_bounce":
			for index in points.size():
				_queue_enemy_hazard({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"slime_bounce_impact","pos":Vector2(points[index]),"radius":radius,"delay":float(index) * (0.12 if empowered else 0.18),"life":0.34,"damage":float(enemy.damage) * (1.05 if empowered else 0.74),"source":Vector2(enemy.pos),"phase":phase})
			events.append({"kind":"slime_bounce","pos":enemy.pos,"points":points.duplicate(),"radius":radius,"phase":phase})
		"slime_burst":
			for index in points.size():
				var angle := float(index) * TAU / maxf(1.0, float(points.size()))
				_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"slime_glob","pos":Vector2(enemy.pos) + Vector2.from_angle(angle) * 36.0,"target_pos":Vector2(points[index]),"damage":float(enemy.damage) * (0.52 if empowered else 0.38),"speed":380.0 if empowered else 320.0,"delay":float(index) * (0.055 if empowered else 0.10),"life":5.0,"splash_radius":radius,"element":elements[index % elements.size()],"phase":phase})
			events.append({"kind":"slime_burst","pos":enemy.pos,"points":points.duplicate(),"radius":radius,"count":points.size(),"phase":phase})
		"slime_reflux":
			var restored := 0.0
			var hits := 0
			for hero: Dictionary in heroes:
				if not bool(hero.get("deployed", false)) or hero.hp <= 0.0 or not is_in_ability_area(Vector2(enemy.pos), Vector2(hero.pos), radius):
					continue
				var dealt := float(enemy.damage) * (1.15 if empowered else 0.82)
				damage_hero(int(hero.id), dealt, Readability.source(enemy))
				hero.pos = _nearest_walkable_point(Vector2(hero.pos).move_toward(Vector2(enemy.pos), 165.0 if empowered else 110.0), 17.0)
				hero.target = hero.pos
				restored += dealt * (0.80 if empowered else 0.55)
				hits += 1
			enemy.shield = minf(float(enemy.get("max_shield", 0.0)), float(enemy.get("shield", 0.0)) + restored)
			events.append({"kind":"slime_reflux","pos":enemy.pos,"radius":radius,"phase":phase,"hits":hits,"shield":restored})
		"slime_court":
			for index in points.size():
				var angle := float(index) * TAU / maxf(1.0, float(points.size()))
				_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"slime_image","pos":Vector2(enemy.pos) + Vector2.from_angle(angle) * (105.0 if empowered else 82.0),"target_pos":Vector2(points[index]),"damage":float(enemy.damage) * (0.64 if empowered else 0.46),"speed":470.0 if empowered else 400.0,"delay":float(index) * (0.075 if empowered else 0.13),"life":4.0,"splash_radius":radius,"element":elements[index % elements.size()],"phase":phase})
			if empowered:
				_queue_enemy_hazard({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"slime_court_final","pos":Vector2(enemy.pos),"radius":280.0,"delay":1.05,"life":0.55,"damage":float(enemy.damage) * 1.35,"phase":phase})
			events.append({"kind":"slime_court","pos":enemy.pos,"points":points.duplicate(),"radius":radius,"count":points.size(),"phase":phase})
	enemy.special_timer = maxf(3.2, float(enemy.get("boss_pulse", 6.0)) * (0.76 if empowered else 1.0))



func _kindred_live_heroes() -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for hero: Dictionary in heroes:
		if bool(hero.get("deployed", false)) and hero.hp > 0.0:
			live.append(hero)
	return live


func _start_kindred_warning(enemy: Dictionary, move: String) -> void:
	var live := _kindred_live_heroes()
	var phase := int(enemy.get("boss_phase", 1))
	var center := Vector2(enemy.pos) + Vector2.LEFT * 210.0
	var nearest := _nearest_live_hero(Vector2(enemy.pos))
	if not nearest.is_empty():
		center = Vector2(nearest.pos)
	var points: Array[Vector2] = []
	var target_ids: Array[int] = []
	var lead := 1.45
	var radius := 110.0
	var shape := "multi_circle"
	var name := "乱箭之舞"
	match move:
		"kindred_dance":
			name = "乱箭之舞"
			lead = 1.18 if phase >= 3 else 1.38
			radius = 105.0
			for index in mini(3, live.size()):
				points.append(Vector2(live[index].pos))
				target_ids.append(int(live[index].id))
		"kindred_wolf":
			name = "狼灵狂热"
			lead = 1.38 if phase >= 3 else 1.62
			radius = 330.0 if phase >= 3 else 275.0
			shape = "circle"
			points.append(center)
		"kindred_dread":
			name = "横生惧意"
			lead = 1.32 if phase >= 3 else 1.70
			radius = 145.0
			shape = "circle"
			if not live.is_empty():
				live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.hp) > float(b.hp))
				center = Vector2(live[0].pos)
				target_ids.append(int(live[0].id))
			points.append(center)
		"kindred_lasers":
			name = "永猎穿星"
			lead = 1.65
			radius = 14.0
			shape = "rays"
			enemy.kindred_laser_source = Vector2(enemy.pos)
			var aim := center - Vector2(enemy.pos)
			aim.y /= 0.4
			if aim.length_squared() < 1: aim = Vector2.LEFT
			for index in 5:
				var ray := aim.normalized().rotated((index - 2) * 0.16) * 1100.0
				ray.y *= 0.4
				points.append(Vector2(enemy.pos) + ray)
		"kindred_hunt":
			name = "永猎轮舞"
			lead = 1.08 if phase >= 3 else 1.48
			radius = 470.0
			shape = "fan"
			if live.is_empty():
				points.append(Vector2(enemy.pos) + Vector2.LEFT * 720.0)
			else:
				for hero: Dictionary in live:
					points.append(Vector2(hero.pos))
					target_ids.append(int(hero.id))
	if points.is_empty():
		points.append(center)
	events.append({"kind":"boss_skill_charge","skill":move,"duration":lead,"pos":enemy.pos})
	enemy.special_warning = lead
	enemy.special_warning_total = lead
	enemy.special_warning_radius = radius
	enemy.special_warning_shape = shape
	enemy.special_move_name = name
	enemy.special_warning_positions = points
	enemy.kindred_target_ids = target_ids
	for point: Vector2 in points:
		events.append({"kind":"enemy_warning","pos":point,"source":enemy.pos,"radius":radius,"life":lead,"boss":true,"shape":shape,"name":name})


func _execute_kindred_special(enemy: Dictionary, move: String) -> void:
	var points: Array = enemy.get("special_warning_positions", [])
	var target_ids: Array = enemy.get("kindred_target_ids", [])
	var live := _kindred_live_heroes()
	var phase := int(enemy.get("boss_phase", 1))
	var empowered := phase >= 3
	var hits := 0
	var cast_source := Vector2(enemy.pos)
	match move:
		"kindred_dance":
			var dodge_y := 74.0 if int(enemy.get("boss_cast_index", 0)) % 2 == 0 else -74.0
			var dodge_bounds: Rect2 = active_view_rect if endless_mode else MOVE_AREA
			enemy.pos.y = clampf(float(enemy.pos.y) + dodge_y, dodge_bounds.position.y + 48.0, dodge_bounds.end.y - 48.0)
			var arrows_per_target := 4 if empowered else 3
			for target_index in mini(3, target_ids.size()):
				for volley_index in arrows_per_target:
					var spread := float(volley_index) - float(arrows_per_target - 1) * 0.5
					_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"kindred_arrow","pos":Vector2(enemy.pos)+Vector2(-22.0,spread*13.0+target_index*7.0-7.0),"source":Vector2(enemy.pos),"target_id":int(target_ids[target_index]),"damage":float(enemy.damage)*(0.32 if empowered else 0.27),"speed":640.0 if empowered else 590.0,"delay":float(target_index)*0.08+float(volley_index)*0.055,"life":3.2,"phase":phase})
			events.append({"kind":"kindred_dance","source":cast_source,"caster_id":int(enemy.id),"pos":enemy.pos,"points":points.duplicate(),"volleys":arrows_per_target,"phase":phase})
		"kindred_wolf":
			var wolf_center := Vector2(points[0]) if not points.is_empty() else Vector2(enemy.pos)
			var wolf_radius := float(enemy.get("special_warning_radius", 240.0))
			_queue_enemy_hazard({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"kindred_wolf_zone","pos":wolf_center,"radius":wolf_radius,"life":5.4 if empowered else 4.6,"total":5.4 if empowered else 4.6,"pulse":0.0,"damage":float(enemy.damage)*(0.55 if empowered else 0.40),"phase":phase})
			events.append({"kind":"kindred_wolf","caster_id":int(enemy.id),"source":cast_source,"pos":wolf_center,"radius":wolf_radius,"phase":phase})
		"kindred_dread":
			if not target_ids.is_empty():
				var target_id := int(target_ids[0])
				for index in 3:
					_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"kindred_dread_arrow","pos":Vector2(enemy.pos)+Vector2(0.0,index*11.0-11.0),"source":Vector2(enemy.pos),"target_id":target_id,"damage":float(enemy.damage)*([0.42,0.54,1.65][index] if empowered else [0.34,0.44,1.24][index]),"speed":560.0+index*65.0,"delay":float(index)*0.28,"life":3.6,"phase":phase,"dread_stack":index+1})
			events.append({"kind":"kindred_dread","caster_id":int(enemy.id),"source":cast_source,"pos":enemy.pos,"target":Vector2(points[0]) if not points.is_empty() else enemy.pos,"phase":phase})
		"kindred_lasers":
			var origin := Vector2(enemy.get("kindred_laser_source", enemy.pos))
			for hero: Dictionary in live:
				for finish: Vector2 in points:
					var scale := Vector2(1.0, 2.5)
					if _distance_to_segment(Vector2(hero.pos) * scale, origin * scale, finish * scale) <= 14.0:
						damage_hero(int(hero.id), float(enemy.damage) * 1.15, {"source_name": "千珏", "source_skill": "永猎穿星"})
						break # Each hero takes one hit; beams penetrate every hero along their path.
			events.append({"kind":"kindred_lasers", "caster_id":int(enemy.id), "source":origin, "pos":enemy.pos, "points":points.duplicate(), "phase":phase})
		"kindred_hunt":
			if live.is_empty():
				live = _kindred_live_heroes()
			var arrow_count := 28 if empowered else (22 if phase == 2 else 18)
			for index in arrow_count:
				if live.is_empty():
					break
				var target: Dictionary = live[index % live.size()]
				var fan_angle := lerpf(-0.72,0.72,float(index % 8)/7.0)
				_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"kindred_arrow","pos":Vector2(enemy.pos)+Vector2.from_angle(PI+fan_angle)*42.0,"source":Vector2(enemy.pos),"target_id":int(target.id),"damage":float(enemy.damage)*(0.34 if empowered else 0.26),"speed":690.0 if empowered else 590.0,"delay":float(index)*0.055,"life":4.0,"phase":phase})
			events.append({"kind":"kindred_hunt","caster_id":int(enemy.id),"source":cast_source,"pos":enemy.pos,"points":points.duplicate(),"count":arrow_count,"phase":phase})
	enemy.special_timer = maxf(3.4, float(enemy.get("boss_pulse", 5.8)) * (0.74 if empowered else (0.86 if phase == 2 else 1.0)))


func _activate_kindred_respite(enemy: Dictionary) -> void:
	enemy.kindred_respite_used = true
	enemy.kindred_respite_active = true
	enemy.kindred_respite_timer = 5.0
	enemy.kindred_respite_center = Vector2(enemy.pos)
	enemy.kindred_respite_radius = 285.0
	enemy.hp = maxf(1.0, float(enemy.hp))
	events.append({"kind":"kindred_respite","caster_id":int(enemy.id),"pos":enemy.kindred_respite_center,"radius":enemy.kindred_respite_radius,"duration":5.0,"phase":int(enemy.get("boss_phase", 1))})


func _tick_kindred_respite(enemy: Dictionary, dt: float) -> void:
	if not bool(enemy.get("kindred_respite_active", false)):
		return
	enemy.hp = maxf(1.0, float(enemy.hp))
	enemy.kindred_respite_timer = maxf(0.0, float(enemy.get("kindred_respite_timer", 0.0)) - dt)
	if enemy.kindred_respite_timer > 0.0:
		return
	enemy.kindred_respite_active = false
	var center := Vector2(enemy.get("kindred_respite_center", enemy.pos))
	var radius := float(enemy.get("kindred_respite_radius", 285.0))
	var boss_heal := float(enemy.max_hp) * 0.50
	enemy.hp = minf(float(enemy.max_hp), float(enemy.hp) + boss_heal)
	for hero: Dictionary in heroes:
		if not bool(hero.get("deployed", false)) or not is_in_ability_area(center, Vector2(hero.pos), radius):
			continue
		var was_down := float(hero.hp) <= 0.0
		var healing := float(hero.max_hp) * 0.50
		hero.hp = minf(float(hero.max_hp), maxf(0.0, float(hero.hp)) + healing)
		if was_down and hero.hp > 0.0:
			hero.animation_state = "idle"
			hero.status_timer = 0.0
			hero.target = hero.pos
			hero.moving = false
		events.append({"kind":"heal","pos":hero.pos,"value":ceili(healing),"hero_id":int(hero.id)})
	events.append({"kind":"kindred_respite_end","pos":center,"radius":radius,"value":ceili(boss_heal)})


func _maybe_summon_galio(kindred: Dictionary) -> void:
	if (not endless_mode and current_stage_id != "stage_03") or bool(kindred.get("galio_summoned", false)):
		return
	if float(kindred.hp) / maxf(1.0, float(kindred.max_hp)) > 0.10:
		return
	kindred.galio_summoned = true
	var shield_gain := float(kindred.max_hp) * 0.30
	kindred.max_shield = maxf(float(kindred.get("max_shield", 0.0)), float(kindred.get("shield", 0.0)) + shield_gain)
	kindred.shield = minf(float(kindred.max_shield), float(kindred.get("shield", 0.0)) + shield_gain)
	var spawn_point := _nearest_walkable_point(Vector2(kindred.pos) + Vector2(155.0, 52.0), 48.0)
	var galio := spawn_enemy(spawn_point, "boss_galio")
	if endless_mode:
		_scale_endless_boss(galio, maxi(1,int(kindred.get("endless_boss_number",endless_boss_index))))
	galio.route_points = []
	galio.route_index = 0
	galio.galio_revealed = false
	galio.galio_takeoff_pos = spawn_point
	galio.special_move = "galio_entrance"
	galio.special_pending = true
	galio.special_timer = 0.05
	_start_galio_warning(galio, "galio_entrance")
	events.append({"kind":"galio_guard","pos":kindred.pos,"source":galio.pos,"value":ceili(shield_gain)})
	events.append({"kind":"boss_warning","pos":galio.pos,"name":"英雄登场","phase":1,"duration":float(galio.special_warning_total),"boss_kind":"boss_galio"})

func _start_galio_warning(enemy: Dictionary, move: String) -> void:
	var nearest := _nearest_live_hero(Vector2(enemy.pos))
	var target := Vector2(nearest.pos) if not nearest.is_empty() else Vector2(enemy.pos) + Vector2.LEFT * 260.0
	var lead := 1.45
	var radius := 220.0
	var shape := "circle"
	var name := "英雄登场"
	match move:
		"galio_entrance":
			for ally: Dictionary in enemies:
				if str(ally.get("kind", "")) == "boss_03" and float(ally.get("hp", 0.0)) > 0.0:
					target = _nearest_walkable_point(Vector2(ally.pos) + Vector2(-86.0, 58.0), 48.0)
					enemy.galio_guard_target_id = int(ally.id)
					enemy.galio_guard_pos = Vector2(ally.pos)
					break
			lead = 2.30 if int(enemy.get("boss_phase", 1)) < 3 else 1.90
			radius = 1050.0 if int(enemy.get("boss_phase", 1)) >= 3 else 850.0
			name = "英雄登场"
		"galio_punch":
			lead = 1.25
			radius = 105.0
			shape = "line"
			name = "正义冲拳"
		"galio_winds":
			lead = 1.40
			radius = 175.0
			name = "战争罡风"
		"galio_durand":
			lead = 1.65
			radius = 570.0
			target = Vector2(enemy.pos)
			name = "杜朗护盾"
	events.append({"kind":"boss_skill_charge","skill":move,"duration":lead,"pos":enemy.pos})
	enemy.special_warning = lead
	enemy.special_warning_total = lead
	enemy.special_warning_radius = radius
	enemy.special_warning_shape = shape
	enemy.special_move_name = name
	enemy.special_warning_positions = [target]
	enemy.galio_target = target
	if move == "galio_entrance":
		enemy.galio_landing_pos = target
	events.append({"kind":"enemy_warning","pos":target,"source":enemy.pos,"radius":radius,"life":lead,"boss":true,"shape":shape,"name":name})

func _execute_galio_special(enemy: Dictionary, move: String) -> void:
	var center := Vector2(enemy.get("galio_target", enemy.pos))
	var phase := int(enemy.get("boss_phase", 1))
	var radius := float(enemy.get("special_warning_radius", 220.0))
	var hits := 0
	var cast_source := Vector2(enemy.pos)
	var cast_finish := center
	var hit_positions: Array[Vector2] = []
	match move:
		"galio_entrance":
			enemy.pos = _nearest_walkable_point(center, 48.0)
			enemy.galio_revealed = true
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(center, Vector2(hero.pos), radius):
					damage_hero(int(hero.id), float(enemy.damage) * (1.75 if phase >= 3 else 1.35), Readability.source(enemy))
					var away := (Vector2(hero.pos) - center).normalized()
					hero.pos = _nearest_walkable_point(Vector2(hero.pos) + away * (115.0 if phase >= 3 else 82.0), 17.0)
					hero.target = hero.pos
					hits += 1
		"galio_punch":
			var direction := (center - Vector2(enemy.pos)).normalized()
			if direction.length_squared() < 0.01:
				direction = Vector2.LEFT
			var finish := Vector2(enemy.pos) + direction * 520.0
			cast_finish = finish
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and _distance_to_segment(Vector2(hero.pos), Vector2(enemy.pos), finish) <= radius:
					damage_hero(int(hero.id), float(enemy.damage) * 1.45, Readability.source(enemy))
					hero.pos = _nearest_walkable_point(Vector2(hero.pos) + direction * 125.0, 17.0)
					hero.target = hero.pos
					hits += 1
			enemy.pos = _nearest_walkable_point(Vector2(enemy.pos).move_toward(finish, 300.0), 48.0)
		"galio_winds":
			_queue_enemy_hazard({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"kind":"galio_winds","pos":center,"source":Vector2(enemy.pos),"radius":radius,"delay":0.72,"travel_total":0.72,"life":5.2,"total":5.2,"pulse":0.0,"damage":float(enemy.damage) * 0.38,"phase":phase})
		"galio_durand":
			var own_gain := float(enemy.max_hp) * (0.28 if phase >= 3 else 0.20)
			enemy.max_shield = maxf(float(enemy.get("max_shield", 0.0)), float(enemy.get("shield", 0.0)) + own_gain)
			enemy.shield = minf(float(enemy.max_shield), float(enemy.get("shield", 0.0)) + own_gain)
			for ally: Dictionary in enemies:
				if str(ally.get("kind", "")) == "boss_03" and ally.hp > 0.0:
					var ally_gain := float(ally.max_hp) * 0.15
					ally.max_shield = maxf(float(ally.get("max_shield", 0.0)), float(ally.get("shield", 0.0)) + ally_gain)
					ally.shield = minf(float(ally.max_shield), float(ally.get("shield", 0.0)) + ally_gain)
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(Vector2(enemy.pos), Vector2(hero.pos), radius):
					hit_positions.append(Vector2(hero.pos))
					damage_hero(int(hero.id), float(enemy.damage) * 0.72, Readability.source(enemy))
					hero.pos = _nearest_walkable_point(Vector2(hero.pos).move_toward(Vector2(enemy.pos), 105.0), 17.0)
					hero.target = hero.pos
					hits += 1
	events.append({"kind":move,"pos":center,"source":cast_source,"finish":cast_finish,"caster_id":int(enemy.id),"hit_positions":hit_positions,"radius":radius,"hits":hits,"phase":phase})
	enemy.special_timer = maxf(3.5, float(enemy.get("boss_pulse", 6.2)) * (0.72 if phase >= 3 else (0.84 if phase == 2 else 1.0)))

func _hero_protected_by_kindred(hero: Dictionary) -> bool:
	for enemy: Dictionary in enemies:
		if str(enemy.get("kind", "")) != "boss_03" or not bool(enemy.get("kindred_respite_active", false)):
			continue
		var center := Vector2(enemy.get("kindred_respite_center", enemy.pos))
		var radius := float(enemy.get("kindred_respite_radius", 285.0))
		if bool(hero.get("deployed", false)) and is_in_ability_area(center, Vector2(hero.pos), radius):
			return true
	return false


func _execute_boss_special(enemy: Dictionary) -> void:
	var phase := int(enemy.get("boss_phase", 1))
	var move := str(enemy.get("special_move", "pulse"))
	if str(enemy.get("kind", "")) == "boss_01" and move.begins_with("rift_"):
		_execute_rift_special(enemy, move)
		return
	if str(enemy.get("kind", "")) == "boss_02" and move.begins_with("slime_"):
		_execute_slime_special(enemy, move)
		return
	if str(enemy.get("kind", "")) == "boss_03" and move.begins_with("kindred_"):
		_execute_kindred_special(enemy, move)
		return
	if str(enemy.get("kind", "")) == "boss_galio" and move.begins_with("galio_"):
		_execute_galio_special(enemy, move)
		return
	var hit_count := 0
	var summon_count := 0
	match move:
		"summon":
			summon_count = _boss_summon(enemy, "grunt", 2 + phase)
		"charge_summon":
			summon_count = _boss_summon(enemy, "charger", 2 + phase)
		"elite_summon":
			summon_count = _boss_summon(enemy, "armored", 2)
			summon_count += _boss_summon(enemy, "warder", 1)
		"runner_summon":
			summon_count = _boss_summon(enemy, "runner", 3 + phase)
		"splitter_summon":
			summon_count = _boss_summon(enemy, "splitter", 2 + phase)
		"swarm":
			summon_count = _boss_summon(enemy, "runner", 5 + phase)
		"flyer_summon":
			summon_count = _boss_summon(enemy, "flyer", 2 + phase)
		"warder_summon":
			summon_count = _boss_summon(enemy, "warder", 1 + phase)
		"ranged_summon":
			summon_count = _boss_summon(enemy, "ranged", 2 + phase)
		"heal_summon":
			summon_count = _boss_summon(enemy, "healer", 1 + phase)
		"guard":
			for ally: Dictionary in enemies:
				if ally.hp > 0.0 and ally.pos.distance_to(enemy.pos) <= 360.0:
					var shield_gain := 95.0 + phase * 55.0
					ally.shield = float(ally.get("shield", 0.0)) + shield_gain
					ally.max_shield = maxf(float(ally.get("max_shield", 0.0)), float(ally.shield))
				hit_count += 1
		"terrain_break":
			for construct: Dictionary in geo_constructs.duplicate():
				if construct.hp > 0.0:
					damage_construct(int(construct.id), float(construct.max_hp) * 1.25)
					hit_count += 1
		"pull":
			hit_count = _boss_damage_warned(enemy, 0.34 + phase * 0.06, "pull")
		"knockback", "shockwave":
			hit_count = _boss_damage_warned(enemy, 0.42 + phase * 0.08, "knockback")
		"slow", "slow_field":
			hit_count = _boss_damage_warned(enemy, 0.28 + phase * 0.05, "slow")
		"silence":
			hit_count = _boss_damage_warned(enemy, 0.32 + phase * 0.05, "silence")
		"drain":
			hit_count = _boss_damage_warned(enemy, 0.38 + phase * 0.06, "drain")
		"rewind":
			enemy.hp = minf(float(enemy.max_hp), float(enemy.hp) + float(enemy.max_hp) * 0.15)
			hit_count = _boss_damage_warned(enemy, 0.36 + phase * 0.06, "silence")
		"burning_ground":
			hit_count = _boss_damage_warned(enemy, 0.48 + phase * 0.07, "burn")
		"artillery", "triple_artillery", "carpet_bomb":
			var multiplier := 0.70 if move == "artillery" else (0.82 if move == "triple_artillery" else 0.96)
			hit_count = _boss_damage_warned(enemy, multiplier + phase * 0.06)
		"crossfire", "fan_burst", "sweep", "spiral":
			hit_count = _boss_damage_warned(enemy, 0.52 + phase * 0.08, "knockback" if move in ["fan_burst", "spiral"] else "")
		_:
			hit_count = _boss_damage_warned(enemy, 0.38 + phase * 0.06)
	if summon_count > 0:
		enemy.summons_done = int(enemy.get("summons_done", 0)) + summon_count
		events.append({"kind":"boss_summon","pos":enemy.pos,"value":summon_count})
	events.append({"kind":"boss_move","pos":enemy.pos,"value":move,"name":str(enemy.get("special_move_name","首领技能")),"phase":phase,"shape":str(enemy.get("special_warning_shape","circle")),"hits":hit_count})
	enemy.special_timer = maxf(2.6, float(enemy.get("boss_pulse", 6.0)) * (0.90 if phase == 2 else (0.76 if phase == 3 else 1.0)))

func _bounded_endless_summon_kind(kind: String, index: int) -> String:
	if not endless_mode:
		return kind
	if enemies.size() >= _endless_active_cap():
		return ""
	if kind == "splitter" and _endless_kind_count(["splitter"]) >= ENDLESS_HUT_CAP:
		return _endless_quality_enemy(maxi(1, floori(elapsed / 60.0) + 1), index)
	if kind in ENDLESS_LOW_TIER_IDS and _endless_kind_count(ENDLESS_LOW_TIER_IDS) >= _endless_low_tier_cap():
		return _endless_quality_enemy(maxi(1, floori(elapsed / 60.0) + 1), index)
	return kind

func _boss_summon(enemy: Dictionary, kind: String, count: int) -> int:
	var spawned := 0
	for index in count:
		if not performance_budget.allow_enemy(enemies.size()):
			break
		var resolved_kind := _bounded_endless_summon_kind(kind, index)
		if resolved_kind.is_empty():
			break
		var direction := Vector2.from_angle(float(index) * TAU / maxf(1.0, float(count)))
		var spawn_point: Vector2 = enemy.pos + direction * (64.0 + (index % 2) * 28.0)
		if endless_mode and resolved_kind == "splitter":
			spawn_point = _endless_interior_spawn_point(index % 4, 0.24 + fposmod(index * 0.27, 0.52))
		var minion := spawn_enemy(spawn_point, resolved_kind)
		if endless_mode:
			_apply_endless_scaling(minion, _endless_tier(), 0.78)
		minion.hp *= 0.72 + int(enemy.get("boss_phase", 1)) * 0.08
		minion.max_hp = minion.hp
		spawned += 1
	return spawned

func _boss_damage_warned(enemy: Dictionary, multiplier: float, control: String = "") -> int:
	var hits := 0
	var drained := 0.0
	var bounds := ENDLESS_ARENA.grow(-28.0) if endless_mode else MOVE_AREA
	for hero: Dictionary in heroes:
		if hero.hp <= 0.0 or not bool(hero.get("deployed", false)) or not _hero_in_boss_warning(hero, enemy):
			continue
		if not bool(enemy.get("flying", false)) and terrain_line_blocked(enemy.pos, hero.pos):
			continue
		var amount := float(enemy.damage) * multiplier
		damage_hero(int(hero.id), amount, Readability.source(enemy))
		hits += 1
		if control == "knockback":
			var away: Vector2 = (hero.pos - enemy.pos).normalized()
			hero.pos = Vector2(clampf(hero.pos.x + away.x * 78.0, bounds.position.x, bounds.end.x), clampf(hero.pos.y + away.y * 78.0, bounds.position.y, bounds.end.y))
		elif control == "pull":
			hero.pos = hero.pos.move_toward(enemy.pos, 92.0)
		if control in ["knockback", "pull"]:
			hero.pos = _nearest_walkable_point(hero.pos, 17.0)
			hero.target = hero.pos
		elif control in ["slow", "silence"]:
			hero.skill_cooldown = float(hero.get("skill_cooldown", 0.0)) + (2.0 if control == "slow" else 4.0)
		if control == "drain":
			drained += amount
	if drained > 0.0:
		enemy.hp = minf(float(enemy.max_hp), float(enemy.hp) + drained * float(enemy.get("life_steal", 0.55)))
		events.append({"kind":"enemy_heal","pos":enemy.pos,"value":ceili(drained * float(enemy.get("life_steal", 0.55)))})
	return hits

func _hero_in_boss_warning(hero: Dictionary, enemy: Dictionary) -> bool:
	var shape := str(enemy.get("special_warning_shape", "circle"))
	var radius := float(enemy.get("special_warning_radius", 150.0))
	var source: Vector2 = enemy.pos
	for point_value: Variant in enemy.get("special_warning_positions", []):
		var point: Vector2 = point_value
		var delta: Vector2 = hero.pos - point
		match shape:
			"donut":
				if delta.length() >= radius * 0.38 and delta.length() <= radius: return true
			"line", "multi_line", "rectangle":
				if _distance_to_segment(hero.pos, source, point) <= (34.0 if shape == "line" else 52.0): return true
			"cross":
				if maxf(absf(delta.x), absf(delta.y)) <= radius and (absf(delta.x) <= 34.0 or absf(delta.y) <= 34.0): return true
			"fan", "cone":
				var aim := (point - source).normalized()
				var offset: Vector2 = hero.pos - source
				if offset.length() <= radius * 1.45 and offset.length() > 0.0 and aim.dot(offset.normalized()) >= 0.62: return true
			"checker":
				if absf(delta.x) <= radius and absf(delta.y) <= radius and (floori(absf(delta.x) / 48.0) + floori(absf(delta.y) / 36.0)) % 2 == 0: return true
			_:
				if delta.length() <= radius: return true
	return false

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	if segment.length_squared() <= 0.001:
		return point.distance_to(start)
	var ratio := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * ratio)

func damage_construct(id: int, damage: float) -> void:
	for construct: Dictionary in geo_constructs:
		if construct.id != id or construct.hp <= 0.0:
			continue
		var received := maxf(1.0, damage - float(construct.get("armor", 0.0))) if bool(construct.get("device", false)) and damage > 0.0 else damage
		construct.hp = maxf(0.0, float(construct.hp) - received)
		events.append({"kind": "geo_hit", "pos": construct.pos, "value": ceili(received)})
		if construct.hp <= 0.0:
			events.append({"kind": "geo_break", "pos": construct.pos})
		return

func deployment_required_level(hero_id: int) -> int:
	var levels: Array = stage_runtime.definition.get("deployment_levels", [1, 3, 6]) if stage_runtime != null else [1, 3, 6]
	return int(levels[clampi(hero_id, 0, 2)])

func deployment_slot_unlocked(hero_id: int) -> bool:
	if endless_mode:
		return true
	if rejected_recruits.has(hero_id):
		return false
	var required_level: int = deployment_required_level(hero_id)
	return run_state.crystal_level >= required_level

func is_device_plant_cell(point: Vector2) -> bool:
	for device: Dictionary in battle_devices.placed:
		if float(device.hp) > 0.0 and str(device.kind) in BattleDevices.BLOCKING_PLANTS and Rect2(device.cell).has_point(point): return true
	return false

func deploy_hero(hero_id: int, point: Vector2, allow_reward_state: bool = false) -> bool:
	var valid_state := state in ["running", "between"] or (allow_reward_state and state == "reward")
	if not valid_state or hero_id < 0 or hero_id >= heroes.size() or not deployment_slot_unlocked(hero_id):
		return false
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0.0:
		return false
	var bounds := ENDLESS_ARENA.grow(-36.0) if endless_mode else MOVE_AREA
	point.x = clampf(point.x, bounds.position.x, bounds.end.x)
	point.y = clampf(point.y, bounds.position.y, bounds.end.y)
	if is_device_plant_cell(point): return false
	point = _resolve_walkable_target(point)
	if is_device_plant_cell(point): return false
	hero.pos = point
	hero.target = point
	hero.deployed = true
	hero.moving = false
	if str(hero.get("passive",{}).get("kind","")) == "guardian_spirit":
		crystal_shield = minf(500.0, crystal_shield+90.0)
		events.append({"kind":"crystal_guard","pos":point,"value":90})
	events.append({"kind":"deploy","pos":point,"hero_id":hero_id,"value":hero.name})
	return true

func recall_hero(hero_id: int) -> bool:
	if hero_id < 0 or hero_id >= heroes.size() or hero_id == 0 and endless_mode:
		return false
	var hero: Dictionary = heroes[hero_id]
	hero.deployed = false
	hero.blocked = 0
	hero.target = hero.pos
	events.append({"kind":"recall","pos":hero.pos,"hero_id":hero_id})
	return true

func hero_ability(hero_id: int, ultimate: bool) -> Dictionary:
	if hero_id < 0 or hero_id >= heroes.size(): return {}
	var hero: Dictionary = heroes[hero_id]
	if str(hero.get("character_id","")) == "traveler":
		var element := normalize_element(str(hero.get("element","")))
		if TravelerElements.supports(element,ultimate): return TravelerElements.definition(element,ultimate)
	return hero.get("ultimate" if ultimate else "active_skill",{})

func hero_skill_name(hero_id: int) -> String:
	if hero_id < 0 or hero_id >= heroes.size():
		return "主动技能"
	return str(hero_ability(hero_id,false).get("name", "主动技能"))

func hero_ultimate_name(hero_id: int) -> String:
	if hero_id < 0 or hero_id >= heroes.size():
		return "终结技"
	return str(hero_ability(hero_id,true).get("name", "终结技"))

func set_active_view_rect(rect: Rect2) -> void:
	active_view_rect = rect.intersection(ENDLESS_ARENA) if endless_mode else MOVE_AREA

func _ability_target_visible(point: Vector2) -> bool:
	return not endless_mode or active_view_rect.grow(4.0).has_point(point)

func _clamp_ability_target(target: Vector2) -> Vector2:
	var bounds := active_view_rect.grow(-24.0) if endless_mode else MOVE_AREA.grow(-12.0)
	return Vector2(clampf(target.x, bounds.position.x, bounds.end.x), clampf(target.y, bounds.position.y, bounds.end.y))

func activate_hero_skill(hero_id: int, target: Vector2) -> bool:
	if state != "running" or hero_id < 0 or hero_id >= heroes.size():
		return false
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0.0 or not bool(hero.get("deployed", false)) or float(hero.get("skill_cooldown", 0.0)) > 0.0:
		return false
	target = _clamp_ability_target(target)
	if hero.get("character_id", "") == "traveler":
		var element := traveler_skill_element()
		if TravelerElements.supports(element,false):
			var revised := hero_ability(hero_id,false)
			hero.skill_cooldown = float(revised.cooldown)*maxf(0.35,1.0-skill_cooldown_reduction)
			traveler_skill_cooldown_max = hero.skill_cooldown
			traveler_skill_cooldown = hero.skill_cooldown
			hero.skill_uses = int(hero.skill_uses)+1
			_queue_ability(hero,revised,target,false)
			return true
		traveler_skill_cooldown_max = float({"none": 9.0, "anemo": 16.0, "electro": 14.0, "pyro": 15.0, "hydro": 18.0, "geo": 13.0, "cryo": 17.0}.get(element, 15.0))
		traveler_skill_cooldown_max *= maxf(0.35, 1.0 - skill_cooldown_reduction)
		traveler_skill_cooldown = traveler_skill_cooldown_max
		hero.skill_cooldown = traveler_skill_cooldown_max
		hero.skill_uses = int(hero.skill_uses) + 1
		pending_impacts.append({"life":0.34,"kind":"traveler_skill","hero_id":hero.id,"target_pos":target})
		events.append({"kind":"skill_cast","pos":hero.pos,"target":target,"hero_id":hero.id,"value":traveler_skill_name(),"hit_delay":0.34,"traveler_element":element})
		return true
	var ability: Dictionary = hero.get("active_skill", {})
	hero.skill_cooldown = float(ability.get("cooldown", 10.0)) * maxf(0.35, 1.0 - skill_cooldown_reduction)
	hero.skill_uses = int(hero.skill_uses) + 1
	_queue_ability(hero, ability, target, false)
	return true

func activate_hero_ultimate(hero_id: int, target: Vector2) -> bool:
	if state != "running" or hero_id < 0 or hero_id >= heroes.size():
		return false
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0.0 or not bool(hero.get("deployed", false)) or float(hero.get("energy", 0.0)) < float(hero.get("max_energy", 100.0)) or float(hero.get("ultimate_cooldown", 0.0)) > 0.0:
		return false
	target = _clamp_ability_target(target)
	var ability: Dictionary = hero_ability(hero_id,true)
	hero.energy = 0.0
	hero.ultimate_cooldown_max = maxf(40.0, float(ability.get("cooldown", 40.0)) * maxf(0.55, 1.0 - skill_cooldown_reduction * 0.55))
	hero.ultimate_cooldown = hero.ultimate_cooldown_max
	hero.ultimate_uses = int(hero.ultimate_uses) + 1
	_queue_ability(hero, ability, target, true)
	return true

func _queue_ability(hero: Dictionary, ability: Dictionary, target: Vector2, ultimate: bool) -> void:
	if TravelerElements.handles(str(ability.get("kind",""))):
		target = TravelerElements.target_point(self,hero,target)
		events.append({"kind":"traveler_fx_cast","pos":target,"source":hero.pos,"radius":ability.radius*(1.0+skill_area_bonus),"element":ability.element,"skill":str(ability.kind).trim_prefix("traveler_"),"delay":float(CombatTimeline.compile(ability,ultimate).hit_frame)})
	if SELF_CENTERED_ABILITY_KINDS.has(str(ability.get("kind", ""))):
		target = Vector2(hero.pos)
	if HeroSignature.handles(str(ability.get("kind", ""))):
		target = HeroSignature.target_point(self, hero, ability, target)
	var timeline: Dictionary = CombatTimeline.compile(ability, ultimate)
	hero.animation_state = "ultimate" if ultimate else "skill"
	hero.status_timer = float(timeline.duration)
	pending_impacts.append({"life":float(timeline.hit_frame),"kind":"ability","hero_id":hero.id,"target_pos":target,"ability":ability.duplicate(true),"ultimate":ultimate,"timeline":timeline})
	events.append({"kind":"ultimate_cast" if ultimate else "skill_cast","pos":hero.pos,"target":target,"hero_id":hero.id,"value":str(ability.get("name","技能")),"hit_delay":float(timeline.hit_frame),"duration":float(timeline.duration),"targeting":str(ability.get("targeting","point")),"traveler_rework":TravelerElements.handles(str(ability.get("kind","")))})
	events.append({"kind":"vfx_cue","pos":hero.pos if SELF_CENTERED_ABILITY_KINDS.has(str(ability.get("kind", ""))) else target,"hero_id":hero.id,"profile":"ultimate_burst" if ultimate else "skill_field","delay":float(timeline.vfx_frame),"value":str(ability.get("kind","burst")),"traveler_rework":TravelerElements.handles(str(ability.get("kind","")))})

func _pending_impact_tick(dt: float) -> void:
	var due := pending_impacts
	pending_impacts = []
	for impact: Dictionary in due:
		impact.life = float(impact.life) - dt
		if impact.life > 0.0:
			pending_impacts.append(impact)
			continue
		if impact.kind == "bug_blast":
			EnemyTactics.explode(self,impact)
			continue
		if impact.kind == "fireball_support":
			_resolve_fireball_support(impact)
			continue
		var hero_id := int(impact.get("hero_id", -1))
		if hero_id < 0 or hero_id >= heroes.size() or heroes[hero_id].hp <= 0.0:
			continue
		var hero: Dictionary = heroes[hero_id]
		if impact.kind == "traveler_skill":
			traveler_skill_cooldown = 0.0
			damage_source_override = hero_id
			activate_traveler_skill(impact.get("target_pos", hero.pos))
			damage_source_override = -1
			events.append({"kind":"skill_impact","pos":impact.get("target_pos",hero.pos),"hero_id":hero_id,"value":traveler_skill_name(),"element":hero.element,"radius":traveler_skill_radius() * (1.0 + skill_area_bonus),"character_id":"traveler","traveler_element":traveler_skill_element()})
		elif impact.kind == "melee":
			var victim := find_enemy(int(impact.get("target_id", -1)))
			if victim.is_empty() or not is_in_attack_range(hero, victim.pos):
				continue
			# Attribution for audio only; never feeds damage multipliers/statistics.
			attack_audio_source_override = hero_id
			var dealt := apply_hit(victim, float(impact.damage), str(impact.element), hero_id, bool(impact.get("critical", false)))
			if bool(impact.get("critical", false)):
				events.append({"kind":"critical","pos":victim.pos,"value":ceili(dealt),"hero_id":hero_id})
			var secondary := normalize_element(str(impact.get("secondary_element", "")))
			if not secondary.is_empty() and victim.hp > 0.0:
				apply_hit(victim, float(impact.damage) * 0.85, secondary, hero_id)
			if bool(hero.get("cleave", false)):
				splash_damage(victim, float(impact.damage) * float(hero.get("cleave_ratio", 0.5)), 145.0 + float(hero.get("pierce", 0)) * 18.0, hero)
			_apply_attack_extras(victim, hero, float(impact.damage))
			attack_audio_source_override = -1
			events.append({"kind":"synced_impact","pos":victim.pos,"hero_id":hero_id,"value":ceili(dealt)})
		else:
			_execute_ability_impact(hero, impact.get("ability", {}), impact.get("target_pos", hero.pos), bool(impact.get("ultimate", false)))

func _resolve_fireball_support(impact: Dictionary) -> void:
	var target: Vector2 = impact.target_pos
	var radius := float(impact.radius)
	for enemy: Dictionary in enemies.duplicate():
		if enemy.hp > 0.0 and is_in_ability_area(target,enemy.pos,radius):
			apply_hit(enemy, float(impact.damage), "geo")
			enemy.slow_timer=maxf(float(enemy.slow_timer),2.0)

	events.append({"kind": "fireball_impact", "pos": target, "radius": radius})

func _execute_ability_impact(hero: Dictionary, ability: Dictionary, target: Vector2, ultimate: bool) -> void:
	events.append({"kind":"ability_audio","hero_id":hero.id,"character_id":str(hero.get("character_id","traveler")),"ability_kind":str(ability.get("kind","")),"ultimate":ultimate,"pos":target})
	var kind := str(ability.get("kind", "burst"))
	var radius := float(ability.get("radius", 180.0)) * (1.0 + skill_area_bonus) * (1.2 if ultimate and run_state.equipped_relics.has("relic_resonant_core") else 1.0)
	var power := (float(ability.get("power", 160.0)) + displayed_attack_damage(hero) * float(ability.get("attack_ratio", 0.0))) * (1.0 + skill_power_bonus)
	var passive_kind := str(hero.get("passive", {}).get("kind", ""))
	if passive_kind == "mana_surge": power *= 1.0 + float(hero.energy) / maxf(1.0, float(hero.max_energy)) * 0.35
	if passive_kind == "resolve" and float(hero.hp) / maxf(1.0, float(hero.max_hp)) <= 0.5: power *= 1.45
	if TravelerElements.handles(kind):
		TravelerElements.start(self,hero,ability,target,power,radius)
		return
	if HeroSignature.handles(kind):
		HeroSignature.start(self, hero, ability, target, power, radius)
		return
	match kind:
		"healing_surge":
			_heal_heroes(target, radius, power, 0.0)
		"wind_cut":
			var wind_row := clampi(floori((float(hero.pos.y) - GRID_ORIGIN.y) / GRID_CELL_SIZE.y), 1, GRID_ROWS - 2)
			var wind_left := active_view_rect.position.x if endless_mode else GRID_ORIGIN.x
			var wind_right := active_view_rect.end.x if endless_mode else GRID_ORIGIN.x + GRID_COLUMNS * GRID_CELL_SIZE.x
			skill_effects.append({"kind":"wind_cut_rows","pos":hero.pos,"life":2.35,"pulse":0.0,"remaining":3,"power":power * 0.65,"hero_id":hero.id,"center_row":wind_row,"left_x":wind_left,"right_x":wind_right})
		"columbia_tide_ring":
			skill_effects.append({"kind":"columbia_tide_ring","pos":hero.pos,"life":10.0,"pulse":0.0,"power":power,"area":radius,"hero_id":hero.id,"visual":"columbia_tide_ring"})
		"columbia_tidal_benediction":
			var bonuses: Dictionary = {}
			var recipients: Array[int] = []
			var attack_bonus := float(hero.damage)
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0:
					bonuses[int(ally.id)] = attack_bonus
					ally.damage += attack_bonus
					recipients.append(int(ally.id))
			skill_effects.append({"kind":"columbia_attack_blessing","pos":hero.pos,"life":25.0,"pulse":25.0,"hero_id":hero.id,"bonuses":bonuses,"ally_ids":recipients,"visual":"columbia_blessing"})
		"thread_shelter":
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)) and float(ally.get("hp", 0.0)) > 0.0 and is_in_ability_area(hero.pos, Vector2(ally.pos), radius):
					ally.invulnerable_timer = maxf(float(ally.get("invulnerable_timer", 0.0)), 5.0)
					events.append({"kind":"crystal_guard","pos":ally.pos,"value":5})
		"renewing_breeze":
			skill_effects.append({"kind":"renewing_breeze","pos":target,"life":12.0,"pulse":0.0,"power":power,"area":radius,"hero_id":hero.id,"visual":"fengjin_breeze" if str(hero.get("character_id", "")) == "hero_10" else ""})
		"heal_gust":
			_heal_heroes(hero.pos, radius, power, 0.0)
			crystal_shield = minf(500.0, crystal_shield + 50.0)
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)) and ally.hp>0 and is_in_ability_area(hero.pos,ally.pos,radius):
					ally.invulnerable_timer=maxf(float(ally.get("invulnerable_timer",0)),1.5)
		"anemo_domain":
			_damage_area(target, radius, power, "anemo", hero.id, "pull")
			skill_effects.append({"kind":"anemo_domain","pos":target,"life":7.0,"pulse":0.0,"power":power*0.18,"area":radius/180.0,"hero_id":hero.id,"visual":"sylphie_domain"})
		"hydro_burst":
			_damage_area(target, radius, power, "hydro", hero.id)
		"storm_field":
			_damage_area(target, radius, power*0.65, "hydro", hero.id)
			skill_effects.append({"kind":"storm_field","pos":target,"life":9.0,"pulse":0.0,"power":power*0.22,"area":radius/190.0,"hero_id":hero.id,"visual":"roxy_storm" if str(hero.get("character_id", "")) == "hero_04" else ""})
		"sonic_wave":
			_damage_area(target, radius, power * 1.15, "pyro", hero.id, "knockback")
			skill_effects.append({"kind":"burning_ground","pos":target,"life":5.0,"pulse":0.0,"power":power*0.20,"area":radius/105.0,"hero_id":hero.id,"visual":"saki_score_q"})
		"team_concert":
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0:
					ally.rate += ally.base_rate*0.32
					gain_hero_energy(ally,24.0)
					ally.skill_cooldown = maxf(0.0, ally.skill_cooldown-3.0)
		"cryo_chord":
			_damage_area(target, radius, power, "cryo", hero.id, "freeze")
		"fate_symphony":
			_damage_area(target, radius, power * 1.35, "pyro", hero.id, "knockback")
			skill_effects.append({"kind":"burning_ground","pos":target,"life":10.0,"pulse":0.0,"power":power*0.28,"area":radius/105.0,"hero_id":hero.id,"visual":"saki_score_e"})
			for ally: Dictionary in heroes: ally.crit_chance = minf(0.85, ally.crit_chance+0.18)
		"frost_bloom":
			_damage_area(target, radius, power, "cryo", hero.id, "freeze")
		"frozen_forest":
			_damage_area(target, radius, power*0.75, "cryo", hero.id, "freeze")
			skill_effects.append({"kind":"frozen_forest","pos":target,"life":12.0,"pulse":0.0,"power":power*0.16,"area":radius/210.0,"hero_id":hero.id,"visual":"emilia_forest" if str(hero.get("character_id", "")) == "hero_08" else ""})
		"echo_shot":
			_damage_area(target, radius, power, "hydro", hero.id)
			_damage_area(target, radius*0.72, power*0.55, "hydro", hero.id)
		"encore":
			_heal_heroes(hero.pos, 9999.0, power*0.28, 0.0)
			for ally: Dictionary in heroes:
				ally.skill_cooldown = 0.0
				gain_hero_energy(ally,18.0)
		"tribbie_gate":
			orbitals.append({"hero_id":hero.id,"count":2,"damage":power*0.30,"radius":radius,"timer":0.1,"interval":0.46,"life":9.0,"element":hero.element,"visual":"gate"})
			skill_effects.append({"kind":"gate_field","pos":target,"life":8.0,"pulse":0.0,"power":power*0.12,"area":radius/180.0,"hero_id":hero.id})
		"trinity_field":
			for offset: Vector2 in [Vector2.ZERO,Vector2(150,-80),Vector2(-150,80)]:
				skill_effects.append({"kind":"gate_field","pos":target+offset,"life":12.0,"pulse":0.0,"power":power*0.18,"area":radius/230.0,"hero_id":hero.id})
		"mon3tr":
			orbitals.append({"hero_id":hero.id,"count":1,"damage":power*0.58,"radius":radius*0.72,"timer":0.1,"interval":0.38,"life":14.0,"element":"","visual":"mon3tr"})
		"meltdown":
			_damage_area(target, radius, power*1.35, "", hero.id)
			orbitals.append({"hero_id":hero.id,"count":1,"damage":power*0.72,"radius":radius*0.75,"timer":0.1,"interval":0.30,"life":16.0,"element":"","visual":"mon3tr"})
		"bangboo":
			orbitals.append({"hero_id":hero.id,"count":2,"damage":power*0.36,"radius":radius*0.75,"timer":0.1,"interval":0.5,"life":11.0,"element":"electro","visual":"bangboo"})
		"network_overdrive":
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)):
					ally.rate += ally.base_rate*0.38
					ally.speed *= 1.15
					gain_hero_energy(ally,30.0)
		_:
			_damage_area(target, radius, power, str(hero.element), hero.id)
	if kind != "heal_gust":
		damage_terrain_shortcuts(target, radius, maxf(90.0, power * (0.42 if ultimate else 0.30)))
	if passive_kind == "encore_meter":
		for ally: Dictionary in heroes: ally.skill_cooldown = maxf(0.0, ally.skill_cooldown-1.5)
	gain_hero_energy(hero,8.0 if run_state.equipped_relics.has("relic_resonant_core") else 0.0)
	_clamp_combat_card_stats()
	hero.animation_state = "idle"
	events.append({"kind":"ultimate_impact" if ultimate else "skill_impact","pos":hero.pos if SELF_CENTERED_ABILITY_KINDS.has(kind) else target,"hero_id":hero.id,"value":str(ability.get("name","技能")),"element":hero.element,"radius":radius,"ability_kind":kind,"character_id":str(hero.get("character_id",""))})

func ability_area_screen_radii(center: Vector2, radius: float) -> Vector2:
	var depth := 1.0 if endless_mode else StageProjection.depth_scale(center)
	var radius_x := 42.0 + radius * 0.62 * depth
	return Vector2(radius_x, radius_x * 0.40)

func is_in_ability_area(center: Vector2, point: Vector2, radius: float) -> bool:
	var radii := ability_area_screen_radii(center, radius)
	if not endless_mode:
		return StageProjection.ground_contains(center, point, radii)
	var origin := center if endless_mode else StageProjection.project(center)
	var projected := point if endless_mode else StageProjection.project(point)
	var displacement := projected - origin - Vector2(0.0, 8.0)
	return Vector2(displacement.x / radii.x, displacement.y / radii.y).length_squared() <= 1.0

func _damage_area(center: Vector2, radius: float, power: float, element: String, hero_id: int, control: String = "") -> int:
	var hits := 0
	for enemy: Dictionary in enemies.duplicate():
		if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos) or not is_in_ability_area(center, enemy.pos, radius): continue
		apply_hit(enemy, power, element, hero_id)
		if control == "pull": enemy.pos = enemy.pos.move_toward(center, 72.0)
		elif control == "freeze": enemy.frozen_timer = maxf(float(enemy.get("frozen_timer",0.0)), 2.8)
		hits += 1
	return hits

func _invalidate_enemy_position_queries() -> void:
	projectile_enemy_bins.clear()
	projectile_bins_ready=false
	projectile_neighbor_cache.clear()
	projectile_chain_cache.clear()
	projectile_splash_cache.clear()
	projectile_range_enemies.clear()

func _push_enemy_grid_cells(enemy: Dictionary, origin: Vector2, cells: int) -> void:
	if float(enemy.get("spawn_timer",0.0))>0.0: return
	var delta: Vector2 = Vector2(enemy.pos) - origin
	var direction := Vector2.RIGHT
	if endless_mode:
		if absf(delta.y) > absf(delta.x):
			direction = Vector2.DOWN if delta.y >= 0.0 else Vector2.UP
		else:
			direction = Vector2.RIGHT if delta.x >= 0.0 else Vector2.LEFT
	var step: Vector2 = direction * (GRID_CELL_SIZE.y if absf(direction.y) > 0.0 else GRID_CELL_SIZE.x)
	var bounds: Rect2 = _movement_bounds()
	var radius := maxf(12.0, float(enemy.get("size", 28.0)) * 0.34)
	for cell in cells:
		var candidate: Vector2 = Vector2(enemy.pos) + step
		if not bounds.has_point(candidate) or _terrain_blocks(candidate, radius) or not _terrain_blocker_on_segment(Vector2(enemy.pos), candidate, radius).is_empty():
			break
		enemy.pos = candidate
	enemy.erase("nav_waypoint")
	enemy.nav_timer = 0.0
	enemy.nav_probe_timer = 0.0
	_invalidate_enemy_position_queries()
	events.append({"kind":"knockback","pos":enemy.pos,"value":cells})

func _damage_line(origin: Vector2, target: Vector2, length: float, width: float, power: float, element: String, hero_id: int, push: bool = false) -> int:
	var direction := (target-origin).normalized()
	if direction.length_squared() < 0.1: direction = Vector2.RIGHT
	var hits := 0
	for enemy: Dictionary in enemies.duplicate():
		var relative: Vector2 = enemy.pos-origin
		var forward := relative.dot(direction)
		var lateral := absf(relative.cross(direction))
		if enemy.hp <= 0.0 or float(enemy.get("spawn_timer",0.0))>0.0 or not _ability_target_visible(enemy.pos) or forward < 0.0 or forward > length or lateral > width: continue
		apply_hit(enemy, power, element, hero_id)
		if push:
			enemy.pos += direction*68.0
			_invalidate_enemy_position_queries()
		hits += 1
	return hits

func _heal_heroes(center: Vector2, radius: float, amount: float, shield: float) -> void:
	for ally: Dictionary in heroes:
		if not bool(ally.get("deployed", false)) or ally.hp <= 0.0 or not is_in_ability_area(center, ally.pos, radius): continue
		var healed := minf(ally.max_hp-ally.hp, amount)
		ally.hp += healed
		if shield > 0.0: crystal_shield = minf(500.0, crystal_shield+shield)
		events.append({"kind":"heal","pos":ally.pos,"value":ceili(healed)})

func _record_damage(hero_id: int, damage: float) -> void:
	if hero_id < 0 or hero_id >= heroes.size() or damage <= 0.0:
		return
	var hero: Dictionary = heroes[hero_id]
	hero.damage_done = float(hero.get("damage_done", 0.0)) + damage
	gain_hero_energy(hero, maxf(1.0, damage * 0.055))
	hero.max_energy_seen = maxf(float(hero.get("max_energy_seen", 0.0)), float(hero.energy))

func gain_hero_energy(hero: Dictionary, amount: float) -> void:
	if amount <= 0.0: return
	hero.energy = minf(float(hero.get("max_energy",100)),float(hero.get("energy",0))+amount*(1.0+clampf(energy_gain_bonus,0.0,0.40)))

func _orbital_tick(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for orbital: Dictionary in orbitals:
		orbital.age = float(orbital.get("age",0.0)) + dt
		orbital.phase = fposmod(float(orbital.get("phase",0.0)) + dt*2.2,TAU)
		orbital.life = float(orbital.life) - dt
		orbital.timer = float(orbital.timer) - dt
		orbital.storm_timer = float(orbital.get("storm_timer", 3.2)) - dt
		if orbital.life <= 0.0:
			continue
		var hero_id := int(orbital.get("hero_id", -1))
		if hero_id < 0 or hero_id >= heroes.size() or not bool(heroes[hero_id].get("deployed", false)):
			continue
		if heroes[hero_id].hp <= 0:
			alive.append(orbital)
			continue
		var hero: Dictionary = heroes[hero_id]
		if str(orbital.get("source_card", "")) == "orbit_arcane_blades" and int(orbital.get("level", 1)) >= 9 and orbital.storm_timer <= 0.0:
			orbital.storm_timer += 3.2
			_damage_area(hero.pos, float(orbital.radius) * 1.35, float(orbital.damage) * CardSynergies.team_multiplier(self, "twin_orbits", 1.20) * 1.8, str(orbital.element), hero_id, "barrage")
			events.append({"kind":"orbit_storm","pos":hero.pos,"center":hero.pos,"radius":float(orbital.radius)*1.35,"visual":orbital.get("visual","blade"),"hero_id":hero_id,"value":int(orbital.count)})
		if orbital.timer <= 0.0:
			orbital.timer += float(orbital.interval)
			var targets: Array[Dictionary] = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0.0 and _ability_target_visible(e.pos) and is_in_ability_area(Vector2(hero.pos), Vector2(e.pos), float(orbital.radius)))
			targets.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.pos.distance_to(hero.pos) < b.pos.distance_to(hero.pos))
			for i in mini(int(orbital.count), targets.size()):
				apply_hit(targets[i], float(orbital.damage) * CardSynergies.team_multiplier(self, "twin_orbits", 1.20), str(orbital.element), hero_id)
				events.append({"kind":"orbit_hit","pos":targets[i].pos,"center":hero.pos,"radius":orbital.radius,"angle":float(orbital.phase)+i*TAU/maxi(1,int(orbital.count)),"visual":orbital.get("visual","spell"),"hero_id":hero_id})
		alive.append(orbital)
	orbitals = alive

func _begin_enemy_warning(enemy: Dictionary, victim: Dictionary = {}, construct: Dictionary = {}) -> void:
	var lead := 0.72 if float(enemy.get("attack_range", 0.0)) <= 0.0 else 1.05
	if str(enemy.get("kind", "")) == "boss_01":
		lead = 47.0 / 24.0
	if run_state.equipped_relics.has("relic_warning_clock"):
		lead *= 1.35
	enemy.attack_pending = true
	enemy.warning_timer = lead
	enemy.warning_total = lead
	enemy.warning_pos = construct.pos if not construct.is_empty() else victim.pos
	enemy.warning_radius = 52.0 if float(enemy.get("attack_range", 0.0)) <= 0.0 else 86.0
	enemy.warning_victim = int(victim.get("id", -1))
	enemy.warning_construct = int(construct.get("id", -1))
	enemy.warning_origin = Vector2(enemy.pos) + Vector2(0, -12)
	enemy.warning_direction = (Vector2(enemy.warning_pos) + Vector2(0, -12) - Vector2(enemy.warning_origin)).normalized()
	if float(enemy.get("attack_range", 0.0)) > 0.0:
		var is_boss := str(enemy.get("kind", "")).begins_with("boss_")
		events.append({"kind":"enemy_warning","pos":enemy.warning_pos,"source":enemy.pos,"radius":enemy.warning_radius,"life":lead,"boss":is_boss,"name":"⚠ 首领攻击" if is_boss else ""})

func _resolve_enemy_warning(enemy: Dictionary) -> void:
	EnemyTactics.after_attack(self,enemy)
	enemy.attack_pending = false
	var hit := false
	var victim_id := int(enemy.get("warning_victim", -1))
	var construct_id := int(enemy.get("warning_construct", -1))
	var enemy_kind := str(enemy.get("kind", ""))
	if enemy_kind in ["ranged", "buffer", "troop_ranged"]:
		# Freeze the advertised direction at release; a dodged shot still flies.
		var origin := Vector2(enemy.get("warning_origin", Vector2(enemy.pos) + Vector2(0, -12)))
		var direction := Vector2(enemy.get("warning_direction", Vector2(-1, 0)))
		if direction.is_zero_approx(): direction = Vector2(-1, 0)
		var source: Dictionary = Readability.source(enemy, "飞箭" if enemy_kind == "ranged" else "法术光球")
		hit = _queue_enemy_projectile({"kind":"enemy_arrow" if enemy_kind == "ranged" else "enemy_orb", "visual_kind":"arrow" if enemy_kind == "ranged" else "orb", "ballistic":true, "pos":origin, "previous_pos":origin, "source":Vector2(enemy.pos), "direction":direction, "target_id":victim_id, "source_enemy_id":int(enemy.id), "enemy_kind":enemy_kind, "source_name":source.get("source_name", "敌方"), "source_skill":source.get("source_skill", "普通攻击"), "damage":float(enemy.damage), "speed":650.0 if enemy_kind == "ranged" else 430.0, "life":PROJECTILE_LIFETIME, "hit_ids":[], "hit_radius":5.0 if enemy_kind == "ranged" else 9.0, "element":"anemo" if enemy_kind == "buffer" else "", "vampiric":"vampiric" in enemy.get("affixes", [])})
		if hit:
			events.append({"kind":"enemy_projectile_cast", "pos":enemy.pos, "target":enemy.warning_pos, "direction":direction, "visual_kind":"arrow" if enemy_kind == "ranged" else "orb", "enemy_kind":enemy_kind, "source_enemy_id":int(enemy.id)})
	elif construct_id >= 0:
		for construct: Dictionary in geo_constructs:
			if construct.id == construct_id and construct.hp > 0.0 and construct.pos.distance_to(enemy.warning_pos) <= float(enemy.warning_radius):
				damage_construct(construct_id, enemy.damage)
				hit = true
				break
	elif victim_id >= 0 and victim_id < heroes.size():
		var victim: Dictionary = heroes[victim_id]
		var attack_range := float(enemy.get("attack_range", 0.0))
		var within_attack_range: bool = attack_range <= 0.0 or enemy.pos.distance_to(victim.pos) <= attack_range
		var clear_shot: bool = within_attack_range and (bool(enemy.get("flying", false)) or attack_range <= 0.0 or not terrain_line_blocked(enemy.pos, victim.pos))
		if bool(victim.get("deployed", false)) and victim.hp > 0.0 and is_in_ability_area(enemy.warning_pos, victim.pos, float(enemy.warning_radius)) and clear_shot:
			if str(enemy.get("kind", "")) == "troop_ranged":
				_queue_enemy_projectile({"source_name":Readability.source(enemy).get("source_name","敌方"),"source_skill":Readability.source(enemy).get("source_skill","普通攻击"),"pos":enemy.pos,"target_id":victim_id,"damage":float(enemy.damage),"speed":350.0,"life":3.5})
			else:
				damage_hero(victim_id, enemy.damage, Readability.source(enemy,"普通攻击"))
				if str(enemy.get("kind", "")) == "boss_01":
					events.append({"kind":"rift_arc","pos":enemy.pos,"target":victim.pos})
				elif str(enemy.get("kind", "")) == "boss_02":
					events.append({"kind":"slime_attack","pos":enemy.pos,"target":victim.pos,"phase":int(enemy.get("boss_phase",1))})
			if "suppressor" in enemy.get("affixes",[]):
				victim.skill_cooldown = float(victim.get("skill_cooldown",0.0))+2.0
				events.append({"kind":"skill_suppressed","pos":victim.pos,"value":2})
			hit = true
			if float(enemy.get("attack_range", 0.0)) > 0.0 and str(enemy.get("kind", "")) != "troop_ranged":
				events.append({"kind":"enemy_shot","pos":enemy.pos,"target":victim.pos,"value":ceili(enemy.damage),"enemy_kind":str(enemy.get("kind","")),"duration":clampf(enemy.pos.distance_to(victim.pos) / 620.0, 0.28, 0.72)})
	if hit and enemy_kind not in ["ranged", "buffer", "troop_ranged"] and "vampiric" in enemy.get("affixes", []):
		enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.damage * 0.25)
		events.append({"kind":"enemy_heal","pos":enemy.pos,"value":ceili(enemy.damage * 0.25)})
	if not hit:
		dodges += 1
		if victim_id >= 0 and victim_id < heroes.size():
			var dodge_energy := 12.0 if run_state.equipped_relics.has("relic_warning_clock") else 0.0
			if str(heroes[victim_id].get("passive",{}).get("kind","")) == "proxy_network": dodge_energy += 18.0
			gain_hero_energy(heroes[victim_id],dodge_energy)
		events.append({"kind":"dodge","pos":enemy.warning_pos,"value":1})
	enemy.attack_timer = 1.0 / maxf(0.1, float(enemy.rate) * (1.25 if enemy.haste_timer > 0 else 1.0))

func _apply_enemy_affix(enemy: Dictionary) -> void:
	if not v2_mode:
		return
	var threat := maxi(1, floori(elapsed / 60.0) + 1) if endless_mode else maxi(1, wave)
	if threat < 2 or (enemy.id + threat) % 4 != 0:
		return
	var pool := ["frenzied", "volatile"]
	if threat >= 4: pool.append("vampiric")
	if threat >= 5: pool.append("blink")
	if threat >= 6: pool.append("mirror")
	if threat >= 7: pool.append("aegis")
	if threat >= 8: pool.append("duplicator")
	if threat >= 9: pool.append("suppressor")
	var affix: String = pool[(enemy.id + threat) % pool.size()]
	enemy.affixes.append(affix)
	match affix:
		"frenzied": enemy.rate *= 1.30
		"mirror":
			enemy.shield += enemy.max_hp * 0.35
			enemy.max_shield = enemy.shield
		"aegis":
			enemy.shield += enemy.max_hp*0.50
			enemy.max_shield = enemy.shield
		"duplicator": enemy.split_count = 2
		"suppressor": enemy.damage *= 0.90

func _refresh_tag_synergies() -> void:
	run_state.rebuild_tags(database.cards)
	var thresholds := {"弹道":3,"召唤":3,"反应":3,"暴击":3,"护盾":3,"支援":3}
	for tag: String in thresholds:
		var level := mini(3,int(run_state.tag_counts.get(tag,0)) / int(thresholds[tag]))
		var previous := int(tag_synergy_levels.get(tag,0))
		if level <= previous:
			continue
		var delta := level - previous
		tag_synergy_levels[tag] = level
		match tag:
			"弹道":
				var added := (1 if previous < 1 and level >= 1 else 0)+(1 if previous < 3 and level >= 3 else 0)
				for hero: Dictionary in heroes: hero.projectile_count += added
			"召唤":
				for orbital: Dictionary in orbitals:
					orbital.damage = float(orbital.damage) * (1.0 + 0.08 * delta)
					orbital.radius = float(orbital.radius) + 8.0 * delta
			"反应": reaction_damage_bonus += 0.10 * delta
			"暴击":
				for hero: Dictionary in heroes: hero.crit_chance = minf(0.85, float(hero.crit_chance) + 0.05 * delta)
			"护盾": crystal_shield += 40.0 * delta
			"支援":
				for support: Dictionary in supports.values(): support.interval = maxf(2.5, float(support.interval) * pow(0.94, delta))
		events.append({"kind":"tag_synergy","pos":heroes[0].pos if not heroes.is_empty() else Vector2.ZERO,"value":tag,"level":level})

func traveler_skill_element() -> String:
	if heroes.is_empty() or heroes[0].get("character_id", "") != "traveler":
		return "none"
	var element := normalize_element(str(heroes[0].get("element", "")))
	return "none" if element.is_empty() else element

func traveler_element_display() -> String:
	var primary := traveler_skill_element()
	var secondary := normalize_element(str(heroes[0].get("secondary_element", ""))) if not heroes.is_empty() else ""
	if secondary.is_empty():
		return element_name(primary)
	return "%s + %s" % [element_name(primary), element_name(secondary)]

func traveler_skill_name() -> String:
	if TravelerElements.supports(traveler_skill_element(),false): return str(TravelerElements.definition(traveler_skill_element(),false).name)
	return {
		"none": "无锋剑气", "anemo": "风涡龙卷", "electro": "雷罚连星", "pyro": "烈焰星坠",
		"hydro": "水泽恩典", "geo": "岩脊壁垒", "cryo": "霜封领域"
	}.get(traveler_skill_element(), "元素战技")

func traveler_skill_radius() -> float:
	if TravelerElements.supports(traveler_skill_element(),false): return float(TravelerElements.definition(traveler_skill_element(),false).radius)
	return {"none": 145.0, "anemo": 135.0, "electro": 380.0, "pyro": 215.0, "hydro": 250.0, "geo": 58.0, "cryo": 225.0}.get(traveler_skill_element(), 160.0)

func activate_traveler_skill(target: Vector2) -> bool:
	if not v2_mode or state != "running" or heroes.is_empty() or heroes[0].hp <= 0.0 or traveler_skill_cooldown > 0.0:
		return false
	var skill_bounds := active_view_rect.grow(-36.0) if endless_mode else Rect2(170.0, 225.0, 970.0, 290.0)
	target.x = clampf(target.x, skill_bounds.position.x, skill_bounds.end.x)
	target.y = clampf(target.y, skill_bounds.position.y, skill_bounds.end.y)
	var element := traveler_skill_element()
	traveler_skill_cooldown_max = {"none": 9.0, "anemo": 16.0, "electro": 14.0, "pyro": 15.0, "hydro": 18.0, "geo": 13.0, "cryo": 17.0}.get(element, 15.0)
	traveler_skill_cooldown_max *= maxf(0.35, 1.0 - skill_cooldown_reduction)
	traveler_skill_cooldown = traveler_skill_cooldown_max
	if TravelerElements.supports(element,false):
		var revised := TravelerElements.definition(element,false)
		TravelerElements.start(self,heroes[0],revised,target,(float(revised.power)+float(heroes[0].damage)*float(revised.attack_ratio))*(1.0+skill_power_bonus),float(revised.radius)*(1.0+skill_area_bonus))
		return true
	var power := 1.0 + skill_power_bonus
	var traveler_attack := float(heroes[0].get("damage", 0.0))
	var area := 1.0 + skill_area_bonus
	var duration := 1.0 + skill_duration_bonus
	match element:
		"anemo":
			skill_effects.append({"kind": "anemo_tornado", "pos": target, "life": 4.2 * duration, "total_life": 4.2 * duration, "pulse": 0.0, "power": (42.0 + traveler_attack * 0.38) / 42.0 * power, "area": area})
			events.append({"kind": "skill_anemo", "pos": target, "value": traveler_skill_name()})
		_:
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and is_in_ability_area(target, Vector2(enemy.pos), 145.0 * area):
					apply_hit(enemy, (125.0 + traveler_attack * 0.85) * power, "")
					enemy.pos.x += 45.0
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 45})
			events.append({"kind": "skill_none", "pos": target, "value": traveler_skill_name()})
	damage_terrain_shortcuts(target, traveler_skill_radius() * area, 240.0 * power)
	var secondary := normalize_element(str(heroes[0].get("secondary_element", "")))
	if not secondary.is_empty():
		var secondary_radius := traveler_skill_radius() * (1.0 + skill_area_bonus)
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and is_in_ability_area(target, Vector2(enemy.pos), secondary_radius):
				apply_hit(enemy, (115.0 + traveler_attack * 0.6) * power, secondary)
		events.append({"kind": "element_burst", "pos": target, "value": secondary})
	return true

func _skill_effect_tick(dt: float) -> void:
	var surviving: Array[Dictionary] = []
	for effect: Dictionary in skill_effects:
		if bool(effect.get("traveler_zone", false)):
			if TravelerElements.tick(self,effect,dt): surviving.append(effect)
			continue
		if bool(effect.get("signature", false)):
			if HeroSignature.tick(self, effect, dt): surviving.append(effect)
			continue
		effect.life = float(effect.life) - dt
		effect.pulse = float(effect.pulse) - dt
		if effect.kind == "anemo_tornado":
			effect.pos.x = minf(1140.0, effect.pos.x + 26.0 * dt)
		if effect.kind == "wind_cut_rows" and effect.pulse <= 0.0 and int(effect.remaining) > 0:
			var pulse_index := 3 - int(effect.remaining)
			effect.remaining = int(effect.remaining) - 1
			effect.pulse += 1.0
			var active_row := int(effect.center_row) + pulse_index - 1
			var middle_y := GRID_ORIGIN.y + (active_row + 0.5) * GRID_CELL_SIZE.y
			var hit_positions: Array[Vector2] = []
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos):
					continue
				if enemy.pos.x < float(effect.left_x) or enemy.pos.x > float(effect.right_x) or absf(float(enemy.pos.y) - middle_y) > GRID_CELL_SIZE.y * 0.5:
					continue
				apply_hit(enemy, float(effect.power), "anemo", int(effect.hero_id))
				if enemy.hp > 0.0:
					_push_enemy_grid_cells(enemy, Vector2(effect.pos), 1)
				hit_positions.append(Vector2(enemy.pos))
			events.append({"kind":"fengjin_wind_row","pos":effect.pos,"pulse_index":pulse_index,"center_row":effect.center_row,"row_index":active_row,"left_x":effect.left_x,"right_x":effect.right_x,"hero_id":effect.hero_id,"target_positions":hit_positions})
		elif effect.kind == "columbia_tide_ring" and effect.pulse <= 0.0:
			effect.pulse += 0.8
			var owner_id := int(effect.hero_id)
			if owner_id >= 0 and owner_id < heroes.size() and heroes[owner_id].hp > 0.0:
				var owner: Dictionary = heroes[owner_id]
				effect.pos = owner.pos
				_damage_area(Vector2(owner.pos), float(effect.area), float(effect.power), "hydro", owner_id)
				var healing := 18.0 + float(owner.damage) * 0.20
				var actual_heal := minf(healing, maxf(0.0, float(owner.max_hp) - float(owner.hp)))
				owner.hp += actual_heal
				if actual_heal > 0.0:
					events.append({"kind":"heal","pos":owner.pos,"value":ceili(actual_heal)})
		elif effect.kind == "columbia_attack_blessing":
			var source_id := int(effect.hero_id)
			if source_id >= 0 and source_id < heroes.size():
				effect.pos = heroes[source_id].pos
		elif effect.kind == "renewing_breeze" and effect.pulse <= 0.0:
			effect.pulse += 0.85
			_heal_heroes(effect.pos, float(effect.area), float(effect.power), 0.0)
		elif effect.pulse <= 0.0:
			effect.pulse += 0.42 if effect.kind == "anemo_tornado" else 0.85
			var storm_hits: Array[Vector2] = []
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos):
					continue
				var effect_area: float = float(effect.get("area", 1.0))
				var effect_power: float = float(effect.get("power", 1.0))
				if effect.kind == "anemo_tornado" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 135.0 * effect_area):
					enemy.pos.x += 15.0
					enemy.pos.y = move_toward(float(enemy.pos.y), float(effect.pos.y), 12.0)
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 15})
					apply_hit(enemy, 42.0 * effect_power, "anemo")
				elif effect.kind == "hydro_field" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 250.0 * effect_area):
					apply_hit(enemy, 28.0 * effect_power, "hydro")
				elif effect.kind == "cryo_field" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 225.0 * effect_area):
					enemy.slow_timer = maxf(float(enemy.slow_timer), 1.2)
				elif effect.kind == "burning_ground" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 105.0 * effect_area):
					apply_hit(enemy, 26.0 * effect_power, "pyro", int(effect.get("hero_id",-1)))
				elif effect.kind in ["anemo_domain","gate_field"] and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 180.0 * effect_area):
					apply_hit(enemy, effect_power, "anemo", int(effect.get("hero_id",-1)))
					enemy.pos = enemy.pos.move_toward(effect.pos, 32.0)
				elif effect.kind == "storm_field" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 190.0 * effect_area):
					apply_hit(enemy, effect_power, "hydro", int(effect.get("hero_id",-1)))
					chain_damage(enemy, effect_power*0.35, 1)
					if str(effect.get("visual", "")) == "roxy_storm" and storm_hits.size() < 8:
						storm_hits.append(enemy.pos)
				elif effect.kind == "frozen_forest" and is_in_ability_area(Vector2(effect.pos), Vector2(enemy.pos), 210.0 * effect_area):
					apply_hit(enemy, effect_power, "cryo", int(effect.get("hero_id",-1)))
					enemy.slow_timer = maxf(float(enemy.slow_timer),1.4)
			if not storm_hits.is_empty():
				events.append({"kind":"roxy_thunder", "pos":effect.pos, "targets":storm_hits})
		if effect.life > 0.0:
			surviving.append(effect)
		elif effect.kind == "columbia_attack_blessing":
			for ally_id in effect.get("bonuses", {}):
				var index := int(ally_id)
				if index >= 0 and index < heroes.size():
					heroes[index].damage = maxf(0.0, float(heroes[index].damage) - float(effect.bonuses[ally_id]))
	skill_effects = surviving

func _queue_enemy_projectile(projectile: Dictionary) -> bool:
	var cap := MAX_ENDLESS_ENEMY_PROJECTILES if endless_mode else PerformanceBudget.MAX_PROJECTILES
	if enemy_projectiles.size() >= cap:
		var priority := str(projectile.get("kind", "")) in ["rift_orb", "slime_glob", "slime_image", "kindred_arrow", "kindred_dread_arrow"]
		if not priority:
			return false
		enemy_projectiles.pop_front()
	projectile.visual_id = next_projectile_id
	next_projectile_id += 1
	enemy_projectiles.append(projectile)
	return true

func _queue_enemy_hazard(hazard: Dictionary) -> bool:
	var cap := MAX_ENDLESS_ENEMY_HAZARDS if endless_mode else PerformanceBudget.MAX_EFFECTS
	if enemy_hazards.size() >= cap:
		var priority := str(hazard.get("kind", "")) in ["slime_bounce_impact", "slime_court_final", "kindred_wolf_zone", "galio_winds"]
		if not priority:
			return false
		enemy_hazards.pop_front()
	enemy_hazards.append(hazard)
	return true

func _enemy_projectile_tick(dt: float) -> void:
	var active: Array[Dictionary] = []
	for projectile: Dictionary in enemy_projectiles:
		projectile.life = float(projectile.life) - dt
		if projectile.life <= 0.0:
			continue
		var kind := str(projectile.get("kind", ""))
		if float(projectile.get("delay", 0.0)) > 0.0:
			projectile.delay = float(projectile.delay) - dt
			active.append(projectile)
			continue
		if bool(projectile.get("ballistic", false)):
			if _advance_enemy_ballistic(projectile, dt): active.append(projectile)
			continue
		if kind in ["slime_glob", "slime_image"]:
			var target_pos := Vector2(projectile.get("target_pos", projectile.pos))
			projectile.pos = Vector2(projectile.pos).move_toward(target_pos, float(projectile.speed) * dt)
			if Vector2(projectile.pos).distance_to(target_pos) <= 14.0:
				var splash_radius := float(projectile.get("splash_radius", 90.0))
				for splash_hero: Dictionary in heroes:
					if bool(splash_hero.get("deployed", false)) and splash_hero.hp > 0.0 and is_in_ability_area(target_pos, Vector2(splash_hero.pos), splash_radius):
						damage_hero(int(splash_hero.id), float(projectile.damage), projectile)
				if kind == "slime_glob":
					_queue_enemy_hazard({"source_name":projectile.get("source_name","敌方"),"source_skill":projectile.get("source_skill","普通攻击"),"kind":"slime_pool","pos":target_pos,"radius":splash_radius * 0.82,"life":4.2 if int(projectile.get("phase", 1)) >= 2 else 3.4,"total":4.2 if int(projectile.get("phase", 1)) >= 2 else 3.4,"pulse":0.0,"damage":float(projectile.damage) * 0.24,"element":str(projectile.get("element", "hydro")),"phase":int(projectile.get("phase", 1))})
				events.append({"kind":"slime_glob_hit" if kind == "slime_glob" else "slime_court_hit","pos":target_pos,"radius":splash_radius,"element":str(projectile.get("element", "hydro")),"phase":int(projectile.get("phase", 1))})
			else:
				active.append(projectile)
			continue
		var target_id := int(projectile.get("target_id", -1))
		if kind in ["rift_orb", "kindred_arrow", "kindred_dread_arrow"] and (target_id < 0 or target_id >= heroes.size() or heroes[target_id].hp <= 0.0):
			var nearest: Dictionary = _nearest_live_hero(Vector2(projectile.pos))
			if not nearest.is_empty():
				target_id = int(nearest.id)
				projectile.target_id = target_id
		if target_id < 0 or target_id >= heroes.size():
			continue
		var hero: Dictionary = heroes[target_id]
		if hero.hp <= 0.0 or not bool(hero.get("deployed", false)):
			continue
		projectile.pos = Vector2(projectile.pos).move_toward(hero.pos, float(projectile.speed) * dt)
		if Vector2(projectile.pos).distance_to(hero.pos) <= 16.0:
			if kind == "rift_orb":
				var splash_radius := float(projectile.get("splash_radius", 62.0))
				for splash_hero: Dictionary in heroes:
					if bool(splash_hero.get("deployed", false)) and splash_hero.hp > 0.0 and is_in_ability_area(Vector2(hero.pos), Vector2(splash_hero.pos), splash_radius):
						damage_hero(int(splash_hero.id), float(projectile.damage), projectile)
				events.append({"kind":"rift_orb_hit","pos":hero.pos,"radius":splash_radius,"enraged":bool(projectile.get("enraged", false))})
			elif kind in ["kindred_arrow", "kindred_dread_arrow"]:
				damage_hero(target_id, float(projectile.damage), projectile)
				events.append({"kind":"kindred_arrow_hit","pos":hero.pos,"source":projectile.get("source", projectile.pos),"dread":kind == "kindred_dread_arrow","stack":int(projectile.get("dread_stack", 0)),"phase":int(projectile.get("phase", 1))})
			else:
				damage_hero(target_id, float(projectile.damage), projectile)
				# damage_hero already emits the sole, post-defense hurt value.
				events.append({"kind":"projectile_impact", "pos":hero.pos + Vector2(0, -12), "hero_id":target_id, "source_enemy_id":projectile.get("source_enemy_id", -1), "visual_kind":projectile.get("visual_kind", "orb"), "enemy_kind":projectile.get("enemy_kind", ""), "direction":Vector2(projectile.get("direction", Vector2.LEFT))})
		else:
			active.append(projectile)
	enemy_projectiles = active

func _projectile_in_bounds(point: Vector2) -> bool:
	return (ENDLESS_ARENA if endless_mode else MOVE_AREA).grow(200.0).has_point(point)

func _swept_body_fraction(start: Vector2, finish: Vector2, center: Vector2, radii: Vector2) -> float:
	# Segment/ellipse intersection gives the earliest contact even for fast shots.
	var p := (start - center) / radii
	var d := (finish - start) / radii
	var c := p.length_squared() - 1.0
	if c <= 0.0: return 0.0
	var a := d.length_squared()
	if a <= 0.000001: return INF
	var b := 2.0 * p.dot(d)
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0: return INF
	var contact := (-b - sqrt(discriminant)) / (2.0 * a)
	return contact if contact >= 0.0 and contact <= 1.0 else INF

func _advance_enemy_ballistic(projectile: Dictionary, dt: float) -> bool:
	var start := Vector2(projectile.pos)
	var finish := start + Vector2(projectile.direction) * float(projectile.speed) * dt
	projectile.previous_pos = start
	projectile.pos = finish
	var wall_fraction := _projectile_wall_fraction(start, finish)
	var hit_fraction := wall_fraction
	var victim_id := -1
	var construct_id := -1
	var padding := float(projectile.get("hit_radius", 6.0))
	for hero: Dictionary in heroes:
		if hero.hp <= 0.0 or not bool(hero.get("deployed", false)): continue
		var fraction := _swept_body_fraction(start, finish, Vector2(hero.pos) + Vector2(0, -12), Vector2(15 + padding, 12 + padding))
		if fraction < hit_fraction:
			hit_fraction = fraction
			victim_id = int(hero.id)
	for construct: Dictionary in geo_constructs:
		if float(construct.hp) <= 0.0: continue
		var fraction := _swept_body_fraction(start, finish, Vector2(construct.pos) + Vector2(0, -12), Vector2(24 + padding, 17 + padding))
		if fraction < hit_fraction:
			hit_fraction = fraction
			construct_id = int(construct.id)
			victim_id = -1
	if victim_id >= 0 or construct_id >= 0:
		projectile.pos = start.lerp(finish, hit_fraction)
		if victim_id >= 0:
			var hp_before := float(heroes[victim_id].hp)
			damage_hero(victim_id, float(projectile.damage), projectile)
			if bool(projectile.get("vampiric", false)) and float(heroes[victim_id].hp) < hp_before:
				var caster := find_enemy(int(projectile.get("source_enemy_id", -1)))
				if not caster.is_empty():
					caster.hp = minf(float(caster.max_hp), float(caster.hp) + float(projectile.damage) * 0.25)
					events.append({"kind":"enemy_heal", "pos":caster.pos, "value":ceili(float(projectile.damage) * 0.25)})
		else:
			damage_construct(construct_id, float(projectile.damage))
		events.append({"kind":"projectile_impact", "pos":projectile.pos, "element":projectile.get("element", ""), "visual_kind":projectile.get("visual_kind", "orb"), "direction":projectile.direction, "enemy_kind":projectile.get("enemy_kind", ""), "source_enemy_id":projectile.get("source_enemy_id", -1), "hero_id":victim_id})
		return false
	return wall_fraction == INF and _projectile_in_bounds(finish)


func _enemy_hazard_tick(dt: float) -> void:
	var active: Array[Dictionary] = []
	for hazard: Dictionary in enemy_hazards:
		if float(hazard.get("delay", 0.0)) > 0.0:
			hazard.delay = float(hazard.delay) - dt
			active.append(hazard)
			continue
		var kind := str(hazard.get("kind", ""))
		if not bool(hazard.get("triggered", false)) and kind in ["slime_bounce_impact", "slime_court_final"]:
			hazard.triggered = true
			var hits := 0
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(Vector2(hazard.pos), Vector2(hero.pos), float(hazard.radius)):
					damage_hero(int(hero.id), float(hazard.damage), hazard)
					if kind == "slime_bounce_impact":
						var away := (Vector2(hero.pos) - Vector2(hazard.pos)).normalized()
						hero.pos = _nearest_walkable_point(Vector2(hero.pos) + away * (72.0 if int(hazard.get("phase", 1)) >= 2 else 48.0), 17.0)
						hero.target = hero.pos
					hits += 1
			events.append({"kind":"slime_bounce_hit" if kind == "slime_bounce_impact" else "slime_court_final","pos":hazard.pos,"radius":hazard.radius,"phase":hazard.get("phase", 1),"hits":hits})
		if kind == "kindred_wolf_zone":
			hazard.pulse = float(hazard.get("pulse", 0.0)) - dt
			if hazard.pulse <= 0.0:
				hazard.pulse += 0.62
				var hits := 0
				var hit_positions: Array[Vector2] = []
				for hero: Dictionary in heroes:
					if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(Vector2(hazard.pos), Vector2(hero.pos), float(hazard.radius)):
						hit_positions.append(Vector2(hero.pos))
						damage_hero(int(hero.id), float(hazard.damage), hazard)
						hits += 1
				events.append({"kind":"kindred_wolf_strike","pos":hazard.pos,"radius":hazard.radius,"hits":hits,"hit_positions":hit_positions,"phase":int(hazard.get("phase", 1))})
		if kind == "galio_winds":
			hazard.pulse = float(hazard.get("pulse", 0.0)) - dt
			if hazard.pulse <= 0.0:
				hazard.pulse += 0.68
				var hits := 0
				for hero: Dictionary in heroes:
					if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(Vector2(hazard.pos), Vector2(hero.pos), float(hazard.radius)):
						damage_hero(int(hero.id), float(hazard.damage), hazard)
						hero.pos = _nearest_walkable_point(Vector2(hero.pos).move_toward(Vector2(hazard.pos), 30.0), 17.0)
						hero.target = hero.pos
						hits += 1
				events.append({"kind":"galio_winds_pulse","pos":hazard.pos,"radius":hazard.radius,"hits":hits,"phase":int(hazard.get("phase", 1))})
		if kind == "slime_pool":
			hazard.pulse = float(hazard.get("pulse", 0.0)) - dt
			if hazard.pulse <= 0.0:
				hazard.pulse += 0.65
				for hero: Dictionary in heroes:
					if bool(hero.get("deployed", false)) and hero.hp > 0.0 and is_in_ability_area(Vector2(hazard.pos), Vector2(hero.pos), float(hazard.radius)):
						damage_hero(int(hero.id), float(hazard.damage), hazard)
						hero.slime_slow_timer = maxf(float(hero.get("slime_slow_timer", 0.0)), 0.82)
		hazard.life = float(hazard.get("life", 0.0)) - dt
		if hazard.life > 0.0:
			active.append(hazard)
	enemy_hazards = active


func damage_hero(id: int, raw_damage: float, source: Dictionary = {}) -> void:
	if run_state.equipped_relics.has("relic_glass_cannon"): raw_damage*=1.20
	if workshop_mode and workshop_invulnerable: return
	if id < 0 or id >= heroes.size() or raw_damage <= 0: return
	var h: Dictionary = heroes[id]
	if h.hp <= 0 or float(h.get("invulnerable_timer", 0.0)) > 0.0:
		return
	if crystal_shield > 0.0:
		var absorbed := minf(crystal_shield, raw_damage)
		crystal_shield -= absorbed
		raw_damage -= absorbed
		events.append({"kind": "crystal_guard", "pos": h.pos, "value": ceili(absorbed)})
		if raw_damage <= 0.0:
			return
	var reduction := float(h.get("damage_reduction",0.0))
	if h.hp / h.max_hp < 0.30:
		reduction += 0.15 * CombatCardEffects.level(h, "desperate_guard")
	if str(h.get("passive",{}).get("kind","")) == "resolve" and h.hp/h.max_hp <= 0.5: reduction = maxf(reduction,0.22)
	if str(h.get("passive",{}).get("kind","")) == "tactical_link" and orbitals.any(func(o: Dictionary)->bool: return int(o.get("hero_id",-1)) == id and str(o.get("visual","")) == "mon3tr"): reduction = maxf(reduction,0.25)
	var damage: float = raw_damage * (1.0-clampf(reduction,0.0,0.75)) * 100.0 / (100.0 + maxf(0, h.armor))
	var hp_before: float = h.hp
	h.hp = maxf(0, h.hp - damage)
	var kindred_protected: bool = h.hp <= 0.0 and _hero_protected_by_kindred(h)
	if kindred_protected:
		h.hp = 1.0
	last_incoming_hit = {"source_name":str(source.get("source_name","环境伤害")), "source_skill":str(source.get("source_skill",source.get("kind","持续伤害"))), "victim":str(h.name), "damage":maxf(0,hp_before-float(h.hp))}
	if damage > 0.0 and CombatCardEffects.level(h, "counter_ready") > 0:
		h.card_counter_ready = true
	h.flash = 0.12
	h.animation_state = "hurt"
	h.status_timer = 0.44
	events.append({"kind": "hurt", "pos": h.pos, "value": ceili(damage), "hero_id": id, "critical":false, "source_enemy_id":source.get("source_enemy_id", -1), "source_name":source.get("source_name", "环境伤害")})
	if kindred_protected:
		events.append({"kind":"kindred_protect","pos":h.pos,"hero_id":id})
		return
	if h.hp <= 0 and run_state.equipped_relics.has("relic_second_heartbeat") and not bool(h.get("revived", false)):
		h.hp = h.max_hp * 0.35
		h.revived = true
		events.append({"kind":"revive","pos":h.pos,"hero_id":id})
		return
	if h.hp <= 0:
		hero_down_causes[id] = last_incoming_hit.duplicate()
		h.target = h.pos
		h.moving = false
		h.blocked = 0
		for enemy in enemies:
			if enemy.blocked_by == id:
				enemy.blocked_by = -1
		h.animation_state = "down"
		h.status_timer = 999999.0
		events.append({"kind": "down", "pos": h.pos, "hero_id": id})

func _hero_tick() -> void:
	if workshop_mode and not workshop_auto_attack: return
	for h: Dictionary in heroes:
		if h.hp <= 0 or not bool(h.get("deployed", true)):
			continue
		if normalize_element(str(h.element)) == "hydro" and h.heal_timer <= 0:
			var ally: Dictionary = {}
			for other: Dictionary in heroes:
				if bool(other.get("deployed", true)) and other.hp > 0 and other.hp < other.max_hp and h.pos.distance_to(other.pos) <= HEAL_RANGE:
					if ally.is_empty() or other.hp / other.max_hp < ally.hp / ally.max_hp:
						ally = other
			if not ally.is_empty():
				var healing: float = minf(float(h.get("heal_power", heal_amount)), ally.max_hp - ally.hp)
				ally.hp += healing
				h.heal_timer = float(h.get("personal_heal_interval", heal_interval))
				events.append({"kind": "heal", "pos": ally.pos, "value": ceili(healing)})
		if h.attack_timer > 0:
			continue
		var target: Dictionary = {}
		var available: Array[Dictionary] = []
		var can_target_air: bool = bool(h.get("can_hit_air", false)) or int(h.get("block", 0)) <= 0 or (h.get("character_id", "") == "traveler" and h.get("element", "") != "")
		for e: Dictionary in enemies:
			if e.hp <= 0 or float(e.get("spawn_timer", 0.0)) > 0.0 or (bool(e.get("flying", false)) and not can_target_air):
				continue
			if not is_in_attack_range(h, Vector2(e.pos)):
				continue
			if h.pos.distance_squared_to(e.pos) > 72.0 * 72.0 and terrain_line_blocked(h.pos, e.pos):
				continue
			available.append(e)
			if target.is_empty() or e.pos.x < target.pos.x:
				target = e
		if target.is_empty():
			continue
		if absf(target.pos.x - h.pos.x) > 1.0:
			h.facing = 1.0 if target.pos.x > h.pos.x else -1.0
		var interval: float = 1.0 / maxf(0.1, float(h.rate))
		h.attack_timer = interval
		h.animation_state = "attack"
		h.status_timer = minf(0.72,interval)
		h.shots += 1
		shots_fired += 1
		var before_attack_hp: float = h.hp
		var conqueror_scale: float = CombatCardEffects.on_attack(h)
		_clamp_hero_attack_rate(h)
		if h.hp > before_attack_hp:
			events.append({"kind":"heal","pos":h.pos,"value":ceili(h.hp-before_attack_hp)})
		if h.pos.distance_to(target.pos) > 250.0:
			conqueror_scale *= 1.0 + 0.20 * CombatCardEffects.level(h, "distant_strike")
		events.append({"kind": "shot", "pos": h.pos, "hero_id": h.id, "duration": interval, "element": h.element, "style": str(h.get("attack_style", "standard"))})
		var last_stand_levels := int(run_state.buff_levels.get("global_laststand_1", 0)) if run_state != null else 0
		var last_stand_scale := 1.0 + 0.25 * mini(last_stand_levels,2) if float(h.hp) < float(h.max_hp) * 0.30 else 1.0
		var damage: float = h.damage * terrain_attack_scale(h.pos) * conqueror_scale * last_stand_scale
		var critical: bool = randf() < clampf(float(h.get("crit_chance", 0.0)), 0.0, 0.85)
		if critical:
			damage *= 2.0
		var attack_count: int = maxi(1, int(h.get("projectile_count", 1)))
		if attack_count > 1:
			available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x < b.pos.x)
		else:
			available.assign([target])
		if h.block > 0:
			var hit_ratio := float(h.get("attack_hit_frame_ratio", 0.48))
			for strike in attack_count:
				var victim: Dictionary = available[strike % available.size()]
				CombatCardEffects.on_target(h, victim)
				pending_impacts.append({"life": interval * hit_ratio + strike * 0.025, "kind": "melee", "hero_id": h.id, "target_id": victim.id, "damage": damage if strike == 0 else damage * 0.72, "element": h.element, "secondary_element": h.get("secondary_element", ""), "critical": critical})
				var slash_direction: Vector2 = (victim.pos - h.pos).normalized()
				events.append({"kind": "slash", "pos": victim.pos, "source_pos": h.pos, "angle": slash_direction.angle(), "element": normalize_element(str(h.element)), "critical": critical, "hit_delay": interval * hit_ratio})
		else:
			for shot_index in attack_count:
				if not performance_budget.allow_projectile(projectiles.size()):
					culled_spawns += 1
					break
				var shot_target: Dictionary = available[shot_index % available.size()]
				CombatCardEffects.on_target(h, shot_target)
				var launch_pos := Vector2(h.pos) + Vector2(float(h.facing) * 14, -12 + (shot_index - (attack_count - 1) * 0.5) * 6.0)
				var direction := (Vector2(shot_target.pos) + Vector2(0, -12) - launch_pos).normalized()
				projectiles.append({"visual_id": next_projectile_id, "pos": launch_pos, "previous_pos":launch_pos, "direction":direction, "ballistic":true, "visual_kind":"hero_bolt", "speed":PROJECTILE_SPEED, "life":PROJECTILE_LIFETIME, "hit_ids":[], "can_hit_air":can_target_air, "target_id": shot_target.id, "damage": damage if shot_index == 0 else damage * 0.78, "element": h.element, "secondary_element": h.get("secondary_element", ""), "source_id": h.id, "splash": h.splash, "slow": h.slow, "pierce": int(h.get("pierce", 0)), "chain_count": int(h.get("chain_count", 0)), "blast_radius": float(h.get("blast_radius", 0.0)), "echo_ratio": float(h.get("echo_ratio", 0.0)), "critical": critical, "style": str(h.get("attack_style", "standard"))})
				next_projectile_id += 1
		if attack_count > 1:
			events.append({"kind": "multishot", "pos": h.pos, "value": attack_count})

func displayed_attack_damage(hero: Dictionary) -> float:
	return float(hero.damage) * terrain_attack_scale(hero.pos)

func displayed_attack_range(hero: Dictionary) -> float:
	return float(hero.range) * terrain_range_scale(hero.pos)

func terrain_range_scale(point: Vector2) -> float:
	var high := terrain_feature_at(point, "high_ground")
	var pad := terrain_feature_at(point, "attack_ground")
	return (1.0 + (float(high.get("range_bonus", 1.0)) if not high.is_empty() else 0.0) + (float(pad.get("range_bonus", 0.0)) if not pad.is_empty() else 0.0)) * battle_devices.scale_at(point, "range")

func _attack_range_point(point: Vector2) -> Vector2:
	# Endless uses translation-only camera geometry, not campaign perspective.
	return point if endless_mode else StageProjection.project(point)

func attack_range_screen_radii(hero: Dictionary) -> Vector2:
	var depth: float = 1.0 if endless_mode else StageProjection.depth_scale(hero.pos)
	var radius_x: float = (42.0 + float(hero.range) * 0.62 * depth) * terrain_range_scale(hero.pos)
	return Vector2(radius_x, radius_x * 0.40)

func is_in_attack_range(hero: Dictionary, point: Vector2) -> bool:
	# A chain/splash burst can call this thousands of times with the same hero.
	# Cache only hero geometry, never enemy eligibility or position.
	var id := int(hero.get("id", -1))
	var memo: Dictionary = projectile_range_cache.get(id,{}) if projectile_query_active else {}
	if projectile_query_active and memo.has(point): return bool(memo[point])
	var cached: Dictionary = attack_geometry_cache.get(id, {})
	var position := Vector2(hero.pos)
	var attack_range := float(hero.range)
	if cached.is_empty() or cached.pos != position or float(cached.attack_range) != attack_range or float(cached.time) != elapsed:
		var radii := attack_range_screen_radii(hero)
		cached = {"pos":position, "attack_range":attack_range, "time":elapsed, "center":_attack_range_point(position)+Vector2(0,8), "radii":radii, "world_center":StageProjection.ground_center(position) if not endless_mode else position, "world_radii":StageProjection.ground_world_radii(position, radii) if not endless_mode else radii}
		attack_geometry_cache[id] = cached
		projectile_range_cache.erase(id)
	var delta := point - Vector2(cached.world_center) if not endless_mode else _attack_range_point(point)-Vector2(cached.center)
	var radii := Vector2(cached.world_radii) if not endless_mode else Vector2(cached.radii)
	var inside := delta.x*delta.x/(radii.x*radii.x)+delta.y*delta.y/(radii.y*radii.y) <= 1.0
	if projectile_query_active:
		memo[point] = inside
		projectile_range_cache[id] = memo
	return inside

func _enemies_in_hero_range(hero: Dictionary) -> Dictionary:
	var id := int(hero.id)
	if projectile_range_enemies.has(id): return projectile_range_enemies[id]
	var eligible: Dictionary = {}
	for enemy: Dictionary in enemies:
		if float(enemy.hp)>0.0 and is_in_attack_range(hero,enemy.pos): eligible[int(enemy.id)]=true
	projectile_range_enemies[id]=eligible
	return eligible

func _apply_attack_extras(target: Dictionary, hero: Dictionary, damage: float) -> void:
	if float(hero.get("blast_radius", 0.0)) > 0.0:
		splash_damage(target, damage * 0.45, float(hero.blast_radius), hero)
	if int(hero.get("chain_count", 0)) > 0:
		chain_damage(target, damage * 0.55, int(hero.chain_count), hero)
	if float(hero.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
		apply_hit(target, damage * float(hero.echo_ratio), hero.element)
		events.append({"kind": "echo", "pos": target.pos})

func apply_hit(enemy: Dictionary, raw_damage: float, element: String, source_hero_id: int = -1, critical: bool = false) -> float:
	if source_hero_id < 0 and damage_source_override >= 0:
		source_hero_id = damage_source_override
	if enemy.is_empty() or enemy.hp <= 0 or float(enemy.get("spawn_timer", 0.0)) > 0.0 or bool(enemy.get("burrow_new",false)) or float(enemy.get("burrow_timer",0))>0:
		return 0.0
	raw_damage *= HeroSignature.outgoing_multiplier(self, source_hero_id)
	if float(enemy.get("shield", 0.0)) > 0.0:
		var absorbed: float = minf(float(enemy.shield), raw_damage)
		enemy.shield = float(enemy.shield) - absorbed
		raw_damage -= absorbed
		events.append({"kind": "shield_hit", "pos": enemy.pos, "value": ceili(absorbed)})
		if float(enemy.shield) <= 0.0:
			events.append({"kind": "shield_break", "pos": enemy.pos, "value": 0})
		if raw_damage <= 0.0:
			enemy.flash = 0.08
			return 0.0
	var multiplier: float = 1.0
	var incoming_element := normalize_element(element)
	if float(enemy.get("frozen_timer", 0.0)) > 0.0 and incoming_element in ["", "geo"]:
		multiplier *= 1.55
		enemy.frozen_timer = 0.0
		events.append({"kind": "shatter", "pos": enemy.pos})
	if incoming_element != "":
		if enemy.aura != "" and normalize_element(str(enemy.aura)) != incoming_element and enemy.reaction_timer <= 0:
			var aura_element := normalize_element(str(enemy.aura))
			var reaction: String = reaction_for(aura_element, incoming_element)
			multiplier *= reaction_multiplier(reaction, aura_element, incoming_element) * (1.0 + reaction_damage_bonus)
			enemy.aura = str(enemy.get("intrinsic_element", ""))
			enemy.aura_timer = INF if not str(enemy.aura).is_empty() else 0.0
			enemy.reaction_timer = REACTION_COOLDOWN
			reactions += 1
			events.append({"kind": reaction, "pos": enemy.pos})
			match reaction:
				"overloaded":
					enemy.pos.x += 75.0
					projectile_neighbor_cache.clear()
					projectile_chain_cache.clear()
					projectile_range_enemies.clear()
					projectile_splash_cache.clear()
					projectile_enemy_bins.clear()
					projectile_bins_ready = false
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 75})
					splash_damage(enemy, raw_damage * 0.65 * (1.0 + reaction_damage_bonus), 92.0 + reaction_radius_bonus)
				"swirl":
					_spread_swirl(enemy, aura_element, raw_damage * 0.48 * (1.0 + reaction_damage_bonus), 110.0 + reaction_radius_bonus)
				"electro_charged": chain_damage(enemy, raw_damage * 0.42, 2)
				"superconduct":
					enemy.armor = maxf(0.0, float(enemy.armor) - 18.0)
					enemy.slow_timer = maxf(float(enemy.slow_timer), 1.6)
				"frozen":
					enemy.frozen_timer = maxf(float(enemy.get("frozen_timer", 0.0)), 3.2 + skill_duration_bonus * 2.0)
					enemy.slow_timer = maxf(float(enemy.slow_timer), 3.2)
				"crystallize":
					crystal_shield = minf(500.0, crystal_shield + 35.0 + raw_damage * 0.20)
					events.append({"kind": "crystal_guard", "pos": heroes[0].pos if not heroes.is_empty() else Vector2(350, 360), "value": ceili(35.0 + raw_damage * 0.20)})
		elif enemy.aura == "" or enemy.aura == element:
			enemy.aura = incoming_element
			enemy.aura_timer = aura_duration
	# Reactions can recursively kill this enemy, or start its burrow revival.
	# The returning outer hit must not damage or settle that death again.
	if enemy.hp <= 0.0 or bool(enemy.get("death_settled", false)) or bool(enemy.get("revive_pending", false)) or bool(enemy.get("burrow_new", false)) or float(enemy.get("burrow_timer", 0.0)) > 0.0:
		return 0.0
	if incoming_element == "hydro" and source_hero_id >= 0 and source_hero_id < heroes.size() and str(heroes[source_hero_id].get("character_id", "")) == "hero_01":
		var requiem_hits: Dictionary = enemy.get("requiem_hits", {})
		var next_hit := mini(5, int(requiem_hits.get(source_hero_id, 0)) + 1)
		requiem_hits[source_hero_id] = next_hit
		enemy.requiem_hits = requiem_hits
		multiplier *= 1.0 + 0.04 * float(next_hit)
	var damage: float = raw_damage * multiplier * 100.0 / (100.0 + maxf(0, enemy.armor))
	if enemy.get("kind", "") == "armored" or str(enemy.get("kind", "")).begins_with("boss_"):
		damage *= 1.0 + elite_damage_bonus
	if execute_threshold > 0.0 and enemy.hp / enemy.max_hp <= minf(0.65, execute_threshold):
		damage *= 1.6
	enemy.hp -= damage
	if str(enemy.get("kind", "")) == "boss_03":
		_maybe_summon_galio(enemy)
		if bool(enemy.get("kindred_respite_active", false)):
			enemy.hp = maxf(1.0, float(enemy.hp))
		elif not bool(enemy.get("kindred_respite_used", false)) and enemy.hp <= 1.0:
			_activate_kindred_respite(enemy)
	_record_damage(source_hero_id, damage)
	enemy.flash = 0.1
	_emit_hit_feedback(enemy, ceili(damage), incoming_element, source_hero_id, critical)
	if enemy.hp > 0.0 and str(enemy.get("kind", "")).begins_with("boss_"):
		_update_boss_phase(enemy)
	if enemy.hp <= 0:
		if bool(enemy.get("death_settled", false)):
			return damage
		if EnemyTactics.begin_revival(self, enemy):
			return damage
		enemy.death_settled = true
		if enemy.get("kind", "") == "splitter" and not bool(enemy.get("spawner", false)) and not bool(enemy.get("split_done", false)):
			enemy.split_done = true
			for i in int(enemy.get("split_count", 2)):
				var child := spawn_enemy(enemy.pos + Vector2(24.0 + i * 18.0, -22.0 + i * 44.0), "runner")
				if endless_mode:
					_apply_endless_scaling(child, _endless_tier(), 0.72)
				child.hp *= 0.58
				child.max_hp = child.hp
				child.xp = 4
			events.append({"kind": "split", "pos": enemy.pos, "value": int(enemy.get("split_count", 2))})
		elif "duplicator" in enemy.get("affixes",[]) and not bool(enemy.get("split_done",false)):
			enemy.split_done = true
			for i in 2:
				var copy_enemy := spawn_enemy(enemy.pos+Vector2(22.0,(i*2-1)*26.0),"runner")
				if endless_mode:
					_apply_endless_scaling(copy_enemy, _endless_tier(), 0.72)
				copy_enemy.hp = enemy.max_hp*0.22
				copy_enemy.max_hp = copy_enemy.hp
				copy_enemy.affixes = []
				copy_enemy.xp = 3
			events.append({"kind":"enemy_duplicate","pos":enemy.pos,"value":2})
		EnemyTactics.on_death(self,enemy)
		kills += 1
		battle_devices.on_kill(self, enemy)
		if str(enemy.get("kind", "")).begins_with("boss_"):
			boss_kills += 1
		kill_streak += 1
		kill_streak_timer = 2.5
		best_streak = maxi(best_streak, kill_streak)
		if kill_streak == 10 or kill_streak == 25 or kill_streak % 50 == 0:
			events.append({"kind": "kill_streak", "pos": enemy.pos, "value": kill_streak})
		if "volatile" in enemy.get("affixes", []) and enemy.kind!="originium_bug":
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and hero.pos.distance_to(enemy.pos) <= 95.0:
					damage_hero(hero.id, 36.0, Readability.source(enemy))
			events.append({"kind":"enemy_volatile","pos":enemy.pos,"value":36})
		if death_burst_ratio > 0.0:
			splash_damage(enemy, enemy.max_hp * death_burst_ratio, 90.0)
			events.append({"kind": "death_burst", "pos": enemy.pos})
		var milestone: int = kills / 10
		if kill_frenzy_step > 0.0 and milestone > frenzy_milestone:
			for hero: Dictionary in heroes:
				var previous := float(hero.get("frenzy_bonus",0.0))
				var current := minf(.30,previous+kill_frenzy_step*(milestone-frenzy_milestone))
				hero.frenzy_bonus=current
				hero.rate=float(hero.rate)+float(hero.base_rate)*(current-previous)
				_clamp_hero_attack_rate(hero)
			frenzy_milestone = milestone
			events.append({"kind": "frenzy", "pos": enemy.pos, "value": milestone})
		if endless_mode: expedition.on_kill(enemy)
		grant_xp(enemy.xp)
		if float(enemy.get("death_burst", 0.0)) > 0.0:
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and hero.pos.distance_to(enemy.pos) <= 105.0:
					damage_hero(hero.id, float(enemy.death_burst), Readability.source(enemy))
			events.append({"kind":"enemy_volatile","pos":enemy.pos,"value":int(enemy.death_burst)})
		enemy_lookup.erase(int(enemy.id))
		events.append({"kind": "death", "pos": enemy.pos, "enemy_kind": str(enemy.get("kind", "")), "facing": float(enemy.get("facing", -1.0)), "size": float(enemy.get("size", 48.0)), "color": str(enemy.get("color", "#ffffff"))})
	return damage

func _update_boss_phase(enemy: Dictionary) -> void:
	var ratio: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
	var target_phase := (2 if ratio <= 0.50 else 1) if str(enemy.get("kind", "")) == "boss_02" else (3 if ratio <= 0.35 else (2 if ratio <= 0.70 else 1))
	var current_phase := int(enemy.get("boss_phase", 1))
	if target_phase <= current_phase:
		return
	var jumps := target_phase - current_phase
	enemy.boss_phase = target_phase
	var style := str(enemy.get("boss_style", "commander"))
	var damage_step := 1.25 if style in ["artillery", "chronophage"] else 1.18
	var speed_step := 1.22 if style in ["storm", "chronophage"] else 1.11
	enemy.damage *= pow(damage_step, jumps)
	enemy.speed *= pow(speed_step, jumps)
	enemy.rate *= pow(1.13, jumps)
	enemy.boss_pulse = maxf(2.6, float(enemy.get("boss_pulse", 7.0)) * pow(0.80, jumps))
	enemy.special_timer = minf(float(enemy.special_timer), 0.65)
	var restore_ratio := float(enemy.get("phase_shield_restore", 0.42 if target_phase == 3 else 0.30))
	var restored: float = float(enemy.get("max_shield", 0.0)) * restore_ratio
	enemy.shield = minf(float(enemy.get("max_shield", 0.0)), float(enemy.get("shield", 0.0)) + restored)
	var minion_count := target_phase if style in ["brood", "commander"] else 1
	for i in minion_count:
		var kind := _bounded_endless_summon_kind(str(enemy.get("phase_minion", "runner")), i)
		if kind.is_empty():
			break
		var spawn_point: Vector2 = enemy.pos + Vector2(58.0 + i * 30.0, (i - 1) * 56.0)
		if endless_mode and kind == "splitter":
			spawn_point = _endless_interior_spawn_point(i % 4, 0.28 + fposmod(i * 0.23, 0.44))
		var minion := spawn_enemy(spawn_point, kind)
		if endless_mode:
			_apply_endless_scaling(minion, _endless_tier(), 0.78)
		minion.hp *= 0.74
		minion.max_hp = minion.hp
	var phase_definition: Dictionary = {}
	if database != null:
		var pattern: Dictionary = database.boss_patterns.get(str(enemy.get("kind", "")), {})
		var phase_rows: Array = pattern.get("phases", [])
		if target_phase - 1 < phase_rows.size():
			phase_definition = phase_rows[target_phase - 1]
	if stage_runtime != null and not phase_definition.get("arena_event", {}).is_empty():
		var arena_event: Dictionary = stage_runtime.apply_arena_event(phase_definition.arena_event, enemy.pos)
		events.append({"kind":"arena_event","pos":enemy.pos,"arena_type":arena_event.get("type", "hazard"),"duration":arena_event.get("duration", 6.0),"radius":arena_event.get("radius", 160.0),"intensity":arena_event.get("intensity", target_phase)})
	events.append({"kind": "boss_phase", "pos": enemy.pos, "value": target_phase, "name": str(enemy.name), "shield": ceili(restored), "style": style})
func reaction_for(first: String, second: String) -> String:
	var pair := [normalize_element(first), normalize_element(second)]
	pair.sort()
	var key: String = "+".join(pair)
	return {
		"hydro+pyro": "vaporize", "cryo+pyro": "melt", "electro+pyro": "overloaded",
		"cryo+electro": "superconduct", "electro+hydro": "electro_charged", "cryo+hydro": "frozen",
		"anemo+cryo": "swirl", "anemo+electro": "swirl", "anemo+hydro": "swirl", "anemo+pyro": "swirl",
		"cryo+geo": "crystallize", "electro+geo": "crystallize", "geo+hydro": "crystallize", "geo+pyro": "crystallize",
	}.get(key, "element_burst")

func normalize_element(element: String) -> String:
	return "pyro" if element == "fire" else ("hydro" if element == "water" else element)

func reaction_multiplier(reaction: String, first: String = "", second: String = "") -> float:
	if reaction == "vaporize":
		return 2.0 if normalize_element(first) == "pyro" and normalize_element(second) == "hydro" else vapor_multiplier
	if reaction == "melt":
		return 2.0 if normalize_element(first) == "cryo" and normalize_element(second) == "pyro" else 1.5
	return {"overloaded": 1.35, "superconduct": 1.20, "electro_charged": 1.25, "frozen": 1.10, "swirl": 1.22, "crystallize": 1.08, "element_burst": 1.15}.get(reaction, 1.0)

func _spread_swirl(primary: Dictionary, spread_element: String, damage: float, radius: float) -> void:
	for nearby: Dictionary in enemies.duplicate():
		if nearby.id != primary.id and nearby.hp > 0.0 and nearby.pos.distance_to(primary.pos) <= radius:
			apply_hit(nearby, damage, spread_element)
	events.append({"kind": "swirl_spread", "pos": primary.pos, "value": spread_element})

func _projectile_tick(dt: float) -> void:
	# Positions are stable during this phase except reaction knockback/spawning,
	# which explicitly invalidate this short-lived neighbor snapshot.
	var enclosing_query := projectile_query_active
	projectile_query_active = true
	if not enclosing_query:
		projectile_range_cache.clear()
		projectile_range_enemies.clear()
		projectile_neighbor_cache.clear()
		projectile_chain_cache.clear()
		projectile_range_enemies.clear()
		projectile_splash_cache.clear()
		projectile_enemy_bins.clear()
		projectile_bins_ready = false
	var surviving: Array[Dictionary] = []
	for shot in projectiles:
		shot.life = float(shot.get("life", PROJECTILE_LIFETIME)) - dt
		if float(shot.life) <= 0.0:
			continue
		# Old QA/debug shots acquire a direction once, never every frame.
		if not shot.has("direction"):
			var initial_target := find_enemy(int(shot.get("target_id", -1)))
			if initial_target.is_empty(): continue
			shot.direction = (Vector2(initial_target.pos) + Vector2(0, -12) - Vector2(shot.pos)).normalized()
			shot.ballistic = true
			shot.hit_ids = []
		if not shot.has("hit_ids"): shot.hit_ids = []
		var source_hero: Dictionary = {}
		var source_id := int(shot.get("source_id", -1))
		if source_id >= 0 and source_id < heroes.size():
			source_hero = heroes[source_id]
		var start := Vector2(shot.pos)
		var finish := start + Vector2(shot.direction) * float(shot.get("speed", PROJECTILE_SPEED)) * dt
		shot.previous_pos = start
		shot.pos = finish
		var wall_fraction := _projectile_wall_fraction(start, finish)
		var contacts: Array[Dictionary] = []
		for candidate: Dictionary in _projectile_candidates(start, finish):
			if candidate.hp <= 0.0 or float(candidate.get("spawn_timer", 0.0)) > 0.0 or int(candidate.id) in shot.get("hit_ids", []): continue
			if bool(candidate.get("flying", false)) and not bool(shot.get("can_hit_air", true)): continue
			if bool(candidate.get("burrow_new", false)) or float(candidate.get("burrow_timer", 0.0)) > 0.0: continue
			var body_width := clampf(float(candidate.get("size", 48.0)) * 0.28, 12.0, 36.0) + 5.0
			var fraction := _swept_body_fraction(start, finish, Vector2(candidate.pos) + Vector2(0, -12), Vector2(body_width, body_width * 0.65))
			if fraction < wall_fraction: contacts.append({"fraction":fraction, "enemy":candidate})
		contacts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.fraction) < float(b.fraction))
		var consumed := false
		for contact: Dictionary in contacts:
			var target: Dictionary = contact.enemy
			if target.hp <= 0.0: continue
			shot.hit_ids.append(int(target.id))
			attack_audio_source_override = source_id
			var dealt: float = apply_hit(target, shot.damage, shot.element, source_id, bool(shot.get("critical", false)))
			events.append({"kind":"projectile_impact", "pos":start.lerp(finish, float(contact.fraction)), "element":shot.element, "style":shot.get("style", "standard"), "direction":shot.direction, "hero_id":source_id, "enemy_id":int(target.id), "critical":bool(shot.get("critical", false))})
			if bool(shot.get("critical", false)):
				events.append({"kind": "critical", "pos": target.pos, "value": ceili(dealt), "hero_id": source_id})
			var secondary := normalize_element(str(shot.get("secondary_element", "")))
			if not secondary.is_empty() and target.hp > 0.0:
				apply_hit(target, float(shot.damage) * 0.85, secondary)
			if shot.get("slow", false):
				target.slow_timer = 2.0
			if shot.get("splash", false):
				splash_damage(target, shot.damage * 0.5, 65.0, source_hero)
			if float(shot.get("blast_radius", 0.0)) > 0.0:
				splash_damage(target, shot.damage * 0.45, float(shot.blast_radius), source_hero)
			if int(shot.get("chain_count", 0)) > 0:
				chain_damage(target, shot.damage * 0.55, int(shot.chain_count), source_hero)
			if float(shot.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
				apply_hit(target, shot.damage * float(shot.echo_ratio), shot.element)
				events.append({"kind": "echo", "pos": target.pos})
			attack_audio_source_override = -1
			if int(shot.get("pierce", 0)) > 0:
				shot.pierce = int(shot.pierce) - 1
				events.append({"kind":"pierce", "pos":target.pos, "hero_id":source_id})
			else:
				consumed = true
				break
		if not consumed and wall_fraction == INF and _projectile_in_bounds(finish):
			surviving.append(shot)
	projectiles = surviving
	projectile_query_active = enclosing_query
	if not enclosing_query:
		projectile_range_cache.clear()
		projectile_range_enemies.clear()
		projectile_neighbor_cache.clear()
		projectile_chain_cache.clear()
		projectile_range_enemies.clear()
		projectile_splash_cache.clear()
		projectile_enemy_bins.clear()
		projectile_bins_ready = false

func _projectile_wall_fraction(start: Vector2, finish: Vector2) -> float:
	var ground_start := start + Vector2(0, 12)
	var ground_finish := finish + Vector2(0, 12)
	if not terrain_line_blocked(ground_start, ground_finish): return INF
	var low := 0.0
	var high := 1.0
	for iteration in 8:
		var middle := (low + high) * 0.5
		if terrain_line_blocked(ground_start, ground_start.lerp(ground_finish, middle)):
			high = middle
		else:
			low = middle
	return high

func _projectile_candidates(start: Vector2, finish: Vector2) -> Array[Dictionary]:
	return enemy_candidates_in_rect(Rect2(start, finish - start).abs().grow(52.0))

func enemy_candidates_in_rect(area: Rect2) -> Array[Dictionary]:
	# Outside a stable fixed-step phase, use live positions. Debug tools can move
	# units directly and must never inherit yesterday's bucket assignment.
	if not projectile_query_active:
		var live: Array[Dictionary] = []
		for enemy: Dictionary in enemies:
			if float(enemy.hp) > 0.0 and area.has_point(enemy.pos): live.append(enemy)
		return live
	if not projectile_bins_ready:
		projectile_enemy_bins.clear()
		for enemy: Dictionary in enemies:
			if enemy.hp <= 0.0: continue
			var cell := Vector2i((Vector2(enemy.pos) / PROJECTILE_BIN_SIZE).floor())
			if not projectile_enemy_bins.has(cell): projectile_enemy_bins[cell] = []
			projectile_enemy_bins[cell].append(enemy)
		projectile_bins_ready = true
	var first := Vector2i((area.position / PROJECTILE_BIN_SIZE).floor())
	var last := Vector2i((area.end / PROJECTILE_BIN_SIZE).floor())
	var candidates: Array[Dictionary] = []
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			for enemy: Dictionary in projectile_enemy_bins.get(Vector2i(x, y), []):
				if float(enemy.hp) > 0.0 and area.has_point(enemy.pos): candidates.append(enemy)
	return candidates

func _nearest_enemy_after(origin: Dictionary, excluded: Array, source_hero: Dictionary = {}, max_distance: float = INF) -> Dictionary:
	# Cache the exact nearest eligible result during a stable simulation phase.
	var reusable := projectile_query_active and excluded.size() <= 3 and (not is_finite(max_distance) or floorf(max_distance) == max_distance)
	var key := Vector3i(int(origin.id),int(source_hero.get("id",-1)),ceili(max_distance) if is_finite(max_distance) else -1)
	var exclusions := Vector3i(int(excluded[0]) if excluded.size()>0 else -1,int(excluded[1]) if excluded.size()>1 else -1,int(excluded[2]) if excluded.size()>2 else -1)
	var memo: Dictionary = projectile_chain_cache.get(key,{}) if reusable else {}
	if reusable and memo.has(exclusions):
		var cached: Dictionary = memo[exclusions]
		if cached.is_empty() or float(cached.hp)>0.0: return cached
	var result: Dictionary = {}
	var center := Vector2(origin.pos)
	var eligibility := _enemies_in_hero_range(source_hero) if projectile_query_active and not source_hero.is_empty() else {}
	var neighbor_key := Vector2i(int(origin.id),ceili(max_distance) if is_finite(max_distance) else -1)
	if projectile_query_active:
		if not projectile_neighbor_cache.has(neighbor_key):
			var neighbors: Array = []
			var candidates: Array = enemy_candidates_in_rect(Rect2(center-Vector2.ONE*max_distance,Vector2.ONE*max_distance*2).grow(.001)) if is_finite(max_distance) else enemies
			for enemy: Dictionary in candidates:
				if enemy.hp<=0.0 or enemy.id==origin.id or float(enemy.get("spawn_timer",0.0))>0.0 or float(enemy.get("burrow_timer",0.0))>0.0 or bool(enemy.get("burrow_new",false)): continue
				var distance := Vector2(enemy.pos).distance_squared_to(center)
				if distance>max_distance*max_distance: continue
				neighbors.append([distance,enemy])
			neighbors.sort_custom(func(a: Array,b: Array)->bool: return float(a[0])<float(b[0]) if a[0]!=b[0] else int(a[1].id)<int(b[1].id))
			projectile_neighbor_cache[neighbor_key]=neighbors
		for pair: Array in projectile_neighbor_cache[neighbor_key]:
			var enemy: Dictionary=pair[1]
			if float(enemy.hp)>0.0 and not enemy.id in excluded and (source_hero.is_empty() or eligibility.has(int(enemy.id))):
				result=enemy
				break
	else:
		var best_distance := max_distance*max_distance
		for enemy: Dictionary in enemies:
			if enemy.hp<=0.0 or enemy.id==origin.id or enemy.id in excluded or float(enemy.get("spawn_timer",0.0))>0.0: continue
			var distance := Vector2(enemy.pos).distance_squared_to(center)
			if distance>best_distance or (distance==best_distance and not result.is_empty() and int(enemy.id)>int(result.id)): continue
			if not source_hero.is_empty() and not is_in_attack_range(source_hero,enemy.pos): continue
			result=enemy
			best_distance=distance
	if reusable:
		memo[exclusions]=result
		projectile_chain_cache[key]=memo
	return result

func chain_damage(primary: Dictionary, damage: float, count: int, source_hero: Dictionary = {}) -> void:
	var current: Dictionary = primary
	var excluded: Array = [primary.id]
	for index in count:
		var next_target := _nearest_enemy_after(current, excluded, source_hero, 180.0)
		if next_target.is_empty() or next_target.pos.distance_to(current.pos) > 180.0:
			break
		apply_hit(next_target, damage, "electro")
		events.append({"kind": "chain", "pos": next_target.pos})
		excluded.append(next_target.id)
		current = next_target

func _support_tick(dt: float) -> void:
	for key: String in supports:
		var support: Dictionary = supports[key]
		support.timer = float(support.timer) - dt
		if key == "support_crossfire" and support.timer <= 0.85 and not support.has("lane_y"):
			for enemy: Dictionary in enemies:
				if enemy.hp > 0.0:
					support.lane_y = float(enemy.pos.y)
					break
		if key == "support_barrage" and support.timer <= 1.35 and not support.has("target_point"):
			var locked: Dictionary = {}
			for enemy: Dictionary in enemies:
				if enemy.hp > 0.0 and (locked.is_empty() or enemy.hp > float(locked.hp)):
					locked = enemy
			if not locked.is_empty():
				support.target_point = Vector2(locked.pos)
		if support.timer > 0.0:
			continue
		support.timer += float(support.interval)
		_trigger_support(key, support)

func _trigger_support(kind: String, support: Dictionary) -> void:
	var support_power := float(support.power)
	if kind == "support_heal":
		support_power *= CardSynergies.team_multiplier(self, "healing_tide", 1.20)
	elif kind in ["support_barrage", "support_crossfire"]:
		support_power *= CardSynergies.team_multiplier(self, "cross_barrage", 1.20)
	if kind == "support_heal":
		var visible_hero_ids: Array[int] = []
		for hero: Dictionary in heroes:
			var was_down := float(hero.hp) <= 0.0
			var healed := minf(float(hero.max_hp) - float(hero.hp), support_power)
			hero.hp += healed
			if was_down and hero.hp > 0.0:
				hero.animation_state = "idle"
				hero.status_timer = 0.0
				hero.moving = false
				hero.target = hero.pos
				events.append({"kind":"revive","pos":hero.pos,"hero_id":int(hero.id)})
			if bool(hero.get("deployed", false)) and hero.hp > 0.0:
				visible_hero_ids.append(int(hero.id))
		var repair := ceili(support_power * 0.35)
		base_hp = mini(base_max_hp, base_hp + repair)
		events.append({"kind": "support_heal", "pos": base_world_position(), "value": ceili(support_power), "base_value": repair, "hero_ids": visible_hero_ids})
		return
	if enemies.is_empty():
		support.erase("lane_y")
		support.erase("target_point")
		return
	if kind == "support_crossfire":
		var lane_y: float = float(support.get("lane_y", enemies[0].pos.y))
		var field := active_view_rect if endless_mode else MOVE_AREA
		var hit_positions: Array[Vector2] = []
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and field.has_point(Vector2(enemy.pos)) and absf(float(enemy.pos.y) - lane_y) <= 58.0:
				var hit_point := Vector2(enemy.pos)
				var shield_before := float(enemy.get("shield",0.0))
				var hit_damage := apply_hit(enemy, support_power*SUPPORT_DAMAGE_SCALE, "")
				if hit_damage > 0.0 or float(enemy.get("shield",0.0)) < shield_before:
					hit_positions.append(hit_point)
		support.erase("lane_y")
		events.append({"kind": "crossfire", "pos": Vector2(field.get_center().x, lane_y), "lane_y": lane_y, "lane_half_width": 58.0, "value": int(support.stacks), "hit_positions": hit_positions})
	elif kind == "support_finale":
		for volley in int(support.stacks):
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0:
					apply_hit(enemy, support_power*SUPPORT_DAMAGE_SCALE, "")
		events.append({"kind": "finale", "pos": Vector2(760, 360), "value": int(support.stacks)})
	else:
		var target: Dictionary = {}
		for enemy: Dictionary in enemies:
			if enemy.hp > 0.0 and (target.is_empty() or enemy.hp > target.hp):
				target = enemy
		if target.is_empty() and not support.has("target_point"):
			return
		var center: Vector2 = Vector2(support.get("target_point", target.get("pos", Vector2.ZERO)))
		support.erase("target_point")
		var radius := float(support.radius)
		var hit_positions: Array[Vector2] = []
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and support_barrage_contains(center, Vector2(enemy.pos), radius):
				var hit_point := Vector2(enemy.pos)
				var shield_before := float(enemy.get("shield",0.0))
				var hit_damage := apply_hit(enemy, support_power*SUPPORT_DAMAGE_SCALE, "pyro")
				if hit_damage > 0.0 or float(enemy.get("shield",0.0)) < shield_before:
					hit_positions.append(hit_point)
		events.append({"kind": "barrage", "pos": center, "value": int(support.stacks), "radius": radius, "hit_positions": hit_positions})

func support_barrage_screen_radii(point: Vector2, radius: float) -> Vector2:
	var width := radius
	if not endless_mode:
		width = absf(StageProjection.project(point + Vector2(radius, 0.0)).x - StageProjection.project(point).x)
	return Vector2(width, width * 0.40)

func support_barrage_contains(center: Vector2, candidate: Vector2, radius: float) -> bool:
	var radii := support_barrage_screen_radii(center, radius)
	if not endless_mode:
		return StageProjection.ground_contains(center, candidate, radii, 0.0)
	var center_screen := center if endless_mode else StageProjection.project(center)
	var candidate_screen := candidate if endless_mode else StageProjection.project(candidate)
	var offset := candidate_screen - center_screen
	return pow(offset.x / maxf(1.0, radii.x), 2.0) + pow(offset.y / maxf(1.0, radii.y), 2.0) <= 1.0

func _emit_hit_feedback(enemy: Dictionary, value: int, element: String, source_hero_id: int = -1, critical: bool = false) -> void:
	var audio_source := attack_audio_source_override if attack_audio_source_override >= 0 else source_hero_id
	var key := int(enemy.id)
	var by_element: Dictionary = hit_feedback_cache.get(key,{}) if enemies.size()>=40 else {}
	var audio_bucket := element+":"+str(audio_source)+":"+str(critical) if enemies.size()>=40 else ""
	if not by_element.is_empty() and by_element.has(audio_bucket):
		by_element[audio_bucket].value = int(by_element[audio_bucket].value)+value
		return
	var feedback := {"kind":"hit","pos":enemy.pos+Vector2(0,-12),"value":value,"element":element,"critical":critical,"enemy_id":key}
	if audio_source>=0: feedback.hero_id=audio_source
	if enemies.size()>=40:
		by_element[audio_bucket]=feedback
		hit_feedback_cache[key]=by_element
	events.append(feedback)

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events
	events = []
	hit_feedback_cache.clear()
	if enemies.size() >= 40 and result.size() > 180:
		result = _compact_cosmetic_events(result)
	return result

func _compact_cosmetic_events(batch: Array[Dictionary]) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var buckets: Dictionary = {}
	for event: Dictionary in batch:
		var kind := str(event.get("kind", ""))
		if kind not in ["hit", "critical", "splash", "chain", "pierce", "orbit_hit", "echo", "shield_hit", "knockback"]:
			output.append(event)
			continue
		var point := Vector2(event.get("pos", Vector2.ZERO))
		var key := kind+":"+str(event.get("element", ""))+":"+str(event.get("hero_id", -1))+":"+str(event.get("critical", false))+":"+(str(event.get("enemy_id", -1)) if kind == "hit" else str(Vector2i(floori(point.x/64.0),floori(point.y/48.0))))
		if buckets.has(key):
			var old: Dictionary = buckets[key]
			if event.get("value",0) is int or event.get("value",0) is float:
				old.value = float(old.get("value",0))+float(event.get("value",0))
		else:
			buckets[key] = event
			output.append(event)
	return output

func splash_damage(primary: Dictionary, damage: float, radius: float, source_hero: Dictionary = {}) -> void:
	var candidates: Array
	var key := Vector2(int(primary.id), radius)
	if projectile_query_active and projectile_splash_cache.has(key):
		candidates = projectile_splash_cache[key]
	else:
		candidates = enemy_candidates_in_rect(Rect2(Vector2(primary.pos) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0).grow(0.001))
		if projectile_query_active: projectile_splash_cache[key] = candidates
	var eligibility := _enemies_in_hero_range(source_hero) if projectile_query_active and not source_hero.is_empty() else {}
	for enemy: Dictionary in candidates:
		if enemy.id != primary.id and enemy.hp > 0 and Vector2(enemy.pos).distance_squared_to(Vector2(primary.pos)) <= radius * radius and (source_hero.is_empty() or (eligibility.has(int(enemy.id)) if projectile_query_active else is_in_attack_range(source_hero,enemy.pos))):
			apply_hit(enemy, damage, "")
	events.append({"kind": "splash", "pos": primary.pos})

func grant_xp(amount: int) -> void:
	if v2_mode:
		var solo_levels := int(run_state.buff_levels.get("solo_leveling", 0))
		var boosted_amount := roundi(minf(2147483647.0, float(amount) * (1.0+0.35*mini(solo_levels,2))))
		var previous_level: int = run_state.crystal_level
		var gained: int = _grant_endless_xp(boosted_amount) if endless_mode else crystal.grant(run_state, boosted_amount)
		team_xp = run_state.crystal_xp
		team_level = run_state.crystal_level
		if gained > 0:
			for slot in range(1, heroes.size()):
				if not endless_mode and previous_level < deployment_required_level(slot) and run_state.crystal_level >= deployment_required_level(slot):
					events.append({"kind":"deployment_unlocked","hero_id":slot,"name":heroes[slot].name})
			events.append({"kind": "level_up", "value": run_state.crystal_level})
			if not workshop_mode and state == "running" and reward_cooldown <= 0.0:
				open_reward_or_compensate(true)
		return
	team_xp += amount
	while team_level < 5 and team_xp >= XP_THRESHOLDS[team_level - 1]:
		team_level += 1
		for h in heroes:
			h.damage += h.base_damage * 0.08
			rewards.increase_health(h, h.base_hp * 0.08)
			events.append({"kind": "level_up", "value": team_level})

func _grant_endless_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	run_state.crystal_xp += amount
	var gained := 0
	while run_state.crystal_xp >= endless_next_threshold():
		run_state.crystal_level += 1
		run_state.pending_level_ups += 1
		gained += 1
	return gained

func endless_next_threshold() -> int:
	var level := maxi(1, run_state.crystal_level)
	var n := float(level - 1)
	return roundi((60.0 + 60.0 * n + 24.0 * n * n + 2.5 * n * n * n) * pow(1.16, minf(120, maxf(0, level-40))))

func export_run_snapshot() -> Dictionary:
	var hero_snapshots: Array[Dictionary] = []
	var hero_keys := ["character_id", "hp", "max_hp", "armor", "damage", "rate", "range", "speed", "block", "can_hit_air", "element", "secondary_element", "base_damage", "base_hp", "base_rate", "cleave", "cleave_ratio", "splash", "slow", "projectile_count", "pierce", "chain_count", "blast_radius", "echo_ratio", "crit_chance", "card_levels", "card_synergies", "conqueror_attacks", "tempo_bonus", "tempo_idle", "warmog_timer", "frenzy_bonus", "heartsteel_growth", "card_third_attacks", "card_attack_idle", "card_counter_ready"]
	for hero: Dictionary in heroes:
		if bool(hero.get("temporary_assist", false)): continue
		var row: Dictionary = {}
		for key: String in hero_keys:
			if hero.has(key): row[key] = hero[key]
		hero_snapshots.append(row)
	return {
		"squad": run_state.squad.duplicate(),
		"traveler_element": run_state.traveler_element,
		"traveler_secondary_element": run_state.traveler_secondary_element,
		"buff_levels": run_state.buff_levels.duplicate(true),
		"card_synergies": run_state.card_synergies.duplicate(true),
		"tag_synergy_levels": tag_synergy_levels.duplicate(true),
		"fireball_level": fireball_level,
		"crystal_level": run_state.crystal_level,
		"crystal_xp": run_state.crystal_xp,
		"luck": run_state.luck,
		"heroes": hero_snapshots,
		"supports": supports.duplicate(true),
		"orbitals": orbitals.duplicate(true),
		"execute_threshold": execute_threshold,
		"death_burst_ratio": death_burst_ratio,
		"elite_damage_bonus": elite_damage_bonus,
		"kill_frenzy_step": kill_frenzy_step,
		"frenzy_milestone": frenzy_milestone,
		"reaction_damage_bonus": reaction_damage_bonus,
		"reaction_radius_bonus": reaction_radius_bonus,
		"skill_power_bonus": skill_power_bonus,
		"skill_cooldown_reduction": skill_cooldown_reduction,
		"skill_area_bonus": skill_area_bonus,
		"skill_duration_bonus": skill_duration_bonus,
		"energy_gain_bonus": energy_gain_bonus,
		"crystal_shield": crystal_shield
	}

func import_run_snapshot(snapshot: Dictionary) -> bool:
	if not endless_mode or snapshot.is_empty():
		return false
	run_state.traveler_element = str(snapshot.get("traveler_element", "none"))
	run_state.traveler_secondary_element = str(snapshot.get("traveler_secondary_element", "none"))
	run_state.buff_levels = snapshot.get("buff_levels", {}).duplicate(true)
	run_state.card_synergies = snapshot.get("card_synergies", {}).duplicate(true)
	tag_synergy_levels = snapshot.get("tag_synergy_levels", {}).duplicate(true)
	fireball_level = int(snapshot.get("fireball_level", 0))
	run_state.crystal_level = maxi(1, int(snapshot.get("crystal_level", 1)))
	run_state.crystal_xp = maxi(0, int(snapshot.get("crystal_xp", 0)))
	run_state.pending_level_ups = 0
	run_state.luck = clampf(float(snapshot.get("luck", 0.0)), 0.0, 1.5)
	card_pool.levels = run_state.buff_levels
	var saved_heroes: Array = snapshot.get("heroes", [])
	for saved: Variant in saved_heroes:
		if not saved is Dictionary: continue
		for hero: Dictionary in heroes:
			if str(hero.get("character_id", "")) != str(saved.get("character_id", "")): continue
			for key: String in saved:
				if key != "character_id": hero[key] = saved[key]
			hero.target = hero.pos
			hero.moving = false
			break
	supports = snapshot.get("supports", {}).duplicate(true)
	orbitals.assign(snapshot.get("orbitals", []).duplicate(true))
	execute_threshold = float(snapshot.get("execute_threshold", 0.0))
	death_burst_ratio = float(snapshot.get("death_burst_ratio", 0.0))
	elite_damage_bonus = float(snapshot.get("elite_damage_bonus", 0.0))
	kill_frenzy_step = float(snapshot.get("kill_frenzy_step", 0.0))
	frenzy_milestone = int(snapshot.get("frenzy_milestone",0))
	reaction_damage_bonus = float(snapshot.get("reaction_damage_bonus", 0.0))
	reaction_radius_bonus = float(snapshot.get("reaction_radius_bonus", 0.0))
	skill_power_bonus = float(snapshot.get("skill_power_bonus", 0.0))
	skill_cooldown_reduction = float(snapshot.get("skill_cooldown_reduction", 0.0))
	skill_area_bonus = float(snapshot.get("skill_area_bonus", 0.0))
	skill_duration_bonus = float(snapshot.get("skill_duration_bonus", 0.0))
	energy_gain_bonus = float(snapshot.get("energy_gain_bonus",0.0))
	crystal_shield = float(snapshot.get("crystal_shield", 0.0))
	var center := ENDLESS_ARENA.get_center()
	for index in heroes.size():
		var hero: Dictionary=heroes[index]
		var side := -1.0 if index%2==1 else 1.0
		var spawn := center if index==0 else center+Vector2(-78.0-float((index-1)/2)*22.0,side*32.0)
		hero.pos=_nearest_walkable_point(spawn,17.0); hero.target=hero.pos
		hero.deployed=true; hero.moving=false; hero.follow_independent=false; hero.animation_state="idle"
		hero.erase("endless_move_path"); hero.erase("endless_move_direction")
	follow_leader_id=0; formation_mode="follow"; _reset_follow_history()
	CardSynergies.refresh(self)
	_restore_card_evolution_phases()
	_clamp_combat_card_stats()
	return true

func element_name(element: String) -> String:
	return {"none": "无", "anemo": "风", "electro": "雷", "pyro": "火", "hydro": "水", "geo": "岩", "cryo": "冰"}.get(element, element)

func stage_lane_map() -> Dictionary:
	var result := {"upper": LANES[0], "main": LANES[1], "lower": LANES[2]}
	if v2_mode and stage_runtime != null:
		var configured: Dictionary = stage_runtime.definition.get("lanes", {})
		for key: String in configured:
			result[key] = float(configured[key])
	return result

func stage_lanes() -> Array:
	var mapping := stage_lane_map()
	return [mapping.upper, mapping.main, mapping.lower]

func _snap_route_center(point: Vector2) -> Vector2:
	var origin := Vector2(70.0, 160.0)
	var step := Vector2(60.0, 40.0)
	return Vector2(origin.x + roundf((point.x - origin.x) / step.x) * step.x, origin.y + roundf((point.y - origin.y) / step.y) * step.y)

func _orthogonalize_route(points: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for point: Vector2 in points:
		var snapped := _snap_route_center(point)
		if result.is_empty():
			result.append(snapped); continue
		var previous := result[-1]
		if absf(snapped.x - previous.x) > 0.1 and absf(snapped.y - previous.y) > 0.1:
			var corner := Vector2(snapped.x, previous.y) if result.size() % 2 == 0 else Vector2(previous.x, snapped.y)
			if not corner.is_equal_approx(previous): result.append(corner)
		if not snapped.is_equal_approx(result[-1]): result.append(snapped)
	return result

func _orthogonal_enemy_step(current: Vector2, target: Vector2, distance: float, radius: float) -> Vector2:
	var delta := target - current
	if delta.length_squared() <= 0.01:
		return current
	var horizontal := Vector2(target.x, current.y)
	var vertical := Vector2(current.x, target.y)
	var candidates: Array[Vector2] = []
	if absf(delta.x) >= absf(delta.y):
		candidates.append(horizontal)
		candidates.append(vertical)
	else:
		candidates.append(vertical)
		candidates.append(horizontal)
	for axis_target: Vector2 in candidates:
		if axis_target.distance_squared_to(current) <= 0.01:
			continue
		var candidate := current.move_toward(axis_target, distance)
		if _terrain_blocker_on_segment(current, candidate, radius).is_empty():
			return candidate
	return current

func stage_route(route_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not v2_mode or stage_runtime == null:
		return result
	var configured: Dictionary = stage_runtime.definition.get("routes", {})
	for value in configured.get(route_id, []):
		if value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
	return _orthogonalize_route(result)

func stage_spawn_points(route_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not v2_mode or stage_runtime == null:
		return result
	var configured: Dictionary = stage_runtime.definition.get("spawn_points", {})
	for value in configured.get(route_id, []):
		if value is Array and value.size() >= 2:
			result.append(_snap_route_center(Vector2(float(value[0]), float(value[1]))))
	return result

func stage_routes() -> Dictionary:
	var result := {}
	if not v2_mode or stage_runtime == null:
		return result
	for route_id: String in stage_runtime.definition.get("routes", {}):
		result[route_id] = stage_route(route_id)
	return result

func upcoming_waves(limit: int = 3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not v2_mode or endless_mode or stage_runtime == null:
		return result
	var waves: Array = stage_runtime.definition.get("waves", [])
	for i in waves.size():
		var wave: Dictionary = waves[i]
		var emitted: int = stage_runtime.wave_cursors[i]
		var count: int = int(wave.get("count", 0))
		if emitted >= count:
			continue
		var next_at := float(wave.get("at", 0.0)) + emitted * float(wave.get("interval", 1.0))
		var enemy_id := str(wave.get("enemy_id", "grunt"))
		result.append({"at": next_at, "eta": maxf(0.0, next_at - stage_runtime.elapsed), "enemy_id": enemy_id, "enemy_name": str(Catalog.ENEMIES.get(enemy_id, {}).get("name", enemy_id)), "route_id": str(wave.get("route_id", "main")), "count": count - emitted, "boss": false})
	if not stage_runtime.boss_emitted:
		var boss_id := str(stage_runtime.definition.get("boss_id", "boss_01"))
		var boss_at := float(stage_runtime.definition.get("boss_at_seconds", INF))
		result.append({"at": boss_at, "eta": maxf(0.0, boss_at - stage_runtime.elapsed), "enemy_id": boss_id, "enemy_name": str(Catalog.ENEMIES.get(boss_id, {}).get("name", boss_id)), "route_id": str(stage_runtime.definition.get("boss_route_id", "main")), "count": 1, "boss": true})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.at) < float(b.at))
	if result.size() > limit:
		result.resize(limit)
	return result

func _card_evolution_level(card: Dictionary, purchases: int) -> int:
	var phases: Array=card.get("evolution_levels",[])
	if phases.is_empty(): return maxi(1,purchases)
	return int(phases[clampi(purchases-1,0,phases.size()-1)])

func _orbital_card_state(owner: Dictionary,card: Dictionary,level: int,value: float) -> Dictionary:
	var blade_mode := str(card.get("effect", "")) == "orbit_add"
	var count := ((9 if level >= 6 else (6 if level >= 3 else int(value))) if blade_mode else int(value)+level/3) + (1 if run_state.equipped_relics.has("relic_orbit_foundry") else 0)
	var radius_bonus := 1.20 if run_state.equipped_relics.has("relic_orbit_foundry") else 1.0
	return {"hero_id":owner.id,"source_card":str(card.id),"level":level,"count":count,"damage":24.0+level*7.0,"radius":(160.0+level*10.0)*radius_bonus,"timer":0.1,"interval":maxf(0.40,0.80-level*0.045),"life":99999.0,"element":owner.element,"visual":"blade" if blade_mode else "spell","storm_timer":3.2}

func _restore_card_evolution_phases() -> void:
	# Purchase records stay untouched; only old snapshot execution phases migrate.
	if database == null: return
	for card: Dictionary in database.cards:
		var effect := str(card.get("effect",""))
		if effect not in ["orbit_add","orbit_spell_add","evolving_fireball"] or not run_state.buff_levels.has(str(card.id)):continue
		var purchases := int(run_state.buff_levels[str(card.id)])
		if purchases <= 0:continue
		var level := _card_evolution_level(card,purchases)
		if effect == "evolving_fireball":
			fireball_level=level
			continue
		for index in orbitals.size():
			var saved: Dictionary=orbitals[index]
			if str(saved.get("source_card",""))!=str(card.id) or int(saved.get("level",1))==level:continue
			var owner_id := int(saved.get("hero_id",-1))
			if owner_id<0 or owner_id>=heroes.size():continue
			var restored := _orbital_card_state(heroes[owner_id],card,level,float(card.get("value",0)))
			for key: String in ["timer","age","phase","storm_timer","life","element"]:
				if saved.has(key):restored[key]=saved[key]
			# Preserve additional cosmetic/motion state, replacing canonical combat fields.
			saved.merge(restored,true)

func apply_v2_card_effect(card: Dictionary, target_hero_id: int = -1) -> void:
	if str(card.get("effect", "")) == "card_bundle":
		for component: Dictionary in card.get("components", []):
			var part := component.duplicate(true)
			part.target = card.get("target", "global")
			apply_v2_card_effect(part, target_hero_id)
		return
	var targets: Array[Dictionary] = []
	if card.get("target", "global") == "character":
		if target_hero_id >= 0 and target_hero_id < heroes.size():
			targets.append(heroes[target_hero_id])
		else:
			for hero: Dictionary in heroes:
				if hero.get("character_id", "") == card.get("character_id", ""):
					targets.append(hero)
	else:
		targets.assign(heroes)
	var value: float = float(card.get("value", 0.0)) if card.get("value", 0.0) is float or card.get("value", 0.0) is int else 0.0
	match str(card.get("effect", "")):
		"assign_traveler_element":
			for hero: Dictionary in heroes:
				if str(hero.get("character_id", "")) == "traveler":
					hero.element = str(card.value)
					events.append({"kind": "element_attuned", "pos": hero.pos, "value": str(card.value)})
					break
		"dual_element_mythic":
			if not heroes.is_empty() and heroes[0].get("character_id", "") == "traveler":
				heroes[0].secondary_element = run_state.traveler_secondary_element
				heroes[0].damage += heroes[0].base_damage * 0.30
				events.append({"kind": "element_attuned", "pos": heroes[0].pos, "value": run_state.traveler_secondary_element})
		"luck_add":
			pass
		"grant_relic":
			_apply_relic(str(card.get("value", "")))
		"orbit_add", "orbit_spell_add":
			var owner := targets[0] if not targets.is_empty() else (heroes[0] if not heroes.is_empty() else {})
			if not owner.is_empty():
				var card_id := str(card.id)
				CombatCardEffects.apply_to_hero(owner, str(card.effect))
				var level := _card_evolution_level(card, int(owner.get("card_levels",{}).get(str(card.effect),1)))
				var state := _orbital_card_state(owner,card,level,value)
				var existing_index := -1
				for index in orbitals.size():
					if int(orbitals[index].get("hero_id",-1)) == int(owner.id) and str(orbitals[index].get("source_card","")) == card_id:
						existing_index = index
						break
				if existing_index >= 0:
					state.phase = float(orbitals[existing_index].get("phase",0.0))
					state.age = float(orbitals[existing_index].get("age",0.0))
					state.timer = float(orbitals[existing_index].get("timer",0.1))
					state.storm_timer = float(orbitals[existing_index].get("storm_timer",3.2))
					orbitals[existing_index] = state
				else:
					orbitals.append(state)
		"evolving_fireball":
			fireball_level = maxi(fireball_level, _card_evolution_level(card,int(run_state.buff_levels.get(str(card.id),1))))
		"mythic_projectile_storm":
			for hero in targets:
				hero.projectile_count = int(hero.get("projectile_count", 1)) + 1
				hero.rate += hero.base_rate * 0.24
				hero.pierce = int(hero.get("pierce", 0)) + 1
		"mythic_world_breaker":
			for hero in targets:
				hero.damage += hero.base_damage * 1.50
				hero.blast_radius = float(hero.get("blast_radius", 0.0)) + 180.0
				hero.chain_count = int(hero.get("chain_count", 0)) + 6
		"mythic_eternal_support":
			if not supports.has("support_finale"):
				supports["support_finale"] = {"timer": 0.35, "interval": 1.8, "power": 220.0, "radius": 9999.0, "stacks": 1}
			else:
				var mythic_support: Dictionary = supports["support_finale"]
				mythic_support.stacks = int(mythic_support.stacks) + 3
				mythic_support.power = float(mythic_support.power) + 220.0
				mythic_support.interval = minf(float(mythic_support.interval), 1.8)
		"attack_multiplier", "squad_attack_multiplier":
			for hero in targets: hero.damage += hero.base_damage * value
		"health_multiplier", "squad_health_multiplier":
			for hero in targets:
				var increase: float = hero.base_hp * value
				hero.max_hp += increase
				hero.hp += increase
		"attack_rate_multiplier", "squad_rate_multiplier":
			for hero in targets: hero.rate += hero.base_rate * value
		"opening_strike", "third_strike", "counter_ready", "distant_strike", "desperate_guard", "attack_mend":
			for hero in targets:
				var passive_levels: Dictionary = hero.get("card_levels", {})
				passive_levels[str(card.effect)] = float(passive_levels.get(str(card.effect), 0.0)) + value
				hero.card_levels = passive_levels
		"lethal_tempo", "conqueror", "heartsteel", "warmogs_armor":
			for hero in targets: CombatCardEffects.apply_to_hero(hero, str(card.effect))
		"solo_leveling":
			pass
		"range_flat", "squad_range_flat":
			for hero in targets: hero.range += value
		"crit_flat", "squad_crit_flat":
			for hero in targets: hero.crit_chance = minf(0.85, float(hero.get("crit_chance", 0.0)) + value)
		"armor_flat", "squad_armor_flat":
			for hero in targets: hero.armor += value
		"move_speed_flat":
			for hero in targets: hero.speed += value
		"special_upgrade":
			for hero in targets:
				match str(hero.get("character_id", "")):
					"hero_02": hero.projectile_count = int(hero.projectile_count) + 1
					"hero_03": hero.heal_power = float(hero.heal_power) + 18.0
					"hero_04": hero.chain_count = int(hero.chain_count) + 2
					"hero_05":
						hero.slow = true
						hero.blast_radius = maxf(float(hero.blast_radius), 72.0)
					"hero_06": hero.pierce = int(hero.pierce) + 2
					"hero_07":
						hero.cleave = true
						hero.armor += 28.0
					"hero_08": hero.personal_heal_interval = maxf(0.65, float(hero.personal_heal_interval) * 0.72)
					_:
						hero.cleave = true
						hero.cleave_ratio = maxf(float(hero.get("cleave_ratio", 0.5)), 0.75)
		"signature_upgrade":
			for hero in targets:
				match str(hero.get("character_id", "")):
					"hero_02":
						hero.projectile_count = int(hero.projectile_count) + 2
						hero.blast_radius = maxf(float(hero.blast_radius), 82.0)
					"hero_03":
						hero.echo_ratio = maxf(float(hero.echo_ratio), 0.48)
						hero.heal_power = float(hero.heal_power) + 26.0
					"hero_04":
						hero.chain_count = int(hero.chain_count) + 4
						hero.rate += hero.base_rate * 0.28
					"hero_05":
						hero.blast_radius = maxf(float(hero.blast_radius), 125.0)
						hero.damage += hero.base_damage * 0.42
					"hero_06":
						hero.projectile_count = int(hero.projectile_count) + 1
						hero.pierce = int(hero.pierce) + 4
					"hero_07":
						hero.cleave = true
						hero.cleave_ratio = 1.0
						hero.max_hp += hero.base_hp * 0.55
						hero.hp += hero.base_hp * 0.55
					"hero_08":
						hero.heal_power = float(hero.heal_power) + 48.0
						hero.personal_heal_interval = maxf(0.55, float(hero.personal_heal_interval) * 0.62)
					_:
						hero.damage += hero.base_damage * 0.35
						hero.rate += hero.base_rate * 0.20
		"squad_chain":
			for hero in targets: hero.chain_count = int(hero.get("chain_count", 0)) + maxi(1, int(value))
		"last_stand":
			pass
		"projectile_count_add":
			for hero in targets: hero.projectile_count = int(hero.get("projectile_count", 1)) + int(value)
		"pierce_add":
			for hero in targets: hero.pierce = int(hero.get("pierce", 0)) + int(value)
		"chain_add":
			for hero in targets: hero.chain_count = int(hero.get("chain_count", 0)) + int(value)
		"blast_add":
			for hero in targets: hero.blast_radius = float(hero.get("blast_radius", 0.0)) + value
		"echo_add":
			for hero in targets: hero.echo_ratio = float(hero.get("echo_ratio", 0.0)) + value
		"skill_power_add": skill_power_bonus += value
		"skill_cooldown_add": skill_cooldown_reduction = minf(0.65, skill_cooldown_reduction + value)
		"skill_area_add": skill_area_bonus += value
		"skill_duration_add": skill_duration_bonus += value
		"energy_gain_add": energy_gain_bonus += value
		"reaction_damage_add": reaction_damage_bonus += value
		"reaction_radius_add": reaction_radius_bonus += value
		"deploy_reinforcement":
			_add_reinforcement(str(card.get("value", "")))
		"support_barrage", "support_crossfire", "support_heal", "support_finale":
			var support_id: String = str(card.effect)
			if not supports.has(support_id):
				supports[support_id] = {"timer": float(card.get("interval", 8.0)) if support_id == "support_crossfire" else minf(2.0, float(card.get("interval", 8.0))), "interval": float(card.get("interval", 8.0)), "power": value, "radius": float(card.get("radius", 100.0)), "stacks": 1}
			else:
				var support: Dictionary = supports[support_id]
				support.stacks = int(support.stacks) + 1
				support.power = float(support.power) + value * 0.65
				support.radius = float(support.radius) + float(card.get("radius", 20.0)) * 0.18
				support.interval = maxf(2.5, float(support.interval) * 0.88)
			if float(card.get("support_interval_cap",0.0))>0.0:
				supports[support_id].interval=minf(float(supports[support_id].interval),maxf(2.5,float(card.support_interval_cap)))
		"execute_threshold_add": execute_threshold = minf(0.65, value) if execute_threshold <= 0.0 else minf(0.65, execute_threshold + value)
		"death_burst_add": death_burst_ratio += value
		"elite_damage_add": elite_damage_bonus += value
		"kill_frenzy_add": kill_frenzy_step += value
		"crystal_health_flat":
			base_max_hp += int(value)
			base_hp += int(value)
		"crystal_heal": base_hp = mini(base_max_hp, base_hp + int(value))
	battle_devices.sync_modifiers(self)
	_refresh_tag_synergies()
	_clamp_combat_card_stats()

func _clamp_hero_attack_rate(hero: Dictionary) -> void:
	var maximum := minf(5.0,float(hero.base_rate)*3.0)
	var excess := maxf(0.0,float(hero.rate)-maximum)
	if excess>0.0:
		# The decay ledger must contain only temporary rate actually retained.
		hero.tempo_bonus=maxf(0.0,float(hero.get("tempo_bonus",0.0))-excess/maxf(.1,float(hero.base_rate)))
	hero.rate=clampf(float(hero.rate),.1,maximum)

func _clamp_combat_card_stats() -> void:
	# Runtime compatibility guard for old builds; never rewrite the player's save.
	for hero: Dictionary in heroes:
		hero.frenzy_bonus=clampf(float(hero.get("frenzy_bonus",0.0)),0.0,.30)
		hero.projectile_count=clampi(int(hero.get("projectile_count",1)),1,5)
		hero.pierce=clampi(int(hero.get("pierce",0)),0,3)
		hero.chain_count=clampi(int(hero.get("chain_count",0)),0,3)
		hero.blast_radius=clampf(float(hero.get("blast_radius",0)),0,140)
		hero.echo_ratio=clampf(float(hero.get("echo_ratio",0)),0,.45)
		_clamp_hero_attack_rate(hero)
		hero.armor=clampf(float(hero.armor),0,240)
		hero.range=clampf(float(hero.range),40,600)
		hero.speed=clampf(float(hero.speed),20,260)
	skill_cooldown_reduction=clampf(skill_cooldown_reduction,0,.40)
	skill_area_bonus=clampf(skill_area_bonus,0,.65)
	skill_duration_bonus=clampf(skill_duration_bonus,0,.80)
	energy_gain_bonus=clampf(energy_gain_bonus,0,.40)
	reaction_damage_bonus=clampf(reaction_damage_bonus,0,1.0)
	reaction_radius_bonus=clampf(reaction_radius_bonus,0,100)
	execute_threshold=clampf(execute_threshold,0,.18)
	death_burst_ratio=clampf(death_burst_ratio,0,.12)
	elite_damage_bonus=clampf(elite_damage_bonus,0,.75)
	fireball_level=clampi(fireball_level,0,9)
	for orbital: Dictionary in orbitals:
		orbital.count=clampi(int(orbital.count),1,10 if run_state.equipped_relics.has("relic_orbit_foundry") and not str(orbital.get("source_card","")).is_empty() else 9)
		orbital.interval=maxf(.30,float(orbital.interval))
	for support: Dictionary in supports.values():
		support.stacks=clampi(int(support.stacks),1,3)
		support.power=clampf(float(support.power),0.0,300.0)
		support.interval=maxf(2.5,float(support.interval))
	attack_geometry_cache.clear()

func _apply_relic(relic_id: String) -> void:
	match relic_id:
		"relic_glass_cannon":
			for hero: Dictionary in heroes: hero.damage *= 1.35
		"relic_elemental_prism": reaction_damage_bonus += 0.30
		"relic_orbit_foundry":
			for orbital: Dictionary in orbitals:
				if str(orbital.get("source_card","")).is_empty() or str(orbital.get("visual","")) not in ["blade","spell"]: continue
				orbital.count=mini(10,int(orbital.count)+1)
				orbital.radius=float(orbital.radius)*1.20
	events.append({"kind":"relic_awaken","pos":heroes[0].pos if not heroes.is_empty() else Vector2.ZERO,"value":relic_id})

func export_build_record() -> Dictionary:
	var stats: Array[Dictionary] = []
	for hero: Dictionary in heroes:
		stats.append({"id":hero.character_id,"name":hero.name,"damage":roundi(float(hero.get("damage_done",0.0))),"attacks":int(hero.get("shots",0)),"skills":int(hero.get("skill_uses",0)),"ultimates":int(hero.get("ultimate_uses",0)),"max_energy":roundi(float(hero.get("max_energy_seen",0.0)))})
	var record: Dictionary = run_state.export_build()
	record["elapsed"] = elapsed
	record["kills"] = kills
	record["boss_kills"] = boss_kills
	record["crystal_level"] = run_state.crystal_level
	record["wave"] = wave
	record["luck"] = run_state.luck
	record["dodges"] = dodges
	var highest_stack := 0
	for level: Variant in run_state.buff_levels.values():
		highest_stack = maxi(highest_stack, int(level))
	record["highest_stack"] = highest_stack
	record["characters"] = stats
	return record

func _evolution_tick(dt: float) -> void:
	if fireball_level <= 0 or state != "running" or enemies.is_empty():
		return
	meteor_timer -= dt
	if meteor_timer > 0.0:
		return
	meteor_timer += maxf(3.8, 6.0 - fireball_level * 0.18)
	var target: Dictionary = enemies[0]
	for enemy: Dictionary in enemies:
		if enemy.hp > target.hp:
			target = enemy
	var impact_count := 3 if fireball_level >= 3 else 1
	for index in impact_count:
		var offset := Vector2((index - (impact_count - 1) * 0.5) * 85.0, (index % 2) * 32.0)
		var landing: Vector2 = _clamp_ability_target(Vector2(target.pos) + offset)
		var damage := ((100.0 + fireball_level * 12.0) if fireball_level >= 9 else (54.0 + fireball_level * 12.0))*SUPPORT_DAMAGE_SCALE * CardSynergies.team_multiplier(self, "skyfire", 1.20)
		var delay := 1.45 + index * 0.35
		pending_impacts.append({"kind": "fireball_support", "life": delay, "target_pos": landing, "damage": damage, "radius": (160.0 if fireball_level>=6 else 120.0) * CardSynergies.team_multiplier(self, "skyfire", 1.15), "level": fireball_level})
		events.append({"kind": "fireball_fall", "pos": landing, "radius": (160.0 if fireball_level>=6 else 120.0) * CardSynergies.team_multiplier(self, "skyfire", 1.15), "duration": delay})

func _rebuild_endless_blocker_index() -> void:
	endless_blocker_bins.clear();endless_blocker_index_ready=false
	if not endless_mode:return
	for feature:Dictionary in terrain_features:
		if not _feature_blocks(feature):continue
		var r:=_feature_collision_rect(feature)
		for cell in feature.get("grid_cells", []):
			r = r.merge(Rect2(cell))
		for x in range(floori(r.position.x/256),floori(r.end.x/256)+1):
			for y in range(floori(r.position.y/256),floori(r.end.y/256)+1):
				var key:=Vector2i(x,y)
				if not endless_blocker_bins.has(key):endless_blocker_bins[key]=[]
				endless_blocker_bins[key].append(feature)
	endless_blocker_index_ready=true

func _blocker_candidates(area:Rect2) -> Array:
	if not endless_mode or not endless_blocker_index_ready:return terrain_features
	# Long rays are cheaper against the small complete obstacle list.
	if area.size.x>512 or area.size.y>512:return terrain_features
	var first:=Vector2i(floori(area.position.x/256),floori(area.position.y/256))
	var last:=Vector2i(floori(area.end.x/256),floori(area.end.y/256))
	if first==last:return endless_blocker_bins.get(first,[])
	var result:Array=[]
	for x in range(first.x,last.x+1):
		for y in range(first.y,last.y+1):
			for feature:Dictionary in endless_blocker_bins.get(Vector2i(x,y),[]):
				if not result.has(feature):
					result.append(feature)
	return result
