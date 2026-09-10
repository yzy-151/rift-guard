# Rift Guard / 裂隙守望

master，当前最新可玩版本是 [RiftGuard-V18.exe](builds/rift-guard-v18/RiftGuard-V18.exe)，发布目录仅保留 V18。

master，V18 在两个模式中接入旅行者四套 48 帧动画与怪物 30 帧跑步动画，并重做七系弹道轨迹、元素命中、暴击爆发和无尽地图地表。

master，无尽模式现有裂隙统领、黑曜母巢、苍穹风暴、万仞壁垒、熔核炮台、噬时魔像六个 Boss，每个 Boss 都在 70% 与 35% 生命阈值进入新阶段，并有独立召唤、击退、护盾、炮击、吸血或统御机制。

master，设置、重新开始、调整编队、选择关卡、当前状态、强化等级和三名角色的实时数值已集中到暂停战术中心，主菜单和暂停菜单都可调节总音量、BGM、音效、全屏与低特效。

master，后期升级经验采用陡峭曲线，前期仍能快速成型，后期选卡频率会大幅降低；无尽模式继续支持无限叠卡、双元素旅行者和关卡构筑继承。

master，剧情界面采用 Helltaker 的背景、按钮、边框、立绘入场节奏、左侧双回应布局和文字显隐节奏，回应可提高幸运、解锁隐藏角色，或在通关后把当前角色、元素、卡牌等级与战斗属性继承到无尽模式。

master，战斗角色数据为 12 名、卡牌为 204 张，所有角色立绘、头像与图标均通过 [asset_manifest.json](game/data/v2/asset_manifest.json) 映射，后续可直接替换素材路径。

master，角色动画制作要求见 [V18 角色序列帧交付规范](docs/character-animation-spec-v18.md)，实际抠图与图集合并由 [V18 动画构建工具](tools/build_v18_animation_assets.py) 自动完成。

master，外置 Excel 模板位于 [game_config.xlsx](content/game_config.xlsx)，发布包内也带有 `content/game_config.xlsx`，可编辑对话、立绘、位置、缩放、翻转、UI 尺寸、文字、字号和九宫格边距。

master，完整验收结果见 [V18 验收报告](docs/v18-validation/REPORT.md)，Godot 工程入口是 [project.godot](game/project.godot)，核心玩法数据位于 [game/data/v2](game/data/v2)，剧情分支位于 [story.json](game/data/story.json)。

master，后续版本采用独立 Git 分支，当前发布分支为 `v18`。
