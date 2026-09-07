extends RefCounted
## Fixed-step gameplay, independent of scenes and visual effects.
const Rewards = preload("res://scripts/reward_book.gd")
const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CrystalProgression = preload("res://scripts/rewards/crystal_progression.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
const StageRuntime = preload("res://scripts/stages/stage_runtime.gd")
const XP_THRESHOLDS = [80, 190, 330, 500]
const Catalog = preload("res://scripts/combat_catalog.gd")
const MOVE_AREA = Rect2(185, 215, 475, 320)
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

func _init(seed_value: int = -1, enable_v2: bool = false) -> void:
	v2_mode = enable_v2
	if v2_mode:
		reset_stage("stage_01", ["traveler"], seed_value)
	else:
		reset(seed_value)

func reset(seed_value: int = -1) -> void:
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
	run_seed = seed_value if seed_value >= 0 else int(Time.get_ticks_usec() % 2147483647)
	team_xp = 0
	team_level = 1
	state = "ready"
	previous_state = "running"
	base_hp = 100
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
	heroes.clear()
	enemies.clear()
	projectiles.clear()
	events.clear()
	var starts := [Vector2(505, 360), Vector2(375, 295), Vector2(345, 430)]
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
			"hp": float(source.max_hp), "armor": float(source.armor), "damage": float(source.attack),
			"rate": float(source.attack_rate), "range": float(source.attack_range), "speed": float(source.move_speed),
			"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": starts[i],
			"color": colors[i], "tile": Vector2(i * 16, 112)
		}
		h.merge({"id": i, "max_hp": h.hp, "target": h.pos, "moving": false, "attack_timer": 0.0, "heal_timer": 1.0, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": h.damage, "base_hp": h.hp, "base_rate": h.rate, "cleave": id == "traveler", "cleave_ratio": 0.45, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0})
		heroes.append(h)

func _add_reinforcement(character_id: String) -> bool:
	if heroes.size() >= RunState.MAX_SQUAD_SIZE or not database.characters.has(character_id):
		return false
	var starts := [Vector2(505, 360), Vector2(375, 295), Vector2(345, 430)]
	var colors := ["#e9d7ad", "#eaaa7d", "#83c7e8"]
	var i: int = heroes.size()
	var source: Dictionary = database.characters[character_id]
	var element: String = "" if source.element == "none" else str(source.element)
	var hero := {
		"character_id": character_id, "name": source.name, "role": source.role, "element": element,
		"hp": float(source.max_hp), "armor": float(source.armor), "damage": float(source.attack),
		"rate": float(source.attack_rate), "range": float(source.attack_range), "speed": float(source.move_speed),
		"block": int(source.block), "can_hit_air": bool(source.can_hit_air), "pos": starts[i],
		"color": colors[i], "tile": Vector2(i * 16, 112)
	}
	hero.merge({"id": i, "max_hp": hero.hp, "target": hero.pos, "moving": false, "attack_timer": 0.0, "heal_timer": 1.0, "blocked": 0, "flash": 0.0, "shots": 0, "base_damage": hero.damage, "base_hp": hero.hp, "base_rate": hero.rate, "cleave": false, "cleave_ratio": 0.45, "splash": false, "slow": false, "projectile_count": 1, "pierce": 0, "chain_count": 0, "blast_radius": 0.0, "echo_ratio": 0.0})
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
	if state != "reward" or not rewards.take(index, self):
		return false
	if v2_mode:
		crystal.consume_choice(run_state)
		team_level = run_state.crystal_level
		team_xp = run_state.crystal_xp
		if run_state.pending_level_ups > 0:
			rewards.draw(self)
			state = "reward"
		else:
			state = "running"
		events.append({"kind": "reward_taken"})
		return true
	state = "between"
	wave_timer = 4.0
	events.append({"kind": "reward_taken"})
	return true

func toggle_pause() -> void:
	if state == "paused":
		state = previous_state
	elif state in ["running", "between"]:
		previous_state = state
		state = "paused"

func command_move(hero_id: int, point: Vector2) -> void:
	if state not in ["running", "between"] or hero_id < 0 or hero_id >= heroes.size():
		return
	var hero: Dictionary = heroes[hero_id]
	if hero.hp <= 0:
		return
	hero.target = Vector2(clampf(point.x, MOVE_AREA.position.x, MOVE_AREA.end.x), clampf(point.y, MOVE_AREA.position.y, MOVE_AREA.end.y))
	events.append({"kind": "move", "pos": hero.target, "hero_id": hero_id})

func spawn_enemy(point: Vector2, kind: String = "grunt") -> Dictionary:
	var enemy: Dictionary = Catalog.ENEMIES[kind].duplicate(true)
	enemy.hp *= 1.0 + maxf(0.0, wave - 1) * 0.10
	if v2_mode and stage_runtime != null:
		enemy.hp *= float(stage_runtime.definition.get("enemy_health_multiplier", 1.0))
		enemy.damage *= float(stage_runtime.definition.get("enemy_damage_multiplier", 1.0))
		enemy.speed *= float(stage_runtime.definition.get("enemy_speed_multiplier", 1.0))
	next_id += 1
	enemy.merge({"id": next_id, "kind": kind, "pos": point, "max_hp": enemy.hp, "flash": 0.0, "attack_timer": 0.7, "blocked_by": -1, "aura": "", "aura_timer": 0.0, "reaction_timer": 0.0, "slow_timer": 0.0, "xp": 20 if kind == "armored" else (8 if kind == "runner" else 10)})
	enemies.append(enemy)
	return enemy

func find_enemy(id: int) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id and enemy.hp > 0:
			return enemy
	return {}

func tick(dt: float) -> void:
	if state not in ["running", "between"]:
		return
	elapsed += dt
	for h in heroes:
		h.blocked = 0
		h.flash = maxf(0.0, h.flash - dt)
		h.moving = h.hp > 0 and h.pos.distance_to(h.target) > 0.5
		if h.moving:
			h.pos = h.pos.move_toward(h.target, h.speed * dt)
		h.attack_timer = maxf(0.0, h.attack_timer - dt)
		h.heal_timer = maxf(0.0, h.heal_timer - dt)
	if state == "between":
		wave_timer -= dt
		if wave_timer <= 0:
			begin_wave()
		return
	if v2_mode:
		_stage_spawn_tick(dt)
	else:
		_spawn_tick(dt)
	_enemy_tick(dt)
	if base_hp <= 0:
		state = "lost"
		projectiles.clear()
		events.append({"kind": "lost"})
		return
	_hero_tick()
	_projectile_tick(dt)
	_support_tick(dt)
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)
	if v2_mode:
		if stage_runtime.time_complete and stage_runtime.all_spawns_emitted and enemies.is_empty() and projectiles.is_empty():
			state = "won"
			events.append({"kind": "won"})
		return
	if spawn_remaining == 0 and enemies.is_empty() and projectiles.is_empty():
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

func _spawn_tick(dt: float) -> void:
	spawn_timer -= dt
	if spawn_remaining > 0 and spawn_timer <= 0:
		var encounter: Array = Catalog.WAVES[wave - 1]
		var index: int = encounter.size() - spawn_remaining
		var lane: int = (index + wave - 1) % 3
		spawn_enemy(Vector2(1160, LANES[lane]), encounter[index])
		spawn_remaining -= 1
		spawn_timer += 1.50 - wave * 0.10

func _stage_spawn_tick(dt: float) -> void:
	var lanes := {"upper": LANES[0], "main": LANES[1], "lower": LANES[2]}
	for event: Dictionary in stage_runtime.tick(dt):
		if event.kind == "spawn":
			wave = maxi(wave, int(event.get("wave", wave)))
			spawn_enemy(Vector2(1160, lanes.get(event.route_id, LANES[1])), str(event.enemy_id))
		elif event.kind == "boss_wave":
			wave += 1
			spawn_enemy(Vector2(1160, lanes.get(event.route_id, LANES[1])), str(event.enemy_id))
			events.append({"kind": "wave", "value": wave})

func _enemy_tick(dt: float) -> void:
	for e in enemies:
		if e.hp <= 0:
			continue
		e.flash = maxf(0, e.flash - dt)
		e.attack_timer = maxf(0, e.attack_timer - dt)
		e.aura_timer = maxf(0, e.aura_timer - dt)
		e.reaction_timer = maxf(0, e.reaction_timer - dt)
		e.slow_timer = maxf(0, e.slow_timer - dt)
		if e.aura_timer <= 0:
			e.aura = ""
		var next_x: float = e.pos.x - e.speed * (0.7 if e.slow_timer > 0 else 1.0) * dt
		e.blocked_by = -1
		for h in heroes:
			if h.hp <= 0 or h.moving or h.blocked >= h.block:
				continue
			if absf(e.pos.y - h.pos.y) <= 35 and e.pos.x >= h.pos.x - 5 and next_x <= h.pos.x + 40:
				e.blocked_by = h.id
				h.blocked += 1
				next_x = maxf(next_x, h.pos.x + 40)
				break
		e.pos.x = next_x
		var victim: Dictionary = {}
		if e.blocked_by >= 0:
			victim = heroes[e.blocked_by]
		else:
			for h in heroes:
				if h.hp > 0 and h.pos.distance_to(e.pos) <= 33:
					victim = h
					break
		if not victim.is_empty() and e.attack_timer <= 0:
			damage_hero(victim.id, e.damage)
			e.attack_timer = 1.0 / e.rate
		if e.pos.x <= 120:
			e.hp = 0.0
			base_hp = maxi(0, base_hp - e.leak)
			events.append({"kind": "leak", "pos": e.pos, "value": e.leak})
	enemies = enemies.filter(func(e: Dictionary) -> bool: return e.hp > 0)

func damage_hero(id: int, raw_damage: float) -> void:
	var h: Dictionary = heroes[id]
	if h.hp <= 0:
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
		if h.hp <= 0 or h.moving:
			continue
		if h.element == "water" and h.heal_timer <= 0:
			var ally: Dictionary = {}
			for other in heroes:
				if other.hp > 0 and other.hp < other.max_hp and h.pos.distance_to(other.pos) <= HEAL_RANGE:
					if ally.is_empty() or other.hp / other.max_hp < ally.hp / ally.max_hp:
						ally = other
			if not ally.is_empty():
				var healing: float = minf(heal_amount, ally.max_hp - ally.hp)
				ally.hp += healing
				h.heal_timer = heal_interval
				events.append({"kind": "heal", "pos": ally.pos, "value": ceili(healing)})
		if h.attack_timer > 0:
			continue
		var target: Dictionary = {}
		var available: Array[Dictionary] = []
		for e in enemies:
			if e.hp > 0 and h.pos.distance_to(e.pos) <= h.range:
				available.append(e)
				if target.is_empty() or e.pos.x < target.pos.x:
					target = e
		if target.is_empty():
			continue
		h.attack_timer = 1.0 / h.rate
		h.shots += 1
		shots_fired += 1
		events.append({"kind": "shot", "pos": h.pos, "hero_id": h.id})
		var damage: float = h.damage
		var attack_count: int = maxi(1, int(h.get("projectile_count", 1)))
		available.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pos.x < b.pos.x)
		if h.block > 0:
			for strike in attack_count:
				var victim: Dictionary = available[strike % available.size()]
				apply_hit(victim, damage if strike == 0 else damage * 0.72, h.element)
				if h.cleave:
					splash_damage(victim, damage * float(h.get("cleave_ratio", 0.5)), 75.0 + float(h.get("pierce", 0)) * 18.0)
				events.append({"kind": "slash", "pos": victim.pos})
				_apply_attack_extras(victim, h, damage)
		else:
			for shot_index in attack_count:
				var shot_target: Dictionary = available[shot_index % available.size()]
				projectiles.append({"pos": h.pos + Vector2(14, -12 + (shot_index - (attack_count - 1) * 0.5) * 6.0), "target_id": shot_target.id, "damage": damage if shot_index == 0 else damage * 0.78, "element": h.element, "source_id": h.id, "splash": h.splash, "slow": h.slow, "pierce": int(h.get("pierce", 0)), "chain_count": int(h.get("chain_count", 0)), "blast_radius": float(h.get("blast_radius", 0.0)), "echo_ratio": float(h.get("echo_ratio", 0.0))})
		if attack_count > 1:
			events.append({"kind": "multishot", "pos": h.pos, "value": attack_count})

