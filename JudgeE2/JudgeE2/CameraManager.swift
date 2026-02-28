import AVFoundation
import Combine
import CoreImage
import CoreML
import Foundation
import SwiftUI
import MachO

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    @Published var boxes: [CGRect] = []

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private let ciContext = CIContext()
    private var model: yolov9_c?
    private var isProcessing = false
    private var currentPosition: AVCaptureDevice.Position = .back
    private var videoConnection: AVCaptureConnection?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var lastRotationAngle: CGFloat = 0

    private var frameCount = 0
    private var lastFpsTime = CFAbsoluteTimeGetCurrent()

    private var inferenceTimesMs: [Double] = []
    private let inferenceStatsWindow = 100

    private struct Detection {
        let x1: Float
        let y1: Float
        let x2: Float
        let y2: Float
        let score: Float
        let classId: Int
    }

    private struct LetterboxInfo {
        let origW: Float
        let origH: Float
        let scale: Float
        let padX: Float
        let padY: Float
        let inputSize: Float
    }
    private var lastLetterbox: LetterboxInfo?

    override init() {
        super.init()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleOrientationChange),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    @objc private func handleOrientationChange() {
        sessionQueue.async { [weak self] in
            self?.updateRotation()
        }
    }

    private func desiredRotationAngle() -> CGFloat {
        // Keep captured buffer horizontal (landscape) regardless of device orientation
        switch UIDevice.current.orientation {
        case .landscapeRight:
            return 0
        case .landscapeLeft:
            return 180
        case .portraitUpsideDown:
            return 270
        case .portrait:
            fallthrough
        default:
            return 90
        }
    }

    private func updateRotation() {
        guard let output = videoOutput,
              let connection = output.connection(with: .video) else { return }
        let angle = desiredRotationAngle()
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
                lastRotationAngle = angle
            }
        } else {
            if connection.isVideoOrientationSupported {
                let orientation: AVCaptureVideoOrientation
                switch UIDevice.current.orientation {
                case .landscapeLeft:
                    orientation = .landscapeLeft
                case .landscapeRight:
                    orientation = .landscapeRight
                case .portraitUpsideDown:
                    orientation = .portraitUpsideDown
                default:
                    orientation = .portrait
                }
                connection.videoOrientation = orientation
                lastRotationAngle = orientation == .portrait ? 90 : (orientation == .portraitUpsideDown ? 270 : (orientation == .landscapeLeft ? 180 : 0))
            }
        }
    }

    func toggleCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentPosition = (self.currentPosition == .back) ? .front : .back
            self.session.beginConfiguration()
            for input in self.session.inputs {
                self.session.removeInput(input)
            }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.currentPosition),
               let input = try? AVCaptureDeviceInput(device: device),
               self.session.canAddInput(input) {
                self.session.addInput(input)
            } else {
                print("Camera input unavailable when toggling")
            }
            self.session.commitConfiguration()
            // refresh connection + rotation/mirroring
            self.updateRotation()
            if let output = self.videoOutput,
               let conn = output.connection(with: .video),
               conn.isVideoMirroringSupported {
                conn.isVideoMirrored = (self.currentPosition == .front)
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            print("Camera input unavailable")
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            print("Camera output unavailable")
            return
        }
        session.addOutput(output)
        videoOutput = output
        updateRotation()
        if let conn = output.connection(with: .video), conn.isVideoMirroringSupported {
            conn.isVideoMirrored = (currentPosition == .front)
        }

        session.commitConfiguration()

        do {
            model = try yolov9_c(configuration: MLModelConfiguration())
        } catch {
            print("Model load failed in CameraManager: \(error)")
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // FPS + memory logging (1s window)
        frameCount += 1
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastFpsTime >= 1.0 {
            let fps = Double(frameCount) / (now - lastFpsTime)
            let mem = reportMemoryMB()
            print(String(format: "FPS: %.2f | Memory: %.1f MB", fps, mem))
            frameCount = 0
            lastFpsTime = now
        }

        guard let model = model else { return }
        if isProcessing { return }
        isProcessing = true
        defer { isProcessing = false }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let inputBuffer = letterboxToSquare(pixelBuffer: pixelBuffer, size: 640) else { return }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let output = try model.prediction(image: inputBuffer)
            let end = CFAbsoluteTimeGetCurrent()
            let elapsedMs = (end - start) * 1000.0

            inferenceTimesMs.append(elapsedMs)
            if inferenceTimesMs.count >= inferenceStatsWindow {
                let mean = inferenceTimesMs.reduce(0.0, +) / Double(inferenceTimesMs.count)
                let sorted = inferenceTimesMs.sorted()
                let p95Index = max(0, Int(ceil(0.95 * Double(sorted.count))) - 1)
                let p95 = sorted[p95Index]
                print(String(format: "Inference time stats (n=%d): mean=%.2f ms | p95=%.2f ms", sorted.count, mean, p95))
                inferenceTimesMs.removeAll(keepingCapacity: true)
            }

            let detections = decodeDetections(from: output.var_3019, confidenceThreshold: 0.25)
            let topK = 10
            let topDetections = detections.sorted { $0.score > $1.score }.prefix(topK)
            let nmsDetections = classAwareNMS(Array(topDetections), iouThreshold: 0.45)

            let top5 = Array(nmsDetections.prefix(5))
            print(String(format: "Frame inference time: %.2f ms | raw_in_boxes: %d | topK: %d | final_detections: %d", elapsedMs, detections.count, min(topK, detections.count), nmsDetections.count))
            for (idx, det) in top5.enumerated() {
                print(String(format: "det[%d]: class=%d score=%.3f box=[%.1f, %.1f, %.1f, %.1f]", idx, det.classId, det.score, det.x1, det.y1, det.x2, det.y2))
            }

            let rects = top5.compactMap { det in
                self.mapToMetadataRect(det)
            }
            DispatchQueue.main.async { [weak self] in
                self?.boxes = rects
            }
        } catch {
            print("Frame inference failed: \(error)")
        }
    }

    private func mapToMetadataRect(_ det: Detection) -> CGRect? {
        guard let info = lastLetterbox else { return nil }

        // Convert from 640x640 model input back to original buffer coords
        let x1 = (det.x1 - info.padX) / info.scale
        let y1 = (det.y1 - info.padY) / info.scale
        let x2 = (det.x2 - info.padX) / info.scale
        let y2 = (det.y2 - info.padY) / info.scale

        let bx = max(0, min(info.origW, x1))
        let by = max(0, min(info.origH, y1))
        let bw = max(0, min(info.origW, x2)) - bx
        let bh = max(0, min(info.origH, y2)) - by
        if bw <= 1 || bh <= 1 { return nil }

        var rect: CGRect
        switch Int(lastRotationAngle) {
        case 90:
            // Rotate clockwise: (x, y, w, h) in W x H -> (y, W - x - w, h, w) in H x W
            let rotX = by
            let rotY = info.origW - bx - bw
            let rotW = bh
            let rotH = bw
            let normX = rotX / info.origH
            let normY = rotY / info.origW
            let normW = rotW / info.origH
            let normH = rotH / info.origW
            rect = CGRect(x: CGFloat(normX), y: CGFloat(normY), width: CGFloat(normW), height: CGFloat(normH))
        case 180:
            // Rotate 180: (x, y, w, h) -> (W - x - w, H - y - h, w, h)
            let rotX = info.origW - bx - bw
            let rotY = info.origH - by - bh
            let normX = rotX / info.origW
            let normY = rotY / info.origH
            let normW = bw / info.origW
            let normH = bh / info.origH
            rect = CGRect(x: CGFloat(normX), y: CGFloat(normY), width: CGFloat(normW), height: CGFloat(normH))
        case 270:
            // Rotate counterclockwise: (x, y, w, h) -> (H - y - h, x, h, w) in H x W
            let rotX = info.origH - by - bh
            let rotY = bx
            let rotW = bh
            let rotH = bw
            let normX = rotX / info.origH
            let normY = rotY / info.origW
            let normW = rotW / info.origH
            let normH = rotH / info.origW
            rect = CGRect(x: CGFloat(normX), y: CGFloat(normY), width: CGFloat(normW), height: CGFloat(normH))
        default:
            // No rotation
            let normX = bx / info.origW
            let normY = by / info.origH
            let normW = bw / info.origW
            let normH = bh / info.origH
            rect = CGRect(x: CGFloat(normX), y: CGFloat(normY), width: CGFloat(normW), height: CGFloat(normH))
        }

        // Mirror horizontally for front camera
        if currentPosition == .front {
            rect = CGRect(x: 1.0 - rect.origin.x - rect.size.width,
                          y: rect.origin.y,
                          width: rect.size.width,
                          height: rect.size.height)
        }
        return rect
    }

    private func decodeDetections(from multiArray: MLMultiArray, confidenceThreshold: Float) -> [Detection] {
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[1] == 84 else { return [] }
        let locationCount = shape[2]
        let channelCount = shape[1]

        let strides = multiArray.strides.map { $0.intValue }
        let strideC = strides[1]
        let strideI = strides[2]

        let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count)

        func value(_ c: Int, _ i: Int) -> Float {
            let index = c * strideC + i * strideI
            return pointer[index]
        }

        var detections: [Detection] = []
        detections.reserveCapacity(256)

        func looksNormalized(_ v: Float) -> Bool { return v >= -0.1 && v <= 1.5 }

        for i in 0..<locationCount {
            var cx = value(0, i)
            var cy = value(1, i)
            var w = value(2, i)
            var h = value(3, i)

            var bestScore: Float = -Float.greatestFiniteMagnitude
            var bestClass = -1
            if channelCount > 4 {
                for c in 4..<channelCount {
                    let raw = value(c, i)
                    let score = sigmoid(raw)
                    if score > bestScore {
                        bestScore = score
                        bestClass = c - 4
                    }
                }
            }

            if bestScore < confidenceThreshold { continue }

            if looksNormalized(cx) && looksNormalized(cy) && looksNormalized(w) && looksNormalized(h) {
                cx = cx * 640.0
                cy = cy * 640.0
                w  = w  * 640.0
                h  = h  * 640.0
            }

            let x1 = cx - w / 2
            let y1 = cy - h / 2
            let x2 = cx + w / 2
            let y2 = cy + h / 2

            let clampX1 = max(0.0, min(640.0, x1))
            let clampY1 = max(0.0, min(640.0, y1))
            let clampX2 = max(0.0, min(640.0, x2))
            let clampY2 = max(0.0, min(640.0, y2))

            if clampX2 - clampX1 <= 1 || clampY2 - clampY1 <= 1 { continue }

            detections.append(Detection(x1: clampX1, y1: clampY1, x2: clampX2, y2: clampY2, score: bestScore, classId: bestClass))
        }

        return detections
    }

    private func classAwareNMS(_ detections: [Detection], iouThreshold: Float) -> [Detection] {
        var grouped: [Int: [Detection]] = [:]
        for det in detections {
            grouped[det.classId, default: []].append(det)
        }

        var results: [Detection] = []
        for (_, dets) in grouped {
            let sorted = dets.sorted { $0.score > $1.score }
            var kept: [Detection] = []

            for det in sorted {
                var shouldKeep = true
                for keptDet in kept {
                    if iou(det, keptDet) > iouThreshold {
                        shouldKeep = false
                        break
                    }
                }
                if shouldKeep { kept.append(det) }
            }
            results.append(contentsOf: kept)
        }

        return results
    }

    private func iou(_ a: Detection, _ b: Detection) -> Float {
        let xA = max(a.x1, b.x1)
        let yA = max(a.y1, b.y1)
        let xB = min(a.x2, b.x2)
        let yB = min(a.y2, b.y2)

        let interW = max(0, xB - xA)
        let interH = max(0, yB - yA)
        let interArea = interW * interH

        let areaA = max(0, a.x2 - a.x1) * max(0, a.y2 - a.y1)
        let areaB = max(0, b.x2 - b.x1) * max(0, b.y2 - b.y1)
        let union = areaA + areaB - interArea
        if union <= 0 { return 0 }
        return interArea / union
    }

    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }

    private func reportMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0
        }
        return -1
    }

    private func letterboxToSquare(pixelBuffer: CVPixelBuffer, size: Int) -> CVPixelBuffer? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = image.extent.width
        let height = image.extent.height
        let scale = min(CGFloat(size) / width, CGFloat(size) / height)

        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let x = (CGFloat(size) - scaledImage.extent.width) / 2.0
        let y = (CGFloat(size) - scaledImage.extent.height) / 2.0
        let translatedImage = scaledImage.transformed(by: CGAffineTransform(translationX: x, y: y))

        lastLetterbox = LetterboxInfo(
            origW: Float(width),
            origH: Float(height),
            scale: Float(scale),
            padX: Float(x),
            padY: Float(y),
            inputSize: Float(size)
        )

        let outputAttrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: size,
            kCVPixelBufferHeightKey: size,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, size, size, kCVPixelFormatType_32BGRA, outputAttrs as CFDictionary, &outputBuffer)
        guard status == kCVReturnSuccess, let buffer = outputBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        let background = CIImage(color: .black).cropped(to: CGRect(x: 0, y: 0, width: size, height: size))
        let composed = translatedImage.composited(over: background)
        ciContext.render(composed, to: buffer)
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
