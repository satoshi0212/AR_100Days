import Foundation
import Metal
import MetalKit
import ARKit

struct FrameUniforms {
    var projectionMatrix: float4x4
    var viewMatrix: float4x4
}

struct InstanceUniforms {
    var modelMatrix: float4x4
}

struct WorldMesh {
    let transform: float4x4
    let vertices: ARGeometrySource
    let normals: ARGeometrySource
    let submesh: ARGeometryElement
}

let kMaxBuffersInFlight: Int = 3

let kMaxAnchorInstanceCount: Int = 64

let kAlignedFrameUniformsSize = 256
let kAlignedFragmentUniformsSize = 256
let kAlignedInstanceUniformsSize = 16_384

let kImagePlaneVertexData: [Float] = [
    -1.0, -1.0,  0.0, 1.0,
    1.0, -1.0,  1.0, 1.0,
    -1.0,  1.0,  0.0, 0.0,
    1.0,  1.0,  1.0, 0.0,
]

class Day4_Renderer {
    let session: ARSession
    let device: MTLDevice
    let inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    var mtkView: MTKView

    var commandQueue: MTLCommandQueue!
    var frameUniformBuffer: MTLBuffer!
    var anchorUniformBuffer: MTLBuffer!
    var fragmentUniformBuffer: MTLBuffer!
    var imagePlaneVertexBuffer: MTLBuffer!

    var cameraPipelineState: MTLRenderPipelineState!
    var anchorPipelineState: MTLRenderPipelineState!
    var outlinePipelineState: MTLRenderPipelineState!

    var cameraDepthState: MTLDepthStencilState!
    var anchorDepthState: MTLDepthStencilState!

    var cameraTextureY: CVMetalTexture?
    var cameraTextureCbCr: CVMetalTexture?
    var textureCache: CVMetalTextureCache!

    var vertexDescriptor: MTLVertexDescriptor!

    var worldMeshes: [WorldMesh] = []

    var colorMap: MTLTexture?

    var uniformBufferIndex: Int = 0
    var frameUniformBufferOffset: Int = 0
    var anchorUniformBufferOffset: Int = 0
    var frameUniformBufferAddress: UnsafeMutableRawPointer!
    var anchorUniformBufferAddress: UnsafeMutableRawPointer!
    var anchorInstanceCount: Int = 0
    var viewportSize: CGSize = CGSize()

    init(session: ARSession, view: MTKView) {
        self.session = session
        self.device = view.device!
        self.mtkView = view
        loadMetal()
    }

    func update() {
        let _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            var textures = [cameraTextureY, cameraTextureCbCr]
            commandBuffer.addCompletedHandler{ [weak self] commandBuffer in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
                textures.removeAll()
            }

            updateBufferStates()
            updateFrameState()

            if let renderPassDescriptor = mtkView.currentRenderPassDescriptor, let currentDrawable = mtkView.currentDrawable, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                drawCameraImage(renderEncoder: renderEncoder)
                drawAnchorGeometry(renderEncoder: renderEncoder)

                renderEncoder.endEncoding()

                commandBuffer.present(currentDrawable)
            }

