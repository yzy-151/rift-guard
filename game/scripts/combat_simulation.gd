extends RefCounted
## Fixed-step gameplay, independent of scenes and visual effects.
const Rewards = preload("res://scripts/reward_book.gd")
const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CrystalProgression = preload("res://scripts/rewards/crystal_progression.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
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
const ENDLESS_ARENA = Rect2(80, 80, 2400, 1280)
const LANES = [270.0, 360.0, 450.0]
const PROJECTILE_SPEED: float = 720.0
const AURA_DURATION: float = 3.0
const REACTION_COOLDOWN: float = 0.5
const HEAL_RANGE: float = 310.0
const HEAL_AMOUNT: float = 22.0
const ENDLESS_BOSS_IDS := ["boss_01", "boss_02", "boss_03", "boss_04", "boss_05", "boss_06"]
const ENDLESS_ACTIVE_CAP_EARLY := 108
const ENDLESS_ACTIVE_CAP_LATE := 140
const ENDLESS_LOW_TIER_CAP_EARLY := 42
const ENDLESS_LOW_TIER_CAP_LATE := 24
const ENDLESS_HUT_CAP := 2
const ENDLESS_LOW_TIER_IDS := ["grunt", "runner", "slime_pyro", "slime_electro", "slime_anemo", "slime_hydro", "slime_cryo"]

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
var events: Array[Dictionary] = []
var base_hp: int = 100
var base_max_hp: int = 100
var wave: int = 0
var kills: int = 0
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
var crystal_shield: float = 0.0
var kill_streak: int = 0
var best_streak: int = 0
var kill_streak_timer: float = 0.0
var reward_cooldown: float = 0.0
var endless_mode: bool = false
var active_view_rect: Rect2 = ENDLESS_ARENA
var endless_spawn_timer: float = 0.0
var endless_next_boss_at: float = 90.0
var endless_boss_index: int = 0
var terrain_features: Array[Dictionary] = []
var formation_mode: String = "hold"
var follow_history: Array[Dictionary] = []
var follow_sample_timer := 0.0
var pending_impacts: Array[Dictionary] = []
var orbitals: Array[Dictionary] = []
var tag_synergy_levels: Dictionary = {}
var dodges: int = 0
var damage_source_override: int = -1
var fireball_level: int = 0
var meteor_timer: float = 4.0
var performance_budget = PerformanceBudget.new()
var culled_spawns: int = 0
var combat_contract: Dictionary = {}
var contract_completed: bool = false
var contract_reward_text: String = ""
var recent_spawn_kinds: Array[String] = []
var enemy_support_scan_timer: float = 0.0

func _init(seed_value: int = -1, enable_v2: bool = false) -> void:
	v2_mode = enable_v2
	if v2_mode:
		reset_stage("stage_01", ["traveler"], seed_value)
	else:
		reset(seed_value)

func reset(seed_value: int = -1) -> void:
	endless_mode = false
	endless_spawn_timer = 0.0
	endless_next_boss_at = 90.0
	endless_boss_index = 0
	active_view_rect = ENDLESS_ARENA
	terrain_features.clear()
	formation_mode = "hold"
	follow_history.clear()
	follow_sample_timer = 0.0
	run_seed = seed_value if seed_value >= 0 else int(Time.get_ticks_usec() % 2147483647)
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
	base_hp = 100
	base_max_hp = 100
	wave = 0
	kills = 0
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
	fireball_level = 0
	meteor_timer = 4.0
	performance_budget = PerformanceBudget.new()
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
	crystal_shield = 0.0
	kill_streak = 0
	best_streak = 0
	kill_streak_timer = 0.0
	reward_cooldown = 0.0
	heroes.clear()
	enemies.clear()
	enemy_lookup.clear()
	projectiles.clear()
	next_projectile_id = 0
	events.clear()
	for i in Catalog.HEROES.size():
		var h: Dictionary = Catalog.HEROES[i].duplicate(true)
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": false, "splash": false, "slow": false})
		heroes.append(h)

func reset_stage(stage_id: String, squad_ids: Array[String] = [], seed_value: int = -1) -> void:
	v2_mode = true
	current_stage_id = stage_id
	endless_mode = stage_id == "stage_endless"
	endless_spawn_timer = 0.15
	endless_next_boss_at = 90.0
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
	var stage_definition: Dictionary = database.stages[stage_id]
	crystal = CrystalProgression.new(stage_definition.xp_thresholds)
	card_pool = CardPool.new(database.cards, seed_value if seed_value >= 0 else int(Time.get_ticks_usec() % 2147483647))
	card_pool.levels = run_state.buff_levels
	rewards = card_pool
	stage_runtime = StageRuntime.new(stage_definition)
	_load_terrain(stage_definition)
	formation_mode = "follow" if endless_mode else "hold"
	follow_history.clear()
	follow_sample_timer = 0.0
	run_seed = seed_value if seed_value >= 0 else int(Time.get_ticks_usec() % 2147483647)
	team_xp = 0
	team_level = 1
	state = "ready"
	previous_state = "running"
	base_hp = 100
	base_max_hp = 100
	wave = 0
	kills = 0
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
	fireball_level = 0
	meteor_timer = 4.0
	performance_budget = PerformanceBudget.new()
	culled_spawns = 0
	combat_contract = {}
	contract_completed = false
	contract_reward_text = ""
	recent_spawn_kinds.clear()
	enemy_support_scan_timer = 0.0
	combat_contract = database.combat_contracts.get(stage_id, {}).duplicate(true)
	next_construct_id = 0
	reaction_damage_bonus = 0.0
	reaction_radius_bonus = 0.0
	skill_power_bonus = 0.0
	skill_cooldown_reduction = 0.0
	skill_area_bonus = 0.0
	skill_duration_bonus = 0.0
	crystal_shield = 0.0
	kill_streak = 0
	best_streak = 0
	kill_streak_timer = 0.0
	reward_cooldown = 0.0
	heroes.clear()
	enemies.clear()
	enemy_lookup.clear()
	projectiles.clear()
	next_projectile_id = 0
	events.clear()
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
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": id == "traveler", "cleave_ratio": 0.90, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0, "deployed": endless_mode, "energy": 0.0, "max_energy": float(source.get("ultimate", {}).get("energy_cost", 100.0)), "skill_cooldown": 0.0, "ultimate_cooldown": 0.0, "ultimate_cooldown_max": 0.0, "active_skill": source.get("active_skill", {}).duplicate(true), "ultimate": source.get("ultimate", {}).duplicate(true), "passive": source.get("passive", {}).duplicate(true), "animation_state":"idle", "status_timer":0.0, "damage_reduction":0.0, "damage_done": 0.0, "skill_uses": 0, "ultimate_uses": 0, "max_energy_seen": 0.0, "revived": false, "follow_independent": false})
		_configure_character_identity(h)
		heroes.append(h)
	_apply_campaign_progression()
	_apply_team_resonances()
	_reset_follow_history()

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
			hero.attack_style = "frost_shard"
			hero.damage *= 1.18
			hero.pierce = maxi(1, int(hero.pierce))
			hero.slow = true
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
			hero.attack_style = "quantum_gate"
			hero.projectile_count = maxi(2, int(hero.projectile_count))
			hero.chain_count = maxi(2, int(hero.chain_count))
		"hero_11":
			hero.attack_style = "mon3tr"
			hero.block = maxi(2, int(hero.block))
			hero.damage_reduction = maxf(0.12, float(hero.damage_reduction))
			hero.splash = true
			hero.blast_radius = maxf(72.0, float(hero.blast_radius))
		"hero_12":
			hero.attack_style = "ether_shot"
			hero.rate *= 1.25
			hero.chain_count = maxi(3, int(hero.chain_count))
			hero.crit_chance = maxf(0.15, float(hero.crit_chance))
	hero.base_damage = hero.damage
	hero.base_hp = hero.max_hp
	hero.base_rate = hero.rate

func _add_reinforcement(character_id: String) -> bool:
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
	hero.merge({"id": i, "max_hp": hero.hp, "target": hero.pos, "moving": false, "facing": 1.0, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": hero.damage, "base_hp": hero.hp, "base_rate": hero.rate, "cleave": false, "cleave_ratio": 0.45, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0, "deployed": endless_mode, "energy": 0.0, "max_energy": float(source.get("ultimate", {}).get("energy_cost", 100.0)), "skill_cooldown": 0.0, "ultimate_cooldown": 0.0, "ultimate_cooldown_max": 0.0, "active_skill": source.get("active_skill", {}).duplicate(true), "ultimate": source.get("ultimate", {}).duplicate(true), "passive": source.get("passive", {}).duplicate(true), "animation_state":"idle", "status_timer":0.0, "damage_reduction":0.0, "damage_done": 0.0, "skill_uses": 0, "ultimate_uses": 0, "max_energy_seen": 0.0, "revived": false, "follow_independent": false})
	_configure_character_identity(hero)
	heroes.append(hero)
	events.append({"kind": "reinforcement", "pos": hero.pos, "value": character_id})
	return true

func restart_current_stage() -> void:
	if v2_mode:
		reset_stage(current_stage_id, run_state.squad, run_seed)
	else:
		reset(run_seed)

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

func choose_reward(index: int) -> bool:
	if state != "reward" or index < 0 or index >= rewards.offered.size():
		return false
	var picked: Dictionary = rewards.offered[index]
	var picked_name: String = str(picked.get("name", "强化"))
	var picked_rarity: String = str(picked.get("rarity", "common"))
	if not rewards.take(index, self):
		return false
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

func toggle_pause() -> void:
	if state == "paused":
		state = previous_state
	elif state in ["running", "between"]:
		previous_state = state
		state = "paused"

func command_move(hero_id: int, point: Vector2, show_feedback: bool = true) -> void:
	if state not in ["running", "between", "stage_exit"] or hero_id < 0 or hero_id >= heroes.size():
		return
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0 or not bool(hero.get("deployed", true)):
		return
	if endless_mode:
		if hero_id == 0:
			formation_mode = "follow"
			for index in range(1, heroes.size()):
				heroes[index].follow_independent = false
		else:
			hero.follow_independent = true
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

func _load_terrain(stage_definition: Dictionary) -> void:
	terrain_features.clear()
	var claimed_grid_cells := {}
	for value: Variant in stage_definition.get("terrain", []):
		if not value is Dictionary:
			continue
		var feature: Dictionary = value.duplicate(true)
		var raw_rect: Array = feature.get("rect", [])
		if raw_rect.size() < 4:
			continue
		feature.area = Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		var feature_type := str(feature.get("type", ""))
		if current_stage_id != "stage_01" and not endless_mode and feature_type in ["blocked", "trap", "high_ground", "low_ground", "attack_ground"]:
			feature.grid_cells = _claim_grid_cells(_grid_cells_for_area(feature.area), claimed_grid_cells, feature.area.get_center())
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

func _claim_grid_cells(candidates: Array[Rect2], claimed: Dictionary, center: Vector2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	for cell: Rect2 in candidates:
		var key := _grid_cell_key(cell)
		if claimed.has(key):
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
		if not claimed.has(key):
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
	return 1.0 + float(feature.get("attack_bonus", 0.30)) if not feature.is_empty() else 1.0

func terrain_movement_scale(point: Vector2) -> float:
	var feature := terrain_feature_at(point, "low_ground")
	var scale := float(feature.get("speed_scale", 0.72)) if not feature.is_empty() else 1.0
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
	for feature: Dictionary in terrain_features:
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
	for feature: Dictionary in terrain_features:
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
	if _terrain_blocks(hero.pos, 17.0):
		hero.pos = _nearest_walkable_point(hero.pos, 17.0)
		hero.target = hero.pos
	else:
		hero.target = _nearest_walkable_point(hero.target, 17.0)
	var distance := float(hero.speed) * terrain_movement_scale(hero.pos) * dt
	hero.pos = _move_with_terrain(hero.pos, hero.target, distance, 17.0)

func _reset_follow_history() -> void:
	follow_history.clear()
	follow_sample_timer = 0.0
	if heroes.is_empty():
		return
	var leader_pos: Vector2 = heroes[0].pos
	for index in 18:
		follow_history.append({"time": elapsed - 1.7 + index * 0.1, "pos": leader_pos})

func _update_follow_targets(dt: float) -> void:
	if formation_mode != "follow" or heroes.is_empty():
		return
	follow_sample_timer -= dt
	if follow_sample_timer <= 0.0:
		follow_history.append({"time": elapsed, "pos": Vector2(heroes[0].pos)})
		follow_sample_timer += 0.06
	while follow_history.size() > 2 and float(follow_history[0].time) < elapsed - 2.8:
		follow_history.pop_front()
	for i in range(1, heroes.size()):
		if bool(heroes[i].get("follow_independent", false)):
			continue
		var delayed_time := elapsed - (0.24 + float(i - 1) * 0.16)
		var delayed_pos: Vector2 = follow_history[0].pos if not follow_history.is_empty() else heroes[0].pos
		for sample: Dictionary in follow_history:
			if float(sample.time) > delayed_time:
				break
			delayed_pos = sample.pos
		var follow_angle := PI + (i - 1) * 1.15
		heroes[i].target = _resolve_walkable_target(delayed_pos + Vector2.from_angle(follow_angle) * (82.0 + i * 12.0))

func damage_terrain_shortcuts(center: Vector2, radius: float, damage: float) -> int:
	var broken := 0
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) not in ["shortcut", "door"] or float(feature.get("hp", 0.0)) <= 0.0:
			continue
		if feature.area.get_center().distance_to(center) > radius:
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
			for enemy: Dictionary in enemies:
				if enemy.hp > 0.0 and feature.area.has_point(enemy.pos):
					enemy.aura = str(feature.get("element", "anemo")); enemy.aura_timer = 3.0
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
					damage_hero(int(hero.id), float(feature.get("hero_power", 14.0))); hit_count += 1
		feature.timer = float(feature.get("interval", 3.5))
		if hit_count > 0:
			events.append({"kind":"trap_pulse" if kind == "trap" else "mechanism_pulse","pos":feature.area.get_center(),"value":hit_count})

func spawn_enemy(point: Vector2, kind: String = "grunt") -> Dictionary:
	var enemy: Dictionary = Catalog.ENEMIES[kind].duplicate(true)
	if v2_mode and database != null and database.enemy_families.has(kind):
		var family_definition: Dictionary = database.enemy_families[kind]
		enemy.merge({"family":family_definition.get("family", "rift"), "variant":family_definition.get("variant", kind), "behavior":family_definition.get("behavior", "pressure_advance"), "motion":family_definition.get("motion", "elastic_hop"), "visual_family":family_definition.get("visual", kind)}, true)
	if v2_mode and not bool(enemy.get("flying", false)):
		point = _nearest_walkable_point(point, maxf(12.0, float(enemy.get("size", 28.0)) * 0.34))
	enemy.hp *= 1.40
	enemy.hp *= 1.0 + maxf(0.0, wave - 1) * 0.10
	if v2_mode and stage_runtime != null:
		enemy.hp *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		if kind.begins_with("boss_") and not endless_mode:
			enemy.hp *= float(stage_runtime.definition.get("boss_health_multiplier", 1.0))
		enemy.damage *= float(stage_runtime.definition.get("enemy_damage_multiplier", 1.0))
		enemy.speed *= float(stage_runtime.definition.get("enemy_speed_multiplier", 1.0))
		enemy.leak = maxi(1, roundi(float(enemy.leak) * float(stage_runtime.definition.get("enemy_leak_multiplier", 1.0))))
	next_id += 1
	var shield: float = float(enemy.get("shield", 0.0))
	if v2_mode and stage_runtime != null:
		shield *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		if kind.begins_with("boss_") and not endless_mode:
			shield *= float(stage_runtime.definition.get("boss_health_multiplier", 1.0))
	var xp_values := {"grunt": 10, "runner": 8, "armored": 22, "flyer": 12, "ranged": 15, "buffer": 24, "shielded": 38, "charger": 20, "healer": 30, "splitter": 42, "warder": 32, "slime_pyro": 11, "slime_electro": 11, "slime_anemo": 12, "slime_hydro": 14, "slime_cryo": 16, "boss_01": 240, "boss_02": 280, "boss_03": 260, "boss_04": 320, "boss_05": 290, "boss_06": 310}
	var first_special: float = float(enemy.get("boss_pulse", enemy.get("spawn_interval", enemy.get("heal_interval", enemy.get("ward_interval", 0.0)))))
	enemy.merge({"id": next_id, "kind": kind, "pos": point, "facing": -1.0, "max_hp": enemy.hp, "flash": 0.0, "attack_timer": 0.7, "blocked_by": -1, "aura": "", "aura_timer": 0.0, "reaction_timer": 0.0, "slow_timer": 0.0, "frozen_timer": 0.0, "haste_timer": 0.0, "shield": shield, "max_shield": shield, "special_timer": first_special, "split_done": false, "boss_phase": 1, "boss_cast_index": 0, "special_move": "pulse", "summons_done": 0, "route_points": [], "route_index": 0, "route_id": "", "xp": int(xp_values.get(kind, 10)), "attack_pending": false, "warning_timer": 0.0, "warning_pos": point, "warning_radius": 58.0, "special_pending": false, "special_warning": 0.0, "affixes": [], "affix_timer": 3.5, "nav_probe_timer": 0.0, "nav_clear": false, "lod_accumulator": fposmod(float(next_id) * 0.037, 0.20)})
	_apply_enemy_affix(enemy)
	enemies.append(enemy)
	enemy_lookup[int(enemy.id)] = enemy
	return enemy

func find_enemy(id: int) -> Dictionary:
	var enemy: Dictionary = enemy_lookup.get(id, {})
	return enemy if not enemy.is_empty() and float(enemy.get("hp", 0.0)) > 0.0 else {}

func tick(dt: float) -> void:
	if reward_cooldown > 0.0:
		reward_cooldown = maxf(0.0, reward_cooldown - dt)
	if v2_mode and state == "running" and run_state.pending_level_ups > 0 and reward_cooldown <= 0.0:
		rewards.draw(self)
		state = "reward"
	if kill_streak_timer > 0.0:
		kill_streak_timer = maxf(0.0, kill_streak_timer - dt)
		if kill_streak_timer <= 0.0:
			kill_streak = 0
	performance_budget.sample(dt*1000.0,enemies.size(),projectiles.size())
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
		h.moving = h.hp > 0 and bool(h.get("deployed", true)) and h.pos.distance_to(h.target) > 0.5
		if float(h.get("status_timer",0.0)) <= 0.0: h.animation_state = "run" if h.moving else "idle"
		if h.moving:
			if absf(h.target.x - h.pos.x) > 1.0:
				h.facing = 1.0 if h.target.x > h.pos.x else -1.0
			_move_hero_with_terrain(h, dt)
		h.attack_timer = maxf(0.0, h.attack_timer - dt)
		h.heal_timer = maxf(0.0, h.heal_timer - dt)
	if state == "stage_exit":
		return
	if state == "between":
		wave_timer -= dt
		if wave_timer <= 0:
			begin_wave()
		return
	if endless_mode:
		_endless_spawn_tick(dt)
	elif v2_mode:
		_stage_spawn_tick(dt)
	else:
		_spawn_tick(dt)
	_skill_effect_tick(dt)
	_terrain_tick(dt)
	_enemy_tick(dt)
	var party_wiped := endless_mode and (heroes.is_empty() or heroes.all(func(hero: Dictionary) -> bool: return float(hero.get("hp", 0.0)) <= 0.0))
	if base_hp <= 0 or party_wiped:
		state = "lost"
		projectiles.clear()
		events.append({"kind": "lost"})
		return
	_hero_tick()
	_projectile_tick(dt)
	_support_tick(dt)
	_contract_tick()
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if v2_mode and not endless_mode:
		if stage_runtime.time_complete and stage_runtime.all_spawns_emitted and enemies.is_empty() and projectiles.is_empty():
			state = "won"
			events.append({"kind": "won"})
		return
	elif not v2_mode and spawn_remaining == 0 and enemies.is_empty() and projectiles.is_empty():
		if wave == Catalog.WAVES.size():
			state = "won"
			events.append({"kind": "won"})
		else:
			state = "reward"
			wave_timer = 0.0
			for h in heroes:
				h.hp = h.max_hp * 0.5 if h.hp <= 0 else minf(h.max_hp, h.hp + h.max_hp * regroup_ratio)
				h.blocked = 0
			rewards.draw(self)
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
			run_state.luck = clampf(run_state.luck + float(reward.get("value", 0.0)), 0.0, 0.75)
		"shield":
			crystal_shield = minf(999.0, crystal_shield + float(reward.get("value", 0.0)))
		"energy":
			for hero: Dictionary in heroes:
				hero.energy = minf(float(hero.get("max_energy", 100.0)), float(hero.get("energy", 0.0)) + float(reward.get("value", 0.0)))
		"heal":
			for hero: Dictionary in heroes:
				hero.hp = minf(float(hero.max_hp), float(hero.hp) + float(hero.max_hp) * float(reward.get("value", 0.0)))
	events.append({"kind":"contract_complete","pos":heroes[0].pos if not heroes.is_empty() else Vector2(640,360),"value":str(combat_contract.get("name","战术契约")),"reward":contract_reward_text})


func _endless_tier() -> int:
	return maxi(1, floori(elapsed / 45.0) + 1)

func _endless_active_cap() -> int:
	var progression := clampf(elapsed / 540.0, 0.0, 1.0)
	var cap := roundi(lerpf(ENDLESS_ACTIVE_CAP_EARLY, ENDLESS_ACTIVE_CAP_LATE, progression))
	if performance_budget.quality_scale <= 0.58:
		cap = mini(cap, 112)
	elif performance_budget.quality_scale < 1.0:
		cap = mini(cap, 126)
	return cap

func _endless_low_tier_cap() -> int:
	var progression := clampf(elapsed / 420.0, 0.0, 1.0)
	return roundi(lerpf(ENDLESS_LOW_TIER_CAP_EARLY, ENDLESS_LOW_TIER_CAP_LATE, progression))

func _endless_enemy_scales(tier: int) -> Dictionary:
	# Early enemies stay readable; late pressure comes from quality and stats
	# instead of an unbounded count of cheap units.
	return {
		"health": 0.78 + elapsed / 185.0 + pow(float(tier), 1.24) * 0.12,
		"damage": 0.76 + elapsed / 420.0 + float(tier) * 0.055,
		"speed": minf(1.34, 0.93 + float(tier) * 0.024),
		"xp": minf(2.25, 0.92 + float(tier) * 0.075),
	}

func _apply_endless_scaling(enemy: Dictionary, tier: int, strength: float = 1.0) -> void:
	var scales := _endless_enemy_scales(tier)
	var health_scale := lerpf(1.0, float(scales.health), strength)
	var damage_scale := lerpf(1.0, float(scales.damage), strength)
	enemy.hp *= health_scale
	enemy.max_hp = enemy.hp
	enemy.damage *= damage_scale
	enemy.speed *= lerpf(1.0, float(scales.speed), strength)
	enemy.xp = maxi(1, roundi(float(enemy.get("xp", 10)) * lerpf(1.0, float(scales.xp), strength)))
	enemy.endless_rank = tier

func _endless_spawn_tick(dt: float) -> void:
	_spawn_endless_boss_if_due()
	endless_spawn_timer -= dt
	var active_cap := _endless_active_cap()
	if endless_spawn_timer > 0.0 or enemies.size() >= active_cap:
		return
	var tier := _endless_tier()
	var build_levels := 0
	for level: Variant in run_state.buff_levels.values():
		build_levels += int(level)
	var pool := ["grunt", "grunt", "runner", "runner", "slime_pyro", "slime_electro"]
	if tier >= 2:
		pool.append_array(["flyer", "charger", "slime_anemo", "slime_hydro"])
	if tier >= 3:
		pool.append_array(["armored", "buffer", "charger", "slime_cryo", "splitter"])
	if tier >= 3 and build_levels >= 5:
		pool.append("ranged")
	if tier >= 6 and build_levels >= 14:
		pool.append_array(["ranged", "shielded", "healer", "splitter", "warder"])
	elif tier >= 5:
		pool.append_array(["shielded", "healer"])
	if tier >= 8:
		# Shift late waves toward fewer meaningful threats.
		pool.append_array(["armored", "charger", "shielded", "warder", "healer"])
	var low_tier_cap := _endless_low_tier_cap()
	var low_tier_count := _endless_kind_count(ENDLESS_LOW_TIER_IDS)
	var hut_count := _endless_kind_count(["splitter"])
	var available_slots := active_cap - enemies.size()
	var batch := mini(available_slots, mini(6, 2 + floori((tier - 1) / 2.0)))
	for i in batch:
		var side := (kills + next_id + i * 3) % 4
		var ratio := fposmod(sin(float(next_id + i * 19) * 12.9898) * 43758.5453, 1.0)
		var kind: String = pool[(next_id + i * 5 + tier) % pool.size()]
		if kind == "splitter" and hut_count >= ENDLESS_HUT_CAP:
			kind = _endless_quality_enemy(tier, i)
		if kind in ENDLESS_LOW_TIER_IDS and low_tier_count >= low_tier_cap:
			kind = _endless_quality_enemy(tier, i)
		kind = _balanced_spawn_kind(kind)
		var point := _endless_interior_spawn_point(side, ratio) if kind == "splitter" else _endless_edge_point(side, ratio)
		var enemy := spawn_enemy(point, kind)
		_apply_endless_scaling(enemy, tier)
		if kind == "splitter":
			hut_count += 1
		elif kind in ENDLESS_LOW_TIER_IDS:
			low_tier_count += 1
		if enemies.size() < 84 or kind not in ENDLESS_LOW_TIER_IDS:
			events.append({"kind": "route_spawn", "pos": point, "route_id": "edge_%d" % side, "flying": bool(enemy.get("flying", false))})
	endless_spawn_timer += maxf(0.38, 1.16 - elapsed * 0.0012)

func _endless_kind_count(kinds: Array) -> int:
	return enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")) in kinds).size()

func _endless_quality_enemy(tier: int, index: int) -> String:
	var quality_pool := ["armored", "charger", "buffer"]
	if tier >= 5:
		quality_pool.append_array(["shielded", "healer", "warder", "ranged"])
	return quality_pool[posmod(next_id + index * 3 + tier, quality_pool.size())]

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
	match posmod(side, 4):
		0: return Vector2(ENDLESS_ARENA.position.x, lerpf(ENDLESS_ARENA.position.y, ENDLESS_ARENA.end.y, ratio))
		1: return Vector2(ENDLESS_ARENA.end.x, lerpf(ENDLESS_ARENA.position.y, ENDLESS_ARENA.end.y, ratio))
		2: return Vector2(lerpf(ENDLESS_ARENA.position.x, ENDLESS_ARENA.end.x, ratio), ENDLESS_ARENA.position.y)
		_: return Vector2(lerpf(ENDLESS_ARENA.position.x, ENDLESS_ARENA.end.x, ratio), ENDLESS_ARENA.end.y)

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

func _spawn_endless_boss_if_due() -> void:
	while endless_mode and elapsed >= endless_next_boss_at:
		var active_bosses := enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")).begins_with("boss_")).size()
		if active_bosses >= 2:
			endless_next_boss_at = elapsed + 18.0
			return
		_make_room_for_endless_boss()
		var boss_id: String = ENDLESS_BOSS_IDS[endless_boss_index % ENDLESS_BOSS_IDS.size()]
		var cycle := floori(endless_boss_index / float(ENDLESS_BOSS_IDS.size()))
		var side := endless_boss_index % 4
		var boss := spawn_enemy(_endless_edge_point(side, 0.22 + fposmod(endless_boss_index * 0.31, 0.56)), boss_id)
		var boss_scale := 1.0 + elapsed / 360.0 + cycle * 0.55
		boss.hp *= boss_scale
		boss.max_hp = boss.hp
		boss.shield *= 1.0 + elapsed / 520.0 + cycle * 0.35
		boss.max_shield = boss.shield
		boss.damage *= 1.0 + elapsed / 520.0 + cycle * 0.22
		events.append({"kind": "boss_arrival", "pos": boss.pos, "value": str(boss.name), "enemy_id": boss.id})
		endless_boss_index += 1
		endless_next_boss_at += 105.0
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
	projectiles.clear()
	enemies.clear()
	enemy_lookup.clear()
	skill_effects.clear()
	geo_constructs.clear()
	pending_impacts.clear()
	orbitals.clear()
	tag_synergy_levels.clear()
	dodges = 0
	damage_source_override = -1
	fireball_level = 0
	meteor_timer = 4.0
	if not heroes.is_empty():
		heroes[0].target = heroes[0].pos

func _stage_spawn_tick(dt: float) -> void:
	for event: Dictionary in stage_runtime.tick(dt):
		if event.kind == "route_warning":
			events.append(event)
		elif event.kind == "spawn":
			wave = maxi(wave, int(event.get("wave", wave)))
			if performance_budget.allow_enemy(enemies.size()):
				spawn_on_route(str(event.enemy_id), str(event.route_id), int(event.get("sequence", 0)))
			else:
				culled_spawns += 1
		elif event.kind == "boss_wave":
			wave += 1
			var boss_id := str(event.enemy_id)
			var boss := spawn_on_route(boss_id, str(event.route_id))
			events.append({"kind": "wave", "value": wave})
			events.append({"kind": "boss_arrival", "pos": boss.pos, "value": str(boss.get("name", boss_id)), "enemy_id": boss.id})

func _balanced_spawn_kind(requested: String) -> String:
	if requested.begins_with("boss_"):
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
	var chosen := requested
	var active_same := enemies.filter(func(enemy: Dictionary) -> bool: return enemy.hp > 0.0 and str(enemy.get("kind", "")) == requested).size()
	var repeated := recent_spawn_kinds.size() >= 2 and recent_spawn_kinds[-1] == requested and recent_spawn_kinds[-2] == requested
	if (caps.has(requested) and active_same >= int(caps[requested])) or repeated:
		var fallback := ["grunt", "runner", "slime_pyro", "slime_electro", "armored", "slime_anemo"]
		fallback = fallback.filter(func(kind: String) -> bool: return kind != requested and not (recent_spawn_kinds.size() > 0 and kind == recent_spawn_kinds[-1]))
		chosen = fallback[posmod(next_id + enemies.size(), fallback.size())]
	recent_spawn_kinds.append(chosen)
	while recent_spawn_kinds.size() > 8:
		recent_spawn_kinds.pop_front()
	return chosen
func spawn_on_route(kind: String, route_id: String, sequence: int = 0) -> Dictionary:
	kind = _balanced_spawn_kind(kind)
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
		var area := Rect2(feature.area).grow(radius + 26.0)
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
		for candidate: Dictionary in enemies:
			candidate.erase("nav_waypoint")
			candidate.nav_timer = 0.0
func _enemy_tick(dt: float) -> void:
	enemy_support_scan_timer -= dt
	if enemy_support_scan_timer <= 0.0:
		enemy_support_scan_timer = 0.20
		var support_region := active_view_rect.grow(300.0) if endless_mode else MOVE_AREA.grow(500.0)
		for source: Dictionary in enemies:
			if source.hp <= 0 or source.get("kind", "") != "buffer" or not support_region.has_point(source.pos):
				continue
			var aura_radius := float(source.get("aura_radius", 0.0))
			var aura_radius_sq := aura_radius * aura_radius
			for ally: Dictionary in enemies:
				if ally.hp > 0 and ally.id != source.id and support_region.has_point(ally.pos) and ally.pos.distance_squared_to(source.pos) <= aura_radius_sq:
					ally.haste_timer = 0.25
	for e in enemies:
		if e.hp <= 0:
			continue
		e.flash = maxf(0, e.flash - dt)
		e.attack_timer = maxf(0, e.attack_timer - dt)
		e.aura_timer = maxf(0, e.aura_timer - dt)
		e.reaction_timer = maxf(0, e.reaction_timer - dt)
		e.slow_timer = maxf(0, e.slow_timer - dt)
		e.frozen_timer = maxf(0, float(e.get("frozen_timer", 0.0)) - dt)
		e.haste_timer = maxf(0, e.haste_timer - dt)
		e.special_timer = maxf(0, float(e.special_timer) - dt)
		e.spawn_pulse = maxf(0.0, float(e.get("spawn_pulse", 0.0)) - dt)
		e.affix_timer = maxf(0.0, float(e.get("affix_timer", 0.0)) - dt)
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
		if e.aura_timer <= 0:
			e.aura = ""
		var speed_scale: float = (0.0 if e.frozen_timer > 0.0 else (0.7 if e.slow_timer > 0 else 1.0)) * (1.35 if e.haste_timer > 0 else 1.0)
		if not bool(e.get("flying", false)):
			speed_scale *= terrain_movement_scale(e.pos)
		if e.get("kind", "") == "charger" and e.pos.x > 650.0 and e.frozen_timer <= 0.0:
			speed_scale *= float(e.get("charge_multiplier", 2.0))
		var route: Array = e.get("route_points", [])
		var route_index: int = int(e.get("route_index", 0))
		var destination: Vector2 = heroes[0].pos if endless_mode and not heroes.is_empty() else Vector2(100, e.pos.y)
		if not endless_mode and not route.is_empty() and route_index < route.size():
			destination = route[route_index]
		var navigation_radius := maxf(12.0, float(e.get("size", 28.0)) * 0.34)
		var route_destination := destination
		if not bool(e.get("flying", false)) and float(e.get("speed", 0.0)) > 0.0:
			destination = _enemy_navigation_target(e, destination, navigation_radius, movement_dt)
		if absf(destination.x - e.pos.x) > 1.0:
			e.facing = 1.0 if destination.x > e.pos.x else -1.0
		var move_distance := float(e.speed) * speed_scale * movement_dt
		var next_pos: Vector2 = _orthogonal_enemy_step(e.pos, destination, move_distance, navigation_radius, bool(e.get("flying", false)))
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
		if not endless_mode and e.pos.distance_to(route_destination) <= maxf(4.0, e.speed * speed_scale * dt + 1.0):
			e.pos = route_destination
			e.route_index = route_index + 1
			route_index += 1
			next_pos = e.pos
		var construct_victim: Dictionary = {}
		if not bool(e.get("flying", false)):
			for construct: Dictionary in geo_constructs:
				if construct.hp <= 0.0 or absf(e.pos.y - construct.pos.y) > 48.0:
					continue
				if next_pos.distance_to(construct.pos) <= 52.0:
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
		for h in heroes:
			if bool(e.get("flying", false)):
				break
			if h.hp <= 0 or not bool(h.get("deployed", false)) or (h.moving and not endless_mode) or h.blocked >= h.block:
				continue
			if next_pos.distance_to(h.pos) <= 43.0 or e.pos.distance_to(h.pos) <= 43.0:
				e.blocked_by = h.id
				h.blocked += 1
				next_pos = e.pos
				break
		e.pos = next_pos
		var victim: Dictionary = ranged_victim
		if not construct_victim.is_empty():
			victim = {}
		if e.blocked_by >= 0:
			victim = heroes[e.blocked_by]
		elif victim.is_empty():
			for h in heroes:
				if bool(h.get("deployed", false)) and h.hp > 0 and h.pos.distance_to(e.pos) <= 33:
					victim = h
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
			for warned_hero: Dictionary in heroes:
				if bool(warned_hero.get("deployed", false)) and warned_hero.hp > 0.0:
					e.special_warning_positions.append(warned_hero.pos)
					events.append({"kind":"enemy_warning","pos":warned_hero.pos,"source":e.pos,"radius":warning_radius,"life":lead,"boss":true,"shape":e.special_warning_shape,"name":e.special_move_name})
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
		if not endless_mode and (completed_route or (route.is_empty() and e.pos.x <= 108.0)):
			e.hp = 0.0
			base_hp = maxi(0, base_hp - e.leak)
			events.append({"kind": "leak", "pos": e.pos, "value": e.leak})
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	geo_constructs = geo_constructs.filter(func(item: Dictionary) -> bool: return item.hp > 0.0)

func _execute_boss_special(enemy: Dictionary) -> void:
	var phase := int(enemy.get("boss_phase", 1))
	var move := str(enemy.get("special_move", "pulse"))
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
		return _endless_quality_enemy(maxi(1, floori(elapsed / 45.0) + 1), index)
	if kind in ENDLESS_LOW_TIER_IDS and _endless_kind_count(ENDLESS_LOW_TIER_IDS) >= _endless_low_tier_cap():
		return _endless_quality_enemy(maxi(1, floori(elapsed / 45.0) + 1), index)
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
		damage_hero(int(hero.id), amount)
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
		construct.hp = maxf(0.0, float(construct.hp) - damage)
		events.append({"kind": "geo_hit", "pos": construct.pos, "value": ceili(damage)})
		if construct.hp <= 0.0:
			events.append({"kind": "geo_break", "pos": construct.pos})
		return

func deploy_hero(hero_id: int, point: Vector2) -> bool:
	if state not in ["running", "between"] or hero_id < 0 or hero_id >= heroes.size():
		return false
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0.0:
		return false
	var bounds := ENDLESS_ARENA.grow(-36.0) if endless_mode else MOVE_AREA
	point.x = clampf(point.x, bounds.position.x, bounds.end.x)
	point.y = clampf(point.y, bounds.position.y, bounds.end.y)
	point = _resolve_walkable_target(point)
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

func hero_skill_name(hero_id: int) -> String:
	if hero_id < 0 or hero_id >= heroes.size():
		return "主动技能"
	return str(heroes[hero_id].get("active_skill", {}).get("name", "主动技能"))

func hero_ultimate_name(hero_id: int) -> String:
	if hero_id < 0 or hero_id >= heroes.size():
		return "终结技"
	return str(heroes[hero_id].get("ultimate", {}).get("name", "终结技"))

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
		traveler_skill_cooldown_max = float({"none": 9.0, "anemo": 16.0, "electro": 14.0, "pyro": 15.0, "hydro": 18.0, "geo": 13.0, "cryo": 17.0}.get(element, 15.0))
		traveler_skill_cooldown_max *= maxf(0.35, 1.0 - skill_cooldown_reduction)
		traveler_skill_cooldown = traveler_skill_cooldown_max
		hero.skill_cooldown = traveler_skill_cooldown_max
		hero.skill_uses = int(hero.skill_uses) + 1
		pending_impacts.append({"life":0.34,"kind":"traveler_skill","hero_id":hero.id,"target_pos":target})
		events.append({"kind":"skill_cast","pos":hero.pos,"target":target,"hero_id":hero.id,"value":traveler_skill_name(),"hit_delay":0.34})
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
	var ability: Dictionary = hero.get("ultimate", {})
	hero.energy = 0.0
	hero.ultimate_cooldown_max = float(ability.get("cooldown", 26.0)) * maxf(0.55, 1.0 - skill_cooldown_reduction * 0.55)
	hero.ultimate_cooldown = hero.ultimate_cooldown_max
	hero.ultimate_uses = int(hero.ultimate_uses) + 1
	_queue_ability(hero, ability, target, true)
	return true

func _queue_ability(hero: Dictionary, ability: Dictionary, target: Vector2, ultimate: bool) -> void:
	var timeline: Dictionary = CombatTimeline.compile(ability, ultimate)
	hero.animation_state = "ultimate" if ultimate else "skill"
	hero.status_timer = float(timeline.duration)
	pending_impacts.append({"life":float(timeline.hit_frame),"kind":"ability","hero_id":hero.id,"target_pos":target,"ability":ability.duplicate(true),"ultimate":ultimate,"timeline":timeline})
	events.append({"kind":"ultimate_cast" if ultimate else "skill_cast","pos":hero.pos,"target":target,"hero_id":hero.id,"value":str(ability.get("name","技能")),"hit_delay":float(timeline.hit_frame),"duration":float(timeline.duration),"targeting":str(ability.get("targeting","point"))})
	events.append({"kind":"vfx_cue","pos":target,"hero_id":hero.id,"profile":"ultimate_burst" if ultimate else "skill_field","delay":float(timeline.vfx_frame),"value":str(ability.get("kind","burst"))})

func _pending_impact_tick(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for impact: Dictionary in pending_impacts:
		impact.life = float(impact.life) - dt
		if impact.life > 0.0:
			alive.append(impact)
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
			events.append({"kind":"skill_impact","pos":impact.get("target_pos",hero.pos),"hero_id":hero_id,"value":traveler_skill_name(),"element":hero.element,"radius":traveler_skill_radius()})
		elif impact.kind == "melee":
			var victim := find_enemy(int(impact.get("target_id", -1)))
			if victim.is_empty() or not is_in_attack_range(hero, victim.pos):
				continue
			var dealt := apply_hit(victim, float(impact.damage), str(impact.element), hero_id)
			if bool(impact.get("critical", false)):
				events.append({"kind":"critical","pos":victim.pos,"value":ceili(dealt)})
			var secondary := normalize_element(str(impact.get("secondary_element", "")))
			if not secondary.is_empty() and victim.hp > 0.0:
				apply_hit(victim, float(impact.damage) * 0.85, secondary, hero_id)
			if bool(hero.get("cleave", false)):
				splash_damage(victim, float(impact.damage) * float(hero.get("cleave_ratio", 0.5)), 145.0 + float(hero.get("pierce", 0)) * 18.0, hero)
			_apply_attack_extras(victim, hero, float(impact.damage))
			events.append({"kind":"synced_impact","pos":victim.pos,"hero_id":hero_id,"value":ceili(dealt)})
		else:
			_execute_ability_impact(hero, impact.get("ability", {}), impact.get("target_pos", hero.pos), bool(impact.get("ultimate", false)))
	pending_impacts = alive

func _execute_ability_impact(hero: Dictionary, ability: Dictionary, target: Vector2, ultimate: bool) -> void:
	var kind := str(ability.get("kind", "burst"))
	var radius := float(ability.get("radius", 180.0)) * (1.0 + skill_area_bonus) * (1.2 if ultimate and run_state.equipped_relics.has("relic_resonant_core") else 1.0)
	var power := float(ability.get("power", 160.0)) * (1.0 + skill_power_bonus)
	var passive_kind := str(hero.get("passive", {}).get("kind", ""))
	if passive_kind == "mana_surge": power *= 1.0 + float(hero.energy) / maxf(1.0, float(hero.max_energy)) * 0.35
	if passive_kind == "resolve" and float(hero.hp) / maxf(1.0, float(hero.max_hp)) <= 0.5: power *= 1.45
	match kind:
		"heal_gust":
			_heal_heroes(hero.pos, radius, power * 0.42, 34.0)
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)): ally.speed *= 1.08
		"anemo_domain":
			_damage_area(target, radius, power, "anemo", hero.id, "pull")
			skill_effects.append({"kind":"anemo_domain","pos":target,"life":7.0,"pulse":0.0,"power":power*0.18,"area":radius/180.0,"hero_id":hero.id})
		"salon_summon":
			orbitals.append({"hero_id":hero.id,"count":3,"damage":power*0.32,"radius":radius*0.68,"timer":0.1,"interval":0.52,"life":10.0,"element":"hydro","visual":"salon"})
		"hydro_fanfare":
			_heal_heroes(hero.pos, 9999.0, power*0.34, 0.0)
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)): ally.rate += ally.base_rate*0.26
			skill_effects.append({"kind":"hydro_field","pos":hero.pos,"life":10.0,"pulse":0.0,"power":power*0.14,"area":radius/220.0,"hero_id":hero.id})
		"hydro_burst":
			_damage_area(target, radius, power, "hydro", hero.id)
		"storm_field":
			_damage_area(target, radius, power*0.65, "hydro", hero.id)
			skill_effects.append({"kind":"storm_field","pos":target,"life":9.0,"pulse":0.0,"power":power*0.22,"area":radius/190.0,"hero_id":hero.id})
		"sonic_wave":
			_damage_area(target, radius, power * 1.15, "pyro", hero.id, "knockback")
			skill_effects.append({"kind":"burning_ground","pos":target,"life":5.0,"pulse":0.0,"power":power*0.20,"area":radius/105.0,"hero_id":hero.id})
		"team_concert":
			for ally: Dictionary in heroes:
				if bool(ally.get("deployed", false)) and ally.hp > 0.0:
					ally.rate += ally.base_rate*0.32
					ally.energy = minf(ally.max_energy, ally.energy+24.0)
					ally.skill_cooldown = maxf(0.0, ally.skill_cooldown-3.0)
		"arcane_lance":
			_damage_area(target, radius, power*1.18, "electro", hero.id)
		"chimera":
			_damage_area(target, radius, power*1.55, "electro", hero.id)
			hero.hp = maxf(1.0, hero.hp-hero.max_hp*0.08)
			hero.damage += hero.base_damage*0.28
		"cryo_chord":
			_damage_area(target, radius, power, "cryo", hero.id, "freeze")
		"fate_symphony":
			_damage_area(target, radius, power * 1.35, "pyro", hero.id, "knockback")
			skill_effects.append({"kind":"burning_ground","pos":target,"life":10.0,"pulse":0.0,"power":power*0.28,"area":radius/105.0,"hero_id":hero.id})
			for ally: Dictionary in heroes: ally.crit_chance = minf(0.85, ally.crit_chance+0.18)
		"frost_bloom":
			_damage_area(target, radius, power, "cryo", hero.id, "freeze")
		"frozen_forest":
			_damage_area(target, radius, power*0.75, "cryo", hero.id, "freeze")
			skill_effects.append({"kind":"frozen_forest","pos":target,"life":12.0,"pulse":0.0,"power":power*0.16,"area":radius/210.0,"hero_id":hero.id})
		"echo_shot":
			_damage_area(target, radius, power, "hydro", hero.id)
			_damage_area(target, radius*0.72, power*0.55, "hydro", hero.id)
		"encore":
			_heal_heroes(hero.pos, 9999.0, power*0.28, 0.0)
			for ally: Dictionary in heroes:
				ally.skill_cooldown = 0.0
				ally.energy = minf(ally.max_energy, ally.energy+18.0)
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
					ally.energy = minf(ally.max_energy, ally.energy+30.0)
		_:
			_damage_area(target, radius, power, str(hero.element), hero.id)
	damage_terrain_shortcuts(target, radius, maxf(90.0, power * (0.42 if ultimate else 0.30)))
	if passive_kind == "encore_meter":
		for ally: Dictionary in heroes: ally.skill_cooldown = maxf(0.0, ally.skill_cooldown-1.5)
	hero.energy = minf(float(hero.max_energy), float(hero.energy) + (8.0 if run_state.equipped_relics.has("relic_resonant_core") else 0.0))
	hero.animation_state = "idle"
	events.append({"kind":"ultimate_impact" if ultimate else "skill_impact","pos":target,"hero_id":hero.id,"value":str(ability.get("name","技能")),"element":hero.element,"radius":radius,"ability_kind":kind})

