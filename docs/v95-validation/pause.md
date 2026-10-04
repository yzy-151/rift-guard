# V95 暂停页实机验证

暂停页改为角色海报：左侧原有立绘露出完整头脸及上身，右侧倾斜双语动作板由黄色 **RESUME / 继续战斗** 主导。PAUSE 使用 Impact 窄体大字，中文标题与按钮使用既有 TiejiliSC；正文与数值沿用游戏字体。颜色为炭黑 `#111014`、绯红 `#c52c49`、纸白 `#f2e9dc`、黄色 `#ffc848` 和次级灰 `#b7a5a7`。

底部三张成员资料保留原角色素材、生命、攻击、攻速、射程、护甲、移速、弹道及出战状态。生命条是独立 3 px 细条，生命 14 px、两行数值 12 px，避免默认 ProgressBar 最小高度覆盖文字。姓名底条与职业文字位于立绘上层。强化条保留原图标、名称、等级及完整提示；超过可见范围的所有强化通过横向滚动查看。未强化时有明确的下一步引导。

继续、设置、重开、图鉴、路线、主菜单连接原动作；原 Space / Esc、F10、R 保持可用。原路线开放条件和重开确认保持原流程。玩家暂停页移除了 PERF、丢弃计数和调试奖励入口。页面静态呈现，减少特效模式保持相同布局。

## 真实输入与缓存验证

测试入口：`game/scripts/qa_v95_pause.gd`（RefCounted，可用于正式包 QA）和 `game/tests/run_qa_v95_pause.gd`。所有键盘和鼠标动作通过真实 Viewport `push_input`，不直接调用按钮回调或发射 pressed 信号；仅场景/数值测试夹具直接准备。

| 环境 | 结果 | 报告 |
| --- | --- | --- |
| Headless | 64 / 64 | [报告](pause/headless-results.json) |
| Windows 原生 1280×720 | 72 / 72 | [报告](pause/1280-results.json) |
| Windows 原生 1920×1080 | 72 / 72 | [报告](pause/1920-results.json) |

覆盖真实暂停冻结、三名角色原素材/实时 HP 与属性、14 个原强化图标与名称等级、鼠标强化栏滚动、完整六动作 Tab 循环、Enter 和鼠标继续、设置/图鉴/路线往返、重开确认/取消及实际重开、返回主菜单。每次原生截图检查 Image 的实际像素尺寸。

空构筑与完整构筑各连续执行 240 次 HUD refresh，暂停内容更新版本和子节点数保持不变；单独修改攻击值只更新一次。强化节点按实际数量创建并复用，完整构筑为 98 个节点。未新增每帧创建子控件或动画，不改写主 HUD 的签名计算。

## 实机截图

两种尺寸均亲自打开检查，完整头脸、上身、姓名/职业、生命条与数值无重叠，动作板在屏幕安全边界内。所有图片由 Godot 原生渲染直接保存。

| 状态 | 1280×720 | 1920×1080 |
| --- | --- | --- |
| 空构筑 | [截图](pause/1280-01-pause-empty.png) | [截图](pause/1920-01-pause-empty.png) |
| 14 个强化 | [截图](pause/1280-02-pause-full.png) | [截图](pause/1920-02-pause-full.png) |
| 强化栏末端 | [截图](pause/1280-03-pause-full-tail.png) | [截图](pause/1920-03-pause-full-tail.png) |
| 减少特效 | [截图](pause/1280-04-pause-reduced.png) | [截图](pause/1920-04-pause-reduced.png) |

```powershell
& 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe' --path 'D:/FILEEEEEEEEEEE/同人游戏/rift-guard-astra/game' --script res://tests/run_qa_v95_pause.gd -- --qa-output=C:/Users/yzy/Desktop/codex/rift-guard/v95-2026-10-04/pause/native1920 --qa-size=1920x1080
```

此项修改限于 `battle_hud.gd`、新暂停 helper 和上述 QA。未扩展主菜单，未修改战斗/剧情逻辑、工坊、导出或既有版本交付。
