# V29–V30 战斗视觉与关卡扩充 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** 连续完成 V29 战斗视觉成品化与 V30 地图、怪物、关卡扩充，并交付可运行的 Windows 构建和独立 GitHub 分支。

**Architecture:** 战斗数值继续由 `combat_simulation.gd` 驱动，表现层只消费时间轴事件；角色动画、特效主题、怪物外观和地图表现分别配置化。V29 先稳定动作、命中同步和技能反馈，V30 再扩充路线、传送门、怪物族群和 Boss 场地机制，避免表现代码反向污染数值模拟。

**Tech Stack:** Godot 4.4、GDScript、JSON 数据表、RGBA 序列帧、对象池、Windows 导出、Git 分支发布。

---

## 实验基线与统一验收指标

- 基线分支：`v28`，基线提交：`de4145c53be9f1499b8d7476341933e606b5a1fc`。
- V29 开发分支：`v29`；V30 开发分支从已验收的 `v29` 创建为 `v30`。
- 12:25 启动时先执行以下命令，确认基线后创建 V29 分支：

```powershell
git switch v28
git pull --ff-only origin v28
git switch -c v29
```
- 帧同步指标：伤害事件、命中特效、命中音效和顿帧相差不超过一个物理帧。
- 锚点指标：任意动画帧左右翻转后，脚底中心与阴影中心误差不超过 0.5 像素。
- 可读性指标：普通攻击预警、Boss 预警、玩家技能范围使用不同轮廓与色阶，实伤区域与显示区域误差不超过 2 像素。
- 性能指标：1920×1080、300 个敌人、180 个弹道、120 个短时特效时保持 55 FPS 以上；低配策略不得隐藏伤害预警。
- 内容指标：十二名角色均可走完呼吸、移动、攻击、受击、技能、终结技和阵亡状态；九张地图均拥有三条以上有效路线。

## 文件结构

- Create: `game/scripts/unit_visual_actor.gd`，统一角色序列帧、朝向、脚底锚点和状态切换。
- Create: `game/scripts/combat_feedback_director.gd`，将命中事件分发给伤害数字、特效、音效、顿帧和震屏。
- Create: `game/scripts/stage_surface_renderer.gd`，绘制道路床、地形暗示、动态路线箭头和传送门。
- Create: `game/data/v2/vfx_themes.json`，定义六元素与元素反应的表现组合。
- Create: `game/data/v2/enemy_families.json`，定义史莱姆族群、远程、飞行、支援与精英外观。
- Create: `game/scripts/qa_v29.gd`，验证动画、锚点、命中同步、特效引用和部署 UI。
- Create: `game/scripts/qa_v30.gd`，验证路线、传送门、怪物族群、Boss 阶段、地图完整性和性能预算。
- Modify: `game/scripts/battle_view.gd`，接入统一角色表现、反馈导演和地图表现节点。
- Modify: `game/scripts/combat_simulation.gd`，补齐动作事件、怪物行为、阶段事件和压力测试入口。
- Modify: `game/scripts/animation_state_machine.gd`，支持命中标记、非循环动作和攻速缩放。
- Modify: `game/scripts/vfx_pipeline.gd`，按主题生成弹道、命中、范围和持续特效。
- Modify: `game/scripts/battle_hud.gd`，升级角色状态、技能、终结技和预警信息。
- Modify: `game/scripts/squad_panel.gd`，重做角色卡、部署拖拽与合法落点反馈。
- Modify: `game/data/v2/animation_profiles.json`，登记十二名角色的七类动画与命中帧。
- Modify: `game/data/v2/stages.json`，配置九张地图的路线、地形、敌人波次和 Boss。
- Modify: `game/data/v2/stage_templates.json`，增加分叉、汇合、环形、移动平台和可破坏道路模板。
- Modify: `game/data/v2/boss_patterns.json`，完善六个 Boss 的三阶段招式与场地变化。
- Modify: `game/scripts/main.gd`，增加 V29/V30 专项测试入口。
- Modify: `README.md`、`game/project.godot`、`game/export_presets.cfg`，更新版本说明与构建路径。

