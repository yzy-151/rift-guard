extends RefCounted
## Fixed-step gameplay, independent of scenes and visual effects.
const Rewards = preload("res://scripts/reward_book.gd")
const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CrystalProgression = preload("res://scripts/rewards/crystal_progression.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
const StageRuntime = preload("res://scripts/stages/stage_runtime.gd")
const StageProjection = preload("res://scripts/stage_projection.gd")
const XP_THRESHOLDS = [80, 190, 330, 500]
const Catalog = preload("res://scripts/combat_catalog.gd")
const MOVE_AREA = Rect2(40, 140, 1200, 440)
const STAGE_EXIT_AREA = Rect2(185, 215, 900, 320)
const ENDLESS_ARENA = Rect2(80, 80, 2400, 1280)
const LANES = [270.0, 360.0, 450.0]
const PROJECTILE_SPEED: float = 720.0
const AURA_DURATION: float = 3.0
const REACTION_COOLDOWN: float = 0.5
const HEAL_RANGE: float = 310.0
const HEAL_AMOUNT: float = 22.0

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
var endless_spawn_timer: float = 0.0
var terrain_features: Array[Dictionary] = []
var formation_mode: String = "hold"

func _init(seed_value: int = -1, enable_v2: bool = false) -> void:
	v2_mode = enable_v2
	if v2_mode:
		reset_stage("stage_01", ["traveler"], seed_value)
	else:
		reset(seed_value)

func reset(seed_value: int = -1) -> void:
	endless_mode = false
	endless_spawn_timer = 0.0
	terrain_features.clear()
	formation_mode = "hold"
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
	projectiles.clear()
	events.clear()
	for i in Catalog.HEROES.size():
		var h: Dictionary = Catalog.HEROES[i].duplicate(true)
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "attack_timer": 0.0, "heal_timer": 1.0, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": false, "splash": false, "slow": false})
		heroes.append(h)

func reset_stage(stage_id: String, squad_ids: Array[String] = [], seed_value: int = -1) -> void:
	v2_mode = true
	current_stage_id = stage_id
	endless_mode = stage_id == "stage_endless"
	endless_spawn_timer = 0.25
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
	projectiles.clear()
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
			"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": starts[i],
			"color": colors[i], "tile": Vector2(i * 16, 112), "visual": "furina" if id == "hero_03" else ""
		}
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": id == "traveler", "cleave_ratio": 0.90, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0})
		heroes.append(h)

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
		"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": starts[i],
		"color": colors[i], "tile": Vector2(i * 16, 112), "visual": "furina" if character_id == "hero_03" else ""
	}
	hero.merge({"id": i, "max_hp": hero.hp, "target": hero.pos, "moving": false, "attack_timer": 0.0, "heal_timer": 1.0, "heal_power": HEAL_AMOUNT, "personal_heal_interval": 2.6, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": hero.damage, "base_hp": hero.hp, "base_rate": hero.rate, "cleave": false, "cleave_ratio": 0.45, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0, "crit_chance": 0.0})
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

func command_move(hero_id: int, point: Vector2) -> void:
	if state not in ["running", "between", "stage_exit"] or hero_id < 0 or hero_id >= heroes.size():
		return
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0:
		return
	var area := ENDLESS_ARENA if endless_mode else (STAGE_EXIT_AREA if state == "stage_exit" else MOVE_AREA)
	hero.target = _resolve_walkable_target(Vector2(clampf(point.x, area.position.x, area.end.x), clampf(point.y, area.position.y, area.end.y)))
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
	events.append({"kind": "formation", "pos": heroes[0].pos if not heroes.is_empty() else Vector2.ZERO, "value": next_mode})
	return true

func _load_terrain(stage_definition: Dictionary) -> void:
	terrain_features.clear()
	for value: Variant in stage_definition.get("terrain", []):
		if not value is Dictionary:
			continue
		var feature: Dictionary = value.duplicate(true)
		var raw_rect: Array = feature.get("rect", [])
		if raw_rect.size() < 4:
			continue
		feature.area = Rect2(float(raw_rect[0]), float(raw_rect[1]), float(raw_rect[2]), float(raw_rect[3]))
		feature.timer = minf(1.0, float(feature.get("interval", 4.0)))
		feature.hp = float(feature.get("hp", 0.0))
		feature.max_hp = float(feature.hp)
		terrain_features.append(feature)

func terrain_feature_at(point: Vector2, kind: String = "") -> Dictionary:
	for feature: Dictionary in terrain_features:
		if not kind.is_empty() and str(feature.get("type", "")) != kind:
			continue
		if feature.area.has_point(point):
			return feature
	return {}

func terrain_attack_scale(point: Vector2) -> float:
	var feature := terrain_feature_at(point, "high_ground")
	return 1.0 + float(feature.get("attack_bonus", 0.18)) if not feature.is_empty() else 1.0

func terrain_movement_scale(point: Vector2) -> float:
	var feature := terrain_feature_at(point, "low_ground")
	return float(feature.get("speed_scale", 0.72)) if not feature.is_empty() else 1.0

func _resolve_walkable_target(point: Vector2) -> Vector2:
	for feature: Dictionary in terrain_features:
		var blocks := str(feature.get("type", "")) == "blocked" or (str(feature.get("type", "")) == "shortcut" and float(feature.get("hp", 0.0)) > 0.0)
		if not blocks or not feature.area.has_point(point):
			continue
		var area: Rect2 = feature.area
		var candidates := [Vector2(area.position.x - 8.0, point.y), Vector2(area.end.x + 8.0, point.y), Vector2(point.x, area.position.y - 8.0), Vector2(point.x, area.end.y + 8.0)]
		candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(point) < b.distance_squared_to(point))
		return candidates[0]
	return point

func _terrain_blocks(point: Vector2) -> bool:
	return not _terrain_blocker_at(point).is_empty()

func _terrain_blocker_at(point: Vector2) -> Dictionary:
	for feature: Dictionary in terrain_features:
		var blocks := str(feature.get("type", "")) == "blocked" or (str(feature.get("type", "")) == "shortcut" and float(feature.get("hp", 0.0)) > 0.0)
		if blocks and feature.area.grow(7.0).has_point(point):
			return feature
	return {}

func _move_hero_with_terrain(hero: Dictionary, dt: float) -> void:
	var distance := float(hero.speed) * terrain_movement_scale(hero.pos) * dt
	var proposed: Vector2 = hero.pos.move_toward(hero.target, distance)
	var blocker := _terrain_blocker_at(proposed)
	if blocker.is_empty():
		hero.pos = proposed
		return
	var obstacle: Rect2 = blocker.area.grow(10.0)
	var detour_y := obstacle.position.y - 6.0 if hero.pos.y <= obstacle.get_center().y else obstacle.end.y + 6.0
	var tangent := Vector2(hero.pos.x, detour_y)
	var slide: Vector2 = hero.pos.move_toward(tangent, distance)
	if not _terrain_blocks(slide):
		hero.pos = slide

func damage_terrain_shortcuts(center: Vector2, radius: float, damage: float) -> int:
	var broken := 0
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) != "shortcut" or float(feature.get("hp", 0.0)) <= 0.0:
			continue
		if feature.area.get_center().distance_to(center) > radius:
			continue
		feature.hp = maxf(0.0, float(feature.hp) - damage)
		events.append({"kind": "terrain_hit", "pos": feature.area.get_center(), "value": ceili(damage)})
		if feature.hp <= 0.0:
			broken += 1
			events.append({"kind": "terrain_break", "pos": feature.area.get_center(), "value": str(feature.get("label", "捷径"))})
	return broken

