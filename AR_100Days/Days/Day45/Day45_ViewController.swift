import ARKit
import SceneKit

class Day45_ViewController: UIViewController {

    @IBOutlet weak var scnView: ARSCNView!

    private let device = MTLCreateSystemDefaultDevice()!
    private let gridSize = 6
    private let gridLength: Float = 0.4
    private let wallThickness: Float = 0.1
    private lazy var cellSize = gridLength / Float(gridSize)
    private let gridRootNode = SCNNode()
    private let gridCellParentNode = SCNNode()

    private lazy var vertices = [
        SCNVector3(-cellSize/2, 0.0, -cellSize/2),
        SCNVector3( cellSize/2, 0.0, -cellSize/2),
        SCNVector3(-cellSize/2, 0.0, cellSize/2),
        SCNVector3( cellSize/2, 0.0, cellSize/2),
    ]

    private let indices: [Int32] = [
        0, 2, 1,
        1, 2, 3
    ]

    private var time = 0
    private var isTouching = false

    override func viewDidLoad() {
        super.viewDidLoad()

        setupGridBox()

        scnView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        scnView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
}

extension Day45_ViewController: ARSCNViewDelegate {

    func renderer(_: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard let geometory = ARSCNPlaneGeometry(device: device) else { return }

        geometory.update(from: planeAnchor.geometry)

        let planeNode = SCNNode(geometry: geometory)
        planeNode.isHidden = true
        DispatchQueue.main.async {
            node.addChildNode(planeNode)
        }
    }

    func renderer(_: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        DispatchQueue.main.async {
            for childNode in node.childNodes {
                guard let planeGeometry = childNode.geometry as? ARSCNPlaneGeometry else { continue }
                planeGeometry.update(from: planeAnchor.geometry)
                break
            }
        }
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime _: TimeInterval) {

        if isTouching {
            isTouching = false
            DispatchQueue.main.async {
                guard self.gridRootNode.isHidden else { return }
                self.setupCellFaceTexture()
                self.gridRootNode.isHidden = false
            }
        }

        DispatchQueue.main.async {
            guard !self.gridRootNode.isHidden else { return }
            self.hourakuAnimation()
        }
    }
}

extension Day45_ViewController {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let _ = touches.first else { return }
        isTouching = true
    }