---

### Task 1: 建立 V29 视觉审查基线

**Files:**
- Create: `game/scripts/qa_v29.gd`
- Modify: `game/scripts/main.gd`
- Modify: `game/scripts/battle_view.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(game.battle.debug_visual_matrix.size() == 24, "twelve heroes expose both facings")
expect(game.battle.debug_anchor_error_max <= 0.5, "feet and shadows stay aligned")
expect(game.battle.debug_damage_shape_error_max <= 2.0, "telegraph matches damage shape")
```

- [x] **Step 2: 运行测试并确认失败**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
```

Expected: FAIL，缺少视觉矩阵与误差统计。

- [x] **Step 3: 实现审查模式**

```gdscript
func build_visual_matrix() -> Array[Dictionary]:
    var rows: Array[Dictionary] = []
    for hero in sim.heroes:
        rows.append({"hero": hero.character_id, "facing": -1.0})
        rows.append({"hero": hero.character_id, "facing": 1.0})
    return rows
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
git add game/scripts/qa_v29.gd game/scripts/qa_v29.gd.uid game/scripts/main.gd game/scripts/battle_view.gd
git commit -m "test: add V29 visual acceptance matrix"
```

Expected: 双向矩阵、锚点与预警几何检查通过。

### Task 2: 统一十二名角色动画节点

**Files:**
- Create: `game/scripts/unit_visual_actor.gd`
- Modify: `game/scripts/battle_view.gd`
- Modify: `game/data/v2/animation_profiles.json`
- Test: `game/scripts/qa_v29.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
for character in game.sim.database.characters:
    var profile: Dictionary = game.sim.database.animation_profiles[character.id]
    for state in ["idle", "move", "attack", "hurt", "skill", "ultimate", "down"]:
        expect(profile.has(state), "%s owns %s animation" % [character.id, state])
```

- [x] **Step 2: 实现统一状态接口**

```gdscript
func play_state(next_state: String, attack_speed: float = 1.0) -> void:
    current_state = next_state
    sprite.speed_scale = attack_speed if next_state == "attack" else 1.0
    sprite.play(next_state)
```

- [x] **Step 3: 保留占位素材降级规则**

```gdscript
func resolved_animation(requested: String) -> String:
    if sprite.sprite_frames.has_animation(requested):
        return requested
    return "attack" if requested in ["skill", "ultimate"] else "idle"
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
git add game/scripts/unit_visual_actor.gd game/scripts/unit_visual_actor.gd.uid game/scripts/battle_view.gd game/data/v2/animation_profiles.json game/scripts/qa_v29.gd
git commit -m "feat: unify twelve character animation states"
```

### Task 3: 严格同步攻击命中帧

**Files:**
- Create: `game/scripts/combat_feedback_director.gd`
- Modify: `game/scripts/combat_timeline.gd`
- Modify: `game/scripts/combat_simulation.gd`
- Modify: `game/scripts/battle_view.gd`
- Test: `game/scripts/qa_v29.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(event.damage_frame == event.vfx_frame, "damage and VFX share one frame")
expect(event.damage_frame == event.sfx_frame, "damage and SFX share one frame")
expect(event.damage_frame == event.hit_stop_frame, "damage and hit stop share one frame")
```

- [x] **Step 2: 统一命中载荷**

```gdscript
var payload := {
    "kind": "impact",
    "source_id": source.id,
    "target_id": target.id,
    "frame": timeline.current_frame,
    "element": source.element,
    "critical": critical,
    "damage": damage,
}
```

- [x] **Step 3: 集中消费表现事件**

```gdscript
func present_impact(event: Dictionary) -> void:
    vfx_pipeline.spawn_impact(event)
    audio_director.play_hit(event)
    battle_view.apply_hit_stop(event)
    battle_view.apply_shake(event)
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
git add game/scripts/combat_feedback_director.gd game/scripts/combat_feedback_director.gd.uid game/scripts/combat_timeline.gd game/scripts/combat_simulation.gd game/scripts/battle_view.gd game/scripts/qa_v29.gd
git commit -m "feat: synchronize combat impact feedback"
```

### Task 4: 六元素与反应特效主题

**Files:**
- Create: `game/data/v2/vfx_themes.json`
- Modify: `game/scripts/vfx_pipeline.gd`
- Modify: `game/scripts/battle_view.gd`
- Modify: `game/scripts/content/game_database.gd`
- Test: `game/scripts/qa_v29.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
for element in ["anemo", "electro", "pyro", "hydro", "geo", "cryo"]:
    expect(db.vfx_themes.has(element), "%s owns projectile and impact themes" % element)
