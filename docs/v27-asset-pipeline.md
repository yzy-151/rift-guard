# V27 怪物与角色锚点素材流

## 史莱姆替换

源文件放入任意目录并保持以下文件名：

- anemo_slime_sprite_master.png
- electro_slime_sprite_master_jittery.png
- hydro_slime_sprite_master_surprised.png
- pyro_slime_sprite_master_grinning.png
- slime_king_boss_sprite_master.png

执行：

    D:\SOFTWARE\Anaconda\python.exe tools\process_monster_green_screen.py <源目录> game\assets\enemies\slimes

脚本会移除高亮绿色背景、抑制绿边、裁切主体，并输出 512×512 RGBA PNG。统一脚底锚点为 (256, 480)。游戏中的敌人映射、尺寸和原生朝向位于 game/data/v2/enemy_visuals.json，后续只需要替换 sprite 路径或 PNG。

当前透明素材位于 game/assets/enemies/slimes，包含风、雷、水、火史莱姆与史莱姆王。

## 序列帧锚点

执行：

    D:\SOFTWARE\Anaconda\python.exe tools\build_sprite_pivots.py

工具会读取旅行者、芙宁娜和丘丘人的透明序列帧，为每帧计算可见轮廓的底部中心，并生成 game/data/v2/sprite_pivots.json。绘制代码使用该锚点翻转素材，因此正反方向共享同一世界坐标，不会因透明留白不对称而横向偏移。

新增序列帧时应在 tools/build_sprite_pivots.py 的 PROFILES 中登记图集路径、单帧尺寸、列数、帧数和起始行，然后重新生成锚点文件。
