extends RefCounted
## Ephemeral laboratory. It owns no storage, checkpoint or progression service.
const Sim = preload("res://scripts/combat_simulation.gd")
const Catalog = preload("res://scripts/combat_catalog.gd")

var sim
var templates: Dictionary = {}
var selected_kind := ""
var selected_id := -1
var auto_attack := true
var enemy_action := true
var invulnerable := true
var infinite_energy := true
var paused := false
var speed := 1.0
var cards_applied: Array[Dictionary] = []
var dormant_orbitals: Dictionary = {}
var stage_id := "stage_01"
var layout_id := "blood_gate"
var message := "选择角色或敌人，再点击战场放置。Tab 收起工具；右键移动选中单位。"

func _init() -> void:
	change_map(stage_id)

func change_map(next_stage: String, next_layout: String = "blood_gate") -> void:
	stage_id = next_stage
	layout_id = next_layout
	sim = Sim.new(9304, true)
	if stage_id != "stage_01":
		var squad: Array[String] = ["traveler"]
		sim.reset_stage(stage_id, squad, 9304)
	sim.workshop_mode = true
	sim.battle_devices.reset(sim)
	sim.state = "running"
	# Slot zero remains reserved for the traveler's elemental rules. Removed heroes
	# are undeployed, not reindexed, so queued hits always retain their true owner.
	sim.heroes[0].deployed = false
	sim.run_state.squad.clear()
	sim.events.clear()
	cards_applied.clear()
	dormant_orbitals.clear()
	selected_kind = ""
	selected_id = -1
	_sync_flags()

func _sync_flags() -> void:
	sim.workshop_auto_attack = auto_attack
	sim.workshop_enemy_action = enemy_action
	sim.workshop_invulnerable = invulnerable
	if infinite_energy:
		for hero: Dictionary in sim.heroes:
			hero.energy = hero.max_energy
			hero.skill_cooldown = 0.0
			hero.ultimate_cooldown = 0.0
		sim.traveler_skill_cooldown = 0.0

func tick(dt: float) -> void:
	_sync_flags()
	sim.tick(dt)
	_sync_flags()

func template(character_id: String) -> Dictionary:
	if not templates.has(character_id):
		var source = Sim.new(9304, true)
		if character_id != "traveler":
			var squad: Array[String] = ["traveler", character_id]
			source.reset_stage("stage_01", squad, 9304)
		templates[character_id] = source.heroes[0 if character_id == "traveler" else 1].duplicate(true)
	return templates[character_id].duplicate(true)

func legal(point: Vector2, radius: float = 17.0) -> bool:
	var area: Rect2 = Sim.ENDLESS_ARENA if sim.endless_mode else Sim.MOVE_AREA
	return area.grow(-radius).has_point(point) and not sim._terrain_blocks(point, radius)

func place_hero(character_id: String, point: Vector2) -> bool:
	if not sim.database.characters.has(character_id) or not legal(point):
		message = "此处不可放置：请避开墙体与地图边缘。"
		return false
	var hero: Dictionary = {}
	for existing: Dictionary in sim.heroes:
		if str(existing.character_id) == character_id:
			hero = existing
			break
	if hero.is_empty():
		hero = template(character_id)
		hero.id = sim.heroes.size()
		sim.heroes.append(hero)
	hero.pos = point
	hero.target = point
	hero.moving = false
	hero.deployed = true
	hero.hp = hero.max_hp
	if dormant_orbitals.has(int(hero.id)):
		sim.orbitals.append_array(dormant_orbitals[int(hero.id)])
		dormant_orbitals.erase(int(hero.id))
	if not character_id in sim.run_state.squad: sim.run_state.squad.append(character_id)
	selected_kind = "hero"
	selected_id = int(hero.id)
	message = "已放置 %s；Q / E 进入技能瞄准，再点选落点或方向。" % hero.name
	_sync_flags()
	return true

