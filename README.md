# 裂隙守望 · Rift Guard

《裂隙守望》是一款多角色路线防守、Roguelike 构筑与分支剧情结合的 2.5D 游戏原型。

## 当前玩法

- 普通模式包含八个关卡，敌人沿多条路线进攻，关卡结束后触发剧情、角色解锁与下一关入口。
- 无尽模式使用四屏地图，敌人从边缘持续追击，角色随旅行者移动并自动攻击。
- 每次升级三选一强化，卡牌可无限叠加并形成弹道、召唤、反应、护盾与支援联动。
- 十二名角色拥有独立主动技能、终结技、能量与冷却，Q/E 支持圆形范围和落点预览。
- 敌人包含近战、远程、飞行、护盾、增益与史莱姆家族，并配置六名三阶段 Boss。
- 火、水、雷、冰、风、岩元素参与反应，旅行者可在局内选择元素并通过高阶卡牌获得双元素。

## V46 UI 实验台与图文手册

V46 把剧情、选模式、选关、选角色、普通战斗、无尽战斗、强化卡和设置八类界面全部纳入 Godot UI 实验台；每页都带实机参考图，可拖动、缩放、替换贴图并安全写回 Profile。

- [图文指导书（PDF，可下载）](output/pdf/Rift-Guard-UI-Visual-Editing-Guide.pdf)
- [图文指导书（Markdown，适合在 GitHub 阅读）](docs/UI-VISUAL-EDITING-GUIDE.md)
- [Godot UI 素材与布局操作手册](docs/UI-GODOT-EDITING-MANUAL.md)

![模式选择](docs/ui-editing-guide/images/mode-annotated.jpg)

![剧情分支](docs/ui-editing-guide/images/dialogue-annotated.jpg)

![战斗界面](docs/ui-editing-guide/images/campaign_battle-annotated.jpg)

## 运行

- Windows 发布包：`builds/rift-guard-v46/RiftGuard-V46.exe`
- Godot 工程：`game/project.godot`
- 设计分辨率：1280×720
- 输出分辨率：1920×1080

## 操作

- WASD：移动当前角色
- 鼠标右键：移动或取消技能瞄准
- 1/2/3：切换角色
- Q：主动技能
- E：终结技
- Space：暂停
- F2：图鉴
- F4：关卡选择
- F6：剧情预览
- F7：特效预览
- F10：设置

## UI 与剧情编辑

### 可以手动调整的界面

UI 实验台目前覆盖八类运行界面：

1. `Dialogue`：剧情立绘、姓名、正文、两个分支选项框和底部操作区。
2. `Mode`：普通模式、无尽模式、存档区和设置入口。
3. `Mission`：关卡标题、八张关卡卡片、缩略图、状态和无尽入口。
4. `Squad`：角色选择面板、角色卡网格、呼吸动画预览和确认按钮。
5. `Campaign Battle`：普通战斗地图可视区、波次、右侧角色栏和 Q/E 技能格。
6. `Endless Battle`：无尽战斗四屏地图视口、角色栏、强化栏和 Q/E 技能格。
7. `Reward`：三选一强化卡、卡牌标签、标题、说明和构筑历史。
8. `Settings`：音量滑杆、全屏、减弱震屏、重置和关闭按钮。

### 在 Godot 中修改布局

1. 使用 Godot 4.4.1 打开 `game/project.godot`。
2. 打开“项目 → 项目设置 → 插件”，确认 **Rift Guard UI Lab** 已启用。
3. 在右侧 **UI 实验台**点击“打开实验台场景”，然后选择要调整的页面。
4. 在 2D 视口拖动红色半透明框修改位置，拖角点修改尺寸；也可以在 Inspector 精确填写 `Position` 和 `Size`。
5. 点击“校验并写回”，再运行对应界面确认效果；点击“刷新 / 撤销未写回”可放弃尚未保存的调整。

工程内部坐标为 1280×720，发布窗口为 1920×1080。将实机截图上的位移除以 1.5 即可换算为 Profile 坐标，例如截图向右移动 30 px，Profile 的 x 增加 20。

### 替换 UI 素材

UI 坐标的唯一数据源是 `game/data/ui_layout_profile.tres`，UI 贴图绑定的唯一数据源是 `game/data/ui_skin_profile.tres`，自定义透明素材放在 `game/assets/ui/custom/`。

将透明 PNG 放入 `game/assets/ui/custom/` 后，可以直接在 `ui_skin_profile.tres` 的 Inspector 中把图片拖到对应 `Texture2D` 字段；也可以在实验台选中 `Skin_字段名`，替换 `Texture` 后点击“校验并写回”。框体素材应保留完整四角和透明边距，需要伸缩的面板优先使用适合九宫格的图片。

Godot 右侧的“UI 实验台”可编辑 Dialogue、Mode、Mission、Squad、Campaign Battle、Endless Battle、Reward、Settings 和 Stage；完整操作见 [UI 手动编辑图文指导书](docs/UI-VISUAL-EDITING-GUIDE.md) 与 [Godot UI 素材与布局操作手册](docs/UI-GODOT-EDITING-MANUAL.md)。

剧情姓名、正文、人物素材、左右/上下位置、缩放与翻转由 `content/game_config.xlsx` 管理。战场地形、地板、前景遮挡和关卡色板使用 `game/data/stage_visual_profile.tres`，攻击特效使用 `game/assets/vfx/`，技能图标使用 `game/assets/ui/icons/`。

## 素材

项目当前混合使用 Helltaker 风格界面资源、用户提供角色素材、Kenney 素材与第三方透明特效素材；各第三方资源的许可证文件保存在对应素材目录。
