class_name StarfallSimulation
extends RefCounted

const Catalog = preload("res://starfall/catalog.gd")
const WORLD: Rect2 = Catalog.WORLD
const CORE: Vector2 = Catalog.CORE
var phase: String = "battle"
var mode: String = "campaign"
var heroes: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var events: Array[Dictionary] = []
var time: float = 0.0
var wave: int = 1
var wave_time: float = 0.0
var wave_duration: float = 30.0
var kills: int = 0
var combo: int = 0
var best_combo: int = 0
var coins: int = 0
var xp: float = 0.0
var xp_needed: float = 36.0
var level: int = 1
var core_hp: float = Catalog.CORE_HP
var max_core_hp: float = Catalog.CORE_HP
var selected: int = 0
var upgrades: Dictionary = {}
var upgrade_choices: Array[Dictionary] = []
var pending_upgrades: int = 0
var reroll_used: bool = false
var boss_spawned: bool = false
var spawn_timer: float = 1.0
var combo_timer: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _next_id: int = 1
var _frame: int = 0

func start(run_mode: String, squad: Array, seed_value: int = 0) -> void:
	mode = "endless" if run_mode == "endless" else "campaign"
	phase = "battle"
	heroes.clear()
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	pickups.clear()
	events.clear()
	upgrades.clear()
	upgrade_choices.clear()
	time = 0.0
	wave = 1
	wave_time = 0.0
	wave_duration = 30.0
	kills = 0
	combo = 0
	best_combo = 0
	combo_timer = 0.0
	coins = 0
	xp = 0.0
	xp_needed = 36.0
	level = 1
	core_hp = Catalog.CORE_HP
	max_core_hp = Catalog.CORE_HP
	selected = 0
	pending_upgrades = 0
	reroll_used = false
	boss_spawned = false
	spawn_timer = 1.0
	_next_id = 1
	_frame = 0
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	var defaults: Array[String] = ["traveler", "hero_03", "hero_08"]
	for i in range(3):
		var definition: Dictionary = Catalog.hero(str(squad[i]) if i < squad.size() else defaults[i])
		var position: Vector2 = Vector2(900 + i * 66, 730 + (26 if i == 1 else 0))
		var hero: Dictionary = _entity(definition.id, position, definition.hp, 19.0, definition.color)
		hero.merge({"character_id": definition.id, "name": definition.name, "element": definition.element, "q_cd": 0.0, "q_max": definition.q_cooldown, "energy": 25.0, "max_energy": 100.0, "dash_cd": 0.0, "dash_time": 0.0, "dash_dir": Vector2.RIGHT, "invuln": 0.0, "attack_timer": i * 0.18, "attack_pose": 0.0, "damage": definition.damage, "speed": definition.speed, "attack_interval": definition.attack_interval, "style": definition.attack_style, "skill": definition.skill})
		heroes.append(hero)
	_emit("wave", CORE, Color("ead6a1"), {"wave": wave, "act": 1, "label": "第一幕 · 月井初鸣"})

func _entity(kind: String, position: Vector2, health: float, radius: float, color: Color) -> Dictionary:
	var result: Dictionary = {"id": _next_id, "kind": kind, "pos": position, "hp": health, "max_hp": health, "vel": Vector2.ZERO, "face": 1.0, "anim": "idle", "anim_time": 0.0, "hit_flash": 0.0, "radius": radius, "color": color}
	_next_id += 1
	return result

func step(dt: float, movement: Vector2, aim: Vector2) -> void:
	if phase != "battle" or dt <= 0.0:
		return
	dt = minf(dt, 0.1)
	if core_hp <= 0.0:
		_finish(false)
		return
	time += dt
	wave_time += dt
	_frame += 1
	combo_timer = maxf(0.0, combo_timer - dt)
	if combo_timer == 0.0:
		combo = 0
	_step_heroes(dt, movement.limit_length(), aim)
	_step_spawning(dt)
	_step_enemies(dt)
	_step_projectiles(dt)
	_step_hazards(dt)
	_collect_deaths()
	_step_pickups(dt)
	if phase == "battle":
		_advance_wave()
	if core_hp <= 0.0:
		_finish(false)

