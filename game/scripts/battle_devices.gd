extends RefCounted
## One-cell battlefield purchases. Card modifiers apply to old and future plants.
const ITEMS := {
	"power": {"name":"攻击格", "price":100, "description":"格内角色攻击 +35%，可被机关卡强化"},
	"range": {"name":"射程格", "price":120, "description":"格内角色射程 +30%，可被机关卡强化"},
	"barricade": {"name":"坚果墙", "price":90, "description":"阻挡地面敌人，受损开裂，可被攻破"},
	"mine": {"name":"土豆雷", "price":140, "description":"埋下 3 秒后武装，敌人踩中时范围爆炸"},
	"pea": {"name":"豌豆射手", "price":180, "description":"沿所在行向右射击，可升级双发、三线和机枪"},
	"snowpea": {"name":"寒冰射手", "price":240, "description":"豌豆减速 20%，持续 2 秒"},
	"sunflower": {"name":"向日葵", "price":100, "description":"每 8 秒产出 20 金币，可被敌人攻破"},
	"spikeweed": {"name":"地刺", "price":120, "description":"持续伤害经过此格的地面敌人"},
	"melon": {"name":"西瓜投手", "price":320, "description":"向固定落点抛射西瓜，落地造成范围伤害"},
	"cherry": {"name":"樱桃炸弹", "price":220, "description":"部署 1 秒后爆炸，清理周围敌人"}
}
const CARD_IDS: Array[String] = ["device_botanist", "device_repeater", "device_threepeater", "device_gatling", "device_melon", "device_frost", "device_iron_nut", "device_nut_repair", "device_power_pad", "device_range_pad", "device_soil_discount", "device_photosynthesis", "device_quick_growth", "device_mine_chain", "device_rooted", "device_salvage"]
const BLOCKING_PLANTS: Array[String] = ["barricade", "pea", "snowpea", "sunflower", "melon"]
var enabled := false
var gold := 0
var limit := 25
var selected_kind := ""
var message := ""
var valid := false
var hover_cell := Rect2()
var placed: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var feedback_timer := 0.0
var serial := 0
var card_levels: Dictionary = {}
var card_limits: Dictionary = {}
var modifier_signature := ""
var muzzle_shots: Dictionary = {}

func reset(sim) -> void:
	enabled = sim.v2_mode and not sim.endless_mode and not sim.workshop_mode
	if sim.run_state != null: sim.run_state.device_cards_enabled = enabled
	gold = 120 if enabled else 0
	limit = 25
	selected_kind = ""
	message = "点击种子，再点击地格部署 · 右键 / Esc 取消"
	valid = false
	hover_cell = Rect2()
	placed.clear()
	shots.clear()
	muzzle_shots.clear()
	card_levels.clear()
	card_limits.clear()
	if sim.database != null:
		for card: Dictionary in sim.database.cards:
			if str(card.get("id","")) in CARD_IDS: card_limits[str(card.id)] = maxi(1,int(card.get("max_stacks",1)))
	modifier_signature = ""
	serial = 0
	feedback_timer = 6.0
	sync_modifiers(sim)

func snapshot(sim) -> Dictionary:
	sync_modifiers(sim)
	var items := ITEMS.duplicate(true)
	for kind: String in items: items[kind].price = price_of(kind)
	return {"enabled":enabled and not sim.workshop_mode and sim.state in ["ready","running","between","paused","reward"], "gold":gold, "used":active_count(), "limit":limit, "items":items, "selected_kind":selected_kind, "message":message, "valid":valid}

func level(card_id: String) -> int:
	return int(card_levels.get(card_id, 0))

func price_of(kind: String) -> int:
	return ceili(float(ITEMS.get(kind, {}).get("price", 0)) * (1.0 - 0.1 * mini(3, level("device_soil_discount"))))

