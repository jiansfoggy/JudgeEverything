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
- [x] Map detection coordinates to preview layer
- [x] Handle aspectFill scaling
- [x] Handle device orientation
- [x] Draw bounding boxes in real time while holding and rotating the phone.
- [x] When the phone is rotated, the captured image must remain horizontal. For example, if the phone is rotated 90 degrees clockwise, the image must be rotated 90 degrees counterclockwise to maintain its original horizontal state.

## Debugger
- [x] Confirm boxes align with objects
- [x] Confirm no flipped or mirrored boxes
- [x] Confirm overlay stable across rotation

Deliverable:
Real-time bounding box overlay on iPhone 11.

---

# Day 7 — Stabilization & Baseline

## Debugger
- [x] Measure model load time
- [x] Measure inference time (mean + p95)
- [x] Measure FPS
- [x] Record memory usage

## Architect
- [x] Review pipeline structure
- [x] Freeze Phase 1 architecture
- [x] Define Phase 2 (Segmentation integration plan)

Deliverable:
Stable YOLO detection pipeline.
Performance baseline recorded.
Ready for next 7-day cycle.

---

# Phase 2 — MobileSAM Real-Time Segmentation Integration

Objective:
Integrate MobileSAM instance segmentation on top of YOLO without breaking Phase 1 geometry or scheduling contract.

Principle:
Reuse Phase 1 pipeline. Add modules without rewriting it.

Must Reuse:
CanonicalFrame
FrameGeometry
LetterboxTransform

------------------------------------------------------------
Phase 2 — Detailed 7-Day Plan
------------------------------------------------------------

Design Rule:
Only assign tasks to agents when required.
Follow agent order:
Architect → ML_Vision → Builder → Debugger

------------------------------------------------------------
Day 1 — Architecture Lock & Integration Contract
------------------------------------------------------------

## Architect
- [ ] Define segmentation pipeline insertion point (post-NMS)
- [ ] Freeze geometry reuse contract (NO duplicate transforms)
- [ ] Define bbox→prompt format (box normalization + coordinate space)
- [ ] Define encoder/decoder split API + fallback (monolithic allowed)
- [ ] Define threading model (background queues; no capture blocking)
- [ ] Define bbox-only fallback policy

Deliverable:
Approved Phase 2 integration diagram + contracts.
No Phase 1 code modified.

------------------------------------------------------------
Day 2 — MobileSAM Model Preparation
------------------------------------------------------------

## ML_Vision
- [ ] Convert MobileSAM to CoreML (encoder/decoder split preferred)
- [ ] Provide input/output tensor names + shapes
- [ ] Provide embedding shape + mask output semantics
- [ ] Provide preprocessing spec (color space, normalization)
- [ ] Benchmark single-image latency (CPU/GPU)

## Debugger
- [ ] Confirm model loads on device
- [ ] Confirm no memory spike during load

Deliverable:
Working MobileSAM CoreML models load on iPhone 11 with documented I/O.

------------------------------------------------------------
Day 3 — Encoder Integration (Low Frequency)
------------------------------------------------------------

## Builder
- [ ] Insert Encoder module after detection (non-blocking)
- [ ] Run encoder every N frames (default 12)
- [ ] Cache embeddings with TTL
- [ ] Log embedding latency + cache hit rate

## Debugger
- [ ] Confirm embedding TTL works
- [ ] Confirm no main-thread blocking
- [ ] Confirm stable FPS (bbox-only path) not regressed

Deliverable:
Embedding generation working and cached.

------------------------------------------------------------
Day 4 — Decoder Integration (Medium Frequency)
------------------------------------------------------------

## Builder
- [ ] Build PromptBuilder (bbox → SAM prompt)
- [ ] Run decoder every N frames (default 6)
- [ ] Implement mask TTL (default 800ms)
- [ ] Log decode time + mask refresh rate

## Debugger
- [ ] Confirm mask aligns with bbox (same geometry chain)
- [ ] Confirm no jitter across frames
- [ ] Confirm fallback to bbox-only works when decoder stalls

Deliverable:
BBox → Mask working pipeline.

------------------------------------------------------------
Day 5 — Mask Renderer
------------------------------------------------------------

## Builder
- [ ] Add mask overlay layer
- [ ] Match geometry to preview layer (reuse Phase 1 mapping)
- [ ] Add alpha blending + color palette
- [ ] Handle rotation/mirror (reuse Phase 1 logic)

## Debugger
- [ ] Confirm mask not flipped
- [ ] Confirm alignment across orientation
- [ ] Confirm preview smooth

Deliverable:
Real-time mask overlay at 2–5Hz.

------------------------------------------------------------
Day 6 — Temporal Manager
------------------------------------------------------------

## Architect
- [ ] Define primary-object selection strategy (top-1 + hysteresis)
- [ ] Define bbox drift threshold (re-seg trigger)
- [ ] Define cache invalidation triggers (geometry change / TTL)

## Builder
- [ ] Implement TTL system for embedding + mask
- [ ] Implement drift detection & re-seg trigger
- [ ] Implement priority refresh for primary object

## Debugger
- [ ] Stress test motion & rotation
- [ ] Confirm mask stability during object motion
- [ ] Confirm fallback triggers correctly

Deliverable:
Stable segmentation loop with caching.

------------------------------------------------------------
Day 7 — Stabilization & Phase Freeze
------------------------------------------------------------

## Debugger
- [ ] Measure encoder latency (mean + p95)
- [ ] Measure decoder latency (mean + p95)
- [ ] Measure mask refresh rate
- [ ] Measure FPS (bbox + mask)
- [ ] Record memory usage

## Architect
- [ ] Freeze Phase 2 architecture
- [ ] Document integration contracts
- [ ] Define Phase 3 entry points

Deliverable:
Stable Detection + Segmentation pipeline.
Ready for Phase 3.