func _step_heroes(dt: float, movement: Vector2, aim: Vector2) -> void:
	if heroes.is_empty():
		return
	var leader: Dictionary = heroes[selected]
	var companion_slot: int = 0
	for i in range(heroes.size()):
		var hero: Dictionary = heroes[i]
		hero.anim_time += dt
		hero.hit_flash = maxf(0.0, hero.hit_flash - dt)
		if hero.hp <= 0.0:
			hero.anim = "down"
			continue
		hero.q_cd = maxf(0.0, hero.q_cd - dt)
		hero.dash_cd = maxf(0.0, hero.dash_cd - dt)
		hero.invuln = maxf(0.0, hero.invuln - dt)
		hero.attack_timer -= dt
		hero.attack_pose = maxf(0.0, hero.attack_pose - dt)
		hero.energy = minf(100.0, hero.energy + dt * (1.1 + 0.25 * _stack("energy")))
		hero.hp = minf(hero.max_hp, hero.hp + 0.7 * _stack("regen") * dt)
		var direction: Vector2 = movement
		if i != selected:
			var side: float = -1.0 if companion_slot == 0 else 1.0
			companion_slot += 1
			var destination: Vector2 = _clamp_pos(leader.pos + Vector2(side * 76.0, 54.0), hero.radius)
			var difference: Vector2 = destination - hero.pos
			direction = difference.normalized() * minf(1.25, difference.length() / 55.0) if difference.length() > 16.0 else Vector2.ZERO
		var velocity: Vector2 = direction * hero.speed * (1.0 + 0.09 * _stack("stride"))
		if hero.dash_time > 0.0:
			hero.dash_time = maxf(0.0, hero.dash_time - dt)
			velocity = hero.dash_dir * Catalog.DASH_SPEED
		hero.vel = velocity
		hero.pos = _clamp_pos(hero.pos + velocity * dt, hero.radius)
		if absf(velocity.x) > 1.0:
			hero.face = signf(velocity.x)
		hero.anim = "attack" if hero.attack_pose > 0.0 else ("run" if velocity.length_squared() > 4.0 else "idle")
		if hero.attack_timer <= 0.0:
			var target: Dictionary = _attack_target(hero, aim if i == selected else hero.pos)
			if not target.is_empty():
				_auto_attack(hero, target)

