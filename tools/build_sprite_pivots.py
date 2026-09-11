"""Build per-frame bottom-center pivots for atlas animations."""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "game/data/v2/sprite_pivots.json"
PROFILES = {
    "traveler_idle": ("game/assets/characters/traveler_v18/idle.png", 288, 8, 48, 0),
    "traveler_run": ("game/assets/characters/traveler_v18/run.png", 288, 8, 48, 0),
    "traveler_attack": ("game/assets/characters/traveler_v18/attack.png", 288, 8, 48, 0),
    "traveler_down": ("game/assets/characters/traveler_v18/death.png", 288, 8, 48, 0),
    "hilichurl_run": ("game/assets/enemies/hilichurl_v18/run.png", 256, 6, 30, 0),
    "furina_idle": ("game/assets/characters/furina_frames/furina-motion-sheet.png", 256, 8, 8, 0),
    "furina_move": ("game/assets/characters/furina_frames/furina-motion-sheet.png", 256, 8, 8, 1),
    "furina_hurt": ("game/assets/characters/furina_frames/furina-motion-sheet.png", 256, 8, 4, 3),
    "furina_down": ("game/assets/characters/furina_frames/furina-motion-sheet.png", 256, 8, 8, 4),
    "furina_attack": ("game/assets/characters/furina_ai_frames/attack_16/furina-attack-16-atlas.png", 512, 4, 16, 0),
}


def profile(path: str, cell: int, columns: int, frames: int, row_offset: int) -> dict:
    alpha = np.asarray(Image.open(ROOT / path).convert("RGBA"))[:, :, 3]
    pivots: list[list[float]] = []
    for index in range(frames):
        column = index % columns
        row = row_offset + index // columns
        frame = alpha[row * cell : (row + 1) * cell, column * cell : (column + 1) * cell]
        ys, xs = np.where(frame > 12)
        if len(xs) == 0:
            pivots.append([cell / 2.0, float(cell)])
            continue
        # Bounding-box center stays stable when the frame is mirrored, while
        # the lowest visible pixel provides a consistent ground contact point.
        pivot_x = (float(xs.min()) + float(xs.max()) + 1.0) * 0.5
        pivot_y = float(ys.max()) + 1.0
        pivots.append([round(pivot_x, 2), round(pivot_y, 2)])
    return {
        "path": f"res://{path.removeprefix('game/')}",
        "cell": [cell, cell],
        "columns": columns,
        "frames": frames,
        "native_facing": 1,
        "pivots": pivots,
    }


def main() -> None:
    result = {name: profile(*spec) for name, spec in PROFILES.items()}
    OUTPUT.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"wrote {OUTPUT}")


if __name__ == "__main__":
    main()
