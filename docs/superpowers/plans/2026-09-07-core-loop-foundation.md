# Core Loop Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a playable first vertical slice with an eight-character roster, a maximum three-character squad, a five-minute stage, crystal XP level-ups, dynamic three-card rewards, per-stage Traveler element locking, and complete run-state reset.

**Architecture:** Add focused data and domain modules beside the current fixed-step simulation, then migrate `combat_simulation.gd` through a small compatibility boundary. Keep rendering event-driven and keep all content references behind stable IDs so placeholder assets can be replaced without changing combat code.

**Tech Stack:** Godot 4.4.1, typed GDScript, JSON content files, existing headless SceneTree tests, fixed-step simulation.

---

## Delivery roadmap

This plan is phase one of four independently testable deliveries:

1. Core loop foundation: roster, squad, stage duration, XP, rewards, Traveler element lock and reset.
2. Element combat and active abilities: eight reactions, elemental application, Geo construct and Anemo tornado.
3. Stage and enemy expansion: tile deployment, multiple routes and maps, flying/ranged/support/shield enemies and bosses.
4. Progression and polish: chapter dialogue gates, unlocks, codices, save migration, horde optimization and combat feel.

Only phase one is implemented by this plan.

## File structure

- Create `game/data/v2/characters.json`: eight character records with stable IDs and replaceable asset keys.
- Create `game/data/v2/cards.json`: phase-one pool of 100 configured card records.
- Create `game/data/v2/stages.json`: stage timing, XP thresholds, waves and unlock IDs.
- Create `game/data/v2/asset_manifest.json`: logical asset keys mapped to current placeholders.
- Create `game/scripts/content/game_database.gd`: load and validate version-two JSON content.
- Create `game/scripts/run/run_state.gd`: own all per-stage state and reset boundaries.
- Create `game/scripts/rewards/crystal_progression.gd`: accumulate XP and queue level-ups.
- Create `game/scripts/rewards/card_pool.gd`: filter, weight and draw three unique eligible cards.
- Create `game/scripts/stages/stage_runtime.gd`: run a stage for at least five minutes and schedule waves.
- Create `game/tests/test_game_database.gd`: validate IDs, counts and cross-references.
- Create `game/tests/test_run_state.gd`: verify squad and stage reset rules.
- Create `game/tests/test_crystal_progression.gd`: verify XP overflow and queued selections.
- Create `game/tests/test_card_pool_v2.gd`: verify field-only targeting, rarity and element locking.
- Create `game/tests/test_stage_runtime.gd`: verify five-minute duration and final boss wave.
- Modify `game/scripts/combat_simulation.gd`: consume new run, stage, XP and reward services.
- Modify `game/scripts/reward_panel.gd`: show rarity, target, crystal level and queued upgrade count.
- Modify `game/scripts/battle_hud.gd`: display stage clock, crystal XP and current Traveler element.
- Modify `game/scripts/main.gd`: start a configured stage and resolve queued rewards.
- Modify `game/scripts/qa_suite.gd`: exercise the new vertical slice.
- Modify `game/project.godot`: replace the obsolete M9 description.

### Task 1: Version-two content database

**Files:**
- Create: `game/data/v2/characters.json`
- Create: `game/data/v2/cards.json`
- Create: `game/data/v2/stages.json`
- Create: `game/data/v2/asset_manifest.json`
- Create: `game/scripts/content/game_database.gd`
- Test: `game/tests/test_game_database.gd`

- [ ] **Step 1: Write the failing content validation test**

```gdscript
extends SceneTree
const Database = preload("res://scripts/content/game_database.gd")

func _initialize() -> void:
	var db = Database.new()
	assert(db.errors.is_empty(), str(db.errors))
	assert(db.characters.size() == 8)
	assert(db.cards.size() >= 100)
	assert(db.stages.has("stage_01"))
	assert(db.characters["traveler"].element == "none")
	assert(db.characters.values().all(func(c): return db.assets.has(c.asset_key)))
	print("GAME DATABASE PASSED")
	quit()
```

- [ ] **Step 2: Run the database test and verify the missing preload failure**

Run:

```powershell
& 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path game -s res://tests/test_game_database.gd
```

Expected: FAIL because `res://scripts/content/game_database.gd` does not exist.

