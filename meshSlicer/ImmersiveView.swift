import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    
    let modelName = "CHARIS KRISNA MUKTI_ TN_Mandibula_001"

    @State private var modelEntityForGesture: ModelEntity? = nil
    @State private var initialTransformForGesture: Transform? = nil
    @State private var initialRotationForGesture: simd_quatf? = nil
    let modelWorldPosition: SIMD3<Float> = [0, 0.3, -0.2]
    let modelWorldScale: SIMD3<Float> = [0.01, 0.01, 0.01]
    
    @State private var modelHeightWorld: Float = 0.001
    @State private var modelLocalMinY: Float = 0.0
    @State private var modelLocalMaxY: Float = 0.0
    @State private var modelLocalMinX: Float = 0.0
    @State private var modelLocalMaxX: Float = 0.0
    @State private var modelLocalWidth: Float = 0.0
    @State private var modelLocalDepth: Float = 0.0
    @State private var modelLocalMinZ: Float = 0.0 // New state for min Z
    @State private var modelLocalMaxZ: Float = 0.0 // New state for max Z

    @State private var leftPlaneOffset: Float = 0.25
    @State private var rightPlaneOffset: Float = 0.75
    @State private var leftPlaneYPosition: Float = 0.0
    @State private var rightPlaneYPosition: Float = 0.0
    @State private var leftPlaneZPosition: Float = -0.2 // New state for Z position
    @State private var rightPlaneZPosition: Float = -0.2 // New state for Z position
    let occluderThickness: Float = 0.002
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
            model.components.set(InputTargetComponent()) 
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
                modelLocalMinZ = localBounds.min.z // New: Update min Z
                modelLocalMaxZ = localBounds.max.z // New: Update max Z
                modelHeightWorld = localHeight * modelWorldScale.y
                
                // Initialize Z positions based on model's initial Z
                leftPlaneZPosition = modelWorldPosition.z + (localBounds.min.z * modelWorldScale.z) + (localDepth * modelWorldScale.z / 2.0)
                rightPlaneZPosition = modelWorldPosition.z + (localBounds.min.z * modelWorldScale.z) + (localDepth * modelWorldScale.z / 2.0)
            }

            let modelBaseWorldY = modelWorldPosition.y + (localMinY * modelWorldScale.y)
            let modelBaseWorldX = modelWorldPosition.x + (localBounds.min.x * modelWorldScale.x)
            let modelBaseWorldZ = modelWorldPosition.z + (localBounds.min.z * modelWorldScale.z) // New: Base Z for model
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
            let planeDepth = max(localDepthWorld * 1.05, 0.001) 
            let planeVisualHeight = planeHeight * 1.2 
            let planeVisualDepth = planeDepth * 1.2   

            DispatchQueue.main.async {
                leftPlaneYPosition = modelBaseWorldY + (planeVisualHeight / 2.0)
                rightPlaneYPosition = modelBaseWorldY + (planeVisualHeight / 2.0)
            }

            let leftPlane = ModelEntity(
                mesh: .generateBox(size: [planeThickness, planeVisualHeight, planeVisualDepth]),
                materials: [SimpleMaterial(color: .blue.withAlphaComponent(0.5), isMetallic: false)]
            )
            leftPlane.name = "LeftPlane"
            leftPlane.position = [
                modelBaseWorldX + (leftPlaneOffset * localWidthWorld),
                leftPlaneYPosition,
                leftPlaneZPosition // Use new Z position
            ]
            leftPlane.components.set(CollisionComponent(shapes: [.generateBox(width: planeThickness, height: planeHeight, depth: planeDepth)]))
            leftPlane.components.set(InputTargetComponent())
            content.add(leftPlane)

            let rightPlane = ModelEntity(
                mesh: .generateBox(size: [planeThickness, planeVisualHeight, planeVisualDepth]),
                materials: [SimpleMaterial(color: .red.withAlphaComponent(0.5), isMetallic: false)]
            )
            rightPlane.name = "RightPlane"
            rightPlane.position = [
                modelBaseWorldX + (rightPlaneOffset * localWidthWorld),
                rightPlaneYPosition,
                rightPlaneZPosition // Use new Z position
            ]
            rightPlane.components.set(CollisionComponent(shapes: [.generateBox(width: planeThickness, height: planeHeight, depth: planeDepth)]))
            rightPlane.components.set(InputTargetComponent())
            content.add(rightPlane)

            let cubeInitWidth = max(localWidthWorld * (rightPlaneOffset - leftPlaneOffset), 0.01)
            let cubeInitHeight = max(localHeightWorld, 0.01)
            let cubeInitDepth = max(localDepthWorld * 1.05, 0.01) 
            
            let followingCube = ModelEntity(
                mesh: .generateBox(size: [cubeInitWidth, cubeInitHeight, cubeInitDepth]),
                materials: [OcclusionMaterial()]
            )
            followingCube.name = "FollowingCube"
            followingCube.position = [
                modelBaseWorldX + ((leftPlaneOffset + rightPlaneOffset) / 2.0 * localWidthWorld),
                (leftPlaneYPosition + rightPlaneYPosition) / 2.0,
                (leftPlaneZPosition + rightPlaneZPosition) / 2.0 // Use average Z position
            ]
            content.add(followingCube)

        } update: { content in
            guard let leftPlane = content.entities.first(where: { $0.name == "LeftPlane" }) as? ModelEntity,
                  let rightPlane = content.entities.first(where: { $0.name == "RightPlane" }) as? ModelEntity,
                  let followingCube = content.entities.first(where: { $0.name == "FollowingCube" }) as? ModelEntity else {
                return
            }

            guard modelLocalWidth > 0, modelHeightWorld > 0, modelLocalDepth > 0 else {
                return
            }

            let modelBaseWorldX = modelWorldPosition.x + (modelLocalMinX * modelWorldScale.x)
            let modelWidthWorld = modelLocalWidth * modelWorldScale.x
            let modelBaseWorldY = modelWorldPosition.y + (modelLocalMinY * modelWorldScale.y)
            let modelBaseWorldZ = modelWorldPosition.z + (modelLocalMinZ * modelWorldScale.z) // New: Base Z for model
            let modelWorldHeight = modelHeightWorld
            let modelWorldDepth = modelLocalDepth * modelWorldScale.z

            leftPlane.transform.translation.x = modelBaseWorldX + (leftPlaneOffset * modelWidthWorld)
            leftPlane.transform.translation.y = leftPlaneYPosition
            leftPlane.transform.translation.z = leftPlaneZPosition // Update Z position
            rightPlane.transform.translation.x = modelBaseWorldX + (rightPlaneOffset * modelWidthWorld)
            rightPlane.transform.translation.y = rightPlaneYPosition
            rightPlane.transform.translation.z = rightPlaneZPosition // Update Z position

            let cubeMinX = min(leftPlane.transform.translation.x, rightPlane.transform.translation.x)
            let cubeMaxX = max(leftPlane.transform.translation.x, rightPlane.transform.translation.x)
            let cubeWidth = max(0.001, cubeMaxX - cubeMinX)
            let cubeCenterX = cubeMinX + (cubeWidth / 2.0)

            let cubeHeight = max(0.001, modelWorldHeight)
            let cubeDepth = max(0.001, modelWorldDepth * 1.05) 

            followingCube.transform.translation = SIMD3<Float>(
                cubeCenterX,
                (leftPlaneYPosition + rightPlaneYPosition) / 2.0,
                (leftPlaneZPosition + rightPlaneZPosition) / 2.0 // Update Z position
            )
            
            followingCube.model?.mesh = .generateBox(size: [cubeWidth, cubeHeight, cubeDepth])
            
        }
        .gesture(
            Gestures.dragGesture(modelEntity: $modelEntityForGesture, initialTransform: $initialTransformForGesture)
                .exclusively(before: Gestures.rotationGesture(modelEntity: $modelEntityForGesture, initialRotation: $initialRotationForGesture))
        )
        .gesture(
            DragGesture(minimumDistance: 0.0, coordinateSpace: .global)
                .targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity
                    let translation = value.translation3D
                    let deltaX = Float(translation.x)
                    let deltaY = Float(translation.y)
                    let deltaZ = Float(translation.z) // New: Get deltaZ

                    let modelWidthWorld = modelLocalWidth * modelWorldScale.x
                    let modelHeightWorld = modelHeightWorld 
                    let modelDepthWorld = modelLocalDepth * modelWorldScale.z // New: Model world depth
                    guard modelWidthWorld > 0, modelHeightWorld > 0, modelDepthWorld > 0 else { // New: Guard modelDepthWorld
                        return
                    }

                    let modelBaseWorldX = modelWorldPosition.x + (modelLocalMinX * modelWorldScale.x)
                    let currentLeftPlaneX = modelBaseWorldX + (leftPlaneOffset * modelWidthWorld)
                    let currentRightPlaneX = modelBaseWorldX + (rightPlaneOffset * modelWidthWorld)

                    let modelBaseWorldY = modelWorldPosition.y + (modelLocalMinY * modelWorldScale.y)
                    let planeVisualHeight = (modelLocalMaxY - modelLocalMinY) * modelWorldScale.y * 1.2

                    let minYClamp = modelBaseWorldY + (planeVisualHeight / 2.0)
                    let maxYClamp = modelBaseWorldY + modelHeightWorld - (planeVisualHeight / 2.0)

                    // New: Z-axis clamping
                    let modelBaseWorldZ = modelWorldPosition.z + (modelLocalMinZ * modelWorldScale.z)
                    let planeVisualDepth = (modelLocalMaxZ - modelLocalMinZ) * modelWorldScale.z * 1.2
                    let minZClamp = modelBaseWorldZ + (planeVisualDepth / 2.0)
                    let maxZClamp = modelBaseWorldZ + modelDepthWorld - (planeVisualDepth / 2.0)


                    if entity.name == "LeftPlane" {
                        var newLeftPlaneX = currentLeftPlaneX + deltaX
                        let minLeftX = modelBaseWorldX
                        let maxLeftX = currentRightPlaneX - occluderThickness
                        newLeftPlaneX = max(min(newLeftPlaneX, maxLeftX), minLeftX)
                        leftPlaneOffset = (newLeftPlaneX - modelBaseWorldX) / modelWidthWorld

                        var newLeftPlaneY = leftPlaneYPosition + deltaY
                        newLeftPlaneY = max(min(newLeftPlaneY, maxYClamp), minYClamp)
                        leftPlaneYPosition = newLeftPlaneY
                        
                        var newLeftPlaneZ = leftPlaneZPosition + deltaZ // New: Update Z position
                        newLeftPlaneZ = max(min(newLeftPlaneZ, maxZClamp), minZClamp) // New: Clamp Z position
                        leftPlaneZPosition = newLeftPlaneZ // New: Assign Z position
                        
                    } else if entity.name == "RightPlane" {
                        var newRightPlaneX = currentRightPlaneX + deltaX
                        let minRightX = currentLeftPlaneX + occluderThickness
                        let maxRightX = modelBaseWorldX + modelWidthWorld
                        newRightPlaneX = max(min(newRightPlaneX, maxRightX), minRightX)
                        rightPlaneOffset = (newRightPlaneX - modelBaseWorldX) / modelWidthWorld

                        var newRightPlaneY = rightPlaneYPosition + deltaY
                        newRightPlaneY = max(min(newRightPlaneY, maxYClamp), minYClamp)
                        rightPlaneYPosition = newRightPlaneY

                        var newRightPlaneZ = rightPlaneZPosition + deltaZ // New: Update Z position
                        newRightPlaneZ = max(min(newRightPlaneZ, maxZClamp), minZClamp) // New: Clamp Z position
                        rightPlaneZPosition = newRightPlaneZ // New: Assign Z position
                    }
                }
        )
        .overlay(alignment: .bottom) {
            VStack {
                ToggleImmersiveSpaceButton()
            }
            .padding(24)
            .background(.black.opacity(0.5))
            .cornerRadius(16)
            .offset(z: -0.5) 
        }
    }
}
