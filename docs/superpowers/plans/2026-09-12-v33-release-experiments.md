# V33 续做与发布实验计划

> **For agentic workers:** Use executing-plans / subagent-driven-development for the bounded review and verification tasks below; preserve the existing V33 implementation.

**Goal:** 完成未提交的 V33 远征检查点，复验后提交并推送独立 v33 分支。

**Architecture:** 继续现有双槽、SHA256、版本与字段校验方案；在实际进程重启中检查续玩，修复审查发现的生命周期缺口。

**Tech Stack:** Godot 4.4.1 / GDScript / Python / Windows x64 / GitHub。

## 2026-09-12 基线

- GitHub 分支查询：最新版本 v32 = 013f9e8966bdad042ef94a5b2c50cc12729d5fdf；没有 v33，无开放 issue。
- 本地 v33 基于 V32，检查点与 QA 已写但未提交；上次留下的测试记录只作参考。
- 用户指定原目录续做；沿用独立 v33 分支，保留无关未跟踪素材。
- Windows 默认沙箱因 apply deny-read ACLs 初始化失败；已通过受审查的执行权限恢复工具运行。

## 实验与收尾

- [x] 先审查 V33 需求覆盖：编队、路线、待选事件、关前剧情、通关结算、失败重开、无尽隔离、幸运持久化、损坏回退。
- [x] 对审查发现的实际缺口先添加复现，再修复并运行 V33 专项；不扩展到 V34。
- [x] 新增跨进程验收：一个进程写入隔离的远征检查点后退出，第二个进程读取同一路径并通过真实继续入口恢复；检查队伍、资源、待选事件和奖励去重。
- [x] 运行 `python tools/validate_v33.py`，期望全部专项与八组底层回归成功，日志没有 ERROR。
- [x] 运行 `python tools/validate_v33_visual.py`，人工查看 1280×720 / 1600×900 / 1920×1080 的继续菜单、事件结算和下一关编队截图，确认可读性与入口可用。
- [x] 使用 Godot `--headless --path game --export-release "Windows Desktop"` 构建，运行 `python tools/validate_v33_release.py`，并纳入跨进程发布包检查。
- [x] 保存独立代码审查结论、最新测试结果与 SHA256，更新 README、V33 发布说明和原计划勾选。
- [x] `git diff --check` 后仅暂存 V33 文件，提交并 `git push -u origin v33`，读取远端确认 SHA 一致。

## 判定标准

每个自动化进程必须退出码为 0、含预期完成摘要、没有脚本错误；跨进程检查必须使用同一隔离目录且两个不同 PID，不接触玩家存档；Windows 发布包从自身目录启动。