func _terrain_tick(dt: float) -> void:
	if endless_mode:
		return
	for feature: Dictionary in terrain_features:
		if str(feature.get("type", "")) != "mechanism":
			continue
		feature.timer = maxf(0.0, float(feature.get("timer", 0.0)) - dt)
		if feature.timer > 0.0 or enemies.is_empty():
			continue
		var active: bool = heroes.any(func(hero: Dictionary) -> bool: return hero.hp > 0.0 and feature.area.grow(95.0).has_point(hero.pos))
		if not active:
			continue
		var hit_count := 0
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and enemy.pos.distance_to(feature.area.get_center()) <= float(feature.get("radius", 185.0)):
				apply_hit(enemy, float(feature.get("power", 60.0)), "pyro")
				hit_count += 1
		feature.timer = float(feature.get("interval", 3.5))
		if hit_count > 0:
			events.append({"kind": "mechanism_pulse", "pos": feature.area.get_center(), "value": hit_count})

func spawn_enemy(point: Vector2, kind: String = "grunt") -> Dictionary:
	var enemy: Dictionary = Catalog.ENEMIES[kind].duplicate(true)
	enemy.hp *= 1.0 + maxf(0.0, wave - 1) * 0.10
	if v2_mode and stage_runtime != null:
		enemy.hp *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		enemy.damage *= float(stage_runtime.definition.get("enemy_damage_multiplier", 1.0))
		enemy.speed *= float(stage_runtime.definition.get("enemy_speed_multiplier", 1.0))
		enemy.leak = maxi(1, roundi(float(enemy.leak) * float(stage_runtime.definition.get("enemy_leak_multiplier", 1.0))))
	next_id += 1
	var shield: float = float(enemy.get("shield", 0.0))
	if v2_mode and stage_runtime != null:
		shield *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
	var xp_values := {"grunt": 10, "runner": 8, "armored": 22, "flyer": 12, "ranged": 15, "buffer": 24, "shielded": 28, "charger": 20, "healer": 30, "splitter": 34, "warder": 32, "boss_01": 180, "boss_02": 240}
	var first_special: float = float(enemy.get("boss_pulse", enemy.get("heal_interval", enemy.get("ward_interval", 0.0))))
	enemy.merge({"id": next_id, "kind": kind, "pos": point, "max_hp": enemy.hp, "flash": 0.0, "attack_timer": 0.7, "blocked_by": -1, "aura": "", "aura_timer": 0.0, "reaction_timer": 0.0, "slow_timer": 0.0, "frozen_timer": 0.0, "haste_timer": 0.0, "shield": shield, "max_shield": shield, "special_timer": first_special, "split_done": false, "boss_phase": 1, "summons_done": 0, "route_points": [], "route_index": 0, "route_id": "", "xp": int(xp_values.get(kind, 10))})
	enemies.append(enemy)
	return enemy

