from __future__ import annotations

import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game/data/v2"

def read(name):
    return json.loads((DATA / name).read_text(encoding="utf-8"))

def save(name, data):
    (DATA / name).write_bytes((json.dumps(data, ensure_ascii=False, indent=2) + "\n").replace("\n", "\r\n").encode("utf-8"))

characters = read("characters.json")
by_id = {row["id"]: row for row in characters}
roxy = by_id["hero_04"]
roxy["content_ready"] = True
roxy["unlocked_by_default"] = True
roxy["active_skill"].update({"name": "水脉疗愈", "kind": "healing_surge", "power": 195, "radius": 230, "cooldown": 12.0, "targeting": "point", "description": "治疗目标区域内友军195点生命。"})
feng = by_id["hero_10"]
feng["content_ready"] = True
feng["unlocked_by_default"] = True
feng["active_skill"].update({"name": "风刃切流", "kind": "wind_cut", "power": 225, "radius": 200, "cooldown": 10.5, "targeting": "point", "description": "对目标区域敌人造成225点风元素伤害。"})
feng["ultimate"].update({"name": "长风复苏", "kind": "renewing_breeze", "power": 42, "radius": 280, "energy_cost": 165, "cooldown": 44.0, "targeting": "point", "duration": 12.0, "description": "在目标区域持续12秒，每0.85秒为友军恢复42点生命。"})
gwen = copy.deepcopy(by_id["hero_04"])
gwen.update({"id": "hero_13", "name": "格温", "role": "无元素织针", "element": "none", "max_hp": 960, "armor": 76, "attack": 96, "attack_rate": 1.42, "attack_range": 345, "move_speed": 122, "block": 2, "can_hit_air": True, "asset_key": "character.hero_13", "unlocked_by_default": True, "animation_profile": "hero_13", "content_ready": True})
gwen["active_skill"].update({"name": "丝缕缠流", "kind": "thread_shelter", "power": 0, "radius": 345, "cooldown": 34.0, "targeting": "self", "duration": 5.0, "description": "攻击范围内所有友军5秒内免受伤害。"})
gwen["ultimate"].update({"name": "引针簇射", "kind": "needle_barrage", "power": 76, "radius": 255, "energy_cost": 180, "cooldown": 49.0, "targeting": "point", "needles": 12, "description": "向目标区域射出12根追踪针；每根造成76点无元素伤害并波及附近敌人。"})
gwen["passive"] = {"name": "剪影织卫", "kind": "thread_guard", "description": "高生命、高攻击的无元素近远程守卫。"}
if "hero_13" not in by_id:
    characters.append(gwen)
save("characters.json", characters)

stages = read("stages.json")
new_regular = [
    ("hilichurl_brute", 56, 2, 3.2),
    ("rift_bat", 98, 3, 2.5),
    ("originium_bug", 132, 4, 2.2),
    ("troop_cannon", 156, 1, 1.0),
]
for stage in stages:
    if stage["id"] in ("stage_01", "stage_endless"):
        continue
    routes = [str(wave.get("route_id", "main")) for wave in stage.get("waves", [])]
    route = routes[0] if routes else "main"
    existing = {str(wave.get("enemy_id", "")) for wave in stage.get("waves", [])}
    for enemy_id, at, count, interval in new_regular:
        if enemy_id not in existing:
            stage["waves"].append({"at": at, "enemy_id": enemy_id, "count": count, "interval": interval, "route_id": route})
    stage["waves"].sort(key=lambda wave: float(wave.get("at", 0)))
save("stages.json", stages)
print("configured three characters and staged six new enemy types")

# Gwen requires an animation state profile alongside the sequence atlas.
animation_path = DATA / "animation_profiles.json"
animation_profiles = read("animation_profiles.json")
if not any(profile["id"] == "hero_13" for profile in animation_profiles):
    import copy
    profile = copy.deepcopy(animation_profiles[-1])
    profile["id"] = "hero_13"
    animation_profiles.append(profile)
    save("animation_profiles.json", animation_profiles)
