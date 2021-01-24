/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Helper Functions
*/

import RealityKit

/// Given three points of a triangle, returns the normal of the resulting face
/// - Parameter pointA: First point of the triangle
/// - Parameter pointB: Second point of the triangle
/// - Parameter pointC: Third point of the triangle
/// - Returns: The normal of the specified triangle
public func getTriNormal(pointA: SIMD3<Float>, pointB: SIMD3<Float>, pointC: SIMD3<Float>) -> SIMD3<Float> {
    return simd.normalize(simd.cross(pointB - pointA, pointC - pointA))
}

/// Lerps between two vector over time
///  - Parameter vectorA: The "from" vector
///  - Parameter vectorB: the "to" vector
///  - Parameter timeInterval:A clamped `Float` representing how far along the lerp (e.g 0.5 = half way)
///  - Returns: The resulting vector
public func lerp(vectorA: SIMD3<Float>, vectorB: SIMD3<Float>, timeInterval: Float) -> SIMD3<Float> {
    return vectorA + (timeInterval * (vectorB - vectorA))
}

/// Constrains a value to an inclusive range
/// - Parameter value: The value to constrain
/// - Parameter minValue: The smallest allowed value
/// - Parameter maxValue: The highest allowed value
/// - Returns: The constrained (clamped) value
public func clampValue<T>(_ value: T, _ minValue: T, _ maxValue: T) -> T where T: Comparable {
    return min(max(value, minValue), maxValue)
}
