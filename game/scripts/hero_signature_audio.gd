extends RefCounted
const SOUNDS := ["gwen_needles", "gwen_needle_hit", "amiya_shards", "amiya_chimera", "amiya_detonate", "furina_salon", "furina_stage", "furina_splash", "roxy_thunder", "neutral_slash", "neutral_starfall", "traveler_pyro_q", "traveler_pyro_e", "traveler_hydro_q", "traveler_hydro_e", "traveler_electro_q", "traveler_electro_e", "traveler_geo_q", "traveler_geo_e", "traveler_cryo_q", "traveler_cryo_e", "traveler_anemo_e"]
static func describe(event: Dictionary) -> Dictionary:
	var key := ""
	match str(event.get("kind", "")):
		"signature_start": key = str({"arcane_lance":"amiya_shards", "chimera":"amiya_chimera", "salon_summon":"furina_salon", "hydro_fanfare":"furina_stage"}.get(str(event.get("skill", "")), ""))
		"traveler_fx_start": key = "traveler_"+str(event.get("skill",""))
		"roxy_thunder": key = "roxy_thunder"
		"fireball_impact": key = "traveler_geo_e"
		"skill_impact":
			if str(event.get("character_id",""))=="traveler" and str(event.get("element","")) in ["","none"]: key="neutral_slash"
		"ultimate_impact":
			if str(event.get("character_id",""))=="traveler" and str(event.get("element","")) in ["","none"]: key="neutral_starfall"
		"signature_needle_volley": key = "gwen_needles"
		"signature_needle_hit": key = "gwen_needle_hit"
		"signature_chimera_pulse": key = "amiya_detonate"
		"signature_salon_hit": key = "furina_splash"
	if key.is_empty(): return {}
	return {"key":key,"volume_db":-10.0 if key in ["gwen_needle_hit","furina_splash","roxy_thunder"] else -4.0,"pitch":1.0,"min_interval":0.065 if key == "gwen_needle_hit" else 0.1}
