import ARKit
import SceneKit
import UIKit

class Day51_ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!

    private let faceTextureSize = 640//1024
    private var faceUvGenerator: FaceTextureGenerator!
    private var scnFaceGeometry: ARSCNFaceGeometry!
    private var previewImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = false
        sceneView.rendersCameraGrain = true

        scnFaceGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)

        faceUvGenerator = FaceTextureGenerator(
            device: sceneView.device!,
            library: sceneView.device!.makeDefaultLibrary()!,
            viewportSize: view.bounds.size,
            face: scnFaceGeometry,
            textureSize: faceTextureSize)

        previewImageView = UIImageView(frame: CGRect(x: 0, y: 80, width: 180, height: 180))
        previewImageView.backgroundColor = .black
        view.addSubview(previewImageView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        resetTracking()
    }

    private func resetTracking() {
        sceneView.session.run(ARFaceTrackingConfiguration(),
                              options: [.removeExistingAnchors,
                                        .resetTracking,
                                        .resetSceneReconstruction,
                                        .stopTrackedRaycasts])
    }

    func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else {
            return nil
        }

        let node = SCNNode(geometry: scnFaceGeometry)
        scnFaceGeometry.firstMaterial?.diffuse.contents = faceUvGenerator.texture
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor,
              let frame = sceneView.session.currentFrame
        else {
            return
        }

        scnFaceGeometry.update(from: faceAnchor.geometry)
        faceUvGenerator.update(frame: frame, scene: sceneView.scene, headNode: node, geometry: scnFaceGeometry)

        DispatchQueue.main.async {
            if let uiImage = self.textureToImage(self.faceUvGenerator.texture) {
                self.previewImageView.image = uiImage
            }
        }
    }

    private func makeImage(for texture: MTLTexture) -> CGImage? {
        let width = texture.width
        let height = texture.height
        let pixelByteCount = 4 * MemoryLayout<UInt8>.size
        let imageBytesPerRow = width * pixelByteCount
        let imageByteCount = imageBytesPerRow * height
        let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: pixelByteCount)
        defer {
            imageBytes.deallocate()
        }

        texture.getBytes(imageBytes,
                         bytesPerRow: imageBytesPerRow,
                         from: MTLRegionMake2D(0, 0, width, height),
                         mipmapLevel: 0)

        let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear)!
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue))

        guard let bitmapContext = CGContext(data: nil,
                                            width: width,
                                            height: height,
                                            bitsPerComponent: 8,
                                            bytesPerRow: imageBytesPerRow,
                                            space: colorSpace,
                                            bitmapInfo: bitmapInfo.rawValue) else { return nil }
        bitmapContext.data?.copyMemory(from: imageBytes, byteCount: imageByteCount)
        return bitmapContext.makeImage()
    }

    private func textureToImage(_ texture: MTLTexture) -> UIImage? {
        if let image = makeImage(for: texture) {
            return UIImage(cgImage: image)
        }
        return nil
    }
}
