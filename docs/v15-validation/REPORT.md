# V15 验收报告

master，V15 修复了发布前未覆盖真实鼠标路径的问题，并加入数据驱动的双选项分支剧情与隐藏角色解锁。

## 功能结果

- master，模式菜单、剧情关卡卡片和编队确认均增加根级左键命中保险链，标准 Godot Button 键盘和鼠标行为继续保留。
- master，普通模式路径为“裂隙守望 → 第一关 → 确认编队 → 开场对话 → 战斗”，发布包内已完整走通。
- master，无尽模式从主菜单直接进入 stage_endless，发布包内已完整走通。
- master，对话行可在 game/data/story.json 定义两个 choices，每个选项可配置独立回应、结果、效果和隐藏角色解锁。
- master，Excel 对话覆盖时会保留内置 JSON 的 choice 元数据，避免可编辑对白覆盖分支结构。
- master，选择“稳住水晶”获得本关 8% 幸运值，选择“追查求救信号”永久解锁隐藏角色白露。
- master，白露已从第三关普通通关解锁表移除，因此新存档只能通过隐藏选项发现。

## 验收证据

- master，[双选项对话](01-dialogue-choice.png) 展示两条 Helltaker 式横向回应按钮。
- master，[普通模式战场](02-campaign-running.png) 证明关卡与编队确认后进入实际战斗。
- master，[无尽模式战场](03-endless-running.png) 证明无尽模式直接进入四屏生存地图。

## 自动验证

- master，V15 真实窗口测试为 12 checks、0 failures。
- master，最终导出的 RiftGuard-V15.exe 内部测试同样为 12 checks、0 failures，进程退出码为 0。
- master，现行发布矩阵覆盖剧情、Excel、数据库、卡池、奖励、元素技能、Boss、关卡运行、三关平衡、图鉴及 V13/V14 兼容测试，共 20 组全部通过。
- master，旧版 M4 `test_combat.gd` 仍保留为历史样例，但其直线路径、旧漏怪坐标与旧伤害断言已被 V6/V7 和关卡平衡测试取代，不作为 V15 发布门禁。
- master，三关强构筑模拟结果分别为 243、292、436 击杀，并全部通关。

## 发布包

- master，文件为 builds/rift-guard-v15/RiftGuard-V15.exe。
- master，文件大小为 174,458,768 字节。
- master，SHA256 为 ED61B0C0148C7EED36F576620F4FE27455D8B957C5AC7674EDD1A726569F48A4。