func sync_modifiers(sim) -> void:
	var levels: Dictionary = sim.run_state.buff_levels if sim.run_state != null else {}
	var values: Array[int] = []
	for card_id: String in CARD_IDS: values.append(clampi(int(levels.get(card_id,0)),0,int(card_limits.get(card_id,1))))
	var signature := str(values)
	if signature == modifier_signature: return
	modifier_signature = signature
	var previous_growth := _growth_scale()
	for index in CARD_IDS.size(): card_levels[CARD_IDS[index]] = values[index]
	for device: Dictionary in placed:
		if float(device.hp) <= 0.0: continue
		var ratio := float(device.hp) / maxf(1.0, float(device.max_hp))
		device.max_hp = _max_hp(device)
		device.hp = float(device.max_hp) * ratio
		device.armor = 30.0 if device.kind == "barricade" and level("device_iron_nut") > 0 else 0.0
		if device.kind in ["pea", "snowpea", "melon", "spikeweed"]:
			device.timer = float(device.timer) * _growth_scale() / previous_growth
		var variant := visual_variant(device)
		if str(device.get("visual_variant", "")) != variant:
			device.visual_variant = variant
			device.burst_queue = []
			device.timer = minf(float(device.timer), 0.2)
	sim.attack_geometry_cache.clear()

func visual_variant(device: Dictionary) -> String:
	var kind := str(device.kind)
	if kind == "barricade": return "iron_nut" if level("device_iron_nut") > 0 else "wallnut"
	if kind == "mine": return "potato_mine" if bool(device.get("armed", false)) else "potato_unarmed"
	if kind not in ["pea", "snowpea"]: return kind
	if level("device_melon") > 0: return "melon"
	if level("device_gatling") > 0: return "gatling"
	if level("device_threepeater") > 0: return "threepeater"
	if level("device_repeater") > 0: return "repeater"
	return "snowpea" if kind == "snowpea" else "pea"

func _max_hp(device: Dictionary) -> float:
	var result := float(device.get("base_hp", 1.0))
	if device.kind not in ["power", "range"]: result *= 1.0 + 0.25 * mini(4, level("device_rooted"))
	if device.kind == "barricade":
		result *= 1.0 + 0.30 * mini(3, level("device_nut_repair"))
		if level("device_iron_nut") > 0: result *= 2.5
	return result

func active_count() -> int:
	var count := 0
	for device: Dictionary in placed:
		if float(device.hp) > 0.0: count += 1
	return count

func select(sim, kind: String) -> bool:
	sync_modifiers(sim)
	if not enabled or sim.workshop_mode or sim.state not in ["running", "between", "ready"] or not ITEMS.has(kind): return false
	if selected_kind == kind:
		cancel()
		return true
	if active_count() >= limit: return reject("部署已满：%d / %d" % [active_count(), limit])
	if gold < price_of(kind): return reject("金币不足：需要 %d" % price_of(kind))
	selected_kind = kind
	message = "%s · %d 金币 · %s" % [ITEMS[kind].name, price_of(kind), ITEMS[kind].description]
	feedback_timer = 0.0
	valid = false
	return true

func cancel() -> void:
	selected_kind = ""
	valid = false
	hover_cell = Rect2()
	message = "部署已取消"
	feedback_timer = 2.0

func reject(reason: String) -> bool:
	message = reason
	feedback_timer = 2.5
	valid = false
	return false

func cell_at(sim, point: Vector2) -> Rect2:
	var col := floori((point.x - sim.GRID_ORIGIN.x) / sim.GRID_CELL_SIZE.x)
	var row := floori((point.y - sim.GRID_ORIGIN.y) / sim.GRID_CELL_SIZE.y)
	if col < 0 or col >= sim.GRID_COLUMNS or row < 0 or row >= sim.GRID_ROWS: return Rect2()
	return Rect2(sim.GRID_ORIGIN + Vector2(col, row) * sim.GRID_CELL_SIZE, sim.GRID_CELL_SIZE)

