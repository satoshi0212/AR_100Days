import ARKit
import SceneKit
import UIKit

class Day43_ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet private var sceneView: ARSCNView!

    private var currentFaceAnchor: ARFaceAnchor?
    private var currentController = VideoTexturedFace()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        currentController.isMeshMode.toggle()

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
           let newContent = currentController.renderer(sceneView, nodeFor: anchor) {
            node.addChildNode(newContent)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        currentController.viewportSize = sceneView.bounds.size
    }
}

extension Day43_ViewController: ARSCNViewDelegate {

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
    var viewportSize: CGSize?
    var isMeshMode = false

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
    }
}

private class VideoTexturedFace: TexturedFace {

    override func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
              let frame = sceneView.session.currentFrame,
              anchor is ARFaceAnchor,
              let viewportSize = viewportSize
        else { return nil }

        let planeNode = SCNNode()
        planeNode.geometry = SCNPlane(width: 100, height: 100)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.black
        planeNode.position.z = -5
        sceneView.pointOfView?.addChildNode(planeNode)

        if isMeshMode {
            let faceMeshGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)!
            let materialMesh = faceMeshGeometry.firstMaterial!
            materialMesh.lightingModel = .constant
            materialMesh.diffuse.contents =  UIImage(named: "facemap_yellow")
            contentNode = SCNNode(geometry: faceMeshGeometry)
            return contentNode
        }

        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)!
        let material = faceGeometry.firstMaterial!
        material.lightingModel = .constant
        material.diffuse.contents = sceneView.scene.background.contents

        guard let shaderURL = Bundle.main.url(forResource: "VideoTexturedFace", withExtension: "shader"),
              let modifier = try? String(contentsOf: shaderURL)
        else { fatalError("Can't load shader modifier from bundle.") }
        faceGeometry.shaderModifiers = [.geometry: modifier]

        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize)
        let transform = SCNMatrix4(affineTransform)
        faceGeometry.setValue(SCNMatrix4Invert(transform), forKey: "displayTransform")

        contentNode = SCNNode(geometry: faceGeometry)
        return contentNode
    }
}
