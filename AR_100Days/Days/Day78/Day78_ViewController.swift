import UIKit
import ARKit
import SceneKit

class Day78_ViewController: UIViewController, ARSCNViewDelegate {

    private var sceneView: ARSCNView!
    private var videoNodes: [SCNNode] = []

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
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
        
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)

        makeNodes()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        if let avPlayerItem = notification.object as? AVPlayerItem {
            avPlayerItem.seek(to: .zero, completionHandler: nil)
        }
    }

    private func makeNodes() {
        let recipes = ["recipe_1", "recipe_2", "recipe_3", "recipe_4", "recipe_5"]
//        let positions = [SCNVector3(-0.42, 0.1, -0.05),
//                         SCNVector3(-0.2, 0.1, -0.2),
//                         SCNVector3( 0.0, 0.1, -0.3),
//                         SCNVector3( 0.2, 0.1, -0.2),
//                         SCNVector3( 0.42, 0.1, -0.05)]
        let positions = [SCNVector3(-0.42, 0.1, -0.15),
                         SCNVector3(-0.2, 0.1, -0.3),
                         SCNVector3( 0.0, 0.1, -0.4),
                         SCNVector3( 0.2, 0.1, -0.3),
                         SCNVector3( 0.42, 0.1, -0.15)]

        for (i, recipe) in recipes.enumerated() {
            let url = Bundle.main.url(forResource: recipe, withExtension: "mp4")!
            let node = createVideoNode(size: 0.2, videoUrl: url)
            node.position = positions[i]
            sceneView.scene.rootNode.addChildNode(node)
            videoNodes.append(node)
        }
    }
    
    private func createVideoNode(size: CGFloat, videoUrl: URL) -> SCNNode {
        let skSceneSize = CGSize(width: 1024, height: 1024)

        let avPlayer = AVPlayer(url: videoUrl)
        avPlayer.actionAtItemEnd = .none
  
        let skVideoNode = SKVideoNode(avPlayer: avPlayer)
        skVideoNode.position = CGPoint(x: skSceneSize.width / 2.0, y: skSceneSize.height / 2.0)
        skVideoNode.size = skSceneSize
        skVideoNode.yScale = -1.0
        skVideoNode.play()

        let skScene = SKScene(size: skSceneSize)
        skScene.addChild(skVideoNode)

        let material = SCNMaterial()
        material.diffuse.contents = skScene
        material.isDoubleSided = true

        let node = SCNNode()
        node.geometry = SCNPlane(width: size, height: size)
        node.geometry?.materials = [material]
        node.scale = SCNVector3(1, 1, 1)
        node.opacity = 0.85
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if let camera = sceneView.pointOfView {
            videoNodes.forEach { $0.eulerAngles = SCNVector3(0, camera.eulerAngles.x, 0) }
        }
    }
}
