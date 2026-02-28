import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let boxes: [CGRect]

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
        uiView.updateBoxes(boxes)
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private let overlayLayer = CAShapeLayer()

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOverlay()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOverlay()
    }

    private func setupOverlay() {
        overlayLayer.strokeColor = UIColor.green.cgColor
        overlayLayer.lineWidth = 2.0
        overlayLayer.fillColor = UIColor.clear.cgColor
        layer.addSublayer(overlayLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        overlayLayer.frame = bounds
    }

    func updateBoxes(_ boxes: [CGRect]) {
        let path = UIBezierPath()
        for box in boxes {
            let rect = videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: box)
            path.append(UIBezierPath(rect: rect))
        }
        overlayLayer.path = path.cgPath
    }
}
