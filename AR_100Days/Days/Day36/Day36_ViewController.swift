import UIKit
import SceneKit

class Day36_ViewController: UIViewController {

    override func loadView() {

        let sceneView = SCNView()
        self.view = sceneView

        sceneView.backgroundColor = .black
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true

        let scene = SCNScene()
        sceneView.scene = scene

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 11)
        scene.rootNode.addChildNode(cameraNode)

        let half = Float(2)
        let vertices = [
            // 手前
            SCNVector3(-half, +half, +half), // 手前+左上 0
            SCNVector3(+half, +half, +half), // 手前+右上 1
            SCNVector3(-half, -half, +half), // 手前+左下 2
            SCNVector3(+half, -half, +half), // 手前+右下 3

            // 奥
            SCNVector3(-half, +half, -half), // 奥+左上 4
            SCNVector3(+half, +half, -half), // 奥+右上 5
            SCNVector3(-half, -half, -half), // 奥+左下 6
            SCNVector3(+half, -half, -half), // 奥+右下 7

            // 左側
            SCNVector3(-half, +half, -half), // 8 (=4)
            SCNVector3(-half, +half, +half), // 9 (=0)
            SCNVector3(-half, -half, -half), // 10 (=6)
            SCNVector3(-half, -half, +half), // 11 (=2)

            // 右側
            SCNVector3(+half, +half, +half), // 12 (=1)
            SCNVector3(+half, +half, -half), // 13 (=5)
            SCNVector3(+half, -half, +half), // 14 (=3)
            SCNVector3(+half, -half, -half), // 15 (=7)

            // 上側
            SCNVector3(-half, +half, -half), // 16 (=4)
            SCNVector3(+half, +half, -half), // 17 (=5)
            SCNVector3(-half, +half, +half), // 18 (=0)
            SCNVector3(+half, +half, +half), // 19 (=1)

            // 下側
            SCNVector3(-half, -half, +half), // 20 (=2)
            SCNVector3(+half, -half, +half), // 21 (=3)
            SCNVector3(-half, -half, -half), // 22 (=6)
            SCNVector3(+half, -half, -half), // 23 (=7)
        ]

        let texcoords = [
            // 手前
            SIMD2<Float>(0, 0),
            SIMD2<Float>(1 / 6, 0),
            SIMD2<Float>(0, 1),
            SIMD2<Float>(1 / 6, 1),

            // 奥
            SIMD2<Float>(1, 0),
            SIMD2<Float>(5 / 6, 0),
            SIMD2<Float>(1, 1),
            SIMD2<Float>(5 / 6, 1),

            // 左側
            SIMD2<Float>(1 / 6, 0),
            SIMD2<Float>(2 / 6, 0),
            SIMD2<Float>(1 / 6, 1),
            SIMD2<Float>(2 / 6, 1),

            // 右側
            SIMD2<Float>(4 / 6, 0),
            SIMD2<Float>(5 / 6, 0),
            SIMD2<Float>(4 / 6, 1),
            SIMD2<Float>(5 / 6, 1),

            // 上側
            SIMD2<Float>(2 / 6, 0),
            SIMD2<Float>(3 / 6, 0),
            SIMD2<Float>(2 / 6, 1),
            SIMD2<Float>(3 / 6, 1),

            // 下側
            SIMD2<Float>(3 / 6, 0),
            SIMD2<Float>(4 / 6, 0),
            SIMD2<Float>(3 / 6, 1),
            SIMD2<Float>(4 / 6, 1),
        ]

//        let textureCoordinates = [
//            // 手前
//            CGPoint(x: 0, y: 0),
//            CGPoint(x: 1/6, y: 0),
//            CGPoint(x: 0, y: 1),
//            CGPoint(x: 1/6, y: 1),
//
//            // 奥
//            CGPoint(x: 1, y: 0),
//            CGPoint(x: 5/6, y: 0),
//            CGPoint(x: 1, y: 1),
//            CGPoint(x: 5/6, y: 1),
//
//            // 左側
//            CGPoint(x: 1/6, y: 0),
//            CGPoint(x: 2/6, y: 0),
//            CGPoint(x: 1/6, y: 1),
//            CGPoint(x: 2/6, y: 1),
//
//            // 右側
//            CGPoint(x: 4/6, y: 0),
//            CGPoint(x: 5/6, y: 0),
//            CGPoint(x: 4/6, y: 1),
//            CGPoint(x: 5/6, y: 1),
//
//            // 上側
//            CGPoint(x: 2/6, y: 0),
//            CGPoint(x: 3/6, y: 0),
//            CGPoint(x: 2/6, y: 1),
//            CGPoint(x: 3/6, y: 1),
//
//            // 下側
//            CGPoint(x: 3/6, y: 0),
//            CGPoint(x: 4/6, y: 0),
//            CGPoint(x: 3/6, y: 1),
//            CGPoint(x: 4/6, y: 1),
//        ]

