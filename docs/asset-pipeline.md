# 素材流水线与旧项目复用

master，CC 已只读检查修正后的目录，原项目与原始素材没有被修改。

## 本地证据

| 来源 | 发现 | 使用方式 |
|---|---|---|
| G:\software\unity\unity_file\My project | Unity 2022.3.5f1c1、URP 14.0.11、TMP、Timeline、DOTween | 参考视觉小说交互；不整体搬迁 Unity 场景 |
| Assets/Scripts | 14 个项目脚本，包括 VNManager、ExcelReader、SaveLoadManager、HistoryManager、TypewriterEffect | 提取数据字段和行为，Godot 中重新实现 |
| Assets 全目录 | 112 PNG、14 MP3、8 XLSX、12 TTF、6 PSD | 包含第三方内容，不等于全部可以发布 |
| D:\SDnew\ComfyUI-aki-v1.7\ComfyUI\output\ComfyUI_Alpha | 2934 个文件 | 先建索引、缩略图与人工筛选；不全量复制到游戏 |
| 首三张 Alpha PNG | 1680×2480、8-bit、RGBA | 仅验证文件头，尚未逐像素确认透明度和抠图质量 |

master，图片查看工具遇到沙箱初始化错误，因此本轮不作“已经看过立绘效果”的结论。

## 已有工作流

master，已读取并复制 user/default/workflows/把妹王ILV3.4+手部修复抠图绿幕.json，其节点中记录以下配置。

- Checkpoint：WAI_NSFW-illustrious-SDXL_v9.safetensors
- 风格 LoRA：SDXL_IL/style/VanripperIllustriousXL_byKonan.safetensors，权重约 0.8
- 角色 LoRA：SDXL_IL/Arknights/明日方舟il-极光_1.0.safetensors，权重约 0.8
- 超分：RealESRGAN_x4plus_anime_6B.pth
- 采样：KSampler //Inspire
- 修复：FaceDetailer、UltralyticsDetectorProvider、SAMLoader
- 抠图候选：InspyrenetRembg、BiRefNetUltraV2、ImageRemoveBackground+
- 输出：SaveImageWithAlpha，另有多路预览和 SaveImage

master，这些是工作流文件的引用，模型是否完整存在、各抠图分支是否启用、节点能否执行尚未运行验证，不能把节点出现等同于整条生产链已跑通。

## 推荐生产链

master，制作两条独立分支，共享角色设定与来源记录，避免对话立绘和战斗小人互相拉扯参数。

### A：对话立绘

master，流程为“角色设定卡 → IL checkpoint → 角色 LoRA → 风格 LoRA → 固定构图与采样 → 局部修复 → 动漫超分 → 一路经过测试的抠图 → 尺寸/锚点归一 → 表情预览 → 入库”。

- 每角色先完成 1 张主立绘，再用参考图和局部重绘制作平静、开心、生气、受伤 4 表情
- 锁定镜头、头身比、服装、轮廓与光照；单靠相同 seed 不能保证表情变体身份一致
- 对话输出目标画布 1024×1536 RGBA，保留原分辨率母版
- 表情变体必须相同画布和锚点，切换不能人物跳动
- 黑、白、深灰、棋盘格四种背景检查发丝、武器孔隙、半透明边缘和绿幕残留
- 超分置于抠图之前；像素精灵不沿用动漫超分链

### B：战斗 Q 版与动作

master，首选 Q 版 2D 分层骨骼，AI 生成姿态明确的角色母图和部件参考，人工/工具补齐遮挡区域，Godot 编排动作。

- 母版：512×512；运行显示约 96—144 像素高，最终按战场可读性调整
- 朝向：主要面朝右；非对称武器和服饰不能无条件镜像
- 拆层：头、躯干、前后上臂/前臂、前后腿、武器、头发、配件
- 锚点：脚底中心，所有动作共用原点；碰撞体和攻击范围独立于图片边框
- 动作：idle 1.0s、move 0.6s、attack 0.5s、hit 0.15s、skill 0.8s、down 0.6s
- 攻击动作标明出手事件和命中时刻；运行时攻速变化需要同步动作速度
- 首角色全流程通过之后，再扩到其他角色

master，生成式视频可以提供动作草稿或 B站展示镜头，但连续帧的服饰、武器和轮廓可能漂移，不能直接作为稳定攻击动画的默认生产方案。

master，如果后续坚持真像素风，应切换统一 64/96 像素网格、固定调色板和逐帧修图，使用 AnimatedSprite2D，不能把高分辨率 AI 图缩小就视作合格像素动画。

来源：https://docs.godotengine.org/en/stable/tutorials/animation/2d_skeletons.html

## 自动化工作流设计

master，未来由本地批处理工具连接 ComfyUI，游戏运行时只读取完成的素材，不依赖生成服务和显卡推理环境。

1. 输入角色表：角色 ID、提示词、模型引用、表情、姿势、seed、输出规格
2. 预检：模型文件与哈希、节点类型、磁盘空间、服务可用性
3. 提交：使用从现有前端导出的 API 格式，通过本地 /prompt 入队
4. 跟踪：WebSocket /ws 监听进度，/history 查询输出；失败记录后可重试
5. 归档：原图、UI 工作流、API 工作流、seed、模型哈希、节点版本和参数共同保存
6. 检查：解码、尺寸、Alpha、裁边、空白占比、同角色脚底锚点一致
7. 人工评审：角色身份、手部、服饰、武器和实际游戏比例下的识别度
8. 导入：只将通过的版本复制到运行资源目录，生成角色素材映射
9. 回滚：使用内容哈希与版本目录，避免同名覆盖已入库结果

master，本轮保存的是原 UI 工作流副本，尚未导出 API 工作流或实现上述自动化，后续应保留已经验证过的节点连接，不能凭 widget 顺序猜测 API 图。

master，建议清理生产副本中的拼图和无关预览分支，再通过实际小批次测试选定一种抠图器，记录最小依赖和显存峰值。

来源：https://docs.comfy.org/development/comfyui-server/comms_routes 、https://github.com/Comfy-Org/ComfyUI/blob/master/script_examples/websockets_api_example_ws_images.py

## 旧剧情迁移

master，ExcelReader.cs 已确认存在说话人、正文、头像、语音、背景图、BGM、两个角色动作/坐标/立绘，以及若干上一状态字段。

master，下一阶段保留 master 熟悉的 Excel 编写方式，由导入器转成含 line_id、speaker、text、portrait、emotion、audio、background、choices 和 next 的 JSON，并通过映射处理旧坐标和动作含义。

master，旧文件存在编码显示差异，迁移前要识别真实编码并校验中文；分支、空单元格继承和旧存档不能未经验证直接复用。

## 素材清单字段

master，每个入库资源需记录 asset_id、character_id、用途、原路径、输出路径、尺寸、pivot、来源 URL、许可、作者、生成模型/LoRA、工作流 hash、seed、修改历史和发布状态。

master，训练模型文件、大批未选原图、旧游戏原声和未确认字体不进入首版公开仓库，公开素材表只列已确认可发布的实际资源。
