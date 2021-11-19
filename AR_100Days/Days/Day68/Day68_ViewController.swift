import UIKit
import Vision
import CoreML
import Accelerate

class Day68_ViewController: UIViewController {

    private var model: VNCoreMLModel!
    private var originalImage: UIImage!
    private var imageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()

        imageView = UIImageView(frame: view.bounds)
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: imageView!, attribute: $0, relatedBy: .equal, toItem: imageView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        view.sendSubviewToBack(imageView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapRecognizer)
        imageView.contentMode = .scaleAspectFit

        imageView.image = UIImage(named: "day68")
        originalImage = imageView.image!

        let config = MLModelConfiguration()
        let obj = try! animeganpaprika.init(configuration: config)

        let mlModel = obj.model
        model = try! VNCoreMLModel(for: mlModel)
    }

    @objc func tapped() {
        execStyle()
    }

    private func execStyle() {

        let request = VNCoreMLRequest(model: model) { (request, error) in
            if let error = error {
                print("error:\(error)")
                return
            }
            let result = request.results?.first as! VNCoreMLFeatureValueObservation
            let multiArray = result.featureValue.multiArrayValue
            let cgImage = multiArray?.cgImage(min: -1, max: 1, channel: nil, axes: (3,1,2))
            DispatchQueue.main.async {
                self.imageView.image = UIImage(cgImage: cgImage!)
            }
        }
        request.usesCPUOnly = true

        guard let cgImage = originalImage.cgImage else { fatalError() }
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try! handler.perform([request])
    }
}

protocol MultiArrayType: Comparable {
    static var multiArrayDataType: MLMultiArrayDataType { get }
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
    init(_: Int)
    var toUInt8: UInt8 { get }
}

extension Double: MultiArrayType {
    public static var multiArrayDataType: MLMultiArrayDataType { return .double }
    public var toUInt8: UInt8 { return UInt8(self) }
}

extension Float: MultiArrayType {
    public static var multiArrayDataType: MLMultiArrayDataType { return .float32 }
    public var toUInt8: UInt8 { return UInt8(self) }
}

extension Int32: MultiArrayType {
    public static var multiArrayDataType: MLMultiArrayDataType { return .int32 }
    public var toUInt8: UInt8 { return UInt8(self) }
}

extension MLMultiArray {

    func clamp<T: Comparable>(_ x: T, min: T, max: T) -> T {
        if x < min { return min }
        if x > max { return max }
        return x
    }

    func cgImage(min: Double = 0,
                 max: Double = 255,
                 channel: Int? = nil,
                 axes: (Int, Int, Int)? = nil) -> CGImage? {
        switch self.dataType {
        case .double:
            return _image(min: min, max: max, channel: channel, axes: axes)
        case .float32:
            return _image(min: Float(min), max: Float(max), channel: channel, axes: axes)
        case .int32:
            return _image(min: Int32(min), max: Int32(max), channel: channel, axes: axes)
        @unknown default:
            fatalError("Unsupported data type \(dataType.rawValue)")
        }
    }

    private func _image<T: MultiArrayType>(min: T,
                                           max: T,
                                           channel: Int?,
                                           axes: (Int, Int, Int)?) -> CGImage? {
        if let (b, w, h, _) = toRawBytes(min: min, max: max, channel: channel, axes: axes) {
            return CGImage.fromByteArrayRGBA(b, width: w, height: h)
        }
        return nil
    }

    func toRawBytes<T: MultiArrayType>(min: T,
                                       max: T,
                                       channel: Int? = nil,
                                       axes: (Int, Int, Int)? = nil)
    -> (bytes: [UInt8], width: Int, height: Int, channels: Int)? {

        if shape.count < 3 {
            print("Cannot convert MLMultiArray of shape \(shape) to image")
            return nil
        }

        let channelAxis = 0
        let heightAxis = 1
        let widthAxis = 2

        let height = shape[heightAxis].intValue
        let width = shape[widthAxis].intValue
        let yStride = strides[heightAxis].intValue
        let xStride = strides[widthAxis].intValue

        let channels: Int
        let cStride: Int
        let bytesPerPixel: Int
        let channelOffset: Int

        let channelDim = shape[channelAxis].intValue
        if let channel = channel {
            if channel < 0 || channel >= channelDim {
                print("Channel must be -1, or between 0 and \(channelDim - 1)")
                return nil
            }
            channels = 1
            bytesPerPixel = 1
            channelOffset = channel
        } else if channelDim == 1 {
            channels = 1
            bytesPerPixel = 1
            channelOffset = 0
        } else {
            if channelDim != 3 && channelDim != 4 {
                print("Expected channel dimension to have 1, 3, or 4 channels, got \(channelDim)")
                return nil
            }
            channels = channelDim
            bytesPerPixel = 4
            channelOffset = 0
        }
        cStride = self.strides[channelAxis].intValue

        let count = height * width * bytesPerPixel
        var pixels = [UInt8](repeating: 255, count: count)

        var ptr = UnsafeMutablePointer<T>(OpaquePointer(self.dataPointer))
        ptr = ptr.advanced(by: channelOffset * cStride)

        for c in 0..<channels {
            for y in 0..<height {
                for x in 0..<width {
                    let value = ptr[c*cStride + y*yStride + x*xStride]
                    let scaled = (value - min) * T(255) / (max - min)
                    let pixel = clamp(scaled, min: T(0), max: T(255)).toUInt8
                    pixels[(y*width + x)*bytesPerPixel + c] = pixel
                }
            }
        }
        return (pixels, width, height, channels)
    }
}

extension CGImage {

    class func fromByteArrayRGBA(_ bytes: [UInt8],
                                 width: Int,
                                 height: Int) -> CGImage? {
        return fromByteArray(bytes, width: width, height: height,
                             bytesPerRow: width * 4,
                             colorSpace: CGColorSpaceCreateDeviceRGB(),
                             alphaInfo: .premultipliedLast)
    }

    class func fromByteArray(_ bytes: [UInt8],
                             width: Int,
                             height: Int,
                             bytesPerRow: Int,
                             colorSpace: CGColorSpace,
                             alphaInfo: CGImageAlphaInfo) -> CGImage? {
        return bytes.withUnsafeBytes { ptr in
            let context = CGContext(data: UnsafeMutableRawPointer(mutating: ptr.baseAddress!),
                                    width: width,
                                    height: height,
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: alphaInfo.rawValue)
            return context?.makeImage()
        }
    }
}