func _attack_target(hero: Dictionary, aim: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var best: float = INF
	for enemy in enemies:
		if enemy.hp <= 0.0:
			continue
		var distance: float = hero.pos.distance_to(enemy.pos)
		if distance > 720.0:
			continue
		var score: float = distance + 0.25 * aim.distance_to(enemy.pos)
		if score < best:
			best = score
			result = enemy
	return result

func _auto_attack(hero: Dictionary, target: Dictionary) -> void:
	hero.attack_timer = hero.attack_interval / (1.0 + 0.14 * _stack("haste"))
	hero.attack_pose = 0.24
	hero.anim = "attack"
	hero.anim_time = 0.0
	hero.face = 1.0 if target.pos.x >= hero.pos.x else -1.0
	var direction: Vector2 = (target.pos - hero.pos).normalized()
	var count: int = 1 + _stack("multishot")
	for i in range(count):
		var offset: float = (i - (count - 1) * 0.5) * 0.13
		_shoot(hero.pos + direction * 20.0, direction.rotated(offset), _hero_damage(hero), "hero", hero.color, hero.style, hero.id, Catalog.HERO_PROJECTILE_SPEED, 7.0, _stack("pierce") + (_stack("gold_bond") if hero.element == "gold" else 0))

func cast(slot: String, aim: Vector2) -> bool:
	if phase != "battle" or heroes.is_empty() or (slot != "q" and slot != "e"):
		return false
	var hero: Dictionary = heroes[selected]
	if hero.hp <= 0.0:
		return false
	var ultimate: bool = slot == "e"
	if (ultimate and hero.energy < hero.max_energy) or (not ultimate and hero.q_cd > 0.0):
		return false
	if ultimate:
		hero.energy = 0.0
	else:
		hero.q_max = Catalog.hero(hero.character_id).q_cooldown * (1.0 - 0.09 * _stack("cooldown"))
		hero.q_cd = hero.q_max
	hero.attack_pose = 0.45
	hero.anim_time = 0.0
	var direction: Vector2 = (aim - hero.pos).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2(hero.face, 0)
	var target: Vector2 = hero.pos + (aim - hero.pos).limit_length(440.0)
	if hero.skill == "water_ring" or hero.skill == "wind_heal":
		target = hero.pos
	var power: float = _hero_damage(hero) * (4.0 if ultimate else 2.25)
	var radius: float = 260.0 if ultimate else 155.0
	var label: String = Catalog.hero(hero.character_id).e_name if ultimate else Catalog.hero(hero.character_id).q_name
	_emit("cast", hero.pos, hero.color, {"target": target, "style": hero.skill, "radius": radius, "label": label, "ultimate": ultimate, "owner": "hero"})
	match hero.skill:
		"star_blades", "needles":
			var count: int = (24 if ultimate else 7) if hero.skill == "needles" else (16 if ultimate else 3)
			for i in range(count):
				var angle: float = TAU * i / count if ultimate else (i - (count - 1) * 0.5) * 0.16
				_shoot(hero.pos, direction.rotated(angle), power, "hero", hero.color, "needle", hero.id, 790.0, 10.0, 4 + _stack("gold_bond"))
		"water_ring", "wind_heal":
			var field: Dictionary = _hazard(hero.pos, radius, 0.12, power, "hero", hero.color, hero.id, "circle")
			field.push = 90.0 * (1.0 + 0.25 * _stack("wind_bond"))
			field.slow = 1.0
			_heal_team((48.0 if ultimate else 20.0) * (1.0 + 0.25 * _stack("water_bond")))
			if ultimate:
				_hazard(CORE, 480.0, 0.55, power, "hero", hero.color, hero.id, "circle")
		"rain", "frost_zone":
			for i in range(5 if ultimate else 3):
				var field: Dictionary = _hazard(target, radius, 0.25 + i * 0.5, power * 0.6, "hero", hero.color, hero.id, "circle")
				field.slow = (2.8 + _stack("frost_bond") * 0.5) if hero.skill == "frost_zone" else 1.2
				field.freeze = hero.skill == "frost_zone"
		"moon_bloom":
			radius *= 1.0 + _stack("fire_bond") * 0.12
			for i in range(6 if ultimate else 3):
				var center: Vector2 = hero.pos + Vector2.RIGHT.rotated(i * TAU / 6.0) * 200.0 if ultimate else target + Vector2(rng.randf_range(-70, 70), rng.randf_range(-60, 60))
				_hazard(center, radius * 0.72, 0.3 + i * 0.18, power, "hero", hero.color, hero.id, "circle")
		"fire_line":
			radius *= 1.0 + _stack("fire_bond") * 0.12
			for i in range(6 if ultimate else 3):
				_hazard(hero.pos + direction * (85.0 + i * 90.0), radius * 0.7, 0.12 + i * 0.13, power, "hero", hero.color, hero.id, "circle")
		"chain":
			_chain(hero, 12 if ultimate else 6, power, target)
		"tornado":
			for i in range(3 if ultimate else 1):
				var field: Dictionary = _hazard(hero.pos, 95.0 if ultimate else 72.0, 2.8, power * 0.34, "hero", hero.color, hero.id, "circle")
				field.vel = direction.rotated((i - 1) * 0.35 if ultimate else 0.0) * 155.0
				field.interval = 0.28
				field.tick = 0.0
				field.push = 32.0 * (1.0 + 0.25 * _stack("wind_bond"))
				field.style = "tornado"
	return true

func dash(direction: Vector2) -> bool:
	if phase != "battle" or heroes.is_empty():
		return false
	var hero: Dictionary = heroes[selected]
	if hero.hp <= 0.0 or hero.dash_cd > 0.0:
		return false
	if direction.length_squared() < 0.01:
		direction = Vector2(hero.face, 0)
	hero.dash_dir = direction.normalized()
	hero.dash_time = Catalog.DASH_DURATION
	hero.dash_cd = Catalog.DASH_COOLDOWN * (1.0 - 0.07 * _stack("stride"))
	hero.invuln = 0.32
	_emit("dash", hero.pos, hero.color, {"dir": hero.dash_dir})
	return true

func select_hero(index: int) -> void:
	if index >= 0 and index < heroes.size() and heroes[index].hp > 0.0:
		selected = index

func hurt_hero(hero: Dictionary, amount: float) -> void:
	if hero.hp <= 0.0 or hero.invuln > 0.0 or phase == "won" or phase == "lost":
		return
	var actual: float = maxf(0.0, amount * (1.0 - 0.06 * _stack("resolve")))
	hero.hp = maxf(0.0, hero.hp - actual)
	hero.hit_flash = 0.22
	hero.invuln = 0.24
	_emit("hurt", hero.pos, Color("f4979c"), {"amount": actual, "hero_id": hero.id})
	if hero.hp <= 0.0:
		hero.anim = "down"
		hero.anim_time = 0.0
		_emit("death", hero.pos, hero.color, {"kind": hero.character_id, "owner": "hero"})
		var survivor: int = -1
		for i in range(heroes.size()):
			if heroes[i].hp > 0.0:
				survivor = i
				break
		if survivor < 0:
			_finish(false)
		elif heroes[selected].hp <= 0.0:
			selected = survivor

func spawn_enemy(kind: String, position: Vector2) -> Dictionary:
	if enemies.size() >= Catalog.MAX_ENEMIES:
		return {}
	var definition: Dictionary = Catalog.enemy(kind)
	var scale: float = 1.0 + (wave - 1) * 0.105
	var enemy: Dictionary = _entity(definition.kind, _clamp_pos(position, definition.radius), definition.hp * scale, definition.radius, definition.color)
	enemy.merge({"name": definition.name, "speed": definition.speed * minf(1.65, 1.0 + (wave - 1) * 0.018), "damage": definition.damage * (1.0 + (wave - 1) * 0.065), "xp": definition.xp, "interval": definition.interval, "attack_timer": rng.randf_range(0.6, 1.7), "state": "approach", "state_time": 0.0, "locked_dir": Vector2.LEFT, "facing_dir": Vector2.LEFT, "locked_target": CORE, "slow": 0.0, "freeze": 0.0, "pattern": 0, "boss_phase": 1})
	enemies.append(enemy)
	return enemy

func _step_spawning(dt: float) -> void:
	spawn_timer -= dt
	if wave % 3 == 0 and not boss_spawned:
		var boss: Dictionary = spawn_enemy("boss_01", Vector2(960, 235))
		if not boss.is_empty():
			boss_spawned = true
			_emit("boss", boss.pos, boss.color, {"wave": wave, "label": "裂隙统领", "phase": 1})
	if spawn_timer > 0.0:
		return
	spawn_timer = maxf(0.65, 1.85 - wave * 0.08)
	var options: Array[String] = ["grunt", "grunt", "runner", "ranged"]
	if wave >= 2:
		options.append("buffer")
		options.append("armored")
	if wave >= 4:
		options.append("splitter")
	for i in range(mini(4, 1 + wave / 3)):
		spawn_enemy(options[rng.randi_range(0, options.size() - 1)], _edge_position())

func _edge_position() -> Vector2:
	match rng.randi_range(0, 3):
		0: return Vector2(WORLD.position.x + 35, rng.randf_range(220, 1060))
		1: return Vector2(WORLD.end.x - 35, rng.randf_range(220, 1060))
		2: return Vector2(rng.randf_range(210, 1710), WORLD.position.y + 35)
		_: return Vector2(rng.randf_range(210, 1710), WORLD.end.y - 35)

func _enemy_target(enemy: Dictionary) -> Vector2:
	if enemy.id % 4 == 0 and enemy.kind != "boss_01":
		return CORE
	var nearest: Vector2 = CORE
	var best: float = INF
	for hero in heroes:
		if hero.hp <= 0.0:
			continue
		var distance: float = enemy.pos.distance_squared_to(hero.pos)
		if distance < best:
			best = distance
			nearest = hero.pos
	return nearest

func _step_enemies(dt: float) -> void:
	# A snapshot allows summoners to add entities during their turn.
	for enemy in enemies.duplicate():
		if enemy.hp <= 0.0:
			continue
		enemy.anim_time += dt
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - dt)
		enemy.slow = maxf(0.0, enemy.slow - dt)
		enemy.freeze = maxf(0.0, enemy.freeze - dt)
		enemy.vel = Vector2.ZERO
		# Save this frame's action-clock decision. A later frost impact takes
		# effect next frame for both the windup and its linked warning.
		enemy.action_paused = enemy.freeze > 0.0
		if enemy.action_paused:
			enemy.anim = "idle"
			continue
		enemy.attack_timer -= dt
		enemy.state_time -= dt
		if enemy.state == "windup":
			enemy.anim = "attack"
			if enemy.state_time <= 0.0:
				_resolve_enemy_attack(enemy)
			continue
		if enemy.state == "dash":
			var previous: Vector2 = enemy.pos
			enemy.vel = enemy.locked_dir * 560.0
			enemy.pos = _clamp_pos(enemy.pos + enemy.vel * dt, enemy.radius)
			for hero in heroes:
				if hero.hp > 0.0 and not hero.id in enemy.dash_hits and _segment_distance(hero.pos, previous, enemy.pos) < hero.radius + enemy.radius:
					hurt_hero(hero, enemy.damage)
					enemy.dash_hits.append(hero.id)
			if not -1 in enemy.dash_hits and _segment_distance(CORE, previous, enemy.pos) < 42.0 + enemy.radius:
				_hurt_core(enemy.damage * 0.72)
				enemy.dash_hits.append(-1)
			enemy.anim = "run"
			if enemy.state_time <= 0.0:
				enemy.state = "recover"
				enemy.state_time = 0.8
			continue
		if enemy.state == "recover":
			enemy.anim = "idle"
			if enemy.state_time <= 0.0:
				enemy.state = "approach"
			continue
		var target: Vector2 = _enemy_target(enemy)
		var difference: Vector2 = target - enemy.pos
		var distance: float = difference.length()
		var direction: Vector2 = difference.normalized()
		enemy.facing_dir = direction
		if absf(direction.x) > 0.1:
			enemy.face = signf(direction.x)
		var attack_range: float = 68.0
		match enemy.kind:
			"runner": attack_range = 300.0
			"ranged": attack_range = 480.0
			"buffer", "splitter": attack_range = 700.0
			"armored": attack_range = 120.0
			"boss_01": attack_range = 580.0
		if distance <= attack_range and enemy.attack_timer <= 0.0:
			_begin_enemy_attack(enemy, target)
			continue
		if enemy.kind == "ranged":
			if distance < 245.0:
				direction = -direction
			elif distance < 355.0:
				direction = direction.orthogonal() * 0.35
		elif enemy.kind == "buffer" or enemy.kind == "splitter":
			if distance < 280.0:
				direction *= -0.5
		elif distance < 48.0:
			direction = Vector2.ZERO
		var velocity: Vector2 = direction * enemy.speed * (0.46 if enemy.slow > 0.0 else 1.0)
		if _frame % 3 == 0:
			var separation: Vector2 = Vector2.ZERO
			for other in enemies:
				if other.id == enemy.id or other.hp <= 0.0:
					continue
				var delta: Vector2 = enemy.pos - other.pos
				var desired: float = (enemy.radius + other.radius) * 0.82
				var length_sq: float = delta.length_squared()
				if length_sq > 0.1 and length_sq < desired * desired:
					separation += delta.normalized() * (desired - sqrt(length_sq)) * 2.6
			enemy.pos = _clamp_pos(enemy.pos + separation.limit_length(110.0) * dt * 3.0, enemy.radius)
		enemy.vel = velocity
		enemy.pos = _clamp_pos(enemy.pos + velocity * dt, enemy.radius)
		enemy.anim = "run" if velocity.length_squared() > 4.0 else "idle"

