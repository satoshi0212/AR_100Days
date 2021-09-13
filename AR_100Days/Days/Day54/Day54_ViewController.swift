import ARKit
import SceneKit
import UIKit

class Day54_ViewController: UIViewController {

    private var sceneView: ARSCNView!
    private var targetFaceGeometry: ARFaceGeometry?
    private var targetColor = UIColor(hue: 1.0, saturation: 1.0, brightness: 1.0, alpha: 1.0)

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = ARSCNView(frame: view.bounds)
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: sceneView!, attribute: $0, relatedBy: .equal, toItem: sceneView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        sceneView.scene = SCNScene()
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.userFaceTrackingEnabled = true
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        addFaceNode()
    }

    private func addFaceNode() {
        guard
            let camera = sceneView.pointOfView,
            let faceGeometry = targetFaceGeometry
        else { return }

        let newGeometry: ARSCNFaceGeometry = {
            let device = sceneView.device!
            let maskGeometry = ARSCNFaceGeometry(device: device)!
            maskGeometry.firstMaterial?.lightingModel = .physicallyBased
            maskGeometry.firstMaterial?.diffuse.contents = targetColor
            maskGeometry.firstMaterial?.roughness.contents = UIColor.black
            return maskGeometry
        }()
        newGeometry.update(from: faceGeometry)

        let node = SCNNode()
        node.geometry = newGeometry
        node.position = camera.convertPosition(SCNVector3(x: 0, y: 0, z: -0.2), to: nil)
        node.eulerAngles = camera.eulerAngles

        sceneView.scene.rootNode.addChildNode(node)
    }
}

// MARK: - ARSCNViewDelegate

extension Day54_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard
            let faceAnchor = anchor as? ARFaceAnchor
        else { return }

        targetFaceGeometry = faceAnchor.geometry
    }
}

// MARK: - ARSessionDelegate

extension Day54_ViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let translation = frame.camera.transform.columns.3
        let distance = distance(between: SCNVector3(translation[0], translation[1], translation[2]), and: SCNVector3(0, 0, 0))
        let percentToMax = distance / CGFloat(3) // meters
        let hue = min(percentToMax, 1.0)
        targetColor = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
    }

    func length(_ xDist: Float, _ yDist: Float, _ zDist: Float) -> CGFloat {
        return CGFloat(sqrt((xDist * xDist) + (yDist * yDist) + (zDist * zDist)))
    }

    func distance(between v1:SCNVector3, and v2:SCNVector3) -> CGFloat {
        let xDist = v1.x - v2.x
        let yDist = v1.y - v2.y
        let zDist = v1.z - v2.z
        return length(xDist, yDist, zDist)
    }
}