func _damage_area(center: Vector2, radius: float, power: float, element: String, hero_id: int, control: String = "") -> int:
	var hits := 0
	for enemy: Dictionary in enemies.duplicate():
		if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos) or enemy.pos.distance_to(center) > radius: continue
		apply_hit(enemy, power, element, hero_id)
		if control == "pull": enemy.pos = enemy.pos.move_toward(center, 72.0)
		elif control == "freeze": enemy.frozen_timer = maxf(float(enemy.get("frozen_timer",0.0)), 2.8)
		hits += 1
	return hits

func _damage_line(origin: Vector2, target: Vector2, length: float, width: float, power: float, element: String, hero_id: int, push: bool = false) -> int:
	var direction := (target-origin).normalized()
	if direction.length_squared() < 0.1: direction = Vector2.RIGHT
	var hits := 0
	for enemy: Dictionary in enemies.duplicate():
		var relative: Vector2 = enemy.pos-origin
		var forward := relative.dot(direction)
		var lateral := absf(relative.cross(direction))
		if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos) or forward < 0.0 or forward > length or lateral > width: continue
		apply_hit(enemy, power, element, hero_id)
		if push: enemy.pos += direction*68.0
		hits += 1
	return hits

func _heal_heroes(center: Vector2, radius: float, amount: float, shield: float) -> void:
	for ally: Dictionary in heroes:
		if not bool(ally.get("deployed", false)) or ally.hp <= 0.0 or ally.pos.distance_to(center) > radius: continue
		var healed := minf(ally.max_hp-ally.hp, amount)
		ally.hp += healed
		if shield > 0.0: crystal_shield = minf(500.0, crystal_shield+shield)
		events.append({"kind":"heal","pos":ally.pos,"value":ceili(healed)})