            commandBuffer.commit()
        }
    }

    func updateWorldMeshAnchors(_ frame: ARFrame) {
        let anchors = frame.anchors.filter { $0 is ARMeshAnchor } as! [ARMeshAnchor]

        worldMeshes = anchors.map { anchor in
            let meshGeometry = anchor.geometry
            let vertices: ARGeometrySource = meshGeometry.vertices
            let normals: ARGeometrySource = meshGeometry.normals
            let submesh: ARGeometryElement = meshGeometry.faces
            let worldMesh = WorldMesh(transform: anchor.transform,
                                      vertices: vertices,
                                      normals: normals,
                                      submesh: submesh)
            return worldMesh
        }
    }

    // MARK: - Private

    func loadMetal() {
        mtkView.depthStencilPixelFormat = .depth32Float_stencil8
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.sampleCount = 1

        let frameUniformBufferSize = kAlignedFrameUniformsSize * kMaxBuffersInFlight
        let anchorUniformBufferSize = kAlignedInstanceUniformsSize * kMaxBuffersInFlight

        frameUniformBuffer = device.makeBuffer(length: frameUniformBufferSize, options: .storageModeShared)

        fragmentUniformBuffer = device.makeBuffer(length: kAlignedFragmentUniformsSize, options: .storageModeShared)

        anchorUniformBuffer = device.makeBuffer(length: anchorUniformBufferSize, options: .storageModeShared)

        let imagePlaneVertexDataCount = kImagePlaneVertexData.count * MemoryLayout<Float>.size
        imagePlaneVertexBuffer = device.makeBuffer(bytes: kImagePlaneVertexData, length: imagePlaneVertexDataCount, options: [])

        let defaultLibrary = device.makeDefaultLibrary()!

        let cameraVertexFunction = defaultLibrary.makeFunction(name: "Day4_cameraVertexTransform")!
        let cameraFragmentFunction = defaultLibrary.makeFunction(name: "Day4_cameraFragmentShader")!

        let imagePlaneVertexDescriptor = MTLVertexDescriptor()
        imagePlaneVertexDescriptor.attributes[0].format = .float2
        imagePlaneVertexDescriptor.attributes[0].offset = 0
        imagePlaneVertexDescriptor.attributes[0].bufferIndex = 0
        imagePlaneVertexDescriptor.attributes[1].format = .float2
        imagePlaneVertexDescriptor.attributes[1].offset = 8
        imagePlaneVertexDescriptor.attributes[1].bufferIndex = 0
        imagePlaneVertexDescriptor.layouts[0].stride = 16

        let cameraPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        cameraPipelineStateDescriptor.sampleCount = mtkView.sampleCount
        cameraPipelineStateDescriptor.vertexFunction = cameraVertexFunction
        cameraPipelineStateDescriptor.fragmentFunction = cameraFragmentFunction
        cameraPipelineStateDescriptor.vertexDescriptor = imagePlaneVertexDescriptor
        cameraPipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        cameraPipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        cameraPipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        do {
            try cameraPipelineState = device.makeRenderPipelineState(descriptor: cameraPipelineStateDescriptor)
        } catch let error {
            print("Failed to created captured image pipeline state, error \(error)")
        }

        let cameraDepthStateDescriptor = MTLDepthStencilDescriptor()
        cameraDepthStateDescriptor.depthCompareFunction = .always
        cameraDepthStateDescriptor.isDepthWriteEnabled = false
        cameraDepthState = device.makeDepthStencilState(descriptor: cameraDepthStateDescriptor)

        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        self.textureCache = textureCache

        let anchorGeometryVertexFunction = defaultLibrary.makeFunction(name: "Day4_anchorGeometryVertexTransform")!
        let anchorGeometryFragmentFunction = defaultLibrary.makeFunction(name: "Day4_anchorGeometryFragmentLighting")!

        vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        vertexDescriptor.layouts[0].stride = 12
        vertexDescriptor.layouts[1].stride = 12

        let anchorPipelineStateDescriptor = MTLRenderPipelineDescriptor()
        anchorPipelineStateDescriptor.sampleCount = mtkView.sampleCount
        anchorPipelineStateDescriptor.vertexFunction = anchorGeometryVertexFunction
        anchorPipelineStateDescriptor.fragmentFunction = anchorGeometryFragmentFunction
        anchorPipelineStateDescriptor.vertexDescriptor = vertexDescriptor
        anchorPipelineStateDescriptor.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        anchorPipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        anchorPipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        anchorPipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        anchorPipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        anchorPipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        anchorPipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        anchorPipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        anchorPipelineStateDescriptor.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        anchorPipelineStateDescriptor.stencilAttachmentPixelFormat = mtkView.depthStencilPixelFormat

        do {
            try anchorPipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor)
        } catch let error {
            print("Failed to create anchor geometry pipeline state, error \(error)")
        }

        let geometryOutlineVertexFunction = defaultLibrary.makeFunction(name: "Day4_anchorGeometryVertexTransform")!
        let geometryOutlineFragmentFunction = defaultLibrary.makeFunction(name: "Day4_geometryOutlineFragment")!
        anchorPipelineStateDescriptor.vertexFunction = geometryOutlineVertexFunction
        anchorPipelineStateDescriptor.fragmentFunction = geometryOutlineFragmentFunction

        do {
            try outlinePipelineState = device.makeRenderPipelineState(descriptor: anchorPipelineStateDescriptor)
        } catch let error {
            print("Failed to create outline geometry pipeline state, error \(error)")
        }


        let anchorDepthStateDescriptor = MTLDepthStencilDescriptor()
        anchorDepthStateDescriptor.depthCompareFunction = .lessEqual
        anchorDepthStateDescriptor.isDepthWriteEnabled = true
        anchorDepthState = device.makeDepthStencilState(descriptor: anchorDepthStateDescriptor)

        commandQueue = device.makeCommandQueue()

        let textureLoader = MTKTextureLoader(device: device)
        colorMap = try? textureLoader.newTexture(name: "day4", scaleFactor: 1.0, bundle: nil, options: nil)
    }

    func updateBufferStates() {
        uniformBufferIndex = (uniformBufferIndex + 1) % kMaxBuffersInFlight

        frameUniformBufferOffset = kAlignedFrameUniformsSize * uniformBufferIndex
        anchorUniformBufferOffset = kAlignedInstanceUniformsSize * uniformBufferIndex

        frameUniformBufferAddress = frameUniformBuffer.contents().advanced(by: frameUniformBufferOffset)
        anchorUniformBufferAddress = anchorUniformBuffer.contents().advanced(by: anchorUniformBufferOffset)
    }

    func updateFrameState() {
        guard let currentFrame = session.currentFrame else {
            return
        }

        viewportSize = mtkView.drawableSize
        updateImagePlane(frame: currentFrame)

        updateWorldMeshAnchors(currentFrame)
        updateFrameUniforms(frame: currentFrame)
        updateAnchors(frame: currentFrame)
        updateCameraTextures(frame: currentFrame)
    }

    func updateFrameUniforms(frame: ARFrame) {
        let uniforms = frameUniformBufferAddress.assumingMemoryBound(to: FrameUniforms.self)

        uniforms.pointee.viewMatrix = frame.camera.viewMatrix(for: .landscapeRight)
        uniforms.pointee.projectionMatrix = frame.camera.projectionMatrix(for: .landscapeRight,
                                                                          viewportSize: viewportSize,
                                                                          zNear: 0.05,
                                                                          zFar: 50)
    }

    func updateAnchors(frame: ARFrame) {
        for (index, mesh) in worldMeshes.enumerated() {
            let instanceIndex = min(index, kMaxAnchorInstanceCount - 1)
            let modelMatrix = mesh.transform
            let anchorUniforms = anchorUniformBufferAddress.assumingMemoryBound(to: InstanceUniforms.self).advanced(by: instanceIndex)
            anchorUniforms.pointee.modelMatrix = modelMatrix
        }
    }

    func updateCameraTextures(frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        cameraTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.r8Unorm, planeIndex:0)
        cameraTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat:.rg8Unorm, planeIndex:1)
    }

    func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        _ = CVMetalTextureCacheCreateTextureFromImage(nil,
                                                      textureCache,
                                                      pixelBuffer,
                                                      nil,
                                                      pixelFormat,
                                                      width,
                                                      height,
                                                      planeIndex,
                                                      &texture)
        return texture
    }

    func updateImagePlane(frame: ARFrame) {
        let displayToCameraTransform = frame.displayTransform(for: .landscapeRight, viewportSize: viewportSize).inverted()

        let vertexData = imagePlaneVertexBuffer.contents().assumingMemoryBound(to: Float.self)
        for index in 0...3 {
            let textureCoordIndex = 4 * index + 2
            let textureCoord = CGPoint(x: CGFloat(kImagePlaneVertexData[textureCoordIndex]),
                                       y: CGFloat(kImagePlaneVertexData[textureCoordIndex + 1]))
            let transformedCoord = textureCoord.applying(displayToCameraTransform)
            vertexData[textureCoordIndex] = Float(transformedCoord.x)
            vertexData[textureCoordIndex + 1] = Float(transformedCoord.y)
        }
    }

    func drawCameraImage(renderEncoder: MTLRenderCommandEncoder) {
        guard let textureY = cameraTextureY, let textureCbCr = cameraTextureCbCr else {
            return
        }

        renderEncoder.setCullMode(.none)
        renderEncoder.setRenderPipelineState(cameraPipelineState)
        renderEncoder.setDepthStencilState(cameraDepthState)
        renderEncoder.setVertexBuffer(imagePlaneVertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureY), index: 1)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(textureCbCr), index: 2)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    func drawAnchorGeometry(renderEncoder: MTLRenderCommandEncoder) {
        renderEncoder.setFragmentTexture(colorMap, index: 0)

        for (index, mesh) in worldMeshes.enumerated() {
            renderEncoder.setVertexBuffer(mesh.vertices.buffer, offset: mesh.vertices.offset, index: 0)
            renderEncoder.setVertexBuffer(mesh.normals.buffer, offset: mesh.normals.offset, index: 1)
            renderEncoder.setVertexBuffer(anchorUniformBuffer,
                                          offset: anchorUniformBufferOffset + MemoryLayout<InstanceUniforms>.size * index,
                                          index: 2)
            renderEncoder.setVertexBuffer(frameUniformBuffer, offset: frameUniformBufferOffset, index: 3)

            renderEncoder.setRenderPipelineState(anchorPipelineState)
            renderEncoder.setDepthStencilState(anchorDepthState)
            renderEncoder.setTriangleFillMode(.fill)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: mesh.submesh.count * mesh.submesh.indexCountPerPrimitive,
                                                indexType: .uint32,
                                                indexBuffer: mesh.submesh.buffer,
                                                indexBufferOffset: 0)

            renderEncoder.setRenderPipelineState(outlinePipelineState)
            renderEncoder.setDepthStencilState(anchorDepthState)
            renderEncoder.setTriangleFillMode(.lines)
            renderEncoder.drawIndexedPrimitives(type: .triangle,
                                                indexCount: mesh.submesh.count * mesh.submesh.indexCountPerPrimitive,
                                                indexType: .uint32,
                                                indexBuffer: mesh.submesh.buffer,
                                                indexBufferOffset: 0)
        }
    }
}
