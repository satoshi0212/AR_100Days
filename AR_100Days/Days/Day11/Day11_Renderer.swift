import Foundation
import Metal
import MetalKit
import ARKit

protocol Day11_RenderDestinationProvider {
    var currentRenderPassDescriptor: MTLRenderPassDescriptor? { get }
    var currentDrawable: CAMetalDrawable? { get }
    var colorPixelFormat: MTLPixelFormat { get set }
    var depthStencilPixelFormat: MTLPixelFormat { get set }
    var sampleCount: Int { get set }
}

class Day11_Renderer {

    // The max number anchors our uniform buffer will hold
    let kMaxAnchorInstanceCount: Int = 64

    // The 16 byte aligned size of our uniform structures
    let kAlignedSharedUniformsSize: Int = (MemoryLayout<SharedUniforms>.size & ~0xFF) + 0x100
    let kAlignedInstanceUniformsSize: Int = ((MemoryLayout<InstanceUniforms>.size * 64) & ~0xFF) + 0x100

    // Vertex data for an image plane
    let kImagePlaneVertexData: [Float] = [
        -1.0, -1.0, 0.0, 1.0,
        1.0, -1.0, 1.0, 1.0,
        -1.0, 1.0, 0.0, 0.0,
        1.0, 1.0, 1.0, 0.0
    ]

    let session: ARSession
    let matteGenerator: ARMatteGenerator
    let device: MTLDevice
    let inFlightSemaphore = DispatchSemaphore(value: 3)
    var renderDestination: Day11_RenderDestinationProvider

    // Metal objects
    var commandQueue: MTLCommandQueue!
    var sharedUniformBuffer: MTLBuffer!
    var anchorUniformBuffer: MTLBuffer!
    var imagePlaneVertexBuffer: MTLBuffer!
    var scenePlaneVertexBuffer: MTLBuffer!
    var capturedImagePipelineState: MTLRenderPipelineState!
    var capturedImageDepthState: MTLDepthStencilState!
    var anchorPipelineState: MTLRenderPipelineState!
    var anchorDepthState: MTLDepthStencilState!
    var compositePipelineState: MTLRenderPipelineState!
    var compositeDepthState: MTLDepthStencilState!

    var capturedImageTextureY: CVMetalTexture?
    var capturedImageTextureCbCr: CVMetalTexture?

    // Matting textures to be filled by ARMattingGenerator
    var alphaTexture: MTLTexture?
    var dilatedDepthTexture: MTLTexture?

    // Temporary render targets for 3d scene
    var sceneColorTexture: MTLTexture!
    var sceneDepthTexture: MTLTexture!

    // Captured image texture cache
    var capturedImageTextureCache: CVMetalTextureCache!

    // Metal vertex descriptor specifying how vertices will by laid out for input into our
    //   anchor geometry render pipeline and how we'll layout our Model IO verticies
    var geometryVertexDescriptor: MTLVertexDescriptor!

    // MetalKit mesh containing vertex data and index buffer for our anchor geometry
    var cubeMesh: MTKMesh!

    // Used to determine _uniformBufferStride each frame.
    //   This is the current frame number modulo kMaxBuffersInFlight
    var uniformBufferIndex: Int = 0

    // Offset within _sharedUniformBuffer to set for the current frame
    var sharedUniformBufferOffset: Int = 0

    // Offset within _anchorUniformBuffer to set for the current frame
    var anchorUniformBufferOffset: Int = 0

    // Addresses to write shared uniforms to each frame
    var sharedUniformBufferAddress: UnsafeMutableRawPointer!

    // Addresses to write anchor uniforms to each frame
    var anchorUniformBufferAddress: UnsafeMutableRawPointer!

    // The number of anchor instances to render
    var anchorInstanceCount: Int = 0

    // The current viewport size
    var viewportSize: CGSize = CGSize()

    // Flag for viewport size changes
    var viewportSizeDidChange: Bool = false

