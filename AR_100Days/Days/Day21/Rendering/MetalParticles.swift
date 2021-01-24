import ARKit
import Metal
import ModelIO
import MetalKit
import os.log

class MetalParticles {

    private let log = OSLog(subsystem: appSubsystem, category: "MetalParticles")

    struct Particle {
        var position: SIMD3<Float>
        var category: UInt
    }

    private var vertexBuffer: MTLBuffer!

    private var renderState: MTLRenderPipelineState!
    private var depthState: MTLDepthStencilState!
    private var computeState: MTLComputePipelineState!

    private var geometryVertexDescriptor: MTLVertexDescriptor!
    private var particleCacheIndex: Int = 0

    private let maxBuffersInFlight: Int = 3
    private let alignedInstanceUniformsSize: Int = ((MemoryLayout<InstanceUniforms>.size * 1) & ~0xFF) + 0x100

    private var numBugs: Int = 0

    public var transform = float4x4(translation: SIMD3<Float>())

    var mesh: MTKMesh!

    public let particleCount: UInt
    public var pointSize: Float = 4

    init(_ library: MTLLibrary, _ view: MTKView, _ count: UInt = 100_000) {
        let device = view.device!
        particleCount = count

        var particles = [Particle]()
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        for _ in 0..<count {
            let particle = Particle(position: SIMD3<Float>(10_000, 10_000, 10_000), category: 0
            )
            particles.append(particle)
        }

        vertexBuffer = device.makeBuffer( bytes: &particles,
                                          length: particles.count * MemoryLayout<Particle>.stride, options: [])!

        let meshBuffer = metalAllocator.newBuffer(MemoryLayout<Particle>.stride * particles.count, type: .vertex)
        let vertexMap = meshBuffer.map()
        vertexMap.bytes.assumingMemoryBound(to: Particle.self).assign(from: particles, count: particles.count)

        let indices = particles.enumerated().map { UInt32($0.0) }
        let indexBuffer = metalAllocator.newBuffer(MemoryLayout<UInt32>.size * indices.count, type: .index)
        let indexMap = indexBuffer.map()
        indexMap.bytes.assumingMemoryBound(to: UInt32.self).assign(from: indices, count: indices.count)

        let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indices.count, indexType: .uInt32,
                                 geometryType: .points, material: nil)

        let vertexDescriptor = setupVertexDescriptor()

        let pipelineStateDescriptor = setupPipelineStateDescriptor(library, view)

        do {
            try renderState = device.makeRenderPipelineState(descriptor: pipelineStateDescriptor)
        } catch let error {
            log.error("Failed to created anchor geometry pipeline state, error: %s", "\(error)")
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = .less
        depthStateDescriptor.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthStateDescriptor)

        let functionVertex = library.makeFunction(name: "particleCompute")!
        do {
            try computeState = device.makeComputePipelineState(function: functionVertex)
        } catch let error {
            log.error("Failed to created compute pipeline state, error: %s", "\(error)")
        }

        let model = MDLMesh( vertexBuffer: meshBuffer, vertexCount: particles.count,
                             descriptor: vertexDescriptor, submeshes: [submesh])

