extends RefCounted
## Numeric feedback has its own budget and is drawn after actors and scenery.
## A critical event is a flash; its hit event owns the single damage number.
const LIMIT := 90
const MERGE_WINDOW := 0.07
const NUMBER_FONT = preload("res://assets/fonts/BarlowCondensed-Black.ttf")
const HELL_RED := Color("#dc244c")
var active: Array[Dictionary] = []
var sequence := 0
var dropped := 0
var font: Font = NUMBER_FONT

func clear() -> void:
	active.clear()
	sequence = 0
	dropped = 0

func accept(view, batch: Array[Dictionary]) -> void:
	for event: Dictionary in batch:
		var kind := str(event.get("kind", ""))
		if kind not in ["hit", "hurt", "heal"] or not event.has("pos"):
			continue
		var value := int(event.get("value", 0))
		if value <= 0 or not view._render_point_visible(Vector2(event.pos), 60.0):
			continue
		var critical := kind == "hit" and bool(event.get("critical", false))
		var victim := int(event.get("enemy_id", -1)) if kind == "hit" else int(event.get("hero_id", -1))
		var identity := "%s:%d:%s" % [kind, victim, str(critical)]
		if victim < 0:
			identity += ":%d:%d" % [roundi(event.pos.x / 4.0), roundi(event.pos.y / 4.0)]
		var merged := false
		for index in range(active.size() - 1, -1, -1):
			var number: Dictionary = active[index]
			if float(number.age) <= MERGE_WINDOW and str(number.identity) == identity:
				number.value += value
				number.count += 1
				merged = true
				break
		if merged:
			continue
		if active.size() >= LIMIT:
			var expendable := -1
			for index in active.size():
				if str(active[index].kind) == "hit" and not bool(active[index].critical):
					expendable = index
					break
			if expendable < 0:
				if kind == "hit" and not critical:
					dropped += 1
					continue
				expendable = 0
			active.remove_at(expendable)
			dropped += 1
		sequence += 1
		active.append({"identity":identity, "kind":kind, "critical":critical,
			"pos":Vector2(event.pos), "value":value, "count":1, "age":0.0,
			"lane":float(sequence % 5 - 2), "life":0.86 if critical else 0.72})

func advance(dt: float) -> void:
	for number in active:
		number.age += dt
	active = active.filter(func(number: Dictionary) -> bool: return float(number.age) < float(number.life))

func draw(view) -> void:
	for number: Dictionary in active:
		var age := float(number.age)
		var critical := bool(number.critical)
		var kind := str(number.kind)
		var color := HELL_RED if critical else Color("#ffffff")
		if kind == "heal": color = Color("#69ffc6")
		elif kind == "hurt": color = Color("#ff7975")
		var alpha := clampf((float(number.life) - age) / 0.22, 0.0, 1.0)
		var pop := lerpf(0.88, 1.08, clampf(age / 0.055, 0.0, 1.0)) if age < 0.055 else lerpf(1.08, 1.0, clampf((age - 0.055) / 0.10, 0.0, 1.0))
		var point: Vector2 = view.world_to_screen(Vector2(number.pos)) + Vector2(float(number.lane) * 9.0, -46.0 - age * 22.0)
		point.y = maxf(110.0, point.y)
		var size := 19 if critical else (16 if kind == "hurt" else 15)
		var label := str(number.value)
		if kind == "heal": label = "+" + label
		elif kind == "hurt": label = "−" + label
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		view.draw_set_transform(point, 0.0, Vector2.ONE * pop)
		var baseline := Vector2(-width * 0.5, 0)
		if critical:
			view.draw_string_outline(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(color, alpha * 0.12))
		view.draw_string_outline(font, baseline + Vector2(0.5, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.03, 0.025, 0.07, alpha * 0.96))
		view.draw_string(font, baseline, label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(color, alpha))
		view.draw_set_transform(Vector2.ZERO)
