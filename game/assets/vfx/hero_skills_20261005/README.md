# 沙龙召唤物

master，本目录使用内置 image_gen.imagegen 生成，先生成三格透明横排，再用同一工具定向改成平涂粗线和较宽留白，最终 PNG 原样复制，未用脚本改图。

master，最终文件为 `furina_salon_familiars_v2.png`，实际 2172×724 RGBA，三等宽 724px 格，透明像素比例 64.7%，背景是真 alpha。

master，左至右为章鱼 Gentilhomme Usher、海马 Surintendante Chevalmarin、螃蟹 Mademoiselle Crabaletta，`furina_salon_familiars_v2.regions.json` 保存基于 alpha 检查得到的主体区域。

master，`furina_salon_familiars_v2.source.json` 保留两次完整 prompt、生成模式和原始输出位置，项目只依赖本目录副本。

master，游戏内以 53 / 58 / 52px 高度显示，并根据真实弹体方向转身，按真实发射年龄回弹，持续轻漂浮。
