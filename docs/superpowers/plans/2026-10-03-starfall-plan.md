# Starfall Implementation Plan

> Execute in this session using subagent-driven-development for bounded components and independent review. All tasks remain authorized by the user's broad rebuild request.

**Goal:** Deliver a cohesive, playable action defense roguelite retaining V86 character and monster art.

**Architecture:** New Godot scene in `game/starfall/`, independent deterministic combat state, event-driven renderer and native Control interface. Keep `game/main.tscn` as V86 archive access.

**Tech Stack:** Godot 4.6, GDScript, existing 24 FPS atlases, generated painted arena.

- [x] Download exact V86 and validate official Godot executable.
- [x] Inspect reference video, existing source and character manifests; select visual direction.
- [x] Create `catalog.gd` and `simulation.gd`, starting with failing behavioral assertions in `tests/test_simulation.gd`. API: `start(mode,squad,seed)`, `step(dt,input,aim)`, `cast(slot,aim)`, `dash(direction)`, `choose_upgrade(id)`. Dictionary entities retain stable IDs; projectile and hazard collisions happen in simulation.
- [x] Create native `interface.gd` for title, squad, HUD, upgrades, pause/settings and result. Signals request actions; UI never changes combat entities directly.
- [x] Create `arena.gd` for original animated actors, new environment, telegraphs, layered VFX, feedback and camera; consume simulation events once per frame.
- [x] Create `main.gd` / `main.tscn` for input routing, settings and records, sound, scene transitions, and QA capture options. Change project default to new scene.
- [x] Run pure simulation tests under `--headless --path game --script res://starfall/tests/test_simulation.gd`; fix all parse/runtime failures.
- [x] Render and inspect all important screens with real Godot, exercise full campaign/endless progression and reduced effects settings; record evidence.
- [x] Independent spec and code review, fix findings, package runnable Windows game and write Chinese instructions. Record actual limits and validation.

Use UTF-8 source. New Chinese text uses bundled Tiejili font with system fallback; Latin headings use bundled Crimson Pro. Keep assets at original paths and dimensions. Source controls use visible named scene nodes where practical; gameplay tuning stays centralized. No third-party plugin required for the new scene.
