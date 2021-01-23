import Foundation
import UIKit
import ARKit
import RealityKit
import Combine
import CoreMotion

protocol InputSystemDelegate: AnyObject {
    func playerUpdatedTouchTrail(touchTransform: Transform)
}

class InputSystem: UIGestureRecognizer {
    public var arView: ARView!

    // Touch input variables
    private var panVelocity = SIMD2<Float>.zero
    private var previousTouchPosition: CGPoint!

    private let motion = CMMotionManager()

    // The Tractor Beam allows you to carry a creature around with you
    private let cameraCarryOffset: SIMD3<Float> = [0, 0, 0.4]

    private let flingVelocityMetersPerPoint: Float

    public weak var inputSystemDelegate: InputSystemDelegate?

    override init(target: Any?, action: Selector?) {
        // calculate screen space (points) to world space (meters) conversion based on this device
        flingVelocityMetersPerPoint = Constants.flingVerticalScale / Float(UIScreen.main.bounds.height)
        super.init(target: target, action: action)
        motion.accelerometerUpdateInterval = 1.0 / Double(Constants.accelerometerFramesPerSecond)
        motion.startAccelerometerUpdates()
    }

    public func setupDependencies(arView: ARView) {
        self.arView = arView
        previousTouchPosition = arView.center
    }

    override func reset() {
        super.reset()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first else { return }
        // Initialize this new touch
        let touchStartPosition = touch.location(in: view)
        previousTouchPosition = touchStartPosition
        panVelocity = .zero
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first else { return }
        let currentTouchPosition = touch.location(in: view)

        // Track pan velocity from position delta. Note: Screen is (0,0) in top left corner
        panVelocity.x = Float(currentTouchPosition.x) - Float(previousTouchPosition?.x ?? 0)
        panVelocity.y = -1 * (Float(currentTouchPosition.y) - Float(previousTouchPosition?.y ?? 0))
        previousTouchPosition = currentTouchPosition
        // If you're not carrying a creature, you may engage the touch trail
        updateTouchTrail()
    }

    func updateTouchTrail() {
        guard let surfaceTransform = surfaceTransformFromTouchPosition() else { return }
        inputSystemDelegate?.playerUpdatedTouchTrail(touchTransform: surfaceTransform)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        reset()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        reset()
    }

    public func worldspaceTouchPosition() -> SIMD3<Float> {
        cgPointToWorldspace(previousTouchPosition,
                            offsetFromCamera: cameraCarryOffset)
    }

    func cgPointToWorldspace(_ cgPoint: CGPoint, offsetFromCamera: SIMD3<Float>) -> SIMD3<Float> {
        // Get position of camera plane
        let camForwardPoint = arView.cameraTransform.matrix.position +
            (arView.cameraTransform.matrix.forwardVector * offsetFromCamera.z)
        var col0 = SIMD4<Float>(1, 0, 0, 0)
        var col1 = SIMD4<Float>(0, 1, 0, 0)
        var col2 = SIMD4<Float>(0, 0, 1, 0)
        var col3 = SIMD4<Float>(camForwardPoint.x, camForwardPoint.y, camForwardPoint.z, 1)
        let planePosMatrix = float4x4(col0, col1, col2, col3)

        // Get initial rotation of camera plane
        let camRotMatrix = float4x4(arView.cameraTransform.rotation)

        // Get rotation offset: Y-up is considered the plane's normal, so we
        // rotate the plane around its X-axis by 90 degrees.
        col0 = SIMD4<Float>(1, 0, 0, 0)
        col1 = SIMD4<Float>(0, 0, 1, 0)
        col2 = SIMD4<Float>(0, -1, 0, 0)
        col3 = SIMD4<Float>(0, 0, 0, 1)
        let axisFlipMatrix = float4x4(col0, col1, col2, col3)

        let rotatedPlaneAtPoint = planePosMatrix * camRotMatrix * axisFlipMatrix
        let projectionAtRotatedPlane = arView.unproject(cgPoint, ontoPlane: rotatedPlaneAtPoint) ?? camForwardPoint
        let verticalOffset = arView.cameraTransform.matrix.upVector * offsetFromCamera.y
        let horizontalOffset = arView.cameraTransform.matrix.rightVector * offsetFromCamera.x
        return projectionAtRotatedPlane + verticalOffset + horizontalOffset
    }

    func surfaceTransformFromTouchPosition() -> Transform? {
        let pointA = cgPointToWorldspace(previousTouchPosition,
                                         offsetFromCamera: SIMD3<Float>(0, 0, 0.01))
        let pointB = cgPointToWorldspace(previousTouchPosition,
                                         offsetFromCamera: SIMD3<Float>(0, 0, 0.02))
        let query = ARRaycastQuery(origin: pointA,
                                   direction: normalize(pointB - pointA),
                                   allowing: .estimatedPlane,
                                   alignment: .any)
        guard let hit = arView.session.raycast(query).first else { return nil }
        return Transform(matrix: hit.worldTransform)
    }
}
