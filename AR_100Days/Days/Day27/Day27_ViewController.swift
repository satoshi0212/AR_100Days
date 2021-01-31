import UIKit
import ARKit
import SceneKit

class Day27_ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!

    private var leftEyeNode: ImageNode?
    private var rightEyeNode: ImageNode?
    private let faceTrackingConfiguration = ARFaceTrackingConfiguration()

    override func viewDidLoad() {
        super.viewDidLoad()
        sceneView.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        sceneView.session.run(faceTrackingConfiguration)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sceneView.session.pause()
    }
}

extension Day27_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor, let device = sceneView.device else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.colorBufferWriteMask = []

        rightEyeNode = ImageNode(width: 0.02, height: 0.02, image: #imageLiteral(resourceName: "day27"))
        leftEyeNode = ImageNode(width: 0.015, height: 0.015, image: #imageLiteral(resourceName: "day27"))

        rightEyeNode?.pivot = SCNMatrix4MakeTranslation(0, 0, -0.01)
        leftEyeNode?.pivot = SCNMatrix4MakeTranslation(0, 0, -0.01)

        rightEyeNode.flatMap { node.addChildNode($0) }
        leftEyeNode.flatMap { node.addChildNode($0) }

        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }

        faceGeometry.update(from: faceAnchor.geometry)
        leftEyeNode?.simdTransform = faceAnchor.leftEyeTransform
        rightEyeNode?.simdTransform = faceAnchor.rightEyeTransform
    }
}

private class ImageNode: SCNNode {

    init(width: CGFloat, height: CGFloat, image: UIImage) {
        super.init()

        let plane = SCNPlane(width: width, height: height)
        plane.firstMaterial?.diffuse.contents = image
        plane.firstMaterial?.isDoubleSided = true
        geometry = plane
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
