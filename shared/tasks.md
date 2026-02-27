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
- [ ] Confirm no signing errors
- [ ] Confirm app launches on Simulator
- [ ] Confirm app launches on device

Deliverable:
App runs on iPhone 11 with default UI.

---

# Day 2 — CoreML Model Load

## ML_Vision
- [ ] Provide YOLO CoreML model (.mlmodel)
- [ ] Provide input name
- [ ] Provide output tensor names
- [ ] Provide expected output shape
- [ ] Confirm minimum iOS requirement

## Builder
- [ ] Import .mlmodel into Xcode
- [ ] Confirm model class auto-generated
- [ ] Write minimal load test
- [ ] Print "Model loaded successfully"

## Debugger
- [ ] Confirm model loads on device
- [ ] Confirm no runtime crash
- [ ] Confirm console log visible

Deliverable:
YOLO model loads successfully on iPhone 11.

---

# Day 3 — Single Image Inference

## Builder
- [ ] Create dummy 640x640 image input
- [ ] Run single inference
- [ ] Print output tensor shapes
- [ ] Measure inference time

## Debugger
- [ ] Confirm output shape matches spec
- [ ] Confirm inference time logged
- [ ] Confirm no memory spike

Deliverable:
Single-frame inference works on device.

---

# Day 4 — Camera Pipeline

## Builder
- [ ] Add AVFoundation preview
- [ ] Capture frame buffer
- [ ] Convert to 640x640 (letterbox)
- [ ] Feed frame into model
- [ ] Log per-frame inference time

## Debugger
- [ ] Confirm preview stable
- [ ] Confirm no main-thread blocking
- [ ] Confirm stable inference loop

Deliverable:
Live camera → YOLO inference running.

---

# Day 5 — Decode + NMS

## ML_Vision
- [ ] Provide reference decode logic
- [ ] Clarify bbox format (xywh or xyxy)
- [ ] Clarify confidence + class structure
- [ ] Provide recommended thresholds

## Builder
- [ ] Implement decode
- [ ] Implement confidence filtering
- [ ] Implement NMS
- [ ] Print detection count per frame

## Debugger
- [ ] Confirm boxes appear reasonable
- [ ] Confirm no explosion in detection count
- [ ] Measure decode time

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