func place_enemy(kind: String, point: Vector2) -> bool:
	if not Catalog.ENEMIES.has(kind): return false
	var radius := maxf(17.0, float(Catalog.ENEMIES[kind].get("size", 28.0)) * 0.34)
	if not legal(point, radius):
		message = "此处不可放置：请避开墙体与地图边缘。"
		return false
	var enemy: Dictionary = sim.spawn_enemy(point, kind)
	selected_kind = "enemy"
	selected_id = int(enemy.id)
	message = "已放置 %s；敌人行动可单独开关。" % enemy.name
	return true

func selected() -> Dictionary:
	if selected_kind == "hero" and selected_id >= 0 and selected_id < sim.heroes.size():
		var hero: Dictionary = sim.heroes[selected_id]
		return hero if bool(hero.get("deployed", false)) else {}
	if selected_kind == "enemy":
		return sim.find_enemy(selected_id)
	return {}

func select_at(point: Vector2) -> bool:
	var distance := 52.0
	var found: Dictionary = {}
	var kind := ""
	for hero: Dictionary in sim.heroes:
		if not bool(hero.get("deployed", false)): continue
		var d: float = point.distance_to(hero.pos)
		if d < distance: distance = d; found = hero; kind = "hero"
	for enemy: Dictionary in sim.enemies:
		var d: float = point.distance_to(enemy.pos)
		if enemy.hp > 0.0 and d < distance: distance = d; found = enemy; kind = "enemy"
	selected_kind = kind
	selected_id = int(found.get("id", -1))
	return not found.is_empty()

func move_selected(point: Vector2) -> bool:
	var unit := selected()
	var radius := 17.0 if selected_kind == "hero" else maxf(17.0, float(unit.get("size", 28.0)) * 0.34)
	if unit.is_empty() or not legal(point, radius):
		message = "无法移动到此处。"
		return false
	if selected_kind == "hero":
		if float(unit.hp)<=0.0:
			message = "倒地角色需要先恢复。"
			return false
		sim.command_move(selected_id,point)
	elif not sim.command_workshop_enemy_move(selected_id,point):
		message = "固定建筑无法行走，请重新放置。"
		return false
	message = "已下达移动指令；抵达后继续自主战斗。"
	return true

func remove_selected() -> void:
	var unit := selected()
	if unit.is_empty(): return
	if selected_kind == "hero":
		unit.deployed = false
		unit.moving = false
		sim.run_state.squad.erase(str(unit.character_id))
		_cancel_hero_effects(selected_id)
	else:
		sim.enemies.erase(unit)
		sim.enemy_lookup.erase(selected_id)
	selected_kind = ""
	selected_id = -1

func _cancel_hero_effects(id: int) -> void:
	var saved: Array[Dictionary] = []
	for orbital: Dictionary in sim.orbitals:
		if int(orbital.get("hero_id", -1)) == id: saved.append(orbital.duplicate(true))
	if not saved.is_empty(): dormant_orbitals[id] = saved
	for collection: Array in [sim.projectiles, sim.pending_impacts, sim.skill_effects, sim.orbitals, sim.geo_constructs]:
		for index in range(collection.size() - 1, -1, -1):
			if int(collection[index].get("hero_id", collection[index].get("owner", -1))) == id: collection.remove_at(index)

func clear_units(enemies_only: bool = false) -> void:
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	if not enemies_only:
		for hero: Dictionary in sim.heroes:
			hero.deployed = false; hero.moving = false
			_cancel_hero_effects(int(hero.id))
		sim.run_state.squad.clear()
	clear_effects(not enemies_only)
	selected_kind = ""
	selected_id = -1
	message = "战场已清空，可以继续放置。"

func clear_effects(clear_orbitals: bool = true) -> void:
	for collection: Array in [sim.projectiles, sim.enemy_projectiles, sim.enemy_hazards, sim.pending_impacts, sim.skill_effects, sim.geo_constructs, sim.pending_stage_spawns, sim.pending_troop_spawns, sim.events]: collection.clear()
	if clear_orbitals: sim.orbitals.clear()

