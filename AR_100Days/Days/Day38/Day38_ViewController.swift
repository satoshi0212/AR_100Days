import UIKit
import ARKit

class Day38_ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!

    private let SPRITE_SIZE: CGFloat = 256
    private let device = MTLCreateSystemDefaultDevice()!
    var knownAnchors: [UUID: SCNNode] = [:]
    var isUpdating = true

    private var _planeNode: SCNNode!

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        sceneView.debugOptions = .showPhysicsShapes

        addTapGesture()

        let _planeNode = SCNNode()
        _planeNode.position = SCNVector3(0, 0, -1.5)
        _planeNode.geometry = SCNPlane(width: 0.7, height: 0.7)
        let _shape = SCNPhysicsShape(geometry: _planeNode.geometry!, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron])
        _planeNode.physicsBody = SCNPhysicsBody(type: .static, shape: _shape)

        let materialP = _planeNode.geometry!.firstMaterial!
        materialP.isDoubleSided = true

        let skSceneP = SKScene(size: CGSize(width: SPRITE_SIZE, height: SPRITE_SIZE))
        skSceneP.backgroundColor = .white
        materialP.diffuse.contents = skSceneP

        sceneView.scene.rootNode.addChildNode(_planeNode)
        _planeNode.runAction(.repeatForever(.rotate(by: .pi * 2, around: SCNVector3Make(0.4, 1, 0), duration: 16)))

        sceneView.prepare(sceneView.scene, shouldAbortBlock: nil)
        sceneView.scene.physicsWorld.contactDelegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        //configuration.planeDetection = [.horizontal, .vertical]
        configuration.planeDetection = [.vertical]
        configuration.sceneReconstruction = .mesh
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    func addTapGesture() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        isUpdating = false
        launchColorBall()
    }

    private func launchColorBall() {

        let ball = SCNNode()
        ball.geometry = SCNSphere(radius: 0.06)
        let hue = CGFloat(arc4random()) / CGFloat(UInt32.max)
        ball.geometry!.firstMaterial?.diffuse.contents = SKColor(hue: hue, saturation: 1, brightness: 1, alpha: 1)
        ball.geometry!.firstMaterial?.fresnelExponent = 1.0
        ball.physicsBody = .dynamic()
        ball.physicsBody!.contactTestBitMask = ~0
        ball.physicsBody!.collisionBitMask = ~(0x4)

        guard let camera = sceneView.pointOfView else { return }
        let cameraPos = SCNVector3Make(0, 0, -0.5)
        let position = camera.convertPosition(cameraPos, to: nil)
        ball.position = position

        let (direction, _) = getUserVector()

        ball.physicsBody!.velocity = SCNVector3Make(
            direction.x * 6.0,
            direction.y * 6.0,
            direction.z * 6.0)

        sceneView.scene.rootNode.addChildNode(ball)
    }

    private func getUserVector() -> (SCNVector3, SCNVector3) {
        if let frame = sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space

            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.2))
    }

    private func addPaintAtLocation(_ _p: CGPoint, color: SKColor, targetNode: SCNNode) {

        guard let skScene = targetNode.geometry!.firstMaterial!.diffuse.contents as? SKScene else { return }

        var p = _p

        p.x *= SPRITE_SIZE
        p.y *= SPRITE_SIZE

        let node: SKNode = SKSpriteNode()
        node.position = p

        let subNode = SKSpriteNode(imageNamed: "splash.png")
        subNode.color = color
        subNode.colorBlendFactor = 1

        node.addChild(subNode)
        skScene.addChild(node)
    }
}

