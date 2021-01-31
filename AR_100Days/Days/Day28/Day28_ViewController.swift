import UIKit
import SceneKit
import SpriteKit

class Day28_ViewController: UIViewController, SCNSceneRendererDelegate, SCNPhysicsContactDelegate {

    private func randFloat<F: FloatingPoint>(_ min: F, _ max: F) -> F {
        return min + (max - min) * F(arc4random()) / F(UInt32.max)
    }

    private let SPRITE_SIZE: CGFloat = 256

    @IBOutlet weak var sceneView: SCNView!

    private var _scene: SCNScene!
    private var _plok: SCNParticleSystem!
    private var _cameraHandle: SCNNode!
    private var _cameraOrientation: SCNNode!
    private var _cameraNode: SCNNode!
    private var _spotLightParentNode: SCNNode!
    private var _spotLightNode: SCNNode!
    private var _ambientLightNode: SCNNode!
    private var _floorNode: SCNNode!
    private var _torus: SCNNode!

    override func viewDidLoad() {
        super.viewDidLoad()

        _scene = SCNScene()
        sceneView.scene = _scene
        sceneView.scene!.physicsWorld.speed = 2.0
        sceneView.delegate = self
        sceneView.pointOfView = _cameraNode

        setupEnvironment()
        setupSceneElements()

        sceneView.isPlaying = true
        sceneView.loops = true
        sceneView.backgroundColor = .white
    }

    private func setupEnvironment() {
        _cameraNode = SCNNode()
        _cameraNode.position = SCNVector3Make(0, 0, 120)

        _cameraHandle = SCNNode()
        _cameraHandle.position = SCNVector3Make(0, 60, 0)

        _cameraOrientation = SCNNode()

        _scene?.rootNode.addChildNode(_cameraHandle)
        _cameraHandle.addChildNode(_cameraOrientation)
        _cameraOrientation.addChildNode(_cameraNode)

        _cameraNode.camera = SCNCamera()
        _cameraNode.camera!.zFar = 800
        _cameraNode.camera!.fieldOfView = 95

        _ambientLightNode = SCNNode()
        _ambientLightNode.light = SCNLight()
        _ambientLightNode.light!.type = .ambient
        _ambientLightNode.light!.color = SKColor(white: 0.3, alpha: 1.0)
        _scene.rootNode.addChildNode(_ambientLightNode)

        _spotLightParentNode = SCNNode()
        _spotLightParentNode.position = SCNVector3Make(0, 90, 20)
        _spotLightNode = SCNNode()
        _spotLightNode.rotation = SCNVector4Make(1, 0, 0, -.pi / 4)
        _spotLightNode.light = SCNLight()
        _spotLightNode.light!.type = .spot
        _spotLightNode.light!.color = SKColor(white: 1.0, alpha: 1.0)
        _spotLightNode.light!.castsShadow = true
        _spotLightNode.light!.shadowColor = SKColor(white: 0, alpha: 0.5)
        _spotLightNode.light!.zNear = 30
        _spotLightNode.light!.zFar = 800
        _spotLightNode.light!.shadowRadius = 1.0
        _spotLightNode.light!.spotInnerAngle = 15
        _spotLightNode.light!.spotOuterAngle = 70
        _cameraNode.addChildNode(_spotLightParentNode)
        _spotLightParentNode.addChildNode(_spotLightNode)

        let floor = SCNFloor()
        floor.reflectionFalloffEnd = 0
        floor.reflectivity = 0
        _floorNode = SCNNode()
        _floorNode.geometry = floor
        _floorNode.geometry!.firstMaterial!.diffuse.contents = "wood.png"
        _floorNode.geometry!.firstMaterial!.locksAmbientWithDiffuse = true
        _floorNode.geometry!.firstMaterial!.diffuse.wrapS = .repeat
        _floorNode.geometry!.firstMaterial!.diffuse.wrapT = .repeat
        _floorNode.geometry!.firstMaterial!.diffuse.mipFilter = .nearest
        _floorNode.geometry!.firstMaterial!.isDoubleSided = false
        _floorNode.physicsBody = .static()
        _floorNode.physicsBody!.restitution = 1.0
        _scene.rootNode.addChildNode(_floorNode)
    }