func find_enemy(id: int) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id and enemy.hp > 0:
			return enemy
	return {}

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
	if state not in ["running", "between", "stage_exit"]:
		return
	elapsed += dt
	traveler_skill_cooldown = maxf(0.0, traveler_skill_cooldown - dt)
	if formation_mode == "follow" and not heroes.is_empty():
		for i in range(1, heroes.size()):
			var follow_angle := PI + (i - 1) * 1.15
			heroes[i].target = heroes[0].pos + Vector2.from_angle(follow_angle) * (82.0 + i * 12.0)
	for h in heroes:
		h.blocked = 0
		h.flash = maxf(0.0, h.flash - dt)
		h.moving = h.hp > 0 and h.pos.distance_to(h.target) > 0.5
		if h.moving:
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
	var traveler_down := endless_mode and (heroes.is_empty() or float(heroes[0].hp) <= 0.0)
	if base_hp <= 0 or traveler_down:
		state = "lost"
		projectiles.clear()
		events.append({"kind": "lost"})
		return
	_hero_tick()
	_projectile_tick(dt)
	_support_tick(dt)
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

func _endless_spawn_tick(dt: float) -> void:
	endless_spawn_timer -= dt
	if endless_spawn_timer > 0.0 or enemies.size() >= 180:
		return
	var tier := maxi(1, floori(elapsed / 50.0) + 1)
	var build_levels := 0
	for level: Variant in run_state.buff_levels.values():
		build_levels += int(level)
	var pool := ["grunt", "grunt", "runner", "runner"]
	if tier >= 2:
		pool.append("flyer")
	if tier >= 3:
		pool.append_array(["armored", "buffer", "charger"])
	if tier >= 3 and build_levels >= 5:
		pool.append("ranged")
	if tier >= 6 and build_levels >= 14:
		pool.append_array(["ranged", "ranged", "shielded", "healer", "splitter", "warder"])
	elif tier >= 5:
		pool.append_array(["shielded", "healer"])
	var batch := mini(6, 1 + floori((tier - 1) / 3.0))
	for i in batch:
		var side := (kills + next_id + i * 3) % 4
		var ratio := fposmod(sin(float(next_id + i * 19) * 12.9898) * 43758.5453, 1.0)
		var point := Vector2.ZERO
		match side:
			0: point = Vector2(ENDLESS_ARENA.position.x, lerpf(ENDLESS_ARENA.position.y, ENDLESS_ARENA.end.y, ratio))
			1: point = Vector2(ENDLESS_ARENA.end.x, lerpf(ENDLESS_ARENA.position.y, ENDLESS_ARENA.end.y, ratio))
			2: point = Vector2(lerpf(ENDLESS_ARENA.position.x, ENDLESS_ARENA.end.x, ratio), ENDLESS_ARENA.position.y)
			_: point = Vector2(lerpf(ENDLESS_ARENA.position.x, ENDLESS_ARENA.end.x, ratio), ENDLESS_ARENA.end.y)
		var kind: String = pool[(next_id + i * 5 + tier) % pool.size()]
		var enemy := spawn_enemy(point, kind)
		var health_scale := 1.0 + elapsed / 210.0 + pow(float(tier), 1.18) * 0.08
		enemy.hp *= health_scale
		enemy.max_hp = enemy.hp
		enemy.damage *= 1.0 + elapsed / 360.0
		events.append({"kind": "route_spawn", "pos": point, "route_id": "edge_%d" % side, "flying": bool(enemy.get("flying", false))})
	endless_spawn_timer += maxf(0.30, 1.55 - elapsed * 0.0018)
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
	skill_effects.clear()
	geo_constructs.clear()
	if not heroes.is_empty():
		heroes[0].target = heroes[0].pos

