extends SceneTree

const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")
const Icons = preload("res://scripts/content/generated_icon_catalog.gd")
const DEVICE_IDS := [
	"device_botanist", "device_repeater", "device_threepeater", "device_gatling",
	"device_melon", "device_frost", "device_iron_nut", "device_nut_repair",
	"device_power_pad", "device_range_pad", "device_soil_discount", "device_photosynthesis",
	"device_quick_growth", "device_mine_chain", "device_rooted", "device_salvage",
]
const EVOLUTION_IDS := ["device_repeater", "device_threepeater", "device_gatling", "device_melon"]

var checks := 0
var failures: Array[String] = []
var observations: Dictionary = {}
var database
var device_cards: Array[Dictionary] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("DEVICE CARD QA: " + label)

func _initialize() -> void:
	database = Database.new()
	check(database.errors.is_empty(), "live database validates with device family added")
	for card: Dictionary in database.cards:
		if str(card.get("family", "")) == "device":
			device_cards.append(card)
	check(device_cards.size() == 16, "database loads exactly 16 device cards alongside existing card families")
	_test_card_content()
	_test_applications_and_caps()
	_test_upgrade_priority()
	_test_modes()
	_test_offers()
	_test_icons()
	if "--qa-integration" in OS.get_cmdline_user_args():
		_test_real_simulation()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--qa-output="):
			var output_path := argument.trim_prefix("--qa-output=")
			DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
			var output := FileAccess.open(output_path, FileAccess.WRITE)
			if output != null:
				output.store_string(JSON.stringify({"checks":checks, "failures":failures, "observations":observations}, "\t"))
				output.close()
	print("DEVICE CARDS QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _card(id: String) -> Dictionary:
	for card: Dictionary in device_cards:
		if str(card.id) == id:
			return card
	return {}

func _campaign_run():
	var run = RunState.new()
	run.stage_id = "stage_01"
	run.mode_id = "rift_watch"
	run.device_cards_enabled = true
	run.traveler_element = "electro"
	run.crystal_level = 40
	return run

func _prepare_prerequisites(card: Dictionary, run) -> void:
	var required: Array = card.get("requires_any", [])
	if not required.is_empty(): run.buff_levels[str(required[0])] = 1
	run.rebuild_tags(database.cards)

func _test_card_content() -> void:
	var unique := {}
	for id: String in DEVICE_IDS:
		var card := _card(id)
		check(not card.is_empty(), "live database exposes %s" % id)
		if card.is_empty():
			continue
		unique[str(card.id)] = true
		check(str(card.get("target", "")) == "global" and bool(card.get("mechanic", false)), "%s uses the existing global mechanic card template" % id)
		check("机关" in card.get("tags", []) and "device" in card.get("tags", []), "%s supplies Chinese device family and machine tags" % id)
		check(int(card.get("max_stacks", 0)) > 0 and float(card.get("weight", 0)) > 0, "%s has a finite stack cap and nonzero offer weight" % id)
		check(str(card.get("icon", "")) == Icons.DEVICE_CARD_DIR + id + ".png", "%s maps to its own cropped atlas cell" % id)
	check(unique.size() == 16, "all 16 device IDs are distinct")
	observations.icon_atlas_order = DEVICE_IDS.duplicate()

func _test_applications_and_caps() -> void:
	for card: Dictionary in device_cards:
		var run = _campaign_run()
		_prepare_prerequisites(card, run)
		var pool = CardPool.new(database.cards, 61)
		var cap := int(card.get("max_stacks", 1))
		var tags_before := int(run.tag_counts.get("机关", 0))
		for level in cap:
			check(pool.eligible(card, run), "%s remains eligible before level %d" % [card.id, level + 1])
			check(pool.apply_card(card, run), "%s applies without requiring a hero target" % card.id)
			check(int(run.buff_levels.get(card.id, 0)) == level + 1, "%s records the actual device upgrade level" % card.id)
		check(not pool.eligible(card, run), "%s disappears at its declared cap" % card.id)
		check(not pool.apply_card(card, run) and int(run.buff_levels[card.id]) == cap, "%s cannot be applied past cap" % card.id)
		check(int(run.tag_counts.get("机关", 0)) == cap + tags_before, "%s updates device family build tags" % card.id)
		check(bool(run.export_build().get("device_cards_enabled", false)), "%s keeps device context in exported build metadata" % card.id)
	# All combat families now share the finite level contract.
	var legacy: Dictionary = database.cards.filter(func(card: Dictionary) -> bool: return str(card.id) == "mechanic_twin_arc")[0]
	var legacy_run = _campaign_run()
	var legacy_pool = CardPool.new(database.cards, 66)
	for level in int(legacy.max_stacks):
		check(legacy_pool.apply_card(legacy, legacy_run), "combat mechanic card accepts level %d" % (level + 1))
	check(not legacy_pool.apply_card(legacy, legacy_run), "combat mechanic card cannot exceed its cap")

func _test_upgrade_priority() -> void:
	for first in EVOLUTION_IDS.size():
		var run = _campaign_run()
		_prepare_prerequisites(_card(EVOLUTION_IDS[first]), run)
		var pool = CardPool.new(database.cards, 62)
		check(pool.apply_card(_card(EVOLUTION_IDS[first]), run), "%s obtainable with prerequisite" % EVOLUTION_IDS[first])
		for tier in EVOLUTION_IDS.size():
			var expected := tier > first and not (first == 2 and tier == 3)
			check(pool.eligible(_card(EVOLUTION_IDS[tier]), run) == expected, "%s respects evolution branches after %s" % [EVOLUTION_IDS[tier], EVOLUTION_IDS[first]])
	var climbing_run = _campaign_run()
	var climbing_pool = CardPool.new(database.cards, 63)
	for id: String in EVOLUTION_IDS.slice(0, 3):
		check(climbing_pool.apply_card(_card(id), climbing_run), "successive plant upgrades can progress through %s" % id)
	check(not climbing_pool.apply_card(_card("device_melon"), climbing_run), "melon is an alternate branch rather than replacing Gatling")
	var melon_run = _campaign_run()
	_prepare_prerequisites(_card("device_melon"), melon_run)
	check(climbing_pool.apply_card(_card("device_melon"), melon_run), "botanist branch can progress directly to melon")
	for id: String in EVOLUTION_IDS:
		check(not climbing_pool.eligible(_card(id), melon_run), "%s never downgrades a melon-pult build" % id)

func _test_modes() -> void:
	var run = _campaign_run()
	var pool = CardPool.new(database.cards, 64)
	for card: Dictionary in device_cards:
		var fresh = _campaign_run()
		_prepare_prerequisites(card, fresh)
		check(pool.eligible(card, fresh), "normal campaign offers %s after prerequisites" % card.id)
	run.mode_id = "endless_survival"
	for card: Dictionary in device_cards:
		check(not pool.eligible(card, run), "endless cannot offer inactive-shop %s" % card.id)
	run.mode_id = "rift_watch"
	run.device_cards_enabled = false
	for card: Dictionary in device_cards:
		check(not pool.eligible(card, run), "workshop or disabled shop cannot offer %s" % card.id)
	run.device_cards_enabled = true
	run.reset_for_stage("stage_02")
	check(not run.device_cards_enabled, "stage resets clear the prior shop context until the new device shop configures it")
	for card: Dictionary in device_cards:
		check(not pool.eligible(card, run), "freshly reset disabled context cannot leak %s" % card.id)

func _test_offers() -> void:
	var run = _campaign_run()
	run.crystal_level = 4
	var seen: Dictionary = {}
	var rarities: Dictionary = {}
	var offers: Dictionary = {}
	var pool = CardPool.new(database.cards, 65)
	for seed_value in 512:
		pool.reseed(seed_value)
		var first := pool.draw_three(run)
		check(first.size() == 3, "level-four offer %d still contains three cards" % seed_value)
		check(first.any(func(card: Dictionary) -> bool: return str(card.get("family", "")) == "device"), "level-four offer %d guarantees an eligible device card" % seed_value)
		var ids: Array[String] = []
		for card: Dictionary in first:
			ids.append(str(card.id))
			check(pool.eligible(card, run), "seed %d exposes only currently eligible %s" % [seed_value, card.id])
			if str(card.get("family", "")) == "device":
				seen[str(card.id)] = true
				rarities[str(card.rarity)] = true
		check(ids.size() == 3 and ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2], "offer %d has no duplicate IDs" % seed_value)
		offers[",".join(ids)] = true
	check(seen.size() >= 6 and not seen.has("device_gatling") and not seen.has("device_melon"), "early draws offer foundational plants before final evolutions")
	check(rarities.has("common") and rarities.has("rare"), "early draws exercise common and rare device weights")
	check(offers.size() > 400, "new seeds vary actual device/combat combinations rather than using a fixed stage sequence")
	pool.reseed(810)
	var replay: Array[Dictionary] = pool.draw_three(run)
	var exact = CardPool.new(database.cards, 810)
	check(replay == exact.draw_three(run), "saved seeds reproduce the full weighted device offer")
	check(pool.reroll(run) and pool.rerolls_left == 1, "ordinary reroll replaces a device offer using the existing counter")
	check(pool.offered != replay, "reroll changes the offered combinations")
	for level in [8, 12, 16, 20]:
		run.crystal_level = level
		var offer := pool.draw_three(run)
		check(offer.size() == 3 and offer.any(func(card: Dictionary) -> bool: return str(card.get("family", "")) == "device"), "level %d retains three cards and a device option beside other guarantees" % level)
	run.mode_id = "endless_survival"
	for seed_value in 24:
		pool.reseed(seed_value)
		check(pool.draw_three(run).all(func(card: Dictionary) -> bool: return str(card.get("family", "")) != "device"), "endless actual draw %d contains no device cards" % seed_value)
	observations.random_draws = {"seeds":512, "unique_combinations":offers.size(), "reachable_device_ids":seen.keys(), "rarities":rarities.keys()}

