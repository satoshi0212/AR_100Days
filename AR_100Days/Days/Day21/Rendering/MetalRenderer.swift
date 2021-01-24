import Metal
import MetalKit
import ARKit

class MetalRenderer {
    private let maxBuffersInFlight: Int = 3
    private let alignedSharedUniformsSize: Int = (MemoryLayout<Day21_SharedUniforms>.size & ~0xFF) + 0x100

    private let device: MTLDevice
    private let inFlightSemaphore: DispatchSemaphore
    private var renderDestination: MTKView

    private var commandQueue: MTLCommandQueue!
    public var particles: MetalParticles!

    // A ring buffer, in case the renderer gets behind 60 fps
    private var sharedUniformBuffer: MTLBuffer!
    private var uniformBufferIndex: Int = 0
    private var sharedUniformBufferOffset: Int = 0
    private var sharedUniformBufferAddress: UnsafeMutableRawPointer!

    private var viewportSize: CGSize = CGSize()
    private var viewportSizeDidChange: Bool = false

    public var cameraCone: MetalModel!
    public var progress: Float = 0  // 0...1

    func drawRectResized(size: CGSize) {
        viewportSize = size
        viewportSizeDidChange = true
    }

    func update(_ newParticles: [SIMD3<Float>: ARMeshClassification], bugTransforms: [float4x4]) {
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "RadarUpdate"
            particles.update(commandQueue, newParticles, bugTransforms)
            commandBuffer.commit()
        }
    }

    func draw(_ camera: Day21_CustomCameraComponent) {
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)

        if let commandBuffer = commandQueue.makeCommandBuffer() {
            commandBuffer.label = "RadarDraw"

            commandBuffer.addCompletedHandler { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.inFlightSemaphore.signal()
                }
            }

            updateBufferStates()
            updateSharedUniforms(camera: camera)

            cameraCone.update(transforms: [camera.deviceTransform], 1)

            if let renderPassDescriptor = renderDestination.currentRenderPassDescriptor,
                let currentDrawable = renderDestination.currentDrawable,
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                cameraCone.render(renderEncoder: renderEncoder, sharedUniformBuffer, sharedUniformBufferOffset)
                particles.draw(renderEncoder: renderEncoder, sharedUniformBuffer, sharedUniformBufferOffset)

                renderEncoder.endEncoding()

                commandBuffer.present(currentDrawable)
            }
            commandBuffer.commit()
        }
    }

    private func updateBufferStates() {
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        sharedUniformBufferOffset = alignedSharedUniformsSize * uniformBufferIndex
        sharedUniformBufferAddress = sharedUniformBuffer.contents().advanced(by: sharedUniformBufferOffset)
    }

    private func updateSharedUniforms(camera: Day21_CustomCameraComponent) {
        // all the ARKit we will be passing to our shaders
        let uniforms = sharedUniformBufferAddress.assumingMemoryBound(to: Day21_SharedUniforms.self)

        uniforms.pointee.viewMatrix = camera.viewMatrix
        uniforms.pointee.projectionMatrix = camera.projectionMatrix
        uniforms.pointee.deviceMatrix = camera.deviceTransform
        uniforms.pointee.pointSize = particles.pointSize
        uniforms.pointee.progress = progress
    }

    private func loadMetal() {
        renderDestination.depthStencilPixelFormat = .depth32Float_stencil8
        renderDestination.colorPixelFormat = .bgra8Unorm
        renderDestination.sampleCount = 1

        let sharedUniformBufferSize = alignedSharedUniformsSize * maxBuffersInFlight

        sharedUniformBuffer = device.makeBuffer(length: sharedUniformBufferSize, options: .storageModeShared)
        sharedUniformBuffer.label = "SharedUniformBuffer"

        let library = device.makeDefaultLibrary()!
        particles = MetalParticles(library, renderDestination)

        cameraCone = MetalModel(library, renderDestination, name: "cone", suffix: "usdz")
        cameraCone.tint = SIMD4<Float>(1, 1, 1, 1)
        commandQueue = device.makeCommandQueue()
    }

    init(_ renderDestination: MTKView) {
        self.device = MTLCreateSystemDefaultDevice()!
        self.renderDestination = renderDestination
        renderDestination.device = self.device
        inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
        loadMetal()
    }
}