extension Day38_ViewController: SCNPhysicsContactDelegate {

    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {

        var ball: SCNNode? = nil
        var target: SCNNode? = nil
        if contact.nodeA.physicsBody!.type == .dynamic {
            ball = contact.nodeA
            target = contact.nodeB
        } else if contact.nodeB.physicsBody!.type == .dynamic {
            ball = contact.nodeB
            target = contact.nodeA
        }

        if let ball = ball {
            let pointA = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z + 20)
            let pointB = SCNVector3Make(contact.contactPoint.x, contact.contactPoint.y, contact.contactPoint.z - 20)

            let results = sceneView.scene.rootNode.hitTestWithSegment(from: pointA, to: pointB, options: [:])

            if !results.isEmpty, let hit = results.first {
                let color = ball.geometry!.firstMaterial!.diffuse.contents as! SKColor
                addPaintAtLocation(hit.textureCoordinates(withMappingChannel: 0), color: color, targetNode: target!)
            }

            ball.removeFromParentNode()
        }
    }
}

extension Day38_ViewController: ARSessionDelegate {

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {

        if !isUpdating { return }

        for anchor in anchors {
            //var sceneNode: SCNNode?

            if anchor is ARPlaneAnchor {
                //let planeGeo = ARSCNPlaneGeometry(device: device)!

                let planeGeo = SCNPlane(width: 1.5, height: 1.5)
                //planeGeo.update(from: planeAnchor.geometry)

                let defaultMaterial = SCNMaterial()
                defaultMaterial.isDoubleSided = true
                //defaultMaterial.diffuse.contents = UIColor(displayP3Red: 0, green: 0, blue: 1, alpha: 0.7)

                let skScene = SKScene(size: CGSize(width: 256, height: 256))
                //skScene.backgroundColor = UIColor(displayP3Red: 0.0, green: 1.0, blue: 0.0, alpha: 0.1)
                skScene.backgroundColor = .clear
                defaultMaterial.diffuse.contents = skScene

                planeGeo.materials = [defaultMaterial]

                let sceneNode = SCNNode(geometry: planeGeo)
                let shape = SCNPhysicsShape(geometry: planeGeo, options: [.type: SCNPhysicsShape.ShapeType.concavePolyhedron])
                sceneNode.physicsBody = SCNPhysicsBody(type: .static, shape: shape)

                sceneNode.simdTransform = anchor.transform
                sceneNode.rotation = SCNVector4(0, 1, 0, Float.pi/2)

                sceneView.scene.rootNode.addChildNode(sceneNode)
            }
        }
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {

        if !isUpdating { return }

        for anchor in anchors {
            if let node = knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
                knownAnchors.removeValue(forKey: anchor.identifier)
            }
        }
    }
}

extension Day38_ViewController: ARSCNViewDelegate {

}

private extension SCNGeometry {

    static func fromAnchor(meshAnchor: ARMeshAnchor) -> SCNGeometry {
        let vertices = meshAnchor.geometry.vertices
        let normals = meshAnchor.geometry.normals
        let faces = meshAnchor.geometry.faces

        let vertexSource = SCNGeometrySource(buffer: vertices.buffer,
                                             vertexFormat: vertices.format,
                                             semantic: .vertex,
                                             vertexCount: vertices.count,
                                             dataOffset: vertices.offset,
                                             dataStride: vertices.stride)

        let normalsSource = SCNGeometrySource(buffer: normals.buffer,
                                              vertexFormat: normals.format,
                                              semantic: .normal,
                                              vertexCount: normals.count,
                                              dataOffset: normals.offset,
                                              dataStride: normals.stride)

        let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)

        let faceElement = SCNGeometryElement(data: faceData,
                                             primitiveType: .triangles,
                                             primitiveCount: faces.count,
                                             bytesPerIndex: faces.bytesPerIndex)

        let geometry = SCNGeometry(sources: [vertexSource, normalsSource], elements: [faceElement])

        let defaultMaterial = SCNMaterial()
        defaultMaterial.isDoubleSided = true
        defaultMaterial.diffuse.contents = UIColor(displayP3Red: 0, green: 1, blue: 0, alpha: 0.5)

        let material = SCNMaterial()
        material.isDoubleSided = true
        material.lightingModel = .constant

        let skScene = SKScene(size: CGSize(width: 256, height: 256))
        skScene.backgroundColor = UIColor(displayP3Red: 0.0, green: 0.0, blue: 1.0, alpha: 0.5)
        material.diffuse.contents = skScene

        geometry.materials = [defaultMaterial, material]

        return geometry
    }
}
