# V92 HUD 生命周期复核

复核日期：2026-10-04。范围限于真实控制器重开、HUD 瞬态状态和地形反馈清理。

主任务后续使用最终源码完成原生窗口回归：52 检查、0 失败，含本记录新增的 6 项和 7 次截图。日志位于缓存根目录 `hud-native-final.log`；下文保留本次独立无头复核的范围与证据。

## 问题与修复结果

修复前，`Main.restart(true)` 调用 `restart_current_stage()` 后保持同一关卡、布局与种子。HUD 的运行标识未改变，自动跨关清理不会触发。原探针确认：新局敌人数已经为 0，旧契约通知和旧 Boss 危险条仍显示，危险计时仍为 8 秒。

当前 `main.gd` 在模拟器重开后显式调用 `battle.reset_transients()` 与 `hud.reset_transients()`；战场重置同时清空 `functional_terrain_art.bursts`。

修复后探针通过 **9/9** 项断言：

- 先确认旧局确有活动通知、Boss 危险条和泉台反馈，避免空状态检查。
- 暂停期间危险计时不推进。
- 真实重开保持同一关卡与种子，同时清空活动及排队通知、危险计时和面板、泉台反馈。
- 新局恢复运行后，旧反馈不会重新出现。
- 连续 20 次清理，HUD 节点数保持 294，弹出动画和通知队列没有积累。

本次复核发现的重开遗漏已消除，未发现本范围内仍需阻断交付的问题。

## 正式回归

`game/tests/qa_v92_hud.gd` 新增 `exercise_restart_lifecycle()`，通过真实 `game.restart(true)` 验证相同关卡和种子的路径。新增 **6** 项必要断言，涵盖反馈前置条件、关卡身份不变、三类瞬态清理及新局启动后不复现。

完整无头 HUD 回归由 **39** 项增至 **45** 项，结果为：

```text
V92 HUD QA: 45 checks; 0 failures
```

最终两份日志未出现脚本错误、资源泄漏或退出警告。本次没有复跑原生截图录制，因此原有 46 项原生记录不能视为新增 6 项的原生验收。

## 证据与复跑

临时文件均保存在任务缓存目录：

- 修复前复现：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/review-hud/lifecycle.log`
- 修复后断言探针：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/review-hud/lifecycle_probe.gd`
- 修复后探针日志：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/review-hud/lifecycle-fixed.log`
- 完整 HUD 回归日志：`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/review-hud/hud-final-45.log`

在项目根目录运行正式回归：

```powershell
& 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe' --headless --path game --script res://tests/qa_v92_hud.gd
```

探针复跑：

```powershell
& 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe' --headless --path game --script 'C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/review-hud/lifecycle_probe.gd'
```
