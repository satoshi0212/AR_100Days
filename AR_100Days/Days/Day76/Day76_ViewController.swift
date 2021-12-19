import UIKit
import ARKit
import SceneKit

class Day76_ViewController: UIViewController {

    private var sceneView: ARSCNView!
    private var videoSource: Any?
    
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
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARBodyTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    @objc func tapped() {
        if let videoSource = self.videoSource, sceneView.scene.background.contents as? UIColor == UIColor.black {
            sceneView.scene.background.contents = videoSource
        } else {
            videoSource = sceneView.scene.background.contents
            sceneView.scene.background.contents = UIColor.black
        }
    }
}

extension Day76_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        let plane = Plane(anchor: planeAnchor, in: sceneView)
        node.addChildNode(plane)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor,
            let plane = node.childNodes.first as? Plane
            else { return }

        if let planeGeometry = plane.meshNode.geometry as? ARSCNPlaneGeometry {
            planeGeometry.update(from: planeAnchor.geometry)
        }

        if let extentGeometry = plane.extentNode.geometry as? SCNPlane {
            extentGeometry.width = CGFloat(planeAnchor.extent.x)
            extentGeometry.height = CGFloat(planeAnchor.extent.z)
            plane.extentNode.simdPosition = planeAnchor.center
        }
        
        if let classificationNode = plane.classificationNode,
           let classificationGeometry = classificationNode.geometry as? SCNText {
            
            let currentClassification = planeAnchor.classification.description
            if let oldClassification = classificationGeometry.string as? String, oldClassification != currentClassification {
                classificationGeometry.string = currentClassification
                classificationNode.centerAlign()
            }
        }
    }
}

private extension ARPlaneAnchor.Classification {
    var description: String {
        switch self {
        case .wall:
            return "Wall"
        case .floor:
            return "Floor"
        case .ceiling:
            return "Ceiling"
        case .table:
            return "Table"
        case .seat:
            return "Seat"
        case .window:
            return "Window"
        case .door:
            return "Door"
        case .none(.unknown):
            return "Unknown"
        default:
            return ""
        }
    }
}

private extension SCNNode {
    func centerAlign() {
        let (min, max) = boundingBox
        let extents = SIMD3<Float>(max) - SIMD3<Float>(min)
        simdPivot = float4x4(translation: ((extents / 2) + SIMD3<Float>(min)))
    }
}

private extension UIColor {
    static let planeColor = UIColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0)
}

private class Plane: SCNNode {
    
    let meshNode: SCNNode
    let extentNode: SCNNode
    var classificationNode: SCNNode?
    
    init(anchor: ARPlaneAnchor, in sceneView: ARSCNView) {
        
        guard let meshGeometry = ARSCNPlaneGeometry(device: sceneView.device!) else { fatalError("Can't create plane geometry") }
        meshGeometry.update(from: anchor.geometry)
        meshNode = SCNNode(geometry: meshGeometry)
        
        let extentPlane: SCNPlane = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        extentNode = SCNNode(geometry: extentPlane)
        extentNode.simdPosition = anchor.center
        
        extentNode.eulerAngles.x = -.pi / 2

        super.init()

        self.setupMeshVisualStyle()
        self.setupExtentVisualStyle()

        addChildNode(meshNode)
        addChildNode(extentNode)
        
        let classification = anchor.classification.description
        let textNode = self.makeTextNode(classification)
        classificationNode = textNode
        textNode.centerAlign()
        
        extentNode.addChildNode(textNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMeshVisualStyle() {
        meshNode.opacity = 0.25
        guard let material = meshNode.geometry?.firstMaterial else { fatalError("ARSCNPlaneGeometry always has one material") }
        material.diffuse.contents = UIColor.planeColor
    }
    
    private func setupExtentVisualStyle() {
        extentNode.opacity = 0.6
        guard let material = extentNode.geometry?.firstMaterial else { fatalError("SCNPlane always has one material") }
        material.diffuse.contents = UIColor.planeColor

        let shader = """
#pragma body

float u = _surface.diffuseTexcoord.x;
float v = _surface.diffuseTexcoord.y;

float2 thickness = float2(0.005);
if (u > thickness[0] && u < (1.0 - thickness[0]) && v > thickness[1] && v < (1.0 - thickness[1])) {
    discard_fragment();
}
"""
            material.shaderModifiers = [.surface: shader]
    }
    
    private func makeTextNode(_ text: String) -> SCNNode {
        let textGeometry = SCNText(string: text, extrusionDepth: 1)
        textGeometry.font = UIFont(name: "Futura", size: 100)
        let textNode = SCNNode(geometry: textGeometry)
        textNode.simdScale = SIMD3<Float>(repeating: 0.0005)
        return textNode
    }
}
