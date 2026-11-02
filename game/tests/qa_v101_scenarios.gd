extends SceneTree
## Run with --headless --path game --script res://tests/qa_v101_scenarios.gd -- --qa-output=<directory>.
const Session = preload("res://scripts/workshop_session.gd")
const Scenarios = preload("res://scripts/workshop_scenarios.gd")
var checks := 0
var failures: Array[String] = []
var output := ""
var store

class FailedCommit extends Scenarios:
	func _replace_file(_temporary: String, _destination: String) -> Error:
		return ERR_FILE_CANT_WRITE

class LockedCommit extends Scenarios:
	func _replace_file(temporary: String, destination: String) -> Error:
		# On Windows the live source handle makes the real MoveFileW fail.
		var held := FileAccess.open(temporary, FileAccess.READ)
		var result := super._replace_file(temporary, destination)
		if held != null: held.close()
		return result

func _init() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _card(session, id: String) -> Dictionary:
	for row: Dictionary in session.sim.database.cards:
		if str(row.id) == id: return row
	return {}

func _hero(session, id: String) -> Dictionary:
	for row: Dictionary in session.sim.heroes:
		if str(row.character_id) == id: return row
	return {}

func _point(session, offset: int = 0) -> Vector2:
	var count := 0
	var area: Rect2 = Session.Sim.ENDLESS_ARENA if session.sim.endless_mode else Session.Sim.MOVE_AREA
	for y in range(int(area.position.y) + 80, int(area.end.y) - 80, 70):
		for x in range(int(area.position.x) + 80, int(area.end.x) - 80, 70):
			var point := Vector2(x, y)
			if session.legal(point, 50.0):
				if count == offset: return point
				count += 1
	return Vector2(-10000, -10000)

func _write(slot: int, data: Variant) -> void:
	var file := FileAccess.open(store.slot_path(slot), FileAccess.WRITE)
	_check(file != null, "fixture file opens")
	if file != null:
		file.store_string(JSON.stringify({"slot_id":slot, "generation":store._generation(store.slot_path(slot)), "config":data}))
		file.close()

func _reject(data: Variant, label: String) -> void:
	_write(3, data)
	var result: Dictionary = store.load_slot(3)
	_check(not result.ok and not str(result.error).is_empty() and not result.has("session"), label)

