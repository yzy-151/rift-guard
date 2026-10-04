# V91 战斗声音与来源

本目录新增 90 个 Ogg：40 个独立音效、23 段原角色日语录音、27 段标准合成语音。未覆盖或改写任何旧素材。`manifest.json` 是逐文件来源、原文件名/剪辑区间、SHA-256、时长、语言、真实性和使用条件的完整清单。

原 `assets/sfx/heroes` 的 22 个 WAV 和 `assets/sfx/boss` 的 30 个 WAV 均保留。旧通用命中、攻击、Boss 与 signature 音频分支由主控制器停用，避免与新 Director 叠播。

## 角色覆盖

“原声”仅指确为相应角色的原始录音，不代表取得了再发行授权。“原创合成”是为本项目新写的日语台词，使用标准 `ja-JP-NanamiNeural` 合成声，不是原作声优，也没有克隆或模仿声优。

| 角色 | 登场 | Q | E | 倒地 |
|---|---|---|---|---|
| 旅行者·荧 | 原声·入队 | 原声·风技能 | 原声·风爆发 | 原声·倒下 |
| 哥伦比娅 | 原声 | 原声 | 原声 | 原声 |
| 希露菲 | 原创合成 | 原创合成·风疗 | 原创合成·守护 | 原创合成 |
| 芙宁娜 | 原声 | 原声 | 原声 | 原声 |
| 洛琪希 | 原创合成 | 原创合成·水术 | 原创合成·涌流 | 原创合成 |
| 阿米娅 | 原声·部署 | 原声·战斗 | 原声·战斗 | 原声·行动失败，改用于倒地 |
| 丰川祥子 | 原创合成·舞台 | 原创合成·音律 | 原创合成·终曲 | 原创合成 |
| 爱蜜莉雅 | 原创合成 | 原创合成·冰花 | 原创合成·白色风暴 | 原创合成 |
| 风堇 | 原声·回合开始，改用于登场 | 原声·战技 | 原声·终结技 | 原声·倒下 |
| 格温 | 原声·选择英雄 | 原创合成·剪裁 | 原创合成·针线 | 原创合成 |

旅行者使用荧的语音与现有立绘一致；风技能语句用于游戏内通用 Q/E，不宣称每种元素均有独立原声。阿米娅档案中的 `CN_025` 等是资源索引名，选中的音轨为日语。希露菲、洛琪希、丰川祥子、爱蜜莉雅仍缺少经过确认的原声；格温仍缺少 Q/E/倒地原声。逐条原创日语台词与合成声名写在 manifest 中。

裂隙统领使用为本项目新写台词和标准 `ja-JP-KeitaNeural` 声音；史莱姆为非语言黏液、蓄力与落地音色；千珏与加里奥保留真实日语选择英雄录音作为登场语音。千珏危险提示是明确的中性系统播报，并非千珏本人台词。

## 来源与实际授权状态