func placement_error(sim, point: Vector2) -> String:
	if selected_kind.is_empty(): return "先选择机关"
	if not enabled or sim.workshop_mode or sim.state not in ["running", "between", "ready"]: return "当前无法部署"
	var cell := cell_at(sim, point)
	if cell.size == Vector2.ZERO: return "请选择战场地格"
	if cell.get_center().x < 220.0 or cell.get_center().x > 1150.0: return "水晶与入口区域不能部署"
	for device: Dictionary in placed:
		if float(device.hp) > 0.0 and device.cell == cell: return "该格已有机关"
	for feature: Dictionary in sim.terrain_features:
		if str(feature.get("type", "")) not in ["blocked", "door", "trap", "attack_ground", "high_ground"]: continue
		if str(feature.get("type", "")) == "door" and float(feature.get("hp", 0.0)) <= 0.0: continue
		var cells: Array = feature.get("grid_cells", [])
		if cells.is_empty():
			if cell.intersects(feature.area): return "墙壁或已有机关不能部署"
		else:
			for occupied: Rect2 in cells:
				if cell.intersects(occupied): return "墙壁或已有机关不能部署"
	if sim._terrain_blocks(cell.get_center(), 10.0): return "此格不可通行"
	if selected_kind in BLOCKING_PLANTS:
		for hero: Dictionary in sim.heroes:
			if bool(hero.get("deployed", false)) and float(hero.hp) > 0.0 and cell.has_point(hero.pos): return "请先移开格内角色"
		for enemy: Dictionary in sim.enemies:
			if float(enemy.hp) > 0.0 and cell.has_point(enemy.pos): return "敌人占据此格"
	if active_count() >= limit: return "部署已满：%d / %d" % [active_count(), limit]
	if gold < price_of(selected_kind): return "金币不足：需要 %d" % price_of(selected_kind)
	return ""

func hover(sim, point: Vector2) -> void:
	if selected_kind.is_empty(): return
	hover_cell = cell_at(sim, point)
	var error := placement_error(sim, point)
	valid = error.is_empty()
	message = "%s · 点击部署 · 右键 / Esc 取消" % ITEMS[selected_kind].name if valid else error

func place(sim, point: Vector2) -> bool:
	sync_modifiers(sim)
	var error := placement_error(sim, point)
	if not error.is_empty(): return reject(error)
	var kind := selected_kind
	var cell := cell_at(sim, point)
	var hp := 1.0
	if kind == "barricade": hp = 850.0 + sim.team_level * 80.0
	elif kind in ["pea", "snowpea", "sunflower"]: hp = 220.0 + sim.team_level * 20.0
	elif kind == "melon": hp = 320.0 + sim.team_level * 25.0
	elif kind in ["mine", "cherry", "spikeweed"]: hp = 80.0
	var device := {"id":serial, "kind":kind, "pos":cell.get_center(), "cell":cell, "base_hp":hp, "hp":hp, "max_hp":hp, "armor":0.0, "paid_price":price_of(kind), "refunded":false, "timer":0.35, "pulse":0.0, "visual_time":0.0, "shoot_age":999.0, "armed":false, "arm_remaining":3.0, "burst_queue":[], "visual_variant":kind}
	device.id = -serial - 1
	serial += 1
	device.max_hp = _max_hp(device)
	device.hp = device.max_hp
	device.visual_variant = visual_variant(device)
	device.armor = 30.0 if kind == "barricade" and level("device_iron_nut") > 0 else 0.0
	if kind == "sunflower": device.timer = 8.0
	elif kind == "cherry": device.timer = 1.0
	elif kind == "spikeweed": device.timer = 0.0
	if kind in BLOCKING_PLANTS:
		device.id = sim.next_construct_id
		sim.next_construct_id += 1
		device.device = true
		sim.geo_constructs.append(device)
	placed.append(device)
	gold -= int(device.paid_price)
	selected_kind = ""
	valid = false
	hover_cell = Rect2()
	message = "%s已部署 · %d / %d" % [ITEMS[kind].name, active_count(), limit]
	feedback_timer = 3.0
	sim.attack_geometry_cache.clear()
	sim.events.append({"kind":"device_place", "pos":device.pos, "device_kind":kind})
	return true

