import ARKit
import Combine
import Foundation
import os.log
import RealityKit
import UIKit

private let log = OSLog(subsystem: appSubsystem, category: "Extensions")

extension String {
    func leftPadding(toLength newLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < newLength {
            return String(repeatElement(character, count: newLength - stringLength)) + self
        } else {
            return String(self.suffix(newLength))
        }
    }
}

extension Float {
    // Return the constant needed to convert degrees to radians
    static let degreesToRadians: Float = (.pi / 180)

    // Return the linear interpolation between two values at supplied "progress"
    static func lerp(_ value1: Float, _ value2: Float, progress: Float) -> Float {
        return value1 + ((value2 - value1) * progress)
    }

    // Returns the "progress" value that yields the lerp output value within the range [value1, value2]
    static func inverseLerp(_ value1: Float, _ value2: Float, lerpOutput: Float) -> Float {
        var delta = value2 - value1
        if delta == 0.0 {
            log.error("Preventing divide by zero.")
            delta = 1.0
        }
        return (lerpOutput - value1) / delta
    }

    var dotTwoDescription: String { String(format: "%0.2f", self) }
}

extension SIMD2 where Scalar == Float {
    // Returns the magnitude of the two points that comprise the 2d Vector
    func magnitude() -> Float {
        return sqrtf(x * x + y * y)
    }

    var terseDescription: String { "\(x), \(y)" }
    var dotFourDescription: String { String(format: "(%0.4f, %0.4f)", x, y) }
    var dotTwoDescription: String { String(format: "(%0.2f, %0.2f)", x, y) }
    var fiveDotTwoDescription: String { String(format: "(%5.2f, %5.2f)", x, y) }
}

extension SIMD3 where Scalar == Float {
    // Determine if the vector is pointing somewhat upward in 3d space.
    // Threshold for upwardness expressed as a constant value
    func isUpwardPointing() -> Bool {
        let thresholdForUpwardPointingAngle = Float.pi / 8
        let dotProduct = simd.dot(normalize(self), SIMD3<Float>(0, 1, 0))
        let thetaOffset = simd.acos(dotProduct)
        return thetaOffset <= thresholdForUpwardPointingAngle
    }

    var terseDescription: String { "\(x), \(y), \(z)" }
    var dotFourDescription: String { String(format: "(%0.4f, %0.4f, %0.4f)", x, y, z) }
    var dotTwoDescription: String { String(format: "(%0.2f, %0.2f, %0.2f)", x, y, z) }
    var fiveDotTwoDescription: String { String(format: "(%5.2f, %5.2f, %5.2f)", x, y, z) }
}

extension simd_quatf {
    // Returns a new quaternion representing only the Y-Axis rotation of the original Quaternion
    func yaw() -> simd_quatf {
        var quat = self
        quat.vector[0] = 0
        quat.vector[2] = 0
        let mag = sqrt(quat.vector[3] * quat.vector[3] + quat.vector[1] * quat.vector[1])
        // Magnitude is always positive.
        if mag > 0 {
            quat.vector[3] /= mag
            quat.vector[1] /= mag
        }
        return quat
    }
    // The identity quaternion
    static let identity = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
}

extension float4x4 {
    init(translation: SIMD3<Float>) {
        self = matrix_identity_float4x4
        columns.3.x = translation.x
        columns.3.y = translation.y
        columns.3.z = translation.z
    }

    init(rotationX angle: Float) {
        self = matrix_identity_float4x4
        columns.1.y = cos(angle)
        columns.1.z = sin(angle)
        columns.2.y = -sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationY angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.z = -sin(angle)
        columns.2.x = sin(angle)
        columns.2.z = cos(angle)
    }

    init(rotationZ angle: Float) {
        self = matrix_identity_float4x4
        columns.0.x = cos(angle)
        columns.0.y = sin(angle)
        columns.1.x = -sin(angle)
        columns.1.y = cos(angle)
    }

    init(rotation angle: SIMD3<Float>) {
        let rotationX = float4x4(rotationX: angle.x)
        let rotationY = float4x4(rotationY: angle.y)
        let rotationZ = float4x4(rotationZ: angle.z)
        self = rotationX * rotationY * rotationZ
    }

    init(projectionFov fov: Float, near: Float, far: Float, aspect: Float, lhs: Bool = true) {
        let yValue = 1 / tan(fov * 0.5)
        let xValue = yValue / aspect
        let zValue = lhs ? far / (far - near) : far / (near - far)
        let x2Value = SIMD4<Float>(xValue, 0, 0, 0)
        let y2Value = SIMD4<Float>(0, yValue, 0, 0)
        let z2Value = lhs ? SIMD4<Float>(0, 0, zValue, 1) : SIMD4<Float>(0, 0, zValue, -1)
        let wValue = lhs ? SIMD4<Float>(0, 0, zValue * -near, 0) : SIMD4<Float>(0, 0, zValue * near, 0)
        self.init()
        columns = (x2Value, y2Value, z2Value, wValue)
    }

    var upVector: SIMD3<Float> {
        return SIMD3<Float>(columns.1.x, columns.1.y, columns.1.z)
    }

    var rightVector: SIMD3<Float> {
        return SIMD3<Float>(columns.0.x, columns.0.y, columns.0.z)
    }

    var forwardVector: SIMD3<Float> {
        return SIMD3<Float>(-columns.2.x, -columns.2.y, -columns.2.z)
    }

    var position: SIMD3<Float> {
        return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
    }
}

extension UIViewController {
    public func showAlert(title: String, message: String? = nil, actions: [UIAlertAction]? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let actions = actions {
            actions.forEach { alertController.addAction($0) }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        present(alertController, animated: true, completion: nil)
    }
}

extension UIView {
    func fadeIn(duration: TimeInterval = 1.0, delay: TimeInterval = 0.0,
                completion: @escaping ((Bool) -> Void) = { (finished: Bool) -> Void in }) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn, animations: {
            self.alpha = 1.0
        }, completion: completion)
    }

    func fadeOut(duration: TimeInterval = 1.0, delay: TimeInterval = 3.0,
                 completion: @escaping (Bool) -> Void = { (finished: Bool) -> Void in }) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn, animations: {
            self.alpha = 0.0
        }, completion: completion)
    }
}
