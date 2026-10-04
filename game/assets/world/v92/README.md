# V91 正式地面与环境素材

生成日期：2026-10-03。按任务约定放在 `world/v92` 目录；该目录名不表示将游戏发布版本改为 V92。本轮仅新增美术素材与本说明，不更改代码、音频或原有地图资产。

## 来源与用途

使用 Codex **内置 image_gen** 生成，未使用 CLI/API fallback、程序拼砖、Python 绘图或后期裁改代替作画。输出保持工具原生像素和通道格式；正式文件与生成图逐字节复制一致。完整提示词见下文。工具原始输出留存于 `C:/Users/yzy/.codex/generated_images/01a100c7-90c3-74b1-ad7e-35f16814030c/`，临时副本与图集初稿位于 `C:/Users/yzy/Desktop/codex/rift-guard/v91-2026-10-03/visual-redo/`。

视觉参考先人工查看 `reference-review/frame-11.png` 与 `reference-review/contact.png`，只提取暗色安静铺面、细小地面纹理衬托亮技能的要求；未将视频画面或霓虹 UI 像素复制到资源。风格采用任务要求的红黑哥特、干净平涂与墨线描边。背景没有人物、敌人、文字或 UI。素材为生成图，不宣称第三方图库 CC0。

## 文件与检查

| 文件 | 场景 | 原生尺寸/通道 | 原始输出 |
|---|---|---|---|
| `courtyard-crimson.png` | 血门夜庭 | 1672 × 941 RGB | `exec-c91cc9b9-5114-4cd0-b9ce-6f5df2bb0977.png` |
| `courtyard-frost.png` | 霜汐回廊 | 1672 × 941 RGB | `exec-c623cfeb-2877-4028-b8d5-73a94e89202e.png` |
| `courtyard-wind.png` | 风蚀钟庭 | 1672 × 941 RGB | `exec-74aa49b5-b1a5-4ab4-b391-8d97450884e1.png` |
| `courtyard-meadow.png` | 月下草庭 / 首关 | 1672 × 941 RGB | `exec-bf7fa3c8-e695-4641-a1da-3a9dec3275e8.png` |
| `terrain-atlas.png` | 2×2 真实地形图集 | 1254 × 1254 RGBA | `exec-0ce1a6db-2a93-4df2-8475-f8071d845d1e.png` |

四张地板为接近 16:9 的工具原生画幅（1672/941≈1.7768），没有为了凑精确比例再拉伸或裁图。请由渲染器按实际地图边界显示。

逐张查看结果：血门夜庭为炭灰深靛旧石与边缘暗红窗/烛光；霜汐回廊为蓝灰湿石与边缘冰封水道；风蚀钟庭为暖灰砂岩、边沿青铜与枯叶；首关草庭为灰绿短草、苔藓和细碎平铺石径。中央均为低对比连续铺面，没有建筑、家具、角色或巨大中央图案。细裂纹、霜花、小草和碎石属于地表纹理。可碰撞墙体、门和陷阱应由游戏根据真实地形另外绘制，不能把底图纹理当作新增碰撞。

## 透明图集裁切

`terrain-atlas.png` 的 alpha 范围为 0–255，52.65% 像素完全透明；不是黑底或棋盘背景。每格为 627×627。

| 格 | 物件 | 完整格 Rect2(x,y,width,height) | 可见内容紧边界（alpha≥16，含手绘边缘） |
|---|---|---|---|
| 左上 | 石砌方形矮墙/实心石块顶部 | `(0,0,627,627)` | `(74,82,504,502)` |
| 右上 | 正俯视铁门及端柱 | `(627,0,627,627)` | `(678,300,522,89)` |
| 左下 | 凹槽尖刺地砖 | `(0,627,627,627)` | `(85,690,482,488)` |
| 右下 | 浅水池 | `(627,627,627,627)` | `(716,690,456,481)` |

