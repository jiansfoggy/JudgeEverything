import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack(alignment: .topLeading) {
            CameraPreview(session: cameraManager.session, boxes: cameraManager.boxes)
                .ignoresSafeArea()

            Text("JudgeE2 — Camera Pipeline")
                .padding(8)
                .background(.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
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
