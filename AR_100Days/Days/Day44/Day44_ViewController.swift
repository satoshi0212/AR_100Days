import ARKit
import SceneKit
import UIKit

class Day44_ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet weak fileprivate var imageView: UIImageView!

    private var currentFaceAnchor: ARFaceAnchor?
    private var currentController = VideoTexturedFace()
    private var viewSize: CGSize = .zero

    let planeNode = SCNNode()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        imageView.backgroundColor = .gray
        imageView.alpha = 0.5
        imageView.isHidden = true

        currentController.imageView = imageView

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
           let newContent = currentController.renderer(sceneView, nodeFor: anchor) {
            node.addChildNode(newContent)
        }

        planeNode.geometry = SCNPlane(width: 0.1, height: 0.1)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        planeNode.position.z = -0.2
        sceneView.pointOfView?.addChildNode(planeNode)

        currentController.planeNode = planeNode
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        viewSize = view.bounds.size
        currentController.viewSize = viewSize
    }
}

extension Day44_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor

        if node.childNodes.isEmpty, let contentNode = currentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
              let contentNode = currentController.contentNode,
              contentNode.parent == node
        else { return }

        currentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
}

private class TexturedFace: NSObject {

    var contentNode: SCNNode?
    var imageView: UIImageView?
    var planeNode: SCNNode?

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
              anchor is ARFaceAnchor else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        let material = faceGeometry.firstMaterial!
        material.lightingModel = .physicallyBased

        contentNode = SCNNode(geometry: faceGeometry)
        return contentNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceGeometry = node.geometry as? ARSCNFaceGeometry,
              let faceAnchor = anchor as? ARFaceAnchor
        else { return }

        faceGeometry.update(from: faceAnchor.geometry)

        if let planeNode = planeNode {
            DispatchQueue.main.async {
                let material = faceGeometry.firstMaterial!
                planeNode.geometry?.materials = [material]
            }
        }
    }
}

private class VideoTexturedFace: TexturedFace {

    var viewSize: CGSize = .zero

    override func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
              let frame = sceneView.session.currentFrame,
              anchor is ARFaceAnchor
        else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)!
        let material = faceGeometry.firstMaterial!
        material.diffuse.contents = sceneView.scene.background.contents
        material.lightingModel = .constant

        guard let shaderURL = Bundle.main.url(forResource: "Day44_VideoTexturedFace", withExtension: "shader"),
              let modifier = try? String(contentsOf: shaderURL)
        else { fatalError("Can't load shader modifier from bundle.") }
        faceGeometry.shaderModifiers = [.geometry: modifier]

        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: viewSize)
        let transform = SCNMatrix4(affineTransform)
        faceGeometry.setValue(SCNMatrix4Invert(transform), forKey: "displayTransform")

        contentNode = SCNNode(geometry: faceGeometry)
        return contentNode
    }
}
