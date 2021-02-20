import ARKit
import SceneKit
import UIKit

class Day41_ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet private var sceneView: ARSCNView!
    @IBOutlet weak fileprivate var imageView: DrawnImageView!

    private var currentFaceAnchor: ARFaceAnchor?
    private var currentController = TexturedFace()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        resetTracking()

        currentController.imageView = imageView

        if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
           let newContent = currentController.renderer(sceneView, nodeFor: anchor) {
            node.addChildNode(newContent)
        }
    }

    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    @IBAction func clearButton_action(_ sender: UIButton) {
        imageView.clear()
    }
}

extension Day41_ViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor

        if node.childNodes.isEmpty, let contentNode = currentController.renderer(renderer, nodeFor: faceAnchor) {
            node.addChildNode(contentNode)
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
              let contentNode = currentController.contentNode,
              contentNode.parent == node
        else { return }

        currentController.renderer(renderer, didUpdate: contentNode, for: anchor)
    }
}

private class TexturedFace: NSObject {

    var contentNode: SCNNode?
    var imageView: UIImageView?

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
              anchor is ARFaceAnchor else { return nil }

        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!)!
        let material = faceGeometry.firstMaterial!
        material.lightingModel = .physicallyBased

        contentNode = SCNNode(geometry: faceGeometry)
        return contentNode
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceGeometry = node.geometry as? ARSCNFaceGeometry,
              let faceAnchor = anchor as? ARFaceAnchor
        else { return }

        faceGeometry.update(from: faceAnchor.geometry)

        if let imageView = imageView {
            DispatchQueue.main.async {
                let material = faceGeometry.firstMaterial!
                material.diffuse.contents = imageView.image
            }
        }
    }
}

class DrawnImageView: UIImageView {

    private var swiped: Bool = false
    private var lastPoint: CGPoint = .zero

    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func clear() {
        image = UIImage(named: "day40")
    }

    func setupView() {
        alpha = 0.6
        backgroundColor = .gray
        isUserInteractionEnabled = true
        clear()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }

        swiped = true
        let currentPoint = touch.location(in: self)
        if lastPoint == .zero {
            lastPoint = currentPoint
        }
        drawLine(from: lastPoint, to: currentPoint)

        lastPoint = currentPoint
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        lastPoint = .zero
    }

    private func drawLine(from fromPoint: CGPoint, to toPoint: CGPoint) {

        UIGraphicsBeginImageContext(frame.size)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        image?.draw(in: bounds)

        context.move(to: fromPoint)
        context.addLine(to: toPoint)

        context.setLineCap(.round)
        context.setBlendMode(.normal)
        context.setLineWidth(8)
        context.setStrokeColor(UIColor.black.cgColor)

        context.strokePath()

        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
    }
}