- [ ] **Step 3: Add the database loader and strict validators**

```gdscript
extends RefCounted

var characters: Dictionary = {}
var cards: Array[Dictionary] = []
var stages: Dictionary = {}
var assets: Dictionary = {}
var errors: Array[String] = []

func _init() -> void:
	characters = _by_id(_read("res://data/v2/characters.json"), "characters")
	cards.assign(_read("res://data/v2/cards.json"))
	stages = _by_id(_read("res://data/v2/stages.json"), "stages")
	assets = _read("res://data/v2/asset_manifest.json")
	_validate()

func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		errors.append("missing file: " + path)
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		errors.append("invalid json: " + path)
		return []
	return parsed

func _by_id(rows: Array, label: String) -> Dictionary:
	var result := {}
	for row: Dictionary in rows:
		var id: String = row.get("id", "")
		if id.is_empty() or result.has(id):
			errors.append("invalid or duplicate %s id: %s" % [label, id])
		else:
			result[id] = row
	return result

func _validate() -> void:
	var elements := ["none", "anemo", "electro", "pyro", "hydro", "geo", "cryo"]
	for id: String in characters:
		var row: Dictionary = characters[id]
		if row.get("element", "") not in elements:
			errors.append("invalid character element: " + id)
		if not assets.has(row.get("asset_key", "")):
			errors.append("missing character asset key: " + id)
	for card: Dictionary in cards:
		if card.get("target", "global") == "character" and not characters.has(card.get("character_id", "")):
			errors.append("card target missing: " + card.get("id", ""))
```

- [ ] **Step 4: Add eight character records and the replaceable asset manifest**

Use IDs `traveler`, `hero_02`, `hero_03`, `hero_04`, `hero_05`, `hero_06`, `hero_07`, and `hero_08`. Every record contains `id`, `name`, `role`, `element`, `max_hp`, `armor`, `attack`, `attack_rate`, `attack_range`, `move_speed`, `block`, `can_hit_air`, and `asset_key`. Only `traveler` has `unlocked_by_default: true`; all other records use `unlocked_by_default: false`.

Map every asset key in `asset_manifest.json` to an existing placeholder under `res://assets/`. The manifest value shape is:

```json
{
  "character.traveler": {
    "portrait": "res://assets/portraits/jessica.png",
    "idle": "res://assets/tiny-dungeon.png",
    "attack": "res://assets/tiny-dungeon.png",
    "hurt": "res://assets/tiny-dungeon.png"
  }
}
```

- [ ] **Step 5: Generate and validate exactly 100 phase-one cards**

Add 64 character cards, 18 Traveler element cards, 12 global cards and 6 reaction preparation cards. Each row contains:

```json
{
  "id": "traveler_attack_common_1",
  "name": "磨亮剑锋",
  "description": "旅行者攻击力提高12%",
  "rarity": "common",
  "weight": 60,
  "target": "character",
  "character_id": "traveler",
  "effect": "attack_multiplier",
  "value": 0.12,
  "max_stacks": 5,
  "requires": [],
  "excludes": []
}
```

The six element assignment cards use `effect: "assign_traveler_element"`, one of `anemo`, `electro`, `pyro`, `hydro`, `geo`, or `cryo` as `value`, `rarity: "common"`, and `max_stacks: 1`.

- [ ] **Step 6: Add stage one content**

Set `duration_seconds` to `330`, `boss_at_seconds` to `270`, `starting_squad` to `["traveler"]`, and provide XP thresholds `[40, 90, 150, 220, 300, 390, 490, 600, 720, 850, 990, 1140, 1300, 1470, 1650]` so the content validator can calculate that stage one supports at least twelve choices from its configured enemy budget.

- [ ] **Step 7: Run the database test**

Expected: `GAME DATABASE PASSED` with exit code 0.

- [ ] **Step 8: Commit the content boundary**

```powershell
git add -- game/data/v2 game/scripts/content/game_database.gd game/tests/test_game_database.gd
git commit -m "feat: add validated game content database"
```

### Task 2: Per-stage run state and three-character squad

**Files:**
- Create: `game/scripts/run/run_state.gd`
- Test: `game/tests/test_run_state.gd`

