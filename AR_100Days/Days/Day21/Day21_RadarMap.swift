import MetalKit
import ARKit
import Combine
import RealityKit

class Day21_RadarMap {
    private enum RadarAnimationState {
        case fullscreen
        case transitionToMinimap
        case minimap
        case transitionToFullscreen
    }

    private var radarState: RadarAnimationState = .fullscreen
    private var view: UIView = UIView()
    private var mask = UIView()
    private var metalView: MTKView
    private var renderer: MetalRenderer
    private var newCategories = [SIMD3<Float>: ARMeshClassification]()
    private var bugTransforms = [float4x4]()
    private var camera = Day21_CustomCameraComponent()
    private let cameraDistance: Float = 7.5 // five meters overhead
    private let animationTime: TimeInterval = 4 // cannot be zero
    private var animationStartTime: TimeInterval?
    private var animationCallback: (() -> Void)?

    private var cameraHead = float4x4(translation: SIMD3<Float>()) // rotates
    private var cameraOffset = float4x4(translation: SIMD3<Float>()) // dollies away
    private var transitionOrigin = Transform()

    public var startFrame: CGRect
    private var targetFrame: CGRect
    private let blurStartFrame: CGRect

    private let blurView: UIVisualEffectView
    private let ringView: UIView //UIImageView

    private let nearClipPlane: CGFloat = 0.001
    private let farClipPlane: CGFloat = 100

    private let pointSizeFullscreen: Float = 6
    private let pointSizeMinimap: Float = 4

    public var isFullScreen: Bool { radarState == .fullscreen }

