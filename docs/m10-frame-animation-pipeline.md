# M10 芙宁娜逐帧动画生产方案

master，M9 的整图缩放、旋转和形变已经判定为视觉失败，M10 不复用这些动画帧。

master，角色主体采用真正逐帧重绘，骨骼只允许驱动头发、披风、飘带和饰物，不允许驱动整个人体轮廓。

## 本机可用组件

master，基础模型使用 `WAI_NSFW-illustrious-SDXL_v9.safetensors`。

master，角色身份使用 `SDXL_IL/原神/芙宁娜Fenina_FeninaV1.safetensors`，风格使用 `SDXL_IL/style/VanripperIllustriousXL_byKonan.safetensors` 或像素风 LoRA，但同一批动作只允许固定一种风格。

master，姿势控制使用已安装的 `comfyui_controlnet_aux`、`comfyui-advanced-controlnet` 与 OpenPose ControlNet，身份一致性使用 `comfyui_ipadapter_plus`。

master，动作连续性使用 `comfyui-animatediff-evolved`，透明背景使用 `ComfyUI-RMBG` 或 `comfyui-Inspyrenet-Rembg`，最终放大使用 `comfyui_UltimateSDUpscale`。

## 生产顺序

1. master，先绘制或生成同一画布、同一脚底线的关键姿势：待机2张、移动4张、攻击5张、受击2张、倒地4张。
2. master，每张关键姿势通过 OpenPose 固定四肢和重心，通过芙宁娜 LoRA 与 IPAdapter 固定脸、发型和服装。
3. master，仅在相邻关键姿势之间生成1至2张中间帧，禁止对整张角色图做缩放、旋转、倾斜或液化来冒充动作。
4. master，每帧独立执行 RMBG 抠图，再统一脚底锚点、角色高度、画布尺寸和透明边缘。
5. master，水浪、命中特效和角色身体分层导出，避免特效跨帧或污染人物 Alpha。
6. master，最终导出 `idle`、`move`、`attack`、`hurt`、`down` 五个独立序列，并生成逐帧总览与实机 GIF 供人工验收。

## 上线门槛

- master，每帧必须是不同的人体姿势，膝、髋、肩、肘和躯干方向需要产生可读变化。
- master，脸型、发色、帽子、服装纹样、腿部比例与武器在连续帧中不得漂移。
- master，双脚在非跳跃动作中锁定地面，待机脚底抖动不得超过2像素，移动动作不得出现滑步。
- master，透明背景必须是真实 Alpha，禁止棋盘格、黑底、白边和衣服内部孔洞。
- master，每帧必须保留完整头饰与四肢，禁止额外手指、额外武器、断肢和跨格特效。
- master，先检查单帧放大图，再检查12 FPS循环，再放入实机以100%、150%和200%缩放检查。
- master，任何一项失败都退回素材阶段，禁止用代码补偿失败的人体绘制。

## 动作预算

| 状态 | 关键姿势 | 最终帧数 | 播放速度 |
|---|---:|---:|---:|
| 待机 | 2 | 6 | 6 FPS |
| 移动 | 4 | 8 | 10 FPS |
| 攻击 | 16 | 16 | 8 FPS（2秒循环） |
| 受击 | 2 | 4 | 12 FPS |
| 倒地 | 4 | 8 | 10 FPS |

master，芙宁娜首轮目标共42帧，其中攻击固定为16帧、8 FPS和2秒循环，每一帧都由最初的单张 Q 版立绘直接参考生成，不再引用旧8帧动作稿。

## 当前动作设计稿

master，[furina-attack-motion-concept-v3-background-failed.png](../research/m10-animation-concepts/furina-attack-motion-concept-v3-background-failed.png) 已证明独立姿势方向可行，但其背景不是透明 Alpha，因此只作为动作设计稿，禁止接入游戏。
