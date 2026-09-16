# Endless terrain assets

无尽模式（`stage_endless`）的地形贴图。石墙与大门按矩形按整数网格拼接，尺寸来自 `data/v2/stages.json`。

## 石墙（type: blocked）

- `stone_wall_a.png` / `stone_wall_b.png` / `stone_wall_c.png`：三张石块，横墙按行并排、按序轮换。
  - 整块区域 `Rect2(11, 10, 78, 83)`，顶面区域 `Rect2(11, 10, 78, 48)`。
  - 横墙（宽 > 高）：整块并排铺满。
  - 竖墙（高 > 宽）：只裁顶面、块距收紧到 `WALL_STACK_TIGHTNESS = 0.82`，自顶向下绘制，靠下的块压住上一块的底缘。
- 渲染代码：`scripts/battle_view.gd` 的 `_draw_endless_wall` / `_draw_endless_wall_column` / `_stitch_cells`。

## 可破坏大门（type: door，无尽模式）

- `gate_chest_h.png`：横墙上的门（北/南门，160×70），双锁箱并排。
- `gate_crate_v.png`：竖墙上的门（东/西门，70×160），铁箱上下叠放。
- 渲染代码：`scripts/battle_view.gd` 的 `_draw_endless_gate`。
- 战役模式的门仍走纯色多边形绘制（`battle_view.gd` 里 `kind in ["shortcut", "door"]` 的非无尽分支）。

## 已退役的占位素材

- `wall_segment.svg`、`breakable_gate.svg`：v57 之前的占位图，现已不被引用，保留以备回退。

## V59 Helltaker 地板模块

- `helltaker/labFloor0001.png` 至 `labFloor0008.png`：100×100 方形模块，按世界坐标确定性拼接，始终等比例显示。
- `helltaker/bossFloor.png`：100×100 Boss 契约区域模块，中央以 3×3 方格拼接。
- `helltaker/boxExport*.png`、`labWall.png`、`wallTube.png`、`wallVent.png` 等作为后续可替换地图组件保留。
- 来源：`research/helltaker-reference/exported-primary/Assets/Texture2D`；运行时副本放在本目录，避免依赖 `research/`。