        let normals = [
            // 手前
            SCNVector3(0, 0, 1),
            SCNVector3(0, 0, 1),
            SCNVector3(0, 0, 1),
            SCNVector3(0, 0, 1),

            // 奥
            SCNVector3(0, 0, -1),
            SCNVector3(0, 0, -1),
            SCNVector3(0, 0, -1),
            SCNVector3(0, 0, -1),

            // 左側
            SCNVector3(-1, 0, 0),
            SCNVector3(-1, 0, 0),
            SCNVector3(-1, 0, 0),
            SCNVector3(-1, 0, 0),

            // 右側
            SCNVector3(1, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(1, 0, 0),
            SCNVector3(1, 0, 0),

            // 上側
            SCNVector3(0, 1, 0),
            SCNVector3(0, 1, 0),
            SCNVector3(0, 1, 0),
            SCNVector3(0, 1, 0),

            // 下側
            SCNVector3(0, -1, 0),
            SCNVector3(0, -1, 0),
            SCNVector3(0, -1, 0),
            SCNVector3(0, -1, 0),
        ]

        // ポリゴンを定義します。
        let indices: [Int32] = [
            // 手前
            0, 2, 1,
            1, 2, 3,

            // 奥
            4, 5, 7,
            4, 7, 6,

            // 左側
            8, 10, 9,
            9, 10, 11,

            // 右側
            13, 12, 14,
            13, 14, 15,

            // 上側
            16, 18, 17,
            17, 18, 19,

            // 下側
            22, 23, 20,
            23, 21, 20,
        ]

        let verticesSource = SCNGeometrySource(vertices: vertices)
        let normalsSource = SCNGeometrySource(normals: normals)

        let textureCoordinatesSource = SCNGeometrySource(textureCoordinates: texcoords)
        //let textureCoordinatesSource = SCNGeometrySource(textureCoordinates: textureCoordinates)

        let faceSource = SCNGeometryElement(indices: indices, primitiveType: .triangles)

        let customGeometry = SCNGeometry(sources: [verticesSource, normalsSource, textureCoordinatesSource], elements: [faceSource])

        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: "day36")
        customGeometry.materials = [material]

        scene.rootNode.addChildNode(SCNNode(geometry: customGeometry))
    }
}

extension SCNGeometrySource {

    convenience init(textureCoordinates texcoord: [SIMD2<Float>]) {
        let data = Data(bytes: texcoord, count: MemoryLayout<SIMD2<Float>>.size * texcoord.count)
        self.init(data: data,
                  semantic: .texcoord,
                  vectorCount: texcoord.count,
                  usesFloatComponents: true,
                  componentsPerVector: 2,
                  bytesPerComponent: MemoryLayout<Float>.size,
                  dataOffset: 0,
                  dataStride: MemoryLayout<SIMD2<Float>>.size)
    }
}
