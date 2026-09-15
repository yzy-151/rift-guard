# V51 素材位置与替换表

## 角色

| 角色 | ID | 运行时图集目录 | 数据配置 |
|---|---|---|---|
| 芙宁娜 | `hero_03` | `game/assets/characters/sequences/hero_03/` | `game/data/v2/character_sequences.json` |
| 丰川祥子 | `hero_07` | `game/assets/characters/sequences/hero_07/` | `game/data/v2/character_sequences.json` |
| 艾米莉亚 | `hero_08` | `game/assets/characters/sequences/hero_08/` | `game/data/v2/character_sequences.json` |
| 希露菲 | `hero_02` | `game/assets/characters/sequences/hero_02/` | `display_size = 142.5` |

每个目录含 `idle.png`、`run.png`、`attack.png`、`down.png` 与 `portrait.png`。重新读取源帧并生成图集时运行 `python tools/build_v51_sequence_atlases.py`。

## 怪物

| 怪物 | ID | 运行时图集目录 | 机制 |
|---|---|---|---|
| 木棍丘丘人 | `grunt` | `game/assets/enemies/sequences/grunt/` | 基础近战 |
| 哥布林 | `runner` | `game/assets/enemies/sequences/runner/` | 高移速近战 |
| 铁桶僵尸 | `armored` | `game/assets/enemies/sequences/armored/` | 高护甲推进 |
| 丘丘弓箭手 | `ranged` | `game/assets/enemies/sequences/ranged/` | 远程箭矢 |
| 丘丘萨满 | `buffer` | `game/assets/enemies/sequences/buffer/` | 风法球与加速光环 |
| 野猪骑士 | `charger` | `game/assets/enemies/sequences/charger/` | 距离充足时冲锋 |
| 皮卡超人 | `shielded` | `game/assets/enemies/sequences/shielded/` | 2.5 倍大型重甲单位 |
| 哥布林茅房 | `splitter` | `game/assets/enemies/sequences/splitter/` | 定时生产哥布林 |

怪物序列数据位于 `game/data/v2/enemy_sequences.json`，怪物图鉴与静态预览绑定位于 `game/data/v2/enemy_visuals.json`，战斗数值与机制位于 `game/scripts/combat_catalog.gd`。

## 元素史莱姆

史莱姆独立素材位于 `game/assets/enemies/slimes/`。运行时 ID 为 `slime_pyro`、`slime_electro`、`slime_anemo`、`slime_hydro`、`slime_cryo`，Boss `boss_02` 显示为史莱姆王。

尚未获得新动作素材的角色与 `flyer`、`healer`、`warder` 保留现有占位素材，后续只需按同一目录结构生成图集并更新序列清单。