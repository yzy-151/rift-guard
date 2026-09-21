# Slime King Two-Phase Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build four bespoke Slime King skills across exactly two phases and convert Rift Commander's enraged laser into a three-beam ±60-degree fan.

**Architecture:** Keep boss gameplay authoritative in `combat_simulation.gd`, boss definitions in `boss_patterns.json`, and rendering in `battle_view.gd`. Use dedicated event payloads so warning geometry, damage geometry, and visual geometry consume the same points, radii, angles, and phase values.

**Tech Stack:** Godot 4.4, GDScript, JSON content data, procedural CanvasItem drawing, WAV SFX.

---

### Task 1: Focused failing tests

**Files:**
- Create: `game/tests/qa_slime_king_focus.gd`
- Modify: `game/tests/qa_rift_boss_focus.gd`

- [ ] **Step 1: Add assertions for the Rift Commander fan geometry**

Assert that the phase-three `rift_laser` event exposes three targets whose normalized directions have dot products equal to `cos(60°)` against the center beam.

- [ ] **Step 2: Add Slime King phase and skill assertions**

Assert that `boss_02` stays in phase one above 50%, enters phase two at 50%, never enters phase three, and exposes `slime_bounce`, `slime_burst`, `slime_reflux`, and `slime_court`.

- [ ] **Step 3: Run the focused tests before implementation**

Run:
`Godot_v4.4.1-stable_win64_console.exe --headless --path game --script res://tests/qa_slime_king_focus.gd`

Expected: FAIL because the custom Slime King methods and event payloads do not exist.

### Task 2: Data and phase model

**Files:**
- Modify: `game/data/v2/boss_patterns.json`
- Modify: `game/scripts/combat_simulation.gd`

- [ ] **Step 1: Replace the three generic Slime King phase rows with two custom rows**

Phase one and two both list:
`["slime_bounce", "slime_burst", "slime_reflux", "slime_court"]`.

- [ ] **Step 2: Special-case Slime King phase thresholds**

In `_update_boss_phase`, compute `target_phase = 2 if ratio <= 0.50 else 1` for `boss_02`; retain the existing three-phase rule for every other boss.

- [ ] **Step 3: Run the phase assertions**

Expected: Slime King transitions once at 50% and never produces phase 3.

### Task 3: Authoritative skill geometry and damage

**Files:**
- Modify: `game/scripts/combat_simulation.gd`
- Test: `game/tests/qa_slime_king_focus.gd`

- [ ] **Step 1: Implement `_start_slime_warning`**

Lock landing points, projectile landing points, reflux center/radius, and court targets at cast start.

- [ ] **Step 2: Implement `_execute_slime_special`**

Resolve:
- `slime_bounce`: 3/5 ellipse hits with knockback.
- `slime_burst`: 5/10 projectiles with elemental colors.
- `slime_reflux`: pull, damage, and shield restoration.
- `slime_court`: 5/10 orbiting image charges and explosions.

- [ ] **Step 3: Add enemy slime pools and projectile resolution**

Tick short-lived pools after enemy projectiles, damage at a bounded pulse rate, slow heroes inside them, and emit `slime_pool` plus impact events.

- [ ] **Step 4: Convert Rift Commander phase-three laser to three rotated targets**

Create directions at -60°, 0°, and +60° from the center aim and use the same target list for damage and visuals.

- [ ] **Step 5: Run focused headless verification**

Expected: all gameplay assertions pass with zero failures.

### Task 4: Warnings, effects, and sprite motion

**Files:**
- Modify: `game/scripts/battle_view.gd`
- Test: `game/tests/qa_slime_king_focus.gd`

- [ ] **Step 1: Draw Slime King warnings from simulation payloads**

Use projected ellipses for bounce and pools, a contracting ellipse for reflux, and five colored orbit points plus locked charge paths for the court.

- [ ] **Step 2: Draw impact effects behind units**

Render elastic splash crowns, colored glob trails, fading pools, contracting rings, and orbiting elemental images.

- [ ] **Step 3: Add skill-specific squash and stretch**

Use `special_move` and warning progress in `_draw_slime_enemy` while preserving proportional texture scaling.

- [ ] **Step 4: Draw the Rift Commander fan from three shared-origin targets**

Render three warning ribbons and three impact ribbons using the exact event target list.

### Task 5: Four dedicated skill sounds

**Files:**
- Create: `tools/build_slime_king_sfx.py`
- Create: `game/assets/sfx/boss/slime_bounce.wav`
- Create: `game/assets/sfx/boss/slime_burst.wav`
- Create: `game/assets/sfx/boss/slime_reflux.wav`
- Create: `game/assets/sfx/boss/slime_court.wav`
- Modify: `game/scripts/main.gd`

- [ ] **Step 1: Generate distinct WAV assets**

Generate elastic impact, bubbling volley, suction pulse, and royal multi-impact sounds at 48 kHz stereo.

- [ ] **Step 2: Register the four event-to-player mappings**

Create SFX players on the SFX bus and trigger them from the matching event kinds.

- [ ] **Step 3: Verify each stream loads**

Assert that all four players have non-null streams in the graphical focused test.

### Task 6: Visual capture and final verification

**Files:**
- Create: `game/tests/qa_slime_king_gifs.gd`
- Output: `outputs/slime-king-gifs/*.gif`

- [ ] **Step 1: Capture phase-two warnings and impacts at 24 FPS**

Record each skill from warning start through effect fade.

- [ ] **Step 2: Encode GIFs without overwriting prior artifacts**

Write new files with a `_phase2` suffix.

- [ ] **Step 3: Run final checks**

Run the focused headless test, focused graphical test, and `git diff --check`.

Expected: zero test failures, all WAV streams loaded, and four GIFs produced.
