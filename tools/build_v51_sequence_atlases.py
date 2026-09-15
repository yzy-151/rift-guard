from __future__ import annotations

import argparse
import json
import math
import statistics
from pathlib import Path
from PIL import Image

FPS = 24.0
CELL = 256
COLUMNS = 8
STATE_FOLDERS = {
    "idle": ("breath", True, False),
    "run": ("run", True, False),
    "attack": ("attack", True, False),
    "down": ("death", False, True),
}
CHARACTERS = {
    "hero_03": {"folder": "芙宁娜", "name": "芙宁娜", "display_size": 150.0},
    "hero_07": {"folder": "丰川祥子", "name": "丰川祥子", "display_size": 150.0},
    "hero_08": {"folder": "艾米莉亚", "name": "艾米莉亚", "display_size": 150.0},
}
ENEMIES = {
    "grunt": {"folder": "木棍丘丘人", "name": "木棍丘丘人", "display_size": 118.0},
    "runner": {"folder": "哥布林", "name": "哥布林", "display_size": 105.0},
    "armored": {"folder": "铁桶僵尸", "name": "铁桶僵尸", "display_size": 130.0},
    "ranged": {"folder": "丘丘弓箭手", "name": "丘丘弓箭手", "display_size": 116.0},
    "buffer": {"folder": "丘丘萨满", "name": "丘丘萨满", "display_size": 128.0},
    "charger": {"folder": "野猪骑士", "name": "野猪骑士", "display_size": 150.0},
    "shielded": {"folder": "皮卡超人", "name": "皮卡超人", "display_size": 230.0},
    "splitter": {"folder": "哥布林茅房", "name": "哥布林茅房", "display_size": 185.0, "procedural": "spawner_stretch"},
}


def files(folder: Path) -> list[Path]:
    return sorted(folder.glob("*.png"), key=lambda p: p.name.lower())


