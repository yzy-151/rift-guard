# V92 功能地形表现验证

验证日期：2026-10-04（Asia/Shanghai）。环境：Windows，Godot 4.6 stable 官方 console 版，headless 原生 GDScript。

本次复核通过 **13 项检查，0 项失败，进程退出码 0**。覆盖此前四项表现层问题的修复，并只读检查跨关、暂停和资源累积相关接线。此次复核仅新增本说明；没有编辑游戏源码。

## 四项修复复核

| 检查 | 输入与修复前复现 | 修复后实际结果 |
| --- | --- | --- |
| 无尽继电器作用区域剔除 | 本体 `Rect2(930,555,64,64)`，视窗 `Rect2(1200,550,1244,548)`。本体不与扩大 80px 的视窗相交，电击作用区域仍与视窗相交；原实现产生 0 次矩形绘制。 | 以本体和 `effect_area` 合并后的区域剔除，产生 5 次矩形绘制；屏内作用区域不再随屏外本体被跳过。 |
| 状态提示进度 | 火道预警 `phase_progress=0.5`，继电器冷却 `phase_progress=0.5, charge=1`；原提示填充宽度分别为 0px 和 242px。 | 两者填充宽度均为 121px，即 242px 总宽的一半。 |
| 泉台治疗音去重 | 泉台为一名角色恢复 14HP，生成普通 `heal` 和 `terrain_react/pulse` 两个事件；原音频导演同时安排两路相同 `heal`。 | 音频导演 `played=1`、`active_sfx.size()=1`。保留泉台脉冲音，带 `terrain_id` 的普通治疗事件不再另播。 |
| 高密度风道事件挤出泉台反馈 | 先接收一次泉台反馈，再接收 32 个风道脉冲；原队列留下 32 个不绘制的风道事件，泉台反馈被逐出。 | 队列仍只有 1 个泉台反馈；推进 0.53 秒后正常过期清空。 |

这些探针调用实际的 `EndlessStageArt.draw_terrain`、`FunctionalTerrainArt.draw_hint/accept/advance` 和 `BattleAudioDirector.handle_events`。绘制使用记录调用的轻量视图对象，并开启低特效模式。音频设置 `playback_enabled=false`，验证事件到声部的调度和去重；此项不等同于扬声器听感验收。

## 跨关、暂停与资源检查

| 检查 | 实际结果 |
| --- | --- |
| 正式模拟器加载第五关 | 恰好创建 4 个功能地形。 |
| 从第五关切到第二关 | 修改旧机关时钟、泉台储量和角色风道反馈后调用真实 `CombatSimulation.reset_stage`；第二关恰好 2 个功能地形，时钟恢复 0、泉台储量恢复 80，角色不保留旧关风道反馈字典。 |
| 暂停期间推进 | `state="paused"` 时分别调用功能地形 tick 和完整模拟器 tick 各 60 秒；地形字典与推进前快照完全一致。 |
| 无人使用时的泉台恢复 | 空储量以 0.25 秒步长运行 100 秒，最终储量为容量上限 80。 |
| 持续治疗的资源边界 | 以 0.25 秒步长运行 120 秒；每步检查泉台储量始终处于 [0,80]，角色生命与能量均不超过各自上限。 |
| 风道反馈存储 | 同一角色触发同一风道 1000 次，角色反馈字典始终只有 1 个键；风道不持有累积死亡单位的 `feedback_until` 注册表。 |

源码只读检查确认：`_load_terrain` 先清空旧地形再构建本关实例；`reset_stage` 重建角色并清空事件；功能地形 tick 只在 `running` 状态推进；泉台治疗和恢复均受储量与容量约束；风道反馈时间戳归属角色实例。

在本次范围内没有发现需要阻断源码冻结的跨关、暂停或资源累积问题。这里没有宣称完成所有关卡组合或长时间性能验收；实机录制与画面遮挡检查由主任务另外记录。

## 可复现证据

临时探针和日志按工作区规则保存在固定缓存目录：

- 原问题探针：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional.gd`
- 原问题日志：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional.log`
- 修复后探针：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional-fixed.gd`
- 修复后日志：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional-fixed.log`

修复后探针沿用原四个复现输入，将预期改为修复后的行为，并补充生命周期与资源边界检查。运行命令：

```powershell
& 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe' --headless --path 'D:/FILEEEEEEEEEEE/同人游戏/rift-guard-astra/game' --script 'C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional-fixed.gd' --log-file 'C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/props/review-functional-fixed.log'
```

日志末行：

```text
RESULT checks=13 failures=0
```

