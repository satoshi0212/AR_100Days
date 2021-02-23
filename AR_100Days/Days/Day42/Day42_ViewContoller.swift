import UIKit
import ARKit

class Day42_ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!

    let features = ["nose", "leftEye", "rightEye", "mouth"]
    let featureIndices = [[9], [1064], [42], [24, 25]]

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
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

    func updateFeatures(for node: SCNNode, using anchor: ARFaceAnchor) {
        for (feature, indices) in zip(features, featureIndices) {
            guard let child = node.childNode(withName: feature, recursively: false) else { continue }
            let vertices = indices.map { anchor.geometry.vertices[$0] }

            var newPos = vertices.reduce(vector_float3(), +) / Float(vertices.count)

            switch feature {
            case "leftEye":
                let scaleX = child.scale.x
                let eyeBlinkValue = anchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0.0
                child.scale = SCNVector3(scaleX, 1.0 - eyeBlinkValue * 0.6, 1.0)

                newPos.y += 0.004

            case "rightEye":
                let scaleX = child.scale.x
                let eyeBlinkValue = anchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0.0
                child.scale = SCNVector3(scaleX, 1.0 - eyeBlinkValue * 0.6, 1.0)

                newPos.y += 0.007

            default:
                break
            }

            child.position = SCNVector3(newPos)
        }
    }
}

extension Day42_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let device = sceneView.device else { return nil }
        let faceGeometry = ARSCNFaceGeometry(device: device)
        let node = SCNNode(geometry: faceGeometry)
        node.geometry?.firstMaterial?.transparency = 0.0

        let torus = SCNTorus(ringRadius: 0.009, pipeRadius: 0.01)
        torus.firstMaterial?.diffuse.contents = UIColor.black

        let leftEyeNode = SCNNode(geometry: torus)
        leftEyeNode.name = "leftEye"
        node.addChildNode(leftEyeNode)

        let rightEyeNode = SCNNode(geometry: torus)
        rightEyeNode.name = "rightEye"
        node.addChildNode(rightEyeNode)

        updateFeatures(for: node, using: faceAnchor)
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor, let faceGeometry = node.geometry as? ARSCNFaceGeometry else { return }

        faceGeometry.update(from: faceAnchor.geometry)
        updateFeatures(for: node, using: faceAnchor)
    }
}
