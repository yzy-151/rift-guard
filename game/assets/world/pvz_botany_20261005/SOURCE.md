# Original plant animations

The Peashooter, Repeater, Snow Pea, Sunflower, Potato Mine, Wall-nut and Cherry Bomb are original PopCap / Electronic Arts character artwork, retrieved from the GIF collection in [GeeeekExplorer/PVZ](https://github.com/GeeeekExplorer/PVZ/tree/master/images).

Threepeater, Gatling Pea, Spikeweed and Tall-nut use the original animated art from [JiangNanGame's web PvZ resource collection](https://github.com/jiangnangame/New-Plants-vs-Zombies-JavaScript/tree/master/images/Plants).

Melon-pult uses its original animation tracks and component images from [FregD156/PvZ_Assets](https://github.com/FregD156/PvZ_Assets/tree/main/reanim). `tools/render_melon_reanim_20261005.py` assembles the original affine track transforms. Idle frames 5 through 35 and shooting frames 36 through 73 are retained, with the original 12 fps clock. No plant was redrawn or synthesized.

`tools/extract_pvz_botany_20261005.py` converts the composited GIF frames into transparent PNG atlases with a maximum width of 4096 pixels. The original Peashooter / Repeater / Threepeater / Gatling / Snow Pea frame timings are 90 ms; other original timings are retained in `manifest.json`. Each muzzle landmark follows the painted opening in that specific frame. Foot positions and the ground shadows remain fixed.

The regular Pea and Snow Pea projectiles are from the same Qt resource collection. The melon projectile uses the original `Melonpult_melon.png`, which is also the melon resting in the plant's basket. `projectiles.source.json` records exact URLs and SHA-256 hashes.

`manifest.json` records all source URLs, original GIF hashes, atlas hashes, frame sizes, durations, loop periods, anchor points and mouth coordinates. Iron-nut reuses the original Wall-nut motion and all damage states, with a cached metallic material conversion in GDScript; its original PNG files remain unchanged.