def normalized_rgba(path: Path, canvas: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != canvas:
        image = image.resize(canvas, Image.Resampling.LANCZOS)
    return image


def build_profile(source: Path, output: Path, profile_id: str, definition: dict, resource_prefix: str) -> dict:
    state_files: dict[str, list[Path]] = {}
    death = files(source / definition["folder"] / "death")
    for state, (folder, _loop, _hold) in STATE_FOLDERS.items():
        found = files(source / definition["folder"] / folder)
        if not found and death:
            found = [death[0]]
        if not found:
            raise RuntimeError(f"Missing frames for {definition['folder']}:{state}")
        state_files[state] = found

    all_paths = [p for group in state_files.values() for p in group]
    sizes = [Image.open(p).size for p in all_paths]
    canvas = (max(w for w, _ in sizes), max(h for _, h in sizes))
    boxes = []
    for path in all_paths:
        image = normalized_rgba(path, canvas)
        box = image.getchannel("A").getbbox()
        if box:
            boxes.append(box)
    if not boxes:
        raise RuntimeError(f"No visible pixels: {definition['folder']}")
    padding = max(12, round(max(canvas) * 0.022))
    crop = (
        max(0, min(b[0] for b in boxes) - padding),
        max(0, min(b[1] for b in boxes) - padding),
        min(canvas[0], max(b[2] for b in boxes) + padding),
        min(canvas[1], max(b[3] for b in boxes) + padding),
    )
    crop_w, crop_h = crop[2] - crop[0], crop[3] - crop[1]
    scale = min((CELL - 12) / crop_w, (CELL - 12) / crop_h)
    fitted = (max(1, round(crop_w * scale)), max(1, round(crop_h * scale)))
    offset = ((CELL - fitted[0]) // 2, (CELL - fitted[1]) // 2)

    anchor_source = state_files["idle"] if len(state_files["idle"]) > 1 else state_files["run"]
    anchor_boxes = []
    for path in anchor_source:
        box = normalized_rgba(path, canvas).getchannel("A").getbbox()
        if box:
            anchor_boxes.append(box)
    anchor_x = statistics.median((b[0] + b[2]) * 0.5 for b in anchor_boxes)
    anchor_y = statistics.median(b[3] for b in anchor_boxes)
    pivot = [
        round(offset[0] + (anchor_x - crop[0]) * scale, 3),
        round(offset[1] + (anchor_y - crop[1]) * scale, 3),
    ]

    dest = output / profile_id
    dest.mkdir(parents=True, exist_ok=True)
    states = {}
    for state, paths in state_files.items():
        rows = math.ceil(len(paths) / COLUMNS)
        atlas = Image.new("RGBA", (COLUMNS * CELL, rows * CELL), (0, 0, 0, 0))
        for index, path in enumerate(paths):
            image = normalized_rgba(path, canvas).crop(crop)
            resized = image.resize(fitted, Image.Resampling.LANCZOS)
            cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            cell.alpha_composite(resized, offset)
            if state == "idle" and index == 0:
                cell.save(dest / "portrait.png", optimize=True, compress_level=9)
            atlas.alpha_composite(cell, ((index % COLUMNS) * CELL, (index // COLUMNS) * CELL))
        atlas.save(dest / f"{state}.png", optimize=True, compress_level=9)
        _, loop, hold = STATE_FOLDERS[state]
        states[state] = {
            "texture": f"{resource_prefix}/{profile_id}/{state}.png",
            "frames": len(paths),
            "columns": COLUMNS,
            "fps": FPS,
            "loop": loop,
            "hold_last": hold,
        }
    row = {
        "name": definition["name"],
        "source_folder": definition["folder"],
        "cell": [CELL, CELL],
        "pivot": pivot,
        "display_size": definition["display_size"],
        "native_facing": 1,
        "fps": FPS,
        "crop": list(crop),
        "states": states,
    }
    if "procedural" in definition:
        row["procedural"] = definition["procedural"]
    return row


def write_json(path: Path, data) -> None:
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--characters", type=Path, required=True)
    parser.add_argument("--enemies", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "game")
    args = parser.parse_args()

    char_manifest_path = args.project / "data/v2/character_sequences.json"
    char_manifest = json.loads(char_manifest_path.read_text(encoding="utf-8"))
    for profile_id, definition in CHARACTERS.items():
        char_manifest[profile_id] = build_profile(
            args.characters,
            args.project / "assets/characters/sequences",
            profile_id,
            definition,
            "res://assets/characters/sequences",
        )
    char_manifest["hero_02"]["display_size"] = round(float(char_manifest["hero_02"].get("display_size", 150.0)) * 0.95, 3)
    write_json(char_manifest_path, char_manifest)

    enemy_manifest = {}
    for profile_id, definition in ENEMIES.items():
        enemy_manifest[profile_id] = build_profile(
            args.enemies,
            args.project / "assets/enemies/sequences",
            profile_id,
            definition,
            "res://assets/enemies/sequences",
        )
    write_json(args.project / "data/v2/enemy_sequences.json", enemy_manifest)

    asset_path = args.project / "data/v2/asset_manifest.json"
    assets = json.loads(asset_path.read_text(encoding="utf-8"))
    for profile_id, definition in CHARACTERS.items():
        states = char_manifest[profile_id]["states"]
        assets[f"character.{profile_id}"] = {
            "portrait": f"res://assets/characters/sequences/{profile_id}/portrait.png",
            "idle": states["idle"]["texture"],
            "move": states["run"]["texture"],
            "attack": states["attack"]["texture"],
            "hurt": f"res://assets/characters/sequences/{profile_id}/portrait.png",
            "skill": states["attack"]["texture"],
            "down": states["down"]["texture"],
            "idle_frames": states["idle"]["frames"],
            "idle_columns": COLUMNS,
            "idle_cell": [CELL, CELL],
            "idle_fps": FPS,
            "sequence_profile": profile_id,
        }
    write_json(asset_path, assets)

    for profile_id, row in {**{k: char_manifest[k] for k in CHARACTERS}, **enemy_manifest}.items():
        counts = ", ".join(f"{state}={value['frames']}" for state, value in row["states"].items())
        print(f"{profile_id} {row['name']}: {counts}; pivot={row['pivot']}; display={row['display_size']}")


if __name__ == "__main__":
    main()