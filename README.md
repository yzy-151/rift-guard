# Rift Guard / 裂隙守望

master，[V15 Windows试玩版](builds/rift-guard-v15/RiftGuard-V15.exe) 已修复发布包菜单点击链路，并在导出的 EXE 内通过普通模式、关卡选择、编队确认和无尽模式的真实窗口点击验收。

master，开场剧情现有两项 Helltaker 式回应：“稳住水晶”使本关幸运值提高 8%，而“追查求救信号”会永久解锁隐藏角色白露，后续剧情可继续用同一 JSON 格式增加分支和结果。

master，[V15视觉与发布验收](docs/v15-validation/REPORT.md) 包含双选项、普通模式、无尽模式截图，以及 20 组核心回归和发布包 12/12 点击检查。

master，剧情模式可从主菜单点击“裂隙守望”，再点击第一关并确认编队进入；战斗中按 Z 进入全队移动、按 X 跟随旅行者、按 C 原地坚守，右键下达移动命令。

master，当前玩法现已登记为 **模式一：裂隙守望**；模式数据位于 `game/data/v2/modes.json`，以后新增模式无需改写现有关卡入口。master，模式一的强化不设层数上限，数值、弹道数量、贯穿、连锁、爆炸、追击、处决、击杀成长和周期场外支援都能持续叠加。master，水晶每逢 3 的倍数等级至少出现一张机制卡，队伍未满三人时还会出现角色增援卡。

master，[模式一 V2 可试玩版](builds/mode1-v2/RiftGuard-Mode1-V2.exe) 已包含本轮机制、特效与对话演出更新。

master，战斗现已接入 CC0 斩击动画、强化弹道轨迹、冲击环、爆炸射线和屏幕震动；第三方素材来源与许可记录在 `game/assets/vfx/third_party/README.md`。master，对话采用原创的黑红漫画式界面、双侧立绘回弹入场、快速文字显隐和短促音效，参考 Helltaker 的演出节奏，但不包含其原始素材。

master，第一期核心循环现已成为正式启动路径：第一关由无元素旅行者出战，击杀怪物为水晶提供经验，水晶升级触发三选一，首轮保证元素赋予卡，选定元素后本关锁定，全部局内 Buff 在重开或下一关时清空。

- [第一期玩法规格](docs/superpowers/specs/2026-09-07-core-game-loop-design.md)
- [第一期实施计划](docs/superpowers/plans/2026-09-07-core-loop-foundation.md)
- [第一期验证报告](docs/phase-1-validation/REPORT.md)
- [战斗开始截图](docs/phase-1-validation/battle-start.png)
- [首次三选一截图](docs/phase-1-validation/first-reward.png)

master，旧 **M9 功能验证版** 的整图拉伸与旋转动画已经视觉验收失败，不再作为发布候选；其 EXE 仅保留用于历史对照。

- [Excel 配置模板](builds/m9/content/game_config.xlsx)
- [芙宁娜五组帧动画总览](game/assets/characters/furina_frames/furina-motion-preview.jpg)
- [芙宁娜实机与范围法阵截图](docs/m9-validation/furina-frame-idle-range.png)
- [M9 验证记录](docs/m9-validation/REPORT.md)
- [M10 逐帧动画生产方案](docs/m10-frame-animation-pipeline.md)
- [芙宁娜骨骼与范围法阵截图](docs/m8-validation/furina-rig-selected.png)
- [M8 验证记录](docs/m8-validation/REPORT.md)
- [芙宁娜Q版实机截图](docs/m7-validation/furina-chibi-battle.png)
- [M7 验证记录](docs/m7-validation/REPORT.md)
- [芙宁娜实机截图](docs/m6-validation/furina-battle.png)
- [M6 验证记录](docs/m6-validation/REPORT.md)
- [自己修改 UI、对话和立绘](docs/自己改UI和对话.md)
- [角色与特效升级方案](docs/角色与特效升级方案.md)
- [M5 验证记录](docs/m5-validation/REPORT.md)
- [本地素材来源](docs/m4-assets.md)
- [Godot 工程](game/project.godot)
- [整体设计](docs/game-design.md)
- [素材流水线](docs/asset-pipeline.md)

master，本版可直接从 Excel 读取姓名、对白、立绘资源、左右位置、坐标、缩放、翻转、UI 尺寸、素材、文字、字号和九宫格边距，并支持 F6 对话预览。

master，本版使用铁蒺藜体，并将 holopix 中的金色10帧与蓝色6帧特效接入治疗和蒸发事件，F7 可单独预览。

master，战场采用 2.5D 斜俯视投影、纵深建筑、直立精灵与前后遮挡，实际部署面积增加约 57%，保留三角色协防、元素反应、五节点、四次三选一和小队成长。

master，本版使用 Godot 4.4.1，M1—M4 EXE 均保留，M4 源码快照位于 research/m4-source-snapshot。

master，M6 已从 holopix 拆分板生成透明母版和30个独立裁片，并由完整芙宁娜裁片替换原水系辅助，接入待机、移动、攻击、受击和倒地的程序化动画样板。

master，M7 根据拆分板生成约2.5头身的Q版芙宁娜，完成真实透明背景处理，并将战斗显示高度调整为94像素。

master，M8 使用 Q 拆分板的11张独立贴图建立 `Skeleton2D` 与9根 `Bone2D`，并用贴地双层椭圆法阵替换旧攻击范围圆。

master，M8 的散件骨骼拼装经放大视觉审查判定不合格，当前源码和 M9 已停用该显示方案，M8 仅保留为问题记录。

master，M9 改用完整人形母图生成36帧程序化变形动画，但实际观感仍是整图拉伸与旋转，已判定不合格并停止扩展。

master，M10 改用 OpenPose 关键姿势、角色 LoRA、IPAdapter、逐帧抠图与人工放大验收生成真正重绘的动作帧，骨骼只允许处理头发和披风等次级摆动。
