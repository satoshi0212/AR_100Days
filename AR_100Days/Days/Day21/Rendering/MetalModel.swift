import os.log
import MetalKit

class MetalModel {

    private var uniformsBuffer: MTLBuffer!

    private var vertexBuffer: MTLBuffer!
    private let mesh: MTKMesh
    private var pipelineState: MTLRenderPipelineState!
    public var tint = SIMD4<Float>(0, 1, 0, 1)

    init(_ library: MTLLibrary, _ view: MTKView, _ mdlMesh: MDLMesh) {
        let mesh = try? MTKMesh(mesh: mdlMesh, device: view.device!)
        self.mesh = mesh!
        setup(library, view)
    }

    init(_ library: MTLLibrary, _ view: MTKView, name: String, suffix: String = "obj") {
        guard let mdlMesh = MetalModel.load(device: view.device!, name: name, suffix: suffix) else {
            fatalError("Invalid model: " + name+"."+suffix)
        }

        let mesh = try? MTKMesh(mesh: mdlMesh, device: view.device!)
        self.mesh = mesh!

        setup(library, view)
    }

    private func setup(_ library: MTLLibrary, _ view: MTKView) {
        vertexBuffer = mesh.vertexBuffers[0].buffer

        // Create a reusable pipeline state for rendering anchor geometry
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.sampleCount = view.sampleCount
        pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "modelVertex")!
        pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "modelFragment")!
        pipelineStateDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .min
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .zero
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .zero

        do {
            try pipelineState = view.device!.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch {
            fatalError("failed to create pipeline state for model")
        }

        var uniforms = [Day21_InstanceUniforms(modelMatrix: float4x4(), color: SIMD4<Float>.zero, fadeType: 0)]
        uniformsBuffer = view.device!.makeBuffer(
            bytes: &uniforms,
            length: MemoryLayout<Day21_InstanceUniforms>.size,
            options: .storageModeShared)!
        uniformsBuffer.label = "ModelUniformsBuffer"
    }

    static func load(device: MTLDevice, name: String, suffix: String = "obj") -> MDLMesh? {
        guard let assetURL = Bundle.main.url(forResource: name, withExtension: suffix) else {
            return nil
        }
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: assetURL, vertexDescriptor: defaultVertexDescriptor, bufferAllocator: allocator)

        if let mesh = asset.childObjects(of: MDLMesh.self).first as? MDLMesh {
            return mesh
        }
        return nil
    }

    static var defaultVertexDescriptor: MDLVertexDescriptor {
        let vertexDescriptor = MDLVertexDescriptor()
        vertexDescriptor.attributes[Int(kVertexAttributePosition.rawValue)] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0)
        vertexDescriptor.attributes[Int(kVertexAttributeNormal.rawValue)] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: 12,
            bufferIndex: 0)
        vertexDescriptor.attributes[Int(kVertexAttributeTexcoord.rawValue)] =
            MDLVertexAttribute(name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0)
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: 32)
        return vertexDescriptor
    }

    func update(transforms: [float4x4], _ fadeType: Int = 0) {
        // Update the anchor uniform buffer with transforms of the current frame's anchors
        guard let transform = transforms.first else { return }
        let uniforms = uniformsBuffer.contents().assumingMemoryBound(to: Day21_InstanceUniforms.self).advanced(by: 0)
        uniforms.pointee.modelMatrix = transform
        uniforms.pointee.color = tint
        uniforms.pointee.fadeType = Int32(fadeType)
    }

    func render(renderEncoder: MTLRenderCommandEncoder,
                _ sharedUniformBuffer: MTLBuffer,
                _ sharedUniformBufferOffset: Int) {
        renderEncoder.setCullMode(.front)
        renderEncoder.setRenderPipelineState(pipelineState)

        renderEncoder.setVertexBuffer(sharedUniformBuffer,
                                      offset: sharedUniformBufferOffset,
                                      index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setVertexBuffer(uniformsBuffer, offset: 0, index: Int(kBufferIndexInstanceUniforms.rawValue))
        renderEncoder.setFragmentBuffer(sharedUniformBuffer,
                                        offset: sharedUniformBufferOffset,
                                        index: Int(kBufferIndexSharedUniforms.rawValue))

        for (index, vertexBuffer) in mesh.vertexBuffers.enumerated() {
            renderEncoder.setVertexBuffer(vertexBuffer.buffer, offset: vertexBuffer.offset, index: index)
        }

        for index in 0..<mesh.submeshes.count {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: mesh.submeshes[index].indexCount,
                indexType: mesh.submeshes[index].indexType,
                indexBuffer: mesh.submeshes[index].indexBuffer.buffer,
                indexBufferOffset: mesh.submeshes[index].indexBuffer.offset,
                instanceCount: 1)
        }
    }
}
