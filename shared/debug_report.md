# Debug Report — Day 4 (Debugger)

日期：2026-02-26

## 结论摘要
- ✅ 代码层面：相机采集与推理均在 `videoQueue` 上执行，**没有明显主线程阻塞**。
- ⚠️ 预览是否稳定、推理循环是否稳定，需要真机/模拟器实际观察确认。
- ⚠️ 性能风险：单帧推理约 222.63 ms（Day 3 结果），实时管线可能只有 ~4–5 FPS，加上 letterbox/CI 渲染开销，可能进一步下降。

---

## 1) 编译/构建问题（Compile/Build Issues）
- 未发现新增编译/签名问题（Day 4 新增 AVFoundation/CI 代码）。

## 2) 运行时错误（Runtime Errors）
- 代码路径：
  - 采集回调 `captureOutput` 在 `videoQueue`，并用 `isProcessing` 防止重入。
  - 每帧执行 letterbox + CoreML 推理，打印 `Frame inference time`。
- 需要现场确认：
  - 预览画面是否稳定（无卡顿/黑屏）。
  - 推理循环是否稳定运行（日志持续输出，未崩溃）。

## 3) 性能瓶颈（Performance Bottlenecks）
- **主要瓶颈**：模型推理本身（单帧 ~222.63 ms）。
- **次要瓶颈**：每帧 `CIContext.render` + 新建 CVPixelBuffer，可能增加 CPU/GPU 负载。
- `alwaysDiscardsLateVideoFrames = true` 可以避免堆积，但会牺牲帧率。

---

## 备注 / 需要人工确认
为完成 Day 4 Debugger 三项确认，请在真机或 Xcode 运行时确认：
1) 预览稳定（无明显卡顿/黑屏/花屏）。
2) 主线程无明显阻塞（UI 操作流畅）。
3) 推理循环稳定运行（Frame inference time 持续输出）。

> 未在 tasks.md 勾选任何项（按要求）。

---

# Debug Report — Day 5 (Debugger)

日期：2026-02-28

## 结论摘要
- ✅ 框显示位置已恢复精准（offset 已修正）
- ✅ 检测数量未爆炸（topK=10 + NMS 后稳定）
- ✅ 解码与推理时间已记录（推理约 176–447ms，输出稳定）

---

## 1) 编译/构建问题（Compile/Build Issues）
- 未发现导致构建失败的错误。
- 已避开 `videoOrientation` 相关 deprecation（使用 `videoRotationAngle`）。

## 2) 运行时错误（Runtime Errors）
- 运行日志显示输出稳定：
  - `raw_in_boxes: 8400`
  - `topK: 10`
  - `final_detections: 1–4`
- 仅见系统级 `XPC connection interrupted`，不影响推理与绘制。

## 3) 性能瓶颈（Performance Bottlenecks）
- 单帧推理时间约 176–447 ms（波动较大，偶有高峰）。
- 主要瓶颈仍为模型推理 + 解码；NMS/topK 有助于稳定数量。

---

## Evidence
- 运行日志（2026-02-28）：
  - `Frame inference time: 176–447 ms`
  - `final_detections: 1–4`

> 未在 tasks.md 勾选任何项（按要求）。

---

# Debug Report — Day 6 (Debugger)

日期：2026-02-28

## 结论摘要
- ✅ 竖屏下框与物体对齐（当前版本已恢复精准）
- ✅ 横屏/倒置稳定性已确认（旋转后 bbox 检测正常）
- ✅ 前置摄像头 bbox 已确认（切换前后均对齐）

---

## 1) 编译/构建问题（Compile/Build Issues）
- 未发现新的编译错误。
- iOS 17 deprecation 已通过 `videoRotationAngle` 规避。

## 2) 运行时错误（Runtime Errors）
- 当前未见崩溃或 fatal error；仅有系统级 XPC/Camera 警告可忽略。

## 3) 性能瓶颈（Performance Bottlenecks）
- 主要瓶颈仍是模型推理 + decode；overlay 绘制开销低。

> 未在 tasks.md 勾选任何项（按要求）。

---

# Debug Report — Day 7 (Debugger)

日期：2026-02-28

## 结论摘要
- ✅ 推理时间已记录（多数 170–190 ms，偶发高峰 ~508 ms）
- ✅ FPS 已记录（约 0.5–3.3 FPS，稳定区间 ~3.1 FPS）
- ✅ 内存已记录（约 75–180 MB，稳定在 ~177 MB）
- ✅ 模型加载时间已记录（Model loaded in 9842.05 ms）
- ✅ 推理时间统计（mean + p95）已记录：
  - mean=177.26 ms | p95=182.75 ms
  - mean=182.09 ms | p95=190.96 ms

---

## 1) 编译/构建问题（Compile/Build Issues）
- 未发现新的编译/构建错误。

## 2) 运行时错误（Runtime Errors）
- 日志无崩溃；仅见 XPC 相关系统提示（不影响运行）。

## 3) 性能瓶颈（Performance Bottlenecks）
- 推理时间分布（样本）：
  - 常态区间：约 170–190 ms
  - 偶发峰值：约 508 ms
- FPS（样本）：
  - 0.52, 2.83, 3.17, 3.22, 3.20, 3.23, 3.18, 3.22, 3.14, 3.09, 3.11, 3.12, 3.14
  - 稳定区间 ~3.1 FPS
- 内存（样本）：
  - 75.0 MB（初始）
  - ~177.3 MB（稳定值）

---

## Evidence
- 运行日志（2026-02-28）：
  - `FPS: 0.52–3.26`
  - `Memory: 75.0–177.3 MB`
  - `Frame inference time: 170–190 ms (主流)`
  - `Frame inference time: 508.56 ms (峰值)`
- `Model loaded in 9842.05 ms`
- `Inference time stats (n=100): mean=177.26 ms | p95=182.75 ms`
- `Inference time stats (n=100): mean=182.09 ms | p95=190.96 ms`

> 未在 tasks.md 勾选任何项（按要求）。