func recover() -> void:
	# A laboratory has no campaign result or card-selection screen. Recover old
	# sessions stranded there without changing the author's explicit pause.
	if sim.workshop_mode and sim.state in ["reward", "won", "lost"]:
		sim.state = "running"
		sim.previous_state = "running"
		if sim.rewards != null: sim.rewards.offered.clear()
	for hero: Dictionary in sim.heroes:
		hero.hp = hero.max_hp
		hero.energy = hero.max_energy
		hero.skill_cooldown = 0.0
		hero.ultimate_cooldown = 0.0
		hero.status_timer = 0.0
		hero.slime_slow_timer = 0.0
		hero.animation_state = "idle"
	for enemy: Dictionary in sim.enemies:
		enemy.hp = enemy.max_hp
		enemy.shield = enemy.get("max_shield", 0.0)
	sim.base_hp = sim.base_max_hp
	sim.traveler_skill_cooldown = 0.0
	message = "在场单位已恢复生命、护盾与能量，技能冷却已清除。"

func cast(ultimate: bool, point: Vector2) -> bool:
	if selected_kind != "hero" or selected().is_empty(): return false
	_sync_flags()
	var success: bool = sim.activate_hero_ultimate(selected_id, point) if ultimate else sim.activate_hero_skill(selected_id, point)
	message = "已施放；暂停时用逐帧查看命中过程。" if success else "技能尚未就绪；可开启无限能量或恢复。"
	return success

func apply_card(card: Dictionary) -> bool:
	var hero := selected()
	if selected_kind != "hero" or hero.is_empty():
		message = "先在战场选中要获得卡牌的角色。"
		return false
	var effect := str(card.get("effect", ""))
	if effect == "deploy_reinforcement":
		message = "增援角色请从角色目录任意放置。"
		return false
	if effect in ["assign_traveler_element", "dual_element_mythic"] and hero.character_id != "traveler":
		message = "此卡改变旅行者元素，请先选中旅行者。"
		return false
	var applied := card.duplicate(true)
	# Existing character effects take a runtime ID. Team-only mechanics remain
	# honest about their original shared scope in the card description.
	applied.target = "character"
	if effect == "assign_traveler_element": sim.run_state.traveler_element = str(card.value)
	if effect == "dual_element_mythic": sim.run_state.traveler_secondary_element = "hydro" if hero.element != "hydro" else "electro"
	sim.run_state.buff_levels[str(card.id)] = int(sim.run_state.buff_levels.get(str(card.id), 0)) + 1
	sim.run_state.rebuild_tags(sim.database.cards)
	sim.apply_v2_card_effect(applied, selected_id)
	cards_applied.append({"hero_id":selected_id, "card":card.duplicate(true)})
	message = "%s 获得「%s」；队伍机制仍按卡牌原有效果结算。" % [hero.name, card.name]
	return true

func reset_builds() -> void:
	var units: Array[Dictionary] = []
	for hero: Dictionary in sim.heroes:
		units.append({"id":hero.character_id, "pos":hero.pos, "deployed":hero.deployed})
	var enemies: Array[Dictionary] = sim.enemies.duplicate(true)
	var old_next_id: int = sim.next_id
	change_map(stage_id, layout_id)
	for hero: Dictionary in units:
		place_hero(str(hero.id), hero.pos)
		sim.heroes[selected_id].deployed = bool(hero.deployed)
		if not hero.deployed: sim.run_state.squad.erase(str(hero.id))
	sim.enemies = enemies
	sim.next_id = old_next_id
	for enemy: Dictionary in enemies: sim.enemy_lookup[int(enemy.id)] = enemy
	selected_kind = ""
	selected_id = -1
	message = "所有构筑已恢复为角色初始值，摆放保留。"
