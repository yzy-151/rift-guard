extends RefCounted
## Dispatch only: materially different skills stay in their own choreography.
const G = preload("res://scripts/boss_vfx_geometry_20261006.gd")
const Slime = preload("res://scripts/slime_king_vfx_20261006.gd")
const Rift = preload("res://scripts/rift_commander_vfx_20261006.gd")
const Kindred = preload("res://scripts/kindred_skill_vfx_20261006.gd")
const Galio = preload("res://scripts/galio_skill_vfx_20261006.gd")
const Support = preload("res://scripts/support_fire_vfx_20261006.gd")
const MOVES := ["rift_laser","rift_orbs","rift_overhead","rift_storm","slime_bounce","slime_burst","slime_reflux","slime_court","kindred_dance","kindred_wolf","kindred_dread","kindred_hunt","kindred_lasers","galio_entrance","galio_punch","galio_winds","galio_durand"]
const EFFECTS := ["rift_laser","rift_orbs","rift_overhead","rift_storm","rift_orb_hit","slime_bounce","slime_burst","slime_reflux","slime_court","slime_bounce_hit","slime_glob_hit","slime_court_hit","slime_court_final","kindred_dance","kindred_wolf","kindred_dread","kindred_hunt","kindred_lasers","kindred_arrow_hit","kindred_wolf_strike","kindred_respite","kindred_respite_end","kindred_protect","galio_entrance","galio_punch","galio_winds","galio_winds_pulse","galio_durand","galio_guard","crossfire","barrage"]
static var rendering_enabled := true

static func prewarm() -> void:
	G.prewarm()

static func handles_effect(kind: String) -> bool:
	return kind in EFFECTS

static func draw_warning(v, enemy: Dictionary) -> bool:
	if not rendering_enabled or not bool(enemy.get("special_pending",false)): return false
	var kind := str(enemy.get("special_move",""))
	if kind.begins_with("slime_"): return Slime.warning(v,enemy)
	if kind.begins_with("rift_"): return Rift.warning(v,enemy)
	if kind.begins_with("kindred_"): return Kindred.warning(v,enemy)
	if kind.begins_with("galio_"): return Galio.warning(v,enemy)
	return false

static func draw_effect(v, effect: Dictionary) -> bool:
	if not rendering_enabled or not handles_effect(str(effect.get("kind",""))): return false
	var kind := str(effect.kind)
	if kind.begins_with("slime_"): return Slime.effect(v,effect)
	if kind.begins_with("rift_"): return Rift.effect(v,effect)
	if kind.begins_with("kindred_"): return Kindred.effect(v,effect)
	if kind.begins_with("galio_"): return Galio.effect(v,effect)
	return Support.effect(v,effect)

static func draw_projectile(v, projectile: Dictionary) -> bool:
	if not rendering_enabled: return false
	return Slime.projectile(v,projectile) or Rift.projectile(v,projectile) or Kindred.projectile(v,projectile)

static func draw_hazard(v, hazard: Dictionary) -> bool:
	if not rendering_enabled: return false
	return Slime.hazard(v,hazard) or Kindred.hazard(v,hazard) or Galio.hazard(v,hazard)

static func draw_support_warning(v, kind: String) -> bool:
	return Support.warning(v,kind) if rendering_enabled else false

static func draw_actor_overlays(v) -> void:
	if not rendering_enabled: return
	Galio.overlay(v)
	Kindred.overlay(v)

static func draw_persistent_ground(v) -> void:
	if rendering_enabled: Kindred.persistent_ground(v)
