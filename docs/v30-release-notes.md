# V30 发布说明

V30 聚焦关卡战场、敌人族群、Boss 场地变化和大规模战斗可读性。

## 新增内容

- 九张地图都配置至少三条路线、四种地形暗示和多组合法出生点。
- 路线警告只在敌军到来前出现，箭头沿完整折线路径连续流动。
- 传送门具备凝聚、展开、活跃、闭合四阶段动画，并随实际出生点移动。
- 敌人族群表包含十七个现有战斗单位与五个史莱姆扩展原型；生成时会继承族群、变体、行为和动作字段。
- 六个 Boss 的十八个阶段都拥有独立场地事件，包括封路、安全区移动、风道、炮击网格、地形破坏和时间迟滞。
- 表现预算在高负载下降低普通装饰特效，始终保留 Boss 阶段、敌方预警、终结技命中和地形破坏提示。
- 对象池公开容量、复用、释放和活跃数量，便于后续性能监控。

## 可替换数据

- 敌人族群：`game/data/v2/enemy_families.json`
- 关卡路线、地形与出生点：`game/data/v2/stages.json`
- 路线模板：`game/data/v2/stage_templates.json`
- Boss 阶段与场地事件：`game/data/v2/boss_patterns.json`
- 地图绘制规则：`game/scripts/stage_surface_renderer.gd`

## 验收

```powershell
Godot_v4.4.1-stable_win64_console.exe --headless --path game -- --v30-test
```

V30 专项共 25 项；V29、V28、V26、V25、V20、V17 关键回归均为 0 failures。专项压力样本覆盖 300 个敌人、180 个弹道和 120 个短时特效预算，并验证关键预警在降级时保留。

视觉证据：`docs/v30-validation/01-dynamic-route-portals-and-arena.png`。

发布包：`builds/rift-guard-v30/RiftGuard-V30.exe`（203,226,464 bytes）
SHA256：`BEA6063E08E985CF55C8A3468C0CA3487A86F08D61F120E3171D836DBD9942E5`
