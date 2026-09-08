# 临时素材替换清单

更新时间：2026-09-08

| 用途 | 当前临时素材目录 | 来源 | 后续替换入口 |
|---|---|---|---|
| UI、技能、元素、图鉴图标 | `game/assets/ui/icons/temporary/nieobie/` | Nieobie Game Icon Pack，CC0 | 同名 SVG 或调整各 UI 脚本的图标映射 |
| 斩击序列 | `game/assets/vfx/third_party/cethiel_weapon_slash/` | OpenGameArt 下载包 | `battle_view.gd` 的 `slash_frames` |
| 枪口火焰与离子特效 | `game/assets/vfx/third_party/reactorcore_muzzle/` | OpenGameArt 下载包 | `battle_view.gd` 的 `muzzle_fire_frames`、`muzzle_ion_frames` |
| Helltaker 风格背景、面板和按钮 | `game/assets/helltaker/` | 本地参考素材 | `battle_hud.gd`、`stage_select_panel.gd`、`dialogue_panel.gd` 的集中 preload |
| 角色立绘 | `game/assets/characters/` 与 `game/data/v2/asset_manifest.json` | 本地项目及生成素材 | `asset_manifest.json` 中按角色 key 替换 |
| 芙宁娜战斗帧 | `game/assets/characters/furina/` | 当前审核用素材 | `furina_frame_actor.gd` 的帧资源 |
| 对话数据、姓名、立绘位置与缩放 | `content/game_config.xlsx` | 用户可编辑内容表 | Excel 对话与图片字段直接修改后重新导入 |

## 已下载图标明细

`game/assets/ui/icons/temporary/nieobie/` 内含 `anemo.svg`、`archive.svg`、`armor.svg`、`attack.svg`、`boss.svg`、`card.svg`、`character.svg`、`cryo.svg`、`door.svg`、`electro.svg`、`experience.svg`、`geo.svg`、`health.svg`、`hydro.svg`、`level.svg`、`map.svg`、`pause.svg`、`pyro.svg`、`skill.svg`、`skull.svg`、`squad.svg` 与 `LICENSE-CC0.txt`。

源仓库保存在 `research/nieobie-game-icon-pack/`，方便核对原始文件和许可证。