func _begin_enemy_attack(enemy: Dictionary, target: Vector2) -> void:
	enemy.state = "windup"
	enemy.locked_target = target
	enemy.locked_dir = (target - enemy.pos).normalized()
	enemy.attack_timer = enemy.interval
	enemy.anim_time = 0.0
	var warning: float = 0.65
	match enemy.kind:
		"grunt":
			_hazard(target, 59.0, warning, enemy.damage, "enemy", Color("e99787"), enemy.id, "circle")
		"runner":
			warning = 0.7
			enemy.dash_hits = []
			var field: Dictionary = _hazard(enemy.pos, 24.0, warning, enemy.damage, "enemy", Color("edb574"), enemy.id, "line")
			field.preview = true
			field.dir = enemy.locked_dir
			field.length = 330.0
			field.width = 45.0
		"ranged":
			warning = 0.62
		"buffer":
			warning = 1.05
			var field: Dictionary = _hazard(enemy.pos, 245.0, warning, 0.0, "enemy", Color("a8dcab"), enemy.id, "circle")
			field.style = "heal"
		"armored":
			warning = 1.0
			_hazard(enemy.pos + enemy.locked_dir * 70.0, 104.0, warning, enemy.damage, "enemy", Color("e7a984"), enemy.id, "circle")
		"splitter":
			warning = 1.1
		"boss_01":
			var next_phase: int = 1 + int(enemy.hp < enemy.max_hp * 0.66) + int(enemy.hp < enemy.max_hp * 0.33)
			if next_phase != enemy.boss_phase:
				enemy.boss_phase = next_phase
				_emit("boss", enemy.pos, enemy.color, {"phase": next_phase, "label": "裂隙统领 · 阶段 %d" % next_phase})
			warning = maxf(0.8, 1.25 - enemy.boss_phase * 0.1)
			enemy.pattern = (enemy.pattern + 1) % 3
			if enemy.pattern == 1:
				_hazard(target, 130.0 + enemy.boss_phase * 18.0, warning, enemy.damage * 1.35, "enemy", enemy.color, enemy.id, "circle")
				if enemy.boss_phase >= 2:
					_hazard(CORE, 100.0, warning + 0.35, enemy.damage, "enemy", enemy.color, enemy.id, "circle")
	enemy.state_time = warning
	enemy.windup_duration = warning
	_emit("cast", enemy.pos, enemy.color, {"target": target, "style": "enemy_" + enemy.kind, "radius": 60.0, "label": "", "warning": warning, "owner": "enemy"})

