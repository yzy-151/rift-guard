# V25 角色动画与透明特效交付规范

## 角色动画最小集合

| 状态 | 建议帧数 | 建议时长 | 循环 | 用途 |
|---|---:|---:|---|---|
| idle | 48 | 2.0 秒 | 是 | 待机呼吸 |
| run | 48 | 2.0 秒 | 是 | 全地图移动 |
| attack | 24–36 | 0.7–1.2 秒 | 否 | 普通攻击 |
| skill | 24–48 | 0.8–1.6 秒 | 否 | 主动技能 |
| ultimate | 36–72 | 1.2–2.4 秒 | 否 | 终结技 |
| hurt | 8–12 | 0.25–0.4 秒 | 否 | 受击 |
| down | 18–24 | 0.7–1.0 秒 | 否 | 阵亡 |
| deploy | 16–24 | 0.5–0.8 秒 | 否 | 入场 |

静态素材也可接入：缺少动作时，状态机会使用轻微位移、缩放和闪白回退，不阻塞游戏。最终角色素材应补齐上表八种状态。

## 画面约束

- 每一帧使用相同画布、角色脚底锚点、人物尺寸和镜头。
- 标准朝向为面向右侧，游戏运行时通过水平翻转处理向左移动。
- 角色本体、武器、飞行弹道、命中特效分别交付，避免把长距离弹道烘焙进人物序列。
- 不允许位置漂移、尺寸呼吸漂移、身体裁切、绿幕残边或不透明背景。
- 推荐透明 PNG 序列；视频使用带 alpha 的 WebM。颜色空间 sRGB，禁止预乘 alpha。
- 推荐角色画布 512×512，脚底 pivot 为 `(0.5, 0.72)`。
- 命名：`character_action_0001.png`，例如 `furina_attack_0001.png`。

## 动作与战斗同步

每个攻击动作需标记五个时间点：

1. `anticipation`：前摇开始。
2. `vfx`：武器光或法术起手特效出现。
3. `hit`：伤害真正结算。
4. `sfx`：命中音效播放，通常与 hit 同帧。
5. `recovery`：后摇结束，可切回 idle/run。

游戏按攻速缩放整条时间轴，因此同一套攻击动画可以适配不同攻速。移动由 Godot 控制，run 只负责原地跑步循环。重大受击可以用短暂拉伸、闪白、位移和震屏补足。

## 目录结构

```text
game/assets/characters/<character_id>/
  idle/
  run/
  attack/
  skill/
  ultimate/
  hurt/
  down/
  deploy/
game/assets/vfx/<profile_id>/
game/assets/projectiles/<projectile_id>/
game/assets/audio/sfx/<character_id>/
```

角色状态写入 `game/data/v2/animation_profiles.json`，能力时间点写入 `game/data/v2/characters.json` 的 `timeline`，透明特效池写入 `game/data/v2/vfx_profiles.json`。替换文件后保持 id 与命名不变即可热替换，无需修改战斗代码。
