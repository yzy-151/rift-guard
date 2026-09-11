extends RefCounted

static func compile(ability: Dictionary, ultimate: bool = false) -> Dictionary:
	var source: Dictionary = ability.get("timeline", {})
	var duration := maxf(0.1, float(source.get("duration", 1.18 if ultimate else 0.72)))
	var hit := clampf(float(source.get("hit_frame", duration * float(ability.get("hit_frame_ratio", 0.5)))), 0.02, duration)
	return {
		"duration": duration,
		"anticipation": clampf(float(source.get("anticipation", hit * 0.65)), 0.0, hit),
		"vfx_frame": hit,
		"hit_frame": hit,
		"sfx_frame": hit,
		"recovery": maxf(0.0, float(source.get("recovery", duration - hit))),
		"shake": clampf(float(source.get("shake", 0.72 if ultimate else 0.32)), 0.0, 1.0),
	}

static func validate(ability: Dictionary) -> String:
	var timeline := compile(ability, false)
	if float(timeline.hit_frame) > float(timeline.duration):
		return "hit frame exceeds duration"
	if not is_equal_approx(float(timeline.sfx_frame), float(timeline.hit_frame)) or not is_equal_approx(float(timeline.vfx_frame), float(timeline.hit_frame)):
		return "impact cues must share the damage frame"
	return ""