func _roster_replay() -> void:
	var chronological = Session.new()
	var chronology_store = Scenarios.new(output.path_join("roster_%d" % Time.get_ticks_usec()))
	_check(chronological.place_hero("traveler", _point(chronological)), "chronology deploy traveler")
	_check(chronological.apply_card(_card(chronological, "relic_drop_glass")), "chronology first shared relic")
	_check(chronological.place_hero("hero_01", _point(chronological, 1)), "chronology later hero creation")
	var later_base: float = _hero(chronological, "hero_01").damage
	_check(chronology_store.save_slot(1, chronological).ok, "save creation chronology")
	var result: Dictionary = chronology_store.load_slot(1)
	_check(result.ok, "load creation chronology")
	if not result.ok: return
	_check(_hero(result.session, "hero_01").damage == later_base, "later-created hero does not retroactively receive shared relic")
	chronological.remove_selected()
	# This third hero is affected by a shared relic but never directly receives any card.
	_check(chronological.place_hero("hero_02", _point(chronological, 2)), "create indirect hidden beneficiary")
	chronological.remove_selected()
	chronological.selected_kind = "hero"
	chronological.selected_id = 0
	_check(chronological.apply_card(_card(chronological, "relic_drop_glass")), "shared relic reaches already-existing hidden heroes")
	_check(chronological.apply_card(_card(chronological, "element_resonance_hydro")), "element applied with hidden roster")
	_check(chronology_store.save_slot(1, chronological).ok, "save indirect hidden beneficiaries")
	result = chronology_store.load_slot(1)
	_check(result.ok, "load indirect hidden beneficiaries")
	if not result.ok: return
	_check(not _hero(result.session, "hero_02").deployed and _hero(result.session, "hero_02").damage == _hero(chronological, "hero_02").damage, "hidden non-target retains shared relic")
	_check(chronological.place_hero("hero_01", _point(chronological, 1)), "redeploy previous hero without recreation")
	_check(chronological.apply_card(_card(chronological, "orbit_arcane_blades")), "orbital created before hiding")
	chronological.remove_selected()
	chronological.selected_kind = "hero"
	chronological.selected_id = 0
	_check(chronological.apply_card(_card(chronological, "orbit_spell_rings")), "summon tag while other orbital dormant")
	_check(chronological.apply_card(_card(chronological, "orbit_spell_rings")), "summon synergy threshold while orbital dormant")
	_check(chronological.apply_card(_card(chronological, "v75_gargoyle_plate")), "guardian bundle applied")
	_check(chronology_store.save_slot(1, chronological).ok, "save dormant orbital chronology")
	result = chronology_store.load_slot(1)
	_check(result.ok, "load dormant orbital chronology")
	if not result.ok: return
	var dormant: Dictionary = chronological.dormant_orbitals[1][0]
	var restored_dormant: Dictionary = result.session.dormant_orbitals[1][0]
	_check(dormant.damage == restored_dormant.damage and dormant.radius == restored_dormant.radius and dormant.count == restored_dormant.count, "dormant orbital avoids later active-only synergies")
	_check(_hero(result.session, "traveler").card_levels == _hero(chronological, "traveler").card_levels, "guardian effect levels restored")
	_check(chronological.place_hero("hero_01", _point(chronological, 3)), "restore hidden orbital on redeploy")
	_check(chronological.apply_card(_card(chronological, "single_health_common")), "card after redeploy")
	_check(chronology_store.save_slot(1, chronological).ok, "save final redeployment")
	result = chronology_store.load_slot(1)
	_check(result.ok, "load final redeployment")
	if not result.ok: return
	for id: String in ["traveler", "hero_01", "hero_02"]:
		for field: String in ["damage", "max_hp", "armor", "projectile_count", "crit_chance", "element", "deployed", "pos"]:
			_check(_hero(result.session, id)[field] == _hero(chronological, id)[field], "chronology %s %s matches" % [id, field])
	_check(JSON.stringify(chronology_store.capture(result.session)) == JSON.stringify(chronology_store.capture(chronological)), "full historical rosters roundtrip without drift")
	_check(chronology_store._generation_paths(1).size() == 2, "repeated saves keep exactly two immutable generations")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	if output.is_empty():
		printerr("V101 SCENARIOS: --qa-output= 必须指定隔离测试目录。")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	# Every execution uses a new child, so no real slots or previous QA evidence are overwritten.
	store = Scenarios.new(output.path_join("slots_%d" % Time.get_ticks_usec()))
	_check(not store.slot_info(1).occupied, "empty slot")
	_check(not store.load_slot(1).ok, "missing slot fails cleanly")
	var original = Session.new()
	original.change_map("stage_endless", "frost_isles")
	_check(original.place_hero("traveler", _point(original)), "place traveler")
	_check(original.apply_card(_card(original, "single_attack_common")), "apply attack card")
	_check(original.apply_card(_card(original, "element_resonance_hydro")), "apply hydro first")
	_check(original.apply_card(_card(original, "element_resonance_pyro")), "apply pyro second")
	var companion := ""
	for id: String in original.sim.database.characters:
		if id != "traveler": companion = id; break
	_check(original.place_hero(companion, _point(original, 1)), "place companion")
	_check(original.apply_card(_card(original, "single_health_common")), "apply hidden hero card")
	_check(original.apply_card(_card(original, "orbit_arcane_blades")), "apply hidden hero orbit")
	original.remove_selected()
	_check(original.place_enemy("grunt", _point(original, 2)), "place living enemy")
	_check(original.place_enemy("runner", _point(original, 3)), "place dead enemy fixture")
	original.sim.enemies.back().hp = 0.0
	original.auto_attack = false
	original.enemy_action = false
	original.invulnerable = false
	original.infinite_energy = false
	original.speed = 0.5
	original.sim.elapsed = 93.5
	_hero(original, "traveler").hp = 1.0
	_hero(original, "traveler").energy = 1.0
	_hero(original, "traveler").damage_done = 1234.0
	original.sim.projectiles.append({"fixture": true})
	var data: Dictionary = store.capture(original)
	_check(not data.is_empty(), "capture valid scene")
	_check(data.get("heroes", []).size() == 2, "capture keeps hidden card target")
	_check(data.get("enemies", []).size() == 1, "capture excludes dead enemies")
	_check(not JSON.stringify(data).contains("damage_done") and not data.has("projectiles"), "configuration contains no runtime combat state")
	var before := JSON.stringify(data)
	for slot in range(1, 4):
		_check(store.save_slot(slot, original).ok, "save slot %d" % slot)
		_check(store.slot_info(slot).occupied and not str(store.slot_info(slot).summary).is_empty(), "slot %d summary" % slot)
	var second = Scenarios.new(store.directory)
	var loaded: Dictionary = second.load_slot(1)
	_check(loaded.ok, "cross-instance reload")
	if loaded.ok:
		var restored = loaded.session
		_check(restored != original and restored.sim != original.sim, "new independent session")
		_check(restored.stage_id == "stage_endless" and restored.layout_id == "frost_isles", "map and layout restored")
		_check(restored.paused and restored.sim.elapsed == 0.0, "load starts paused at zero")
		_check(not restored.auto_attack and not restored.enemy_action and not restored.invulnerable and not restored.infinite_energy and restored.speed == 0.5, "all settings restored")
		_check(_hero(restored, "traveler").hp == _hero(restored, "traveler").max_hp and _hero(restored, "traveler").energy == _hero(restored, "traveler").max_energy, "restored fresh health and energy")
		_check(_hero(restored, "traveler").damage == _hero(original, "traveler").damage, "attack card replays from catalog")
		_check(_hero(restored, "traveler").element == "pyro", "ordered elemental cards preserve final element")
		_check(not _hero(restored, companion).deployed and _hero(restored, companion).max_hp == _hero(original, companion).max_hp, "hidden build retained without deployment")
		_check(restored.dormant_orbitals.has(int(_hero(restored, companion).id)), "hidden orbital build retained")
		_check(restored.sim.enemies.size() == 1 and restored.sim.enemies[0].hp == restored.sim.enemies[0].max_hp, "only live enemies restored at full health")
		_check(restored.sim.projectiles.is_empty() and _hero(restored, "traveler").damage_done == 0.0, "runtime effects and counters reset")
		_check(JSON.stringify(store.capture(restored)) == before, "configuration roundtrip exact")
	_check(JSON.stringify(store.capture(original)) == before and original.sim.elapsed == 93.5 and _hero(original, "traveler").hp == 1.0 and original.sim.projectiles.size() == 1, "capture/save/load leave original session unchanged")
	# Alternate slots stay independent after replacement.
	var empty = Session.new()
	_check(second.save_slot(2, empty).ok, "replace existing slot atomically")
	_check(second.load_slot(2).session.stage_id == "stage_01" and second.load_slot(1).session.stage_id == "stage_endless", "slots are independent")
	_check(second._generation_paths(2).size() == 2, "two complete immutable generations retained")
	var latest_slot_two := second.slot_path(2)
	var interrupted := FileAccess.open(latest_slot_two + ".tmp_crash", FileAccess.WRITE)
	interrupted.store_string("incomplete newer write")
	interrupted.flush()
	interrupted.close()
	_check(second.load_slot(2).session.stage_id == "stage_01", "interrupted uncommitted write ignored")
	interrupted = FileAccess.open(latest_slot_two, FileAccess.WRITE)
	interrupted.store_string("corrupted generation")
	interrupted.close()
	var recovered: Dictionary = second.load_slot(2)
	_check(recovered.ok and recovered.session.stage_id == "stage_endless" and not str(recovered.warning).is_empty(), "corrupt newest generation recovers previous with explicit warning")
	_check("恢复" in str(second.slot_info(2).summary), "fallback warning visible in slot summary")
	_check(second.save_slot(2, empty).ok and second._generation_paths(2).size() == 2, "new successful commit prunes only old generations")
	var bad: Dictionary = data.duplicate(true)
	bad.schema_version = 999
	_reject(bad, "reject unknown schema")
	bad = data.duplicate(true); bad.stage_id = "missing_stage"
	_reject(bad, "reject unknown map")
	bad = data.duplicate(true); bad.layout_id = "missing_layout"
	_reject(bad, "reject unknown layout")
	bad = data.duplicate(true); bad.stage_id = "stage_01"
	_reject(bad, "reject non-endless alternate layout")
	bad = data.duplicate(true); bad.heroes[0].character_id = "missing_hero"
	_reject(bad, "reject unknown hero")
	bad = data.duplicate(true); bad.heroes.append(bad.heroes[0].duplicate(true))
	_reject(bad, "reject duplicate hero")
	bad = data.duplicate(true); bad.heroes[0].position = [1e99, 1]
	_reject(bad, "reject out-of-bounds coordinates")
	bad = data.duplicate(true); bad.heroes[0].position = ["NaN", 1]
	_reject(bad, "reject nonnumeric coordinate")
	bad = data.duplicate(true); bad.heroes[0].position = [500, 320]
	_reject(bad, "reject placement in frost island terrain")
	bad = data.duplicate(true); bad.heroes = [false]
	_reject(bad, "reject wrong hero row type")
	bad = data.duplicate(true); bad.settings.auto_attack = 1
	_reject(bad, "reject coercible nonboolean flag")
	bad = data.duplicate(true); bad.settings.speed = 0.0
	_reject(bad, "reject unsupported speed")
	bad = data.duplicate(true); bad.enemies[0].kind = "missing_enemy"
	_reject(bad, "reject unknown enemy")
	bad = data.duplicate(true); bad.cards_applied[0].card_id = "missing_card"
	_reject(bad, "reject unknown card")
	bad = data.duplicate(true); bad.cards_applied[0].hero_character_id = "missing_hero"
	_reject(bad, "reject missing card target")
	bad = data.duplicate(true); bad.cards_applied[1].hero_character_id = companion
	_reject(bad, "reject nontraveler elemental target")
	bad = data.duplicate(true); bad.cards_applied[0].card = {"effect": "attack_multiplier", "value": 1000}
	_reject(bad, "reject serialized runtime card dictionary")
	bad = data.duplicate(true); bad.cards_applied[0].erase("roster")
	_reject(bad, "reject missing historical roster")
	bad = data.duplicate(true); bad.cards_applied[0].roster[0].deployed = false
	_reject(bad, "reject undeployed historical card target")
	bad = data.duplicate(true); bad.cards_applied[0].roster[0].character_id = companion
	_reject(bad, "reject historical creation order mismatch")
	bad = data.duplicate(true); bad.heroes = null
	_reject(bad, "reject null collection")
	# JSON input is untyped; wrong nested types must produce errors, never VM errors.
	for field: String in ["format", "schema_version", "stage_id", "layout_id", "heroes", "enemies", "cards_applied", "settings"]:
		bad = data.duplicate(true); bad[field] = {"unexpected": [false, null]}
		_reject(bad, "reject object in field " + field)
	bad = data.duplicate(true); bad.settings.speed = "0.5"
	_reject(bad, "reject string speed instead of number")
	bad = data.duplicate(true); bad.heroes[0].position = [true, false]
	_reject(bad, "reject boolean coordinates")
	bad = data.duplicate(true); bad.cards_applied = [null]
	_reject(bad, "reject null card row")
	_reject([], "reject nonobject document")
	bad = data.duplicate(true)
	for index in Scenarios.MAX_ENEMIES + 1: bad.enemies.append(data.enemies[0].duplicate(true))
	_reject(bad, "reject excessive enemy count")
	bad = data.duplicate(true)
	for index in Scenarios.MAX_CARDS + 1: bad.cards_applied.append(data.cards_applied[0].duplicate(true))
	_reject(bad, "reject excessive cards")
	var broken := FileAccess.open(store.slot_path(3), FileAccess.WRITE)
	broken.store_string('{"schema_version":1,"bad":NaN}')
	broken.close()
	_check(not store.load_slot(3).ok, "reject malformed/nonfinite JSON")
	_check(store.slot_info(3).occupied and not str(store.slot_info(3).error).is_empty(), "corrupt slot is occupied with error")
	broken = FileAccess.open(store.slot_path(3), FileAccess.WRITE)
	broken.store_string(" ".repeat(Scenarios.MAX_FILE_BYTES + 1))
	broken.close()
	_check(not store.load_slot(3).ok, "reject oversized file before parse")
	for slot in [-1, 0, 4, 2147483647]:
		_check(not store.save_slot(slot, original).ok and not store.load_slot(slot).ok and not str(store.slot_info(slot).error).is_empty(), "reject slot bounds %d" % slot)
	var saved_bytes := FileAccess.get_file_as_bytes(store.slot_path(1))
	var temporaries_before := 0
	for file_name: String in DirAccess.get_files_at(store.directory):
		if ".tmp_" in file_name: temporaries_before += 1
	var failed_commit = FailedCommit.new(store.directory)
	_check(not failed_commit.save_slot(1, original).ok and FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes, "failed commit preserves existing slot bytes")
	if OS.get_name() == "Windows":
		var locked_commit = LockedCommit.new(store.directory)
		_check(not locked_commit.save_slot(1, original).ok, "real OS rename fails with locked source")
		_check(FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes and store.load_slot(1).ok, "real failed OS move leaves previous generation readable")
	var temporaries := 0
	for file_name: String in DirAccess.get_files_at(store.directory):
		if ".tmp_" in file_name: temporaries += 1
	_check(temporaries == temporaries_before, "failed commit removes only its own temporary file")
	_hero(original, "traveler").pos = Vector2(NAN, 1)
	_check(not store.save_slot(1, original).ok and FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes, "NaN save rejects without damaging old slot")
	_hero(original, "traveler").pos = _point(original)
	original.cards_applied.append({"hero_id": 99999, "card": _card(original, "single_attack_common")})
	_check(not store.save_slot(1, original).ok and FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes, "dangling runtime card target cannot silently disappear")
	original.cards_applied.pop_back()
	var old_roster: Variant = original.cards_applied[0].roster
	original.cards_applied[0].erase("roster")
	_check(not store.save_slot(1, original).ok and FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes, "old in-memory builds without roster are explicitly rejected")
	original.cards_applied[0].roster = old_roster
	var blocker := output.path_join("blocked_%d" % Time.get_ticks_usec())
	broken = FileAccess.open(blocker, FileAccess.WRITE)
	broken.store_string("blocked")
	broken.close()
	var blocked_store = Scenarios.new(blocker.path_join("slots"))
	_check(not blocked_store.save_slot(1, original).ok, "directory I/O failure returns error")
	_check(FileAccess.get_file_as_bytes(store.slot_path(1)) == saved_bytes, "I/O and corrupt-load failures leave good slot intact")
	_check(original.sim.elapsed == 93.5 and original.sim.projectiles.size() == 1, "all failed loads leave active combat untouched")
	_roster_replay()
	var report := {"checks":checks, "failures":failures, "failure_count":failures.size(), "slots_directory":store.directory, "timestamp":Time.get_datetime_string_from_system(true)}
	var report_file := FileAccess.open(output.path_join("v101_scenarios_report.json"), FileAccess.WRITE)
	if report_file != null: report_file.store_string(JSON.stringify(report, "\t")); report_file.close()
	print("V101 SCENARIOS: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