func _stage_spawn_tick(dt: float) -> void:
	for event: Dictionary in stage_runtime.tick(dt):
		if event.kind == "route_warning":
			events.append(event)
		elif event.kind == "spawn":
			wave = maxi(wave, int(event.get("wave", wave)))
			spawn_on_route(str(event.enemy_id), str(event.route_id))
		elif event.kind == "boss_wave":
			wave += 1
			var boss_id := str(event.enemy_id)
			var boss := spawn_on_route(boss_id, str(event.route_id))
			events.append({"kind": "wave", "value": wave})
			events.append({"kind": "boss_arrival", "pos": boss.pos, "value": str(boss.get("name", boss_id)), "enemy_id": boss.id})

func spawn_on_route(kind: String, route_id: String) -> Dictionary:
	var points := stage_route(route_id)
	var start := points[0] if not points.is_empty() else Vector2(1160, stage_lane_map().get(route_id, LANES[1]))
	var enemy := spawn_enemy(start, kind)
	enemy.route_points = points
	enemy.route_index = 1 if points.size() > 1 else 0
	enemy.route_id = route_id
	events.append({"kind": "route_spawn", "pos": start, "route_id": route_id, "flying": bool(enemy.get("flying", false))})
	return enemy

func _enemy_tick(dt: float) -> void:
	for source: Dictionary in enemies:
		if source.hp <= 0 or source.get("kind", "") != "buffer":
			continue
		for ally: Dictionary in enemies:
			if ally.hp > 0 and ally.id != source.id and ally.pos.distance_to(source.pos) <= float(source.get("aura_radius", 0.0)):
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
		var next_pos: Vector2 = e.pos.move_toward(destination, e.speed * speed_scale * dt)
		if not endless_mode and e.pos.distance_to(destination) <= maxf(4.0, e.speed * speed_scale * dt + 1.0):
			e.pos = destination
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
				if h.hp > 0 and e.pos.distance_to(h.pos) <= float(e.attack_range):
					if ranged_victim.is_empty() or e.pos.distance_to(h.pos) < e.pos.distance_to(ranged_victim.pos):
						ranged_victim = h
			if not ranged_victim.is_empty():
				next_pos = e.pos
		e.blocked_by = -1
		for h in heroes:
			if bool(e.get("flying", false)):
				break
			if h.hp <= 0 or (h.moving and not endless_mode) or h.blocked >= h.block:
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
				if h.hp > 0 and h.pos.distance_to(e.pos) <= 33:
					victim = h
					break
		if not construct_victim.is_empty() and e.attack_timer <= 0:
			damage_construct(int(construct_victim.id), e.damage)
			e.attack_timer = 1.0 / (e.rate * (1.25 if e.haste_timer > 0 else 1.0))
		elif not victim.is_empty() and e.attack_timer <= 0:
			damage_hero(victim.id, e.damage)
			if float(e.get("attack_range", 0.0)) > 0.0:
				events.append({"kind": "enemy_shot", "pos": e.pos, "target": victim.pos, "value": ceili(e.damage)})
			e.attack_timer = 1.0 / (e.rate * (1.25 if e.haste_timer > 0 else 1.0))
		if float(e.get("boss_pulse", 0.0)) > 0.0 and e.special_timer <= 0.0:
			for h: Dictionary in heroes:
				if h.hp > 0:
					damage_hero(h.id, e.damage * 0.42)
			if int(e.get("summon_count", 0)) > 0 and int(e.get("summons_done", 0)) < int(e.get("summon_limit", 4)):
				for summon in int(e.summon_count):
					var minion := spawn_enemy(e.pos + Vector2(45.0 + summon * 22.0, (summon - 1) * 48.0), "runner")
					minion.hp *= 0.72
					minion.max_hp = minion.hp
				e.summons_done = int(e.get("summons_done", 0)) + 1
				events.append({"kind": "boss_summon", "pos": e.pos, "value": int(e.summon_count)})
			e.special_timer = float(e.get("boss_pulse", 7.0))
			events.append({"kind": "boss_pulse", "pos": e.pos, "value": ceili(e.damage * 0.42)})
		elif e.get("kind", "") == "healer" and e.special_timer <= 0.0:
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

