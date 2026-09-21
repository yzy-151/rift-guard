from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
from PIL import Image

ANIMATIONS = {
    "run": ("run", True),
    "attack": ("attack", False),
    "down": ("death", False),
    "skill1": ("skill1_48p", False),
    "skill2": ("skill2_2s", False),
    "skill3": ("skill3_48p", False),
    "skill4": ("skill_27p", False),
}
CELL = 384
SOURCE_CELL = 768
COLUMNS = 8

def build(source: Path, output: Path) -> dict:
    output.mkdir(parents=True, exist_ok=True)
    states = {}
    for state, (folder, loop) in ANIMATIONS.items():
        frames = sorted((source / folder).glob("sprite_*.png"))
        if not frames:
            raise FileNotFoundError(source / folder)
        atlas = Image.new("RGBA", (COLUMNS * CELL, math.ceil(len(frames) / COLUMNS) * CELL))
        for index, path in enumerate(frames):
            with Image.open(path) as original:
                canvas = Image.new("RGBA", (SOURCE_CELL, SOURCE_CELL))
                canvas.alpha_composite(original.convert("RGBA"), (0, 0))
                tile = canvas.resize((CELL, CELL), Image.Resampling.LANCZOS)
            atlas.alpha_composite(tile, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
        target = output / f"{state}.png"
        atlas.save(target, compress_level=4)
        states[state] = {
            "texture": f"res://assets/enemies/sequences/boss_01/{state}.png",
            "frames": len(frames),
            "columns": COLUMNS,
            "fps": 24.0,
            "loop": loop,
            "hold_last": not loop,
        }
        print(f"{state}: {len(frames)} frames, {atlas.size}, {target.stat().st_size} bytes", flush=True)
    states["idle"] = dict(states["run"], frames=1)
    with Image.open(source / "run" / "sprite_001.png") as original:
        portrait = original.convert("RGBA").crop((0, 120, 512, 632))
        portrait.resize((256, 256), Image.Resampling.LANCZOS).save(output / "portrait.png", compress_level=4)
    return {
        "name": "裂隙统领",
        "source_folder": "裂隙统领",
        "cell": [CELL, CELL],
        "pivot": [135, 305],
        "display_size": 285.0,
        "native_facing": 1,
        "fps": 24.0,
        "states": states,
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, default=Path("game/assets/enemies/sequences/boss_01"))
    parser.add_argument("--manifest", type=Path, default=Path("game/data/v2/enemy_sequences.json"))
    args = parser.parse_args()
    entry = build(args.source, args.output)
    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    data["boss_01"] = entry
    args.manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