func scale_at(point: Vector2, kind: String) -> float:
	for device: Dictionary in placed:
		if float(device.hp) > 0.0 and device.kind == kind and Rect2(device.cell).has_point(point):
			return 1.35 + 0.15 * mini(3, level("device_power_pad")) if kind == "power" else 1.30 + 0.15 * mini(3, level("device_range_pad"))
	return 1.0

func on_kill(sim, enemy: Dictionary) -> void:
	if not enabled or sim.workshop_mode: return
	var kind := str(enemy.get("kind", ""))
	var amount := 100 if kind.begins_with("boss_") else (22 if kind in ["hilichurl_brute", "armored", "troop_heavy", "rift_commander"] else 12)
	gold += amount

func _damage_scale() -> float:
	return 1.0 + 0.20 * mini(5, level("device_botanist"))

func _growth_scale() -> float:
	return maxf(0.60, 1.0 - 0.12 * mini(3, level("device_quick_growth")))

func _consume(device: Dictionary) -> void:
	device.hp = 0.0
	device.burst_queue = []
	_refund(device)

func _refund(device: Dictionary) -> void:
	if bool(device.get("refunded", false)): return
	device.refunded = true
	if level("device_salvage") > 0: gold += floori(float(device.get("paid_price", 0)) * 0.5)

func _explode(sim, device: Dictionary, base_damage: float, base_radius: float) -> void:
	var explosive_level := mini(3, level("device_mine_chain"))
	var radius := base_radius * (1.0 + 0.20 * explosive_level)
	var damage := base_damage * _damage_scale() * (1.0 + 0.30 * explosive_level)
	_consume(device)
	for victim: Dictionary in sim.enemies.duplicate():
		if float(victim.hp) > 0.0 and sim.is_in_ability_area(device.pos, victim.pos, radius): sim.apply_hit(victim, damage, "pyro", -1)
	sim.events.append({"kind":"device_explosion", "pos":device.pos, "radius":radius, "life":0.48, "device_kind":device.kind})

func _aim(sim, device: Dictionary, lane: int = 0) -> Dictionary:
	var origin: Vector2 = Vector2(device.pos) + Vector2(0, float(lane) * sim.GRID_CELL_SIZE.y)
	var candidates: Array = sim.enemy_candidates_in_rect(Rect2(origin - Vector2(0,20.001), Vector2(maxf(sim.MOVE_AREA.end.x,sim.ENDLESS_ARENA.end.x)-origin.x+200.0,40.002)))
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.pos.x)<float(b.pos.x) if float(a.pos.x)!=float(b.pos.x) else int(a.id)<int(b.id))
	# The first clear target wins; distant blocked rays no longer repeat per seed.
	for enemy: Dictionary in candidates:
		if float(enemy.hp) <= 0.0 or float(enemy.get("spawn_timer", 0.0)) > 0.0 or bool(enemy.get("flying", false)) or enemy.pos.x <= origin.x or absf(float(enemy.pos.y) - origin.y) > 20.0: continue
		if str(device.visual_variant) != "melon" and sim.terrain_line_blocked(origin, enemy.pos): continue
		return enemy
	return {}

func _release(sim, device: Dictionary, lane: int, target: Vector2 = Vector2.INF) -> void:
	device.pulse = 0.18
	device.shoot_age = 0.0
	var variant := str(device.visual_variant)
	var start: Vector2 = Vector2(device.pos) + Vector2(14, float(lane) * sim.GRID_CELL_SIZE.y)
	var kind := "melon" if variant == "melon" else ("snowpea" if device.kind == "snowpea" else "pea")
	var damage: float = (125.0 + sim.team_level * 12.0 if kind == "melon" else 45.0 + sim.team_level * 6.0) * _damage_scale()
	var shot := {"kind":kind, "pos":start, "previous_pos":start, "model_origin":start, "visual_origin":device.pos, "visual_time":device.visual_time, "visual_variant":variant, "muzzle_lane":lane, "muzzle_pulse":device.pulse, "shoot_age":0.0, "life":2.4, "damage":damage, "direction":Vector2.RIGHT, "slow":device.kind == "snowpea" or level("device_frost") > 0}
	if kind == "melon":
		if not target.is_finite(): return
		shot.target = target
		shot.flight_time = 0.0
		shot.flight_total = clampf(start.distance_to(target) / 400.0, 0.6, 1.45)
		shot.arc_height = 85.0
		shot.radius = 82.0
	shots.append(shot)
	shot.device_id = int(device.id)
	sim.events.append({"kind":"device_pea_cast", "pos":device.pos, "device_kind":kind, "visual_variant":variant})

