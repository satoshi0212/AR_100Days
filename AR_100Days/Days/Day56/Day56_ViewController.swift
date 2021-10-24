import ARKit
import Metal
import MetalKit
import CoreImage

class Day56_ViewController: UIViewController, UIGestureRecognizerDelegate {

    private var mtkView: MTKView!

    private var session: ARSession!

    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue!
    lazy private var textureCache: CVMetalTextureCache = {
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &cache)
        return cache!
    }()

    private var texture: MTLTexture!

    lazy private var renderer = PointCloudRenderer(device: device,session: session, mtkView: mtkView)

    var orientation: UIInterfaceOrientation {
        guard let orientation = UIApplication.shared.windows.first?.windowScene?.interfaceOrientation else {
            fatalError()
        }
        return orientation
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mtkView = MTKView(frame: view.bounds)
        view.addSubview(mtkView)
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: mtkView!, attribute: $0, relatedBy: .equal, toItem: mtkView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        view.sendSubviewToBack(mtkView)

        session = ARSession()

        commandQueue = device.makeCommandQueue()
        mtkView.device = device
        mtkView.framebufferOnly = false
        mtkView.delegate = self

        let width = mtkView.currentDrawable!.texture.width
        let height = mtkView.currentDrawable!.texture.height

        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: mtkView.colorPixelFormat,
                                                                 width: height, height: width, mipmapped: false)
        colorDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.environmentTexturing = .automatic
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }
        session.run(configuration)
    }
}

extension Day56_ViewController: MTKViewDelegate {

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        guard session.currentFrame != nil else { return }
        renderer.drawRectResized(size: size)
    }

    func draw(in view: MTKView) {

        guard let drawable = view.currentDrawable,
              let renderPassDescriptor = view.currentRenderPassDescriptor
        else { return }

        guard let (textureY, textureCbCr) = session.currentFrame?.buildCapturedImageTextures(textureCache: textureCache) else { return }
        guard let (depthTexture, confidenceTexture) = session.currentFrame?.buildDepthTextures(textureCache: textureCache) else { return }

        let commandBuffer = commandQueue.makeCommandBuffer()!

        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderer.update(commandBuffer,
                        renderEncoder: encoder,
                        capturedImageTextureY: textureY,
                        capturedImageTextureCbCr: textureCbCr,
                        depthTexture: depthTexture,
                        confidenceTexture: confidenceTexture)

        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
}

extension ARFrame {
    
    fileprivate func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int, textureCache: CVMetalTextureCache) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    func buildCapturedImageTextures(textureCache: CVMetalTextureCache) -> (textureY: CVMetalTexture, textureCbCr: CVMetalTexture)? {
        let pixelBuffer = capturedImage

        guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
            return nil
        }

        guard let capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0, textureCache: textureCache),
              let capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1, textureCache: textureCache) else {
                  return nil
              }

        return (textureY: capturedImageTextureY, textureCbCr: capturedImageTextureCbCr)
    }

    func buildDepthTextures(textureCache: CVMetalTextureCache) -> (depthTexture: CVMetalTexture, confidenceTexture: CVMetalTexture)? {
        guard let depthMap = self.sceneDepth?.depthMap,
              let confidenceMap = self.sceneDepth?.confidenceMap else {
                  return nil
              }

        guard let depthTexture = createTexture(fromPixelBuffer: depthMap, pixelFormat: .r32Float, planeIndex: 0, textureCache: textureCache),
              let confidenceTexture = createTexture(fromPixelBuffer: confidenceMap, pixelFormat: .r8Uint, planeIndex: 0, textureCache: textureCache) else {
                  return nil
              }

        return (depthTexture: depthTexture, confidenceTexture: confidenceTexture)
    }
}