图集先生成四格，再用内置 image_gen 仅校正右上铁门：初稿错误地露出正面栏杆，最终只保留垂直俯视可见的细长门顶与端柱。保持透明背景及其余三格内容。实际碰撞尺寸仍以模拟定义为准；渲染时可使用紧边界去除透明留白，避免把整个627格当成实体尺寸。

## 完整提示词

### courtyard-crimson.png

```text
Use case: stylized-concept. Asset type: FINAL in-game 2D action defense ground background, not a concept painting. Make ONE complete full-bleed horizontal landscape PNG image, 16:9, ideally 2048x1152. Camera strictly orthographic straight overhead, parallel axes, uniform scale everywhere, absolutely no horizon or vanishing point. Art direction: polished hand-drawn cartoon game environment matching a red-and-black Helltaker-inspired gothic game: confident ink contours, controlled flat cel colors, subtle painted wear and material character. A dark quiet floor for small bright animated characters and spell effects to be placed on later. The center and the entire inside rectangle from x=8% to92%, y=8% to92% MUST be completely traversable flat ground, without furniture, rocks, trees, architecture, holes, props, characters or enemies. Architectural decoration and any raised structure confined to the outermost 8% perimeter only; do not let their silhouettes or long shadows invade the usable interior. Cover interior with SMALL closely sized hand-laid stone slabs, slightly irregular/staggered and weathered, quiet subtle grout: roughly 35 to50 small slabs across width, not 8 gigantic tiles. The floor is a cohesive finished illustration with small chips, stains and fine scratches; all ground details low contrast, same dark value family. A few extremely faint flush ground grooves are allowed, no giant icon tiles or central magic emblem, no checkerboard, no colored building blocks, no technical diagram. No procedural-tile look. No text, lettering, signage, watermark, UI, health bars, characters, creatures, pickups, spell effects or bright central focal point. No neon sci-fi styling. Central gameplay floor should occupy at least80% of visual attention as quietly detailed material. Entire floor remains legible, not pure black. Scene: BLOODGATE NIGHT COURT, the worn rooftop courtyard of an old gothic church at night. Palette predominantly charcoal and very deep muted indigo stone, subtle warm soot stains, occasional dull oxblood joints, nothing pink. Outer edge only: narrow cropped dark-red gothic window recesses and short parapet ends, thin aged dark copper drainage channels, a few tiny dim candles at far edges, muted moonlight grazing the edge stones. Warm candle flecks stay tiny; the vast floor is matte, quiet, beautifully observed old stone, naturally worn instead of a repeating pattern.
```

### courtyard-frost.png

```text
Use case: stylized-concept. Asset type: FINAL in-game 2D action defense ground background, not a concept painting. Make ONE complete full-bleed horizontal landscape PNG image, 16:9, ideally 2048x1152. Camera strictly orthographic straight overhead, parallel axes, uniform scale everywhere, absolutely no horizon or vanishing point. Art direction: polished hand-drawn cartoon game environment matching a red-and-black Helltaker-inspired gothic game: confident ink contours, controlled flat cel colors, subtle painted wear and material character. A dark quiet floor for small bright animated characters and spell effects to be placed on later. The center and the entire inside rectangle from x=8% to92%, y=8% to92% MUST be completely traversable flat ground, without furniture, rocks, trees, architecture, holes, props, characters or enemies. Architectural decoration and any raised structure confined to the outermost 8% perimeter only; do not let their silhouettes or long shadows invade the usable interior. Cover interior with SMALL closely sized hand-laid stone slabs, slightly irregular/staggered and weathered, quiet subtle grout: roughly 35 to50 small slabs across width, not 8 gigantic tiles. The floor is a cohesive finished illustration with small chips, stains and fine scratches; all ground details low contrast, same dark value family. A few extremely faint flush ground grooves are allowed, no giant icon tiles or central magic emblem, no checkerboard, no colored building blocks, no technical diagram. No procedural-tile look. No text, lettering, signage, watermark, UI, health bars, characters, creatures, pickups, spell effects or bright central focal point. No neon sci-fi styling. Central gameplay floor should occupy at least80% of visual attention as quietly detailed material. Entire floor remains legible, not pure black. Scene: FROSTTIDE GALLERY, a neglected open-air stone cloister chilled by a cold tide. Palette slate blue-grey, very dark cool charcoal grout, restrained desaturated cyan ONLY at the periphery. Quiet slightly damp small paving stones, hairline cracks, occasional faint frost flowers and shallow thin ice films flush with the ground, never large ice crystal props or floor holes. Outermost8% only: cropped frozen arch-wall bases and narrow water gutters, faint icy edge accents, no large dark foreground shape. Beautiful flat painted stone material, subdued ice not a glossy photorealistic render.
```

