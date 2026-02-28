import AVFoundation
import Combine
import CoreImage
import CoreML
import Foundation
import SwiftUI

final class CameraManager: NSObject, ObservableObject {
//    var objectWillChange: ObservableObjectPublisher
    
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoQueue = DispatchQueue(label: "camera.video.queue")
    private let ciContext = CIContext()
    private var model: yolov9_c?
    private var isProcessing = false

    private struct Detection {
        let x1: Float
        let y1: Float
        let x2: Float
        let y2: Float
        let score: Float
        let classId: Int
    }

    override init() {
        super.init()
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
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

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
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

//        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
//            connection.videoOrientation = .portrait
//        }
        if let connection = output.connection(with: .video) {

            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
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

            let detections = decodeDetections(from: output.var_3019,
                                              confidenceThreshold: 0.25)
            let nmsDetections = classAwareNMS(detections, iouThreshold: 0.45)

            print(String(format: "Frame inference time: %.2f ms | detections: %d", elapsedMs, nmsDetections.count))
        } catch {
            print("Frame inference failed: \(error)")
        }
    }

    private func decodeDetections(from multiArray: MLMultiArray, confidenceThreshold: Float) -> [Detection] {
        let shape = multiArray.shape.map { $0.intValue }
        guard shape.count == 3, shape[1] == 84 else { return [] }
        let locationCount = shape[2]
        let channelCount = shape[1]

        let strides = multiArray.strides.map { $0.intValue }
        let strideC = strides[1]
        let strideI = strides[2]

        guard let pointer = multiArray.dataPointer.bindMemory(to: Float.self, capacity: multiArray.count) as UnsafeMutablePointer<Float>? else {
            return []
        }

        func value(_ c: Int, _ i: Int) -> Float {
            let index = c * strideC + i * strideI
            return pointer[index]
        }

        var detections: [Detection] = []
        detections.reserveCapacity(256)

        for i in 0..<locationCount {
            let cx = value(0, i)
            let cy = value(1, i)
            let w = value(2, i)
            let h = value(3, i)

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

            let x1 = cx - w / 2
            let y1 = cy - h / 2
            let x2 = cx + w / 2
            let y2 = cy + h / 2

            detections.append(Detection(x1: x1, y1: y1, x2: x2, y2: y2, score: bestScore, classId: bestClass))
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

    private func letterboxToSquare(pixelBuffer: CVPixelBuffer, size: Int) -> CVPixelBuffer? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        let width = image.extent.width
        let height = image.extent.height
        let scale = min(CGFloat(size) / width, CGFloat(size) / height)

        let scaledImage = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let x = (CGFloat(size) - scaledImage.extent.width) / 2.0
        let y = (CGFloat(size) - scaledImage.extent.height) / 2.0
        let translatedImage = scaledImage.transformed(by: CGAffineTransform(translationX: x, y: y))

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
