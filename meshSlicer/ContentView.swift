import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ZStack(alignment: .bottom) {
            RealityView { content in
                guard let model = try? await Entity(named: modelName) else {
                    print("Error: Could not load model '\(modelName)'.")
                    let placeholder = ModelEntity(
                        mesh: .generateBox(size: 0.1),
                        materials: [SimpleMaterial(color: .red, isMetallic: false)]
                    )
                    placeholder.position = [0, 1.5, -0.5]
                    content.add(placeholder)
                    return
                }

                model.position = [0, 0.1, -0.2]
                model.scale = [0.001, 0.001, 0.001]
                content.add(model)
                
                let directionalLight = DirectionalLight()
                directionalLight.light.color = .white
                directionalLight.light.intensity = 10000
                directionalLight.shadow = DirectionalLightComponent.Shadow()
                directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, 1, 0])
                content.add(directionalLight)
            }
            
            VStack(spacing: 20) {
                Text("USDZ Mesh Slicer")
                    .font(.largeTitle)

                Text("Model: \(modelName)")
                    .font(.headline)

                ToggleImmersiveSpaceButton()
                .font(.headline)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .padding(30)
            .background(.black.opacity(0.5))
            .cornerRadius(20)
            .padding(.bottom, 30) 
        }
    }
}
