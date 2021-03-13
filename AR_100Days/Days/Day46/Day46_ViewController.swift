import UIKit
import QuartzCore
import SceneKit
import ARKit

class Day46_ViewController: UIViewController, SCNSceneRendererDelegate, ARSCNViewDelegate {

    @IBOutlet weak var arscnView: ARSCNView!
    @IBOutlet weak var mainView: SCNView!

    private var capturedNode: SCNNode!

    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var renderer: SCNRenderer!

    private var offscreenTexture: MTLTexture!
    private let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    private let bytesPerPixel = Int(4)
    private let bitsPerComponent = Int(8)
    private let bitsPerPixel:Int = 32

    private var textureSizeX: CGFloat!
    private var textureSizeY: CGFloat!

    override func viewDidLoad() {
        super.viewDidLoad()

        device = arscnView.device

        commandQueue = device.makeCommandQueue()
        renderer = SCNRenderer(device: device, options: nil)

        textureSizeX = arscnView.bounds.width
        textureSizeY = arscnView.bounds.height

        setupTexture()

        let mainScene = SCNScene(named: "SceneKitAssets.scnassets/main.scn")!

        capturedNode = mainScene.rootNode.childNode(withName: "box", recursively: false)!
        capturedNode.geometry?.firstMaterial?.diffuse.contents = offscreenTexture
        capturedNode.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 4)))

        mainView.scene = mainScene
        mainView.allowsCameraControl = true
        mainView.showsStatistics = true
        mainView.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        arscnView.delegate = self
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arscnView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    // MARK: - SceneKit Delegate

    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        sceneRender()
    }

    // MARK: - Metal

    func sceneRender() {
        let viewport = CGRect(x: 0, y: 0, width: CGFloat(textureSizeX), height: CGFloat(textureSizeY))

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = offscreenTexture

        let commandBuffer = commandQueue.makeCommandBuffer()

        let scene = SCNScene()
        //let scene = arscnView.scene

        renderer.scene = scene
        renderer.pointOfView = arscnView.pointOfView
        renderer.render(atTime: 0, viewport: viewport, commandBuffer: commandBuffer!, passDescriptor: renderPassDescriptor)

        commandBuffer?.commit()
    }

    func setupTexture() {
        var rawData0 = [UInt8](repeating: 0, count: Int(textureSizeX) * Int(textureSizeY) * 4)
        let bytesPerRow = 4 * Int(textureSizeX)
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: MTLPixelFormat.rgba8Unorm, width: Int(textureSizeX), height: Int(textureSizeY), mipmapped: false)
        textureDescriptor.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        let texture = device.makeTexture(descriptor: textureDescriptor)
        let region = MTLRegionMake2D(0, 0, Int(textureSizeX), Int(textureSizeY))
        texture?.replace(region: region, mipmapLevel: 0, withBytes: &rawData0, bytesPerRow: Int(bytesPerRow))
        offscreenTexture = texture
    }
}
