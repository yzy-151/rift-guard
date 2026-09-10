# Rift Guard V18 验收报告

- master，Windows 发布包位于 `builds/rift-guard-v18/RiftGuard-V18.exe`，大小为 200,531,744 字节。
- master，EXE 的 SHA256 为 `6BC73DBC4877395E30C92590BBDC6A0BE2674921B83432E9DB74DCA510BBC1FF`。
- master，`builds` 目录只保留 `rift-guard-v18`，发布包同时包含 `content/game_config.xlsx`。

## 动画与素材

- master，旅行者待机、跑步、攻击、阵亡均为 48 帧透明图集，原始绿幕视频不会进入发布包。
- master，怪物跑步完整保留用户提供的 30 帧，旅行者与常规怪物的画面身高比例约为 1:1.45。
- master，批处理脚本执行连通绿幕抠图、边缘去绿、统一身高、固定脚底锚点、等距采样和图集合并。
- master，普通攻击从第 18 帧的弹道释放点播放恢复段，技能从第 0 帧完整播放，实际播放时长按攻击速度缩放。
- master，轻受击使用当前帧压缩、拉伸、闪白和回弹，倒地播放阵亡动画并停在末帧。

## 战斗表现

- master，每个投射物拥有独立 `visual_id` 与最多 11 个历史位置，弹道会按真实飞行方向绘制渐隐宽轨迹。
- master，无元素、火、水、雷、冰、风、岩各有独立弹体轮廓、颜色、核心高光和尾迹。
- master，命中与暴击加入冲击核、扩散弧、放射碎片、伤害数字和分级镜头震动，命中特效读取实际攻击元素。
- master，无尽地图去除了黑色棋盘缝，改为低对比重叠石板、裂纹、环形符文、脉冲微光和柔和暗角。

## 验证结果

- master，V18 动画与弹道专测 15/15 通过。
- master，V18 场景集成与视觉 QA 6/6 通过。
- master，模式菜单、真实指针进入无尽、暂停、设置、编队、关卡和 Boss UI 回归 15/15 通过。
- master，现行玩法测试 20 个脚本全部通过，其中包含 Boss 31 项、旅行者元素技能 15 项、三关平衡模拟、卡池、剧情、图鉴、路线与 Excel 配置。
- master，导出的 V18 EXE 再次执行 V18 QA 6/6 与点击回归 15/15，两个进程退出码均为 0。
- master，`export_notices.gd` 是要求输出路径参数的打包工具，未计入测试脚本；早期 `test_combat.gd` 仍按已废弃的 V1 规则断言，未纳入 V2 回归基线。

## 视觉证据

- master，[旅行者、怪物、五类弹道与命中效果](01-traveler-monster-projectile-vfx.png)。
- master，[无尽地图、旅行者与十二只动画怪物](02-endless-arena-animation-density.png)。
- master，逐动作 GIF 位于 `review/v18-assets/traveler-idle.gif`、`traveler-run.gif`、`traveler-attack.gif`、`traveler-death.gif` 与 `hilichurl-run.gif`。
