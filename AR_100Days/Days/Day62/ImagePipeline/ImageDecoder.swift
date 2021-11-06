//import Cocoa
import UIKit

public protocol ImageDecoding {
    func decode(data: Data) -> UIImage?
}

public struct ImageDecoder: ImageDecoding {
    public init() {}

    public func decode(data: Data) -> UIImage? {
        guard data.count > 12 else {
            return nil
        }

        let bytes = Array(data)
        if isJPEG(bytes: bytes) || isPNG(bytes: bytes) || isGIF(bytes: bytes) {
            return UIImage(data: data)
        }

        return nil
    }

    private func isJPEG(bytes: [UInt8]) -> Bool {
        return bytes[0...2] == [0xFF, 0xD8, 0xFF]
    }

    private func isPNG(bytes: [UInt8]) -> Bool {
        return bytes[0...3] == [0x89, 0x50, 0x4E, 0x47]
    }

    private func isGIF(bytes: [UInt8]) -> Bool {
        return bytes[0...2] == [0x47, 0x49, 0x46]
    }

    private func isWebP(bytes: [UInt8]) -> Bool {
        return bytes[8...11] == [0x57, 0x45, 0x42, 0x50]
    }
}
