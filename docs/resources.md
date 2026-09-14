# Skills 与素材来源 · 2026-09-05

master，CC 使用 skills.sh 榜单与 npx skills find godot 搜索，并检查候选 GitHub 仓库和技能正文；项目内已安装以下 8 个 skills，未运行上游附带脚本。

| Skill | 用途 | 项目适配 |
|---|---|---|
| game-feel | 命中反馈、缓动、震动、顿帧 | 普攻避免全局顿帧，强反馈按重要性分级 |
| game-ui-ux | HUD、菜单、输入焦点、适配 | 战斗/奖励/对话明确输入所有权 |
| tower-defense | 波次、自动索敌、射程、漏怪 | 静态塔改为有限移动角色，强化替代造塔经济 |
| godot-animation | 关键帧、状态机、Tween | Q 版动作与 UI 动效 |
| godot-ui-control | Control、容器、Theme | 三选一卡片与剧情对话 |
| godot-shaders | 2D shader | 闪白、描边、消散 |
| create-game-assets | 统一美术、素材清单、归一化 | 衔接 ComfyUI 与游戏资源 |
| dialogue-systems | 剧情图、条件、状态 | 首版小型 JSON runner，保留表格创作 |

master，上游为 https://github.com/gamedev-skills/awesome-gamedev-agent-skills ，本次网页显示 832 stars；CLI 搜索显示其中 Godot 动画、UI、shader 各约 2.1K installs，其他所选项的独立安装量没有逐一核实。

master，上游 Apache-2.0 的 LICENSE 和 NOTICE 已保留，下载快照保存在 research/upstream，安装文件哈希保存在 research/skills-hashes.json，尚未记录对应 commit SHA。

master，这些 skills 是开发参考而不是可直接装进引擎的插件，使用时仍需按官方 API 和实际运行验证；其 Godot 4.7 示例与本次选定版本接近，示例不是现成游戏架构。

master，roguelike 候选偏网格回合制，与本作实时防守有差异，所以首版不自动套用其完整设计。

master，另一个候选 https://skills.sh/wshobson/agents/godot-gdscript-patterns 在本次 CLI 查询中约 14.8K installs，可在需要基础 GDScript 模式时继续评审，目前未安装。

## 已下载占位素材

| 资源 | 用途 | 来源与许可 |
|---|---|---|
| Tiny Dungeon | 首版角色、敌人、地形符号 | https://kenney.nl/assets/tiny-dungeon · CC0 |
| Impact Sounds | 命中、碰撞、终结反馈 | https://kenney.nl/assets/impact-sounds · CC0 |
| UI Pack | 卡片面板、按钮、状态条 | https://kenney.nl/assets/ui-pack · CC0 |

master，各包保存原始 ZIP 并解压到 assets/third_party，保留包内许可；Tiny Dungeon 为像素占位库，不作为最终 Q 版美术定稿。

master，Kenney 官方支持页确认素材页资源使用 CC0，https://kenney.nl/support ，后续可同源扩展 UI 与音效以减少混搭。

master，首版背景音乐和中文字体仍需单独选定并核验来源，本轮没有把旧项目的 Helltaker 音乐或未知字体标为可公开使用。
