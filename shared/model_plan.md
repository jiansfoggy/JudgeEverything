# Model Plan — Day 2 (CoreML Model Load)

## Selected Model
- **File:** `/Users/jiansun/Documents/PostDoc/CODE-SHOW/APP/JudgeE2/models/yolov9-c.mlmodel`
- **Model class (CoreML):** `yolov9_c`
- **Model type:** NeuralNetwork
- **Compute precision:** Float16 (weights), outputs Float32

## Inputs
- **Name:** `image`
- **Type:** Image (Color)
- **Size:** 640 × 640
- **Pixel format (from generated interface):** CVPixelBuffer, kCVPixelFormatType_32BGRA

## Outputs
- **Name:** `var_3019`
  - **Type:** MultiArray (Float32)
  - **Shape:** (1, 84, 8400)
- **Name:** `var_3022`
  - **Type:** MultiArray (Float32)
  - **Shape:** (1, 84, 8400)

> Shape source: compiled model `model.espresso.shape` (rank=3 with n=1, h=84, w=8400). Both outputs match this shape.

## Minimum OS Requirement
- **iOS 13.0** (from compiled model availability metadata)

---

# Day 5 — Decode + NMS (ML_Vision)

## Output Tensor Interpretation (YOLOv9-c, CoreML)
- Output shape: **(1, 84, 8400)**
- Interpret as **84 channels × 8400 locations**
- **84 = 4 box + 80 class scores** (no separate objectness channel)

### Channel Layout (per location index i in 0..8399)
- `0`: **cx** (center x)
- `1`: **cy** (center y)
- `2`: **w** (width)
- `3`: **h** (height)
- `4..83`: **class scores** (80 classes)

> This matches YOLOv8/v9 detection head convention for 80-class COCO models.

## Decode Logic (Reference)
1. For each location `i`:
   - Read `cx, cy, w, h` from channels 0..3
   - Find `bestClass = argmax(classScores)` and `bestScore = max(classScores)`
2. **Confidence** = `bestScore` (no objectness multiplier)
3. Filter by confidence threshold
4. Convert box to **xyxy** for NMS:
   - `x1 = cx - w/2`, `y1 = cy - h/2`, `x2 = cx + w/2`, `y2 = cy + h/2`
5. Run class-aware NMS (preferred) or class-agnostic NMS

## Coordinate Assumption
- Boxes are in **input image coordinates** for the **640×640** model input.
- If input is letterboxed, map from 640×640 to original frame using the same scale + padding applied during preprocessing.

## Recommended Thresholds (Starting Point)
- **Confidence threshold:** `0.25`
- **NMS IoU threshold:** `0.45`
- Adjust as needed once you see detection density.

## Notes
- Two outputs exist but both are `(1, 84, 8400)`; treat either output as the detection tensor unless builder confirms a preferred one.
- If detections seem too many or too few, verify if the model was trained with a different class count or requires sigmoid/softmax; generally YOLOv8/v9 uses sigmoid on class scores.
