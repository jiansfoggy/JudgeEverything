# Builder Progress — JudgeE2

## Day 1 — Clean iOS Foundation

**Status:** Complete.

### Completed
- Xcode project located at `/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/JudgeE2`.
- iOS deployment target **17.0** in `JudgeE2.xcodeproj`.
- Bundle Identifier: `js.JudgeE2`.
- Signing Team: `W95LVGJ7G3` (Automatic).
- Simulator + iPhone 11 both launch the default app (white screen).

## Day 2 — CoreML Model Load (Builder)

**Status:** Complete.

### Completed
- Added `yolov9-c.mlmodel` to app target (copied to `JudgeE2/JudgeE2/Models/`).
- Confirmed auto-generated model class: `yolov9_c` (via CoreML generate).
- Added minimal load test (`ModelLoader.testLoad()`), called in `JudgeE2App.init()`.
- Prints **"Model loaded successfully"** on app start.

## Day 3 — Single Image Inference (Builder)

**Status:** Complete.

### Completed
- Created dummy 640×640 BGRA pixel buffer input.
- Ran a single inference via `yolov9_c.prediction(image:)`.
- Printed output tensor shapes for `var_3019` and `var_3022`.
- Measured and logged single inference time (ms).

## Day 4 — Camera Pipeline (Builder)

**Status:** Complete.

### Completed
- Added AVFoundation camera preview (`CameraPreview` + `PreviewView`).
- Captured frame buffers via `AVCaptureVideoDataOutput` delegate.
- Implemented 640×640 letterbox conversion with CoreImage.
- Fed frames into `yolov9_c.prediction(image:)`.
- Logged per-frame inference time (ms).

### Verification (2026-02-27)
- Confirmed `CameraManager.swift` handles session config, frame capture, letterbox, and per-frame inference logging.
- Confirmed `ContentView` uses `CameraPreview` with start/stop lifecycle.

### Notes
- Added camera usage description in build settings: `INFOPLIST_KEY_NSCameraUsageDescription`.

---

## Day 5 — Decode + NMS (Builder)

**Status:** Complete.

### Completed
- Implemented decode for YOLOv9-c output tensor `(1, 84, 8400)`.
- Added confidence filtering (sigmoid + threshold 0.25).
- Added class-aware NMS (IoU 0.45).
- Prints detection count per frame in the inference log.

### Code Notes
- Implemented in `CameraManager.swift`:
  - `decodeDetections(from:confidenceThreshold:)`
  - `classAwareNMS(_:iouThreshold:)`
  - `iou(_:_:), sigmoid(_:)`
- Uses `var_3019` output for decode.

---

## Day 6 — Bounding Box Overlay (Builder)

**Status:** Complete.

### Completed
- Mapped detection coordinates to preview layer via metadata-normalized rects.
- Handled aspectFill scaling using `layerRectConverted(fromMetadataOutputRect:)`.
- Handled device orientation and kept captured image horizontal by adjusting `videoRotationAngle` based on device rotation.
- Drew bounding boxes in real time with `CAShapeLayer` overlay.

### Code Notes
- `CameraManager.swift`: orientation observer + `updateRotation()` + rotation-aware `mapToMetadataRect`.
- `CameraPreview.swift`: overlay layer path update from normalized rects.
