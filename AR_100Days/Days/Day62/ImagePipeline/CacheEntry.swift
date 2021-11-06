import Foundation

public struct CacheEntry {
    public let url: URL
    public let data: Data
    public let contentType: String?
    public let timeToLive: TimeInterval?
    public let creationDate: Date
    public let modificationDate: Date

    public init(url: URL, data: Data, contentType: String?, timeToLive: TimeInterval?, creationDate: Date, modificationDate: Date) {
        self.url = url
        self.data = data
        self.contentType = contentType
        self.timeToLive = timeToLive
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
}

extension CacheEntry: Equatable {
    public static func == (lhs: CacheEntry, rhs: CacheEntry) -> Bool {
        return lhs.url == rhs.url && lhs.data == rhs.data
    }
}
