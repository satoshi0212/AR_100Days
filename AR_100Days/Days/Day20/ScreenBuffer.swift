import Accelerate
import RealityKit
import UIKit

class ScreenBuffer {

    struct RGBBuffer {
        let pointer: UnsafePointer<UInt8>
        let dimensions: BufferDimension

        func getColor(at screenPoint: CGPoint) -> UIColor? {
            let xFlipped = min(1 - screenPoint.x, 0.9999999)
            let xTransformed = Int(screenPoint.y * CGFloat(dimensions.width))
            let yTransformed = Int(xFlipped * CGFloat(dimensions.height))

            guard (xTransformed >= 0) &&
                (xTransformed < dimensions.width) &&
                (yTransformed >= 0) &&
                (yTransformed < dimensions.height) else {
                    return nil
            }

            let index = (yTransformed * dimensions.bytesPerRow) + (xTransformed * 4)
            let scalar: Float = 1.0 / 255.0
            let red = CGFloat(Float(pointer[index + 1]) * scalar)
            let green = CGFloat(Float(pointer[index + 2]) * scalar)
            let blue = CGFloat(Float(pointer[index + 3]) * scalar)

            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
    }

    struct BufferDimension {
        let width: Int
        let height: Int
        let bytesPerRow: Int

        var byteCount: Int {
            return width * bytesPerRow * height
        }

        var uWidth: UInt {
            return UInt(width)
        }

        var uHeight: UInt {
            return UInt(height)
        }

        var size: CGSize {
            return CGSize(width: width, height: height)
        }

        init(pixelBuffer: CVPixelBuffer, plane: Int?) {
            if let plane = plane {
                self.width = CVPixelBufferGetWidthOfPlane(pixelBuffer, plane)
                self.height = CVPixelBufferGetHeightOfPlane(pixelBuffer, plane)
                self.bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, plane)
            } else {
                self.width = CVPixelBufferGetWidth(pixelBuffer)
                self.height = CVPixelBufferGetHeight(pixelBuffer)
                self.bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            }
        }

        init(width: Int, height: Int, bytesPerRow: Int) {
            self.width = width
            self.height = height
            self.bytesPerRow = bytesPerRow
        }

        func buffer(with data: UnsafeMutableRawPointer) -> vImage_Buffer {
            return vImage_Buffer(data: data, height: uHeight, width: uWidth, rowBytes: bytesPerRow)
        }
    }

    static func getConversionMatrix() -> vImage_YpCbCrToARGB {
        var pixelRange = vImage_YpCbCrPixelRange(Yp_bias: 0,
                                                 CbCr_bias: 128,
                                                 YpRangeMax: 255,
                                                 CbCrRangeMax: 255,
                                                 YpMax: 255,
                                                 YpMin: 1,
                                                 CbCrMax: 255,
                                                 CbCrMin: 0)
        var matrix = vImage_YpCbCrToARGB()
        vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2,
                                                      &pixelRange,
                                                      &matrix,
                                                      kvImage420Yp8_CbCr8,
                                                      kvImageARGB8888,
                                                      UInt32(kvImageNoFlags))
        return matrix
    }

    static func makeRGGBuffer(_ pixelBuffer: CVPixelBuffer) -> RGBBuffer? {

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        guard let rawyBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
        let rawcbcrBuffer = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            //log.error("Unable to find correct planar data in source pixel buffer.")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        let ySize = BufferDimension(pixelBuffer: pixelBuffer, plane: 0)
        let cSize = BufferDimension(pixelBuffer: pixelBuffer, plane: 1)

        var yBuffer = ySize.buffer(with: rawyBuffer)
        var cbcrBuffer = cSize.buffer(with: rawcbcrBuffer)

        guard let rawRGBBuffer = malloc(ySize.width * ySize.height * 4) else {
            //log.error("Unable to allocate space for RGB buffer.")
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }

        var rgbBuffer: vImage_Buffer = vImage_Buffer(data: rawRGBBuffer,
                                                     height: ySize.uHeight,
                                                     width: ySize.uWidth,
                                                     rowBytes: ySize.width * 4)

        var conversionMatrix: vImage_YpCbCrToARGB = getConversionMatrix()

        let error = vImageConvert_420Yp8_CbCr8ToARGB8888(&yBuffer,
                                                         &cbcrBuffer,
                                                         &rgbBuffer,
                                                         &conversionMatrix,
                                                         nil,
                                                         255,
                                                         UInt32(kvImageNoFlags))

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)

        if error != kvImageNoError {
            //log.error("Error converting buffer: %s", "\(error)")
            return nil
        }

        let pointer = unsafeBitCast(rgbBuffer.data, to: UnsafePointer<UInt8>.self)
        let dimensions = BufferDimension(width: ySize.width, height: ySize.height, bytesPerRow: ySize.width * 4)
        return RGBBuffer(pointer: pointer, dimensions: dimensions)
    }

    // For images instead of pixels
    struct HitQuad {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomRight: CGPoint
        let bottomLeft: CGPoint
    }

    static func getCorrectedImage(_ ciImage: CIImage, _ quad: HitQuad) -> CGImage? {
        let perspectiveCorrection = CIFilter(name: "CIPerspectiveCorrection")!

        perspectiveCorrection.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveCorrection.setValue(CIVector(cgPoint: quad.topLeft), forKey: "inputTopLeft")
        perspectiveCorrection.setValue(CIVector(cgPoint: quad.topRight), forKey: "inputTopRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: quad.bottomRight), forKey: "inputBottomRight")
        perspectiveCorrection.setValue(CIVector(cgPoint: quad.bottomLeft), forKey: "inputBottomLeft")

        if let output = perspectiveCorrection.outputImage?.oriented(CGImagePropertyOrientation.upMirrored) {
            let context = CIContext(options: nil)
            return context.createCGImage(output, from: output.extent)
        }
        return nil
    }

    static func convert(_ arView: ARView, from: SIMD3<Float>, size: CGSize) -> CGPoint {
        let scale: CGFloat = size.height / arView.frame.height
        let xoffset: CGFloat = (size.width - (arView.frame.width * scale)) / 2
        guard let projectedPoint = arView.project(from) else {
            return CGPoint()
        }

        return CGPoint(x: size.width - xoffset - projectedPoint.x * scale,
                       y: size.height - projectedPoint.y * scale)
    }
}
