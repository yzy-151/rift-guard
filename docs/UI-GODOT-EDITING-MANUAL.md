# Rift Guard UI 素材与布局操作手册

master 可以直接在 Godot 中替换 UI 素材和调整位置，工程已经把关键坐标与贴图从脚本中拆成可编辑 Resource。

## 1. 打开工程

1. master 启动 Godot 4.4.1。
2. master 点击“导入”，选择 `C:\Users\23081\Desktop\codex\rift-guard\game\project.godot`。
3. master 双击项目后，按 F6 预览剧情，按 F7 预览战斗特效，按 F4 打开关卡选择。
4. master 的最终窗口是 1920×1080，工程内部布局是 1280×720，坐标按 1.5 倍显示。

## 2. 调整 UI 位置、大小和拉伸

1. master 在左下角 FileSystem 打开 `res://data/ui_layout_profile.tres`。
2. master 在 Inspector 中展开对应分组。
3. master 修改 Rect2：`x/y` 是左上角位置，`w/h` 是宽高。
4. master 按 Ctrl+S 保存，再运行游戏查看结果。
5. master 每次只改一个页面，确认截图后再改下一页。

关键字段：

- master 调模式页用 `Mode Campaign Rect`、`Mode Endless Rect`、`Mode Checkpoint Rect`。
- master 调选关页用 `Mission Grid Origin`、`Mission Card Size`、`Mission Card Gap`、`Mission Endless Rect`。
- master 调剧情页用 `Dialogue Portrait Rect`、`Dialogue Lower Scrim Rect`、`Dialogue Name Rect`、`Dialogue Body Rect`、`Dialogue Choice Rects`。
- master 调战斗页用 `Battle Playfield Rect`、`Battle Status Rect`、`Battle Timeline Rect`、`Battle Right Shell Rect`、`Battle Party Rect`、`Battle Action Rect`、`Battle Skill Rect`、`Battle Ultimate Rect`。

master 若把 1920×1080 截图中的控件向右移动 30 像素，应在 Resource 中把 x 增加 20。

## 3. 替换 UI 图片

1. master 把透明 PNG 拖入 `res://assets/ui/custom/`。
2. master 在 FileSystem 打开 `res://data/ui_skin_profile.tres`。
3. master 把新 PNG 从 FileSystem 拖到 Inspector 对应的 Texture2D 字段。
4. master 可替换 Choice、Mode Card、Mission Card、Hero、Skill、Ultimate 的灰色与红色状态。
5. master 保存后无需修改脚本，下一次运行会自动使用新素材。

master 的透明框体必须保留完整四角，推荐沿用旧素材画布比例；master 若改变比例，应同步调整 `ui_layout_profile.tres` 中对应 Rect2。

## 4. 修改剧情文字、人物与位置

master 在 `C:\Users\23081\Desktop\codex\rift-guard\content\game_config.xlsx` 中编辑剧情内容，游戏会读取姓名、正文、图片名、左右位置、上下位置、缩放和水平翻转。

master 修改 Excel 后要保存并重新启动游戏；master 若看到文件占用提示，应先关闭 Excel 再启动游戏。

master 的剧情分支按钮固定读取两项，红框表示当前焦点，灰框表示另一项；master 可在 `Dialogue Choice Rects` 中分别调整两行的位置和尺寸。

## 5. 在 Godot 中直接拖动运行时控件

master 可以在 Remote 场景树中临时拖动控件检查效果：

1. master 运行项目。
2. master 切回 Godot，Scene 面板切到 `Remote`。
3. master 找到对应 CanvasLayer 下的 Control。
4. master 在 Inspector 修改 Position 或 Size 观察即时变化。
5. master 记录数值后停止运行，把数值写回 `ui_layout_profile.tres`。

master 对 Remote 节点的修改不会在停止运行后自动保存，因此最终数值必须写回 Resource。

## 6. 验收快捷键

- master 按 F6 打开剧情预览。
- master 按 F7 打开战斗特效预览。
- master 按 F10 打开设置。
- master 按 F4 打开关卡选择。
- master 按 Q 进入当前角色战技圆形落点预览。
- master 按 E 进入当前角色终结技圆形落点预览。
- master 在 Q/E 格内可查看冷却秒数或终结技能量百分比。

## 7. 推荐修改流程