func _record_damage(hero_id: int, damage: float) -> void:
	if hero_id < 0 or hero_id >= heroes.size() or damage <= 0.0:
		return
	var hero: Dictionary = heroes[hero_id]
	hero.damage_done = float(hero.get("damage_done", 0.0)) + damage
	var gain_scale := 1.5 if run_state.equipped_relics.has("relic_overclock") else 1.0
	hero.energy = minf(float(hero.max_energy), float(hero.energy) + maxf(1.0, damage * 0.055) * gain_scale)
	hero.max_energy_seen = maxf(float(hero.get("max_energy_seen", 0.0)), float(hero.energy))

func _orbital_tick(dt: float) -> void:
	var alive: Array[Dictionary] = []
	for orbital: Dictionary in orbitals:
		orbital.life = float(orbital.life) - dt
		orbital.timer = float(orbital.timer) - dt
		orbital.storm_timer = float(orbital.get("storm_timer", 3.2)) - dt
		if orbital.life <= 0.0:
			continue
		var hero_id := int(orbital.get("hero_id", -1))
		if hero_id < 0 or hero_id >= heroes.size() or not bool(heroes[hero_id].get("deployed", false)):
			continue
		var hero: Dictionary = heroes[hero_id]
		if str(orbital.get("source_card", "")) == "orbit_arcane_blades" and int(orbital.get("level", 1)) >= 9 and orbital.storm_timer <= 0.0:
			orbital.storm_timer += 3.2
			_damage_area(hero.pos, float(orbital.radius) * 1.35, float(orbital.damage) * 1.8, str(orbital.element), hero_id, "barrage")
			events.append({"kind":"orbit_storm","pos":hero.pos,"hero_id":hero_id,"value":int(orbital.count)})
		if orbital.timer <= 0.0:
			orbital.timer += float(orbital.interval)
			var targets: Array[Dictionary] = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0.0 and _ability_target_visible(e.pos) and e.pos.distance_to(hero.pos) <= float(orbital.radius))
			targets.sort_custom(func(a: Dictionary,b: Dictionary)->bool: return a.pos.distance_to(hero.pos) < b.pos.distance_to(hero.pos))
			for i in mini(int(orbital.count), targets.size()):
				apply_hit(targets[i], float(orbital.damage), str(orbital.element), hero_id)
				events.append({"kind":"orbit_hit","pos":targets[i].pos,"hero_id":hero_id})
		alive.append(orbital)
	orbitals = alive

