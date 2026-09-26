# V86 Card Refresh and Synergy Implementation Plan

Goal: add two free refreshes per reward offer and eight discoverable, bounded card combinations; export and publish the current game.

Architecture: CardPool owns offer RNG and refresh budget. CardSynergies owns declarative recipes and activation only on card acquisition. Hero-local combinations use hero card effects; team combinations use run inventory. Runtime damage hooks read cached activation flags, without per-frame card scans. Reward UI reads semantic layout fields and blocks refresh while choosing a target or reading the recipe overlay.

Tech stack: Godot 4.4.1, GDScript, JSON, Windows embedded-PCK release, GitHub CLI.

- [x] Refactor weighted draw to preserve eligibility/guarantees, avoid seen cards when possible, expose two-refresh limit and revision.
- [x] Add eight recipes, idempotent activation, same-hero requirements, snapshot preservation and dynamic support/orbit/meteor modifiers.
- [x] Add R/button refresh, focused-card hints, recipe overlay, activation captions and target-specific tooltip.
- [x] Validate RNG determinism, budgets, limited pools, character scope, damage/healing, inheritance, actual UI at 1280/1920/2560 and UI Lab profile checks.
- [x] Export V86 EXE, smoke-test it, commit current game changes, push descriptive branch and create GitHub release; set published branch as default per standing user request.

Refresh: each new draw gets 2, each refresh costs 1, no reward consumed, no stale-target refresh, no refresh after a pick.
Recipes activate once; duplicates strengthen their original card only. Existing tag bonuses remain separate.
