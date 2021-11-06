import Foundation
import UIKit
import ARKit
import SceneKit

class Day62_ViewController: UIViewController {

    private var sceneView: ARSCNView!

    private var boardNodes: [SCNNode] = []
    private let planeSize = CGSize(width: 0.2, height: 0.2)
    private let maxPlaneSize = CGSize(width: 4, height: 3)

    private var images: [Image] = []

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
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        view.sendSubviewToBack(sceneView)

        images = try! JSONDecoder().decode([Image].self, from: try! Foundation.Data(contentsOf: Bundle.main.url(forResource: "images", withExtension: "json")!))

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    private func setup(scene: SCNScene) {

        for i in 0..<3 {

            let boardPlane = SCNPlane(width: maxPlaneSize.width, height: maxPlaneSize.height)

            let material = SCNMaterial()
            material.diffuse.contents = UIColor.clear

            let boardNode = SCNNode(geometry: boardPlane)
            boardNode.position = SCNVector3(x: 0, y: 0, z: -0.5 * Float(i + 1))
            boardNode.geometry?.materials = [material]
            scene.rootNode.addChildNode(boardNode)
            boardNodes.append(boardNode)

            addChildNodes(boardNode: boardNode)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    private func planeNode(layer: CALayer, position: SCNVector3) -> SCNNode {
        let plane = SCNPlane(width: planeSize.width, height: planeSize.height)

        layer.frame = CGRect(x: 0, y: 0, width: 600, height: 600)
        plane.firstMaterial?.diffuse.contents = layer

        let node = SCNNode(geometry: plane)
        node.position = position

        return node
    }

    private var beforeSetup = true
    private var sorted = true

    @objc func tapped(recognizer: UIGestureRecognizer) {

        if beforeSetup {
            beforeSetup = false
            setup(scene: sceneView.scene)
            return
        }

        if sorted {
            sorted.toggle()
            randomSetChildeNodePositions()
        } else {
            sorted.toggle()
            resetChildeNodePositions()
        }
    }

    private func addChildNodes(boardNode: SCNNode) {
        var i: Int = 0
        var posCoefficient: Float = 0

        for image in images.shuffled().prefix(30) {

            posCoefficient += 0.3
            let layer = PhotoLayer()

            if let url = image.urls["regular"] {
                ImagePipeline.shared.load(url, into: layer.imageLayer)
            }
            layer.setTitle(image.description ?? image.alt_description ?? "")

            let x: Float = floor((posCoefficient - 0.01) / 1.5) * 0.4
            let y: Float = (posCoefficient - 0.01).truncatingRemainder(dividingBy: 1.5) + 0.01 - 1.0
            let z: Float = boardNode.position.z + Float(i) * 0.0001 // ちらつき回避のためzに差分設定

            let node = planeNode(layer: layer, position: SCNVector3(x: x, y: y, z: z))
            node.name = image.id

            boardNode.addChildNode(node)

            i += 1
        }
    }

    private func randomSetChildeNodePositions() {
        let size = CGSize(width: planeSize.width * 1.5, height: planeSize.height * 1.5)
        for boardNode in boardNodes {
            let newPoints = randomPoints(count: boardNode.childNodes.count, size: size)
            for i in 0..<boardNode.childNodes.count {
                let node = boardNode.childNodes[i]
                move(node: node, to: node.position, point: newPoints[i]) { }
            }
        }
    }

    private func resetChildeNodePositions() {
        for boardNode in boardNodes {
            var posCoefficient: Float = 0
            for node in boardNode.childNodes {
                posCoefficient += 0.3
                let x: Float = floor((posCoefficient - 0.01) / 1.5) * 0.4
                let y: Float = (posCoefficient - 0.01).truncatingRemainder(dividingBy: 1.5) + 0.01 - 1.0
                move(node: node, to: node.position, point: CGPoint(x: CGFloat(x), y: CGFloat(y))) { }
            }
        }
    }

    private func randomPoints(count: Int, size: CGSize) -> [CGPoint] {
        var ret: [CGPoint] = []
        while ret.count < count {
            if let point = randomPoint(size: size, positions: ret) {
                ret.append(point)
            }
        }
        return ret
    }

    private func randomPoint(size: CGSize, positions: [CGPoint]) -> CGPoint? {
        for _ in 0..<5000 {
            let x = CGFloat.random(in: 0...(maxPlaneSize.width / 2))
            let y = CGFloat.random(in: -maxPlaneSize.height...(maxPlaneSize.height / 2))
            let frame = CGRect(x: x, y: y, width: size.width, height: size.height)

            if positions.isEmpty {
                return frame.origin
            } else {
                var intersects = false
                for position in positions {
                    let f = CGRect(x: position.x, y: position.y, width: size.width, height: size.height)
                    if f.intersects(frame) {
                        intersects = true
                    }
                }
                if !intersects {
                    return frame.origin
                }
            }
        }
        return nil
    }

    private func move(node: SCNNode, to position: SCNVector3, point: CGPoint, duration: TimeInterval = 2, completion: @escaping () -> Void) {
        var position = position
        position.x = Float(point.x)
        position.y = Float(point.y)

        let action = SCNAction.move(to: position, duration: duration)
        action.timingMode = .linear
        action.timingFunction = {
            return simd_smoothstep(0, 1, $0)
        }

        node.runAction(action) {
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

fileprivate struct Image: Codable {
    let id: String
    let description: String?
    let alt_description: String?
    let urls: [String: URL]
}

fileprivate final class PhotoLayer: CALayer {
    private let backgroundLayer = CALayer()
    let imageLayer = CALayer()
    private let titleLayer = CATextLayer()

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0)

        backgroundLayer.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        backgroundLayer.cornerRadius = 10
        backgroundLayer.shadowColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        backgroundLayer.shadowRadius = 8
        backgroundLayer.shadowOpacity = 0.25
        backgroundLayer.shadowOffset = CGSize(width: 0, height: 0)
        backgroundLayer.shouldRasterize = true

        addSublayer(backgroundLayer)

        imageLayer.contentsScale = 2
        imageLayer.contentsGravity = .resizeAspectFill
        imageLayer.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        imageLayer.cornerRadius = 10
        imageLayer.masksToBounds = true
        backgroundLayer.addSublayer(imageLayer)

        titleLayer.contentsScale = 2
        titleLayer.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        titleLayer.foregroundColor = #colorLiteral(red: 0.2549019754, green: 0.2588235438, blue: 0.3058823645, alpha: 1)
        titleLayer.alignmentMode = .right
        titleLayer.font = UIFont.boldSystemFont(ofSize: 52)
        titleLayer.fontSize = 52
        titleLayer.isWrapped = true
        titleLayer.truncationMode = .end

        backgroundLayer.addSublayer(titleLayer)
    }

    func setTitle(_ title: String) {
        titleLayer.string = title
    }

    override func layoutSublayers() {
        super.layoutSublayers()

        let margin: CGFloat = 10

        var frame = bounds
        frame.origin = CGPoint(x: margin, y: margin)
        frame.size.width -= margin * 2
        frame.size.height -= margin * 2
        backgroundLayer.frame = frame

        frame = backgroundLayer.bounds
        frame.origin = CGPoint(x: margin, y: margin)
        frame.size.width -= margin
        frame.size.width -= margin

        frame.size.height = frame.size.width * (1 / 1.61803398875)
        frame.origin.y = backgroundLayer.bounds.height - frame.height - margin
        imageLayer.frame = frame

        titleLayer.frame = CGRect(x: frame.origin.x + margin, y: margin, width: frame.width - margin * 2, height: backgroundLayer.bounds.height - frame.height - margin * 3)
    }
}