func _test_icons() -> void:
	var required := "--qa-icons-required" in OS.get_cmdline_user_args()
	var ready := 0
	for card: Dictionary in device_cards:
		var path := str(card.get("icon", ""))
		var exists := ResourceLoader.exists(path)
		if required or exists:
			check(exists, "%s cropped icon is an imported resource" % card.id)
			check(Icons.card_path(card) == path, "%s resolves in rewards, compendium and buff HUD" % card.id)
			if exists:
				var texture := Icons.card_texture(card)
				check(texture != null and texture.get_width() >= 96 and texture.get_height() >= 96, "%s provides a usable full-size icon texture" % card.id)
				ready += int(texture != null)
	observations.icons = {"required":required, "ready":ready, "total":16}

func _test_real_simulation() -> void:
	var simulation_script = load("res://scripts/combat_simulation.gd")
	var sim = simulation_script.new(6501, true)
	var squad: Array[String] = ["traveler"]
	check(sim.battle_devices.enabled and sim.run_state.device_cards_enabled, "actual normal-stage device reset enables the card family")
	for stage_number in 8:
		sim.reset_stage("stage_%02d" % (stage_number + 1), squad, 6502 + stage_number)
		check(sim.battle_devices.limit == 25 and sim.run_state.device_cards_enabled, "actual normal stage %d has 25 device slots and matching card eligibility" % (stage_number + 1))
	sim.reset_stage("stage_01", squad, 6590)
	sim.run_state.crystal_level = 40
	var hero_attack_before: float = sim.heroes[0].damage
	var hero_range_before: float = sim.heroes[0].range
	sim.card_pool.offered.assign([_card("device_botanist")])
	check(sim.card_pool.take(0, sim), "actual reward taking applies the botanist card through the existing card pool")
	check(int(sim.run_state.buff_levels.get("device_botanist", 0)) == 1, "actual reward application records the device card level")
	check(sim.card_pool.history.back() == "植物学家" and sim.card_pool.offered.is_empty(), "actual reward choice closes and records the ordinary card history")
	check(is_equal_approx(sim.heroes[0].damage, hero_attack_before) and is_equal_approx(sim.heroes[0].range, hero_range_before), "device damage cards do not masquerade as generic hero buffs")
	check(sim.battle_devices.level("device_botanist") == 1, "actual take synchronizes botanist damage immediately without waiting for a tick")
	_test_immediate_existing_plants(sim)
	_test_existing_melon_branch(sim)
	sim.reset_stage("stage_endless", squad, 6591)
	check(not sim.battle_devices.enabled and not sim.run_state.device_cards_enabled, "actual endless reset disables device shop and cards together")
	for card: Dictionary in device_cards:
		check(not sim.card_pool.eligible(card, sim.run_state), "actual endless excludes %s" % card.id)
	sim.reset_stage("stage_01", squad, 6592)
	sim.run_state.crystal_level = 40
	check(sim.run_state.mode_id == "rift_watch" and sim.run_state.device_cards_enabled and sim.card_pool.eligible(_card("device_botanist"), sim.run_state), "endless-to-campaign transition restores device card offers")
	var workshop_script = load("res://scripts/workshop_session.gd")
	var workshop = workshop_script.new()
	check(not workshop.sim.run_state.device_cards_enabled, "actual workshop entry disables device cards after creating its campaign-derived simulation")
	for card: Dictionary in device_cards:
		check(not workshop.sim.card_pool.eligible(card, workshop.sim.run_state), "actual workshop excludes %s" % card.id)
	observations.actual_simulation = true

