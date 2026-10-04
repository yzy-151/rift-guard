extends RefCounted
# Optional endless objectives reuse the existing contract UI and reward event.
# No objective gates leveling, boss arrivals, or survival progression.
var objective_index: int = 0
var baseline: int = 0
var next_at: float = -1.0
var zone_seconds: float = 0.0
var last_elapsed: float = 0.0

func reset() -> void:
	objective_index = 0
	baseline = 0
	next_at = -1.0
	zone_seconds=0.0
	last_elapsed=0.0

func counter(sim, metric: String) -> int:
	match metric:
		"survival_time": return floori(sim.elapsed)
		"reactions": return sim.reactions
		"boss_kills": return sim.boss_kills
		"elite_kills": return sim.elite_kills
		"zone_hold": return floori(zone_seconds)
		_: return sim.kills

func progress(sim) -> int:
	return maxi(0, counter(sim, str(sim.combat_contract.get("metric", "kills"))) - baseline)

func prepare(sim) -> void:
	var dt := clampf(float(sim.elapsed)-last_elapsed,0.0,0.25)
	last_elapsed=float(sim.elapsed)
	if not sim.contract_completed and str(sim.combat_contract.get("metric",""))=="reactions" and not _can_react(sim):
		sim.combat_contract.metric="kills"
		sim.combat_contract.name="委托 %d · 接替清剿" % (objective_index+1)
		sim.combat_contract.target=24
		baseline=sim.kills
	if not sim.contract_completed and str(sim.combat_contract.get("metric",""))=="zone_hold":
		var center: Vector2=sim.combat_contract.get("zone_pos",Vector2.ZERO)
		for hero: Dictionary in sim.heroes:
			if hero.hp>0 and bool(hero.deployed) and Vector2(hero.pos).distance_to(center)<=float(sim.combat_contract.get("zone_radius",120.0)):
				zone_seconds+=dt
				break
	if not sim.contract_completed or next_at < 0.0 or sim.elapsed < next_at:
		return
	objective_index += 1
	var cycle: int = (objective_index - 1) / 6
	var definition: Dictionary
	match (objective_index - 1) % 6:
		0:
			definition = _contract("清理围攻", "kills", mini(70, 18 + cycle * 8), "energy", 15.0, "全队能量 +15")
		1:
			definition = _contract("稳住阵线", "survival_time", mini(90, 45 + cycle * 5), "heal", 0.10, "存活队员恢复 10%")
		2:
			if _can_react(sim):
				definition = _contract("元素交织", "reactions", mini(20, 6 + cycle * 2), "energy", 20.0, "全队能量 +20")
			else:
				definition = _contract("扫清追兵", "kills", mini(80, 24 + cycle * 8), "energy", 20.0, "全队能量 +20")
		3:
			definition = _contract("击破首领", "boss_kills", 1, "heal", 0.15, "存活队员恢复 15%")
		4:
			# The elite roster only exists after the second boss; avoid dead objectives.
			definition = _contract("精英猎手", "elite_kills", mini(8,3+cycle), "energy", 20.0, "全队能量 +20") if sim._endless_phase()>=2 else _contract("突破围攻", "kills", 28, "energy", 20.0, "全队能量 +20")
		_:
			definition = _contract("驻守补给点", "zone_hold", 12, "heal", 0.18, "存活队员恢复 18%")
			var leader: Dictionary=sim._nearest_live_hero(sim.ENDLESS_ARENA.get_center())
			var center: Vector2=leader.get("pos",sim.ENDLESS_ARENA.get_center())
			definition.zone_pos=sim._nearest_walkable_point(center+Vector2(130.0,0.0),28.0)
			definition.zone_radius=120.0
	definition["objective_index"] = objective_index
	definition["optional"] = true
	definition["name"] = "委托 %d · %s" % [objective_index + 1, definition.name]
	sim.combat_contract = definition
	sim.contract_completed = false
	sim.contract_reward_text = ""
	baseline = counter(sim, definition.metric)
	next_at = -1.0

func completed(sim) -> void:
	next_at = sim.elapsed + 3.0

func snapshot(sim) -> Dictionary:
	var contract: Dictionary=sim.combat_contract.duplicate(true)
	if contract.get("zone_pos") is Vector2: contract.zone_pos=[contract.zone_pos.x,contract.zone_pos.y]
	return {"index":objective_index, "progress":progress(sim), "contract":contract, "completed":sim.contract_completed, "reward_text":sim.contract_reward_text, "next_delay":maxf(0.0, next_at - sim.elapsed) if next_at >= 0.0 else -1.0}

func restore(sim, data: Dictionary) -> void:
	var saved: Dictionary = data.get("contract", {})
	if saved.is_empty() or int(saved.get("target", 0)) <= 0:
		return
	objective_index = maxi(0, int(data.get("index", 0)))
	sim.combat_contract = saved.duplicate(true)
	if saved.get("zone_pos") is Array and saved.zone_pos.size()>=2: sim.combat_contract.zone_pos=Vector2(float(saved.zone_pos[0]),float(saved.zone_pos[1]))
	last_elapsed=float(sim.elapsed)
	sim.contract_completed = bool(data.get("completed", false))
	sim.contract_reward_text = str(data.get("reward_text", ""))
	baseline = counter(sim, str(saved.get("metric", "kills"))) - maxi(0, int(data.get("progress", 0)))
	var remaining: float = float(data.get("next_delay", -1.0))
	next_at = sim.elapsed + remaining if remaining >= 0.0 else -1.0

func _can_react(sim) -> bool:
	var elements: Dictionary = {}
	for hero: Dictionary in sim.heroes:
		if float(hero.get("hp", 0.0)) <= 0.0 or not bool(hero.get("deployed",false)):
			continue
		for key in ["element", "secondary_element"]:
			var element: String = sim.normalize_element(str(hero.get(key, "")))
			if element not in ["", "none"]:
				elements[element] = true
	return elements.size() >= 2

func _contract(label: String, metric: String, target: int, reward_kind: String, value: float, text: String) -> Dictionary:
	return {"id":"endless_objective_%d" % objective_index, "name":label, "metric":metric, "target":target, "reward":{"kind":reward_kind, "value":value, "text":text}}
