# JudgeE2 — 7 Day Plan (Phase 1: Detection Only)

## Objective

Build a minimal iOS app that runs YOLO detection on iPhone 11.

Scope for this 7-day cycle:
- Camera input
- YOLO CoreML inference
- Decode + NMS
- Bounding box overlay

Resource:
- python3 virtual environment: /Users/jiansun/Documents/Doctor\ Courses/4455/env1

Out of scope (next 7-day cycle):
- Segmentation (MobileSAM)
- Model quantization
- mlpackage/mlprogram optimization
- Multi-model scheduling
- Performance micro-optimization

Rule:
Correctness first. Optimization later.

---

# Day 1 — Clean iOS Foundation

## Builder
- [x] Create new iOS project (iOS 17 target)
- [x] Verify Simulator runs default template
- [x] Verify iPhone 11 builds and launches
- [x] Confirm Bundle Identifier
- [x] Confirm Signing Team set correctly
- [x] Commit clean baseline

## Debugger
- [x] Confirm no signing errors
- [x] Confirm app launches on Simulator
- [x] Confirm app launches on device

Deliverable:
App runs on iPhone 11 with default UI.

---

# Day 2 — CoreML Model Load

## ML_Vision
- [x] Provide YOLO CoreML model (.mlmodel)
- [x] Provide input name
- [x] Provide output tensor names
- [x] Provide expected output shape
- [x] Confirm minimum iOS requirement

## Builder
- [x] Import .mlmodel into Xcode
- [x] Confirm model class auto-generated
- [x] Write minimal load test
- [x] Print "Model loaded successfully"

## Debugger
- [x] Confirm model loads on device
- [x] Confirm no runtime crash
- [x] Confirm console log visible

Deliverable:
YOLO model loads successfully on iPhone 11.

---

# Day 3 — Single Image Inference

## Builder
- [x] Create dummy 640x640 image input
- [x] Run single inference
- [x] Print output tensor shapes
- [x] Measure inference time

## Debugger
- [x] Confirm output shape matches spec
- [x] Confirm inference time logged
- [x] Confirm no memory spike

Deliverable:
Single-frame inference works on device.

---

# Day 4 — Camera Pipeline

## Builder
- [x] Add AVFoundation preview
- [x] Capture frame buffer
- [x] Convert to 640x640 (letterbox)
- [x] Feed frame into model
- [x] Log per-frame inference time

## Debugger
- [x] Confirm preview stable
- [x] Confirm no main-thread blocking
- [x] Confirm stable inference loop

Deliverable:
Live camera → YOLO inference running.

---

# Day 5 — Decode + NMS

## ML_Vision
- [x] Provide reference decode logic
- [x] Clarify bbox format (xywh or xyxy)
- [x] Clarify confidence + class structure
- [x] Provide recommended thresholds

## Builder
- [x] Implement decode
- [x] Implement confidence filtering
- [x] Implement NMS
- [x] Print detection count per frame

## Debugger
- [x] Confirm boxes appear reasonable
- [x] Confirm no explosion in detection count
- [x] Measure decode time

Deliverable:
Valid bounding boxes computed from model output.

---

# Day 6 — Bounding Box Overlay

## Builder
- [ ] Map detection coordinates to preview layer
- [ ] Handle aspectFill scaling
- [ ] Handle device orientation
- [ ] Draw bounding boxes in real time

## Debugger
- [ ] Confirm boxes align with objects
- [ ] Confirm no flipped or mirrored boxes
- [ ] Confirm overlay stable across rotation

Deliverable:
Real-time bounding box overlay on iPhone 11.

---

# Day 7 — Stabilization & Baseline

## Debugger
- [ ] Measure model load time
- [ ] Measure inference time (mean + p95)
- [ ] Measure FPS
- [ ] Record memory usage

## Architect
- [ ] Review pipeline structure
- [ ] Freeze Phase 1 architecture
- [ ] Define Phase 2 (Segmentation integration plan)

Deliverable:
Stable YOLO detection pipeline.
Performance baseline recorded.
Ready for next 7-day cycle.