func _begin_enemy_warning(enemy: Dictionary, victim: Dictionary = {}, construct: Dictionary = {}) -> void:
	var lead := 0.72 if float(enemy.get("attack_range", 0.0)) <= 0.0 else 1.05
	if run_state.equipped_relics.has("relic_warning_clock"):
		lead *= 1.35
	enemy.attack_pending = true
	enemy.warning_timer = lead
	enemy.warning_pos = construct.pos if not construct.is_empty() else victim.pos
	enemy.warning_radius = 52.0 if float(enemy.get("attack_range", 0.0)) <= 0.0 else 86.0
	enemy.warning_victim = int(victim.get("id", -1))
	enemy.warning_construct = int(construct.get("id", -1))
	if float(enemy.get("attack_range", 0.0)) > 0.0:
		events.append({"kind":"enemy_warning","pos":enemy.warning_pos,"source":enemy.pos,"radius":enemy.warning_radius,"life":lead,"boss":false})

func _resolve_enemy_warning(enemy: Dictionary) -> void:
	enemy.attack_pending = false
	var hit := false
	var victim_id := int(enemy.get("warning_victim", -1))
	var construct_id := int(enemy.get("warning_construct", -1))
	if construct_id >= 0:
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
		if bool(victim.get("deployed", false)) and victim.hp > 0.0 and victim.pos.distance_to(enemy.warning_pos) <= float(enemy.warning_radius) and clear_shot:
			damage_hero(victim_id, enemy.damage)
			if "suppressor" in enemy.get("affixes",[]):
				victim.skill_cooldown = float(victim.get("skill_cooldown",0.0))+2.0
				events.append({"kind":"skill_suppressed","pos":victim.pos,"value":2})
			hit = true
			if float(enemy.get("attack_range", 0.0)) > 0.0:
				events.append({"kind":"enemy_shot","pos":enemy.pos,"target":victim.pos,"value":ceili(enemy.damage),"enemy_kind":str(enemy.get("kind","")),"duration":clampf(enemy.pos.distance_to(victim.pos) / 620.0, 0.28, 0.72)})
	if hit and "vampiric" in enemy.get("affixes", []):
		enemy.hp = minf(enemy.max_hp, enemy.hp + enemy.damage * 0.25)
		events.append({"kind":"enemy_heal","pos":enemy.pos,"value":ceili(enemy.damage * 0.25)})
	if not hit:
		dodges += 1
		if victim_id >= 0 and victim_id < heroes.size():
			var dodge_energy := 12.0 if run_state.equipped_relics.has("relic_warning_clock") else 0.0
			if str(heroes[victim_id].get("passive",{}).get("kind","")) == "proxy_network": dodge_energy += 18.0
			heroes[victim_id].energy = minf(float(heroes[victim_id].max_energy), float(heroes[victim_id].energy) + dodge_energy)
		events.append({"kind":"dodge","pos":enemy.warning_pos,"value":1})
	enemy.attack_timer = 1.0 / maxf(0.1, float(enemy.rate) * (1.25 if enemy.haste_timer > 0 else 1.0))

