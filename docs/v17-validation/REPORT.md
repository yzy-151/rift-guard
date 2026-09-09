# Rift Guard V17 验收报告

- master，V17 Windows 发布包位于 `builds/rift-guard-v17/RiftGuard-V17.exe`，大小为 186,190,576 字节。
- master，发布包 SHA-256 为 `DDC2594E4EDF2137398C58D1C06B8EA060599F3B3526564974602F20DAB25EE7`。
- master，发布目录只保留 `rift-guard-v17`，并带有可编辑的 `content/game_config.xlsx`。

## 功能结果

- master，普通三关敌人生命与伤害已提高，固定种子自动构筑分别以基地 42、17、100 通关。
- master，三关用时约为 396.63、367.27、746.57 秒，每关触发 10、10、12 次选卡。
- master，无尽初期每次至少生成 2 个敌人，后期单批可生成 6–10 个敌人，刷新间隔最低为 0.22 秒。
- master，无尽 Boss 从 90 秒开始，每 105 秒轮换一次，六种 Boss 均有 70% 与 35% 两次阶段变化。
- master，暂停页集中显示模式、关卡、时间、击杀、在场敌人、等级、幸运、强化等级和三名角色数值。
- master，暂停页集中提供设置、重新开始、调整编队、选择关卡、返回主菜单和继续防守入口。
- master，进入模式后立即刷新 HUD，修复了首帧暂停按钮仍处于禁用状态的问题。

## 验证结果

- master，Godot 4.4.1 全工程 headless 编译通过。
- master，19 个脚本回归测试全部通过。
- master，V17 六 Boss 与难度专用测试 31/31 通过。
- master，V17 headless UI 连接测试 15/15 通过。
- master，V17 源码真实窗口鼠标点击测试 15/15 通过。
- master，V17 导出 EXE 的完整窗口 QA 进程退出码为 0。
- master，暂停中心截图为 [01-pause-hub.png](01-pause-hub.png)，三阶段 Boss 截图为 [02-endless-boss-phase3.png](02-endless-boss-phase3.png)。

## 动画交付

master，角色动作、帧数、锚点、攻击释放帧、弹丸插槽和攻速同步标准见 [角色序列帧交付规范](../character-animation-spec-v17.md)。
