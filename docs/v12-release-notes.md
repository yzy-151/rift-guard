# Rift Guard V12

## 本次完成

- 新增启动模式菜单，可进入“裂隙守望”剧情模式或直接进入“四屏无尽生存”。
- 关卡路线改为战前动态预告：路线箭头在敌人出现前播放，开战后自动消失。
- 地面常驻深色道路、转向箭头与分岔结构，玩家无需预告也能从地形判断行进方向。
- 敌方裂隙门绑定各条路线入口，支持上方、右侧和下方等不同刷新位置，并带旋转、脉冲与火花动画。
- 第一波增加四秒准备时间，确保路线与入口预告完整播放。
- 通关对话结束后回到战场，右侧门打开，新角色走出；玩家右键操纵旅行者靠近后才进入下一关编队。
- 修复新解锁角色按钮不可点击的问题；角色在编队界面打开前写入解锁存档，并验证真实按钮点击。
- 射程圈直接使用战斗模拟中的实际 `attack_range` 投影，不再使用缩小后的近似范围。
- Excel 配置随发布包内置；外部 `content/game_config.xlsx` 不存在时自动回退到 `res://data/game_config.xlsx`。
- 移除“未找到 xlsx”常驻提示，仅在 Excel 实际解析失败时显示错误。

## 验收

- V12：14/14
- V11：14/14
- V10：3/3
- V8：6/6
- Phase1：68/68
- Godot 4.4.1 全脚本解析通过。

## 可替换入口

- Excel 内容源：`content/game_config.xlsx`
- 发布包 Excel 回退：`game/data/game_config.xlsx`
- 关卡、路线、波次：`game/data/v2/stages.json`
- 模式主菜单：`game/scripts/mode_select_panel.gd`
- 地图、路线、传送门、射程和战场招募：`game/scripts/battle_view.gd`
- 关卡切换与流程：`game/scripts/main.gd`
- 编队选择：`game/scripts/squad_panel.gd`