for reaction in ["vaporize", "melt", "overload", "electro_charged", "freeze", "swirl", "crystallize", "superconduct"]:
    expect(db.vfx_themes.has(reaction), "%s owns reaction feedback" % reaction)
```

- [x] **Step 2: 写入主题数据**

```json
{
  "pyro": {"projectile":"ember_comet","impact":"fire_bloom","trail":"heat_ribbon"},
  "hydro": {"projectile":"water_lance","impact":"splash_ring","trail":"bubble_stream"},
  "overload": {"impact":"shock_burst","shake":0.55,"hit_stop_ms":55}
}
```

- [x] **Step 3: 按主题生成表现**

```gdscript
func spawn_theme(theme_id: String, event: Dictionary) -> void:
    var theme: Dictionary = themes[theme_id]
    pool.acquire({"kind": theme.impact, "pos": event.pos, "element": theme_id})
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
git add game/data/v2/vfx_themes.json game/scripts/vfx_pipeline.gd game/scripts/battle_view.gd game/scripts/content/game_database.gd game/scripts/qa_v29.gd
git commit -m "feat: add elemental and reaction VFX themes"
```

### Task 5: 部署栏与战斗 HUD 成品化

**Files:**
- Modify: `game/scripts/squad_panel.gd`
- Modify: `game/scripts/battle_hud.gd`
- Modify: `game/scripts/main.gd`
- Test: `game/scripts/qa_v29.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(game.hud.hero_cards.size() == 3, "deployed squad owns three readable cards")
expect(game.hud.hero_cards.all(func(card): return card.has_energy and card.has_skill and card.has_ultimate), "cards expose combat actions")
expect(game.squad_panel.preview_has_anchor and game.squad_panel.preview_has_validity, "drag preview shows anchor and legal placement")
```

- [x] **Step 2: 实现角色卡布局**

```gdscript
func refresh_character_card(card: Control, hero: Dictionary) -> void:
    card.set_meta("element", hero.element)
    card.get_node("Health").value = hero.hp / hero.max_hp * 100.0
    card.get_node("Energy").value = hero.energy / hero.max_energy * 100.0
```

- [x] **Step 3: 实现部署反馈**

```gdscript
func update_deploy_preview(point: Vector2) -> void:
    deploy_preview_point = point
    deploy_preview_valid = sim.can_deploy(selected_id, point)
    queue_redraw()
```

- [x] **Step 4: 完成 V29 验收和发布**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v28-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game --export-release "Windows Desktop"
git add game/scripts/squad_panel.gd game/scripts/battle_hud.gd game/scripts/main.gd game/scripts/qa_v29.gd README.md game/project.godot game/export_presets.cfg docs/v29-release-notes.md
git commit -m "release: ship V29 combat presentation"
git push -u origin v29
```

Expected: V29 专项、V28–V17 关键回归通过，`builds/rift-guard-v29/RiftGuard-V29.exe` 可进入两种模式。