func _fire(sim, device: Dictionary) -> bool:
	var variant := str(device.visual_variant)
	if variant == "threepeater":
		var has_target := false
		for lane in [-1, 0, 1]:
			if not _aim(sim, device, lane).is_empty(): has_target = true
		if not has_target: return false
		for lane in [-1, 0, 1]: _release(sim, device, lane)
		return true
	var enemy := _aim(sim, device)
	if enemy.is_empty(): return false
	_release(sim, device, 0, Vector2(enemy.pos))
	var count := 4 if variant == "gatling" else (2 if variant == "repeater" else 1)
	for burst in range(1, count): device.burst_queue.append({"due":float(device.visual_time) + 0.12 * burst, "lane":0})
	return true

func _slow(enemy: Dictionary) -> void:
	# Independent from elemental slowing, so the ice-pea promise is exactly 20%.
	enemy.device_slow_timer = maxf(float(enemy.get("device_slow_timer", 0.0)), 2.0)
	enemy.device_slow_scale = 0.8

func tick(sim, dt: float) -> void:
	if not enabled or sim.workshop_mode: return
	sync_modifiers(sim)
	feedback_timer = maxf(0.0, feedback_timer - dt)
	if feedback_timer <= 0.0 and selected_kind.is_empty(): message = ""
	for device: Dictionary in placed:
		device.pulse = maxf(0.0, float(device.pulse) - dt)
		device.visual_time = float(device.get("visual_time", 0.0)) + dt
		device.shoot_age = minf(999.0, float(device.get("shoot_age", 999.0)) + dt)
		if float(device.hp) <= 0.0:
			device.burst_queue = []
			_refund(device)
			continue
		if device.kind == "barricade":
			device.hp = minf(float(device.max_hp), float(device.hp) + 12.0 * mini(3, level("device_nut_repair")) * dt)
		elif device.kind == "mine":
			device.arm_remaining = maxf(0.0, float(device.arm_remaining) - dt)
			if device.arm_remaining > 0.0: continue
			device.armed = true
			device.visual_variant = "potato_mine"
			for enemy: Dictionary in sim.enemies:
				if float(enemy.hp) > 0.0 and float(enemy.get("spawn_timer",0.0))<=0.0 and not bool(enemy.get("flying", false)) and Rect2(device.cell).has_point(enemy.pos):
					_explode(sim, device, 420.0 + sim.team_level * 75.0, 150.0)
					break
		elif device.kind == "cherry":
			device.timer = float(device.timer) - dt
			if device.timer <= 0.0: _explode(sim, device, 620.0 + sim.team_level * 90.0, 175.0)
		elif device.kind == "sunflower":
			device.timer = float(device.timer) - dt
			while device.timer <= 0.0:
				device.timer = float(device.timer) + 8.0
				var amount := 20 + 5 * mini(3, level("device_photosynthesis"))
				gold += amount
				device.pulse = 0.5
				sim.events.append({"kind":"device_sun", "pos":device.pos, "value":amount, "life":0.6})
		elif device.kind == "spikeweed":
			device.timer = float(device.timer) - dt
			if device.timer <= 0.0:
				device.timer = float(device.timer) + 0.5 * _growth_scale()
				for enemy: Dictionary in sim.enemies.duplicate():
					if float(enemy.hp) > 0.0 and float(enemy.get("spawn_timer",0.0))<=0.0 and not bool(enemy.get("flying", false)) and Rect2(device.cell).has_point(enemy.pos):
						sim.apply_hit(enemy, (25.0 + sim.team_level * 3.0) * _damage_scale(), "", -1)
						device.pulse = 0.25
		elif device.kind in ["pea", "snowpea", "melon"]:
			var remaining: Array = []
			for burst: Dictionary in device.burst_queue:
				if float(burst.due) <= float(device.visual_time): _release(sim, device, int(burst.lane))
				else: remaining.append(burst)
			device.burst_queue = remaining
			device.timer = float(device.timer) - dt
			if device.timer <= 0.0 and _fire(sim, device): device.timer = (2.6 if str(device.visual_variant) == "melon" else 1.1) * _growth_scale()
	for shot: Dictionary in shots:
		shot.life = float(shot.life) - dt
		if str(shot.kind) == "melon": _tick_melon(sim, shot, dt)
		else: _tick_pea(sim, shot, dt)
		if not sim.MOVE_AREA.grow(25.0).has_point(shot.pos): shot.life = 0.0
	shots = shots.filter(func(shot: Dictionary) -> bool: return float(shot.life) > 0.0)
	rebuild_muzzle_shots()
	placed = placed.filter(func(device: Dictionary) -> bool: return float(device.hp) > 0.0)
	# Shared objects retain identity, even when damaged outside a combat tick.
	sim.geo_constructs = sim.geo_constructs.filter(func(device: Dictionary) -> bool: return float(device.hp) > 0.0)