func damage_construct(id: int, damage: float) -> void:
	for construct: Dictionary in geo_constructs:
		if construct.id != id or construct.hp <= 0.0:
			continue
		construct.hp = maxf(0.0, float(construct.hp) - damage)
		events.append({"kind": "geo_hit", "pos": construct.pos, "value": ceili(damage)})
		if construct.hp <= 0.0:
			events.append({"kind": "geo_break", "pos": construct.pos})
		return

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
	var skill_bounds := ENDLESS_ARENA.grow(-36.0) if endless_mode else Rect2(170.0, 225.0, 970.0, 290.0)
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
			var targets: Array[Dictionary] = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0.0 and e.pos.distance_to(target) <= 380.0)
			targets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.distance_to(target) < b.pos.distance_to(target))
			for i in mini(8, targets.size()):
				apply_hit(targets[i], 155.0 * power * (1.0 - i * 0.055), "electro")
			events.append({"kind": "skill_electro", "pos": target, "value": targets.size()})
		"pyro":
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and enemy.pos.distance_to(target) <= 215.0 * area:
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
				if enemy.hp > 0.0 and enemy.pos.distance_to(target) <= 225.0 * area:
					enemy.slow_timer = maxf(float(enemy.slow_timer), 5.5 * duration)
					apply_hit(enemy, 105.0 * power, "cryo")
			skill_effects.append({"kind": "cryo_field", "pos": target, "life": 5.5 * duration, "pulse": 0.0, "power": power, "area": area})
			events.append({"kind": "skill_cryo", "pos": target, "value": traveler_skill_name()})
		_:
			for enemy: Dictionary in enemies.duplicate():
				if enemy.hp > 0.0 and enemy.pos.distance_to(target) <= 145.0:
					apply_hit(enemy, 125.0 * power, "")
					enemy.pos.x += 45.0
					events.append({"kind": "knockback", "pos": enemy.pos, "value": 45})
			events.append({"kind": "skill_none", "pos": target, "value": traveler_skill_name()})
	damage_terrain_shortcuts(target, traveler_skill_radius() * area, 240.0 * power)
	var secondary := normalize_element(str(heroes[0].get("secondary_element", "")))
	if not secondary.is_empty():
		var secondary_radius := traveler_skill_radius() * (1.0 + skill_area_bonus)
		for enemy: Dictionary in enemies.duplicate():
			if enemy.hp > 0.0 and enemy.pos.distance_to(target) <= secondary_radius:
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
				if enemy.hp <= 0.0:
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
	var damage: float = raw_damage * 100.0 / (100.0 + maxf(0, h.armor))
	h.hp = maxf(0, h.hp - damage)
	h.flash = 0.12
	events.append({"kind": "hurt", "pos": h.pos, "value": ceili(damage), "hero_id": id})
	if h.hp <= 0:
		h.target = h.pos
		h.moving = false
		h.blocked = 0
		for enemy in enemies:
			if enemy.blocked_by == id:
				enemy.blocked_by = -1
		events.append({"kind": "down", "pos": h.pos, "hero_id": id})