---

## V30 分支切换

V29 发布并确认 `HEAD` 与 `origin/v29` 一致后执行：

```powershell
git switch -c v30
```

### Task 6: 建立 V30 地图表现节点

**Files:**
- Create: `game/scripts/stage_surface_renderer.gd`
- Create: `game/scripts/qa_v30.gd`
- Modify: `game/scripts/battle_view.gd`
- Modify: `game/scripts/main.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(renderer.route_beds.size() >= 3, "stage exposes at least three readable routes")
expect(renderer.route_arrows_only_when_warned, "arrows appear only before spawning")
expect(renderer.route_overlap_alpha <= 0.35, "overlapping routes remain visually quiet")
```

- [x] **Step 2: 拆分地图表现职责**

```gdscript
func sync_stage(stage: Dictionary, warnings: Dictionary, portals: Dictionary) -> void:
    current_stage = stage
    route_warnings = warnings
    spawn_portals = portals
    queue_redraw()
```

- [x] **Step 3: 实现动态箭头**

```gdscript
var progress := fposmod(clock * speed + arrow_index * spacing, route_length)
var point := sample_route(route, progress)
var direction := sample_route_tangent(route, progress)
draw_arrow(point, direction, Color(accent, alpha))
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/scripts/stage_surface_renderer.gd game/scripts/stage_surface_renderer.gd.uid game/scripts/qa_v30.gd game/scripts/qa_v30.gd.uid game/scripts/battle_view.gd game/scripts/main.gd
git commit -m "feat: add data-driven stage surface renderer"
```

### Task 7: 动态传送门与多出生点

**Files:**
- Modify: `game/scripts/stage_surface_renderer.gd`
- Modify: `game/scripts/combat_simulation.gd`
- Modify: `game/data/v2/stages.json`
- Test: `game/scripts/qa_v30.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(portal.phases == ["forming", "opening", "active", "closing"], "portal owns four animation phases")
expect(stage.spawn_points.size() >= 5, "stage owns multiple legal spawn points")
expect(spawned_routes.size() >= 3, "encounter rotates through route starts")
```

- [x] **Step 2: 实现传送门状态**

```gdscript
func portal_phase(life: float, total: float) -> String:
    var ratio := 1.0 - life / total
    if ratio < 0.20: return "forming"
    if ratio < 0.38: return "opening"
    if ratio < 0.82: return "active"
    return "closing"
```

- [x] **Step 3: 根据路线选择出生点**

```gdscript
func select_spawn(route_id: String, encounter_index: int) -> Vector2:
    var points: Array = current_stage.spawn_points[route_id]
    return points[encounter_index % points.size()]
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/scripts/stage_surface_renderer.gd game/scripts/combat_simulation.gd game/data/v2/stages.json game/scripts/qa_v30.gd
git commit -m "feat: animate portals across multiple spawn points"
```

### Task 8: 扩充怪物族群与史莱姆行为

**Files:**
- Create: `game/data/v2/enemy_families.json`
- Modify: `game/scripts/content/game_database.gd`
- Modify: `game/scripts/combat_simulation.gd`
- Modify: `game/scripts/battle_view.gd`
- Test: `game/scripts/qa_v30.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
for kind in ["slime_split", "slime_heal", "slime_shield", "slime_bomb", "slime_elemental"]:
    expect(db.enemy_families.has(kind), "%s is configured" % kind)
expect(sim.debug_enemy_behaviors_unique >= 12, "enemy roster owns twelve distinct behaviors")
```

- [x] **Step 2: 定义族群数据**

```json
{
  "slime_split":{"visual":"electro_slime","behavior":"split_on_death","children":2},
  "slime_heal":{"visual":"hydro_slime","behavior":"healing_pulse","interval":6.0},
  "slime_bomb":{"visual":"pyro_slime","behavior":"death_burst","radius":110}
}
```

