import ARKit
import SceneKit
import UIKit

class Day2_ViewController: UIViewController {

    private var sceneView: ARSCNView!
    private var placedPlane = false
    private var planeNode: PlaneNode?
    private let configuration = ARWorldTrackingConfiguration()
    private var viewFrame: CGRect?
    private var lastUpdateTime: TimeInterval?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = ARSCNView(frame: view.bounds, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal
        ])

        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        view.addSubview(sceneView)

        viewFrame = sceneView.bounds

        configuration.environmentTexturing = .automatic
        configuration.planeDetection = [.horizontal, .vertical]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIApplication.shared.isIdleTimerDisabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

extension Day2_ViewController: ARSCNViewDelegate {

    public func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard planeNode == nil else { return nil }

        if anchor is ARPlaneAnchor {
            planeNode = PlaneNode(sceneView: sceneView, viewportSize: viewFrame!.size)
            sceneView.scene.rootNode.addChildNode(planeNode!.contentNode)
        }

        return nil
    }

    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let delta: Float = lastUpdateTime == nil ? 0.03 : Float(time - lastUpdateTime!)
        lastUpdateTime = time

        if planeNode != nil {
            let couldPlace = tryPlacePlaneInWorld(
                planeNode: planeNode!,
                screenLocation: CGPoint(x: viewFrame!.width / 2, y: viewFrame!.height / 2))

            planeNode!.contentNode.isHidden = !couldPlace
        }

        planeNode?.update(time: time, timeDelta: delta)
    }

    private func tryPlacePlaneInWorld(planeNode: PlaneNode, screenLocation: CGPoint) -> Bool {
        if placedPlane {
            return true
        }

        guard let query = sceneView.raycastQuery(from: screenLocation, allowing: .existingPlaneGeometry, alignment: .any),
              let hitTestResult = sceneView.session.raycast(query).first
        else { return false }

        placedPlane = true
        planeNode.contentNode.simdWorldTransform = hitTestResult.worldTransform

        return true
    }
}
