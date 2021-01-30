import UIKit
import SceneKit
import ARKit

class Day26_ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    private var eyeLasers: EyeLasers!

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self

        let device = sceneView.device!
        let faceGeometry = ARSCNFaceGeometry(device: device)!
        eyeLasers = EyeLasers(geometry: faceGeometry)
        sceneView.scene.rootNode.addChildNode(eyeLasers)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        eyeLasers.transform = node.transform
        eyeLasers.update(withFaceAnchor: faceAnchor)
    }
}

private class EyeLasers: SCNNode {

    private let leftEyeCylinder: SCNNode = {
        let node = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 0.5))
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        node.opacity = 0.7
        return node
    }()

    private let rightEyeCylinder: SCNNode = {
        let node = SCNNode(geometry: SCNCylinder(radius: 0.005, height: 0.5))
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        node.opacity = 0.7
        return node
    }()

    init(geometry: ARSCNFaceGeometry) {
        super.init()

        addChildNode(leftEyeCylinder)
        addChildNode(rightEyeCylinder)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(withFaceAnchor anchor: ARFaceAnchor) {
        let rotate = simd_float4x4(SCNMatrix4Mult(
                                    SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0),
                                    SCNMatrix4MakeTranslation(0, 0, 0.1 / 2)))
        leftEyeCylinder.simdTransform = anchor.leftEyeTransform * rotate
        rightEyeCylinder.simdTransform = anchor.rightEyeTransform * rotate
    }
}
