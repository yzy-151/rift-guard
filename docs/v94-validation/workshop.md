# V94 工坊顶部操作台

工坊顶部改成与现有黑红平面风格一致的操作轨：左侧斜切标题签与独立战场状态，中央红色暂停 / 继续主键、逐帧与速度，右侧一条恢复 / 清理工具带，末端独立的返回设置键。工具带使用间隔线分组，去除了重复的亮面、倒角按钮盒子。

标题使用工程已有的 `TiejiliSC-Regular.ttf`，数据与操作文字沿用工坊主题的中文正文字体。播放、逐帧和退出使用绘制图形；空格、`.`、Esc 单独显示为键位标记。悬停使用平面红色反馈与底线，工具说明通过 tooltip 显示。

顶部仍占逻辑坐标 `(16, 10, 1248, 48)`，左侧抽屉、底部属性区与地图可操作范围均沿用现有布局。按钮在 `buttons` 字典中的 ID、信号连接和键盘快捷键保持兼容。`workshop_toolbar.gd` 只负责画面与按钮构建，不持有模拟、存档或音频状态。

## 原生截图复核

2026-10-04 已实际查看以下 GPU 直接截图。1280×720 的抽屉展开 / 收起状态与 1920×1080 的运行 / 暂停状态，顶部均没有标签重叠或裁切；主播放键的图形与文字随真实暂停状态切换，逐帧悬停也能识别。

- [1280×720 展开](workshop-expanded-1280.png)
- [1280×720 收起，完整角色阵容](workshop-collapsed-1280.png)
- [1920×1080 运行](workshop-toolbar-running-1920.png)
- [1920×1080 暂停与逐帧悬停](workshop-toolbar-paused-1920.png)

没有对截图做后期尺寸调整。Godot 初始桌面窗口会适配系统工作区；专门 UI QA 在启动后设置请求尺寸，并直接检验每张保存图像的 `Image.get_size()`，确保两种正式证据尺寸准确。

## 回归

| 回归入口 | 运行方式 | 结果 |
|---|---|---|
| `qa_v93_workshop.gd` | Headless | 78 / 78 |
| `qa_v93_workshop.gd` | 原生 1280×720 | 78 / 78 |
| `qa_v94_workshop_toolbar.gd` | Headless | 54 / 54 |
| `qa_v94_workshop_toolbar.gd` | 原生 1280×720 | 56 / 56 |
| `qa_v94_workshop_toolbar.gd` | 原生 1920×1080 | 56 / 56 |

原有 V93 QA 无须改变坐标：它通过真实控件矩形定位鼠标，继续覆盖完整角色 / 敌人目录、Q/E、卡牌、地图、速度、恢复、清除、相机与退出隔离。新增 QA 补足顶部真实鼠标暂停 / 继续、逐帧、重置、退出，以及全部顶部控件的包含关系、互不重叠与战场点击屏蔽；检查暂停帧长和重置后的真实单位 / 时间 / 特效状态。

- [V93 Headless 报告](workshop-headless-report.json)
- [V93 原生报告](workshop-native-1280-report.json)
- [顶部 Headless 报告](workshop-toolbar-headless-report.json)
- [顶部 1280 报告](workshop-toolbar-native-1280-report.json)
- [顶部 1920 报告](workshop-toolbar-native-1920-report.json)

专门 UI QA 命令（1280 验证把 `--qa-size` 改为 `1280x720`；Headless 验证增加 `--headless`）：

```powershell
& 'C:/Users/yzy/Desktop/codex/tools/godot-4.6/Godot_v4.6-stable_win64_console.exe' --path game --resolution 1280x720 --script res://tests/qa_v94_workshop_toolbar.gd -- --qa-size=1920x1080 --qa-output=C:/Users/yzy/Desktop/codex/rift-guard/v94-2026-10-04/workshop/toolbar-native-1920-final
```

以上验证针对当前工程源码；本次工坊工作没有提交、推送或生成发布包。

## 实际动态预览

- [6 秒原生工坊预览 MP4，1920×1080 / 24 fps](workshop-bug-preview.mp4)
- [6 秒 GIF，1280×720 / 24 fps](workshop-bug-preview.gif)
- [真实模拟录制报告](workshop-bug-preview-report.json)

画面由 Godot MovieMaker 原生录制：通过设置入口进入工坊，使用真实按钮与战场点击放置格温、源石虫，再收起工具；两次击杀调用当前模拟的 `apply_hit`，按 1/60 秒固定步长推进完整工坊模拟、音频与特效。两次预警均持续 1 秒，爆炸半径均为 80；格温距爆心约 297，关闭工坊无敌后生命仍保持 960 / 960。尾段包含顶部真实鼠标暂停、逐帧、继续操作。

原生 AVI 只去掉启动进入过程并转码；没有合成、替换动作或叠加假画面。MP4 使用 H.264 / AAC，GIF 使用调色板转码，均为 144 帧、6.000 秒。已通过 ffprobe 核实尺寸 / 帧率 / 时长、ffmpeg 全片解码，并亲自查看最终 MP4 与 GIF 的闪爆帧。