- [ ] **Step 1: Write failing tests for squad limits and reset**

```gdscript
extends SceneTree
const RunState = preload("res://scripts/run/run_state.gd")

func _initialize() -> void:
	var run = RunState.new()
	assert(run.set_squad(["traveler", "hero_02", "hero_03"]))
	assert(not run.set_squad(["traveler", "hero_02", "hero_03", "hero_04"]))
	run.traveler_element = "hydro"
	run.buff_levels["traveler_attack_common_1"] = 3
	run.crystal_level = 8
	run.crystal_xp = 510
	run.reset_for_stage("stage_02")
	assert(run.traveler_element == "none")
	assert(run.buff_levels.is_empty())
	assert(run.crystal_level == 1 and run.crystal_xp == 0)
	assert(run.squad == ["traveler", "hero_02", "hero_03"])
	print("RUN STATE PASSED")
	quit()
```

- [ ] **Step 2: Run the test and verify it fails because `run_state.gd` is missing**

- [ ] **Step 3: Implement explicit permanent and per-stage fields**

```gdscript
extends RefCounted

const MAX_SQUAD_SIZE := 3
var stage_id := ""
var squad: Array[String] = ["traveler"]
var traveler_element := "none"
var buff_levels: Dictionary = {}
var crystal_level := 1
var crystal_xp := 0
var pending_level_ups := 0
var legendary_count := 0

func set_squad(ids: Array[String]) -> bool:
	if ids.is_empty() or ids.size() > MAX_SQUAD_SIZE or ids.size() != ids.duplicate().size():
		return false
	squad = ids.duplicate()
	return true

func reset_for_stage(next_stage_id: String) -> void:
	stage_id = next_stage_id
	traveler_element = "none"
	buff_levels.clear()
	crystal_level = 1
	crystal_xp = 0
	pending_level_ups = 0
	legendary_count = 0
```

- [ ] **Step 4: Run `test_run_state.gd` and expect `RUN STATE PASSED`**

- [ ] **Step 5: Commit**

```powershell
git add -- game/scripts/run/run_state.gd game/tests/test_run_state.gd
git commit -m "feat: add isolated per-stage run state"
```

### Task 3: Crystal XP with overflow-safe queued level-ups

**Files:**
- Create: `game/scripts/rewards/crystal_progression.gd`
- Test: `game/tests/test_crystal_progression.gd`

- [ ] **Step 1: Write the failing progression test**

```gdscript
extends SceneTree
const Progression = preload("res://scripts/rewards/crystal_progression.gd")

func _initialize() -> void:
	var run = {"crystal_level": 1, "crystal_xp": 0, "pending_level_ups": 0}
	var xp = Progression.new([40, 90, 150])
	xp.grant(run, 155)
	assert(run.crystal_level == 4)
	assert(run.crystal_xp == 155)
	assert(run.pending_level_ups == 3)
	assert(xp.consume_choice(run))
	assert(run.pending_level_ups == 2)
	print("CRYSTAL PROGRESSION PASSED")
	quit()
```

- [ ] **Step 2: Run the test and verify the missing script failure**

- [ ] **Step 3: Implement cumulative thresholds without discarding overflow**

```gdscript
extends RefCounted

var thresholds: Array[int] = []

func _init(values: Array) -> void:
	thresholds.assign(values)

func grant(run, amount: int) -> void:
	if amount <= 0:
		return
	run.crystal_xp += amount
	while run.crystal_level <= thresholds.size() and run.crystal_xp >= thresholds[run.crystal_level - 1]:
		run.crystal_level += 1
		run.pending_level_ups += 1

func consume_choice(run) -> bool:
	if run.pending_level_ups <= 0:
		return false
	run.pending_level_ups -= 1
	return true
```

- [ ] **Step 4: Run `test_crystal_progression.gd` and expect success**

- [ ] **Step 5: Commit**

```powershell
git add -- game/scripts/rewards/crystal_progression.gd game/tests/test_crystal_progression.gd
git commit -m "feat: add crystal experience progression"
```

### Task 4: Dynamic weighted card pool and Traveler element lock

**Files:**
- Create: `game/scripts/rewards/card_pool.gd`
- Test: `game/tests/test_card_pool_v2.gd`