func _take_device_card(sim, id: String) -> bool:
	sim.card_pool.offered.assign([_card(id)])
	var taken: bool = sim.card_pool.take(0, sim)
	check(taken, "existing reward entry point accepts %s" % id)
	return taken

func _test_immediate_existing_plants(sim) -> void:
	var squad: Array[String] = ["traveler"]
	sim.reset_stage("stage_02", squad, 6580)
	sim.run_state.crystal_level = 40
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.geo_constructs.clear()
	for hero: Dictionary in sim.heroes:
		hero.deployed = false
	var devices = sim.battle_devices
	devices.gold = 100000
	var fixtures: Dictionary = {}
	var cells := {"pea":Vector2(430,360), "snowpea":Vector2(490,360), "barricade":Vector2(610,360), "power":Vector2(790,360), "range":Vector2(850,360)}
	for kind: String in cells:
		check(devices.select(sim, kind) and devices.place(sim, cells[kind]), "real reward-upgrade fixture deploys %s" % kind)
		fixtures[kind] = devices.placed.back()
	for id: String in EVOLUTION_IDS.slice(0, 3):
		var variant := str({"device_repeater":"repeater", "device_threepeater":"threepeater", "device_gatling":"gatling", "device_melon":"melon"}[id])
		_take_device_card(sim, id)
		check(str(fixtures.pea.visual_variant) == variant and str(fixtures.snowpea.visual_variant) == variant, "taking %s immediately transforms both already deployed pea species" % id)
	check(not sim.card_pool.eligible(_card("device_melon"), sim.run_state), "live Gatling build rejects alternate melon branch")
	var nut: Dictionary = fixtures.barricade
	nut.hp = float(nut.max_hp) * 0.6
	var old_max: float = nut.max_hp
	_take_device_card(sim, "device_iron_nut")
	check(str(nut.visual_variant) == "iron_nut" and is_equal_approx(float(nut.max_hp), old_max * 2.5) and float(nut.armor) == 30.0, "taking iron-nut immediately transforms and fortifies the existing nut")
	check(is_equal_approx(float(nut.hp) / float(nut.max_hp), 0.6), "iron-nut reward preserves the existing injury ratio")
	_take_device_card(sim, "device_nut_repair")
	check(is_equal_approx(float(nut.max_hp), old_max * 2.5 * 1.3), "taking nut-repair immediately applies its declared HP bonus")
	_take_device_card(sim, "device_rooted")
	check(is_equal_approx(float(nut.max_hp), old_max * 2.5 * 1.3 * 1.25), "taking rooted stacks with existing iron and nut-repair modifiers")
	check(is_equal_approx(float(nut.hp) / float(nut.max_hp), 0.6), "several live HP cards still preserve the injury ratio")
	_take_device_card(sim, "device_power_pad")
	check(is_equal_approx(devices.scale_at(fixtures.power.pos, "power"), 1.50), "taking power-pad immediately raises the live pad from 35 to 50 percent")
	_take_device_card(sim, "device_range_pad")
	check(is_equal_approx(devices.scale_at(fixtures.range.pos, "range"), 1.45), "taking range-pad immediately raises the live pad from 30 to 45 percent")
	var original_price: int = devices.price_of("pea")
	_take_device_card(sim, "device_soil_discount")
	check(devices.price_of("pea") == ceili(original_price * 0.9), "taking soil-discount immediately adjusts the next purchase price")
	var enemy: Dictionary = sim.spawn_enemy(Vector2(1090,360), "grunt")
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.armor = 0.0
	enemy.shield = 0.0
	enemy.speed = 0.0
	devices._fire(sim, fixtures.snowpea)
	check(not devices.shots.is_empty() and str(devices.shots.back().kind) == "snowpea" and bool(devices.shots.back().slow), "snowpea-to-Gatling reward preserves the original cold effect on actual projectiles")
	devices.shots.clear()
	_take_device_card(sim, "device_frost")
	devices._fire(sim, fixtures.pea)
	check(not devices.shots.is_empty() and bool(devices.shots.back().slow), "taking frost immediately affects future attacks of an existing transformed pea")
	_take_device_card(sim, "device_photosynthesis")
	_take_device_card(sim, "device_quick_growth")
	_take_device_card(sim, "device_mine_chain")
	_take_device_card(sim, "device_salvage")
	for id: String in DEVICE_IDS:
		if id in ["device_botanist", "device_melon"]:
			continue
		check(devices.level(id) == 1, "%s live modifier is synchronized by the real card reward entry point" % id)

