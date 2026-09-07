# Helltaker 本地演出参考流程

## 下载

- Steam 官方版：https://store.steampowered.com/app/1289310/Helltaker/
- 作者 itch.io 免 DRM 版：https://vanripper.itch.io/helltaker

## 本地分析

1. 安装或解压官方游戏。
2. 从 https://github.com/AssetRipper/AssetRipper/releases 下载 Windows x64 稳定版。
3. 在 AssetRipper 中选择 Helltaker 游戏根目录，导出到 `research/helltaker-reference/exported`。
4. 运行 `tools/catalog_helltaker_reference.ps1 -ExportedPath <导出目录>`。
5. CC 读取生成的 `research/helltaker-reference/catalog.csv`，分析立绘尺寸、动画帧、UI 切换和音效节奏。

`research/helltaker-reference/` 已被 Git 忽略，也不会进入 Godot 导出。参考素材只用于本地分析；发布版使用原创或许可明确的替代素材。

## 当前解包结果

- 官方压缩包：`research/helltaker-reference/helltaker-official-windows.zip`
- 游戏目录：`research/helltaker-reference/game`
- AssetRipper：`research/tools/assetripper-2.0.0/AssetRipper.GUI.Free.exe`
- 主要资源：`research/helltaker-reference/exported-primary/Assets`
- 自动索引：`research/helltaker-reference/catalog.csv`
- 本次共导出 12,412 个文件，包含 1,037 张 PNG、110 个 WAV、9 个 OGG 和 3 个字体文件。
- 对话背景原始画布主要为 1960×544，项目按等比例映射为 1280×356 的可替换舞台。
