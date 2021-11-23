import Foundation
import UIKit
import ARKit
import SceneKit

class Day70_ViewController: UIViewController {

    private var sceneView: ARSCNView!
    private var targetNodes: [SCNNode] = []

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
        view.sendSubviewToBack(sceneView)

        for i in 0..<91 {
            let _node = SCNNode()
            _node.geometry = SCNSphere(radius: 0.01)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(red: 0.2, green: 029, blue: 0.9, alpha: 0.8)
            _node.geometry?.materials = [material]
            _node.name = "\(i)"
            sceneView.scene.rootNode.addChildNode(_node)
            targetNodes.append(_node)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARBodyTrackingConfiguration()
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }
}

extension Day70_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

        if let anchor = anchor as? ARBodyAnchor {
            //let hipWorldPosition = anchor.transform
            let skeleton = anchor.skeleton

            for (i, jointTransform) in skeleton.jointModelTransforms.enumerated() {
                let parentIndex = skeleton.definition.parentIndices[i]
                guard parentIndex != -1 else { continue }
                //let parentJointTransform = jointTransform[parentIndex]

                let _node = targetNodes[i]
                _node.position = SCNVector3(jointTransform.position.x, jointTransform.position.y, jointTransform.position.z - 1.5)
                //_node.transform = SCNMatrix4Mult(SCNMatrix4MakeRotation(Float.pi, 1, 0, 0), SCNMatrix4(anchor.transform))
            }
        }
    }
}
