/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Reality Kit Helpers
*/

import ARKit
import Foundation
import os.log
import RealityKit

private let log = OSLog(subsystem: appSubsystem, category: "RealityKit+Helpers")

extension Entity {
    func visit(using block: (Entity) -> Void) {
        block(self)
        for child in children {
            child.visit(using: block)
        }
    }

    func resetPhysics() {
        if let physicsEntity = self as? (HasPhysics & HasCollision) {
            physicsEntity.physicsMotion?.angularVelocity = .zero
            physicsEntity.physicsMotion?.linearVelocity = .zero
        }
    }
}

extension ARMeshGeometry {
    // Returns a vertex point in 3d space corresponding to a particular index
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }

    // To get the mesh's classification, parse the classification's raw data
    // and instantiate an `ARMeshClassification` object.
    // For efficiency, ARKit stores classifications in a Metal buffer in `ARMeshGeometry`.
    func classificationOf(faceWithIndex index: Int) -> ARMeshClassification {
        guard let classification = classification else { return .none }
        assert(classification.format == MTLVertexFormat.uchar,
               "Expected one unsigned char (one byte) per classification")
        let classificationPointer =
            classification.buffer.contents().advanced(by: classification.offset + (classification.stride * index))
        let classificationValue = Int(classificationPointer.assumingMemoryBound(to: CUnsignedChar.self).pointee)
        return ARMeshClassification(rawValue: classificationValue) ?? .none
    }

    // Derives a list of vertex indices from the index of a specific face
    func vertexIndicesOf(faceWithIndex faceIndex: Int) -> [UInt32] {
        assert(faces.bytesPerIndex == MemoryLayout<UInt32>.size, "Expected one UInt32 (four bytes) per vertex index")
        let vertexCountPerFace = faces.indexCountPerPrimitive
        let vertexIndicesPointer = faces.buffer.contents()
        var vertexIndices = [UInt32]()
        vertexIndices.reserveCapacity(vertexCountPerFace)
        for vertexOffset in 0..<vertexCountPerFace {
            let advanceAmount = (faceIndex * vertexCountPerFace + vertexOffset) * MemoryLayout<UInt32>.size
            let vertexIndexPointer = vertexIndicesPointer.advanced(by: advanceAmount)
            vertexIndices.append(vertexIndexPointer.assumingMemoryBound(to: UInt32.self).pointee)
        }
        return vertexIndices
    }

    // Returns the vertex point vectors belonging to an index of a specific face
    func verticesOf(faceWithIndex index: Int) -> [SIMD3<Float>] {
        let vertexIndices = vertexIndicesOf(faceWithIndex: index)
        let vertices = vertexIndices.map { vertex(at: $0) }
        return vertices
    }

    // Derives the geometric center of a face of a specific index
    func centerOf(faceWithIndex index: Int) -> SIMD3<Float> {
        let vertices = verticesOf(faceWithIndex: index)
        let sum = vertices.reduce(SIMD3<Float>(0, 0, 0)) { SIMD3<Float>($0[0] + $1[0], $0[1] + $1[1], $0[2] + $1[2]) }
        let geometricCenter = SIMD3<Float>(sum[0] / 3, sum[1] / 3, sum[2] / 3)
        return geometricCenter
    }
}

extension ARCamera {
    // Returns a transform with a flipped Y rotation, because Metal uses the
    // left-handed coordinate system.
    var metalTransform: float4x4 {
        let flipperEuler = SIMD3<Float>(0, self.eulerAngles.y - .pi, 0)
        let convertedCameraTransform = Transform(
            scale: SIMD3<Float>(1, 1, 1),
            rotation: Transform(matrix: float4x4(rotation: flipperEuler)).rotation,
            translation: self.transform.position)
        return convertedCameraTransform.matrix
    }
}

//extension Entity {
//    @available(iOS 14.0, macOS 10.16, *)
//    public func attachDebugModelComponent(_ debugModel: DebugModelComponent) {
//        components.set(debugModel)
//        children.forEach { $0.attachDebugModelComponent(debugModel) }
//    }
//
//    @available(iOS 14.0, macOS 10.16, *)
//    public func removeDebugModelComponent() {
//        components[DebugModelComponent.self] = nil
//        children.forEach { $0.removeDebugModelComponent() }
//    }
//
//    public func shaderDebug(_ index: Int) {
//        guard #available(iOS 14.0, macOS 10.16, *) else { return }
//
//        var mewDebugModel: DebugModelComponent?
//        switch index {
//        case 0: mewDebugModel = nil
//        case 1: mewDebugModel = DebugModelComponent(shaderDebugMode: .baseColor)
//        case 2: mewDebugModel = DebugModelComponent(shaderDebugMode: .normal)
//        case 3: mewDebugModel = DebugModelComponent(shaderDebugMode: .textureCoordinates)
//        default: mewDebugModel = nil
//        }
//
//        if let mewDebugModel = mewDebugModel {
//            attachDebugModelComponent(mewDebugModel)
//        } else {
//            removeDebugModelComponent()
//        }
//    }
//}

