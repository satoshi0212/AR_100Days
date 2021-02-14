import Foundation
import Metal
import MetalKit
import ARKit
import MetalPerformanceShaders

protocol Day37_RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

class Day37_Renderer {

    // The max number of command buffers in flight.
    //let kMaxBuffersInFlight: Int = 3

    // Vertex data for an image plane.
    let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0
    ]

    let session: ARSession
    let device: MTLDevice
    let inFlightSemaphore = DispatchSemaphore(value: 3)
    var renderDestination: Day37_RenderDestinationProvider

    // Metal objects.
    var commandQueue: MTLCommandQueue!

    // An object that holds vertex information for source and destination rendering.
    var imagePlaneVertexBuffer: MTLBuffer!

    // An object that defines the Metal shaders that render the camera image and fog.
    var fogPipelineState: MTLRenderPipelineState!

    // Textures used to transfer the current camera image to the GPU for rendering.
    var cameraImageTextureY: CVMetalTexture?
    var cameraImageTextureCbCr: CVMetalTexture?

    // A texture used to store depth information from the current frame.
    var depthTexture: CVMetalTexture?

    // A texture used to pass confidence information to the GPU for fog rendering.
    var confidenceTexture: CVMetalTexture?

    // A texture of the blurred depth data to pass to the GPU for fog rendering.
    var filteredDepthTexture: MTLTexture!
    // A filter used to blur the depth data for rendering fog.
    var blurFilter: MPSImageGaussianBlur?

    // Captured image texture cache.
    var cameraImageTextureCache: CVMetalTextureCache!

    // The current viewport size.
    var viewportSize: CGSize = CGSize()

    // Flag for viewport size changes.
    var viewportSizeDidChange: Bool = false

    // Initialize a renderer by setting up the AR session, GPU, and screen backing-store.
    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: Day37_RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination

        // Perform one-time setup of the Metal objects.
        loadMetal()
    }

    // Schedule a draw to happen at a new size.
    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }

    func update() {
        // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
        // pipeline (App, Metal, Drivers, GPU, etc).
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // Create a new command buffer for each renderpass to the current drawable.
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"

            // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
            // finished proccssing the commands we're encoding this frame.  This indicates when the
            // dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
            // and the GPU.
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
            }

            updateAppState()

            applyGaussianBlur(commandBuffer: commandBuffer)

            // Pass the depth and confidence pixel buffers to the GPU to shade-in the fog.
            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable {

                if let fogRenderEncoding = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                    // Set a label to identify this render pass in a captured Metal frame.
                    fogRenderEncoding.label = "MyFogRenderEncoder"

                    // Schedule the camera image and fog to be drawn to the screen.
                    doFogRenderPass(renderEncoder: fogRenderEncoding)

                    // Finish encoding commands.
                    fogRenderEncoding.endEncoding()
                }

                // Schedule a present once the framebuffer is complete using the current drawable.
                commandBuffer.present(currentDrawable)
            }

            // Finalize rendering here & push the command buffer to the GPU.
            commandBuffer.commit()
        }
    }

    // MARK: - Private

    // Create and load our basic Metal state objects.
    func loadMetal() {
        // Set the default formats needed to render.
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1

        // Create a vertex buffer with our image plane vertex data.
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"

        // Load all the shader files with a metal file extension in the project.
        let defaultLibrary = device.makeDefaultLibrary()!

        // Create a vertex descriptor for our image plane vertex buffer.
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()

        // Positions.
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Texture coordinates.
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Buffer Layout.
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex

        // Create camera image texture cache.
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        cameraImageTextureCache = textureCache

        // Define the shaders that will render the camera image and fog on the GPU.
        let fogVertexFunction = defaultLibrary.makeFunction(name: "fogVertexTransform")!
        let fogFragmentFunction = defaultLibrary.makeFunction(name: "fogFragmentShader")!
        let fogPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        fogPipelineStateDescriptor.label = "MyFogPipeline"
        fogPipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        fogPipelineStateDescriptor.vertexFunction = fogVertexFunction
        fogPipelineStateDescriptor.fragmentFunction = fogFragmentFunction
        fogPipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        fogPipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat

        // Initialize the pipeline.
        do {
            try fogPipelineState = device.makeRenderPipelineState(descriptor: fogPipelineStateDescriptor)
        } catch let error {
            print("Failed to create fog pipeline state, error \(error)")
        }

        // Create the command queue for one frame of rendering work.
        commandQueue = device.makeCommandQueue()
    }

    // Updates any app state.
    func updateAppState() {

        // Get the AR session's current frame.
        guard let currentFrame = session.currentFrame else {
            return
        }

        // Prepare the current frame's camera image for transfer to the GPU.
        updateCameraImageTextures(frame: currentFrame)

        // Prepare the current frame's depth and confidence images for transfer to the GPU.
        updateARDepthTexures(frame: currentFrame)

        // Update the destination-rendering vertex info if the size of the screen changed.
        if viewportSizeDidChange {
            viewportSizeDidChange = false
            updateImagePlane(frame: currentFrame)
        }
    }

    // Creates two textures (Y and CbCr) to transfer the current frame's camera image to the GPU for rendering.
    func updateCameraImageTextures(frame: ARFrame) {
        if CVPixelBufferGetPlaneCount(frame.capturedImage) < 2 {
            return
        }
        cameraImageTextureY = createTexture(fromPixelBuffer: frame.capturedImage, pixelFormat: .r8Unorm, planeIndex: 0)
        cameraImageTextureCbCr = createTexture(fromPixelBuffer: frame.capturedImage, pixelFormat: .rg8Unorm, planeIndex: 1)
    }

    // Assigns an appropriate MTL pixel format given the argument pixel-buffer's format.
    fileprivate func setMTLPixelFormat(_ texturePixelFormat: inout MTLPixelFormat?, basedOn pixelBuffer: CVPixelBuffer!) {
        if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32 {
            texturePixelFormat = .r32Float
        } else if CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_OneComponent8 {
            texturePixelFormat = .r8Uint
        } else {
            fatalError("Unsupported ARDepthData pixel-buffer format.")
        }
    }

    // Prepares the scene depth information for transfer to the GPU for rendering.
    func updateARDepthTexures(frame: ARFrame) {
        // Get the scene depth or smoothed scene depth from the current frame.
        guard let sceneDepth = frame.smoothedSceneDepth ?? frame.sceneDepth else {
            print("Failed to acquire scene depth.")
            return
        }
        var pixelBuffer: CVPixelBuffer!
        pixelBuffer = sceneDepth.depthMap

        // Set up the destination pixel format for the depth information, and
        // create a Metal texture from the depth image provided by ARKit.
        var texturePixelFormat: MTLPixelFormat!
        setMTLPixelFormat(&texturePixelFormat, basedOn: pixelBuffer)
        depthTexture = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: texturePixelFormat, planeIndex: 0)

        // Get the current depth confidence values from the current frame.
        // Set up the destination pixel format for the confidence information, and
        // create a Metal texture from the confidence image provided by ARKit.
        pixelBuffer = sceneDepth.confidenceMap
        setMTLPixelFormat(&texturePixelFormat, basedOn: pixelBuffer)
        confidenceTexture = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: texturePixelFormat, planeIndex: 0)
    }

    // Creates a Metal texture with the argument pixel format from a CVPixelBuffer at the argument plane index.
    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    // Sets up vertex data (source and destination rectangles) rendering.
    func updateImagePlane(frame: ARFrame) {
        // Update the texture coordinates of the image plane to aspect fill the viewport.
        let displayToCameraTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize).inverted()
        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        let fogVertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
            fogVertexData[textureCoordIndex] = Float(transformedCoord.x)
            fogVertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }

    // Schedules the camera image and fog to be rendered on the GPU.
    func doFogRenderPass(renderEncoder: MTLRenderCommandEncoder) {
        guard let cameraImageY = cameraImageTextureY, let cameraImageCbCr = cameraImageTextureCbCr,
              let confidenceTexture = confidenceTexture else {
            return
        }

        // Push a debug group that enables you to identify this render pass in a Metal frame capture.
        renderEncoder.pushDebugGroup("FogPass")

        // Set render command encoder state.
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(fogPipelineState)

        // Setup plane vertex buffers.
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 1)

        // Setup textures for the fog fragment shader.
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageY), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(cameraImageCbCr), index: 1)
        renderEncoder.setFragmentTexture(filteredDepthTexture, index: 2)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(confidenceTexture), index: 3)
        // Draw final quad to display
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
    }

    // MARK: - MPS Filter

    // Sets up a filter to process the depth texture.
    func setupFilter(width: Int, height: Int) {
        // Create a destination backing-store to hold the blurred result.
        let filteredDepthDescriptor = MTLTextureDescriptor()
        filteredDepthDescriptor.pixelFormat = .r32Float
        filteredDepthDescriptor.width = width
        filteredDepthDescriptor.height = height
        filteredDepthDescriptor.usage = [.shaderRead, .shaderWrite]
        filteredDepthTexture = device.makeTexture(descriptor: filteredDepthDescriptor)
        blurFilter = MPSImageGaussianBlur(device: device, sigma: 5)
    }

    // Schedules the depth texture to be blurred on the GPU using the `blurFilter`.
    func applyGaussianBlur(commandBuffer: MTLCommandBuffer) {
        guard let arDepthTexture = depthTexture, let depthTexture = CVMetalTextureGetTexture(arDepthTexture) else {
            print("Error: Unable to apply the MPS filter.")
            return
        }
        guard let blur = blurFilter else {
            setupFilter(width: depthTexture.width, height: depthTexture.height)
            return
        }

        let inputImage = MPSImage(texture: depthTexture, featureChannels: 1)
        let outputImage = MPSImage(texture: filteredDepthTexture, featureChannels: 1)
        blur.encode(commandBuffer: commandBuffer, sourceImage: inputImage, destinationImage: outputImage)
    }
}
