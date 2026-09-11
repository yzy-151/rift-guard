extends RefCounted

const REACTION_ALIASES := {"overloaded":"overload","electro_charged":"electro_charged","frozen":"freeze","crystallize":"crystallize","superconduct":"superconduct","swirl":"swirl","vaporize":"vaporize","melt":"melt"}
const IMPACT_KINDS := ["hit","synced_impact","critical","skill_impact","ultimate_impact","shield_break","terrain_break","orbit_hit","orbit_storm"]

var themes: Dictionary = {}
var impact_history: Array[Dictionary] = []
var last_impact_frame := -1

func setup(database) -> void:
	themes = database.vfx_themes if database != null else {}

func theme_id(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	if REACTION_ALIASES.has(kind):
		return str(REACTION_ALIASES[kind])
	var element := str(event.get("element", ""))
	return element if themes.has(element) else "neutral"

func observe(event: Dictionary) -> Dictionary:
	var id := theme_id(event)
	var theme: Dictionary = themes.get(id, themes.get("neutral", {}))
	if str(event.get("kind", "")) in IMPACT_KINDS:
		last_impact_frame = Engine.get_physics_frames()
		impact_history.append({"frame":last_impact_frame,"kind":event.get("kind", ""),"theme":id})
		if impact_history.size() > 64:
			impact_history.pop_front()
	return {"theme_id":id,"theme":theme,"impact":str(event.get("kind", "")) in IMPACT_KINDS,"frame":last_impact_frame}

func synchronized(event: Dictionary) -> bool:
	var timeline: Dictionary = event.get("timeline", {})
	if timeline.is_empty():
		return true
	return is_equal_approx(float(timeline.get("hit_frame", 0.0)), float(timeline.get("vfx_frame", -1.0))) and is_equal_approx(float(timeline.get("hit_frame", 0.0)), float(timeline.get("sfx_frame", -1.0)))
