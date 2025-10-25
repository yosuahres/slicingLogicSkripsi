import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var cubeCenter: Float = 0.5    
    @State private var cubeSize: Float = 0.5   
    @State private var cubeWidthFactor: Float = 1.0 
    
    let modelWorldPosition: SIMD3<Float> = [0, 0.3, -0.2]
    let modelWorldScale: SIMD3<Float> = [0.01, 0.01, 0.01]
    @State private var modelHeightWorld: Float = 0.001 
    @State private var modelLocalMinY: Float = 0.0 
    @State private var modelLocalWidth: Float = 0.0
    @State private var modelLocalDepth: Float = 0.0

    let occluderThickness: Float = 0.002 
    let occluderWidthFallback: Float = 100.0 
    let occluderDepthFallback: Float = 100.0 
     var occluderHalfThickness: Float { occluderThickness / 2.0 }
    
     let occluderZ: Float = -0.2 

    let cubeOccluderName = "SliceCubeOccluder"

     var body: some View {
         RealityView { content in
             guard let model = try? await Entity(named: modelName) else {
                 print("Error: Could not load model '\(modelName)'.")
                 let placeholder = ModelEntity(
                     mesh: .generateBox(size: 0.1),
                     materials: [SimpleMaterial(color: .red, isMetallic: false)]
                 )
                 placeholder.position = modelWorldPosition
                 placeholder.name = "Error: Model Not Found"
                 content.add(placeholder)
                 return
             }
             model.position = modelWorldPosition
             model.scale = modelWorldScale
             model.name = "SlicableModel"
             content.add(model)

             let localBounds = model.visualBounds(relativeTo: model) 
             let localMinY = localBounds.min.y
             let localMaxY = localBounds.max.y
             let localHeight = localMaxY - localMinY
            let localWidth = localBounds.max.x - localBounds.min.x
            let localDepth = localBounds.max.z - localBounds.min.z
             DispatchQueue.main.async {
                modelLocalMinY = localMinY
                modelHeightWorld = localHeight * modelWorldScale.y
                modelLocalWidth = localWidth
                modelLocalDepth = localDepth
            }

             let modelBaseWorldY = modelWorldPosition.y + (localMinY * modelWorldScale.y)

             let directionalLight = DirectionalLight()
             directionalLight.light.color = .white
             directionalLight.light.intensity = 10000
             directionalLight.shadow = DirectionalLightComponent.Shadow()
             directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, 1, 0])
             content.add(directionalLight)

            let occlusionMat = OcclusionMaterial()
            let cubeWidthWorld = max((localWidth * modelWorldScale.x) * cubeSize * cubeWidthFactor, occluderWidthFallback * 0.01)
            let cubeDepthWorld = max((localDepth * modelWorldScale.z) * cubeSize, occluderDepthFallback * 0.01)
            let cubeHeightWorld = max(modelHeightWorld * cubeSize, occluderThickness)

            let occlusionCube = ModelEntity(
                mesh: .generateBox(size: [cubeWidthWorld, cubeHeightWorld, cubeDepthWorld]),
                materials: [occlusionMat]
            )
            occlusionCube.name = cubeOccluderName
            occlusionCube.position = [modelWorldPosition.x, modelBaseWorldY + (cubeCenter * modelHeightWorld), occluderZ]
            content.add(occlusionCube)

         } update: { content in
            guard let occlusionCube = content.entities.first(where: { $0.name == cubeOccluderName }) as? ModelEntity else {
                return
            }
            let modelBaseWorldY = modelWorldPosition.y + (modelLocalMinY * modelWorldScale.y)
            let cubeWidthWorld = max((modelLocalWidth * modelWorldScale.x) * cubeSize * cubeWidthFactor, occluderWidthFallback * 0.01)
            let cubeDepthWorld = max((modelLocalDepth * modelWorldScale.z) * cubeSize, occluderDepthFallback * 0.01)
            let cubeHeightWorld = max(modelHeightWorld * cubeSize, occluderThickness)

            let cubeCenterY = modelBaseWorldY + (cubeCenter * modelHeightWorld)
            occlusionCube.transform.translation = SIMD3<Float>(modelWorldPosition.x, cubeCenterY, occluderZ)
            if let mesh = occlusionCube.model?.mesh {
                let bounds = mesh.bounds
                let meshHeight = Float(bounds.max.y - bounds.min.y)
                let yScale = meshHeight > 0 ? (cubeHeightWorld / meshHeight) : 1.0
                let meshWidth = Float(bounds.max.x - bounds.min.x)
                let meshDepth = Float(bounds.max.z - bounds.min.z)
                let xScale = meshWidth > 0 ? (cubeWidthWorld / meshWidth) : 1.0
                let zScale = meshDepth > 0 ? (cubeDepthWorld / meshDepth) : 1.0
                occlusionCube.transform.scale = SIMD3<Float>(xScale, yScale, zScale)
            } else {
                occlusionCube.transform.scale = SIMD3<Float>(cubeWidthWorld / max(occluderWidthFallback * 0.01, 0.001), cubeHeightWorld / max(occluderThickness, 0.001), cubeDepthWorld / max(occluderDepthFallback * 0.01, 0.001))
            }
         }
         .overlay(alignment: .bottom) {
              VStack {
                 VStack {
                     Slider(value: $cubeCenter, in: 0.0...1.0, step: 0.01) {
                         Text("Cube Center")
                     } minimumValueLabel: { Text("0%") } maximumValueLabel: { Text("100%") }
                     .frame(width: 400)
                     Text("Center: \(cubeCenter * 100, specifier: "%.0f")%")
                         .padding(8)
                         .monospaced()
                 }

                 VStack {
                     Slider(value: $cubeSize, in: 0.01...1.0, step: 0.01) {
                         Text("Cube Size")
                     } minimumValueLabel: { Text("1%") } maximumValueLabel: { Text("100%") }
                     .frame(width: 400)
                     Text("Size: \(cubeSize * 100, specifier: "%.0f")% of model height")
                         .padding(8)
                         .monospaced()
                 }

                 VStack {
                     Slider(value: $cubeWidthFactor, in: 0.1...2.0, step: 0.01) {
                         Text("Cube Width Factor")
                     } minimumValueLabel: { Text("10%") } maximumValueLabel: { Text("200%") }
                     .frame(width: 400)
                     Text("Width Factor: \(cubeWidthFactor * 100, specifier: "%.0f")%")
                         .padding(8)
                         .monospaced()
                 }
                
                ToggleImmersiveSpaceButton()
            }
            .padding(24)
            .background(.black) 
            .cornerRadius(16)
            .offset(z: -0.5)
        }
    }
}
