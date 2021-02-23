import UIKit
import SceneKit
import ARKit

class Day22_ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        sceneView.addGestureRecognizer(tap)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    @objc func didTap(_ sender:UITapGestureRecognizer) {

        guard let camera = sceneView.pointOfView else { return }

        let cameraPos = SCNVector3Make(0, 0, -3.5)
        let position = camera.convertPosition(cameraPos, to: nil)

        let wallNode = SCNNode()
        wallNode.position = position

        let sideLength = Nodes.WALL_LENGTH * 3
        let halfSideLength = sideLength * 0.5

        let endWallSegmentNode = Nodes.wallSegmentNode(length: sideLength, maskXUpperSide: true)
        endWallSegmentNode.eulerAngles = SCNVector3(0, 90.0.degreesToRadians, 0)
        endWallSegmentNode.position = SCNVector3(0, Float(Nodes.WALL_HEIGHT * 0.5), Float(Nodes.WALL_LENGTH) * -1.5)
        wallNode.addChildNode(endWallSegmentNode)

        let sideAWallSegmentNode = Nodes.wallSegmentNode(length: sideLength, maskXUpperSide: true)
        sideAWallSegmentNode.eulerAngles = SCNVector3(0, 180.0.degreesToRadians, 0)
        sideAWallSegmentNode.position = SCNVector3(Float(Nodes.WALL_LENGTH) * -1.5, Float(Nodes.WALL_HEIGHT * 0.5), 0)
        wallNode.addChildNode(sideAWallSegmentNode)

        let sideBWallSegmentNode = Nodes.wallSegmentNode(length: sideLength, maskXUpperSide: true)
        sideBWallSegmentNode.position = SCNVector3(Float(Nodes.WALL_LENGTH) * 1.5, Float(Nodes.WALL_HEIGHT * 0.5), 0)
        wallNode.addChildNode(sideBWallSegmentNode)

        let doorSideLength = (sideLength - Nodes.DOOR_WIDTH) * 0.5

        let leftDoorSideNode = Nodes.wallSegmentNode(length: doorSideLength, maskXUpperSide: true)
        leftDoorSideNode.eulerAngles = SCNVector3(0, 270.0.degreesToRadians, 0)
        leftDoorSideNode.position = SCNVector3(Float(-halfSideLength + 0.5 * doorSideLength),
                                               Float(Nodes.WALL_HEIGHT) * Float(0.5),
                                               Float(Nodes.WALL_LENGTH) * 1.5)
        wallNode.addChildNode(leftDoorSideNode)

        let rightDoorSideNode = Nodes.wallSegmentNode(length: doorSideLength, maskXUpperSide: true)
        rightDoorSideNode.eulerAngles = SCNVector3(0, 270.0.degreesToRadians, 0)
        rightDoorSideNode.position = SCNVector3(Float(halfSideLength - 0.5 * doorSideLength),
                                                Float(Nodes.WALL_HEIGHT) * Float(0.5),
                                                Float(Nodes.WALL_LENGTH) * 1.5)
        wallNode.addChildNode(rightDoorSideNode)

        let aboveDoorNode = Nodes.wallSegmentNode(length: Nodes.DOOR_WIDTH, height: Nodes.WALL_HEIGHT - Nodes.DOOR_HEIGHT)
        aboveDoorNode.eulerAngles = SCNVector3(0, 270.0.degreesToRadians, 0)
        aboveDoorNode.position = SCNVector3(0,
                                            Float(Nodes.WALL_HEIGHT) - Float(Nodes.WALL_HEIGHT - Nodes.DOOR_HEIGHT) * 0.5,
                                            Float(Nodes.WALL_LENGTH) * 1.5)
        wallNode.addChildNode(aboveDoorNode)

        let floorNode = Nodes.plane(pieces: 3, maskYUpperSide: false)
        floorNode.position = SCNVector3(0, 0, 0)
        wallNode.addChildNode(floorNode)

        let roofNode = Nodes.plane(pieces: 3, maskYUpperSide: true)
        roofNode.position = SCNVector3(0, Float(Nodes.WALL_HEIGHT), 0)
        wallNode.addChildNode(roofNode)

        sceneView.scene.rootNode.addChildNode(wallNode)

        let floor = SCNFloor()
        floor.reflectivity = 0
        floor.firstMaterial?.diffuse.contents = UIColor.white
        floor.firstMaterial?.colorBufferWriteMask = SCNColorMask(rawValue: 0)
        let floorShadowNode = SCNNode(geometry:floor)
        floorShadowNode.position = position// newPlaneData.1
        sceneView.scene.rootNode.addChildNode(floorShadowNode)

