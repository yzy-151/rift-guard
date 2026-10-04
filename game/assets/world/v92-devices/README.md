# V92 functional device atlas

- File: `functional-atlas.png`
- Generation tool: built-in `image_gen.imagegen`, with `transparent_background: true`.
- Created: 2026-10-03.
- Dimensions: 1254 × 1254 pixels; PNG, RGBA.
- Alpha: range 0–255; 1,220,011 fully transparent pixels out of 1,572,516 (77.58%). The center gutters contain only alpha 0–1. Very low alpha (1–15) speckles from the generator exist outside the visible silhouettes; the generated image is preserved unchanged.
- Final source: `C:/Users/yzy/.codex/generated_images/01a10271-9761-78a3-bed0-14df5074feea/exec-555cbaef-8293-482f-9100-fcf2b1a8b9ea.png`.
- SHA-256 (source and project copy match): `9C0BBD35C04DB4BFA8F2902B34DE6042166D7B3B934B1C3E972257F6239AAA8A`.
- Reference material inspected: existing `../v92/terrain-atlas.png` and `../v92/courtyard-crimson.png`.
- Validation: visual inspection of both ImageGen outputs; Pillow read-only analysis of RGBA dimensions, transparency, quadrant bounds and padded source regions. No programmatic image modification.

## Sprite regions

All rectangles use image pixels. Source rectangles are `[x, y, width, height]`. Visible bounds use alpha ≥ 16 and half-open `[left, top, right, bottom]`. Recommended source rectangles add 8 pixels around those visible bounds; they prevent the generator's nearly invisible distant speckles from influencing placement.

| Sprite | Equal quadrant source rectangle | Visible bounds (alpha ≥ 16) | Recommended padded source rectangle |
| --- | --- | --- | --- |
| relay | [0, 0, 627, 627] | [135, 171, 507, 529] | [127, 163, 388, 374] |
| spring | [627, 0, 627, 627] | [745, 173, 1117, 533] | [737, 165, 388, 376] |
| wind_lane | [0, 627, 627, 627] | [113, 808, 523, 1023] | [105, 800, 426, 231] |
| hazard_lane | [627, 627, 627, 627] | [734, 808, 1146, 1024] | [726, 800, 428, 232] |

The visual designs are a twin-copper-coil crystal relay, a heart-shaped still-water spring, an eastward-chevron wind vent, and a three-nozzle ember furnace. Runtime code supplies activation glow and other effects.

## Initial generation prompt

```text
Use case: stylized-concept.
Asset type: one production sprite atlas for a dark gothic top-down action game. Exactly four isolated props in a square 2-by-2 sheet, each centered within one equal quadrant. No visible grid or dividers.
Camera: absolutely orthographic TOP DOWN, exactly overhead looking straight down, no perspective, no isometric angle. These are low, squat, floor-mounted devices.
Style: bold crisp black ink outlines, flat cartoon color shapes, sharp exaggerated graphic silhouettes and absurd infernal mechanical gothic design, inspired by Helltaker and Panty & Stocking. Avoid shiny 3D icon rendering. Dark gray cracked stone and blackened iron body materials, subdued oxblood and aged copper accents. Low contrast bases; only tiny functional cores are brighter. Match a quiet charcoal gothic stone courtyard. Use simple readable large forms.
Layout: all pixels outside the four prop silhouettes must be genuinely transparent. Generous transparent outer margins and a transparent central cross-shaped gutter. Each prop occupies roughly 70 percent of the width of its own quadrant. Each is centered at the quadrant center; nothing crosses into another quadrant.
Upper left only: a low octagonal dark stone plinth supporting two short copper coil rings flanking one small pale lavender crystal, seen directly overhead; relay device.
Upper right only: a squat dark stone HEART-SHAPED shallow spring bowl, seen directly overhead, heart tip points downward, filled with still subdued turquoise water and one tiny simple reflection, thick stone rim.
Lower left only: one horizontally elongated rectangular blackened-iron vent grating, low stone rim, horizontal wind fins with three east-pointing carved chevrons pointing to the RIGHT, sparse muted teal inserts; wind lane.
Lower right only: one horizontally elongated rectangular furnace grate of blackened brass and iron, three round upward-facing nozzle openings arranged LEFT to RIGHT in a straight horizontal row, each with a tiny ember orange-red core; hazard lane.
Constraints: exactly four game props, one per quadrant. No characters. No scenery. No text, letters, numbers, labels, UI, border, watermark, grid lines, panel backgrounds, shadows outside silhouettes, smoke, flames, clouds, sparks or glow effects outside the props. No blazing lighting; runtime adds effects. Real alpha transparency, never a drawn checkerboard. The final image should be a crisp flat 2D raster asset, a single square sheet.
```

## Targeted layout edit prompt

The initial output was supplied as the sole reference image. This edit reduced the silhouettes to fit inside their equal quadrant cells. The selected output was copied without pixel modifications.

```text
Edit this existing game prop atlas. Preserve all four exact prop designs, materials, colors, crisp bold black outlines, overhead view, and their ordering. Change ONLY the layout and scale: put these four props into an exactly square 2 by 2 atlas, one object perfectly centered at each quadrant center. Scale each prop down so its WIDTH is exactly about 65 percent of its own quadrant width, never more than 70 percent. Keep original proportions. The upper row objects must fit fully within the UPPER HALF, and lower row within LOWER HALF. Centers must be (25% width,25% height), (75% width,25% height), (25% width,75% height), (75% width,75% height). Leave generous TRANSPARENT empty margins at every edge and a clear transparent central cross gutter at least 15 percent of image width. Objects must not touch the quarter boundaries. Make ALL pixels outside the four intended clean silhouettes completely alpha zero; no ghost pixels, no haze, no shadow, no flecks, no checkerboard, no background color. Preserve real transparent alpha. Do not add new elements or effects, do not redraw into perspective, no labels or text. One final square PNG sprite sheet.
```