func _apply_enemy_affix(enemy: Dictionary) -> void:
	if not v2_mode:
		return
	var threat := maxi(1, floori(elapsed / 45.0) + 1) if endless_mode else maxi(1, wave)
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
		var level := int(run_state.tag_counts.get(tag,0)) / int(thresholds[tag])
		var previous := int(tag_synergy_levels.get(tag,0))
		if level <= previous:
			continue
		var delta := level - previous
		tag_synergy_levels[tag] = level
		match tag:
			"弹道":
				for hero: Dictionary in heroes: hero.projectile_count += delta
			"召唤":
				for orbital: Dictionary in orbitals:
					if str(orbital.get("source_card","")) == "orbit_arcane_blades":
						orbital.damage = float(orbital.damage) * (1.0 + 0.12 * delta)
						orbital.radius = float(orbital.radius) + 18.0 * delta
					else:
						orbital.count += delta
			"反应": reaction_damage_bonus += 0.15 * delta
			"暴击":
				for hero: Dictionary in heroes: hero.crit_chance = minf(0.85, float(hero.crit_chance) + 0.10 * delta)
			"护盾": crystal_shield += 80.0 * delta
			"支援":
				for support: Dictionary in supports.values(): support.interval = maxf(1.2, float(support.interval) * pow(0.90, delta))
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
	return {
		"none": "无锋剑气", "anemo": "风涡龙卷", "electro": "雷罚连星", "pyro": "烈焰星坠",
		"hydro": "水泽恩典", "geo": "岩脊壁垒", "cryo": "霜封领域"
	}.get(traveler_skill_element(), "元素战技")