### courtyard-wind.png

```text
Use case: stylized-concept. Asset type: FINAL in-game 2D action defense ground background, not a concept painting. Make ONE complete full-bleed horizontal landscape PNG image, 16:9, ideally 2048x1152. Camera strictly orthographic straight overhead, parallel axes, uniform scale everywhere, absolutely no horizon or vanishing point. Art direction: polished hand-drawn cartoon game environment matching a red-and-black Helltaker-inspired gothic game: confident ink contours, controlled flat cel colors, subtle painted wear and material character. A dark quiet floor for small bright animated characters and spell effects to be placed on later. The center and the entire inside rectangle from x=8% to92%, y=8% to92% MUST be completely traversable flat ground, without furniture, rocks, trees, architecture, holes, props, characters or enemies. Architectural decoration and any raised structure confined to the outermost 8% perimeter only; do not let their silhouettes or long shadows invade the usable interior. Cover interior with SMALL closely sized hand-laid stone slabs, slightly irregular/staggered and weathered, quiet subtle grout: roughly 35 to50 small slabs across width, not 8 gigantic tiles. The floor is a cohesive finished illustration with small chips, stains and fine scratches; all ground details low contrast, same dark value family. A few extremely faint flush ground grooves are allowed, no giant icon tiles or central magic emblem, no checkerboard, no colored building blocks, no technical diagram. No procedural-tile look. No text, lettering, signage, watermark, UI, health bars, characters, creatures, pickups, spell effects or bright central focal point. No neon sci-fi styling. Central gameplay floor should occupy at least80% of visual attention as quietly detailed material. Entire floor remains legible, not pure black. Scene: WINDWORN BELL COURT, an ancient monastery bell terrace. Palette dark warm grey sandstone with smoky umber variation and a very little low-saturation aged bronze. Quiet small worn sandstone paving, extremely subtle rubbed sediment and a few tiny flat dry leaves only near margins, absolutely no large patterned floor medallion. Outermost8% only: cropped broken monastery railings, a small cropped bell-tower foundation lip and narrow dull bronze trim; the bell tower itself must be outside image, no tall central architecture. Light is gentle and dim, the central80% remains dark, open, calm, with high-quality hand-drawn stone textures.
```

### courtyard-meadow.png

```text
Use case: stylized-concept. Asset type: FINAL in-game orthographic 2D ground/background texture, not concept art. Output a single full-bleed landscape PNG, 16:9 ideally2048x1152. Camera is straight down from directly above, uniform scale, parallel edges, no horizon, no perspective vanishing point and no isometric view. Scene: ABANDONED MOONLIT MONASTERY MEADOW COURTYARD at dusk. This is the opening grassy courtyard of a fantasy land, welcoming enough to explore, not another gloomy dungeon. Art is premium clean hand-drawn cartoon game environment, confident dark ink outlines and flat cel color shapes compatible with a red-and-black Helltaker-styled game; restrained painted material detail, no photorealism. Predominant floor material: low-contrast muted grey-green short grass, weathered soft warm-grey tiny flat broken stone paving and finely worn flat gravel paths, occasional patches of worn moss and bare soil. The paths are ground texture with no raised stone borders, not bright ribbons or bold symbols. Subdued evening blue-grey ambient light, very faint soft moonlighting, no harsh spotlit center. The huge interior rectangle from x8%to92% and y8%to92% must be quiet fully traversable flat ground, no fixed objects, no furniture, no trees, no rocks, no holes, no raised paving, no pillars, no props. Quiet central80% ground should provide a calm material backdrop for small bright characters and spectacular effects added later. Stone pieces remain tiny about35to50 paving-piece widths across the screen, not massive tiles. At the far outermost8% perimeter ONLY, cropped low old monastery stone parapet edges, sparse tiny grass tufts and subdued ivy, no tall buildings. No central decorative disc, no huge magical emblem, no checkerboard, no geometric technical diagram, no colored building blocks. No UI, lettering, signs, logos, watermarks, characters, creatures, pickups or spell effects. Complete finished usable game art with beautiful low contrast material variation.
```

