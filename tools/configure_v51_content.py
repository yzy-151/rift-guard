from __future__ import annotations
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def save(path: Path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


characters_path = GAME / "data/v2/characters.json"
characters = load(characters_path)
target_ranges = {"traveler":245,"hero_01":365,"hero_02":325,"hero_03":340,"hero_04":380,"hero_05":350,"hero_06":360,"hero_07":340,"hero_08":330,"hero_09":355,"hero_10":345,"hero_11":340,"hero_12":365}
for row in characters:
    row["attack_range"] = target_ranges[row["id"]]
    if row["id"] == "hero_03":
        row["role"] = "水系法师"
        row["element"] = "hydro"
    elif row["id"] == "hero_07":
        row["role"] = "风系乐律法师"
        row["element"] = "anemo"
        row["active_skill"]["name"] = "苍风奏鸣"
        row["active_skill"]["kind"] = "sonic_wave"
        row["ultimate"]["name"] = "命运风暴交响"
        row["passive"]["description"] = "音乐攻击积累和声，满层时追加风元素音浪并扩散附着。"
    elif row["id"] == "hero_08":
        row["role"] = "冰系法师"
        row["element"] = "cryo"
save(characters_path, characters)

families_path = GAME / "data/v2/enemy_families.json"
families = load(families_path)
updates = {
    "grunt": ("hilichurl", "club", "pressure_advance", "sequence"),
    "runner": ("goblin", "scout", "zigzag_dash", "sequence"),
    "armored": ("undead", "bucket", "armor_lock", "sequence"),
    "ranged": ("hilichurl", "archer", "ranged_volley", "sequence"),
    "buffer": ("hilichurl", "shaman", "haste_aura", "sequence"),
    "shielded": ("construct", "pekka", "armor_lock", "sequence"),
    "charger": ("raider", "hog", "charge_burst", "sequence"),
    "splitter": ("goblin", "hut", "periodic_spawn", "sequence"),
}
for row in families:
    if row["id"] in updates:
        family, variant, behavior, motion = updates[row["id"]]
        row.update({"family": family, "variant": variant, "behavior": behavior, "motion": motion, "visual": row["id"]})
for row in [
    {"id":"slime_pyro","family":"slime","variant":"pyro","behavior":"death_burst","motion":"charged_hop","visual":"slime_pyro"},
    {"id":"slime_electro","family":"slime","variant":"electro","behavior":"split_on_death","motion":"double_bounce","visual":"slime_electro"},
    {"id":"slime_anemo","family":"slime","variant":"anemo","behavior":"air_route","motion":"hover_swoop","visual":"slime_anemo"},
    {"id":"slime_hydro","family":"slime","variant":"hydro","behavior":"healing_pulse","motion":"gentle_bob","visual":"slime_hydro"},
    {"id":"slime_cryo","family":"slime","variant":"cryo","behavior":"slow_aura","motion":"guard_squash","visual":"slime_cryo"},
]:
    existing = next((x for x in families if x["id"] == row["id"]), None)
    if existing:
        existing.update(row)
    else:
        families.append(row)
save(families_path, families)

visual_path = GAME / "data/v2/enemy_visuals.json"
visuals = load(visual_path)
by_id = {row["id"]: row for row in visuals}
sequence_sizes = {
    "grunt":118, "runner":105, "armored":130, "ranged":116,
    "buffer":128, "charger":150, "shielded":230, "splitter":185,
}
for enemy_id, size in sequence_sizes.items():
    by_id[enemy_id] = {
        "id": enemy_id,
        "sprite": f"res://assets/enemies/sequences/{enemy_id}/portrait.png",
        "motion": "sequence",
        "native_facing": 1,
        "pivot": [128, 240],
        "display_size": size,
        "sequence_profile": enemy_id,
    }
slime_specs = {
    "slime_pyro": ("pyro_slime.png", 96),
    "slime_electro": ("electro_slime.png", 96),
    "slime_anemo": ("anemo_slime.png", 96),
    "slime_hydro": ("hydro_slime.png", 96),
    "slime_cryo": ("cryo_slime.png", 96),
}
for enemy_id, (filename, size) in slime_specs.items():
    by_id[enemy_id] = {
        "id": enemy_id,
        "sprite": f"res://assets/enemies/slimes/{filename}",
        "motion": "slime",
        "native_facing": 1,
        "pivot": [256, 480],
        "display_size": size,
    }
save(visual_path, list(by_id.values()))

source = Image.open(GAME / "assets/enemies/slimes/hydro_slime.png").convert("RGBA")
pixels = source.load()
for y in range(source.height):
    for x in range(source.width):
        r, g, b, a = pixels[x, y]
        if a:
            pixels[x, y] = (min(255, int(r * 0.72 + 48)), min(255, int(g * 1.02 + 28)), min(255, int(b * 1.14 + 34)), a)
source.save(GAME / "assets/enemies/slimes/cryo_slime.png", optimize=True, compress_level=9)

stages_path = GAME / "data/v2/stages.json"
stages = load(stages_path)
placements = {
    "stage_01": ("grunt", "slime_pyro"),
    "stage_02": ("runner", "slime_electro"),
    "stage_03": ("flyer", "slime_anemo"),
    "stage_04": ("healer", "slime_hydro"),
    "stage_05": ("warder", "slime_cryo"),
}
def replace_first(value, old, new):
    if isinstance(value, dict):
        if value.get("enemy_id") == old:
            value["enemy_id"] = new
            return True
        return any(replace_first(child, old, new) for child in value.values())
    if isinstance(value, list):
        return any(replace_first(child, old, new) for child in value)
    return False
for stage in stages:
    if stage.get("id") in placements:
        replace_first(stage, *placements[stage["id"]])
save(stages_path, stages)

print("configured 3 characters, 8 sequence enemies, 5 elemental slimes and 5 campaign encounters")
# V51_CATALOG_REPLACEMENTS: keep the core runtime catalog in sync with replaceable art.
catalog_path = GAME / "scripts/combat_catalog.gd"
catalog = catalog_path.read_text(encoding="utf-8")
catalog_replacements = {
    '"grunt": {"name": "裂隙兽", "hp": 95.0, "armor": 0.0, "speed": 54.0, "damage": 15.0, "rate": 1.0, "leak": 8, "color": "#bd8e94", "size": 48.0}': '"grunt": {"name": "木棍丘丘人", "hp": 120.0, "armor": 4.0, "speed": 52.0, "damage": 17.0, "rate": 1.0, "leak": 8, "color": "#bd8e94", "size": 48.0}',
    '"runner": {"name": "疾行兽", "hp": 62.0, "armor": 0.0, "speed": 95.0, "damage": 10.0, "rate": 1.3, "leak": 6, "color": "#e6c77b", "size": 39.0}': '"runner": {"name": "哥布林", "hp": 72.0, "armor": 0.0, "speed": 92.0, "damage": 12.0, "rate": 1.35, "leak": 6, "color": "#e6c77b", "size": 39.0}',
    '"armored": {"name": "重甲兽", "hp": 185.0, "armor": 85.0, "speed": 35.0, "damage": 27.0, "rate": 0.85, "leak": 15, "color": "#b19fc9", "size": 62.0}': '"armored": {"name": "铁桶僵尸", "hp": 230.0, "armor": 92.0, "speed": 31.0, "damage": 29.0, "rate": 0.82, "leak": 15, "color": "#b19fc9", "size": 62.0}',
    '"ranged": {"name": "蚀骨弩手", "hp": 128.0, "armor": 12.0, "speed": 43.0, "damage": 21.0, "rate": 0.72, "leak": 12, "color": "#e58b73", "size": 48.0, "attack_range": 275.0}': '"ranged": {"name": "丘丘弓箭手", "hp": 128.0, "armor": 12.0, "speed": 43.0, "damage": 21.0, "rate": 0.72, "leak": 12, "color": "#e58b73", "size": 48.0, "attack_range": 300.0, "projectile_style": "arrow"}',
    '"buffer": {"name": "咏唱祭司", "hp": 155.0, "armor": 18.0, "speed": 38.0, "damage": 9.0, "rate": 0.65, "leak": 14, "color": "#cf7fda", "size": 54.0, "aura_radius": 155.0}': '"buffer": {"name": "丘丘萨满", "hp": 155.0, "armor": 18.0, "speed": 36.0, "damage": 18.0, "rate": 0.68, "leak": 14, "color": "#67d8b0", "size": 54.0, "attack_range": 300.0, "aura_radius": 155.0, "projectile_style": "anemo_orb"}',
    '"shielded": {"name": "壁垒卫士", "hp": 210.0, "armor": 38.0, "speed": 31.0, "damage": 31.0, "rate": 0.78, "leak": 20, "color": "#76a6d8", "size": 66.0, "shield": 180.0}': '"shielded": {"name": "皮卡超人", "hp": 520.0, "armor": 105.0, "speed": 20.0, "damage": 55.0, "rate": 0.64, "leak": 28, "color": "#76a6d8", "size": 92.0, "shield": 260.0, "large_scale": 2.5}',
    '"charger": {"name": "裂蹄冲锋者", "hp": 145.0, "armor": 18.0, "speed": 48.0, "damage": 34.0, "rate": 0.92, "leak": 16, "color": "#ef795b", "size": 58.0, "charge_multiplier": 2.15}': '"charger": {"name": "野猪骑士", "hp": 175.0, "armor": 20.0, "speed": 50.0, "damage": 38.0, "rate": 0.92, "leak": 16, "color": "#ef795b", "size": 58.0, "charge_multiplier": 2.15}',
    '"splitter": {"name": "孳生母体", "hp": 240.0, "armor": 26.0, "speed": 32.0, "damage": 20.0, "rate": 0.82, "leak": 22, "color": "#d77aa9", "size": 72.0, "split_count": 2}': '"splitter": {"name": "哥布林茅房", "hp": 680.0, "armor": 38.0, "speed": 0.0, "damage": 0.0, "rate": 0.5, "leak": 32, "color": "#d77aa9", "size": 90.0, "spawner": true, "spawn_kind": "runner", "spawn_count": 2, "spawn_interval": 6.5, "spawn_limit": 8}',
    '"boss_02": {"name": "黑曜母巢"': '"boss_02": {"name": "史莱姆王"',
}
for old, new in catalog_replacements.items():
    catalog = catalog.replace(old, new)
slime_rows = '''\n\t"slime_pyro": {"name": "火史莱姆", "hp": 105.0, "armor": 4.0, "speed": 56.0, "damage": 18.0, "rate": 1.0, "leak": 8, "color": "#f06a4e", "size": 47.0, "death_burst": 42.0},
\t"slime_electro": {"name": "雷史莱姆", "hp": 112.0, "armor": 5.0, "speed": 62.0, "damage": 17.0, "rate": 1.12, "leak": 8, "color": "#b27ae8", "size": 47.0},
\t"slime_anemo": {"name": "风史莱姆", "hp": 92.0, "armor": 2.0, "speed": 78.0, "damage": 14.0, "rate": 1.15, "leak": 9, "color": "#69d8c6", "size": 45.0, "flying": true},
\t"slime_hydro": {"name": "水史莱姆", "hp": 128.0, "armor": 8.0, "speed": 49.0, "damage": 12.0, "rate": 0.86, "leak": 10, "color": "#65afea", "size": 48.0, "heal_radius": 170.0, "heal_interval": 6.0},
\t"slime_cryo": {"name": "冰史莱姆", "hp": 145.0, "armor": 18.0, "speed": 43.0, "damage": 16.0, "rate": 0.88, "leak": 11, "color": "#8de2ee", "size": 49.0, "shield": 75.0},'''
if '"slime_pyro"' not in catalog:
    catalog = catalog.replace('\n\t"boss_01":', slime_rows + '\n\t"boss_01":')
catalog_path.write_text(catalog, encoding="utf-8")