- [ ] **Step 1: Write failing eligibility and draw tests**

```gdscript
extends SceneTree
const Database = preload("res://scripts/content/game_database.gd")
const RunState = preload("res://scripts/run/run_state.gd")
const CardPool = preload("res://scripts/rewards/card_pool.gd")

func _initialize() -> void:
	var db = Database.new()
	var run = RunState.new()
	run.set_squad(["traveler"])
	var pool = CardPool.new(db.cards, 42)
	var first := pool.draw_three(run)
	assert(first.size() == 3)
	assert(first.any(func(c): return c.effect == "assign_traveler_element"))
	assert(first.all(func(c): return c.get("character_id", "traveler") == "traveler"))
	assert(pool.apply_element(run, "hydro"))
	for seed_value in 100:
		pool.reseed(seed_value)
		assert(pool.draw_three(run).all(func(c): return c.get("effect", "") != "assign_traveler_element" or c.value == "hydro"))
	print("CARD POOL V2 PASSED")
	quit()
```

- [ ] **Step 2: Run the test and verify failure**

- [ ] **Step 3: Implement one eligibility function used by both draw and apply**

```gdscript
func eligible(card: Dictionary, run) -> bool:
	if card.get("target", "global") == "character" and card.character_id not in run.squad:
		return false
	if int(run.buff_levels.get(card.id, 0)) >= int(card.get("max_stacks", 1)):
		return false
	if card.get("rarity", "common") == "legendary" and run.legendary_count >= 2:
		return false
	if card.get("effect", "") == "assign_traveler_element":
		return run.traveler_element == "none" or card.value == run.traveler_element
	var required_element: String = card.get("requires_element", "")
	if not required_element.is_empty() and required_element != run.traveler_element:
		return false
	for id: String in card.get("requires", []):
		if not run.buff_levels.has(id):
			return false
	for id: String in card.get("excludes", []):
		if run.buff_levels.has(id):
			return false
	return true
```

- [ ] **Step 4: Implement weighted unique draw with first-choice guarantee**

Create candidates from `eligible`. If `run.crystal_level == 2` and `run.traveler_element == "none"`, select one weighted element assignment first. Fill the remaining positions using rarity weight without replacement. Fall back to eligible global reserve cards only when fewer than three normal cards remain.

- [ ] **Step 5: Implement `apply_element` and reject changing an existing element**

```gdscript
func apply_element(run, element: String) -> bool:
	if element not in ["anemo", "electro", "pyro", "hydro", "geo", "cryo"]:
		return false
	if run.traveler_element != "none" and run.traveler_element != element:
		return false
	run.traveler_element = element
	return true
```

- [ ] **Step 6: Run the card pool test over all 100 seeds**

Expected: `CARD POOL V2 PASSED`, with no non-squad target and no alternate element after locking Hydro.

- [ ] **Step 7: Commit**

```powershell
git add -- game/scripts/rewards/card_pool.gd game/tests/test_card_pool_v2.gd
git commit -m "feat: add dynamic weighted card pool"
```

### Task 5: Five-minute stage runtime and scheduled boss

**Files:**
- Create: `game/scripts/stages/stage_runtime.gd`
- Test: `game/tests/test_stage_runtime.gd`

- [ ] **Step 1: Write failing timing tests**

```gdscript
extends SceneTree
const Runtime = preload("res://scripts/stages/stage_runtime.gd")

func _initialize() -> void:
	var events: Array[Dictionary] = []
	var stage = Runtime.new({"duration_seconds": 330.0, "boss_at_seconds": 270.0, "waves": [{"at": 0.0, "enemy_id": "grunt", "count": 2, "interval": 1.0}]})
	for frame in 329 * 60:
		events.append_array(stage.tick(1.0 / 60.0))
	assert(events.filter(func(e): return e.kind == "spawn").size() == 2)
	assert(events.filter(func(e): return e.kind == "boss_wave").size() == 1)
	assert(not stage.time_complete)
	for frame in 60:
		events.append_array(stage.tick(1.0 / 60.0))
	assert(stage.elapsed >= 330.0 and stage.time_complete)
	print("STAGE RUNTIME PASSED")
	quit()
```

- [ ] **Step 2: Run the test and verify the missing script failure**

