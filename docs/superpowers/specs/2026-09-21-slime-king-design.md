# Slime King Two-Phase Skill Design

## Scope

This change has two connected parts:

1. Change Rift Commander's enraged laser from three parallel lanes to three beams sharing one origin, with the side beams at ±60 degrees from the center beam.
2. Replace Slime King's generic boss moves with four bespoke skills that operate in exactly two phases.

## Combat Goals

Slime King should read as elastic, elemental, and territorial. Every warning shape must match the damage shape. Phase two begins at 50% health and upgrades all four skills without introducing a third phase.

## Rift Commander Laser

In phase three, the center beam aims at the nearest living deployed hero. The left and right beams start at the same boss position and rotate the center direction by -60 and +60 degrees. All three extend to the battlefield edge and use the same width, warning, impact, and hit calculation.

## Slime King Skills

### 1. Royal Bounce

The boss compresses, then marks three elliptical landing zones in phase one and five in phase two. It resolves each landing in sequence, dealing area damage and knocking heroes away. Phase two lands faster, uses larger ellipses, and ends with a central crown-shaped shockwave.

### 2. Five-Color Slime Burst

The boss fires five elemental slime globules in phase one and ten in phase two. Each globule travels toward a locked landing point and bursts in a matching elemental color. The impact leaves a short-lived slime pool that damages and slows heroes inside it. Phase two globules are larger, faster, and produce wider pools.

### 3. Devouring Reflux

A wide slime ring contracts toward the boss. Heroes caught by the ring are pulled inward before the center detonates. Damage dealt restores boss shield. Phase two performs two contractions, applies a stronger pull, and restores more shield.

### 4. Split Royal Court

The boss creates five elemental slime images around itself. Each image orbits briefly, then charges toward a locked hero and explodes. Phase two images attack in two staggered volleys and create a final five-color detonation around the boss.

## Phase Rules

- Phase 1: 100% to above 50% health.
- Phase 2: 50% health or below.
- The transition enlarges and recolors the boss, restores part of its shield, emits a presentation event, and immediately shortens the next special timer.
- Slime King never enters phase 3.

## Presentation

The existing Slime King art remains proportionally scaled. Skill windups use squash and stretch rather than replacing the sprite. Skill effects render behind character silhouettes, use projected ellipses for ground areas, and fade smoothly. Each skill has a distinct synthesized SFX bound to its resolution event.

## Verification

A focused simulation test verifies the two-phase threshold, warning counts, damage areas, pull/knockback, shield restoration, projectiles, pools, and the Rift Commander ±60-degree beam directions. A graphical test captures warning and impact frames for all four Slime King skills.
