import SwiftUI
import RealityKit

@main
struct meshSlicerApp: App {
    @State private var appModel = AppModel()

    var body: some SwiftUI.Scene {
        WindowGroup("USDZ Slicer") {
            ContentView()
                .environment(appModel)
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
                .environment(appModel)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}

let modelName = "CHARIS KRISNA MUKTI_ TN_Mandibula_001.usdz" 