    private func setupCellFaceTexture() {

        let bounds = scnView.bounds
        let screenCenter = CGPoint(x: bounds.midX, y: bounds.midY)

        guard let query = scnView.raycastQuery(from: screenCenter, allowing: .existingPlaneGeometry, alignment: .any),
              let hitTestResult = scnView.session.raycast(query).first,
              let _ = hitTestResult.anchor as? ARPlaneAnchor
        else { return }

        let captureImage = scnView.snapshot()

        guard let cameraNode = scnView.pointOfView,
              let camera = cameraNode.camera else { return }

        //gridRootNode.simdTransform = existingPlaneUsingGeometryResult.worldTransform
        gridRootNode.simdTransform = hitTestResult.worldTransform
        for cellNode in gridCellParentNode.childNodes {
            guard let cellFaceNode = cellNode.childNodes.first(where: {$0.name == "face"}) else { continue }
            guard let vertex = cellFaceNode.geometry?.sources.first(where: {$0.semantic == .vertex}) else { continue }
            guard let element = cellFaceNode.geometry?.elements.first else { continue }

            let modelTransform = cellFaceNode.simdWorldTransform
            let viewTransform = cameraNode.simdTransform.inverse
            let projectionTransform = simd_float4x4(camera.projectionTransform(withViewportSize: scnView.bounds.size))
            let mvpTransform = projectionTransform * viewTransform * modelTransform
            var texcoords: [CGPoint] = []
            for vertex in vertices {
                var position = matrix_multiply(mvpTransform, SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0))
                position = position / position.w
                let texcordX = CGFloat(position.x + 1.0) / 2.0
                let texcordY = CGFloat(-position.y + 1.0) / 2.0
                texcoords.append(CGPoint(x: texcordX, y: texcordY))
            }
            let texcoordSource = SCNGeometrySource(textureCoordinates: texcoords)
            let cellFaceGeometry = SCNGeometry(sources: [vertex, texcoordSource], elements: [element])
            let cellFaceMaterial = SCNMaterial()
            cellFaceMaterial.diffuse.contents = captureImage
            cellFaceGeometry.materials = [cellFaceMaterial]
            cellFaceNode.geometry = cellFaceGeometry
        }
    }

    private func hourakuAnimation() {

        guard time < 150 else { return }
        time += 1

        let _time = Float(time)
        let gridSize = Float(self.gridSize)

        let x = sin(Float.pi * 2 * _time/30.0) * _time / 150
        let y = cos(Float.pi * 2 * _time/30.0) * _time / 150
        let ygrid = Int((y + 1.0) / 2 * gridSize * gridSize) / self.gridSize * self.gridSize
        let xgrid = Int((x + 1.0) / 2 * gridSize) + ygrid

        guard 0 <= xgrid, xgrid < gridCellParentNode.childNodes.count else { return }

        let node = gridCellParentNode.childNodes[xgrid]

        guard node.physicsBody == nil else { return }

        let bodyLength = CGFloat(cellSize) * 1.0
        let box = SCNBox(width: bodyLength, height: bodyLength, length: bodyLength, chamferRadius: 0.0)
        let boxShape = SCNPhysicsShape(geometry: box, options: nil)
        let boxBody = SCNPhysicsBody(type: .dynamic, shape: boxShape)
        boxBody.continuousCollisionDetectionThreshold = 0.001
        node.physicsBody = boxBody
    }

    private func setupGridBox() {
        gridRootNode.isHidden = true

        gridCellParentNode.simdPosition = SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0)
        gridRootNode.addChildNode(gridCellParentNode)
        gridRootNode.simdPosition = SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0)
        scnView.scene.rootNode.addChildNode(gridRootNode)

        let cellFaceGeometry = makeCellFaceGeometry()
        let cellBoxGeometry = makeCellBoxGeometry()
        let cellLeftBackPos = -(gridLength / 2) + cellSize / 2
        for y in 0 ..< gridSize {
            for x in 0 ..< gridSize {
                let cellNode = SCNNode()
                cellNode.simdPosition = SIMD3<Float>(x: cellLeftBackPos + (cellSize * Float(x)), y: 0, z: cellLeftBackPos + (cellSize * Float(y)))
                gridCellParentNode.addChildNode(cellNode)
                let cellFaceNode = SCNNode(geometry: cellFaceGeometry)
                cellFaceNode.name = "face"
                cellFaceNode.simdPosition = SIMD3<Float>(x: 0.0, y: 0.0, z: 0.0)
                cellNode.addChildNode(cellFaceNode)
                let cellBoxNode = SCNNode(geometry: cellBoxGeometry)
                cellBoxNode.simdPosition = SIMD3<Float>(x: 0.0, y: -cellSize/2*1.001, z: 0.0)
                cellNode.addChildNode(cellBoxNode)
            }
        }

        let sideOuterBox = makeGridSideOuterGeometry()
        let sideInnerPlane = makeGridSideInnerGeometry()
        for i in 0..<4 {
            let x = sin(Float.pi / 2 * Float(i)) * gridLength / 2.0
            let z = cos(Float.pi / 2 * Float(i)) * gridLength / 2.0

            let outerNode = SCNNode(geometry: sideOuterBox)
            let nodePos = ((gridLength + wallThickness) / 2.0) / (gridLength / 2.0) * 1.001
            outerNode.simdPosition = SIMD3<Float>(x: x * nodePos, y: -gridLength/2.0, z: z * nodePos)
            outerNode.simdRotation = SIMD4<Float>(x: 0.0, y: 1.0, z: 0.0, w: -Float.pi / 2 * Float(i))
            outerNode.physicsBody = SCNPhysicsBody.static()
            outerNode.renderingOrder = -1
            gridRootNode.addChildNode(outerNode)

            let innerNode = SCNNode(geometry: sideInnerPlane)
            innerNode.simdPosition = SIMD3<Float>(x: x, y: -gridLength/2.0, z: z)
            innerNode.simdRotation = SIMD4<Float>(x: 0.0, y: 1.0, z: 0.0, w: -Float.pi / 2 * Float(i))
            gridRootNode.addChildNode(innerNode)
        }

        let bottomBox = makeGridButtomGeometry()
        let bottomNode = SCNNode(geometry: bottomBox)
        bottomNode.simdPosition = SIMD3<Float>(x: 0.0, y: -gridLength+Float(wallThickness), z: 0.0)
        bottomNode.simdRotation = SIMD4<Float>(x: 1.0, y: 0.0, z: 0.0, w: -Float.pi / 2)
        bottomNode.physicsBody = SCNPhysicsBody.static()
        gridRootNode.addChildNode(bottomNode)
    }

    private func makeCellFaceGeometry() -> SCNGeometry {
        let cellFaceVertices = SCNGeometrySource(vertices: vertices)
        let cellFaceIndices = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let cellFaceGeometry = SCNGeometry(sources: [cellFaceVertices], elements: [cellFaceIndices])
        let cellFaceMaterial = SCNMaterial()
        cellFaceMaterial.diffuse.contents = UIColor.clear
        cellFaceGeometry.materials = [cellFaceMaterial]
        return cellFaceGeometry
    }

    private func makeCellBoxGeometry() -> SCNGeometry {
        let cellBox = SCNBox(width: CGFloat(cellSize), height: CGFloat(cellSize), length: CGFloat(cellSize), chamferRadius: 0.0)
        let cellBoxMaterial = SCNMaterial()
        cellBoxMaterial.diffuse.contents = UIColor.black
        cellBox.materials = [cellBoxMaterial]
        return cellBox
    }

    private func makeGridSideOuterGeometry() -> SCNGeometry {
        let sideOuterBox = SCNBox(width: CGFloat(gridLength) * 1.001, height: CGFloat(gridLength), length: CGFloat(wallThickness), chamferRadius: 0)
        let sideOuterMaterial = SCNMaterial()
        sideOuterMaterial.transparency = 0.001
        sideOuterMaterial.diffuse.contents = UIColor.white
        sideOuterMaterial.isDoubleSided = true
        sideOuterBox.materials = [sideOuterMaterial]
        return sideOuterBox
    }

    private func makeGridSideInnerGeometry() -> SCNGeometry {
        let sideInnerPlane = SCNPlane(width: CGFloat(gridLength), height: CGFloat(gridLength))
        let sideInnerMaterial = SCNMaterial()
        sideInnerMaterial.diffuse.contents = UIColor.black
        sideInnerMaterial.isDoubleSided = true
        sideInnerPlane.materials = [sideInnerMaterial]
        return sideInnerPlane
    }

    private func makeGridButtomGeometry() -> SCNGeometry {
        let bottomBox = SCNBox(width: CGFloat(gridLength), height: CGFloat(gridLength), length: CGFloat(wallThickness), chamferRadius: 0)
        let bottomMaterial = SCNMaterial()
        bottomMaterial.diffuse.contents = UIColor.black
        bottomBox.materials = [bottomMaterial]
        return bottomBox
    }
}
