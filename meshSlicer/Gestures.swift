import SwiftUI
import RealityKit

struct Gestures {
    static func dragGesture(modelEntity: Binding<ModelEntity?>, initialTransform: Binding<Transform?>) -> some Gesture {
        DragGesture()
            .targetedToAnyEntity()
            .onChanged { value in
                if modelEntity.wrappedValue == nil {
                    modelEntity.wrappedValue = value.entity as? ModelEntity
                }
                guard let model = modelEntity.wrappedValue else { return }
                
                if initialTransform.wrappedValue == nil {
                    initialTransform.wrappedValue = model.transform
                }
                let convertedTranslation = value.convert(value.translation3D, from: .local, to: model.parent!)

                var newTransform = initialTransform.wrappedValue!
                newTransform.translation += SIMD3<Float>(convertedTranslation)
                model.transform = newTransform
            }
            .onEnded { _ in
                initialTransform.wrappedValue = nil
                modelEntity.wrappedValue = nil
            }
    }

    static func rotationGesture(modelEntity: Binding<ModelEntity?>, initialRotation: Binding<simd_quatf?>) -> some Gesture {
        RotateGesture3D(minimumAngleDelta: .degrees(1)) // Removed constrainedToAxis: .z for full 3D rotation
            .targetedToAnyEntity()
            .onChanged { value in
                if modelEntity.wrappedValue == nil {
                    modelEntity.wrappedValue = value.entity as? ModelEntity
                }
                
                guard let model = modelEntity.wrappedValue else { return }

                if initialRotation.wrappedValue == nil {
                    initialRotation.wrappedValue = model.transform.rotation
                }

                let gestureRotation = simd_quatf(value.rotation)
                model.transform.rotation = initialRotation.wrappedValue! * gestureRotation
            }
            .onEnded { _ in
                initialRotation.wrappedValue = nil
                modelEntity.wrappedValue = nil
            }
    }
}
