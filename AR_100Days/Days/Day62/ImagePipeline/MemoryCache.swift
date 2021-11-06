import Foundation
import UIKit

public protocol ImageCaching {
    func store(_ image: UIImage, for url: URL)
    func load(for url: URL) -> UIImage?
    func remove(for url: URL)
    func removeAll()
}

public final class MemoryCache: ImageCaching {
    public static let shared = MemoryCache()

    public var totalCostLimit: Int {
        get {
            return cache.totalCostLimit
        }
        set {
            cache.totalCostLimit = newValue
        }
    }
    
    public var countLimit: Int {
        get {
            return cache.countLimit
        }
        set {
            cache.countLimit = newValue
        }
    }

    private let cache: NSCache<AnyObject, UIImage>

    private var defaultLimit: Int {
        let physicalMemory = ProcessInfo().physicalMemory
        let ratio = physicalMemory <= (1024 * 1024 * 512) ? 0.1 : 0.2
        let limit = physicalMemory / UInt64(1 / ratio)

        return limit > UInt64(Int.max) ? Int.max : Int(limit)
    }

    public init() {
        cache = NSCache()
        cache.totalCostLimit = defaultLimit
    }

    public func store(_ image: UIImage, for url: URL) {
        let size = image.size
        let bytesPerRow = Int(size.width * 4)
        let cost = bytesPerRow * Int(size.height)

        cache.setObject(image, forKey: url as AnyObject, cost: cost)
    }

    public func load(for url: URL) -> UIImage? {
        return cache.object(forKey: url as AnyObject)
    }

    public func remove(for url: URL) {
        cache.removeObject(forKey: url as AnyObject)
    }

    public func removeAll() {
        cache.removeAllObjects()
    }
}
