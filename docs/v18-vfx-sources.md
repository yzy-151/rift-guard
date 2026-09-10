# V18 动画与特效实现来源

- 荧的 `idle/run/attack/death` 绿色背景视频来自本机 `C:\Users\23081\Desktop\游戏素材\荧`，由 `tools/build_v18_animation_assets.py` 连通区域抠绿、固定身高与脚底锚点后生成四张 48 帧透明图集。
- 丘丘人跑步动画来自本机 `C:\Users\23081\Desktop\游戏素材\生成帧`，30 张透明 PNG 全部保留并合并为一张图集。
- 弹道尾迹的分段渐隐方法参考 CC0 项目 [Godot Advanced Trails Examples](https://github.com/RPicster/Godot-Advanced-Trails-Examples)。
- 冲击停顿、镜头震动、缩放回弹和闪白的组合原则参考 MIT 项目 [Saltmire Juice](https://github.com/saltmire/saltmire-juice)。
- 程序化放射碎片的形态参考 MIT 项目 [Saltmire Spark](https://github.com/saltmire/saltmire-spark)。
- V18 当前实现直接写入 `battle_view.gd` 的 CanvasItem 绘制层，没有复制上述仓库代码或打包其插件，因此不会引入额外运行依赖。

后续替换素材时，只需保持 `animation.json` 中的格子尺寸、列数、帧数和 `release_frame` 字段，即可继续使用现有状态机、攻速同步与弹道释放逻辑。