        let light = SCNLight()
        light.type = .spot
        light.spotInnerAngle = 70
        light.spotOuterAngle = 120
        light.zNear = 0.00001
        light.zFar = 5
        light.castsShadow = true
        light.shadowRadius = 200
        light.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        light.shadowMode = .deferred
        let constraint = SCNLookAtConstraint(target: floorShadowNode)
        constraint.isGimbalLockEnabled = true
        let lightNode = SCNNode()
        lightNode.light = light
        lightNode.position = SCNVector3(position.x,
                                        position.y + Float(Nodes.DOOR_HEIGHT),
                                        position.z - Float(Nodes.WALL_LENGTH))
        lightNode.constraints = [constraint]
        sceneView.scene.rootNode.addChildNode(lightNode)
    }
}

private final class Nodes {

    static let WALL_WIDTH: CGFloat = 0.02
    static let WALL_HEIGHT: CGFloat = 2.2
    static let WALL_LENGTH: CGFloat = 1

    static let DOOR_WIDTH: CGFloat = 0.6
    static let DOOR_HEIGHT: CGFloat = 1.5

    class func plane(pieces:Int, maskYUpperSide:Bool = true) -> SCNNode {
        let maskSegment = SCNBox(width: Nodes.WALL_LENGTH * CGFloat(pieces),
                                 height: Nodes.WALL_WIDTH,
                                 length: Nodes.WALL_LENGTH * CGFloat(pieces),
                                 chamferRadius: 0)
        maskSegment.firstMaterial?.diffuse.contents = UIColor.red
        maskSegment.firstMaterial?.transparency = 0.000001
        maskSegment.firstMaterial?.writesToDepthBuffer = true
        let maskNode = SCNNode(geometry: maskSegment)
        maskNode.renderingOrder = 100

        let segment = SCNBox(width: Nodes.WALL_LENGTH * CGFloat(pieces),
                             height: Nodes.WALL_WIDTH,
                             length: Nodes.WALL_LENGTH * CGFloat(pieces),
                             chamferRadius: 0)
        segment.firstMaterial?.diffuse.contents = UIColor.blue
        segment.firstMaterial?.writesToDepthBuffer = true
        segment.firstMaterial?.readsFromDepthBuffer = true

        let segmentNode = SCNNode(geometry: segment)
        segmentNode.renderingOrder = 200

        let node = SCNNode()
        segmentNode.position = SCNVector3(Nodes.WALL_WIDTH * 0.5, 0, 0)
        node.addChildNode(segmentNode)
        maskNode.position = SCNVector3(Nodes.WALL_WIDTH * 0.5, maskYUpperSide ? Nodes.WALL_WIDTH : -Nodes.WALL_WIDTH, 0)
        node.addChildNode(maskNode)
        return node
    }

    class func wallSegmentNode(length:CGFloat = Nodes.WALL_LENGTH,
                               height:CGFloat = Nodes.WALL_HEIGHT,
                               maskXUpperSide:Bool = true) -> SCNNode {
        let node = SCNNode()

        let wallSegment = SCNBox(width: Nodes.WALL_WIDTH,
                                 height: height,
                                 length: length,
                                 chamferRadius: 0)

        wallSegment.firstMaterial?.diffuse.contents = UIColor.blue
        wallSegment.firstMaterial?.writesToDepthBuffer = true
        wallSegment.firstMaterial?.readsFromDepthBuffer = true

        let wallSegmentNode = SCNNode(geometry: wallSegment)
        wallSegmentNode.renderingOrder = 200

        node.addChildNode(wallSegmentNode)

        let maskingWallSegment = SCNBox(width: Nodes.WALL_WIDTH,
                                        height: height,
                                        length: length,
                                        chamferRadius: 0)
        maskingWallSegment.firstMaterial?.diffuse.contents = UIColor.red
        maskingWallSegment.firstMaterial?.transparency = 0.000001
        maskingWallSegment.firstMaterial?.writesToDepthBuffer = true

        let maskingWallSegmentNode = SCNNode(geometry: maskingWallSegment)
        maskingWallSegmentNode.renderingOrder = 100

        maskingWallSegmentNode.position = SCNVector3(maskXUpperSide ? Nodes.WALL_WIDTH : -Nodes.WALL_WIDTH,0,0)
        node.addChildNode(maskingWallSegmentNode)

        return node
    }
}

private extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}

private extension SCNVector3 {
    static func positionFromTransform(_ transform: matrix_float4x4) -> SCNVector3 {
        return SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }
}