func _apply_attack_extras(target: Dictionary, hero: Dictionary, damage: float) -> void:
	if float(hero.get("blast_radius", 0.0)) > 0.0:
		splash_damage(target, damage * 0.45, float(hero.blast_radius))
	if int(hero.get("chain_count", 0)) > 0:
		chain_damage(target, damage * 0.55, int(hero.chain_count))
	if float(hero.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
		apply_hit(target, damage * float(hero.echo_ratio), hero.element)
		events.append({"kind": "echo", "pos": target.pos})

func apply_hit(enemy: Dictionary, raw_damage: float, element: String) -> float:
	if enemy.is_empty() or enemy.hp <= 0:
		return 0.0
	var multiplier: float = 1.0
	if element != "":
		if enemy.aura != "" and enemy.aura != element and enemy.reaction_timer <= 0:
			multiplier = vapor_multiplier
			enemy.aura = ""
			enemy.aura_timer = 0.0
			enemy.reaction_timer = REACTION_COOLDOWN
			reactions += 1
			events.append({"kind": "vaporize", "pos": enemy.pos})
		elif enemy.aura == "" or enemy.aura == element:
			enemy.aura = element
			enemy.aura_timer = aura_duration
	var damage: float = raw_damage * multiplier * 100.0 / (100.0 + maxf(0, enemy.armor))
	if enemy.get("kind", "") in ["armored", "boss_01"]:
		damage *= 1.0 + elite_damage_bonus
	if execute_threshold > 0.0 and enemy.hp / enemy.max_hp <= minf(0.65, execute_threshold):
		damage *= 1.6
	enemy.hp -= damage
	enemy.flash = 0.1
	events.append({"kind": "hit", "pos": enemy.pos + Vector2(0, -12), "value": ceili(damage)})
	if enemy.hp <= 0:
		kills += 1
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

func _projectile_tick(dt: float) -> void:
	var surviving: Array[Dictionary] = []
	for shot in projectiles:
		var target: Dictionary = find_enemy(shot.target_id)
		if target.is_empty():
			continue
		var impact: Vector2 = target.pos + Vector2(0, -12)
		if shot.pos.distance_to(impact) <= PROJECTILE_SPEED * dt:
			apply_hit(target, shot.damage, shot.element)
			if shot.get("slow", false):
				target.slow_timer = 2.0
			if shot.get("splash", false):
				splash_damage(target, shot.damage * 0.5, 65.0)
			if float(shot.get("blast_radius", 0.0)) > 0.0:
				splash_damage(target, shot.damage * 0.45, float(shot.blast_radius))
			if int(shot.get("chain_count", 0)) > 0:
				chain_damage(target, shot.damage * 0.55, int(shot.chain_count))
			if float(shot.get("echo_ratio", 0.0)) > 0.0 and target.hp > 0:
				apply_hit(target, shot.damage * float(shot.echo_ratio), shot.element)
				events.append({"kind": "echo", "pos": target.pos})
			if int(shot.get("pierce", 0)) > 0:
				var next_target: Dictionary = _nearest_enemy_after(target, [target.id])
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

func _nearest_enemy_after(origin: Dictionary, excluded: Array) -> Dictionary:
	var result: Dictionary = {}
	for enemy: Dictionary in enemies:
		if enemy.hp <= 0 or enemy.id in excluded:
			continue
		if result.is_empty() or enemy.pos.distance_to(origin.pos) < result.pos.distance_to(origin.pos):
			result = enemy
	return result

func chain_damage(primary: Dictionary, damage: float, count: int) -> void:
	var current: Dictionary = primary
	var excluded: Array = [primary.id]
	for index in count:
		var next_target := _nearest_enemy_after(current, excluded)
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
		base_hp = mini(100, base_hp + ceili(float(support.power) * 0.35))
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

func splash_damage(primary: Dictionary, damage: float, radius: float) -> void:
	for enemy in enemies:
		if enemy.id != primary.id and enemy.hp > 0 and enemy.pos.distance_to(primary.pos) <= radius:
			apply_hit(enemy, damage, "")
	events.append({"kind": "splash", "pos": primary.pos})

func grant_xp(amount: int) -> void:
	if v2_mode:
		var gained: int = crystal.grant(run_state, amount)
		team_xp = run_state.crystal_xp
		team_level = run_state.crystal_level
		if gained > 0:
			events.append({"kind": "level_up", "value": run_state.crystal_level})
			if state == "running":
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

func element_name(element: String) -> String:
	return {"none": "无", "anemo": "风", "electro": "雷", "pyro": "火", "hydro": "水", "geo": "岩", "cryo": "冰"}.get(element, element)

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
		"armor_flat", "squad_armor_flat":
			for hero in targets: hero.armor += value
		"move_speed_flat":
			for hero in targets: hero.speed += value
		"special_upgrade":
			for hero in targets:
				hero.cleave = true
				hero.cleave_ratio = maxf(float(hero.get("cleave_ratio", 0.5)), 0.75)
		"signature_upgrade":
			for hero in targets:
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
		"crystal_heal": base_hp = mini(100, base_hp + int(value))
