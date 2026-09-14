from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path
from typing import Iterable

from PIL import Image

CHARACTERS = {
    "hero_01": {"folder": "少女", "name": "少女"},
    "hero_02": {"folder": "希露菲", "name": "希露菲"},
    "traveler": {"folder": "荧", "name": "旅行者"},
    "hero_06": {"folder": "阿米娅", "name": "阿米娅"},
}
STATE_FOLDERS = {
    "idle": {"folder": "breath", "loop": True, "hold_last": False},
    "run": {"folder": "run", "loop": True, "hold_last": False},
    "attack": {"folder": "attack", "loop": True, "hold_last": False},
    "down": {"folder": "death", "loop": False, "hold_last": True},
}
FPS = 24.0
CELL_SIZE = 256
COLUMNS = 8
DISPLAY_SIZE = 150.0


def frame_files(folder: Path) -> list[Path]:
    files = sorted(folder.glob("*.png"), key=lambda path: path.name.lower())
    if not files:
        raise RuntimeError(f"No PNG frames found: {folder}")
    return files


def alpha_bbox(path: Path) -> tuple[int, int, int, int]:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError(f"Transparent frame has no visible pixels: {path}")
    return bbox


def union_bbox(boxes: Iterable[tuple[int, int, int, int]], padding: int = 20) -> tuple[int, int, int, int]:
    rows = list(boxes)
    left = min(box[0] for box in rows) - padding
    top = min(box[1] for box in rows) - padding
    right = max(box[2] for box in rows) + padding
    bottom = max(box[3] for box in rows) + padding
    return left, top, right, bottom


def build_character(source_root: Path, output_root: Path, character_id: str, definition: dict) -> dict:
    source_character = source_root / definition["folder"]
    state_files = {
        state: frame_files(source_character / state_definition["folder"])
        for state, state_definition in STATE_FOLDERS.items()
    }
    all_files = [path for files in state_files.values() for path in files]
    all_boxes = [alpha_bbox(path) for path in all_files]
    crop = union_bbox(all_boxes)
    crop_width = crop[2] - crop[0]
    crop_height = crop[3] - crop[1]
    scale = min((CELL_SIZE - 12) / crop_width, (CELL_SIZE - 12) / crop_height)
    fitted_width = max(1, round(crop_width * scale))
    fitted_height = max(1, round(crop_height * scale))
    offset_x = (CELL_SIZE - fitted_width) // 2
    offset_y = (CELL_SIZE - fitted_height) // 2

    breath_boxes = [alpha_bbox(path) for path in state_files["idle"]]
    anchor_x = statistics.median((box[0] + box[2]) * 0.5 for box in breath_boxes)
    anchor_y = statistics.median(box[3] for box in breath_boxes)
    pivot = [
        round(offset_x + (anchor_x - crop[0]) * scale, 3),
        round(offset_y + (anchor_y - crop[1]) * scale, 3),
    ]

    character_output = output_root / character_id
    character_output.mkdir(parents=True, exist_ok=True)
    states: dict[str, dict] = {}
    for state, files in state_files.items():
        rows = math.ceil(len(files) / COLUMNS)
        atlas = Image.new("RGBA", (COLUMNS * CELL_SIZE, rows * CELL_SIZE), (0, 0, 0, 0))
        for index, path in enumerate(files):
            with Image.open(path) as image:
                crop_image = image.convert("RGBA").crop(crop)
                resized = crop_image.resize((fitted_width, fitted_height), Image.Resampling.LANCZOS)
            cell = Image.new("RGBA", (CELL_SIZE, CELL_SIZE), (0, 0, 0, 0))
            cell.alpha_composite(resized, (offset_x, offset_y))
            if state == "idle" and index == 0:
                cell.save(character_output / "portrait.png", optimize=True, compress_level=9)
            atlas.alpha_composite(cell, ((index % COLUMNS) * CELL_SIZE, (index // COLUMNS) * CELL_SIZE))
        atlas_path = character_output / f"{state}.png"
        atlas.save(atlas_path, optimize=True, compress_level=9)
        state_definition = STATE_FOLDERS[state]
        states[state] = {
            "texture": f"res://assets/characters/sequences/{character_id}/{state}.png",
            "frames": len(files),
            "columns": COLUMNS,
            "fps": FPS,
            "loop": state_definition["loop"],
            "hold_last": state_definition["hold_last"],
        }

    return {
        "name": definition["name"],
        "source_folder": definition["folder"],
        "cell": [CELL_SIZE, CELL_SIZE],
        "pivot": pivot,
        "display_size": DISPLAY_SIZE,
        "fps": FPS,
        "crop": list(crop),
        "states": states,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Build normalized Godot atlases from character frame folders.")
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "game")
    args = parser.parse_args()

    output_root = args.project / "assets" / "characters" / "sequences"
    output_root.mkdir(parents=True, exist_ok=True)
    manifest = {
        character_id: build_character(args.source, output_root, character_id, definition)
        for character_id, definition in CHARACTERS.items()
    }
    manifest_path = args.project / "data" / "v2" / "character_sequences.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    readme_path = output_root / "README.md"
    readme_path.write_text(
        "# Character sequence atlases\n\n"
        "Generated by `tools/build_character_sequence_atlases.py`.\n"
        "Each atlas uses every source frame at 24 FPS. Idle, run, and attack loop; down plays once and holds its last frame.\n",
        encoding="utf-8",
    )
    for character_id, row in manifest.items():
        counts = ", ".join(f"{state}={definition['frames']}" for state, definition in row["states"].items())
        print(f"{character_id} {row['name']}: {counts}; pivot={row['pivot']}")
    print(f"manifest={manifest_path}")


if __name__ == "__main__":
    main()