Expected: FAIL because `res://scripts/stages/stage_runtime.gd` does not exist.

- [ ] **Step 3: Implement deterministic wave scheduling**

```gdscript
extends RefCounted

var definition: Dictionary
var elapsed := 0.0
var time_complete := false
var boss_emitted := false
var wave_cursors: Array[int] = []

func _init(stage_definition: Dictionary) -> void:
	definition = stage_definition.duplicate(true)
	wave_cursors.resize(definition.get("waves", []).size())
	wave_cursors.fill(0)

func tick(dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	elapsed += maxf(dt, 0.0)
	for i in definition.get("waves", []).size():
		var wave: Dictionary = definition.waves[i]
		while wave_cursors[i] < int(wave.count) and elapsed >= float(wave.at) + wave_cursors[i] * float(wave.interval):
			events.append({"kind": "spawn", "enemy_id": wave.enemy_id, "route_id": wave.get("route_id", "main")})
			wave_cursors[i] += 1
	if not boss_emitted and elapsed >= float(definition.boss_at_seconds):
		boss_emitted = true
		events.append({"kind": "boss_wave", "enemy_id": definition.get("boss_id", "boss_01")})
	time_complete = elapsed >= float(definition.duration_seconds)
	return events
```

- [ ] **Step 4: Run the stage timing test**

Expected: boss emitted exactly once and stage cannot complete before 330 seconds.

- [ ] **Step 5: Commit**

```powershell
git add -- game/scripts/stages/stage_runtime.gd game/tests/test_stage_runtime.gd
git commit -m "feat: add deterministic five-minute stage runtime"
```

### Task 6: Integrate the services into fixed-step combat

**Files:**
- Modify: `game/scripts/combat_simulation.gd`
- Modify: `game/scripts/main.gd`
- Test: `game/tests/test_combat.gd`
- Test: `game/tests/test_rewards.gd`

- [ ] **Step 1: Add a failing integration assertion**

Create a simulation with `stage_01`, assert that it starts with one Traveler, kill enemies with different XP values, and verify crystal XP equals the sum. Grant enough XP for two thresholds, verify state becomes `reward`, choose once, and verify a second reward remains queued.

- [ ] **Step 2: Run both legacy tests and record their current passing baseline**

```powershell
& 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path game -s res://tests/test_combat.gd
& 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path game -s res://tests/test_rewards.gd
```

- [ ] **Step 3: Add service dependencies and a configured constructor**

`CombatSimulation` owns `database`, `run_state`, `crystal`, `card_pool`, and `stage_runtime`. `reset_stage(stage_id, squad_ids)` rebuilds runtime heroes from character IDs, preserves the selected squad, and calls `run_state.reset_for_stage(stage_id)`.

- [ ] **Step 4: Replace wave-end reward triggers with XP level-up triggers**

Enemy death calls `crystal.grant(run_state, enemy.xp)`. If `pending_level_ups > 0` and no reward is open, set state to `reward` and call `card_pool.draw_three(run_state)`. After a choice, consume exactly one queued level-up; open the next reward immediately when more remain, otherwise resume the prior battle state.

- [ ] **Step 5: Make victory require both elapsed duration and cleared final enemies**

Set `won` only when `stage_runtime.time_complete`, the boss wave was emitted, no configured spawns remain and `enemies` is empty. Do not offer rewards after state changes to `won`.

- [ ] **Step 6: Keep a compatibility fixture for legacy three-hero tests**

Add `reset_legacy_fixture()` used only by old tests while the renderer and UI migrate. Production startup must use `reset_stage("stage_01", ["traveler"])`.

- [ ] **Step 7: Run combat and reward tests**

Expected: all legacy assertions still pass through their fixture and all new integration assertions pass through production stage startup.

- [ ] **Step 8: Commit**

```powershell
git add -- game/scripts/combat_simulation.gd game/scripts/main.gd game/tests/test_combat.gd game/tests/test_rewards.gd
git commit -m "feat: integrate stage XP rewards into combat"
```

### Task 7: Reward and battle HUD migration

**Files:**
- Modify: `game/scripts/reward_panel.gd`
- Modify: `game/scripts/battle_hud.gd`
- Modify: `game/scripts/main.gd`
- Test: `game/scripts/qa_suite.gd`

