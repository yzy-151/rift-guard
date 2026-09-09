# V16 验收报告

master，V16 的发布候选已完成源码、窗口交互、导出包和兼容性验收。

## 交付物

master，Windows 可执行文件位于 `builds/rift-guard-v16/RiftGuard-V16.exe`，文件大小为 177.55 MiB，SHA-256 为 `3735b707a151536bd4f193f6e4ec6668a130a29510f0a040345a16cb2e6f16f3`。

master，可编辑 Excel 位于 `builds/rift-guard-v16/content/game_config.xlsx`。

## 本版变化

- master，Helltaker 式双回应改为左侧纵向选择栏，并加入错峰滑入、回弹立绘、文字逐字出现和原始 UI 纹理。
- master，加入三首 Helltaker BGM，并提供总音量、音乐、音效、全屏和低特效设置。
- master，通关回应可把队伍、元素、卡牌等级、幸运值和战斗数值带入无尽模式。
- master，修复无尽模式岩造物远距离点击后漂移到左上方的问题。
- master，无尽模式早期不生成远程怪，达到第三强度层级且累计至少 5 级卡牌后才开放远程怪。
- master，角色扩展至 12 名，角色专属卡扩展后总卡牌数为 204 张。
- master，普通路线改为低亮度磨痕，预告箭头与传送门保留动态出现，地图地表和无尽场景完成一轮视觉美化。

## 验收结果

- master，18 个现行脚本测试全部通过。
- master，V16 源码窗口 QA 通过 17/17，覆盖真实鼠标点击、设置滑条、普通模式入口、对话选择、继承无尽、岩造物与早期刷怪池。
- master，V16 导出 EXE 窗口 QA 通过 17/17，并确认 BGM 在发布运行时已加载且播放。
- master，V14 兼容 QA 通过 26/26，V15 兼容 QA 通过 12/12。
- master，关卡平衡模拟通过，第一至第三关均支持至少 5 分钟流程。

## 截图

- master，[设置页](01-settings.png) 展示音量、显示与低特效设置。
- master，[Helltaker 式剧情选择](02-helltaker-dialogue.png) 展示双回应与立绘布局。
- master，[继承后的无尽模式](03-inherited-endless.png) 展示角色和强化等级保留结果。

## 素材替换位置

master，角色资源映射位于 `game/data/v2/asset_manifest.json`，角色数据位于 `game/data/v2/characters.json`，卡牌位于 `game/data/v2/cards.json`。

master，BGM 位于 `game/assets/helltaker/audio`，Helltaker UI 位于 `game/assets/helltaker/ui`，背景位于 `game/assets/helltaker/backgrounds`。