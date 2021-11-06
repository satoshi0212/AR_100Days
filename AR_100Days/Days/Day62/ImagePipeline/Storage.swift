import Foundation
import SQLite3

public protocol Storage {
    func store(_ entry: CacheEntry, for url: URL)
    func load(for url: URL) -> CacheEntry?
    func remove(for url: URL)
    func removeAll()
    func removeOutdated()
    func compact()
}

public protocol FileProvider {
    var path: String { get }
}

public class SQLiteStorage: Storage {
    private var database: OpaquePointer?
    private var replaceStatement: OpaquePointer?
    private var selectStatement: OpaquePointer?
    private var deleteStatement: OpaquePointer?
    private var deleteAllStatement: OpaquePointer?
    private var deleteOutdatedStatement: OpaquePointer?
    private var vacuumStatement: OpaquePointer?

    private static var schemaVersion = 0

    public init(fileProvider: FileProvider = DefaultFileProvider()) {
        let path = fileProvider.path
        do {
            try openDatabase(path: path)
        } catch {
            do {
                try closeDatabase()
                try FileManager().removeItem(atPath: path)
                try openDatabase(path: path)
            } catch {}
        }
    }

    deinit {
        try? closeDatabase()
    }

    public func store(_ entry: CacheEntry, for url: URL) {
        let statement = replaceStatement
        do {
            try SQLite.execute { sqlite3_bind_text(statement, 1, url.absoluteString.cString(using: .utf8), -1, SQLITE_TRANSIENT) }
            try SQLite.execute { sqlite3_bind_text(statement, 2, entry.url.absoluteString.cString(using: .utf8), -1, SQLITE_TRANSIENT) }
            try SQLite.execute { entry.data.withUnsafeBytes { sqlite3_bind_blob(statement, 3, $0.baseAddress, Int32(entry.data.count), SQLITE_TRANSIENT) } }
            if let contentType = entry.contentType {
                try SQLite.execute { sqlite3_bind_text(statement, 4, contentType.cString(using: .utf8), -1, SQLITE_TRANSIENT) }
            }
            if let timeToLive = entry.timeToLive {
                try SQLite.execute { sqlite3_bind_int64(statement, 5, sqlite3_int64(bitPattern: UInt64(timeToLive))) }
            }
            try SQLite.execute { sqlite3_bind_int64(statement, 6, sqlite3_int64(bitPattern: UInt64(entry.creationDate.timeIntervalSince1970))) }
            try SQLite.execute { sqlite3_bind_int64(statement, 7, sqlite3_int64(bitPattern: UInt64(entry.modificationDate.timeIntervalSince1970))) }

            try SQLite.executeUpdate { sqlite3_step(statement) }
            try SQLite.execute { sqlite3_reset(statement) }
        } catch {}
    }

    public func load(for url: URL) -> CacheEntry? {
        let statement = selectStatement
        try? SQLite.execute { sqlite3_bind_text(statement, 1, url.absoluteString.cString(using: .utf8), -1, SQLITE_TRANSIENT) }

        let entry: CacheEntry?
        if sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0), let u = URL(string: String(cString: text)) else {
                return nil
            }
            guard let bytes = sqlite3_column_blob(statement, 1) else {
                return nil
            }
            let byteCount = sqlite3_column_bytes(statement, 1)
            let contentType: String?
            if let mime = sqlite3_column_text(statement, 2) {
                contentType = String(cString: mime)
            } else {
                contentType = nil
            }
            let ttl = sqlite3_column_int64(statement, 3)
            let createdAt = sqlite3_column_int64(statement, 4)
            let updatedAt = sqlite3_column_int64(statement, 5)

