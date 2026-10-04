# V91 音频验证记录

日期：2026-10-03。引擎：Godot 4.6 stable `89cea1439`。音频组件不改模拟、卡牌或原素材；主控制器集成由主线程负责。

## 交付与覆盖

- 独立 `battle_audio_director.gd`、`battle_audio_profile.gd`、`battle_voice_profiles.gd`；十位角色登场/Q/E/倒地均有声音。五位角色四槽使用本人原日语录音，其中风堇登场和阿米娅倒地明确为原声语境改用；格温登场原声，其余缺槽用新写台词、标准日语合成声补齐，不称原声优。
- `game/assets/audio_v91` 共 90 个 Ogg，1,740,643 字节：40 音效、23 原声剪辑、27 合成语音。19 个合成槽有独立角色主题日语台词；其余为统领和系统提示。真实性、版权和来源边界见该目录 README 与 manifest。
- FX 最多 12 路、语音 1 路，队列上限 32，等待语音最多 4 条；语音期间 FX 降低 7.5 dB，合并战斗总线上限 -3 dB。输出仍经过原 SFX 设置，不改音乐。
- 已核对真实事件 `boss_arrival/boss_warning/down`；史莱姆与飞行弹体落地、针线命中、黑兔脉冲、沙龙弹命中保留实际结算时机；`enemy_dash_warning` 蓄力和 `enemy_spin` 旋斧分开。普通死亡不统一爆炸。

## 实际结果

| 验证 | 结果 | 日志/证据 |
|---|---|---|
| 资源、身份、事件、限流、队列、倒地抢占、重置、静音 | 333 checks / 0 failures | `qa_v91_audio_final.log` |
| 真实 AudioStreamPlayer、分组总线、-3 dB 限幅、停止释放 | 7 checks / 0 failures | `qa_audio_playback_headless_final.log` |
| 真实 main 集成：身份、静音、重开、无尽、家园、退出 | 17 checks / 0 failures | `qa_v91_audio_integration_final.log` |
| 原生 OpenGL 实际录音 | 7 checks / 0 failures，421 帧 / 60 FPS，7.0167 秒 | `qa_audio_playback_native.log`；`.err` 为 0 字节 |
| 全文件解码、时长与 SHA-256 | 90 / 90；全部哈希匹配，无 0 dBFS 裁切 | `audio_audit.json` |
| 文件采样峰值 | 最高 -0.7 dBFS，实际 cue 再降低音量并走限幅 | `audio_audit.json` |
| 实际混音采样峰值 / 平均值 | -5.2 dBFS / -22.4 dBFS | `battle_audio_actual.wav`；ffmpeg volumedetect |

上述文件统一位于 `C:/Users/yzy/Desktop/codex/rift-guard/v91-2026-10-03/audio/`，未把临时大视频复制进仓库。`battle_audio_actual_native.avi` 是空白视口的音频组件录音证据，**不是完整战斗视觉演示**；主线程另录正式带画面的战斗演示。

逻辑验证入口：`Godot --headless --path game --script res://tests/qa_v91_audio.gd`。真实播放器入口：`res://tests/qa_v91_audio_playback.gd`；配合原生 Compatibility 渲染器和 `--write-movie` 可得到声音真实混合后的录音。正式集成回归入口为 `res://tests/qa_v91_audio_integration.gd -- --qa-output=C:/Users/yzy/Desktop/codex/任务目录`，缺少绝对路径或路径不在指定缓存根目录内时退出码 2，不实例化游戏、不接触用户存档。

先失败后修复的日志：`qa_audio_event_mapping_red.log`（8 个真实事件缺映射）、`qa_audio_signature_red.log`（5 个延迟命中缺映射）、`qa_audio_playback_red.log`（缺合并限幅总线），对应最终验证均已通过。

## 只读集成复核

使用临时 `integration_review.gd` 实例化真实 `main.tscn`，关闭自动物理步进，直接调用主控制器方法。通过 `--qa-output` 将测试保存隔离到同一临时目录。结果在 `integration_review.log`：

- `down{hero_id:0}` 经 `main.process_events()` 正确解析为阿米娅 `hero_06_down`。
- `muted=true` 后经 `process_events()`，战斗声音和队列清空；SFX/Master 总线音量另由旧 AudioDirector 控制。菜单重置后 active/voice/queued 均空，duck 归零。
- **三个复现问题已由主线程修复并复验**：`restart(true)`、`confirm_next_squad()` 原先未清旧语音；递归 `_stop_scene_audio()` 原先只停玩家而未清延迟 cue。主线程补上重置，也覆盖继承进入无尽。`integration_review_fixed.log` 为 `REVIEW FINDINGS 0`；正式 17 项集成回归亦全部通过。复核者没有修改 main。

## 已处理的工具边界

- Godot 4.6 本机 `--headless --write-movie` 在 dummy renderer 的 `texture_2d_get` 中崩溃；改用真实 OpenGL Compatibility 成功录出完整音轨。此失败记录保留，不包装为测试通过。
- 最初超实时 headless 播放测试在退出时留下 Ogg playback 引用；停止并释放节点后给音频混音线程 120 ms 真实时间即可消失。最终 headless 与原生测试均无 ObjectDB/resource 退出警告。没有据此泛称项目其他测试的退出警告已解决。
- 未做人工盲听评价。已做真实流解码、播放器运行、实际录音和响度测量，录音可试听；声音审美仍以实际游戏试听反馈为准。