func traveler_skill_radius() -> float:
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
	var power := 1.0 + skill_power_bonus
	var area := 1.0 + skill_area_bonus
	var duration := 1.0 + skill_duration_bonus
	match element:
		"anemo":
			skill_effects.append({"kind": "anemo_tornado", "pos": target, "life": 4.2 * duration, "pulse": 0.0, "power": power, "area": area})
			events.append({"kind": "skill_anemo", "pos": target, "value": traveler_skill_name()})
		"electro":
			var targets: Array[Dictionary] = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0.0 and _ability_target_visible(e.pos) and e.pos.distance_to(target) <= 380.0)
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_to(target) < b.pos.distance_to(target))
			for i in mini(8, targets.size()):
				apply_hit(targets[i], 155.0 * power * (1.0 - i * 0.055), "electro")
			events.append({"kind": "skill_electro", "pos": target, "value": targets.size()})
		"pyro":
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and enemy.pos.distance_to(target) <= 215.0 * area:
					apply_hit(enemy, 235.0 * power, "pyro")
			events.append({"kind": "skill_pyro", "pos": target, "value": traveler_skill_name()})
		"hydro":
			for hero: Dictionary in heroes:
				var healing: float = float(hero.max_hp) * 0.38 * power
				hero.hp = minf(hero.max_hp, hero.hp + healing)
				events.append({"kind": "heal", "pos": hero.pos, "value": ceili(healing)})
			base_hp = mini(base_max_hp, base_hp + 12)
			skill_effects.append({"kind": "hydro_field", "pos": target, "life": 5.0 * duration, "pulse": 0.0, "power": power, "area": area})
			events.append({"kind": "skill_hydro", "pos": target, "value": 12})
		"geo":
			next_construct_id += 1
			geo_constructs.append({"id": next_construct_id, "pos": target, "hp": 620.0 * power, "max_hp": 620.0 * power})
			if geo_constructs.size() > 3:
				geo_constructs.pop_front()
			events.append({"kind": "skill_geo", "pos": target, "value": 620})
		"cryo":
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and enemy.pos.distance_to(target) <= 225.0 * area:
					enemy.slow_timer = maxf(float(enemy.slow_timer), 5.5 * duration)
					apply_hit(enemy, 105.0 * power, "cryo")
			skill_effects.append({"kind": "cryo_field", "pos": target, "life": 5.5 * duration, "pulse": 0.0, "power": power, "area": area})
			events.append({"kind": "skill_cryo", "pos": target, "value": traveler_skill_name()})
		_:
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and enemy.pos.distance_to(target) <= 145.0:
					apply_hit(enemy, 125.0 * power, "")
					enemy.pos.x += 45.0
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 45})
			events.append({"kind": "skill_none", "pos": target, "value": traveler_skill_name()})
	damage_terrain_shortcuts(target, traveler_skill_radius() * area, 240.0 * power)
	var secondary := normalize_element(str(heroes[0].get("secondary_element", "")))
	if not secondary.is_empty():
		var secondary_radius := traveler_skill_radius() * (1.0 + skill_area_bonus)
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and _ability_target_visible(enemy.pos) and enemy.pos.distance_to(target) <= secondary_radius:
				apply_hit(enemy, 115.0 * power, secondary)
		events.append({"kind": "element_burst", "pos": target, "value": secondary})
	return true

func _skill_effect_tick(dt: float) -> void:
	var surviving: Array[Dictionary] = []
	for effect: Dictionary in skill_effects:
		effect.life = float(effect.life) - dt
		effect.pulse = float(effect.pulse) - dt
		if effect.kind == "anemo_tornado":
			effect.pos.x = minf(1140.0, effect.pos.x + 52.0 * dt)
		if effect.pulse <= 0.0:
			effect.pulse += 0.42 if effect.kind == "anemo_tornado" else 0.85
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp <= 0.0 or not _ability_target_visible(enemy.pos):
					continue
				var effect_area: float = float(effect.get("area", 1.0))
				var effect_power: float = float(effect.get("power", 1.0))
				if effect.kind == "anemo_tornado" and enemy.pos.distance_to(effect.pos) <= 135.0 * effect_area:
					enemy.pos.x += 34.0
					enemy.pos.y = move_toward(float(enemy.pos.y), float(effect.pos.y), 24.0)
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 34})
					apply_hit(enemy, 42.0 * effect_power, "anemo")
				elif effect.kind == "hydro_field" and enemy.pos.distance_to(effect.pos) <= 250.0 * effect_area:
					apply_hit(enemy, 28.0 * effect_power, "hydro")
				elif effect.kind == "cryo_field" and enemy.pos.distance_to(effect.pos) <= 225.0 * effect_area:
					enemy.slow_timer = maxf(float(enemy.slow_timer), 1.2)
				elif effect.kind == "burning_ground" and enemy.pos.distance_to(effect.pos) <= 105.0 * effect_area:
					apply_hit(enemy, 26.0 * effect_power, "pyro", int(effect.get("hero_id",-1)))
				elif effect.kind in ["anemo_domain","gate_field"] and enemy.pos.distance_to(effect.pos) <= 180.0 * effect_area:
					apply_hit(enemy, effect_power, "anemo", int(effect.get("hero_id",-1)))
					enemy.pos = enemy.pos.move_toward(effect.pos, 32.0)
				elif effect.kind == "storm_field" and enemy.pos.distance_to(effect.pos) <= 190.0 * effect_area:
					apply_hit(enemy, effect_power, "hydro", int(effect.get("hero_id",-1)))
					chain_damage(enemy, effect_power*0.35, 1)
				elif effect.kind == "frozen_forest" and enemy.pos.distance_to(effect.pos) <= 210.0 * effect_area:
					apply_hit(enemy, effect_power, "cryo", int(effect.get("hero_id",-1)))
					enemy.slow_timer = maxf(float(enemy.slow_timer),1.4)
		if effect.life > 0.0:
			surviving.append(effect)
	skill_effects = surviving

func damage_hero(id: int, raw_damage: float) -> void:
	var h: Dictionary = heroes[id]
	if h.hp <= 0:
		return
	if crystal_shield > 0.0:
		var absorbed := minf(crystal_shield, raw_damage)
		crystal_shield -= absorbed
		raw_damage -= absorbed
		events.append({"kind": "crystal_guard", "pos": h.pos, "value": ceili(absorbed)})
		if raw_damage <= 0.0:
			return
	var reduction := float(h.get("damage_reduction",0.0))
	if str(h.get("passive",{}).get("kind","")) == "resolve" and h.hp/h.max_hp <= 0.5: reduction = maxf(reduction,0.22)
	if str(h.get("passive",{}).get("kind","")) == "tactical_link" and orbitals.any(func(o: Dictionary)->bool: return int(o.get("hero_id",-1)) == id and str(o.get("visual","")) == "mon3tr"): reduction = maxf(reduction,0.25)
	var damage: float = raw_damage * (1.0-clampf(reduction,0.0,0.75)) * 100.0 / (100.0 + maxf(0, h.armor))
	h.hp = maxf(0, h.hp - damage)
	h.flash = 0.12
	h.animation_state = "hurt"
	h.status_timer = 0.44
	events.append({"kind": "hurt", "pos": h.pos, "value": ceili(damage), "hero_id": id})
	if h.hp <= 0 and run_state.equipped_relics.has("relic_second_heartbeat") and not bool(h.get("revived", false)):
		h.hp = h.max_hp * 0.35
		h.revived = true
		events.append({"kind":"revive","pos":h.pos,"hero_id":id})
		return
	if h.hp <= 0:
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
	for h: Dictionary in heroes:
		if h.hp <= 0 or not bool(h.get("deployed", true)) or (h.moving and not endless_mode):
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
		for e: Dictionary in enemies:
			var can_target_air: bool = bool(h.get("can_hit_air", false)) or (h.get("character_id", "") == "traveler" and h.get("element", "") != "")
			if e.hp > 0 and (not bool(e.get("flying", false)) or can_target_air) and is_in_attack_range(h, e.pos) and not terrain_line_blocked(h.pos, e.pos):
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
		events.append({"kind": "shot", "pos": h.pos, "hero_id": h.id, "duration": interval, "element": h.element, "style": str(h.get("attack_style", "standard"))})
		var damage: float = h.damage * terrain_attack_scale(h.pos)
		var critical: bool = randf() < clampf(float(h.get("crit_chance", 0.0)), 0.0, 0.85)
		if critical:
			damage *= 2.0
		var attack_count: int = maxi(1, int(h.get("projectile_count", 1)))
		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x < b.pos.x)
		if h.block > 0:
			var hit_ratio := float(h.get("attack_hit_frame_ratio", 0.48))
			for strike in attack_count:
				var victim: Dictionary = available[strike % available.size()]
				pending_impacts.append({"life": interval * hit_ratio + strike * 0.025, "kind": "melee", "hero_id": h.id, "target_id": victim.id, "damage": damage if strike == 0 else damage * 0.72, "element": h.element, "secondary_element": h.get("secondary_element", ""), "critical": critical})
				var slash_direction: Vector2 = (victim.pos - h.pos).normalized()
				events.append({"kind": "slash", "pos": victim.pos, "source_pos": h.pos, "angle": slash_direction.angle(), "element": normalize_element(str(h.element)), "critical": critical, "hit_delay": interval * hit_ratio})
		else:
			for shot_index in attack_count:
				if not performance_budget.allow_projectile(projectiles.size()):
					culled_spawns += 1
					break
				var shot_target: Dictionary = available[shot_index % available.size()]
				projectiles.append({"visual_id": next_projectile_id, "pos": h.pos + Vector2(14, -12 + (shot_index - (attack_count - 1) * 0.5) * 6.0), "target_id": shot_target.id, "damage": damage if shot_index == 0 else damage * 0.78, "element": h.element, "secondary_element": h.get("secondary_element", ""), "source_id": h.id, "splash": h.splash, "slow": h.slow, "pierce": int(h.get("pierce", 0)), "chain_count": int(h.get("chain_count", 0)), "blast_radius": float(h.get("blast_radius", 0.0)), "echo_ratio": float(h.get("echo_ratio", 0.0)), "critical": critical, "style": str(h.get("attack_style", "standard"))})
				next_projectile_id += 1
		if attack_count > 1:
			events.append({"kind": "multishot", "pos": h.pos, "value": attack_count})

func attack_range_screen_radii(hero: Dictionary) -> Vector2:
	var depth: float = StageProjection.depth_scale(hero.pos)
	var range_feature := terrain_feature_at(hero.pos, "high_ground")
	var terrain_range_scale := 1.0 + float(range_feature.get("range_bonus", 0.35)) if not range_feature.is_empty() else 1.0
	var radius_x: float = minf(330.0, 42.0 + float(hero.range) * 0.62 * depth * terrain_range_scale)
	return Vector2(radius_x, radius_x * 0.40)

