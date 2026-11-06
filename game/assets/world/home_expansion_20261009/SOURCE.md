# Helltaker original home expansion assets, 2026-10-09

Six original background PNG files copied byte-for-byte from the locally supplied original Helltaker export.
No original Helltaker character image is copied; character occupants must use Rift Guard hero frames.
No old home assets, room JSON, runtime script, profiles or release executable was edited by this extraction task.

Source textures: `research/helltaker-reference/exported-primary/Assets/Texture2D`.
Source scenes: `research/helltaker-reference/game/Helltaker_Data/level4` through `level9`.
UnityPy is loaded from the previous QA-only dependency directory, outside the packaged game.

Actual original scene mapping:
- puzzle_04 = level4 = chapterBG0004 (1920 x 1080)
- puzzle_05 = level5 = chapterBG0005 (1920 x 1080)
- puzzle_06 = level6 = chapterBG0006 (1920 x 1080)
- puzzle_07 = level7 = chapterBG0007 (1920 x 1080)
- puzzle_08 = level8 = chapterSketches_EXPORT_throne (1920 x 2000)
- puzzle_09 = level9 = chapterBG0008 (1920 x 1080)
- level10 is the dynamic machine confrontation, with no classic chapter background or ordinary wall grid; it is evidence only and excluded from this runtime asset directory.

Coordinates are based on original hierarchy-composed transforms, not local GLB positions.
World-to-source pixel mapping:
`[image_width/2 + (world_x - background_world_x)*100, image_height/2 - (world_y - background_world_y)*100]`.
Standard chapter backgrounds have world center [3,3]. The throne has world center [3,-1.5], original camera center [3,-6].
Every floor cell is 100 original source pixels wide/high; source_origin is the top-left corner of cell [0,0], while the per-cell source pixel is its center.

QA geometry `qa/home-expansion-20261009/original-floor-reconstruction.json` contains grid, source_origin, source_cell, source_view, source_canvas, background_path, cell_coordinates and original_objects.
Raw scene evidence `original-layouts.json` also contains every enabled/disabled collider, renderer, original cameras and pertinent MonoBehaviour bytes.
The default source_view is a suggested static puzzle framing crop; original_camera_source_view stores the actual unmodified Unity camera framing.
Floor reconstruction excludes original active wall colliders, tests original red floor at five cross points, and retains the component connected to the original player spawn.
All original puzzle objects lie on reconstructed original floor; every source floor center is also checked against the original collider AABBs.

NPC sprite feet are original renderer position minus 0.28 world unit on Y.
The level9 original NPC starts offscreen at [6,9.5] feet; retain this as evidence and use the original goalSprite [3,4.5] as the replacement visitor target anchor.
Spikes preserve the two original serialized state fields (spikeUp and spikeStatic).

SHA-256 provenance for every copied background is recorded in manifest.json.
QA contact sheets include labeled original background framing and original collider/floor/object overlays; these are separate from game assets.
