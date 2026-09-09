# Rift Guard / 裂隙守望

master，当前最新可玩版本是 [RiftGuard-V16.exe](builds/rift-guard-v16/RiftGuard-V16.exe)，发布目录仅保留 V16。

master，V16 提供“裂隙守望”关卡模式与“无尽生存”模式，主菜单和暂停菜单都能进入设置或切换模式。

master，剧情界面采用 Helltaker 的背景、按钮、边框、立绘入场节奏、左侧双回应布局和文字显隐节奏，回应可提高幸运、解锁隐藏角色，或在通关后把当前角色、元素、卡牌等级与战斗属性继承到无尽模式。

master，BGM 使用 `Epitomize`、`Vitality`、`Titanium` 三首曲目，设置页支持总音量、背景音乐、音效、全屏与低特效，配置自动保存到用户目录。

master，战斗角色数据扩展到 12 名、卡牌扩展到 204 张，所有角色立绘、头像与图标均通过 [asset_manifest.json](game/data/v2/asset_manifest.json) 映射，后续可直接替换素材路径。

master，无尽模式的岩造物现在按世界坐标准确放置，远程怪会等到强度层级与卡牌构筑同时达到门槛后才加入刷怪池。

master，普通地图路线改为低亮度石质磨痕，动态箭头只在刷怪前出现，传送门随出生点动态生成；无尽地图加入 Helltaker 背景、柔和石砖、符文环与低亮度边界。

master，外置 Excel 模板位于 [game_config.xlsx](content/game_config.xlsx)，发布包内也带有 `content/game_config.xlsx`，可编辑对话、立绘、位置、缩放、翻转、UI 尺寸、文字、字号和九宫格边距。

master，完整验收结果见 [V16 验收报告](docs/v16-validation/REPORT.md)，其中源码 17 项真实点击、发布包 17 项真实点击、18 个脚本测试、V14 兼容 26 项与 V15 兼容 12 项全部通过。

master，Godot 工程入口是 [project.godot](game/project.godot)，核心玩法数据位于 [game/data/v2](game/data/v2)，剧情分支位于 [story.json](game/data/story.json)。

master，后续版本采用独立 Git 分支，当前发布分支为 `v16`。