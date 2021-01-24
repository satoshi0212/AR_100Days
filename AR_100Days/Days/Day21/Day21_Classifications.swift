import ARKit

class Day21_Classifications {
    public static var isUpdating: Bool = false
    private static var classifications = [simd_int3: ARMeshClassification]()

    public static func classification(_ coordinates: simd_int3) -> ARMeshClassification? {
        return classifications[coordinates]
    }

    public static func newClassification(_ coordinates: simd_int3, classification: ARMeshClassification) {
        classifications[coordinates] = classification
    }

    public static var numClassifications: Int {
        return classifications.count
    }

    public static func reset() {
        classifications.removeAll()
        isUpdating = false
    }
}