    required init(frame: CGRect, from: CGRect) {
        targetFrame = frame
        startFrame = from
        let blurEffect = UIBlurEffect(style: .light)
        blurView = UIVisualEffectView(effect: blurEffect)
        ringView = UIView(frame: blurView.frame)
        ringView.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.2)
        ringView.alpha = 0
        ringView.clipsToBounds = true
        view.addSubview(ringView)
        view.addSubview(blurView)
        metalView = MTKView(frame: from)
        metalView.isOpaque = false
        metalView.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.addSubview(metalView)
        renderer = MetalRenderer(metalView)
        renderer.drawRectResized(size: metalView.bounds.size)
        let radius = sqrt((from.width / 2) * (from.width / 2) + (from.height / 2) * (from.height / 2))
        blurView.frame.size = CGSize(width: radius * 2, height: radius * 2)
        blurView.center = view.center
        blurView.frame.origin.y = Day21_Constants.radar2DLocation.origin.y
        blurStartFrame = blurView.frame
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = frame.width / 2
        blurView.alpha = 0
        mask.frame = metalView.frame
        mask.backgroundColor = UIColor.white
        metalView.mask = mask
        camera.aspectRatio = Float(metalView.frame.width / metalView.frame.height)
    }

    func addView(to view: UIView?) {
        view?.addSubview(self.view)
    }

    func removeView() {
        view.removeFromSuperview()
    }

    public func setToMinimap() {
        radarState = .minimap
        animationStartTime = nil
        updateBlurView(progressNewView: 1, progressOldView: 0, overallProgress: 1)
        blurView.layer.cornerRadius = targetFrame.width / 2
        mask.center = CGPoint(x: metalView.frame.width / 2, y: metalView.frame.height / 2)
        mask.frame.size = CGSize(width: blurView.frame.width, height: blurView.frame.height)
        mask.layer.cornerRadius = mask.frame.width / 2
        metalView.mask = mask
        renderer.particles.pointSize = pointSizeMinimap
        ringView.frame = blurView.frame
    }

    public func transitionToMinimap(_ callback: (() -> Void)? = nil) {
        radarState = .transitionToMinimap
        animationStartTime = Date().timeIntervalSinceReferenceDate
        animationCallback = callback
    }

    public func transitionToFullscreen(_ callback: (() -> Void)? = nil) {
        radarState = .transitionToFullscreen
        animationStartTime = Date().timeIntervalSinceReferenceDate
        animationCallback = callback
    }

    public func addCategories(_ categories: [SIMD3<Float>: ARMeshClassification]) {
        newCategories = categories
    }

    public func updateCamera(_ arCamera: ARCamera) {
        camera.deviceTransform = arCamera.metalTransform
        switch radarState {
        case .fullscreen:
            camera.viewMatrix = arCamera.viewMatrix(for: .portrait)
            camera.projectionMatrix = arCamera.projectionMatrix( for: .portrait, viewportSize: metalView.frame.size,
                zNear: nearClipPlane,
                zFar: farClipPlane)
            renderer.cameraCone.tint = SIMD4<Float>(1, 1, 1, 0)
            renderer.particles.pointSize = pointSizeFullscreen
        case .transitionToMinimap:
            if updateTransition(arCamera, reverse: false, immediate: false) {
                onTransitionToMinimapComplete(arCamera)
            }
        case .minimap:
            camera.viewMatrix = overheadViewMatrix(for: arCamera,
                                                   distance: cameraDistance,
                                                   rotationX: .pi / 2)
            camera.projectionMatrix = arCamera.projectionMatrix(for: .portrait,
                                                    viewportSize: metalView.frame.size,
                                                    zNear: nearClipPlane,
                                                    zFar: farClipPlane)
        case .transitionToFullscreen:
            if updateTransition(arCamera, reverse: true) {
                onTransitionToFullscreenComplete(arCamera)
            }
        }
        renderer.update(newCategories, bugTransforms: bugTransforms)
        renderer.draw(camera)
        newCategories.removeAll()
        bugTransforms.removeAll()
    }

    private func updateTransition(_ arCamera: ARCamera, reverse: Bool = false, immediate: Bool = false) -> Bool {
        // Sanity check
        guard let startTime = animationStartTime else { return true }
        // Progress check
        var progress = (Date().timeIntervalSinceReferenceDate - startTime) / animationTime
        if progress >= 1 {
            renderer.progress = 1
            return true
        }
        renderer.progress = Float(progress)
        // Direction check
        if reverse { progress = 1 - progress }
        if immediate { progress = 1 }
        // Update progress
        let progressNewView = Easing.quadraticEaseInOut(point: Float(progress))
        let progressOldView = 1 - Easing.quadraticEaseInOut(point: Float(progress))
        // Update views
        updateBlurView(progressNewView: progressNewView, progressOldView: progressOldView, overallProgress: progress)
        metalAnimation(progressNewView: progressNewView, progressOldView: progressOldView, arCamera: arCamera)
        // Indicate animation is not yet complete
        return false
    }

    private func updateBlurView(progressNewView: Float, progressOldView: Float, overallProgress: Double) {
        let blurWidth = (Float(blurStartFrame.width) * progressOldView) +
            (Float(targetFrame.width) * progressNewView)
        let blurNewSize = CGSize(width: CGFloat(blurWidth), height: CGFloat(blurWidth))
        blurView.frame.size = blurNewSize

        let middle = CGPoint(x: (startFrame.midX * CGFloat(progressOldView)) +
            (targetFrame.midX * CGFloat(progressNewView)),
                             y: (startFrame.midY * CGFloat(progressOldView)) +
                                (targetFrame.midY * CGFloat(progressNewView)))
        blurView.frame.origin = CGPoint(x: middle.x - blurNewSize.width / 2,
                                        y: middle.y - blurNewSize.height / 2)
        blurView.layer.cornerRadius = blurView.frame.width / 2
        blurView.alpha = CGFloat(overallProgress)

        metalView.frame.size.width = (startFrame.width * CGFloat(progressOldView)) +
                    (targetFrame.width * CGFloat(progressNewView))
        if metalView.frame.width > blurView.frame.width {
            metalView.frame.size.width = blurView.frame.width
        }
        let aspect = startFrame.height / startFrame.width
        metalView.frame.size.height = metalView.frame.size.width * aspect
        metalView.center = CGPoint(x: blurView.frame.midX, y: blurView.frame.midY)

        ringView.frame = blurView.frame
        ringView.layer.cornerRadius = blurView.layer.cornerRadius
        ringView.alpha = CGFloat(progressNewView)
        mask.frame.size = CGSize(width: blurView.frame.width, height: blurView.frame.height)
        mask.center = CGPoint(x: metalView.frame.width / 2, y: metalView.frame.height / 2)
        mask.layer.cornerRadius = mask.frame.width / 2 // * CGFloat(progressNewView)
        metalView.mask = mask
    }

    private func metalAnimation(progressNewView: Float, progressOldView: Float, arCamera: ARCamera) {
        // Animate metal contents
        renderer.particles.pointSize = pointSizeFullscreen - (progressNewView * 2)
        renderer.cameraCone.tint = SIMD4<Float>(1, 1, 1, progressNewView)

        // Animate metal camera
        let originMatrix = Transform(matrix: arCamera.viewMatrix(for: .portrait)).matrix
        let targetMatrix = overheadViewMatrix(for: arCamera,
                                              distance: cameraDistance,
                                              rotationX: .pi / 2)
        camera.viewMatrix = float4x4( (originMatrix.columns.0 * progressOldView) +
            (targetMatrix.columns.0 * progressNewView),
                                      (originMatrix.columns.1 * progressOldView) +
                                        (targetMatrix.columns.1 * progressNewView),
                                      (originMatrix.columns.2 * progressOldView) +
                                        (targetMatrix.columns.2 * progressNewView),
                                      (originMatrix.columns.3 * progressOldView) +
                                        (targetMatrix.columns.3 * progressNewView))
        camera.projectionMatrix = arCamera.projectionMatrix(for: .portrait,
                                                            viewportSize: metalView.frame.size,
                                                            zNear: nearClipPlane,
                                                            zFar: farClipPlane)
    }

    private func triggerCallback() {
        guard let callback = animationCallback else {
            return
        }
        callback()
        animationCallback = nil
    }

    private func overheadViewMatrix(for arCamera: ARCamera, distance: Float, rotationX: Float) -> float4x4 {
        let position = float4x4(
            translation: SIMD3<Float>(
                -arCamera.transform.position.x,
                arCamera.transform.position.y,
                -arCamera.transform.position.z) + SIMD3<Float>(0, -distance, 0))
        let rotation = float4x4(rotationY: -arCamera.eulerAngles.y)
        let matrix = rotation * position
        return float4x4(rotationX: rotationX) * matrix
    }
}