        do {
            try mesh = MTKMesh(mesh: model, device: device)
        } catch let error {
            log.error("Error creating MetalKit mesh, error: %s", "\(error)")
        }
    }

    func setupVertexDescriptor() -> MDLVertexDescriptor {
        geometryVertexDescriptor = MTLVertexDescriptor()

        // Positions
        geometryVertexDescriptor.attributes[0].format = .float3
        geometryVertexDescriptor.attributes[0].offset = 0
        geometryVertexDescriptor.attributes[0].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Classifications
        geometryVertexDescriptor.attributes[1].format = .uint
        geometryVertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        geometryVertexDescriptor.attributes[1].bufferIndex = Int(kBufferIndexMeshPositions.rawValue)

        // Position buffer layout
        geometryVertexDescriptor.layouts[0].stride = MemoryLayout<Particle>.stride
        geometryVertexDescriptor.layouts[0].stepRate = 1
        geometryVertexDescriptor.layouts[0].stepFunction = .perVertex

        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(geometryVertexDescriptor)
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0)
        vertexDescriptor.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                                            format: .uInt,
                                                            offset: 12,
                                                            bufferIndex: 0)
        return vertexDescriptor
    }

    func setupPipelineStateDescriptor(_ library: MTLLibrary, _ view: MTKView) -> MTLRenderPipelineDescriptor {
        let pipelineStateDescriptor = MTLRenderPipelineDescriptor()
        pipelineStateDescriptor.label = "ParticlePipeline"
        pipelineStateDescriptor.sampleCount = view.sampleCount
        pipelineStateDescriptor.vertexFunction = library.makeFunction(name: "particleVertex")!
        pipelineStateDescriptor.fragmentFunction = library.makeFunction(name: "particleFragment")!
        pipelineStateDescriptor.vertexDescriptor = geometryVertexDescriptor
        pipelineStateDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        pipelineStateDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        pipelineStateDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat

        pipelineStateDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineStateDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineStateDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineStateDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        return pipelineStateDescriptor
    }

    func update(_ commandQueue: MTLCommandQueue,
                _ newParticles: [SIMD3<Float>: ARMeshClassification],
                _ bugParticles: [float4x4]) {
        let numBugsDeleted: Int = max(0, numBugs - bugParticles.count)
        numBugs = bugParticles.count

        for idx in 0..<bugParticles.count {
            vertexBuffer.contents().assumingMemoryBound(
                to: Particle.self).advanced(
                    by: idx).pointee.position = bugParticles[idx].position
            vertexBuffer.contents().assumingMemoryBound(to: Particle.self).advanced(by: idx).pointee.category = 9
        }
        if numBugsDeleted > 0 {
            for idx in bugParticles.count..<bugParticles.count + numBugsDeleted {
                vertexBuffer.contents().assumingMemoryBound(
                    to: Particle.self).advanced(
                        by: idx).pointee.position = SIMD3<Float>(10_000, 10_000, 10_000)
                vertexBuffer.contents().assumingMemoryBound(to: Particle.self).advanced(by: idx).pointee.category = 0
            }
        }

        if particleCacheIndex < bugParticles.count {
            particleCacheIndex = bugParticles.count
        }

        for (key, value) in newParticles {
            vertexBuffer.contents().assumingMemoryBound(
                to: Particle.self).advanced(
                    by: particleCacheIndex).pointee.position = key
            vertexBuffer.contents().assumingMemoryBound(
                to: Particle.self).advanced(
                    by: particleCacheIndex).pointee.category = UInt(value.rawValue)

            particleCacheIndex += 1
            if particleCacheIndex >= particleCount {
                particleCacheIndex = bugParticles.count
            }
        }

        let threadExecutionWidth = computeState.threadExecutionWidth
        let threadsPerGroup = MTLSize(width: threadExecutionWidth, height: 1, depth: 1)
        let ntg = Int(ceil(Float(particleCount) / Float(threadExecutionWidth)))
        let numThreadgroups = MTLSize(width: ntg, height: 1, depth: 1)

        let computeCommandBuffer = commandQueue.makeCommandBuffer()
        let computeCommandEncoder = computeCommandBuffer?.makeComputeCommandEncoder()

        computeCommandEncoder?.setComputePipelineState(computeState)
        computeCommandEncoder?.setBuffer(mesh.vertexBuffers[0].buffer,
                                         offset: 0,
                                         index: Int(kBufferIndexMeshPositions.rawValue))
        computeCommandEncoder?.setBuffer(vertexBuffer, offset: 0, index: Int(Day21_kBufferIndexVBO.rawValue))
        computeCommandEncoder?.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
        computeCommandEncoder?.endEncoding()

        computeCommandBuffer?.commit()
    }

    func draw(renderEncoder: MTLRenderCommandEncoder,
              _ sharedUniformBuffer: MTLBuffer,
              _ sharedUniformBufferOffset: Int) {

        renderEncoder.pushDebugGroup("DrawParticles")

        renderEncoder.setRenderPipelineState(renderState)
        renderEncoder.setVertexBuffer(sharedUniformBuffer,
                                      offset: sharedUniformBufferOffset,
                                      index: Int(kBufferIndexSharedUniforms.rawValue))
        renderEncoder.setFragmentBuffer(sharedUniformBuffer,
                                        offset: sharedUniformBufferOffset,
                                        index: Int(kBufferIndexSharedUniforms.rawValue))

        for bufferIndex in 0..<mesh.vertexBuffers.count {
            let vertexBuffer = mesh.vertexBuffers[bufferIndex]
            renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                          offset: vertexBuffer.offset,
                                          index: bufferIndex)
        }
        for index in 0..<mesh.submeshes.count {
            renderEncoder.drawIndexedPrimitives(
                type: mesh.submeshes[index].primitiveType,
                indexCount: mesh.submeshes[index].indexCount,
                indexType: mesh.submeshes[index].indexType,
                indexBuffer: mesh.submeshes[index].indexBuffer.buffer,
                indexBufferOffset: mesh.submeshes[index].indexBuffer.offset,
                instanceCount: 1)
        }
        renderEncoder.popDebugGroup()
    }
}
