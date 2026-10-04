# V92 最终音频与旧模拟回归结果

日期：2026-10-04（Asia/Shanghai）。使用 Windows Godot 4.6 stable 官方 console 版，以 `--headless` 运行；未导入编辑器、未导出、未修改游戏源码。

## 本次重新运行

**四套指定回归合计 638 项检查，0 失败，全部退出码 0。** 四份独立日志均未出现 `SCRIPT ERROR`、`ERROR`、`WARNING` 或失败行。

| 测试脚本 | 检查数 | 失败数 | 退出码 | 缓存日志文件 |
| --- | ---: | ---: | ---: | --- |
| `game/tests/qa_v91_audio.gd` | 333 | 0 | 0 | `qa_v91_audio.log` |
| `game/tests/qa_v91_audio_integration.gd` | 17 | 0 | 0 | `qa_v91_audio_integration.log` |
| `game/tests/qa_v91_melee_spacing.gd` | 42 | 0 | 0 | `qa_v91_melee_spacing.log` |
| `game/tests/qa_classic_combat_regressions.gd` | 246 | 0 | 0 | `qa_classic_combat_regressions.log` |

上述四份日志位于：

`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/final-regressions/`

音频集成测试通过 `--qa-output` 将控制器测试存档隔离在：

`C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/audio-integration/`

测试覆盖音频资源和身份映射、声部调度、静音与场景退出清理、重新开始和进入无尽模式时的音频重置，以及旧模拟中的近战站位、远程弹体、冻结、无尽目标和既有战斗规则。具体断言以各测试源码为准。

## 既有最终日志核对

以下项目只读取已经生成的日志，未重复运行：

| 模块 | 已有结果 | 证据 |
| --- | --- | --- |
| V92 功能地形 | 150 checks，0 failures；无错误或告警行 | `terrain/green-3.log` |
| V91 模拟 | 294 checks，0 failures；无错误或告警行 | `terrain/v91-simulation-final.log` |
| V92 HUD | 39 checks，0 failures；该最终 verbose 日志无错误或告警行 | `review-hud/hud-verbose.log` |

这些路径均相对 `C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03/`。读取既有日志没有重新采集其进程退出码，不能等同于本次独立重跑。

较早的 `review-hud/hud-recheck.log` 虽为 39 checks、0 failures，但包含退出时 ObjectDB 和 3 个资源未释放告警；较新的 `hud-verbose.log` 已无这些行。另有独立 `review-hud/lifecycle.log` 记录重开后旧局提示残留，这是主任务的 HUD 生命周期核查证据，不应因本次四套回归通过而被视为自动关闭。

## 复现命令

后续复核：同关重开已加入 HUD 与地形反馈清理；生命周期 9/9、扩充后的 HUD 无头 45/45 和原生 52/52 均通过。见 [生命周期修复记录](hud-lifecycle-validation.md) 和 [最终汇总](README.md)。

PowerShell 中逐项运行以下脚本列表。日志和音频集成测试存档均留在固定缓存目录：

```powershell
$godotExe = 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe'
$gameRoot = 'D:/FILEEEEEEEEEEE/同人游戏/rift-guard-astra/game'
$qaRoot = 'C:/Users/yzy/Desktop/codex/rift-guard/v92-2026-10-03'
$testNames = @(
    'qa_v91_audio',
    'qa_v91_audio_integration',
    'qa_v91_melee_spacing',
    'qa_classic_combat_regressions'
)
foreach ($testName in $testNames) {
    $runArgs = @(
        '--headless',
        '--path', $gameRoot,
        '--script', ('res://tests/' + $testName + '.gd'),
        '--log-file', ($qaRoot + '/final-regressions/' + $testName + '.log')
    )
    if ($testName -eq 'qa_v91_audio_integration') {
        $runArgs += @('--', ('--qa-output=' + $qaRoot + '/audio-integration'))
    }
    & $godotExe @runArgs
}
```

## 验证范围

这是 headless 回归结果，不代替实机图像、音量平衡或扬声器听感验收。音频集成脚本关闭实际播放并验证调度、静音和生命周期；没有宣称听过每段音频。既有 terrain/HUD 日志只确认对应记录的检查计数，本次不扩展其测试范围。

