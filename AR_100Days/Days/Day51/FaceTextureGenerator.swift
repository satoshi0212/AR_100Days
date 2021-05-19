import Foundation
import Metal
import UIKit
import ARKit

class FaceTextureGenerator {

    private static func renderTargetDescriptor(textureSize: Int) -> MTLTextureDescriptor {
        let renderTargetDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: textureSize, height: textureSize, mipmapped: false)
        // We only set .shared here so we can read the texture for exporting to the photo library
        // If you don't need this, use .private instead
        renderTargetDescriptor.storageMode = .shared
        renderTargetDescriptor.usage = [.shaderWrite, .shaderRead, .renderTarget]
        return renderTargetDescriptor;
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let viewportSize: CGSize

    private let textureSize: Int

    private let cameraImageTextureCache: CVMetalTextureCache

    private let renderTarget: MTLTexture

    private let renderPipelineState: MTLRenderPipelineState
    private let renderPassDescriptor: MTLRenderPassDescriptor

    private let indexCount: Int

    private let indexBuffer: MTLBuffer
    private let positionBuffer: MTLBuffer
    private let normalBuffer: MTLBuffer
    private let uvBuffer: MTLBuffer

    init(device: MTLDevice, library: MTLLibrary, viewportSize: CGSize, face: ARSCNFaceGeometry, textureSize: Int) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
        self.viewportSize = viewportSize
        self.textureSize = textureSize

        var textureCache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
        cameraImageTextureCache = textureCache!

        renderTarget = device.makeTexture(descriptor: FaceTextureGenerator.renderTargetDescriptor(textureSize: textureSize))!

        renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = renderTarget
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm

        pipelineDescriptor.vertexFunction = library.makeFunction(name: "faceTextureVertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "faceTextureFragment")

        self.renderPipelineState = try! device.makeRenderPipelineState(descriptor: pipelineDescriptor)

        self.indexCount = face.elements.reduce(0, { sum, x in sum + x.primitiveCount  }) * 3

        self.indexBuffer = device.makeBuffer(length: MemoryLayout<UInt16>.size * self.indexCount, options: [])!
        var indexPtr = self.indexBuffer.contents().bindMemory(to: UInt8.self, capacity: self.indexCount * MemoryLayout<UInt16>.size)

        for element in face.elements {
            let byteSize = element.primitiveCount * 3 * MemoryLayout<UInt16>.size
            let _ = element.data.copyBytes(to: UnsafeMutableBufferPointer(start: indexPtr, count: byteSize))
            indexPtr += byteSize
        }

        self.positionBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face.sources[0].vectorCount, options: [])!
        self.normalBuffer = device.makeBuffer(length: MemoryLayout<SIMD3<Float>>.stride * face.sources[0].vectorCount, options: [])!
        self.uvBuffer = device.makeBuffer(length: MemoryLayout<SIMD2<Float>>.stride * face.sources[0].vectorCount, options: [])!

        self.updateGeometry(face: face)
    }

    private func updateGeometry(face: ARSCNFaceGeometry) {
        let positionSource = face.sources(for: .vertex).first!
        positionSource.data.copyBytes(to: UnsafeMutableRawBufferPointer(
                                        start: self.positionBuffer.contents(),
                                        count: positionSource.vectorCount * MemoryLayout<SIMD3<Float>>.stride))

        let normalSource = face.sources(for: .normal).first!
        normalSource.data.copyBytes(to: UnsafeMutableRawBufferPointer(
                                        start: self.normalBuffer.contents(),
                                        count: normalSource.vectorCount * MemoryLayout<SIMD3<Float>>.stride))

        let uvSource = face.sources(for: .texcoord).first!
        uvSource.data.copyBytes(to: UnsafeMutableRawBufferPointer(
                                    start: self.uvBuffer.contents(),
                                    count: uvSource.vectorCount * MemoryLayout<SIMD2<Float>>.stride))
    }

    /// Captured face texture for UV map
    public var texture: MTLTexture {
        renderTarget
    }

    /// Update the face texture for the current frame
    public func update(frame: ARFrame, scene: SCNScene, headNode: SCNNode, geometry: ARSCNFaceGeometry) {
        struct ShaderState {
            let displayTransform: float4x4
            let modelViewTransform: float4x4
            let projectionTransform: float4x4
        }

        self.updateGeometry(face: geometry)

        let (capturedImageTextureY, capturedImageTextureCbCr) = getCapturedImageTextures(frame: frame)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Could not create computeCommandBuffer")
        }

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!

        renderEncoder.setViewport(MTLViewport(originX: 0, originY: 0, width: Double(self.textureSize), height: Double(textureSize), znear: 0, zfar: 1))
        renderEncoder.setRenderPipelineState(self.renderPipelineState)

        // Buffers
        renderEncoder.setVertexBuffer(self.positionBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(self.normalBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(self.uvBuffer, offset: 0, index: 2)

        // Textures
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureY)!, index: 0)
        renderEncoder.setFragmentTexture(CVMetalTextureGetTexture(capturedImageTextureCbCr)!, index: 1)

        // State
        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: viewportSize)
        let displayTransform = SCNMatrix4Invert(SCNMatrix4(affineTransform))

        let worldTransform = headNode.worldTransform
        let cameraNode = scene.rootNode.childNodes.first!
        let viewTransform = SCNMatrix4Invert(cameraNode.transform)
        let modelViewTransform = SCNMatrix4Mult(worldTransform, viewTransform)
        let projectionTransform = cameraNode.camera!.projectionTransform

        var state = ShaderState(
            displayTransform: simd_float4x4(displayTransform),
            modelViewTransform: simd_float4x4(modelViewTransform),
            projectionTransform: simd_float4x4(projectionTransform))

        renderEncoder.setVertexBytes(&state, length: MemoryLayout<ShaderState>.stride, index: 3)

        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: self.indexCount, indexType: .uint16, indexBuffer: self.indexBuffer, indexBufferOffset: 0)

        renderEncoder.endEncoding()

        commandBuffer.commit()
    }

    private func getCapturedImageTextures(frame: ARFrame) -> (CVMetalTexture, CVMetalTexture)  {
        let pixelBuffer = frame.capturedImage
        let capturedImageTextureY = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .r8Unorm, planeIndex: 0)!
        let capturedImageTextureCbCr = createTexture(fromPixelBuffer: pixelBuffer, pixelFormat: .rg8Unorm, planeIndex: 1)!
        return (capturedImageTextureY, capturedImageTextureCbCr)
    }

    private func getMTLPixelFormat(basedOn pixelBuffer: CVPixelBuffer!) -> MTLPixelFormat {
        let type = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if type == kCVPixelFormatType_DepthFloat32 {
            return .r32Float
        } else if type == kCVPixelFormatType_OneComponent8 {
            return .r8Uint
        } else if type == kCVPixelFormatType_32RGBA {
            return .rgba32Float
        } else {
            fatalError("Unsupported ARDepthData pixel-buffer format.")
        }
    }

    private func createTexture(fromPixelBuffer pixelBuffer: CVPixelBuffer, pixelFormat: MTLPixelFormat, planeIndex: Int) -> CVMetalTexture? {
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)

        var texture: CVMetalTexture? = nil
        let status = CVMetalTextureCacheCreateTextureFromImage(nil, cameraImageTextureCache, pixelBuffer, nil, pixelFormat,
                                                               width, height, planeIndex, &texture)

        if status != kCVReturnSuccess {
            print("Error \(status)")
            texture = nil
        }

        return texture
    }
}
