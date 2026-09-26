extends RefCounted

const SKILLS := ["kindred_dance", "kindred_wolf", "kindred_dread", "kindred_hunt", "kindred_respite", "galio_entrance", "galio_punch", "galio_winds", "galio_durand"]
const ACCENTS := ["kindred_arrow_hit", "kindred_wolf_strike", "kindred_respite_end"]

static func sources() -> Dictionary:
	var result := {}
	for skill: String in SKILLS:
		result[skill] = skill
		if skill != "kindred_respite":
			result[skill + "_charge"] = skill + "_charge"
	for accent: String in ACCENTS:
		result[accent] = accent
	return result

static func describe(event: Dictionary) -> Dictionary:
	var kind := str(event.get("kind", ""))
	var key := str(event.get("skill", "")) + "_charge" if kind == "boss_skill_charge" else kind
	if not key.begins_with("kindred_") and not key.begins_with("galio_"):
		return {}
	if key not in SKILLS and key not in ACCENTS and not (key.ends_with("_charge") and key.trim_suffix("_charge") in SKILLS):
		return {}
	var charge := key.ends_with("_charge")
	var accent := key in ACCENTS and key != "kindred_respite_end"
	return {"key":key, "volume_db":-12.0 if accent else (-9.0 if charge else -5.5), "pitch":2.0 / maxf(0.2, float(event.get("duration", 2.0))) if charge else 1.0, "min_interval":0.12 if accent else 0.05}
