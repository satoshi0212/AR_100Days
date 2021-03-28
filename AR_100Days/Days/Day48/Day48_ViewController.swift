import UIKit
import SceneKit
import ARKit
import GameplayKit

class Day48_ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!

    private var nodes = [SCNNode]()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.scene = SCNScene()
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        sceneView.session.pause()
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        addVirtualObject()
    }

    func addVirtualObject() {
        let node = KnifeNode()
        let position = SCNVector3(x: 0, y: 0, z: -0.5)
        if let camera = sceneView.pointOfView {
            node.position = camera.convertPosition(position, to: nil)
            node.eulerAngles = camera.eulerAngles
        }
        sceneView.scene.rootNode.addChildNode(node)
        nodes.append(node)
    }

    private func resetContent() {
        nodes.forEach { $0.runAction(SCNAction.removeFromParentNode()) }
    }
}

extension Day48_ViewController: ARSessionDelegate {

}

extension Day48_ViewController: ARSCNViewDelegate {

}

class KnifeNode: SCNNode {

    override init() {
        super.init()

        let scene = SCNScene(named: "SceneKitAssets.scnassets/knife.scn")!
        let node = scene.rootNode

        node.position = SCNVector3Zero
        node.position.addNoise()

        addChildNode(node)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SCNVector3 {

    mutating func addNoise() {
        let rand = GKShuffledDistribution(lowestValue: -50, highestValue: 50)
        addNoise(rand: rand)
    }

    fileprivate mutating func addNoise(rand: GKRandom) {
        let cm: () -> Float = { return Float(rand.nextInt()) / 100.0 }

        self.x += cm()
        self.y += cm()
        self.z += cm()
    }
}
