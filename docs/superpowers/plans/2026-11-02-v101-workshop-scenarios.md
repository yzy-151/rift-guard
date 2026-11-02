# V101 工坊场景存取 Implementation Plan

> For agentic workers: use subagent-driven-development for implementation and independent review; preserve the original dirty V88 checkout.

**Goal:** 工坊支持三个持久化实验槽位，跨进程复现地图、摆放、构筑和开关。

**Architecture:** 配置只存稳定目录 ID、坐标和有序卡牌操作；完整校验后构建新 WorkshopSession，成功才替换当前场景。独立存储路径不连接战役检查点、图鉴或设置存档。

**Tech Stack:** Godot 4.6 / GDScript / Python / Windows x64.

## 实际基线

- 2026-11-02 实时确认远端 V100 分支和标签为 `18082a8151a66fa0df21f3dd1d8e51dcb04b5ccc`，最新 Release 为 V100。
- V33 与 V34 功能已在历史提交中完成；不重做检查点、共鸣和地图导航。
- 原工作区 HEAD 为 V88，存在大量本地变更，全部保留；独立 `v101-workshop-scenarios` 从 V100 出发。
- V100 工坊支持摆放、技能、卡牌、倍率、逐帧，但退出后不能复用实验配置。

## 实施与判定

- [x] 基线：Godot 4.6 导入并执行 V95 simulation；记录导入/测试输出。
- [x] `workshop_scenarios.gd`：schema 版本、三个槽、严格 ID/坐标/类型/数量校验、临时写入后替换、错误返回；载入失败不修改旧 Session。
- [x] `workshop_scenario_bar.gd` 与工坊接线：摘要、保存/载入、F5/F9、覆盖确认、载入确认；载入同步地图/倍率/开关、取消瞄准、清空旧特效并暂停。
- [x] 专项：真实卡牌重放、隐藏角色构筑、槽隔离、损坏与未知版本、写入失败、跨进程存取、战役存档隔离。
- [x] 原生 UI：鼠标入口和确认/取消、弹窗输入隔离、1280×720 与 1920×1080 截图目视检查。
- [x] 回归：V93 工坊、V94 工具栏、V95 simulation/pause/dialogue/explosion、V94 endflow、classic-release、UI Lab。
- [x] Windows：正式模板与 PCK 构建；从发布目录以自身 PCK 启动，运行 V101 与既有发布专项，普通入口启动与截图，保存 SHA256。
- [x] 独立需求审查后代码质量审查；修复阻断问题，更新发布说明、README 和验收记录；显式暂存、提交、推送并比对远端 SHA。

## 语义约束

保存的是实验配置，不是战斗快照；载入满血、清除冷却和瞬态特效、时间归零并暂停。按每张卡当时的完整名册重放，保留隐藏角色，避免共享机制给后来角色追加收益。存档不跨不兼容 schema 静默迁移。无有效配置时拒绝并保留当前场景；若最新代损坏而旧代完整，槽摘要、恢复备份按钮、确认对话框和成功消息均明确告知恢复旧代，用户确认后才替换。

## 审查驱动修订

- Windows 的 Godot `rename_absolute` 在目标已存在时会先删目标；改为不可变代文件提交并保留上次完整代，测试锁住真实临时源导致 OS 移动失败仍可读旧槽。
- 先放全部角色再重放共享卡会给后加入角色错误加成；增加每卡名册并按历史顺序创建/部署角色，实测共享遗物、隐藏角色与环绕物构筑一致。
- 场景条高度缩减至 70，并使用 UI 布局 profile 的 `battle_workshop_scenario_bar_rect`；保留原工坊第一排可点击空间。

## 执行命令

## 2026-11-03 续做实验

- 实时 fetch 确认 GitHub 最新仍为 V100 / `18082a8`；V101 位于既有独立工作区，功能和上一轮验收尚未提交，不开启 V102。
- 首先修复发布证据绑定：打包脚本原先从旧 `logic/` 复制报告，且未验证测试后源码或 EXE/PCK 是否变化；改为绑定当前游戏源码/配置与实际二进制 SHA256，并从本次 source/scenarios 读取报告。
- 重新执行完整源码与发布包验收，不用旧结果代替；失败时保留日志并修复后复测。
- 原生截图审查两种分辨率；从新 ZIP 独立解压目录启动，检查主菜单、设置、工坊、保存/载入，关闭后检查退出和日志。
- 保留旧包为历史证据，使用本次独立构建目录；只暂存 V101 功能、脚本和精简证据，提交推送既有独立分支并核对远端 SHA。

## 执行命令（续）

`Godot_v4.6-stable_win64_console.exe --headless --path game --script res://tests/qa_v101_scenarios.gd -- --qa-output=<isolated-directory>`

`python tools/validate_v101.py --engine <Godot4.6> --phase source`

`pwsh -File tools/build_v101.ps1 -GodotExe <Godot4.6> -ExportTemplate <windows_release_x86_64.exe> -OutputDirectory releases/V101-20261103`

`python tools/validate_v101.py --release releases/V101-20261103/RiftGuard-V101.exe --phase release`

`python tools/package_v101.py --package releases/V101-20261103`
