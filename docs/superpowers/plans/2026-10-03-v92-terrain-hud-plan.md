# V92 implementation plan

目标：增加具有实际战术作用的地形，并重整生动、清晰的V86风格战斗HUD。

- [x] 功能模拟：新 functional_terrain.gd 与 terrain_encounters.gd；combat_simulation.gd 小范围接入；功能时序与影响回归。明确共享字段及事件交接给绘制。
- [x] HUD：battle_hud.gd、必要的独立Control动效/绘制辅助、ui_layout_profile.tres 的战斗字段；保留所有原交互和图标；真实输入与拥挤状态验证。
- [x] 地形美术与反馈：root负责新 functional_terrain_art.gd、battle_environment_art.gd 接入；同数据判定边界、清晰物件形态、活动预警、近处说明；battle_view/main 最少接线。
- [x] 集成审查：八关/无尽地图展示、原模拟/近战/卡牌回归，普通/首领/无尽/暂停/密集强化/低特效实机。
- [x] 打包与实机证据：V92 Windows新包，原生EXE验收，机关与HUD动图/有声视频、文档；清理仅自动导入噪音，保留原资产与旧包。

分工按独立源文件执行，先确定数据契约再接显示；各自完成后交叉只读审查，根代理统一导出与核验。功能机制先观察针对性失败再实现；纯视觉调整用原生截图、动画和真实输入检查，不写只镜像绘制实现的测试。