    private func setupSceneElements() {
        let wallNode = SCNNode(geometry: SCNPlane(width: 800, height: 200))
        wallNode.opacity = 0
        wallNode.physicsBody = .static()
        wallNode.physicsBody!.restitution = 1.0
        wallNode.physicsBody!.categoryBitMask = 1 << 2
        wallNode.castsShadow = false
        wallNode.physicsBody!.contactTestBitMask = ~0
        wallNode.position = SCNVector3Make(0, 100, 0)
        wallNode.rotation = SCNVector4Make(0, 1, 0, .pi)
        _scene.rootNode.addChildNode(wallNode)

        _plok = SCNParticleSystem(named: "plok.scnp", inDirectory: "SceneKitAssets.scnassets/particles")

        let W: CGFloat = 50

        _torus = SCNNode()
        _torus.position = SCNVector3Make(_cameraHandle.position.x, 60, 10)
        _torus.geometry = SCNTorus(ringRadius: W/2, pipeRadius: W/6)
        _torus.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: _torus.geometry!, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron]))

        let material = _torus.geometry!.firstMaterial!
        material.specular.contents = SKColor(white: 0.5, alpha: 1)
        material.shininess = 2.0
        material.normal.contents = "wood-normal.png"

        _scene.rootNode.addChildNode(_torus)
        _torus.runAction(.repeatForever(.rotate(by: .pi*2, around: SCNVector3Make(0.4, 1, 0), duration: 8)))

        sceneView.prepare(_scene!, shouldAbortBlock: nil)
        _scene.physicsWorld.contactDelegate = self

        let skScene = SKScene(size: CGSize(width: SPRITE_SIZE, height: SPRITE_SIZE))
        skScene.backgroundColor = .white
        material.diffuse.contents = skScene

        sceneView.scene!.physicsWorld.gravity = SCNVector3Make(0, -70, 0)
    }

    private func addPaintAtLocation(_ _p: CGPoint, color: SKColor) {

        guard let skScene = _torus.geometry!.firstMaterial!.diffuse.contents as? SKScene else { return }

        var p = _p
        p.x *= SPRITE_SIZE
        p.y *= SPRITE_SIZE

        var node: SKNode = SKSpriteNode()
        node.position = p
        node.xScale = 0.33

        let subNode = SKSpriteNode(imageNamed: "splash.png")
        subNode.zRotation = randFloat(0.0, 2.0 * .pi)
        subNode.color = color
        subNode.colorBlendFactor = 1

        node.addChild(subNode)
        skScene.addChild(node)

        // remove
        //node.run(.sequence([.wait(forDuration: 5), .removeFromParent()]));

        if p.x < 16 {
            node = node.copy() as! SKNode
            p.x = SPRITE_SIZE + p.x
            node.position = p
            skScene.addChild(node)
        } else if p.x > SPRITE_SIZE-16 {
            node = node.copy() as! SKNode
            p.x = (p.x - SPRITE_SIZE)
            node.position = p
            skScene.addChild(node)
        }
    }

    private func launchColorBall() {

        let ball = SCNNode()
        let sphere = SCNSphere(radius: 2)
        ball.geometry = sphere
        let hue = CGFloat(arc4random())/CGFloat(UInt32.max)
        ball.geometry!.firstMaterial?.diffuse.contents = SKColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
        ball.geometry!.firstMaterial?.fresnelExponent = 1.0
        ball.physicsBody = .dynamic()
        ball.physicsBody!.restitution = 0.9
        ball.physicsBody!.categoryBitMask = 0x4
        ball.physicsBody!.contactTestBitMask = ~0
        ball.physicsBody!.collisionBitMask = ~(0x4)
        ball.position = SCNVector3Make(_cameraHandle.position.x, 20, 100)

        _scene.rootNode.addChildNode(ball)

        let PAINT_FACTOR = Float(2)

        ball.physicsBody!.velocity = SCNVector3Make(
            PAINT_FACTOR * randFloat(-10, 10),
            (75 + randFloat(0, 35)),
            PAINT_FACTOR * -30.0)
    }

    // MARK: - SCNSceneRendererDelegate

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {

        struct My {
            static var lastTime: TimeInterval = 0
        }

        if time - My.lastTime > 0.1 {
            My.lastTime = time
            launchColorBall()
        }
    }

    // MARK: - SCNPhysicsContactDelegate

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

        var ball: SCNNode? = nil
        if contact.nodeA.physicsBody!.type == .dynamic {
            ball = contact.nodeA
        } else if contact.nodeB.physicsBody!.type == .dynamic {
            ball = contact.nodeB
        }

        if let ball = ball {
            let plokCopy = _plok.copy() as! SCNParticleSystem
            plokCopy.particleImage = _plok.particleImage; // to workaround an bug in seed #1
            plokCopy.particleColor = ball.geometry!.firstMaterial!.diffuse.contents as! SKColor
            _scene.addParticleSystem(plokCopy, transform: SCNMatrix4MakeTranslation(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z))

            let pointA = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z + 20)
            let pointB = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z - 20)

            let results = sceneView.scene!.rootNode.hitTestWithSegment(from: pointA, to: pointB, options: [SCNHitTestOption.rootNode.rawValue: _torus!])

            if !results.isEmpty, let hit = results.first {
                addPaintAtLocation(hit.textureCoordinates(withMappingChannel: 0), color: plokCopy.particleColor)
            }

            ball.removeFromParentNode()
        }
    }
}