extension Day21_RadarMap {
    private func onTransitionToMinimapComplete(_ arCamera: ARCamera) {
        radarState = .minimap
        renderer.cameraCone.tint = SIMD4<Float>(1, 1, 1, 1)
        animationStartTime = nil
        blurView.alpha = 1
        blurView.layer.cornerRadius = targetFrame.width / 2
        mask.center = CGPoint(x: metalView.frame.width / 2, y: metalView.frame.height / 2)
        mask.frame.size = CGSize(width: blurView.frame.width, height: blurView.frame.height)
        mask.layer.cornerRadius = mask.frame.width / 2
        metalView.mask = mask
        renderer.particles.pointSize = pointSizeMinimap
        camera.viewMatrix = overheadViewMatrix(for: arCamera,
                                               distance: cameraDistance,
                                               rotationX: .pi / 2)
        camera.projectionMatrix = arCamera.projectionMatrix(
            for: .portrait,
            viewportSize: metalView.frame.size,
            zNear: nearClipPlane,
            zFar: farClipPlane)
        ringView.frame = blurView.frame
        triggerCallback()
    }

    private func onTransitionToFullscreenComplete(_ arCamera: ARCamera) {
        radarState = .fullscreen
        animationStartTime = nil
        blurView.alpha = 0
        ringView.alpha = 0
        camera.viewMatrix = arCamera.viewMatrix(for: .portrait)
        camera.projectionMatrix = arCamera.projectionMatrix(
            for: .portrait,
            viewportSize: metalView.frame.size,
            zNear: nearClipPlane,
            zFar: farClipPlane)
        renderer.cameraCone.tint = SIMD4<Float>(1, 1, 1, 0)
        renderer.particles.pointSize = pointSizeFullscreen
        triggerCallback()
    }
}
