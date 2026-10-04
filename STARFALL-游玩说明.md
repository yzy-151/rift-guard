# 裂隙守望 · 星夜守望

以 V86 素材为基础的独立附加模式，使用 Godot 4.6。所有原人物、怪物肖像和动作图集仍保留在工程原路径。当前项目默认启动原 V86 主菜单，通过「星夜守望 / 附加模式」进入本模式，通过「返回主菜单」返回 V86。

## 开始游戏

推荐打开 `releases/V86-Enhanced/RiftGuard-V86-Enhanced.exe`，从主菜单进入星夜守望，无需安装 Godot。请把同目录 PCK 一起保留。`releases/Starfall/` 是此前的独立版本留档，不含后续 V86 动效增强。

源工程入口是 `game/project.godot`，默认场景为原 `game/main.tscn`。星夜守望场景为 `game/starfall/main.tscn`；在 Godot 中打开该场景按 F6 可单独运行，F5 启动原主菜单。

## 操作

| 操作 | 按键 |
| --- | --- |
| 移动领队 | WASD，或鼠标右键点击地面 |
| 切换领队 | 1 / 2 / 3，或点击队伍头像 |
| 主动技能 | Q，朝鼠标指向施放；部分技能以自身为中心 |
| 终结技 | E，需要 100 点能量 |
| 闪避 | Shift，优先沿移动方向；站立时朝鼠标方向 |
| 暂停 / 继续 | Esc / Space |
| 全屏 / 窗口 | F11 |

普通攻击自动寻找范围内的敌人。未控制的队友会跟随领队并自动攻击；切换角色可以使用各自独立的主动技能与终结技。角色倒下后会自动选择仍存活的伙伴。全队倒下或月泉耐久归零时，本局结束。

## 模式与构筑

- **星夜远征**：三幕九波，每波约 30 秒，第三、第六、第九波有裂隙统领。首领必须被击败才能推进，普通波次之间会提供少量生命与月泉补给。正常一局约 5 分钟，加上升级选择时间。
- **无尽回响**：沿用波次与首领循环，敌人的数量、强度逐渐增加，记录最高波次。
- **星屑祝福**：击败敌人掉落星屑，靠近后吸收。升级时暂停战斗，从三张祝福中选择一张；每次选择可以重绘一次。23 种祝福包含额外弹体、穿透、吸血、暴击、技能冷却、元素共鸣与修复补给。
- **十位同行者**：旅行者、哥伦比亚、希露菲、芙宁娜、洛琪希、阿米娅、丰川祥子、艾米莉亚、风堇、格温。技能与元素配置针对新玩法重新设计，与 V86 数值不互通。

珊瑚红地面图形是敌方危险预警；计时完成才出手，远程弹体与冲锋均需要实际接触才造成伤害。敌人在蓄力时被击败会打断尚未发出的攻击，冻结也会冻结蓄力和对应预警。已经发射的弹体仍会继续移动。

## 设置与记录

菜单可调节音量、简化特效、镜头震动和全屏。战绩与设置保存在 Godot 用户目录的 `starfall_profile.json`，与 V86 存档分开。当前新版本保存战绩与设置，不支持中途退出后续关。返回营地会结束当前战斗。

## 自己调整工程

新版代码集中在 `game/starfall/`：

- `catalog.gd`：人物、技能说明、敌人数值、祝福数值和数量上限。
- `simulation.gd`：命中、移动、敌人行为、波次、经验和胜负。
- `arena.gd`：镜头、动画图集、危险预警、粒子与地图绘制。选中主场景的 Arena 节点，可在检查器修改缩放与粒子上限。
- `interface.gd`、`glyph.gd`：界面布局、主题与祝福图标。
- `main.gd`：输入、音频、存档、流程协调。
- `assets/moonwell-garden.png`：新绘制的月泉庭院底图。

新版 UI 仍由脚本创建。Godot 中可调整场景导出参数，但菜单布局目前需要编辑 `interface.gd`；没有宣称修好了旧版 UI 实验台。

## 验证与打包

在仓库目录运行（将 `godot` 替换为你的 Godot 路径）：

```powershell
godot --headless --path game --script res://starfall/tests/test_simulation.gd
godot --headless --path game --script res://starfall/tests/test_campaign.gd
godot --headless --path game --script res://starfall/tests/test_interface.gd
godot --headless --path game --script res://starfall/tests/test_controller.gd
godot --headless --path game --script res://starfall/tests/test_arena.gd
```

实际画面、验证范围和测试结果见 [验证记录](docs/starfall-validation/README.md)。发布版可通过 `-- --starfall-qa=campaign` 自动运行正常数值的完整远征检查；这些测试运行不会写入战绩。

运行 `tools/build_v86_enhanced.ps1` 可重建包含星夜守望的完整发布目录。`build_starfall.ps1` 保留为此脚本的兼容入口。需要 Godot 4.6 可执行文件与官方 `windows_release_x86_64.exe` 导出模板，可通过参数传入其他安装路径。

地图底图使用内置 ImageGen 生成；新增祝福图标、粒子和预警由代码绘制。原有角色、怪物、字体与音频的授权及来源沿用原工程记录。本次本地制作没有发布或上传游戏。