func _resolve_enemy_attack(enemy: Dictionary) -> void:
	enemy.state = "recover"
	enemy.state_time = 0.35
	match enemy.kind:
		"runner":
			enemy.state = "dash"
			enemy.state_time = 0.5
		"ranged":
			for i in range(3):
				_shoot(enemy.pos, enemy.locked_dir.rotated((i - 1) * 0.17), enemy.damage, "enemy", Color("f0b592"), "arrow", enemy.id, 310.0, 7.0)
		"splitter":
			for i in range(2):
				spawn_enemy("runner" if i == 0 else "grunt", enemy.pos + Vector2(42, 0).rotated(i * PI))
		"boss_01":
			if enemy.pattern == 0:
				var count: int = 10 + enemy.boss_phase * 3
				for i in range(count):
					_shoot(enemy.pos, Vector2.RIGHT.rotated(TAU * i / count + time * 0.15), enemy.damage * 0.75, "enemy", enemy.color, "orb", enemy.id, 235.0 + enemy.boss_phase * 15.0, 10.0)
			elif enemy.pattern == 2:
				for i in range(5 + enemy.boss_phase * 2):
					_shoot(enemy.pos, enemy.locked_dir.rotated((i - (4 + enemy.boss_phase * 2) * 0.5) * 0.13), enemy.damage, "enemy", enemy.color, "shard", enemy.id, 330.0, 9.0)
			enemy.attack_timer = maxf(1.8, enemy.interval - 0.35 * enemy.boss_phase)

func _shoot(position: Vector2, direction: Vector2, damage: float, owner: String, color: Color, style: String, source_id: int, speed: float, radius: float, pierce: int = 0) -> void:
	if projectiles.size() >= Catalog.MAX_PROJECTILES:
		return
	projectiles.append({"pos": position, "prev_pos": position, "vel": direction.normalized() * speed, "life": 2.8 if owner == "hero" else 5.5, "radius": radius, "damage": damage, "owner": owner, "color": color, "style": style, "from_id": source_id, "pierce": pierce, "hits": []})
	_emit("shot", position, color, {"from": position, "to": position + direction * 50.0, "style": style, "owner": owner})