- [x] **Step 3: 分发行为**

```gdscript
func tick_enemy_behavior(enemy: Dictionary, dt: float) -> void:
    match enemy.behavior:
        "healing_pulse": tick_healing_pulse(enemy, dt)
        "split_on_death": pass
        "death_burst": tick_volatile_warning(enemy, dt)
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/data/v2/enemy_families.json game/scripts/content/game_database.gd game/scripts/combat_simulation.gd game/scripts/battle_view.gd game/scripts/qa_v30.gd
git commit -m "feat: expand slime and enemy behavior families"
```

### Task 9: 九张地图路线与地形机制

**Files:**
- Modify: `game/data/v2/stage_templates.json`
- Modify: `game/data/v2/stages.json`
- Modify: `game/scripts/stages/stage_runtime.gd`
- Modify: `game/scripts/stage_surface_renderer.gd`
- Test: `game/scripts/qa_v30.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
for stage in db.stages:
    expect(stage.routes.size() >= 3, "%s owns three routes" % stage.id)
    expect(stage.terrain.size() >= 4, "%s owns readable terrain cues" % stage.id)
expect(db.stage_templates.has("fork") and db.stage_templates.has("loop") and db.stage_templates.has("breakable_shortcut"), "advanced route templates exist")
```

- [x] **Step 2: 增加路线模板**

```json
{
  "fork":{"branches":2,"merge":true},
  "loop":{"closed":true,"laps":1},
  "breakable_shortcut":{"blocked":true,"break_hp":900}
}
```

- [x] **Step 3: 让地形暗示路线**

```gdscript
func route_material(route_kind: String) -> Dictionary:
    return {"ground":"#4b3034", "edge":"#a65b57", "glow":0.18} if route_kind == "main" else {"ground":"#332b38", "edge":"#725565", "glow":0.10}
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/data/v2/stage_templates.json game/data/v2/stages.json game/scripts/stages/stage_runtime.gd game/scripts/stage_surface_renderer.gd game/scripts/qa_v30.gd
git commit -m "feat: expand nine tactical map layouts"
```

### Task 10: 六个三阶段 Boss 的场地演出

**Files:**
- Modify: `game/data/v2/boss_patterns.json`
- Modify: `game/scripts/combat_simulation.gd`
- Modify: `game/scripts/stage_surface_renderer.gd`
- Modify: `game/scripts/battle_hud.gd`
- Test: `game/scripts/qa_v30.gd`

- [x] **Step 1: 写入失败测试**

```gdscript
expect(db.boss_patterns.size() == 6, "six bosses remain available")
for boss in db.boss_patterns.values():
    expect(boss.phases.size() == 3, "%s owns three phases" % boss.id)
    expect(boss.phases.all(func(phase): return phase.has("arena_event")), "%s changes the arena every phase" % boss.id)
```

- [x] **Step 2: 定义阶段场地事件**

```json
{
  "threshold":0.65,
  "arena_event":{"kind":"seal_route","route":"lower","duration":12.0},
  "moves":["crossfire","elite_summon"]
}
```

- [x] **Step 3: 同步转阶段演出**

```gdscript
func enter_boss_phase(enemy: Dictionary, phase: Dictionary) -> void:
    emit_event({"kind":"boss_phase", "boss_id":enemy.kind, "phase":enemy.phase})
    stage_runtime.apply_arena_event(phase.arena_event)
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/data/v2/boss_patterns.json game/scripts/combat_simulation.gd game/scripts/stage_surface_renderer.gd game/scripts/battle_hud.gd game/scripts/qa_v30.gd
git commit -m "feat: add staged boss arena events"
```

### Task 11: 大规模战斗性能与视觉降级

**Files:**
- Modify: `game/scripts/performance_budget.gd`
- Modify: `game/scripts/reusable_effect_pool.gd`
- Modify: `game/scripts/battle_view.gd`
- Modify: `game/scripts/combat_simulation.gd`
- Test: `game/scripts/qa_v30.gd`

