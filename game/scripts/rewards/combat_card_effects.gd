extends RefCounted

# Character-scoped card state lives on the hero so it survives stage snapshots.
static func apply_to_hero(hero: Dictionary, effect: String) -> void:
	var levels: Dictionary = hero.get("card_levels", {})
	levels[effect] = int(levels.get(effect, 0)) + 1
	hero.card_levels = levels
	if effect == "warmogs_armor" and not hero.has("warmog_timer"):
		hero.warmog_timer = 5.0

static func level(hero: Dictionary, effect: String) -> int:
	return int(hero.get("card_levels", {}).get(effect, 0))

static func tick(hero: Dictionary, dt: float) -> float:
	var tempo_bonus := float(hero.get("tempo_bonus", 0.0))
	if tempo_bonus > 0.0:
		hero.tempo_idle = float(hero.get("tempo_idle", 0.0)) + dt
		if hero.tempo_idle >= 3.0:
			hero.rate = maxf(0.1, float(hero.rate) - float(hero.base_rate) * tempo_bonus)
			hero.tempo_bonus = 0.0
			hero.tempo_idle = 0.0
	var warmog_levels := level(hero, "warmogs_armor")
	if warmog_levels <= 0 or float(hero.hp) <= 0.0:
		return 0.0
	hero.warmog_timer = float(hero.get("warmog_timer", 5.0)) - dt
	if hero.warmog_timer > 0.0:
		return 0.0
	hero.warmog_timer += 5.0
	var healed := minf(float(hero.max_hp) - float(hero.hp), 100.0 * warmog_levels)
	hero.hp = minf(float(hero.max_hp), float(hero.hp) + 100.0 * warmog_levels)
	return maxf(0.0, healed)

static func on_attack(hero: Dictionary) -> float:
	var tempo_levels := level(hero, "lethal_tempo")
	if tempo_levels > 0:
		var previous := float(hero.get("tempo_bonus", 0.0))
		var next_bonus := minf(1.20 * tempo_levels, previous + 0.12 * tempo_levels)
		hero.rate = float(hero.rate) + float(hero.base_rate) * (next_bonus - previous)
		hero.tempo_bonus = next_bonus
		hero.tempo_idle = 0.0
	var conqueror_levels := level(hero, "conqueror")
	if conqueror_levels <= 0:
		return 1.0
	hero.conqueror_attacks = int(hero.get("conqueror_attacks", 0)) + 1
	hero.hp = minf(float(hero.max_hp), float(hero.hp) + 10.0 * conqueror_levels)
	return pow(2.0, conqueror_levels) if hero.conqueror_attacks >= 6 else 1.0

static func on_target(hero: Dictionary, enemy: Dictionary) -> void:
	var heartsteel_levels := level(hero, "heartsteel")
	if heartsteel_levels <= 0:
		return
	var attackers: Dictionary = enemy.get("heartsteel_attackers", {})
	var hero_id := int(hero.id)
	if attackers.has(hero_id):
		return
	attackers[hero_id] = true
	enemy.heartsteel_attackers = attackers
	hero.max_hp = float(hero.max_hp) + 10.0 * heartsteel_levels
