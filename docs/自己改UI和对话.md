# 自己修改 UI、对话和立绘

master，Excel 模板、运行时读取、图片变换、UI 绑定与预览均已完成；修改 `builds/m5/content/game_config.xlsx` 后，保存并关闭 Excel，再重新启动 M5 即可生效。

## 配置位置与加载时机
master，发行包从 EXE 同级 `content/game_config.xlsx` 加载配置，Godot 编辑器运行则读取项目根目录 `content/game_config.xlsx`，保存并关闭 Excel 后重启游戏应用修改。
master，当前不做热更新，不需要安装 Python，不需要手动导出 JSON，也不会执行 Excel 宏或公式。
master，保留第4行表头，从第5行开始填写；模板已经提供500行对白、100行图片资源和150行UI配置位置。

## 对话表
| 列 | 填写内容 |
| --- | --- |
| A 启用 | 1启用，0跳过 |
| B 段落 | opening / node1 / node2 / node3 / node4 / won / lost；自定义段落供F6预览 |
| C 顺序 | 同一段内递增整数，不重复 |
| D 姓名 | 显示在对话框的角色名 |
| E 对白 | 建议一句分一行，长段落拆成多行 |
| F 主图 | 图片资源表中的资源名 |
| G 主侧 | left / right |
| H、I 主X、主Y | 显示框左上角；填X时优先X，X留空才按主侧选择默认左右位置 |
| J 主缩放 | 1原始显示框，0.8缩小，1.2放大 |
| K 主翻转 | 0正常，1左右翻转 |
| L 配图 | 配角图片资源名，空白隐藏 |
| M—Q 配侧/配X/配Y/配缩放/配翻转 | 与主角规则相同 |
| R 高亮 | main主角、partner配角、none两者均不压暗 |

master，坐标基准固定1280×720，左上角为0,0，X变大向右，Y变大向下，实际窗口1600×900会自动等比显示。
master，主图缩放1的框为520×665，配图为490×650，图片按比例放进框中，修改缩放不会强行拉扁立绘。
master，例如主图向右移40，在主X上加40；向上移20，在主Y上减20；改站右侧可清空主X并把主侧改成right。
master，内置段落进入战斗流程，自定义段落可用F6选择预览，但不会自动变成新的战斗节点。

## 图片资源表
master，把新PNG放入content/images，资源名可以自己取，例如jessica_smile，文件填images/jessica_smile.png，然后在对话表“主图”或“配图”引用这个资源名。
master，内置素材以res://assets/开头，不需要拷贝到images；想替换时将对应资源的文件改成你的images路径，避免覆盖原图。
master，透明PNG最合适，白色或棋盘格如果已经画进RGB图片，并不会自动变成透明。
master，素材名不能重复，缺图、错误路径、非法数值或表头被改动时整份Excel不应用，游戏显示首个错误并在用户数据目录config-errors.txt记录明细。

## UI 表
master，UI表采用稳定控件ID，包括dialog_background、dialog_frame、dialog_name、dialog_body、dialog_continue、dialog_auto、dialog_history、dialog_skip、game_title、game_subtitle、pause_button、restart_button、hero_card_1至3、menu_background、menu_frame、reward_title、reward_card_1至3。
master，X/Y改位置，宽/高改控件尺寸，素材列引用图片资源名，文字列改静态标题或按钮文案，字号为0时沿用默认。
master，姓名和对白由对话表驱动，基地生命、暂停状态等动态文字由程序生成，不应在UI表内当固定文案填写。
master，角色卡和奖励卡的子文字跟随卡片移动，宽高变化不会自动重排所有内部文字，改小后需要预览检查。
master，menu_frame的X/Y相对菜单容器，其余所列控件使用各自父容器坐标，初始值已经作为示例提供。
master，ninepatch适合有花纹边框的对话框，只拉伸中间区域，边距左/上/右/下以原图片像素填写；stretch整图拉伸，可能让装饰变形。
master，keep会等比缩放素材并居中，stretch会填满控件，ninepatch会按四项边距保护装饰边框；对话框优先使用ninepatch。
master，替换对话背景时先把图片放入content/images，在图片资源表登记资源名，再把资源名填到UI表dialog_background的素材列；默认位置为X=0、Y=82、宽=1280、高=356、模式=stretch。
master，替换开始、暂停和结算背景时使用menu_background，默认位置为X=0、Y=0、宽=1280、高=720、模式=stretch。
master，当前UI由脚本动态生成，在Godot场景编辑器中不能像手工摆好的Control节点那样直接拖拽，日常修改优先使用完成后的配置表。
master，如果暂时直接改代码，对话布局在game/scripts/dialogue_panel.gd，战斗HUD在battle_hud.gd，三选一在reward_panel.gd，修改后用Godot运行预览，再重新导出EXE。

## 预览
master，F6打开段落列表，选择后播放，预览不改变本局已读记录与战斗进度；Esc离开预览列表。
master，F7在开场或暂停状态展示两种序列特效，特效播放后恢复菜单，战斗过程中仍按实际治疗和元素反应触发。