func _hero_tick() -> void:
	for h in heroes:
		if h.hp <= 0 or (h.moving and not endless_mode):
			continue
		if normalize_element(str(h.element)) == "hydro" and h.heal_timer <= 0:
			var ally: Dictionary = {}
			for other in heroes:
				if other.hp > 0 and other.hp < other.max_hp and h.pos.distance_to(other.pos) <= HEAL_RANGE:
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
		for e in enemies:
			var can_target_air: bool = bool(h.get("can_hit_air", false)) or (h.get("character_id", "") == "traveler" and h.get("element", "") != "")
			if e.hp > 0 and (not bool(e.get("flying", false)) or can_target_air) and is_in_attack_range(h, e.pos):
				available.append(e)
				if target.is_empty() or e.pos.x < target.pos.x:
					target = e
		if target.is_empty():
			continue
		h.attack_timer = 1.0 / h.rate
		h.shots += 1
		shots_fired += 1
		events.append({"kind": "shot", "pos": h.pos, "hero_id": h.id})
		var damage: float = h.damage * terrain_attack_scale(h.pos)
		var critical: bool = randf() < clampf(float(h.get("crit_chance", 0.0)), 0.0, 0.85)
		if critical:
			damage *= 2.0
		var attack_count: int = maxi(1, int(h.get("projectile_count", 1)))
		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x < b.pos.x)
		if h.block > 0:
			for strike in attack_count:
				var victim: Dictionary = available[strike % available.size()]
				if critical:
					events.append({"kind": "critical", "pos": victim.pos, "value": ceili(damage)})
				apply_hit(victim, damage if strike == 0 else damage * 0.72, h.element)
				var secondary := normalize_element(str(h.get("secondary_element", "")))
				if not secondary.is_empty() and victim.hp > 0.0:
					apply_hit(victim, (damage if strike == 0 else damage * 0.72) * 0.85, secondary)
				if h.cleave:
					splash_damage(victim, damage * float(h.get("cleave_ratio", 0.5)), 145.0 + float(h.get("pierce", 0)) * 18.0, h)
				events.append({"kind": "slash", "pos": victim.pos})
				_apply_attack_extras(victim, h, damage)
		else:
			for shot_index in attack_count:
				var shot_target: Dictionary = available[shot_index % available.size()]
				projectiles.append({"pos": h.pos + Vector2(14, -12 + (shot_index - (attack_count - 1) * 0.5) * 6.0), "target_id": shot_target.id, "damage": damage if shot_index == 0 else damage * 0.78, "element": h.element, "secondary_element": h.get("secondary_element", ""), "source_id": h.id, "splash": h.splash, "slow": h.slow, "pierce": int(h.get("pierce", 0)), "chain_count": int(h.get("chain_count", 0)), "blast_radius": float(h.get("blast_radius", 0.0)), "echo_ratio": float(h.get("echo_ratio", 0.0)), "critical": critical})
		if attack_count > 1:
			events.append({"kind": "multishot", "pos": h.pos, "value": attack_count})

