# Rift Guard V61

V61按指定Helltaker素材重新绑定模式选择、关卡选择、编队与角色档案界面，并统一按钮声音和默认音量。

- 模式卡使用mode_card_gray/red，焦点切换时同步更新外框与button_small操作按钮。
- 远征检查点使用mode_checkpoint，继续入口改用ritCode0001图形，设置入口使用mission_header。
- 关卡卡使用buff_card_gray/red九宫格边框，保留战斗截图，锁定关卡显示锁标志与LOCKED。
- 无尽入口使用mission_endless原始比例，返回入口与上一页保持一致。
- 编队卡使用mode_card_red淡/亮状态，角色动画与档案动画全部保持帧单元宽高比。
- 编队页取消右上返回键和滚轮提示，底部返回与确认分别占据左右半区并使用button0003。
- 角色档案读取真实active_skill/ultimate数据，为十三名角色显示独立效果、威力、范围、冷却与能量。
- 六项属性标题和值使用雷盖体并与条形图垂直居中。
- 所有本轮按钮补齐悬停与确认音效；默认音乐由62%降至46%，默认反馈音效由78%提高至90%。

## 验收

- Godot资源导入与脚本编译通过。
- V61窗口视觉与交互专项13/13通过。
- 验收截图位于docs/v61-validation/。
