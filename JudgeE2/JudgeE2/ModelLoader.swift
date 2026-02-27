import Foundation
import CoreML
import CoreVideo

enum ModelLoader {
    static func testLoad() {
        do {
            _ = try yolov9_c(configuration: MLModelConfiguration())
            print("Model loaded successfully")
        } catch {
            print("Model load failed: \(error)")
        }
    }

    static func testSingleInference() {
        do {
            let model = try yolov9_c(configuration: MLModelConfiguration())
            guard let pixelBuffer = makeDummyPixelBuffer(width: 640, height: 640) else {
                print("Failed to create dummy pixel buffer")
                return
            }

            let start = CFAbsoluteTimeGetCurrent()
            let output = try model.prediction(image: pixelBuffer)
            let end = CFAbsoluteTimeGetCurrent()

            let shape1 = output.var_3019.shape.map { $0.intValue }
            let shape2 = output.var_3022.shape.map { $0.intValue }
            print("Output var_3019 shape: \(shape1)")
            print("Output var_3022 shape: \(shape2)")

            let elapsedMs = (end - start) * 1000.0
            print(String(format: "Single inference time: %.2f ms", elapsedMs))
        } catch {
            print("Single inference failed: \(error)")
        }
    }

    private static func makeDummyPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
            let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
            memset(baseAddress, 0, bytesPerRow * height)
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }
}