func _test_existing_melon_branch(sim) -> void:
	var squad: Array[String] = ["traveler"]
	sim.reset_stage("stage_02", squad, 6581)
	sim.run_state.crystal_level = 40
	sim.state = "running"
	sim.terrain_features.clear()
	sim.enemies.clear()
	sim.enemy_lookup.clear()
	sim.geo_constructs.clear()
	for hero: Dictionary in sim.heroes:
		hero.deployed = false
	var devices = sim.battle_devices
	devices.gold = 100000
	check(devices.select(sim, "snowpea") and devices.place(sim, Vector2(490,360)), "melon branch fixture deploys an existing snowpea")
	var snowpea: Dictionary = devices.placed.back()
	_take_device_card(sim, "device_botanist")
	_take_device_card(sim, "device_melon")
	check(str(snowpea.visual_variant) == "melon" and devices.level("device_melon") == 1, "legal botanist-to-melon reward immediately transforms the existing snowpea")
	check(not sim.card_pool.eligible(_card("device_gatling"), sim.run_state), "melon branch rejects the alternate Gatling evolution")
	var enemy: Dictionary = sim.spawn_enemy(Vector2(1090,360), "grunt")
	enemy.spawn_timer = 0.0
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.armor = 0.0
	enemy.shield = 0.0
	enemy.speed = 0.0
	devices._fire(sim, snowpea)
	check(not devices.shots.is_empty() and str(devices.shots.back().kind) == "melon" and bool(devices.shots.back().slow), "snowpea-to-melon reward preserves the original cold effect on actual projectiles")