    init(session: ARSession, metalDevice device: MTLDevice, renderDestination: Day11_RenderDestinationProvider) {
        self.session = session
        self.device = device
        self.renderDestination = renderDestination
        matteGenerator = ARMatteGenerator(device: device, matteResolution: .half)
        loadMetal()
        loadAssets()
    }

    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }

    func update() {
        // Wait to ensure only kMaxBuffersInFlight are getting proccessed by any stage in the Metal
        //   pipeline (App, Metal, Drivers, GPU, etc)
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        // Create a new command buffer for each renderpass to the current drawable
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "MyCommand"

            // Add completion hander which signal _inFlightSemaphore when Metal and the GPU has fully
            //   finished proccssing the commands we're encoding this frame.  This indicates when the
            //   dynamic buffers, that we're writing to this frame, will no longer be needed by Metal
            //   and the GPU.
            // Retain our CVMetalTextures for the duration of the rendering cycle. The MTLTextures
            //   we use from the CVMetalTextures are not valid unless their parent CVMetalTextures
            //   are retained. Since we may release our CVMetalTexture ivars during the rendering
            //   cycle, we must retain them separately here.
            var textures = [capturedImageTextureY, capturedImageTextureCbCr]
            commandBuffer.addCompletedHandler { [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
                textures.removeAll()
            }

            updateBufferStates()
            updateGameState()
            updateMatteTextures(commandBuffer: commandBuffer)

            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor, let currentDrawable = renderDestination.currentDrawable {

                // Setup offscreen render pass for later compositing
                guard let sceneRenderDescriptor = renderPassDescriptor.copy() as? MTLRenderPassDescriptor else {
                    fatalError("Unable to create a render pass descriptor.")
                }
                sceneRenderDescriptor.colorAttachments[0].texture = sceneColorTexture
                sceneRenderDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
                sceneRenderDescriptor.colorAttachments[0].loadAction = .clear
                sceneRenderDescriptor.colorAttachments[0].storeAction = .store

                sceneRenderDescriptor.depthAttachment.texture = sceneDepthTexture
                sceneRenderDescriptor.depthAttachment.clearDepth = 1.0
                sceneRenderDescriptor.depthAttachment.loadAction = .clear
                sceneRenderDescriptor.depthAttachment.storeAction = .store

                if let sceneRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: sceneRenderDescriptor) {

                    sceneRenderEncoder.label = "MySceneRenderEncoder"

                    // "clear" render target to captured camera image
                    drawCapturedImage(renderEncoder: sceneRenderEncoder)

                    // Draw 3d scene to the same texture
                    drawAnchorGeometry(renderEncoder: sceneRenderEncoder)

                    // We're done encoding offscreen commands
                    sceneRenderEncoder.endEncoding()
                }

                // Perform final composite pass
                // Here we take the targets we just rendered camera and scene into and decide whether
                // to hide or show virtual content.
                if let compositeRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                    compositeRenderEncoder.label = "MyCompositeRenderEncoder"

                    // Composite images to final render targets
                    compositeImagesWithEncoder(renderEncoder: compositeRenderEncoder)

                    // We're done encoding commands
                    compositeRenderEncoder.endEncoding()
                }

                // Schedule a present once the framebuffer is complete using the current drawable
                commandBuffer.present(currentDrawable)
            }

            // Finalize rendering here & push the command buffer to the GPU
            commandBuffer.commit()
        }
    }

    // MARK: - Private
    func loadMetal() {
        // Create and load our basic Metal state objects

        // Set the default formats needed to render
        renderDestination.depthStencilPixelFormat = .depth32Float
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1

        // Calculate our uniform buffer sizes. We allocate kMaxBuffersInFlight instances for uniform
        //   storage in a single buffer. This allows us to update uniforms in a ring (i.e. triple
        //   buffer the uniforms) so that the GPU reads from one slot in the ring wil the CPU writes
        //   to another. Anchor uniforms should be specified with a max instance count for instancing.
        //   Also uniform storage must be aligned (to 256 bytes) to meet the requirements to be an
        //   argument in the constant address space of our shading functions.
        let sharedUniformBufferSize = kAlignedSharedUniformsSize * 3
        let anchorUniformBufferSize = kAlignedInstanceUniformsSize * 3

        // Create and allocate our uniform buffer objects. Indicate shared storage so that both the
        //   CPU can access the buffer
        sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
        sharedUniformBuffer.label = "SharedUniformBuffer"

        anchorUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)
        anchorUniformBuffer.label = "AnchorUniformBuffer"

        // Create a vertex buffer with our image plane vertex data.
        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        imagePlaneVertexBuffer.label = "ImagePlaneVertexBuffer"

        scenePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])
        scenePlaneVertexBuffer.label = "ScenePlaneVertexBuffer"

        // Load all the shader files with a metal file extension in the project
        let defaultLibrary = device.makeDefaultLibrary()!

        let capturedImageVertexFunction = defaultLibrary.makeFunction(name: "capturedImageVertexTransform")!
        let capturedImageFragmentFunction = defaultLibrary.makeFunction(name: "capturedImageFragmentShader")!

        // Create a vertex descriptor for our image plane vertex buffer
        let imagePlaneVertexDescriptor = MTLVertexDescriptor()

        // Positions.
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Texture coordinates.
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Buffer Layout
        imagePlaneVertexDescriptor.layouts[0].stride = 16
        imagePlaneVertexDescriptor.layouts[0].stepRate = 1
        imagePlaneVertexDescriptor.layouts[0].stepFunction = .perVertex

        // Create a pipeline state for rendering the captured image
        let capturedImagePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        capturedImagePipelineStateDescriptor.label = "MyCapturedImagePipeline"
        capturedImagePipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        capturedImagePipelineStateDescriptor.vertexFunction = capturedImageVertexFunction
        capturedImagePipelineStateDescriptor.fragmentFunction = capturedImageFragmentFunction
        capturedImagePipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        capturedImagePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        capturedImagePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat

        do {
            try capturedImagePipelineState = device.makeRenderPipelineState(descriptor: capturedImagePipelineStateDescriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }

        let capturedImageDepthStateDescriptor = MTLDepthStencilDescriptor()
        capturedImageDepthStateDescriptor.depthCompareFunction = .always
        capturedImageDepthStateDescriptor.isDepthWriteEnabled = false
        capturedImageDepthState = device.makeDepthStencilState(descriptor: capturedImageDepthStateDescriptor)

        // Create captured image texture cache
        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        capturedImageTextureCache = textureCache

        let anchorGeometryVertexFunction = defaultLibrary.makeFunction(name: "anchorGeometryVertexTransform")!
        let anchorGeometryFragmentFunction = defaultLibrary.makeFunction(name: "anchorGeometryFragmentLighting")!

        // Create a vertex descriptor for our Metal pipeline. Specifies the layout of vertices the
        //   pipeline should expect. The layout below keeps attributes used to calculate vertex shader
        //   output position separate (world position, skinning, tweening weights) separate from other
        //   attributes (texture coordinates, normals).  This generally maximizes pipeline efficiency
        geometryVertexDescriptor = MTLVertexDescriptor()

        // Positions.
        geometryVertexDescriptor.attributes[0].format = .float3
        geometryVertexDescriptor.attributes[0].offset = 0
        geometryVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Texture coordinates.
        geometryVertexDescriptor.attributes[1].format = .float2
        geometryVertexDescriptor.attributes[1].offset = 0
        geometryVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshGenerics.rawValue)

        // Normals.
        geometryVertexDescriptor.attributes[2].format = .half3
        geometryVertexDescriptor.attributes[2].offset = 8
        geometryVertexDescriptor.attributes[2].bufferIndex = Int(kBufferIndexMeshGenerics.rawValue)

        // Position Buffer Layout
        geometryVertexDescriptor.layouts[0].stride = 12
        geometryVertexDescriptor.layouts[0].stepRate = 1
        geometryVertexDescriptor.layouts[0].stepFunction = .perVertex

        // Generic Attribute Buffer Layout
        geometryVertexDescriptor.layouts[1].stride = 16
        geometryVertexDescriptor.layouts[1].stepRate = 1
        geometryVertexDescriptor.layouts[1].stepFunction = .perVertex

        // Create a reusable pipeline state for rendering anchor geometry
        let anchorPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        anchorPipelineStateDescriptor.label = "MyAnchorPipeline"
        anchorPipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        anchorPipelineStateDescriptor.vertexFunction = anchorGeometryVertexFunction
        anchorPipelineStateDescriptor.fragmentFunction = anchorGeometryFragmentFunction
        anchorPipelineStateDescriptor.vertexDescriptor = geometryVertexDescriptor
        anchorPipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        anchorPipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat

        do {
            try anchorPipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor)
        } catch let error {
            print("Failed to created anchor geometry pipeline state, error \(error)")
        }

        let anchorDepthStateDescriptor = MTLDepthStencilDescriptor()
        anchorDepthStateDescriptor.depthCompareFunction = .less
        anchorDepthStateDescriptor.isDepthWriteEnabled = true
        anchorDepthState = device.makeDepthStencilState(descriptor: anchorDepthStateDescriptor)

        // Create render targets for offscreen camera image and scene render
        let width = renderDestination.currentDrawable!.texture.width
        let height = renderDestination.currentDrawable!.texture.height

        let colorDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderDestination.colorPixelFormat,
                                                                 width: width, height: height, mipmapped: false)
        colorDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        sceneColorTexture = device.makeTexture(descriptor: colorDesc)

        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: renderDestination.depthStencilPixelFormat,
                                                                 width: width, height: height, mipmapped: false)
        depthDesc.usage = MTLTextureUsage(rawValue: MTLTextureUsage.renderTarget.rawValue | MTLTextureUsage.shaderRead.rawValue)
        sceneDepthTexture = device.makeTexture(descriptor: depthDesc)

        // Create composite pipeline
        let compositeImageVertexFunction = defaultLibrary.makeFunction(name: "compositeImageVertexTransform")!
        let compositeImageFragmentFunction = defaultLibrary.makeFunction(name: "compositeImageFragmentShader")!

        let compositePipelineStateDescriptor = MTLRenderPipelineDescriptor()
        compositePipelineStateDescriptor.label = "MyCompositePipeline"
        compositePipelineStateDescriptor.sampleCount = renderDestination.sampleCount
        compositePipelineStateDescriptor.vertexFunction = compositeImageVertexFunction
        compositePipelineStateDescriptor.fragmentFunction = compositeImageFragmentFunction
        compositePipelineStateDescriptor.colorAttachments[0].pixelFormat = renderDestination.colorPixelFormat
        compositePipelineStateDescriptor.depthAttachmentPixelFormat = renderDestination.depthStencilPixelFormat

        do {
            try compositePipelineState = device.makeRenderPipelineState(descriptor: compositePipelineStateDescriptor)
        } catch let error {
            print("Failed to create composite pipeline state, error \(error)")
        }

        let compositeDepthStateDescriptor = MTLDepthStencilDescriptor()
        compositeDepthStateDescriptor.depthCompareFunction = .always
        compositeDepthStateDescriptor.isDepthWriteEnabled = false
        compositeDepthState = device.makeDepthStencilState(descriptor: compositeDepthStateDescriptor)

        // Create the command queue
        commandQueue = device.makeCommandQueue()
    }

    func loadAssets() {
        // Create and load our assets into Metal objects including meshes and textures

        // Create a MetalKit mesh buffer allocator so that ModelIO will load mesh data directly into
        //   Metal buffers accessible by the GPU
        let metalAllocator = MTKMeshBufferAllocator(device: device)

        // Creata a Model IO vertexDescriptor so that we format/layout our model IO mesh vertices to
        //   fit our Metal render pipeline's vertex descriptor layout
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(geometryVertexDescriptor)

        // Indicate how each Metal vertex descriptor attribute maps to each ModelIO attribute
        if let vertexDescriptorAttribute = vertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)] as? MDLVertexAttribute {
            vertexDescriptorAttribute.name = MDLVertexAttributePosition
        }
        if let vertexDescriptorAttribute = vertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)] as? MDLVertexAttribute {
            vertexDescriptorAttribute.name = MDLVertexAttributePosition
        }
        if let vertexDescriptorAttribute = vertexDescriptor.attributes[Int(kVertexAttributeNormal.rawValue)] as? MDLVertexAttribute {
            vertexDescriptorAttribute.name = MDLVertexAttributePosition
        }

        // Use ModelIO to create a box mesh as our object
        let mesh = MDLMesh(boxWithExtent: vector3(0.4, 0.4, 0.4), segments: vector3(1, 1, 1), inwardNormals: false,
                           geometryType: .triangles, allocator: metalAllocator)

        // Perform the format/relayout of mesh vertices by setting the new vertex descriptor in our
        //   Model IO mesh
        mesh.vertexDescriptor = vertexDescriptor

        // Create a MetalKit mesh (and submeshes) backed by Metal buffers
        do {
            try cubeMesh = MTKMesh(mesh: mesh, device: device)
        } catch let error {
            print("Error creating MetalKit mesh, error \(error)")
        }
    }

    func updateBufferStates() {
        // Update the location(s) to which we'll write to in our dynamically changing Metal buffers for
        //   the current frame (i.e. update our slot in the ring buffer used for the current frame)

        uniformBufferIndex = (uniformBufferIndex + 1) % 3

        sharedUniformBufferOffset = kAlignedSharedUniformsSize * uniformBufferIndex
        anchorUniformBufferOffset = kAlignedInstanceUniformsSize * uniformBufferIndex

        sharedUniformBufferAddress = sharedUniformBuffer.contents().advanced(by: sharedUniformBufferOffset)
        anchorUniformBufferAddress = anchorUniformBuffer.contents().advanced(by: anchorUniformBufferOffset)
    }

    func updateGameState() {
        // Update any game state

        guard let currentFrame = session.currentFrame else {
            return
        }

        updateSharedUniforms(frame: currentFrame)
        updateAnchors(frame: currentFrame)
        updateCapturedImageTextures(frame: currentFrame)

        if viewportSizeDidChange {
            viewportSizeDidChange = false

            updateImagePlane(frame: currentFrame)
        }
    }

    func updateSharedUniforms(frame: ARFrame) {
        // Update the shared uniforms of the frame

        let uniforms = sharedUniformBufferAddress.assumingMemoryBound(to: SharedUniforms.self)

        uniforms.pointee.viewMatrix = frame.camera.viewMatrix(for: .portrait)
        uniforms.pointee.projectionMatrix = frame.camera.projectionMatrix(for: .portrait, viewportSize: viewportSize, zNear: 0.001, zFar: 1000)

        // Set up lighting for the scene using the ambient intensity if provided
        var ambientIntensity: Float = 1.0

        if let lightEstimate = frame.lightEstimate {
            ambientIntensity = Float(lightEstimate.ambientIntensity) / 1000.0
        }

        let ambientLightColor: vector_float3 = vector3(0.5, 0.5, 0.5)
        uniforms.pointee.ambientLightColor = ambientLightColor * ambientIntensity

        var directionalLightDirection: vector_float3 = vector3(0.0, 0.0, -1.0)
        directionalLightDirection = simd_normalize(directionalLightDirection)
        uniforms.pointee.directionalLightDirection = directionalLightDirection

        let directionalLightColor: vector_float3 = vector3(0.6, 0.6, 0.6)
        uniforms.pointee.directionalLightColor = directionalLightColor * ambientIntensity

        uniforms.pointee.materialShininess = 30

        // Check whether or not to sample estimated depth texture
        uniforms.pointee.useDepth = (session.configuration?.frameSemantics == ARConfiguration.FrameSemantics.personSegmentationWithDepth) ? 1 : 0
    }

    func updateAnchors(frame: ARFrame) {
        // Update the anchor uniform buffer with transforms of the current frame's anchors
        anchorInstanceCount = min(frame.anchors.count, kMaxAnchorInstanceCount)

        var anchorOffset: Int = 0
        if anchorInstanceCount == kMaxAnchorInstanceCount {
            anchorOffset = max(frame.anchors.count - kMaxAnchorInstanceCount, 0)
        }

        for index in 0..<anchorInstanceCount {
            let anchor = frame.anchors[index + anchorOffset]

            // Flip Z axis to convert geometry from right handed to left handed
            var coordinateSpaceTransform = matrix_identity_float4x4
            coordinateSpaceTransform.columns.2.z = -1.0

            let modelMatrix = simd_mul(anchor.transform, coordinateSpaceTransform)

            let anchorUniforms = anchorUniformBufferAddress.assumingMemoryBound(to: InstanceUniforms.self).advanced(by: index)
            anchorUniforms.pointee.modelMatrix = modelMatrix
        }
    }

    func updateCapturedImageTextures(frame: ARFrame) {
        // Create two textures (Y and CbCr) from the provided frame's captured image
        let pixelBuffer = frame.capturedImage

        if CVPixelBufferGetPlaneCount(pixelBuffer) < 2 {
            return
        }

        capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)
        capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)
    }

    func updateMatteTextures(commandBuffer: MTLCommandBuffer) {
        guard let currentFrame = session.currentFrame else {
            return
        }

        alphaTexture = matteGenerator.generateMatte(from: currentFrame, commandBuffer: commandBuffer)

        dilatedDepthTexture = matteGenerator.generateDilatedDepth(from: currentFrame, commandBuffer: commandBuffer)
    }

    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, capturedImageTextureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            texture = nil
        }

        return texture
    }

    func updateImagePlane(frame: ARFrame) {
        // Update the texture coordinates of our image plane to aspect fill the viewport
        let displayToCameraTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize).inverted()

        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        let compositeVertexData = scenePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]), y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)

            compositeVertexData[textureCoordIndex] = kImagePlaneVertexData[textureCoordIndex]
            compositeVertexData[textureCoordIndex + 1] = kImagePlaneVertexData[textureCoordIndex + 1]
        }
    }

    func drawCapturedImage(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawCapturedImage")

        // Set render command encoder state
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(capturedImagePipelineState)
        renderEncoder.setDepthStencilState(capturedImageDepthState)

        // Set mesh's vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: Int(kBufferIndexMeshPositions.rawValue))

        // Set any textures read/sampled from our render pipeline
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: Int(kTextureIndexY.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: Int(kTextureIndexCbCr.rawValue))

        // Draw each submesh of our mesh
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        renderEncoder.popDebugGroup()
    }

    func drawAnchorGeometry(renderEncoder: MTLRenderCommandEncoder) {
        guard anchorInstanceCount > 0 else {
            return
        }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("DrawAnchors")

        // Set render command encoder state
        renderEncoder.setCullMode(.back)
        renderEncoder.setRenderPipelineState(anchorPipelineState)
        renderEncoder.setDepthStencilState(anchorDepthState)

        // Set any buffers fed into our render pipeline
        renderEncoder.setVertexBuffer(anchorUniformBuffer, offset: anchorUniformBufferOffset, index: Int(kBufferIndexInstanceUniforms.rawValue))
        renderEncoder.setVertexBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))

        // Set mesh's vertex buffers
        for bufferIndex in 0..<cubeMesh.vertexBuffers.count {
            let vertexBuffer = cubeMesh.vertexBuffers[bufferIndex]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: bufferIndex)
        }

        // Draw each submesh of our mesh
        for submesh in cubeMesh.submeshes {
            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType, indexCount: submesh.indexCount,
                                                indexType: submesh.indexType, indexBuffer: submesh.indexBuffer.buffer,
                                                indexBufferOffset: submesh.indexBuffer.offset, instanceCount: anchorInstanceCount)
        }

        renderEncoder.popDebugGroup()
    }

    func compositeImagesWithEncoder(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = capturedImageTextureY, let textureCbCr = capturedImageTextureCbCr else {
            return
        }

        // Push a debug group allowing us to identify render commands in the GPU Frame Capture tool
        renderEncoder.pushDebugGroup("CompositePass")

        // Set render command encoder state
        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(compositePipelineState)
        renderEncoder.setDepthStencilState(compositeDepthState)

        // Setup plane vertex buffers
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(scenePlaneVertexBuffer, offset: 0, index: 1)

        // Setup textures for the composite fragment shader
        renderEncoder.setFragmentBuffer(sharedUniformBuffer, offset: sharedUniformBufferOffset, index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: 1)
        renderEncoder.setFragmentTexture(sceneColorTexture, index: 2)
        renderEncoder.setFragmentTexture(sceneDepthTexture, index: 3)
        renderEncoder.setFragmentTexture(alphaTexture, index: 4)
        renderEncoder.setFragmentTexture(dilatedDepthTexture, index: 5)

        // Draw final quad to display
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.popDebugGroup()
    }
}