func _step_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		projectile.prev_pos = projectile.pos
		projectile.pos += projectile.vel * dt
		projectile.life -= dt
		if projectile.owner == "hero":
			for enemy in enemies:
				if enemy.hp <= 0.0 or enemy.id in projectile.hits:
					continue
				if _segment_distance(enemy.pos, projectile.prev_pos, projectile.pos) <= enemy.radius + projectile.radius:
					_damage_enemy(enemy, projectile.damage, projectile.from_id, projectile.prev_pos)
					projectile.hits.append(enemy.id)
					projectile.pierce -= 1
					if projectile.pierce < 0:
						projectile.life = 0.0
						break
		else:
			for hero in heroes:
				if hero.hp > 0.0 and _segment_distance(hero.pos, projectile.prev_pos, projectile.pos) <= hero.radius + projectile.radius:
					hurt_hero(hero, projectile.damage)
					projectile.life = 0.0
					break
			if projectile.life > 0.0 and _segment_distance(CORE, projectile.prev_pos, projectile.pos) < 47.0 + projectile.radius:
				_hurt_core(projectile.damage * 0.65)
				projectile.life = 0.0
		if projectile.life <= 0.0 or not WORLD.grow(80.0).has_point(projectile.pos):
			projectiles.remove_at(i)

func _hazard(position: Vector2, radius: float, delay: float, damage: float, owner: String, color: Color, source_id: int, kind: String) -> Dictionary:
	var field: Dictionary = {"pos": position, "radius": radius, "remaining": delay, "total": delay, "kind": kind, "dir": Vector2.RIGHT, "length": 180.0, "width": 50.0, "color": color, "damage": damage, "owner": owner, "source_id": source_id, "slow": 0.0, "freeze": false, "push": 0.0, "interval": 0.0, "tick": 0.0, "vel": Vector2.ZERO, "style": kind}
	field.created_frame = _frame
	if hazards.size() < Catalog.MAX_HAZARDS:
		hazards.append(field)
	return field

