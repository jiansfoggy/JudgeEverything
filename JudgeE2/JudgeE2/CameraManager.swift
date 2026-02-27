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
            _ = try model.prediction(image: inputBuffer)
            let end = CFAbsoluteTimeGetCurrent()
            let elapsedMs = (end - start) * 1000.0
            print(String(format: "Frame inference time: %.2f ms", elapsedMs))
        } catch {
            print("Frame inference failed: \(error)")
        }
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
