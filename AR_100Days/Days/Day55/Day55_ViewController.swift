import ARKit
import SceneKit
import UIKit

class Day55_ViewController: UIViewController {

    private var sceneView: ARSCNView!

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
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        view.sendSubviewToBack(sceneView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        let alertController = UIAlertController(title: "Answer", message: "正解: Q", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in }
        alertController.addAction(okAction)
        present(alertController, animated: true, completion: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])

        addNodes()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    private func addNode(image: UIImage, position: SCNVector3, rotation: SCNVector4? = nil, scale: SCNVector3? = nil) {
        let node = SCNNode()
        let geometry = SCNPlane(width: 0.4, height: 0.4)
        geometry.firstMaterial?.diffuse.contents = image
        geometry.firstMaterial?.isDoubleSided = true
        node.geometry = geometry
        if let rotation = rotation {
            node.rotation = rotation
        }
        node.position = position
        if let scale = scale {
            node.scale = scale
        }
        sceneView.scene.rootNode.addChildNode(node)
    }

    private func addNodes() {
        addNode(image: UIImage(named: "nazo001")!, position: SCNVector3(0, 0, -1.1))

        addNode(image: UIImage(named: "nazo002")!,
                position: SCNVector3(-0.5, 0.15, -1.5),
                rotation: SCNVector4(0, 1, 0, 0.5 * Double.pi),
                scale: SCNVector3(1.0, 1.0, 1.0))

        addNode(image: UIImage(named: "nazo003")!,
                position: SCNVector3(0, 0.1, -1.5),
                rotation: SCNVector4(0, 1, 0, 0.5 * Double.pi),
                scale: SCNVector3(1.0, 1.0, 1.0))
    }
}