func _step_hazards(dt: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var field: Dictionary = hazards[i]
		if field.owner == "enemy":
			var source: Dictionary = _enemy_by_id(field.source_id)
			# Death interrupts uncommitted attacks; freeze pauses the same action
			# clock as the caster, including charge previews and healing channels.
			if source.is_empty() or source.hp <= 0.0:
				hazards.remove_at(i)
				continue
			if source.get("action_paused", false) or field.created_frame == _frame:
				continue
		field.remaining -= dt
		field.pos += field.vel * dt
		if field.interval > 0.0:
			field.tick -= dt
			if field.tick <= 0.0:
				field.tick = field.interval
				_resolve_hazard(field)
		elif field.remaining <= 0.0 and not field.get("preview", false):
			_resolve_hazard(field)
		if field.remaining <= 0.0:
			hazards.remove_at(i)

func _resolve_hazard(field: Dictionary) -> void:
	if field.style == "heal":
		for enemy in enemies:
			if enemy.hp > 0.0 and enemy.pos.distance_to(field.pos) < field.radius:
				var amount: float = minf(enemy.max_hp - enemy.hp, enemy.max_hp * 0.12)
				enemy.hp += amount
				if amount > 0.0:
					_emit("heal", enemy.pos, field.color, {"amount": amount})
		return
	if field.owner == "hero":
		for enemy in enemies:
			if enemy.hp > 0.0 and _hazard_contains(field, enemy.pos, enemy.radius):
				_damage_enemy(enemy, field.damage, field.source_id, field.pos)
				enemy.slow = maxf(enemy.slow, field.slow)
				if field.freeze:
					enemy.freeze = maxf(enemy.freeze, field.slow * (0.25 if enemy.kind == "boss_01" else 0.65))
				if field.push > 0.0:
					var direction: Vector2 = (enemy.pos - field.pos).normalized()
					enemy.pos = _clamp_pos(enemy.pos + direction * field.push * (0.2 if enemy.kind == "boss_01" else 1.0), enemy.radius)
	else:
		for hero in heroes:
			if hero.hp > 0.0 and _hazard_contains(field, hero.pos, hero.radius):
				hurt_hero(hero, field.damage)
		if _hazard_contains(field, CORE, 42.0):
			_hurt_core(field.damage * 0.72)
	_emit("cast", field.pos, field.color, {"target": field.pos, "style": "impact", "source_style": field.style, "effect": "damage", "radius": field.radius, "label": "", "owner": field.owner})

func _hazard_contains(field: Dictionary, position: Vector2, radius: float) -> bool:
	if field.kind == "line":
		return _segment_distance(position, field.pos, field.pos + field.dir * field.length) <= field.width * 0.5 + radius
	if field.kind == "cone":
		var difference: Vector2 = position - field.pos
		return difference.length() < field.length + radius and field.dir.dot(difference.normalized()) > cos(field.width * 0.5)
	return field.pos.distance_to(position) <= field.radius + radius

func _damage_enemy(enemy: Dictionary, base_damage: float, source_id: int, source_pos: Vector2) -> void:
	if enemy.hp <= 0.0:
		return
	var crit: bool = rng.randf() < 0.05 + 0.08 * _stack("crit")
	var damage: float = base_damage * (2.0 if crit else 1.0)
	if enemy.kind == "armored" and enemy.facing_dir.dot((source_pos - enemy.pos).normalized()) > 0.25:
		damage *= 0.45
	damage = minf(damage, enemy.hp)
	enemy.hp = maxf(0.0, enemy.hp - damage)
	enemy.hit_flash = 0.16
	_emit("hit", enemy.pos, enemy.color, {"amount": damage, "crit": crit})
	for hero in heroes:
		if hero.id == source_id:
			hero.energy = minf(100.0, hero.energy + (1.1 + damage * 0.015) * (1.0 + 0.25 * _stack("energy")))
			if hero.hp > 0.0 and _stack("lifesteal") > 0:
				hero.hp = minf(hero.max_hp, hero.hp + damage * 0.02 * _stack("lifesteal"))
			break

func _chain(hero: Dictionary, count: int, damage: float, aim: Vector2) -> void:
	var used: Array[int] = []
	var previous: Vector2 = hero.pos
	for i in range(count + _stack("lightning_bond")):
		var best: Dictionary = {}
		var distance: float = 620.0 if i == 0 else 260.0
		for enemy in enemies:
			if enemy.hp <= 0.0 or enemy.id in used:
				continue
			var current: float = previous.distance_to(enemy.pos)
			if i == 0:
				current += aim.distance_to(enemy.pos) * 0.12
			if current < distance:
				distance = current
				best = enemy
		if best.is_empty():
			break
		used.append(best.id)
		_emit("shot", previous, hero.color, {"from": previous, "to": best.pos, "style": "chain", "owner": "hero"})
		_damage_enemy(best, damage, hero.id, previous)
		previous = best.pos

func _collect_deaths() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy.hp > 0.0:
			continue
		kills += 1
		combo += 1
		best_combo = maxi(best_combo, combo)
		combo_timer = 3.5
		coins += 12 if enemy.kind == "boss_01" else 1
		_emit("death", enemy.pos, enemy.color, {"kind": enemy.kind, "owner": "enemy"})
		_add_pickup(enemy.pos, enemy.xp, "xp")
		if rng.randf() < 0.09:
			_add_pickup(enemy.pos + Vector2(13, -8), 12.0, "heal")
		if enemy.kind == "boss_01" and phase != "lost":
			_heal_team(25.0)
			core_hp = minf(max_core_hp, core_hp + 90.0)
		enemies.remove_at(i)

func _add_pickup(position: Vector2, amount: float, kind: String) -> void:
	if pickups.size() >= Catalog.MAX_PICKUPS:
		# Merge experience rather than losing it or growing the pool.
		for pickup in pickups:
			if pickup.kind == kind:
				pickup.amount += amount
				pickup.life = 90.0
				return
		return
	pickups.append({"pos": position, "amount": amount, "kind": kind, "radius": 8.0, "life": 90.0, "color": Color("b7e3df") if kind == "xp" else Color("f4b8ba")})

func _step_pickups(dt: float) -> void:
	if heroes.is_empty() or phase == "won" or phase == "lost":
		return
	var target: Dictionary = heroes[selected]
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		pickup.life -= dt
		var distance: float = pickup.pos.distance_to(target.pos)
		if distance < 115.0 + 65.0 * _stack("magnet") or pickup.life < 3.0:
			pickup.pos = pickup.pos.move_toward(target.pos, (290.0 + 250.0 * (1.0 - minf(distance / 300.0, 1.0))) * dt)
		if pickup.pos.distance_to(target.pos) < 25.0:
			if pickup.kind == "xp":
				grant_xp(pickup.amount * (1.0 + 0.1 * _stack("magnet")))
			else:
				_heal_team(pickup.amount)
			_emit("pickup", pickup.pos, pickup.color, {"kind": pickup.kind, "amount": pickup.amount})
			pickups.remove_at(i)
		elif pickup.life <= 0.0:
			pickups.remove_at(i)

func grant_xp(amount: float) -> void:
	if amount <= 0.0 or phase == "won" or phase == "lost":
		return
	xp += amount
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = 36.0 + (level - 1) * 19.0
		pending_upgrades += 1
	if pending_upgrades > 0 and phase != "upgrade":
		_open_draft()

func _open_draft() -> void:
	phase = "upgrade"
	reroll_used = false
	_roll_choices()
	_emit("level", heroes[selected].pos, Color("f4daa1"), {"level": level, "label": "星辉赐福"})

func _roll_choices() -> void:
	var available: Array[Dictionary] = []
	var elements: Array[String] = []
	for hero in heroes:
		elements.append(hero.element)
	for entry in Catalog.upgrades():
		if _stack(entry.id) >= entry.max_stacks:
			continue
		if entry.id.ends_with("_bond") and not entry.id.trim_suffix("_bond") in elements:
			continue
		available.append(entry)
	upgrade_choices.clear()
	for i in range(mini(3, available.size())):
		var index: int = rng.randi_range(0, available.size() - 1)
		upgrade_choices.append(available[index])
		available.remove_at(index)

func choose_upgrade(id: String) -> bool:
	if phase != "upgrade":
		return false
	var selected_option: Dictionary = {}
	for option in upgrade_choices:
		if option.id == id:
			selected_option = option
			break
	if selected_option.is_empty() or _stack(id) >= selected_option.max_stacks:
		return false
	upgrades[id] = _stack(id) + 1
	match id:
		"vitality":
			for hero in heroes:
				hero.max_hp += 30.0
				if hero.hp > 0.0:
					hero.hp = minf(hero.max_hp, hero.hp + 30.0)
		"core_repair":
			max_core_hp += 60.0
			core_hp = minf(max_core_hp, core_hp + 150.0)
		"respite":
			_heal_team(40.0)
			core_hp = minf(max_core_hp, core_hp + 60.0)
		"stardust":
			coins += 30
			for hero in heroes:
				hero.energy = minf(100.0, hero.energy + 12.0)
		"energy":
			for hero in heroes:
				hero.energy = minf(100.0, hero.energy + 20.0)
		"cooldown":
			for hero in heroes:
				hero.q_max = Catalog.hero(hero.character_id).q_cooldown * (1.0 - 0.09 * _stack("cooldown"))
				hero.q_cd = minf(hero.q_cd, hero.q_max)
	pending_upgrades = maxi(0, pending_upgrades - 1)
	upgrade_choices.clear()
	if pending_upgrades > 0:
		_open_draft()
	else:
		phase = "battle"
	return true

func reroll() -> bool:
	if phase != "upgrade" or reroll_used:
		return false
	reroll_used = true
	_roll_choices()
	return true

func _advance_wave() -> void:
	if wave_time < wave_duration:
		return
	if wave % 3 == 0:
		if not boss_spawned:
			return
		for enemy in enemies:
			if enemy.kind == "boss_01" and enemy.hp > 0.0:
				return
	if mode == "campaign" and wave >= 9:
		_finish(true)
		return
	wave += 1
	wave_time = 0.0
	boss_spawned = false
	spawn_timer = minf(spawn_timer, 0.8)
	_heal_team(12.0)
	core_hp = minf(max_core_hp, core_hp + 22.0)
	_emit("wave", CORE, Color("ead6a1"), {"wave": wave, "act": 1 + (wave - 1) / 3, "label": "第 %d 波" % wave})
	if wave % 3 == 0:
		_step_spawning(0.0)

func _finish(won: bool) -> void:
	if phase == "won" or phase == "lost":
		return
	phase = "won" if won else "lost"
	upgrade_choices.clear()
	_emit("win" if won else "lose", CORE, Color("e9d8a4") if won else Color("eaa5aa"), {"wave": wave, "kills": kills, "time": time})

func _hurt_core(amount: float) -> void:
	core_hp = maxf(0.0, core_hp - amount)
	_emit("core_hit", CORE, Color("f59f9b"), {"amount": amount})
	if core_hp <= 0.0:
		_finish(false)

func _heal_team(amount: float) -> void:
	for hero in heroes:
		if hero.hp <= 0.0:
			continue
		var actual: float = minf(hero.max_hp - hero.hp, amount)
		hero.hp += actual
		if actual > 0.0:
			_emit("heal", hero.pos, Color("b6dfb9"), {"amount": actual})

func _hero_damage(hero: Dictionary) -> float:
	return hero.damage * (1.0 + 0.18 * _stack("power") + 0.30 * _stack(hero.element + "_bond") + 0.03 * _stack("training"))

func _stack(id: String) -> int:
	return int(upgrades.get(id, 0))

func _enemy_by_id(id: int) -> Dictionary:
	for enemy in enemies:
		if enemy.id == id:
			return enemy
	return {}

func _clamp_pos(position: Vector2, radius: float) -> Vector2:
	return Vector2(clampf(position.x, WORLD.position.x + radius, WORLD.end.x - radius), clampf(position.y, WORLD.position.y + radius, WORLD.end.y - radius))

func _segment_distance(point: Vector2, from: Vector2, to: Vector2) -> float:
	var delta: Vector2 = to - from
	var length_sq: float = delta.length_squared()
	if length_sq < 0.0001:
		return point.distance_to(from)
	var fraction: float = clampf((point - from).dot(delta) / length_sq, 0.0, 1.0)
	return point.distance_to(from + delta * fraction)

func _emit(type: String, position: Vector2, color: Color, extra: Dictionary = {}) -> void:
	var event: Dictionary = {"type": type, "pos": position, "color": color}
	event.merge(extra, true)
	if events.size() >= Catalog.MAX_EVENTS:
		events.pop_front()
	events.append(event)

func drain_events() -> Array[Dictionary]:
	var result: Array[Dictionary] = events.duplicate()
	events.clear()
	return result
