from __future__ import annotations

import argparse
import json
from pathlib import Path

from build_v51_sequence_atlases import build_profile

CHARACTERS = {
    "hero_04": {"folder": "洛琪希", "name": "洛琪希", "display_size": 150.0},
    "hero_10": {"folder": "风堇", "name": "风堇", "display_size": 150.0},
    "hero_13": {"folder": "格温", "name": "格温", "display_size": 155.0},
}
ENEMIES = {
    "troop_cannon": {"folder": "炮车", "name": "炮车", "display_size": 120.0, "family": "troop"},
    "troop_melee": {"folder": "近战兵", "name": "近战兵", "display_size": 75.0, "family": "troop"},
    "troop_ranged": {"folder": "远程兵", "name": "远程兵", "display_size": 75.0, "family": "troop"},
    "hilichurl_brute": {"folder": "丘丘暴徒", "name": "丘丘暴徒", "display_size": 375.0, "family": "hilichurl"},
    "rift_bat": {"folder": "小蝙蝠", "name": "小蝙蝠", "display_size": 75.0, "family": "riftwing"},
    "originium_bug": {"folder": "源石虫", "name": "源石虫", "display_size": 75.0, "family": "originium"},
}

def read(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))

def save(path: Path, data) -> None:
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + "\n").replace("\n", "\r\n").encode("utf-8"))

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--characters", type=Path, required=True)
    parser.add_argument("--enemies", type=Path, required=True)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[1] / "game")
    args = parser.parse_args()
    data = args.project / "data" / "v2"
    char_sequences = read(data / "character_sequences.json")
    enemy_sequences = read(data / "enemy_sequences.json")
    assets = read(data / "asset_manifest.json")
    visuals = read(data / "enemy_visuals.json")
    families = read(data / "enemy_families.json")
    for character_id, definition in CHARACTERS.items():
        row = build_profile(args.characters, args.project / "assets/characters/sequences", character_id, definition, "res://assets/characters/sequences")
        char_sequences[character_id] = row
        prefix = f"res://assets/characters/sequences/{character_id}"
        assets[f"character.{character_id}"] = {
            "portrait": f"{prefix}/portrait.png",
            "idle": f"{prefix}/idle.png",
            "move": f"{prefix}/run.png",
            "attack": f"{prefix}/attack.png",
            "hurt": f"{prefix}/portrait.png",
            "skill": f"{prefix}/attack.png",
            "down": f"{prefix}/down.png",
            "idle_frames": row["states"]["idle"]["frames"],
            "idle_columns": row["states"]["idle"]["columns"],
            "idle_cell": row["cell"],
            "idle_fps": 24.0,
            "sequence_profile": character_id,
        }
        print(f"{character_id}: {definition['name']} 24fps")
    for enemy_id, definition in ENEMIES.items():
        row = build_profile(args.enemies, args.project / "assets/enemies/sequences", enemy_id, definition, "res://assets/enemies/sequences")
        enemy_sequences[enemy_id] = row
        visuals = [visual for visual in visuals if visual["id"] != enemy_id]
        visuals.append({
            "id": enemy_id,
            "sprite": f"res://assets/enemies/sequences/{enemy_id}/portrait.png",
            "motion": "sequence",
            "native_facing": 1,
            "pivot": row["pivot"],
            "display_size": definition["display_size"],
            "sequence_profile": enemy_id,
        })
        families = [family for family in families if family["id"] != enemy_id]
        families.append({
            "id": enemy_id,
            "family": definition["family"],
            "variant": enemy_id,
            "behavior": "air_route" if enemy_id == "rift_bat" else ("ranged_volley" if enemy_id == "troop_ranged" else "pressure_advance"),
            "motion": "sequence",
            "visual": enemy_id,
        })
        print(f"{enemy_id}: {definition['name']} 24fps size={definition['display_size']}")
    save(data / "character_sequences.json", char_sequences)
    save(data / "enemy_sequences.json", enemy_sequences)
    save(data / "asset_manifest.json", assets)
    save(data / "enemy_visuals.json", visuals)
    save(data / "enemy_families.json", families)

if __name__ == "__main__":
    main()