- [x] **Step 1: 写入压力测试**

```gdscript
sim.debug_spawn_load(300, 180, 120)
expect(sim.enemies.size() <= sim.MAX_ENEMIES, "enemy cap is respected")
expect(game.battle.effect_pool.live_count <= game.battle.effect_pool.capacity, "effect pool is bounded")
expect(game.battle.debug_telegraphs_visible, "performance degradation preserves warnings")
```

- [x] **Step 2: 分级表现预算**

```gdscript
func quality_for_load(enemy_count: int, projectile_count: int) -> float:
    var pressure := enemy_count / 300.0 + projectile_count / 180.0
    return clampf(1.0 - maxf(0.0, pressure - 1.0) * 0.35, 0.45, 1.0)
```

- [x] **Step 3: 保留战斗信息优先级**

```gdscript
func can_spawn_cosmetic(kind: String) -> bool:
    if kind in ["telegraph", "projectile", "impact"]:
        return true
    return performance_budget.quality_scale >= 0.70
```

- [x] **Step 4: 验证并提交**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
git add game/scripts/performance_budget.gd game/scripts/reusable_effect_pool.gd game/scripts/battle_view.gd game/scripts/combat_simulation.gd game/scripts/qa_v30.gd
git commit -m "perf: protect large-scale battle readability"
```

### Task 12: V30 综合验收、构建和发布

**Files:**
- Create: `docs/v30-release-notes.md`
- Modify: `README.md`
- Modify: `game/project.godot`
- Modify: `game/export_presets.cfg`

- [x] **Step 1: 执行专项与回归**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v29-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v28-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v26-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v25-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v20-test
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v17-test
```

Expected: 所有专项和回归为 0 failures。

- [x] **Step 2: 导出并直接启动发布包**

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game --export-release "Windows Desktop"
.\builds\rift-guard-v30\RiftGuard-V30.exe --headless -- --v30-test
.\builds\rift-guard-v30\RiftGuard-V30.exe --headless -- --v17-test
```

Expected: 两次启动退出码均为 0。

- [x] **Step 3: 清理旧构建并记录哈希**

```powershell
Get-FileHash .\builds\rift-guard-v30\RiftGuard-V30.exe -Algorithm SHA256
```

Expected: `builds` 只保留 `rift-guard-v30`，发布说明记录文件大小与 SHA256。

- [x] **Step 4: 提交并推送 V30**

```powershell
git add README.md docs/v30-release-notes.md game/project.godot game/export_presets.cfg game/scripts/stage_surface_renderer.gd game/scripts/stage_surface_renderer.gd.uid game/scripts/qa_v30.gd game/scripts/qa_v30.gd.uid game/scripts/main.gd game/scripts/battle_view.gd game/scripts/combat_simulation.gd game/scripts/content/game_database.gd game/scripts/stages/stage_runtime.gd game/scripts/battle_hud.gd game/scripts/performance_budget.gd game/scripts/reusable_effect_pool.gd game/data/v2/enemy_families.json game/data/v2/stages.json game/data/v2/stage_templates.json game/data/v2/boss_patterns.json
git commit -m "release: ship V30 maps monsters and encounters"
git push -u origin v30
```

Expected: 本地 `HEAD` 与 `origin/v30` 一致，受跟踪工作区无未提交修改。

## 自审结果

- V29 覆盖角色动作、双向锚点、命中同步、六元素特效、元素反应、部署和 HUD。
- V30 覆盖地图地形、动态路线、传送门、多出生点、怪物族群、史莱姆行为、六个 Boss、性能预算和发布。
- 计划未依赖尚未提供的最终角色素材，缺失动作会走明确的降级动画，后续替换无需修改战斗逻辑。
- 每个任务均包含可观察的失败条件、实现接口、验收命令和独立提交节点。
