import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(session: cameraManager.session, boxes: cameraManager.boxes)
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Text("JudgeE2 — Camera Pipeline")
                    .padding(8)
                    .background(.black.opacity(0.6))
                    .foregroundColor(.white)
                    .cornerRadius(8)

                Button(action: {
                    cameraManager.toggleCamera()
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(.black.opacity(0.6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .onAppear {
            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
}

#Preview {
    ContentView()
}
