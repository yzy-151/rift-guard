# Rift Guard V50 发布说明

## 本次更新

- 角色卡牌姓名与描述改为从 `characters.json` 动态关联，替换角色后不再残留旧名。
- 战斗 HUD 从右侧竖栏改为底部横向指挥台，三名角色平铺，HP/能量条缩短，Q/E 与构筑信息集中排列。
- HUD 头像从 `asset_manifest.json` 读取角色真实素材，并保留缺图占位机制。
- 普通关卡投影与无尽战场可视区扩展为宽屏布局，桌面发布固定为 1920×1080。
- 无尽模式加入丁字路口、十字路口、双向回廊、墙体、高台、洼地与四座可破坏门。
- 角色和地面怪物不能穿墙；地面远程攻击及 Boss 地面攻击受墙体遮挡；飞行怪物可越墙。
- 可破坏门拥有 720 HP，普通战技强度约需多次命中，破坏后立即开放通路。
- 墙体与门使用独立透明 SVG 素材，可分别替换。

## 可替换位置

- 墙体：`game/assets/world/endless/wall_segment.svg`
- 门：`game/assets/world/endless/breakable_gate.svg`
- 地形位置与尺寸：`game/data/v2/stages.json`
- 战斗 HUD 布局：`game/data/ui_layout_profile.tres`
- 角色头像绑定：`game/data/v2/asset_manifest.json`

## 验证

- V50：128 项通过。
- V49：66 项通过。
- V48：18 项通过。
- V34：40 项通过。
- V33：85 项通过。
- V33 UI：30 项通过。
- UI 实验台：16 项通过。
- 实机截图尺寸：1920×1080。