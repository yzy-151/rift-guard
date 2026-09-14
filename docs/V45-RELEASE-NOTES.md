# Rift Guard V45

master 的 V45 新增 Godot 编辑器内“UI 实验台”，可在五个页面的实机参考图上直接拖动、缩放并替换贴图。

master 可通过右侧 Dock 选择 Dialogue、Mode、Mission、Battle 或 Stage，字段表会实时显示名称、位置和尺寸并联动 Inspector。

master 的布局与贴图统一由 game/data/ui_layout_profile.tres 和 game/data/ui_skin_profile.tres 驱动，模式页、选关页、剧情页和战斗 HUD 已接入这些语义字段。

master 的写回流程包含负尺寸校验、字段校验、磁盘哈希冲突检查、临时资源重载和失败恢复。

master 与 CC 的并行编辑由 game/editor/ui_lab/.master_editing.lock 协调，规则记录在项目根目录 AGENTS.md。

master 的编辑器工具只在 Godot 工程中使用，发布包会排除 editor/ 与 addons/rift_ui_lab/。
