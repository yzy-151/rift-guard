# V91 Implementation Plan

**Goal:** 完成用户九项修改，交付保留 V86 核心玩法的更清晰战场、完整角色音画、可探索家园和多样无尽。

**Architecture:** 在原事件流和数据系统上分工修改：模拟、战斗绘制/HUD、音频、家园四组；主流程由根代理统一接入。子代理只修改各自负责文件，交接使用事件契约。

**Tech Stack:** Godot 4.6 / GDScript / PowerShell / FFmpeg；本地分支继续承接已授权的未提交改动。

- [x] 战斗模拟：复现路线偏离，修正路线追踪与特殊移动回归；升级角色技能机制，保留卡牌兼容；增加三种无尽场景、轮换任务与阶段成长。文件 `combat_simulation.gd`、`hero_signature_skills.gd`、`enemy_tactics.gd`、`classic_endless_objectives.gd`、相关数据；测试实际路线采样、每角色技能效果、无尽目标完成与阶段上限。
- [x] 战斗表现：缩小原图集的绘制比例和锚点，整理紧凑上下 HUD，给地图更多空间；新增/重做支援卡与三个 Boss 特效，保持真实预警。文件 `battle_view.gd`、`battle_hud.gd`、`flat_stage_art.gd`、`stage_projection.gd`、VFX 辅助类；测试显示边界、投影与真实范围。
- [x] 音频：盘点原角色声音，联网下载成熟 SFX 与对应日语语音，制作有层次的音效与音量/并发管理；提供音频事件路由组件和角色/Boss清单。由根代理接入 `main.gd`，音频代理负责新资源、音频类与来源说明。测试资源存在、事件路由、降噪/并发、导出播放。
- [x] 家园：添加三个区域的数据与绘制、出口切换、区域角色和专属剧情、探索持久化。文件 `home_panel.gd`、新 `home_regions.gd` / `home_region_art.gd`、`home_stories.json` 和 `main.gd` 对话接入；测试往返、剧情选择后恢复、解锁边界与存档恢复。
- [x] 整合并独立审查，执行新回归与原卡牌/觉醒/剧情回归；修复实际窗口显示、导出资源与声音问题。
- [x] 录制特殊怪物、Boss 与无尽 GIF 和带声音的实机视频；更新角色技能说明、素材来源、验证记录，打包新 Windows 版本。
