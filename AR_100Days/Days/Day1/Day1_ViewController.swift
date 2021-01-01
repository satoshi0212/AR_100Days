import UIKit
import SceneKit
import ARKit

class Day1_ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.scene = SCNScene()

        let videoUrl = Bundle.main.url(forResource: "sample_320x240", withExtension: "mp4")!
        let videoNode = createVideoNode(size: 1, videoUrl: videoUrl)
        videoNode.position = SCNVector3(0, 0, -0.3)
        sceneView.scene.rootNode.addChildNode(videoNode)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }

    func createVideoNode(size: CGFloat, videoUrl: URL) -> SCNNode {
        let skSceneSize = CGSize(width: 1024, height: 1024)

        let avPlayer = AVPlayer(url: videoUrl)

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
        node.scale = SCNVector3(1, 0.5625, 1)
        return node
    }
}