- [ ] **Step 1: Add failing UI assertions**

Assert the HUD shows `旅行者`, `无元素`, a `0 / 40` crystal XP label and a stage timer starting at `05:30`. Force a level-up, assert exactly three cards appear, and assert each card has a rarity label. Select Hydro and assert the HUD changes to `水` and future offers contain no other assignment element.

- [ ] **Step 2: Run `--ui-test` and verify the new assertions fail**

```powershell
& 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path game -- --ui-test
```

- [ ] **Step 3: Bind HUD text to new state**

Display `MM:SS`, current wave label, crystal level, current XP and next threshold, and Traveler element. Use a six-entry localized element dictionary and display `无元素` for `none`.

- [ ] **Step 4: Style reward cards by rarity**

Use stable colors: common `#B8C0CC`, rare `#69A7E8`, epic `#B77AE8`, legendary `#E9B85D`. Display rarity, target name, current stack and maximum stack. Do not put asset paths or internal IDs on player-facing UI.

- [ ] **Step 5: Support queued selections**

The reward heading displays `待选择 N` when multiple level-ups were crossed in one frame. Selecting a card refreshes the same modal with the next offer until the queue reaches zero.

- [ ] **Step 6: Run the UI suite at 1280×720, 1600×900 and 1920×1080**

Expected: no clipped cards, exactly three focusable choices, correct XP and element text, and battle input blocked while choosing.

- [ ] **Step 7: Commit**

```powershell
git add -- game/scripts/reward_panel.gd game/scripts/battle_hud.gd game/scripts/main.gd game/scripts/qa_suite.gd
git commit -m "feat: show crystal progression and rarity rewards"
```

### Task 8: End-to-end reset and five-minute vertical slice

**Files:**
- Modify: `game/scripts/qa_suite.gd`
- Modify: `game/project.godot`
- Create: `docs/phase-1-validation/REPORT.md`

- [ ] **Step 1: Add a deterministic accelerated stage scenario**

Drive the fixed-step simulation without rendering until at least twelve rewards have been chosen, select Hydro as the first element assignment, complete the boss wave, and enter `won` only after simulated time reaches 330 seconds.

- [ ] **Step 2: Assert full stage reset**

Start `stage_02` with the same squad and assert: crystal level 1, XP 0, no pending choices, empty Buff history, zero legendary cards, Traveler element `none`, no enemies, no projectiles, no constructs and no active reactions.

- [ ] **Step 3: Run all focused tests**

```powershell
$godot = 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe'
& $godot --headless --path game -s res://tests/test_game_database.gd
& $godot --headless --path game -s res://tests/test_run_state.gd
& $godot --headless --path game -s res://tests/test_crystal_progression.gd
& $godot --headless --path game -s res://tests/test_card_pool_v2.gd
& $godot --headless --path game -s res://tests/test_stage_runtime.gd
& $godot --headless --path game -s res://tests/test_combat.gd
& $godot --headless --path game -s res://tests/test_rewards.gd
```

Expected: every process exits 0 and prints its final `PASSED` marker.

- [ ] **Step 4: Run the UI smoke test**

```powershell
& 'C:\Users\23081\Desktop\codex\.tools\godot\Godot_v4.4.1-stable_win64_console.exe' --headless --path game -- --ui-test
```

Expected: exit code 0 with no parser errors and no failed UI assertions.

- [ ] **Step 5: Update project metadata and write validation evidence**

Change `config/description` to describe the phase-one core loop. Record the exact commands, Godot version, passing assertion counts, simulated stage duration, number of choices, selected Traveler element, reset results and remaining phase-two limitations in `docs/phase-1-validation/REPORT.md`.

- [ ] **Step 6: Commit phase-one verification**

```powershell
git add -- game/scripts/qa_suite.gd game/project.godot docs/phase-1-validation/REPORT.md
git commit -m "test: verify core loop vertical slice"
```

## Completion criteria

Phase one is complete only when all eight tasks are committed, all focused headless tests pass, the UI test passes, stage one cannot end before 330 simulated seconds, at least twelve card selections occur, only fielded characters contribute cards, Traveler cannot change element during a stage, and stage two begins with all temporary progression cleared.
