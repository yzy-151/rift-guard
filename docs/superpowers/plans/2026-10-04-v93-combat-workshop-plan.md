# V93 Implementation Plan

**Goal:** 完成用户九项数值/美术/工坊修改，并削弱全角色初始普攻范围。

**Architecture:** 保留现有 CombatSimulation/BattleView 管线，将普攻规则独立为模块；技能投递与工坊使用同一模拟。各文件限定所有者，集成与发布由 root 负责。

**Tech Stack:** Godot 4.6、GDScript、JSON、原生 MovieWriter、FFmpeg。

- [x] 数值与路线：combat_simulation.gd、character 数据、卡牌数据、敌人目录、enemy_melee_spacing、stage_runtime 与 terrain_encounters。新增 basic_attack_rules.gd，接替 HeroSignature 的 launch_attack/attack_hit/tick_attack，避免与技能作者争写。初始单体/短射程、卡牌逐级多目标、重甲慢速、普通关卡按路阻挡、新障碍路线净空。新增 qa_v93_balance_routes.gd 先运行红例，再实现并验证旧行为中仍需保留的部分。正式数值与结果写 docs/v93-validation/balance.md。
- [x] 独立工坊：新增 workshop/session 与界面文件、settings_panel/main 接线。操作包含地图/角色/敌人放置、选择/删除、Q/E、卡牌、清场、无敌与能量、自动攻击/敌人行动、暂停/逐帧/倍率、退出恢复。使用真实 main/输入实现 QA 并检查存档和旧战斗完全隔离。验证副产物放 cache/workshop。
- [x] 原作技能：hero_signature_skills.gd 与 hero_signature_vfx.gd（禁止改 combat_simulation/character JSON）；先核对官方参考，将格温改为可读飞针序列，检查所有可玩角色的身份表现。前三个旧普攻静态函数改为调用新 BasicAttackRules（与数值作者协调），保持兼容。测试针飞行真实命中与分段、技能取消/归属，记录参考与实际改编。需要角色数据变更时交数值作者合入。
- [x] 共通表现：root 修改 battle_view/comic_combat_vfx/functional_terrain_art 与必要独立 burst helper。移除截图中的旧轮辐爆炸；直线电极；新出场裂光；route preview 如需 UI 接线与数值作者约定。实机录制检查短时相位、低特效、密集事件和无多重叠画。
- [x] 交叉审查：各作者完成后只读审查不同模块；root 检查九条需求与真实视觉，修复阻断问题。同步玩法说明、原有卡名/素材保留与正式测试范围。
- [x] 发布：版本93、build_v93、正式说明与画廊，导出 releases/V93，原生 EXE 验收含工坊入口/操作；媒体解码/包哈希/文档链接，最后清理仅自动 .import 噪音。旧包保留；不提交、不推送。

回归使用已安装 Godot_v4.6-stable_win64_console.exe --headless --path game --script res://tests/qa_v93_*.gd，控制器类测试传 -- --qa-output=C:/Users/yzy/Desktop/codex/rift-guard/v93-2026-10-04/<case>。视觉原生录制同步推进模拟、BattleView、SheetEffects 与 HUD，不以静态截图替代动作验收。
