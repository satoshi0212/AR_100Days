import Foundation

public protocol DataCaching {
    func store(_ data: CacheEntry, for url: URL)
    func load(for url: URL) -> CacheEntry?
    func remove(for url: URL)
    func removeAll()
    func removeOutdated()
    func compact()
}

public final class DiskCache: DataCaching {
    public static let shared = DiskCache()

    private let storage: Storage

    public init(storage: Storage = SQLiteStorage()) {
        self.storage = storage
    }

    public func store(_ entry: CacheEntry, for url: URL) {
        storage.store(entry, for: url)
    }

    public func load(for url: URL) -> CacheEntry? {
        return storage.load(for: url)
    }
    
    public func remove(for url: URL) {
        storage.remove(for: url)
    }

    public func removeAll() {
        storage.removeAll()
    }

    public func removeOutdated() {
        storage.removeOutdated()
    }

    public func compact() {
        storage.compact()
    }
}
