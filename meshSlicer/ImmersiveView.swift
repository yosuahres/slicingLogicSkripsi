import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var sliceHeightBottom: Float = 0.001 
    @State private var sliceHeightTop: Float = 0.999    
    
    let modelWorldPosition: SIMD3<Float> = [0, 0.3, -0.2]
    let modelWorldScale: SIMD3<Float> = [0.01, 0.01, 0.01]
    @State private var modelHeightWorld: Float = 0.001 
    @State private var modelLocalMinY: Float = 0.0 

    let occluderThickness: Float = 0.002 
    let occluderWidth: Float = 100.0 
    let occluderDepth: Float = 100.0 
    var occluderHalfThickness: Float { occluderThickness / 2.0 }
    
    let occluderZ: Float = -0.2 

    let bottomOccluderName = "BottomSliceOccluder"
    let topOccluderName = "TopSliceOccluder"
    // Invisible occlusion masks to hide regions outside the slice bounds
    let bottomMaskName = "BottomMaskOccluder"
    let topMaskName = "TopMaskOccluder"

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
            DispatchQueue.main.async {
                modelLocalMinY = localMinY
                modelHeightWorld = localHeight * modelWorldScale.y
            }

            let modelBaseWorldY = modelWorldPosition.y + (localMinY * modelWorldScale.y)

            let directionalLight = DirectionalLight()
            directionalLight.light.color = .white
            directionalLight.light.intensity = 10000
            directionalLight.shadow = DirectionalLightComponent.Shadow()
            directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, 1, 0])
            content.add(directionalLight)

            let bottomSlicerMaterial = SimpleMaterial(color: .blue, isMetallic: false)
            let topSlicerMaterial = SimpleMaterial(color: .green, isMetallic: false)
            
            let bottomOccluder = ModelEntity(
                mesh: .generateBox(size: [occluderWidth, occluderThickness, occluderDepth]),
                materials: [bottomSlicerMaterial]
            )
            bottomOccluder.name = bottomOccluderName
            
            let initialBottomOccluderCenterY = modelBaseWorldY + (sliceHeightBottom * modelHeightWorld)
            bottomOccluder.position = [modelWorldPosition.x, initialBottomOccluderCenterY, occluderZ]
            content.add(bottomOccluder)

            let topOccluder = ModelEntity(
                mesh: .generateBox(size: [occluderWidth, occluderThickness, occluderDepth]),
                materials: [topSlicerMaterial]
            )
            topOccluder.name = topOccluderName
            
            let initialTopOccluderCenterY = modelBaseWorldY + (sliceHeightTop * modelHeightWorld)
            topOccluder.position = [modelWorldPosition.x, initialTopOccluderCenterY, occluderZ]
            content.add(topOccluder)

            // --- Invisible occlusion masks ---
            // Use a unit-height box and scale it in Y to the desired mask height so we can update easily later.
            let occlusionMat = OcclusionMaterial()

            // Bottom mask: hides everything from model bottom up to (but not including) the bottom slice plane
            let bottomMask = ModelEntity(
                mesh: .generateBox(size: [occluderWidth, 1.0, occluderDepth]),
                materials: [occlusionMat]
            )
            bottomMask.name = bottomMaskName
            // initial mask height (clamped to at least occluderThickness to avoid zero)
            let initialBottomMaskHeight = max(sliceHeightBottom * modelHeightWorld, occluderThickness)
            let bottomMaskCenterY = modelBaseWorldY + (initialBottomMaskHeight / 2.0)
            bottomMask.position = [modelWorldPosition.x, bottomMaskCenterY, occluderZ]
            bottomMask.scale = SIMD3<Float>(1.0, initialBottomMaskHeight, 1.0)
            content.add(bottomMask)

            // Top mask: hides everything from top slice plane up to model top
            let topMask = ModelEntity(
                mesh: .generateBox(size: [occluderWidth, 1.0, occluderDepth]),
                materials: [occlusionMat]
            )
            topMask.name = topMaskName
            let modelTopY = modelBaseWorldY + modelHeightWorld
            let initialTopMaskHeight = max((1.0 - sliceHeightTop) * modelHeightWorld, occluderThickness)
            let topMaskCenterY = (modelBaseWorldY + (sliceHeightTop * modelHeightWorld)) + (initialTopMaskHeight / 2.0)
            topMask.position = [modelWorldPosition.x, topMaskCenterY, occluderZ]
            topMask.scale = SIMD3<Float>(1.0, initialTopMaskHeight, 1.0)
            content.add(topMask)

        } update: { content in
            // --- Update Loop ---
            // Find the occluders
            guard let bottomOccluder = content.entities.first(where: { $0.name == bottomOccluderName }),
                  let topOccluder = content.entities.first(where: { $0.name == topOccluderName }),
                  let bottomMask = content.entities.first(where: { $0.name == bottomMaskName }) as? ModelEntity,
                  let topMask = content.entities.first(where: { $0.name == topMaskName }) as? ModelEntity else {
                return
            }
            
            // Recalculate position for bottom/top occluders using the computed model base and world height
            let modelBaseWorldY = modelWorldPosition.y + (modelLocalMinY * modelWorldScale.y)
            let bottomOccluderTargetY = modelBaseWorldY + (sliceHeightBottom * modelHeightWorld)
            bottomOccluder.transform.translation = SIMD3<Float>(modelWorldPosition.x, bottomOccluderTargetY, occluderZ)

            let topOccluderTargetY = modelBaseWorldY + (sliceHeightTop * modelHeightWorld)
            topOccluder.transform.translation = SIMD3<Float>(modelWorldPosition.x, topOccluderTargetY, occluderZ)
            
            // Update invisible masks to hide outside regions
            // Bottom mask: height = distance from model bottom to bottom slice
            let bottomMaskHeight = max(sliceHeightBottom * modelHeightWorld, occluderThickness)
            let bottomMaskCenterY = modelBaseWorldY + (bottomMaskHeight / 2.0)
            bottomMask.transform.translation = SIMD3<Float>(modelWorldPosition.x, bottomMaskCenterY, occluderZ)
            bottomMask.transform.scale = SIMD3<Float>(1.0, bottomMaskHeight, 1.0)

            // Top mask: height = distance from top slice to model top
            let modelTopY = modelBaseWorldY + modelHeightWorld
            let topMaskHeight = max((modelTopY - topOccluderTargetY), occluderThickness)
            let topMaskCenterY = topOccluderTargetY + (topMaskHeight / 2.0)
            topMask.transform.translation = SIMD3<Float>(modelWorldPosition.x, topMaskCenterY, occluderZ)
            topMask.transform.scale = SIMD3<Float>(1.0, topMaskHeight, 1.0)
         }
         .overlay(alignment: .bottom) {
             VStack {
                 // Bottom Slice Slider
                 Slider(value: $sliceHeightBottom, in: 0.0...1.0, step: 0.01) { 
                     Text("Bottom Slice")
                 } minimumValueLabel: {
                     Text("0%")
                 } maximumValueLabel: {
                     Text("100%")
                 }
                 .frame(width: 400)
                 .onChange(of: sliceHeightBottom) { oldValue, newValue in
                     if newValue >= sliceHeightTop { 
                         sliceHeightBottom = sliceHeightTop - 0.001 
                     }
                     print("Bottom Slice Height changed to: \(newValue)")
                 }
                
                 Text("Bottom Slice: \(sliceHeightBottom * 100, specifier: "%.0f")%")
                     .padding(12)
                     .monospaced()

                 // Top Slice Slider
                 Slider(value: $sliceHeightTop, in: 0.0...1.0, step: 0.01) { 
                     Text("Top Slice")
                 } minimumValueLabel: {
                     Text("0%")
                 } maximumValueLabel: {
                     Text("100%")
                 }
                 .frame(width: 400)
                 .onChange(of: sliceHeightTop) { oldValue, newValue in
                     if newValue <= sliceHeightBottom { 
                         sliceHeightTop = sliceHeightBottom + 0.001 
                     }
                     print("Top Slice Height changed to: \(newValue)")
                 }
                
                 Text("Top Slice: \(sliceHeightTop * 100, specifier: "%.0f")%")
                     .padding(12)
                     .monospaced()
                
                 ToggleImmersiveSpaceButton()
             }
             .padding(24)
             .background(.black) 
             .cornerRadius(16)
             .offset(z: -0.5)
         }
     }
 }