func _tick_pea(sim, shot: Dictionary, dt: float) -> void:
	var start: Vector2 = shot.pos
	var finish := start + Vector2(600.0 * dt, 0)
	shot.previous_pos = start
	var hit: Dictionary = {}
	var nearest := 2.0
	for enemy: Dictionary in sim.enemy_candidates_in_rect(Rect2(start, finish-start).abs().grow(20.001)):
		if float(enemy.hp) <= 0.0 or float(enemy.get("spawn_timer", 0.0)) > 0.0 or bool(enemy.get("flying", false)) or absf(float(enemy.pos.y) - start.y) > 20.0: continue
		var fraction: float = sim._swept_body_fraction(start, finish, enemy.pos, Vector2(17, 16))
		if fraction >= 0.0 and fraction < nearest:
			nearest = fraction
			hit = enemy
	var contact := start.lerp(finish, nearest) if not hit.is_empty() else finish
	if sim.terrain_line_blocked(start, contact): shot.life = 0.0
	elif not hit.is_empty():
		sim.apply_hit(hit, float(shot.damage), "", -1)
		if bool(shot.slow) and float(hit.hp) > 0.0: _slow(hit)
		sim.events.append({"kind":"device_pea_hit", "pos":contact, "device_kind":shot.kind, "shot_visual":shot.duplicate()})
		shot.life = 0.0
	shot.pos = contact

func _tick_melon(sim, shot: Dictionary, dt: float) -> void:
	shot.previous_pos = shot.pos
	shot.flight_time = float(shot.flight_time) + dt
	var progress := minf(1.0, float(shot.flight_time) / float(shot.flight_total))
	shot.pos = Vector2(shot.model_origin).lerp(shot.target, progress)
	if progress < 1.0: return
	for enemy: Dictionary in sim.enemies.duplicate():
		if float(enemy.hp) > 0.0 and not bool(enemy.get("flying", false)) and sim.is_in_ability_area(shot.target, enemy.pos, float(shot.radius)):
			sim.apply_hit(enemy, float(shot.damage), "", -1)
			if bool(shot.slow) and float(enemy.hp) > 0.0: _slow(enemy)
	sim.events.append({"kind":"device_melon_hit", "pos":shot.target, "radius":shot.radius, "life":0.48, "shot_visual":shot.duplicate()})
	shot.life = 0.0

func rebuild_muzzle_shots() -> void:
	muzzle_shots.clear()
	for shot: Dictionary in shots:
		if str(shot.get("kind", "pea")) == "melon" or float(shot.pos.x)-float(shot.get("model_origin",shot.pos).x)>16.0: continue
		var origin := Vector2(shot.get("visual_origin",Vector2.INF))
		if not muzzle_shots.has(origin): muzzle_shots[origin] = []
		muzzle_shots[origin].append(shot)
