import ARKit
import SceneKit

private let PLANE_SCALE = Float(0.75)
private let PLANE_SEGS = 60

class PlaneNode: NSObject {
        
    public let contentNode: SCNNode
    private let geometryNode: SCNNode
    private let vertexEffectMaterial: SCNMaterial
    private let sceneView: ARSCNView
    private let viewportSize: CGSize
    private var time: Float = 0.0

    init(sceneView: ARSCNView, viewportSize: CGSize) {
        self.sceneView = sceneView
        self.viewportSize = viewportSize
        
        let plane = SCNPlane(width: 1.0, height: 1.0)
        plane.widthSegmentCount = PLANE_SEGS
        plane.heightSegmentCount = PLANE_SEGS
        
        contentNode = SCNNode()
        
        geometryNode = SCNNode(geometry: plane)
        geometryNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        geometryNode.scale = SCNVector3(PLANE_SCALE, PLANE_SCALE, PLANE_SCALE)
        contentNode.addChildNode(geometryNode)
        
        vertexEffectMaterial = PlaneNode.createMaterial(vertexFunctionName: "Day2_geometryEffectVertextShader", fragmentFunctionName: "Day2_geometryEffectFragmentShader")
        vertexEffectMaterial.setValue(SCNMaterialProperty(contents: sceneView.scene.background.contents!), forKey: "diffuseTexture")

        super.init()
        
        geometryNode.geometry!.firstMaterial = vertexEffectMaterial
    }
    
    func update(time: TimeInterval, timeDelta: Float) {
        self.time += timeDelta
        guard let frame = sceneView.session.currentFrame else { return }
        
        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize)
        let transform = SCNMatrix4(affineTransform)
        
        let material = geometryNode.geometry!.firstMaterial!
        material.setValue(SCNMatrix4Invert(transform), forKey: "u_displayTransform")
        material.setValue(NSNumber(value: self.time), forKey: "u_time")
    }
    
    private static func createMaterial(vertexFunctionName: String, fragmentFunctionName: String)-> SCNMaterial {
        let program = SCNProgram()
        program.vertexFunctionName = vertexFunctionName
        program.fragmentFunctionName = fragmentFunctionName
        
        let material = SCNMaterial()
        material.program = program
        
        return material
    }
}