- **音效：Kenney** 的 [Impact Sounds](https://kenney.nl/assets/impact-sounds)、[RPG Audio](https://kenney.nl/assets/rpg-audio)、[Sci-Fi Sounds](https://kenney.nl/assets/sci-fi-sounds)。三个素材包均注明 **CC0 1.0**；随包原始许可文本保存在 `licenses/`。每个输出的素材包、原文件名和滤波/回声/裁剪处理均可在 manifest 追溯。
- **荧、哥伦比娅、芙宁娜：HoYoverse / miHoYo** 原始日语录音，通过 Genshin Impact Wiki 的公开媒体文件取得。[荧语音](https://genshin-impact.fandom.com/wiki/Traveler/Voice-Overs/Japanese)、[哥伦比娅语音](https://genshin-impact.fandom.com/wiki/Columbina/Voice-Overs/Japanese)、[芙宁娜语音](https://genshin-impact.fandom.com/wiki/Furina/Voice-Overs/Japanese)。manifest 记录每个实际下载 URL。原录音版权保留，公开可下载不构成游戏再发行授权。
- **风堇：HoYoverse / miHoYo** 原始日语录音，来自 [Hyacine 日语语音档案](https://honkai-star-rail.fandom.com/wiki/Hyacine/Voice-Overs/Japanese)。同样未验证游戏再发行授权。
- **阿米娅：Hypergryph** 原始日语录音，来自 [isHarryh/Ark-Voice](https://github.com/isHarryh/Ark-Voice) 的 `char_002_amiya.ogg` 与 `voice_data.json` 时间索引。该仓库声明版权归鹰角、非商用且不得损害权利人利益；档案提供者的声明不等于独立再授权。
- **格温、千珏、加里奥：Riot Games** 日语选择英雄录音，来自 CommunityDragon `global/ja_jp/v1/champion-choose-vo/`，英雄编号分别为 887、203、3。**未验证将这些录音用于游戏/应用的授权**；[Riot 公布政策第 3 节](https://www.riotgames.com/en/legal) 明确排除未经授权的游戏/应用使用，不能将其描述为“非商业便可自由使用”。档案可下载不是许可。
- **27 段合成语音**：新写台词，通过 [edge-tts](https://github.com/rany2/edge-tts) 调用 Microsoft Edge 标准日语合成声音；声音服务受 [Microsoft 服务协议](https://www.microsoft.com/en-us/servicesagreement) 约束，未将输出宣称为 CC0。生成工具只放临时目录，未随游戏附带。19 段角色主题原创台词、3 段统领台词、5 段系统兜底提示。未用演员声音作为训练、克隆或模仿目标。

音效许可与角色录音权利是两件事；本清单不宣称整个音频目录可自由公开再发行。

## 混音与事件约定

- `BattleAudioProfile.describe(event, sim)` 产生可检查的声音描述；`BattleVoiceProfiles.resolve(character_id, slot)` 返回语音及来源真实性。
- `BattleAudioDirector.handle_events(batch, sim)` 接收一次真实事件批次。节点自身推进时间；主控制器不要再次调用 `advance()`。菜单/关卡切换调用 `reset()`；声音设置使用 `set_enabled()`。
- `deploy/down` 通过 `hero_id` 回查 `sim.heroes`。Q/E 台词在 `skill_cast/ultimate_cast` 播放；`skill_geometry` 发声按线、扇形、十字、区域区分；`skill_impact/ultimate_impact` 才加入接触音。`signature_start/slash` 等并行视觉事件不会重复播同一动作。
- Boss 用真实的 `boss_arrival` 与 `boss_warning`，由 `enemy_id` / `boss_kind` 确认身份。史莱姆弹跳、弹体落地与千珏箭命中分别绑定相应的 `*_hit` 事件。源石虫只在 `enemy_volatile` 爆炸结算时响重击。普通怪物死亡为身体/衣料/蝙蝠坠落音，无统一爆炸。
- 最多 12 路音效、1 路语音、32 条待播描述、4 条等候语音；同声音有最短间隔和过期时间。倒地优先于技能与登场语音。声优录音保持原音高；没有用单条声音整体调音高替代所有攻击。
- 效果音 `BattleFX`、语音 `BattleVoice` 汇入 `BattleMix`，再送原有 `SFX` 总线，服从原音量设置。语音期间效果音平滑降低 7.5 dB。`BattleMix` 使用 Godot 4.6 的 `AudioEffectHardLimiter`，输出上限 -3 dB，不改动音乐总线。
- 文件转为 mono 44.1 kHz / Ogg Vorbis q5，处理以 -21 LUFS、-4 dBTP 为目标并保留瞬态。短音效和最终编码/声道合并的实际峰值以审核结果为准：90 个解码文件最高采样峰值 -0.7 dBFS；运行时再应用每个 cue 的音量及总线限幅。7 秒实际 Godot 混音测试最高 -5.2 dBFS，并非只检查源文件。

## 验证入口

`res://tests/qa_v91_audio.gd` 检查十角四事件、来源信息、全素材解码、真实事件映射、去重、优先级、队列限制与重置。`res://tests/qa_v91_audio_playback.gd` 使用真实 AudioStreamPlayer、总线和限幅器；用原生渲染器 `--write-movie` 可输出实际混音。Godot 4.6 的 headless dummy renderer 与 `--write-movie` 组合在本机发生 texture_2d_get 崩溃，因此录音验证使用原生 OpenGL Compatibility；普通无窗口逻辑测试正常。