func attack_range_screen_radii(hero: Dictionary) -> Vector2:
	var depth: float = StageProjection.depth_scale(hero.pos)
	var terrain_range_scale := 1.22 if not terrain_feature_at(hero.pos, "high_ground").is_empty() else 1.0
	var radius_x: float = minf(248.0, 35.0 + float(hero.range) * 0.56 * depth * terrain_range_scale)
	return Vector2(radius_x, radius_x * 0.30)

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

func apply_hit(enemy: Dictionary, raw_damage: float, element: String) -> float:
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
	if enemy.get("kind", "") in ["armored", "boss_01", "boss_02"]:
		damage *= 1.0 + elite_damage_bonus
	if execute_threshold > 0.0 and enemy.hp / enemy.max_hp <= minf(0.65, execute_threshold):
		damage *= 1.6
	enemy.hp -= damage
	enemy.flash = 0.1
	events.append({"kind": "hit", "pos": enemy.pos + Vector2(0, -12), "value": ceili(damage)})
	if enemy.hp > 0.0 and str(enemy.get("kind", "")).begins_with("boss_"):
		_update_boss_phase(enemy)
	if enemy.hp <= 0:
		if enemy.get("kind", "") == "splitter" and not bool(enemy.get("split_done", false)):
			enemy.split_done = true
			for i in int(enemy.get("split_count", 2)):
				var child := spawn_enemy(enemy.pos + Vector2(24.0 + i * 18.0, -22.0 + i * 44.0), "runner")
				child.hp *= 0.58
				child.max_hp = child.hp
				child.xp = 4
			events.append({"kind": "split", "pos": enemy.pos, "value": int(enemy.get("split_count", 2))})
		kills += 1
		kill_streak += 1
		kill_streak_timer = 2.5
		best_streak = maxi(best_streak, kill_streak)
		if kill_streak == 10 or kill_streak == 25 or kill_streak % 50 == 0:
			events.append({"kind": "kill_streak", "pos": enemy.pos, "value": kill_streak})
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
		events.append({"kind": "death", "pos": enemy.pos})
	return damage

func _update_boss_phase(enemy: Dictionary) -> void:
	var ratio: float = float(enemy.hp) / maxf(1.0, float(enemy.max_hp))
	var target_phase := 3 if ratio <= 0.35 else (2 if ratio <= 0.70 else 1)
	var current_phase := int(enemy.get("boss_phase", 1))
	if target_phase <= current_phase:
		return
	var jumps := target_phase - current_phase
	enemy.boss_phase = target_phase
	enemy.damage *= pow(1.18, jumps)
	enemy.speed *= pow(1.12, jumps)
	enemy.rate *= pow(1.10, jumps)
	enemy.boss_pulse = maxf(2.8, float(enemy.get("boss_pulse", 7.0)) * pow(0.82, jumps))
	enemy.special_timer = minf(float(enemy.special_timer), 0.8)
	var restored: float = float(enemy.get("max_shield", 0.0)) * (0.28 if target_phase == 2 else 0.42)
	enemy.shield = minf(float(enemy.get("max_shield", 0.0)), float(enemy.get("shield", 0.0)) + restored)
	var reinforcements := target_phase if enemy.get("kind", "") == "boss_02" else target_phase - 1
	for i in reinforcements:
		var kind := "charger" if target_phase == 3 and i == 0 else "runner"
		var minion := spawn_enemy(enemy.pos + Vector2(55.0 + i * 28.0, (i - 1) * 54.0), kind)
		minion.hp *= 0.70
		minion.max_hp = minion.hp
	events.append({"kind": "boss_phase", "pos": enemy.pos, "value": target_phase, "name": str(enemy.name), "shield": ceili(restored)})

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
			var dealt: float = apply_hit(target, shot.damage, shot.element)
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
	return roundi(55.0 + 38.0 * (level - 1) + 70.0 * sqrt(float(level - 1)))

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

func stage_route(route_id: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not v2_mode or stage_runtime == null:
		return result
	var configured: Dictionary = stage_runtime.definition.get("routes", {})
	for value in configured.get(route_id, []):
		if value is Array and value.size() >= 2:
			result.append(Vector2(float(value[0]), float(value[1])))
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