func is_in_attack_range(hero: Dictionary, point: Vector2) -> bool:
	var center: Vector2 = StageProjection.project(hero.pos) + Vector2(0, 8)
	var projected: Vector2 = StageProjection.project(point)
	var radii := attack_range_screen_radii(hero)
	var normalized := Vector2((projected.x - center.x) / radii.x, (projected.y - center.y) / radii.y)
	return normalized.length_squared() <= 1.0

func _apply_attack_extras(target: Dictionary, hero: Dictionary, damage: float) -> void:
	if float(hero.get("blast_radius", 0.0)) > 0.0:
		splash_damage(target, damage * 0.45, float(hero.blast_radius), hero)
	if int(hero.get("chain_count", 0)) > 0:
		chain_damage(target, damage * 0.55, int(hero.chain_count), hero)
	if float(hero.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
		apply_hit(target, damage * float(hero.echo_ratio), hero.element)
		events.append({"kind": "echo", "pos": target.pos})

func apply_hit(enemy: Dictionary, raw_damage: float, element: String, source_hero_id: int = -1) -> float:
	if source_hero_id < 0 and damage_source_override >= 0:
		source_hero_id = damage_source_override
	if enemy.is_empty() or enemy.hp <= 0:
		return 0.0
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
			enemy.aura = ""
			enemy.aura_timer = 0.0
			enemy.reaction_timer = REACTION_COOLDOWN
			reactions += 1
			events.append({"kind": reaction, "pos": enemy.pos})
			match reaction:
				"overloaded":
					enemy.pos.x += 75.0
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
	var damage: float = raw_damage * multiplier * 100.0 / (100.0 + maxf(0, enemy.armor))
	if enemy.get("kind", "") == "armored" or str(enemy.get("kind", "")).begins_with("boss_"):
		damage *= 1.0 + elite_damage_bonus
	if execute_threshold > 0.0 and enemy.hp / enemy.max_hp <= minf(0.65, execute_threshold):
		damage *= 1.6
	enemy.hp -= damage
	_record_damage(source_hero_id, damage)
	enemy.flash = 0.1
	events.append({"kind": "hit", "pos": enemy.pos + Vector2(0, -12), "value": ceili(damage), "element": incoming_element})
	if enemy.hp > 0.0 and str(enemy.get("kind", "")).begins_with("boss_"):
		_update_boss_phase(enemy)
	if enemy.hp <= 0:
		if enemy.get("kind", "") == "splitter" and not bool(enemy.get("spawner", false)) and not bool(enemy.get("split_done", false)):
			enemy.split_done = true
			for i in int(enemy.get("split_count", 2)):
				var child := spawn_enemy(enemy.pos + Vector2(24.0 + i * 18.0, -22.0 + i * 44.0), "runner")
				child.hp *= 0.58
				child.max_hp = child.hp
				child.xp = 4
			events.append({"kind": "split", "pos": enemy.pos, "value": int(enemy.get("split_count", 2))})
		elif "duplicator" in enemy.get("affixes",[]) and not bool(enemy.get("split_done",false)):
			enemy.split_done = true
			for i in 2:
				var copy_enemy := spawn_enemy(enemy.pos+Vector2(22.0,(i*2-1)*26.0),"runner")
				copy_enemy.hp = enemy.max_hp*0.22
				copy_enemy.max_hp = copy_enemy.hp
				copy_enemy.affixes = []
				copy_enemy.xp = 3
			events.append({"kind":"enemy_duplicate","pos":enemy.pos,"value":2})
		kills += 1
		kill_streak += 1
		kill_streak_timer = 2.5
		best_streak = maxi(best_streak, kill_streak)
		if kill_streak == 10 or kill_streak == 25 or kill_streak % 50 == 0:
			events.append({"kind": "kill_streak", "pos": enemy.pos, "value": kill_streak})
		if "volatile" in enemy.get("affixes", []):
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and hero.pos.distance_to(enemy.pos) <= 95.0:
					damage_hero(hero.id, 36.0)
			events.append({"kind":"enemy_volatile","pos":enemy.pos,"value":36})
		if death_burst_ratio > 0.0:
			splash_damage(enemy, enemy.max_hp * death_burst_ratio, 90.0)
			events.append({"kind": "death_burst", "pos": enemy.pos})
		var milestone: int = kills / 10
		if kill_frenzy_step > 0.0 and milestone > frenzy_milestone:
			for hero: Dictionary in heroes:
				hero.rate += hero.base_rate * kill_frenzy_step * (milestone - frenzy_milestone)
			frenzy_milestone = milestone
			events.append({"kind": "frenzy", "pos": enemy.pos, "value": milestone})
		grant_xp(enemy.xp)
		if float(enemy.get("death_burst", 0.0)) > 0.0:
			for hero: Dictionary in heroes:
				if bool(hero.get("deployed", false)) and hero.hp > 0.0 and hero.pos.distance_to(enemy.pos) <= 105.0:
					damage_hero(hero.id, float(enemy.death_burst))
			events.append({"kind":"enemy_volatile","pos":enemy.pos,"value":int(enemy.death_burst)})
		enemy_lookup.erase(int(enemy.id))
		events.append({"kind": "death", "pos": enemy.pos, "enemy_kind": str(enemy.get("kind", "")), "facing": float(enemy.get("facing", -1.0)), "size": float(enemy.get("size", 48.0)), "color": str(enemy.get("color", "#ffffff"))})
	return damage

func _update_boss_phase(enemy: Dictionary) -> void:
	var ratio: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
	var target_phase := 3 if ratio <= 0.35 else (2 if ratio <= 0.70 else 1)
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
	return {"fire": "pyro", "water": "hydro"}.get(element, element)

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
	var surviving: Array[Dictionary] = []
	for shot in projectiles:
		var target: Dictionary = find_enemy(shot.target_id)
		if target.is_empty():
			continue
		var source_hero: Dictionary = {}
		var source_id := int(shot.get("source_id", -1))
		if source_id >= 0 and source_id < heroes.size():
			source_hero = heroes[source_id]
		var impact: Vector2 = target.pos + Vector2(0, -12)
		if shot.pos.distance_to(impact) <= PROJECTILE_SPEED * dt:
			if not source_hero.is_empty() and not is_in_attack_range(source_hero, target.pos):
				continue
			var dealt: float = apply_hit(target, shot.damage, shot.element, source_id)
			if bool(shot.get("critical", false)):
				events.append({"kind": "critical", "pos": target.pos, "value": ceili(dealt)})
			var secondary := normalize_element(str(shot.get("secondary_element", "")))
			if not secondary.is_empty() and target.hp > 0.0:
				apply_hit(target, float(shot.damage) * 0.85, secondary)
			if shot.get("slow", false):
				target.slow_timer = 2.0
			if shot.get("splash", false):
				splash_damage(target, shot.damage * 0.5, 65.0, source_hero)
			if float(shot.get("blast_radius", 0.0)) > 0.0:
				splash_damage(target, shot.damage * 0.45, float(shot.blast_radius), source_hero)
			if fireball_level >= 6 and normalize_element(str(shot.element)) == "pyro":
				skill_effects.append({"kind":"burning_ground","pos":target.pos,"life":3.2,"pulse":0.0,"power":0.65+fireball_level*0.06,"area":1.0})
				events.append({"kind":"burning_ground","pos":target.pos,"value":fireball_level})
			if int(shot.get("chain_count", 0)) > 0:
				chain_damage(target, shot.damage * 0.55, int(shot.chain_count), source_hero)
			if float(shot.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
				apply_hit(target, shot.damage * float(shot.echo_ratio), shot.element)
				events.append({"kind": "echo", "pos": target.pos})
			if int(shot.get("pierce", 0)) > 0:
				var next_target: Dictionary = _nearest_enemy_after(target, [target.id], source_hero)
				if not next_target.is_empty():
					shot.target_id = next_target.id
					shot.pierce = int(shot.pierce) - 1
					shot.pos = impact
					surviving.append(shot)
					events.append({"kind": "pierce", "pos": target.pos})
		else:
			shot.pos = shot.pos.move_toward(impact, PROJECTILE_SPEED * dt)
			surviving.append(shot)
	projectiles = surviving

func _nearest_enemy_after(origin: Dictionary, excluded: Array, source_hero: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0 or enemy.id in excluded or (not source_hero.is_empty() and not is_in_attack_range(source_hero, enemy.pos)):
			continue
		if result.is_empty() or enemy.pos.distance_to(origin.pos) < result.pos.distance_to(origin.pos):
			result = enemy
	return result

func chain_damage(primary: Dictionary, damage: float, count: int, source_hero: Dictionary = {}) -> void:
	var current: Dictionary = primary
	var excluded: Array = [primary.id]
	for index in count:
		var next_target := _nearest_enemy_after(current, excluded, source_hero)
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
		if support.timer > 0.0:
			continue
		support.timer += float(support.interval)
		_trigger_support(key, support)

func _trigger_support(kind: String, support: Dictionary) -> void:
	if kind == "support_heal":
		for hero: Dictionary in heroes:
			hero.hp = minf(hero.max_hp, hero.hp + float(support.power))
		base_hp = mini(base_max_hp, base_hp + ceili(float(support.power) * 0.35))
		events.append({"kind": "support_heal", "pos": Vector2(360, 360), "value": ceili(float(support.power))})
		return
	if enemies.is_empty():
		return
	if kind == "support_crossfire":
		var lane_y: float = enemies[0].pos.y
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0 and absf(enemy.pos.y - lane_y) < 58.0:
				apply_hit(enemy, float(support.power), "")
		events.append({"kind": "crossfire", "pos": Vector2(760, lane_y), "value": int(support.stacks)})
	elif kind == "support_finale":
		for volley in int(support.stacks):
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0:
					apply_hit(enemy, float(support.power), "")
		events.append({"kind": "finale", "pos": Vector2(760, 360), "value": int(support.stacks)})
	else:
		var target: Dictionary = enemies[0]
		for enemy: Dictionary in enemies:
			if enemy.hp > target.hp:
				target = enemy
		apply_hit(target, float(support.power), "pyro")
		splash_damage(target, float(support.power) * 0.75, float(support.radius))
		events.append({"kind": "barrage", "pos": target.pos, "value": int(support.stacks)})

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events.duplicate()
	events.clear()
	return result

func splash_damage(primary: Dictionary, damage: float, radius: float, source_hero: Dictionary = {}) -> void:
	for enemy in enemies:
		if enemy.id != primary.id and enemy.hp > 0 and enemy.pos.distance_to(primary.pos) <= radius and (source_hero.is_empty() or is_in_attack_range(source_hero, enemy.pos)):
			apply_hit(enemy, damage, "")
	events.append({"kind": "splash", "pos": primary.pos})

func grant_xp(amount: int) -> void:
	if v2_mode:
		var gained: int = _grant_endless_xp(amount) if endless_mode else crystal.grant(run_state, amount)
		team_xp = run_state.crystal_xp
		team_level = run_state.crystal_level
		if gained > 0:
			events.append({"kind": "level_up", "value": run_state.crystal_level})
			if state == "running" and reward_cooldown <= 0.0:
				state = "reward"
				rewards.draw(self)
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
	return roundi(60.0 + 60.0 * n + 24.0 * n * n + 2.5 * n * n * n)

func export_run_snapshot() -> Dictionary:
	var hero_snapshots: Array[Dictionary] = []
	var hero_keys := ["character_id", "hp", "max_hp", "armor", "damage", "rate", "range", "speed", "block", "can_hit_air", "element", "secondary_element", "base_damage", "base_hp", "base_rate", "cleave", "cleave_ratio", "splash", "slow", "projectile_count", "pierce", "chain_count", "blast_radius", "echo_ratio", "crit_chance"]
	for hero: Dictionary in heroes:
		var row: Dictionary = {}
		for key: String in hero_keys:
			if hero.has(key): row[key] = hero[key]
		hero_snapshots.append(row)
	return {
		"squad": run_state.squad.duplicate(),
		"traveler_element": run_state.traveler_element,
		"traveler_secondary_element": run_state.traveler_secondary_element,
		"buff_levels": run_state.buff_levels.duplicate(true),
		"crystal_level": run_state.crystal_level,
		"crystal_xp": run_state.crystal_xp,
		"luck": run_state.luck,
		"heroes": hero_snapshots,
		"supports": supports.duplicate(true),
		"execute_threshold": execute_threshold,
		"death_burst_ratio": death_burst_ratio,
		"elite_damage_bonus": elite_damage_bonus,
		"kill_frenzy_step": kill_frenzy_step,
		"reaction_damage_bonus": reaction_damage_bonus,
		"reaction_radius_bonus": reaction_radius_bonus,
		"skill_power_bonus": skill_power_bonus,
		"skill_cooldown_reduction": skill_cooldown_reduction,
		"skill_area_bonus": skill_area_bonus,
		"skill_duration_bonus": skill_duration_bonus,
		"crystal_shield": crystal_shield
	}

func import_run_snapshot(snapshot: Dictionary) -> bool:
	if not endless_mode or snapshot.is_empty():
		return false
	run_state.traveler_element = str(snapshot.get("traveler_element", "none"))
	run_state.traveler_secondary_element = str(snapshot.get("traveler_secondary_element", "none"))
	run_state.buff_levels = snapshot.get("buff_levels", {}).duplicate(true)
	run_state.crystal_level = maxi(1, int(snapshot.get("crystal_level", 1)))
	run_state.crystal_xp = maxi(0, int(snapshot.get("crystal_xp", 0)))
	run_state.pending_level_ups = 0
	run_state.luck = clampf(float(snapshot.get("luck", 0.0)), 0.0, 0.75)
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
	execute_threshold = float(snapshot.get("execute_threshold", 0.0))
	death_burst_ratio = float(snapshot.get("death_burst_ratio", 0.0))
	elite_damage_bonus = float(snapshot.get("elite_damage_bonus", 0.0))
	kill_frenzy_step = float(snapshot.get("kill_frenzy_step", 0.0))
	reaction_damage_bonus = float(snapshot.get("reaction_damage_bonus", 0.0))
	reaction_radius_bonus = float(snapshot.get("reaction_radius_bonus", 0.0))
	skill_power_bonus = float(snapshot.get("skill_power_bonus", 0.0))
	skill_cooldown_reduction = float(snapshot.get("skill_cooldown_reduction", 0.0))
	skill_area_bonus = float(snapshot.get("skill_area_bonus", 0.0))
	skill_duration_bonus = float(snapshot.get("skill_duration_bonus", 0.0))
	crystal_shield = float(snapshot.get("crystal_shield", 0.0))
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

func _orthogonal_enemy_step(current: Vector2, target: Vector2, distance: float, radius: float, ignore_terrain: bool = false) -> Vector2:
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
		if ignore_terrain or _terrain_blocker_on_segment(current, candidate, radius).is_empty():
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

func apply_v2_card_effect(card: Dictionary) -> void:
	var targets: Array[Dictionary] = []
	if card.get("target", "global") == "character":
		for hero: Dictionary in heroes:
			if hero.get("character_id", "") == card.get("character_id", ""):
				targets.append(hero)
	else:
		targets.assign(heroes)
	var value: float = float(card.get("value", 0.0)) if card.get("value", 0.0) is float or card.get("value", 0.0) is int else 0.0
	match str(card.get("effect", "")):
		"assign_traveler_element":
			if not heroes.is_empty() and heroes[0].get("character_id", "") == "traveler":
				heroes[0].element = str(card.value)
				events.append({"kind": "element_attuned", "pos": heroes[0].pos, "value": str(card.value)})
		"dual_element_mythic":
			if not heroes.is_empty() and heroes[0].get("character_id", "") == "traveler":
				heroes[0].secondary_element = run_state.traveler_secondary_element
				heroes[0].damage += heroes[0].base_damage * 0.80
				heroes[0].rate += heroes[0].base_rate * 0.35
				heroes[0].projectile_count = int(heroes[0].projectile_count) + 2
				events.append({"kind": "element_attuned", "pos": heroes[0].pos, "value": run_state.traveler_secondary_element})
		"luck_add":
			pass
		"grant_relic":
			_apply_relic(str(card.get("value", "")))
		"orbit_add", "orbit_spell_add":
			var owner := targets[0] if not targets.is_empty() else (heroes[0] if not heroes.is_empty() else {})
			if not owner.is_empty():
				var card_id := str(card.id)
				var level := int(run_state.buff_levels.get(card_id, 1))
				var blade_mode := str(card.get("effect", "")) == "orbit_add"
				var count := (6 if level >= 6 else (3 if level >= 3 else 2)) if blade_mode else int(value) + level / 3 + (1 if run_state.equipped_relics.has("relic_orbit_foundry") else 0)
				var radius_bonus := 1.25 if run_state.equipped_relics.has("relic_orbit_foundry") else 1.0
				var state := {"hero_id":owner.id,"source_card":card_id,"level":level,"count":count,"damage":28.0+level*9.0,"radius":(155.0+level*12.0)*radius_bonus,"timer":0.1,"interval":maxf(0.24,0.70-level*0.035),"life":99999.0,"element":owner.element,"visual":"blade" if blade_mode else "spell","storm_timer":3.2}
				var existing_index := -1
				for index in orbitals.size():
					if int(orbitals[index].get("hero_id",-1)) == int(owner.id) and str(orbitals[index].get("source_card","")) == card_id:
						existing_index = index
						break
				if existing_index >= 0:
					state.timer = float(orbitals[existing_index].get("timer",0.1))
					state.storm_timer = float(orbitals[existing_index].get("storm_timer",3.2))
					orbitals[existing_index] = state
				else:
					orbitals.append(state)
		"evolving_fireball":
			var level := int(run_state.buff_levels.get(str(card.id), 1))
			fireball_level = maxi(fireball_level, level)
			for hero: Dictionary in targets:
				hero.blast_radius = maxf(float(hero.get("blast_radius",0.0)), 45.0 + level * 9.0)
				if level >= 3: hero.projectile_count += 1
				if level >= 6: hero.echo_ratio = maxf(float(hero.echo_ratio), 0.35)
				if level >= 9: hero.chain_count += 3
		"mythic_projectile_storm":
			for hero in targets:
				hero.projectile_count = int(hero.get("projectile_count", 1)) + 4
				hero.rate += hero.base_rate * 0.60
				hero.pierce = int(hero.get("pierce", 0)) + 3
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
		"range_flat", "squad_range_flat":
			for hero in targets: hero.range += value
		"squad_crit_flat":
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
		"reaction_damage_add": reaction_damage_bonus += value
		"reaction_radius_add": reaction_radius_bonus += value
		"deploy_reinforcement":
			_add_reinforcement(str(card.get("value", "")))
		"support_barrage", "support_crossfire", "support_heal", "support_finale":
			var support_id: String = str(card.effect)
			if not supports.has(support_id):
				supports[support_id] = {"timer": minf(2.0, float(card.get("interval", 8.0))), "interval": float(card.get("interval", 8.0)), "power": value, "radius": float(card.get("radius", 100.0)), "stacks": 1}
			else:
				var support: Dictionary = supports[support_id]
				support.stacks = int(support.stacks) + 1
				support.power = float(support.power) + value * 0.65
				support.radius = float(support.radius) + float(card.get("radius", 20.0)) * 0.18
				support.interval = maxf(1.5, float(support.interval) * 0.88)
		"execute_threshold_add": execute_threshold = 0.20 if execute_threshold <= 0.0 else minf(0.65, execute_threshold + value)
		"death_burst_add": death_burst_ratio += value
		"elite_damage_add": elite_damage_bonus += value
		"kill_frenzy_add": kill_frenzy_step += value
		"crystal_health_flat":
			base_max_hp += int(value)
			base_hp += int(value)
		"crystal_heal": base_hp = mini(base_max_hp, base_hp + int(value))
	_refresh_tag_synergies()

func _apply_relic(relic_id: String) -> void:
	match relic_id:
		"relic_glass_cannon":
			for hero: Dictionary in heroes: hero.damage *= 1.35
		"relic_overclock":
			for hero: Dictionary in heroes: hero.rate *= 1.25
		"relic_elemental_prism": reaction_damage_bonus += 0.30
		"relic_geo_contract":
			for construct: Dictionary in geo_constructs:
				construct.hp *= 2.0
				construct.max_hp *= 2.0
	events.append({"kind":"relic_awaken","pos":heroes[0].pos if not heroes.is_empty() else Vector2.ZERO,"value":relic_id})

func export_build_record() -> Dictionary:
	var stats: Array[Dictionary] = []
	for hero: Dictionary in heroes:
		stats.append({"id":hero.character_id,"name":hero.name,"damage":roundi(float(hero.get("damage_done",0.0))),"attacks":int(hero.get("shots",0)),"skills":int(hero.get("skill_uses",0)),"ultimates":int(hero.get("ultimate_uses",0)),"max_energy":roundi(float(hero.get("max_energy_seen",0.0)))})
	var record: Dictionary = run_state.export_build()
	record["elapsed"] = elapsed
	record["kills"] = kills
	record["dodges"] = dodges
	var highest_stack := 0
	for level: Variant in run_state.buff_levels.values():
		highest_stack = maxi(highest_stack, int(level))
	record["highest_stack"] = highest_stack
	record["characters"] = stats
	return record

func _evolution_tick(dt: float) -> void:
	if fireball_level < 9 or state != "running" or enemies.is_empty():
		return
	meteor_timer -= dt
	if meteor_timer > 0.0:
		return
	meteor_timer += maxf(1.8, 5.0 - fireball_level * 0.18)
	var target: Dictionary = enemies[(kills + fireball_level) % enemies.size()]
	var source_id := 0 if not heroes.is_empty() else -1
	for enemy: Dictionary in enemies.duplicate():
		if enemy.hp > 0.0 and enemy.pos.distance_to(target.pos) <= 190.0:
			apply_hit(enemy, 150.0 + fireball_level * 18.0, "pyro", source_id)
	events.append({"kind":"meteor","pos":target.pos,"value":fireball_level})
