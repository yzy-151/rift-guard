# Helltaker home and puzzle source assets

The 83 original files are copied byte-for-byte from the existing local original-game export at `research/helltaker-reference/exported-primary/Assets`. The original package is `research/helltaker-reference/helltaker-official-windows.zip`. The manifest lists every original path and SHA-256. No runtime texture has been generated, resized, recolored, or recompressed.

Thirteen import-ready audio copies repair the AssetRipper output's zero RIFF length and zero data chunk length. Only those two unsigned length fields change. All PCM audio bytes remain identical to the original samples. `manifest.audio` references these *_ready.wav files, while `source_files` records the untouched originals.

The original home and Chapter 1 / 2 / 3 maps use complete hand-drawn background canvases; their walls, rocks, floor joins and furniture are baked into those images. They should be drawn as complete images, not reassembled from laboratory tiles.

The four map backgrounds have a 1920 x 1080 canvas at 100 pixels per original grid unit. Their original world center and orthographic camera center are [3, 3], with camera orthographic size 5.4. Map coordinates convert by source_pixel = [960 + 100 * (world_x - 3), 540 - 100 * (world_y - 3)]. `Home07B.png` is a separate transparent foreground/shadow layer, centered on the same original world location.

Pivot positions in the manifest are top-left PNG pixel coordinates for the complete PNG, retaining its original transparent margins. All 100 x 220 skeleton, key and spike frames use [50, 110], not the image bottom; stone frames use [50, 70]. Original Unity normalized pivots are relative to trimmed sprite Rect and must first be converted into the complete source texture canvas.

`door_closed` uses a region of the original wooden entrance in Home07; `door_open` uses the original portal loop, since the original indoor door has no independent open sprite. Do not draw the closed door again over the hub background unless rendering a separate interactive overlay.

Supporting QA files `qa/home-helltaker-20261008/original-layouts.json`, `asset-validation.json`, the four collision overlays and contact sheets are development evidence only and are outside the exported Godot game. Original layout data was extracted read-only from original Unity level1 / level2 / level3 / level16 using UnityPy; world transforms include all parent translations and scales.