            entry = CacheEntry(url: u,
                               data: Data(bytes: bytes, count: Int(byteCount)),
                               contentType: contentType,
                               timeToLive: TimeInterval(ttl),
                               creationDate: Date(timeIntervalSince1970: TimeInterval(createdAt)),
                               modificationDate: Date(timeIntervalSince1970: TimeInterval(updatedAt)))
        } else {
            entry = nil
        }

        try? SQLite.execute { sqlite3_reset(statement) }

        return entry
    }

    public func remove(for url: URL) {
        let statement = deleteStatement
        do {
            try SQLite.execute { sqlite3_bind_text(statement, 1, url.absoluteString.cString(using: .utf8), -1, SQLITE_TRANSIENT) }
            try SQLite.executeUpdate { sqlite3_step(statement) }
            try SQLite.execute { sqlite3_reset(statement) }
        } catch {}
    }

    public func removeAll() {
        let statement = deleteAllStatement
        do {
            try SQLite.executeUpdate { sqlite3_step(statement) }
            try SQLite.execute { sqlite3_reset(statement) }
        } catch {}
    }
    
    public func removeOutdated() {
        let statement = deleteOutdatedStatement
        do {
            try SQLite.executeUpdate { sqlite3_step(statement) }
            try SQLite.execute { sqlite3_reset(statement) }
        } catch {}
    }

    public func compact() {
        let statement = vacuumStatement
        do {
            try SQLite.executeUpdate { sqlite3_step(statement) }
            try SQLite.execute { sqlite3_reset(statement) }
        } catch {}
    }

    private func openDatabase(path: String) throws {
        try SQLite.execute { sqlite3_open_v2(path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) }
        try SQLite.execute {
            sqlite3_exec(database,
                         """
                         CREATE TABLE IF NOT EXISTS entry (
                             id TEXT NOT NULL PRIMARY KEY,
                             url TEXT NOT NULL,
                             data BLOB NOT NULL,
                             mime TEXT,
                             ttl INTEGER,
                             created_at INTEGER NOT NULL,
                             updated_at INTEGER NOT NULL
                         );
                         """,
                         nil,
                         nil,
                         nil) }
        try validateSchemaVersion()
        try prepareStatements()
    }

    private func validateSchemaVersion() throws {
        var statement: OpaquePointer?
        defer {
            try? finalizeStatement(statement)
        }
        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               PRAGMA user_version;
                               """,
                               -1,
                               &statement,
                               nil) }
        guard sqlite3_step(statement) == SQLITE_ROW else {
            throw SQLite.SQLiteError.schemaChanged
        }
        guard sqlite3_column_int64(statement, 0) == SQLiteStorage.schemaVersion else {
            throw SQLite.SQLiteError.schemaChanged
        }
    }

    private func prepareStatements() throws {
        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               REPLACE INTO entry
                                   (id, url, data, mime, ttl, created_at, updated_at)
                               VALUES
                                   (?,  ?,   ?,    ?,    ?,   ?,          ?);
                               """,
                               -1,
                               &replaceStatement,
                               nil) }

        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               SELECT
                                   url, data, mime, ttl, created_at, updated_at
                               FROM
                                   entry
                               WHERE id = ?;
                               """,
                               -1,
                               &selectStatement,
                               nil) }

        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               DELETE FROM entry WHERE id = ?;
                               """,
                               -1,
                               &deleteStatement,
                               nil) }

        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               DELETE FROM entry;
                               """,
                               -1,
                               &deleteAllStatement,
                               nil) }

        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               DELETE FROM entry WHERE (updated_at + ttl) < CAST(strftime('%s', 'now') AS INTEGER);
                               """,
                               -1,
                               &deleteOutdatedStatement,
                               nil) }

        try SQLite.execute {
            sqlite3_prepare_v2(database,
                               """
                               VACUUM;
                               """,
                               -1,
                               &vacuumStatement,
                               nil) }
    }

    private func closeDatabase() throws {
        try finalizeStatement(replaceStatement)
        try finalizeStatement(selectStatement)
        try finalizeStatement(deleteStatement)
        try finalizeStatement(deleteAllStatement)
        try finalizeStatement(deleteOutdatedStatement)
        try finalizeStatement(vacuumStatement)
        if #available(iOS 8.2, *) {
            guard let database = database else { return }
            try SQLite.execute { sqlite3_close_v2(database) }
        } else {
            guard let database = database else { return }
            try SQLite.execute { sqlite3_close(database) }
        }
    }

    func finalizeStatement(_ statement: OpaquePointer?) throws {
        guard let statement = statement else { return }
        try SQLite.execute { sqlite3_finalize(statement) }
    }

    private enum SQLite {
        static func execute(_ closure: () -> Int32) throws {
            let code = closure()
            if code != SQLITE_OK {
                throw SQLiteError.error(code)
            }
        }

        static func executeUpdate(_ closure: () -> Int32) throws {
            let code = closure()
            if code != SQLITE_DONE {
                throw SQLiteError.error(code)
            }
        }

        enum SQLiteError: Error {
            case error(Int32)
            case schemaChanged
        }
    }
}

public struct DefaultFileProvider: FileProvider {
    public init() {}

    public var path: String {
        let directory = FileManager().urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return directory.appendingPathComponent("com.folio-sec.cache.sqlite").path
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self)
