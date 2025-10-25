import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    
    let modelName = "CHARIS KRISNA MUKTI_ TN_Mandibula_001"
    let modelWorldPosition: SIMD3<Float> = [0, 0.3, -0.2]
    let modelWorldScale: SIMD3<Float> = [0.01, 0.01, 0.01]
    
    @State private var modelHeightWorld: Float = 0.001
    @State private var modelLocalMinY: Float = 0.0
    @State private var modelLocalMaxY: Float = 0.0
    @State private var modelLocalMinX: Float = 0.0
    @State private var modelLocalMaxX: Float = 0.0
    @State private var modelLocalWidth: Float = 0.0
    @State private var modelLocalDepth: Float = 0.0

    @State private var leftPlaneOffset: Float = 0.25
    @State private var rightPlaneOffset: Float = 0.75

    let occluderThickness: Float = 0.002
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
                modelLocalMaxY = localMaxY
                modelLocalMinX = localBounds.min.x
                modelLocalMaxX = localBounds.max.x
                modelLocalWidth = localWidth
                modelLocalDepth = localDepth
                modelHeightWorld = localHeight * modelWorldScale.y
            }

            let modelBaseWorldY = modelWorldPosition.y + (localMinY * modelWorldScale.y)
            let modelBaseWorldX = modelWorldPosition.x + (localBounds.min.x * modelWorldScale.x)
            let localHeightWorld = localHeight * modelWorldScale.y
            let localWidthWorld = localWidth * modelWorldScale.x
            let localDepthWorld = localDepth * modelWorldScale.z

            let directionalLight = DirectionalLight()
            directionalLight.light.color = .white
            directionalLight.light.intensity = 10000
            directionalLight.shadow = DirectionalLightComponent.Shadow()
            directionalLight.orientation = simd_quatf(angle: .pi / 4, axis: [1, 1, 0])
            content.add(directionalLight)

            let planeThickness: Float = max(occluderThickness, 0.001)
            let planeHeight = max(localHeightWorld, 0.001)
            let planeDepth = max(localDepthWorld * 1.05, 0.001) // 5% buffer
            let planeVisualHeight = planeHeight * 1.2 // Make planes slightly taller
            let planeVisualDepth = planeDepth * 1.2   // and deeper visually

            let leftPlane = ModelEntity(
                mesh: .generateBox(size: [planeThickness, planeVisualHeight, planeVisualDepth]),
                materials: [SimpleMaterial(color: .blue.withAlphaComponent(0.5), isMetallic: false)]
            )
            leftPlane.name = "LeftPlane"
            // Position bottom of plane at bottom of model
            leftPlane.position = [
                modelBaseWorldX + (leftPlaneOffset * localWidthWorld),
                modelBaseWorldY + (planeVisualHeight / 2.0),
                occluderZ
            ]
            // Use precise collision shape
            leftPlane.components.set(CollisionComponent(shapes: [.generateBox(width: planeThickness, height: planeHeight, depth: planeDepth)]))
            leftPlane.components.set(InputTargetComponent())
            content.add(leftPlane)

            let rightPlane = ModelEntity(
                mesh: .generateBox(size: [planeThickness, planeVisualHeight, planeVisualDepth]),
                materials: [SimpleMaterial(color: .red.withAlphaComponent(0.5), isMetallic: false)]
            )
            rightPlane.name = "RightPlane"
            // Position bottom of plane at bottom of model
            rightPlane.position = [
                modelBaseWorldX + (rightPlaneOffset * localWidthWorld),
                modelBaseWorldY + (planeVisualHeight / 2.0),
                occluderZ
            ]
            // Use precise collision shape
            rightPlane.components.set(CollisionComponent(shapes: [.generateBox(width: planeThickness, height: planeHeight, depth: planeDepth)]))
            rightPlane.components.set(InputTargetComponent())
            content.add(rightPlane)

            // --- 7. Create Initial Occluder Cube ---
            let cubeInitWidth = max(localWidthWorld * (rightPlaneOffset - leftPlaneOffset), 0.01)
            let cubeInitHeight = max(localHeightWorld, 0.01)
            let cubeInitDepth = max(localDepthWorld * 1.05, 0.01) // 5% buffer
            
            let followingCube = ModelEntity(
                mesh: .generateBox(size: [cubeInitWidth, cubeInitHeight, cubeInitDepth]),
                materials: [OcclusionMaterial()]
            )
            followingCube.name = "FollowingCube"
            followingCube.position = [
                modelBaseWorldX + ((leftPlaneOffset + rightPlaneOffset) / 2.0 * localWidthWorld),
                modelBaseWorldY + (cubeInitHeight / 2.0),
                occluderZ
            ]
            content.add(followingCube)

        } update: { content in
            // --- 1. Guard for Entities ---
            guard let leftPlane = content.entities.first(where: { $0.name == "LeftPlane" }) as? ModelEntity,
                  let rightPlane = content.entities.first(where: { $0.name == "RightPlane" }) as? ModelEntity,
                  let followingCube = content.entities.first(where: { $0.name == "FollowingCube" }) as? ModelEntity else {
                return
            }

            // --- 2. Guard for Async State ---
            // Prevent updates until model dimensions are loaded
            guard modelLocalWidth > 0, modelHeightWorld > 0, modelLocalDepth > 0 else {
                return
            }

            // --- 3. Recalculate World Coords from State ---
            let modelBaseWorldX = modelWorldPosition.x + (modelLocalMinX * modelWorldScale.x)
            let modelWidthWorld = modelLocalWidth * modelWorldScale.x
            let modelBaseWorldY = modelWorldPosition.y + (modelLocalMinY * modelWorldScale.y)
            let modelWorldHeight = modelHeightWorld
            let modelWorldDepth = modelLocalDepth * modelWorldScale.z

            // --- 4. Update Slicer Plane Positions (Driven by State) ---
            // Get Y-position from the plane itself, as it's constant
            leftPlane.transform.translation.x = modelBaseWorldX + (leftPlaneOffset * modelWidthWorld)
            rightPlane.transform.translation.x = modelBaseWorldX + (rightPlaneOffset * modelWidthWorld)

            // --- 5. Update Occluder Cube Position and Scale ---
            let cubeMinX = min(leftPlane.transform.translation.x, rightPlane.transform.translation.x)
            let cubeMaxX = max(leftPlane.transform.translation.x, rightPlane.transform.translation.x)
            let cubeWidth = max(0.001, cubeMaxX - cubeMinX)
            let cubeCenterX = cubeMinX + (cubeWidth / 2.0)

            // Use consistent height/depth
            let cubeHeight = max(0.001, modelWorldHeight)
            let cubeDepth = max(0.001, modelWorldDepth * 1.05) // 5% buffer

            // **FIX:** Use modelBaseWorldY for correct vertical alignment
            followingCube.transform.translation = SIMD3<Float>(
                cubeCenterX,
                modelBaseWorldY + (cubeHeight / 2.0),
                occluderZ
            )
            
            // Update the mesh itself
            followingCube.model?.mesh = .generateBox(size: [cubeWidth, cubeHeight, cubeDepth])
            
        }
        .gesture(
            DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
                .targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity
                    let translation = value.translation3D
                    let deltaX = Float(translation.x)

                    // --- Guard for Async State ---
                    let modelWidthWorld = modelLocalWidth * modelWorldScale.x
                    guard modelWidthWorld > 0 else {
                        // Don't allow dragging until model width is calculated
                        return
                    }

                    // --- Get World Coords ---
                    let modelBaseWorldX = modelWorldPosition.x + (modelLocalMinX * modelWorldScale.x)
                    let currentLeftPlaneX = modelBaseWorldX + (leftPlaneOffset * modelWidthWorld)
                    let currentRightPlaneX = modelBaseWorldX + (rightPlaneOffset * modelWidthWorld)

                    // --- Update State Offsets Based on Drag ---
                    if entity.name == "LeftPlane" {
                        var newLeftPlaneX = currentLeftPlaneX + deltaX
                        // Clamp position: [modelBase] ... [rightPlane - thickness]
                        let minLeftX = modelBaseWorldX
                        let maxLeftX = currentRightPlaneX - occluderThickness
                        newLeftPlaneX = max(min(newLeftPlaneX, maxLeftX), minLeftX)
                        
                        // Convert back to relative offset
                        leftPlaneOffset = (newLeftPlaneX - modelBaseWorldX) / modelWidthWorld
                        
                    } else if entity.name == "RightPlane" {
                        var newRightPlaneX = currentRightPlaneX + deltaX
                        // Clamp position: [leftPlane + thickness] ... [modelBase + modelWidth]
                        let minRightX = currentLeftPlaneX + occluderThickness
                        let maxRightX = modelBaseWorldX + modelWidthWorld
                        newRightPlaneX = max(min(newRightPlaneX, maxRightX), minRightX)
                        
                        // Convert back to relative offset
                        rightPlaneOffset = (newRightPlaneX - modelBaseWorldX) / modelWidthWorld
                    }
                }
        )
        .overlay(alignment: .bottom) {
            // Your UI overlay
            VStack {
                ToggleImmersiveSpaceButton()
            }
            .padding(24)
            .background(.black.opacity(0.5))
            .cornerRadius(16)
            .offset(z: -0.5) // Push UI back slightly
        }
    }
}
