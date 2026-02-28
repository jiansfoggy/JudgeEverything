# Architect Output — Day 7

Project: JudgeE2 (Phase 1: Detection Only)
Target: iPhone 11
Date: 2026-02-28

## 1) Phase 1 Pipeline Structure Review（检测-only）
**Pipeline（实时检测）**
CameraCapture → Preprocess（orientation/mirror + letterbox 640×640） → YOLO CoreML → Decode + NMS → Overlay（bbox）

**关键结构确认**
- **Canonical 坐标**：统一使用 camera buffer px（Wc×Hc）作为逻辑坐标；所有几何变换显式记录并可逆。
- **FrameGeometry/LetterboxTransform**：每帧必须携带 Wc/Hc、orientation、mirroring、r/px/py 等元数据，保证 overlay 对齐。
- **线程/队列**：capture/preview 不阻塞；detector latest-frame-only；decode/NMS 与推理解耦并允许丢帧。
- **渲染**：overlay 仅做 Canonical→preview 映射（aspectFill 需处理裁剪偏移）。
- **性能指标**：必须可测量 model load time / inference mean+p95 / FPS / memory，作为 Phase 1 基线。

结论：Phase 1 结构完整且最小闭环，满足“正确性优先”的目标。

## 2) Phase 1 Architecture Freeze（冻结）
**冻结内容（不再改动的 v1 基线）**
1. **数据流**：Camera → Preprocess → YOLO → Decode/NMS → Overlay（bbox-only）。
2. **坐标契约**：Canonical = camera px；所有变换显式化（orientation/mirror + letterbox）。
3. **调度策略**：latest-frame-only + drop-if-busy；detector 与 decode 可分离。
4. **输出范围**：仅 bbox + class + score；不引入分割、跟踪或 UI 交互。

**允许变动（Phase 1 内仍可调）**
- 阈值/TopK/NMS 参数；
- computeUnits 选择；
- 可视化样式（不影响几何契约）。

## 3) Phase 2: Segmentation Integration Plan（MobileSAM）
**目标**：在不破坏 Phase 1 的几何/调度契约前提下，引入分割与缓存策略。

**3.1 模块新增**
- PromptBuilder（从 bbox 生成 prompts）
- SAM Encoder/Decoder（优先 split，允许 monolithic 作为备选）
- TemporalManager（主目标选择、缓存、TTL）
- Mask Renderer（mask 叠加）

**3.2 运行策略（默认值，后续可调）**
- **Encoder cadence**：每 12 帧（~2.5Hz@30fps），或主目标变化/geometry 变化触发。
- **Decoder cadence**：每 6 帧（~5Hz@30fps），或 bbox 变化显著触发。
- **缓存**：embedding TTL 1200ms；mask TTL 800ms；过期或 bbox drift 触发重算。

**3.3 约束与退路**
- 与 Phase 1 共享 Canonical/FrameGeometry/LetterboxTransform（不可重复定义）。
- 若 SAM 忙/超时：退回 bbox-only；旧 mask 在 TTL 内可显示。
- computeUnits 先求稳（CPU/GPU），待 AB 验证后再切 ANE。

**3.4 验收标准（Phase 2 启动前）**
- Mask 与 bbox 对齐（同一几何链路）。
- 交互帧率可用（bbox > 15fps；mask 刷新 2–5Hz）。
- 主要线程不卡顿，preview 连续。

---
结论：Phase 1 架构已冻结；Phase 2 的分割集成路径与调度策略已定义，可在下一周期按此实施。
