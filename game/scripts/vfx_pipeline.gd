extends RefCounted

static func import_spec() -> Dictionary:
	return {
		"format":"PNG sequence or WebM with alpha",
		"color_space":"sRGB",
		"premultiplied_alpha":false,
		"frame_size":[512,512],
		"pivot":[0.5,0.72],
		"naming":"character_action_0001.png",
		"required_events":["anticipation","vfx","hit","sfx","recovery"],
	}

static func validate_profile(profile: Dictionary) -> bool:
	return int(profile.get("pool", 0)) > 0 and float(profile.get("lifetime", 0.0)) > 0.0 and str(profile.get("blend", "")) in ["add", "mix"]

static func validate_theme(theme: Dictionary) -> bool:
	return not str(theme.get("color", "")).is_empty() and not str(theme.get("impact", "")).is_empty()

static func color_for(theme: Dictionary, accent: bool = false) -> Color:
	return Color(str(theme.get("accent" if accent else "color", "#ffffff")))