master 先替换 `ui_skin_profile.tres` 中的图片，再修改 `ui_layout_profile.tres` 的位置和尺寸，然后修改 Excel 文案与人物参数，最后分别截取模式、选关、剧情、普通战斗、无尽战斗五张图进行对照。


## 8. 调整地图分层与色板

1. master 在 FileSystem 打开 res://data/stage_visual_profile.tres。
2. master 在 Inspector 的 Common Layers 中调整全局遮罩、战场边框、前景墙和余烬颜色。
3. master 在 Stage 01、Stage 02、Stage 03+ 中分别调整 Floor、Tile A、Tile B 与 Accent。
4. master 保存后重新进入关卡，地图会按关卡重新构建缓存，不需要改绘制脚本。
5. master 若要替换背景图，替换 res://assets/helltaker/backgrounds/ 内对应文件并保持原文件名即可。

master 的 UI 框体采用保持比例居中或九宫格绘制；master 替换素材时应保留透明边距与四角装饰，避免把带人物或复杂图案的整张参考图直接当作可拉伸框体。


## 9. UI 实验台：在 Godot 里拖拽并写回

master 打开工程后会在 Godot 右侧看到“UI 实验台”Dock；master 若未看到，可在“项目 → 项目设置 → 插件”中确认 “Rift Guard UI Lab” 已启用。

1. master 点击“打开实验台场景”。
2. master 在页面下拉框选择 Dialogue、Mode、Mission、Squad、Campaign Battle、Endless Battle、Reward、Settings 或 Stage。
3. master 在 2D 画布看到 1280×720 的对应实机截图和带字段名的红色半透明框。
4. master 在右侧字段表点击一项，Godot 会在 Scene 与 Inspector 中选中对应节点。
5. master 使用 2D 工具拖动红框，或拖角点改大小；master 也可以在 Inspector 的 Position 与 Size 中输入精确数值。
6. master 拖动时字段表每 0.25 秒刷新一次，因此 master 能直接确认正在修改的字段名、位置和尺寸。
7. master 点击“校验并写回”，实验台会同时更新 `res://data/ui_layout_profile.tres` 与 `res://data/ui_skin_profile.tres`。
8. master 按 F6、F7 或运行主场景查看游戏实际效果。
9. master 若不想保留未写回的拖动，点击“刷新 / 撤销未写回”即可重新载入磁盘 Profile。

master 的实机参考图已经预先从 1920×1080 缩放为 1280×720，所以 master 在实验台中拖动多少内部像素，写回就是多少内部像素；master 对照外部 1920×1080 截图手算时仍使用 2/3 比例。

master 要替换贴图时，在画布向下滚动到 720 线以下，选中 `Skin_字段名` 的 TextureRect，再把新 PNG 从 FileSystem 拖到 Inspector 的 Texture 属性，随后点击“校验并写回”。

master 点击“打开实验台场景”后会生成 `res://editor/ui_lab/.master_editing.lock`；master 关闭实验台或禁用插件后锁会释放，CC 后续改代码时会先检查该锁，避免覆盖 master 正在编辑的两个 Profile。

master 若在 CC 修改代码期间保持实验台开启，完成后点击“刷新 / 撤销未写回”即可读取 CC 的新字段；实验台按字段前缀自动反射，不需要为新字段改编辑器代码。

完整的八页标注图、字段对照与素材替换表见 [UI 手动编辑图文指导书](UI-VISUAL-EDITING-GUIDE.md)。

## 10. 双方共同更新时的边界

master 负责通过实验台调整 `ui_layout_profile.tres` 和 `ui_skin_profile.tres`，CC 负责运行时脚本、交互逻辑和新增语义字段，双方通过 Profile 协作。

master 的地图地形、路线和刷怪几何继续放在 `res://data/stage_visual_profile.tres`，地图数据不会混入 UI Profile。

master 可直接替换 `res://assets/ui/custom/` 中的图片；master 只要在 Skin Profile 中重新绑定贴图，CC 后续重构运行时代码不会改回旧路径。

master 遇到“Profile 已被外部修改”提示时，先点击“刷新 / 撤销未写回”，再重新拖动；实验台会拒绝静默覆盖新版本。

master 遇到负宽高、字段丢失或临时资源无法重载时，实验台会显示明确错误并保留原文件。
