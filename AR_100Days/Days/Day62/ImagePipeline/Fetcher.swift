import Foundation

public protocol Fetching {
    func fetch(_ url: URL, completion: @escaping (CacheEntry) -> Void, cancellation: @escaping () -> Void, failure: @escaping (Error?) -> Void)
    func cancel(_ url: URL)
    func cancelAll()
}

public final class Fetcher: Fetching {
    private let session: URLSession
    private let taskExecutor = TaskExecutor()

    private let queue = DispatchQueue.init(label: "com.folio-sec.image-pipeline.fetcher", qos: .userInitiated)

    public init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldUsePipelining = true
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        session = URLSession(configuration: configuration, delegate: nil, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    public func fetch(_ url: URL, completion: @escaping (CacheEntry) -> Void, cancellation: @escaping () -> Void, failure: @escaping (Error?) -> Void) {
        let queue = self.queue
        let taskExecutor = self.taskExecutor

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let task = session.dataTask(with: request) { (data, response, error) in
            queue.sync {
                taskExecutor.removeTask(for: url)
            }

            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                cancellation()
                return
            }

            guard let data = data, !data.isEmpty else {
                failure(error)
                return
            }
            guard let response = response as? HTTPURLResponse else {
                failure(error)
                return
            }

            let headers = response.allHeaderFields
            var timeToLive: TimeInterval? = nil
            if let cacheControl = headers["Cache-Control"] as? String {
                let directives = parseCacheControlHeader(cacheControl)
                if let maxAge = directives["max-age"], let ttl = TimeInterval(maxAge) {
                    timeToLive = ttl
                }
            }

            let contentType = headers["Content-Type"] as? String

            let now = Date()
            let entry = CacheEntry(url: url, data: data, contentType: contentType, timeToLive: timeToLive, creationDate: now, modificationDate: now)
            completion(entry)
        }

        queue.sync {
            taskExecutor.push(DownloadTask(sessionTask: task, url: url))
        }
    }

    public func cancel(_ url: URL) {
        taskExecutor.cancel(for: url)
    }

    public func cancelAll() {
        taskExecutor.cancelAll()
    }
}

private class TaskExecutor {
    private var tasks = [DownloadTask]()
    private var runningTasks = [URL: DownloadTask]()
    private let maxConcurrentTasks = 4

    func push(_ task: DownloadTask) {
        if let index = tasks.firstIndex(of: task) {
            tasks.remove(at: index)
        }
        tasks.append(task)
        startPendingTasks()
    }

    func removeTask(for url: URL) {
        runningTasks[url] = nil
        startPendingTasks()
    }

    func cancel(for url: URL) {
        if let task = runningTasks[url] {
            task.sessionTask.cancel()
            runningTasks[url] = nil
        }
    }

    func cancelAll() {
        (tasks + runningTasks.values).forEach { $0.sessionTask.cancel() }
        tasks.removeAll()
        runningTasks.removeAll()
    }

    private func startPendingTasks() {
        while tasks.count > 0 && runningTasks.count <= maxConcurrentTasks {
            let task = tasks.removeLast()
            task.sessionTask.resume()
            runningTasks[task.url] = task
        }
    }
}

private class DownloadTask: Hashable {
    let sessionTask: URLSessionTask
    let url: URL

    init(sessionTask: URLSessionTask, url: URL) {
        self.sessionTask = sessionTask
        self.url = url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func == (lhs: DownloadTask, rhs: DownloadTask) -> Bool {
        return lhs.url == rhs.url
    }
}

private let regex = try! NSRegularExpression(pattern:
    """
    ([a-zA-Z][a-zA-Z_-]*)\\s*(?:=(?:"([^"]*)"|([^ \t",;]*)))?
    """, options: [])

internal func parseCacheControlHeader(_ cacheControl: String) -> [String: String] {
    let matches = regex.matches(in: cacheControl, options: [], range: NSRange(location: 0, length: cacheControl.utf16.count))
    return matches.reduce(into: [String: String]()) { (directives, result) in
        if let range = Range(result.range, in: cacheControl) {
            let directive = cacheControl[range]
            let pair = directive.split(separator: "=")
            if pair.count == 2 {
                directives[String(pair[0])] = String(pair[1])
            }
        }
    }
}