### terrain-atlas.png

```text
Use case: stylized-concept. Asset type: production game environment prop sprite atlas with TRUE TRANSPARENT background, NOT a screenshot. Output square2048x2048 PNG. Four independent sprites arranged in a strict2x2 atlas, one completely contained in each quadrant, equal quadrant size and generous transparent padding on all sides. Do NOT draw the quadrant lines, frame, ground background, labels or text. STRICTLY STRAIGHT OVERHEAD ORTHOGRAPHIC view looking vertically down, no perspective, no isometric angle, no vanishing point. Hand-drawn game art matching Helltaker-inspired gothic cartoon environment: clean confident dark ink outline, flat cel color, restrained weathering, dark desaturated charcoal stone and dull copper. Sprite1 UPPER LEFT: a square filled solid low stone BLOCK, a collision obstacle viewed from directly above, showing the dark worn flat top of tightly fitted small masonry blocks with a narrow beveled rim. Sprite2 UPPER RIGHT: a short straight iron-bar GATE segment with two small stone end posts, seen directly overhead, so the gate thickness is visible as a narrow horizontal band; aged grey-black iron and dull copper hinges. Sprite3 LOWER LEFT: a square inset SPIKED FLOOR TRAP tile, viewed straight down, small steel spike tips nested in individual dark recessed slots, quiet stone frame, restrained worn-metal highlights, no neon and no magical symbols. Sprite4 LOWER RIGHT: a small square SHALLOW WATER BASIN inset tile, viewed straight down, flat dark blue-grey water, faint two or three drawn ripples, narrow weathered dark stone coping, no bright glows. Each sprite is a different independently crop-able asset at equal visual scale, occupies about70% of its quadrant with ample transparent margin. No cast shadows leaving the sprite region, no external background, no fake checkerboard transparency, no floor outside the object, no glyphs, no floating objects, no plants, no characters. Four useful actual terrain objects, NOT icons or a technical diagram. Transparent background MUST be real alpha.
```

### 图集定向修正

初稿：`exec-21751723-2b25-484e-a36a-e6b72915d7f2.png`。使用 `referenced_image_paths` 指向已查看初稿，`transparent_background=true`。

```text
Use case: precise-object-edit. Edit this four-sprite transparent game terrain atlas. Change ONLY the UPPER RIGHT sprite, the iron gate: it currently appears as a front elevation, and must instead become a TRUE VERTICAL STRAIGHT-DOWN TOP VIEW. Show the TOP EDGES only of a horizontal closed gate: a long thin narrow dark-iron top rail with a few small attached dark cross-sections, aged dull copper hinge housings, flanked by two small SQUARE top-facing stone posts. The entire central gate band must be very thin top-to-bottom (about one fifth the width of a stone end post). No visible tall vertical bars dangling below the rail, no facade, no elevation, no isometric perspective. Imagine the camera hovering directly vertically above the gate and seeing only its tiny thickness. Keep this sprite centered within its UPPER RIGHT quadrant, independently crop-able with transparent margins. Keep all other three sprites EXACTLY unchanged in their positions, scale, rendering and outlines. Preserve original square canvas and actual transparent alpha background. No new objects, no background fill, no labels, no frame.
```