extension Entity {
    public func forEachInHierarchy(depth: Int = 0, closure: (Entity, Int) throws -> Void) rethrows {
        try closure(self, depth)
        for child in children {
            try child.forEachInHierarchy(depth: depth + 1, closure: closure)
        }
    }

    static let tabSpace = String(repeating: " ", count: 4)
    public func treeDescription(_ parentDepth: Int = 0, maxDepth: Int = Int.max) -> String {
        let depth = parentDepth + 1

        let indent = String(repeating: Entity.tabSpace, count: depth)
        var string = "\(indent)\(name)"

        if let modelEntity = self as? HasModel,
            let modelComponent = modelEntity.model,
            !modelComponent.materials.isEmpty {
            string += "(\(modelComponent.materials.count))"
        }

        if !children.isEmpty {
            if depth < maxDepth {
                string += " {\n" + children.map { $0.treeDescription(depth, maxDepth: maxDepth) }
                    .joined(separator: ",\n") + "\n\(indent)}"
            } else {
                string += " {\n\(indent + Entity.tabSpace)...\n\(indent)}"
            }
        }
        return string
    }
}

extension HasModel {
    public func replaceMaterial(_ index: Int, with material: Material) {
        guard index >= 0, index < model?.materials.count ?? 0 else {
            let materialCount = model?.materials.count ?? 0
            fatalError(String(format: "replaceMaterial() index %d out of range (%d)", index, materialCount))
        }
        model?.materials[index] = material
    }
}

extension Entity {
    // installMaterial by material index, and debug support
    // the debug support is a way to keep a debug material index offset to
    // experiment with cycling which material is being replaced at runtime
    public func installMaterial(_ material: Material,
                                modelEntityName: String,
                                materialIndex: Int,
                                offset materialIndexOffset: Int = -1) -> (Bool, Int) {
        let useOffset = materialIndexOffset >= 0
        var newIndexOffset = materialIndexOffset + 1

        // once we have replaced a material, we are done searching...
        var success = false
        forEachInHierarchy { (entity, _) in
            guard !success else { return }
            guard let modelEntity = entity as? HasModel,
                let modelComponent = modelEntity.model else { return }
            if modelEntity.name.contains(modelEntityName) {
                // debug feature to allow runtime shifting of which material
                // index to replace so that a visual verification can be
                // used to determine which is the correct index
                let materialCount = modelComponent.materials.count
                var index = materialIndex
                if useOffset {
                    index += newIndexOffset
                    if index >= materialCount {
                        index -= materialCount
                    }
                }

                modelEntity.replaceMaterial(index, with: material)

                // make sure the return material index offset is valid
                if useOffset {
                    newIndexOffset = index - materialIndex
                    if newIndexOffset < 0 {
                        newIndexOffset += materialCount
                    }
                }

                log.debug("Entity '%s' material %d replaced (base=%d, offset=%d",
                          "\(name)",
                          index,
                          materialIndex,
                          newIndexOffset)
                success = true
            }
        }
        return (success, useOffset ? newIndexOffset : -1)
    }
}

extension ARView {

    func updateDebugOptions(_ newDebugOptions: ARView.DebugOptions, _ enableDisable: Bool) {
        // only update if changed
        guard enableDisable != debugOptions.contains(newDebugOptions) else { return }
        if enableDisable {
            debugOptions.insert(newDebugOptions)
        } else {
            debugOptions.remove(newDebugOptions)
        }
    }

    func updateRenderOptions(_ newRenderOptions: ARView.RenderOptions, _ enableDisable: Bool) {
        // only update if changed
        guard enableDisable != renderOptions.contains(newRenderOptions) else { return }
        if enableDisable {
            renderOptions.insert(newRenderOptions)
        } else {
            renderOptions.remove(newRenderOptions)
        }
    }

    func updateSceneUnderstandingOptions(_ newSceneUnderstandingOptions: ARView.Environment.SceneUnderstanding.Options,
                                         _ enableDisable: Bool) {
        // only update if changed
        guard enableDisable != environment.sceneUnderstanding.options.contains(newSceneUnderstandingOptions) else {
            return
        }
        if enableDisable {
            environment.sceneUnderstanding.options.insert(newSceneUnderstandingOptions)
        } else {
            environment.sceneUnderstanding.options.remove(newSceneUnderstandingOptions)
        }
    }

}
