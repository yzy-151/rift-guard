extends RefCounted

const Synergies = preload("res://scripts/rewards/card_synergies.gd")

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
	hero.card_attack_idle = minf(3.0, float(hero.get("card_attack_idle", 3.0)) + dt)
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
	var amount := 100.0 * warmog_levels * (1.5 if Synergies.hero_active(hero, "immortal_heart") else 1.0)
	var healed := minf(float(hero.max_hp) - float(hero.hp), amount)
	hero.hp = minf(float(hero.max_hp), float(hero.hp) + amount)
	return maxf(0.0, healed)

static func on_attack(hero: Dictionary) -> float:
	var tempo_levels := level(hero, "lethal_tempo")
	if tempo_levels > 0:
		var previous := float(hero.get("tempo_bonus", 0.0))
		var next_bonus := minf(1.20 * tempo_levels, previous + 0.12 * tempo_levels)
		hero.rate = float(hero.rate) + float(hero.base_rate) * (next_bonus - previous)
		hero.tempo_bonus = next_bonus
		hero.tempo_idle = 0.0
	var multiplier := 1.0
	var conqueror_levels := level(hero, "conqueror")
	if conqueror_levels > 0:
		hero.conqueror_attacks = int(hero.get("conqueror_attacks", 0)) + 1
		hero.hp = minf(float(hero.max_hp), float(hero.hp) + (15.0 if Synergies.hero_active(hero, "battle_fervor") else 10.0) * conqueror_levels)
		if hero.conqueror_attacks >= (4 if Synergies.hero_active(hero, "battle_fervor") else 6): multiplier *= pow(2.0, conqueror_levels)
	var strike_level := level(hero, "third_strike")
	if strike_level > 0:
		hero.card_third_attacks = int(hero.get("card_third_attacks", 0)) + 1
		if int(hero.card_third_attacks) % 3 == 0: multiplier *= 1.0 + 1.5 * strike_level
	if float(hero.get("card_attack_idle", 3.0)) >= 3.0:
		multiplier *= 1.0 + 0.8 * level(hero, "opening_strike")
	hero.card_attack_idle = 0.0
	if bool(hero.get("card_counter_ready", false)):
		multiplier *= 1.0 + 0.5 * level(hero, "counter_ready")
		hero.card_counter_ready = false
	hero.hp = minf(float(hero.max_hp), float(hero.hp) + level(hero, "attack_mend"))
	return multiplier

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
	hero.max_hp = float(hero.max_hp) + (15.0 if Synergies.hero_active(hero, "immortal_heart") else 10.0) * heartsteel_levels
