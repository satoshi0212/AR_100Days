import UIKit
//import Cocoa

public final class ImagePipeline {
    public static let shared = ImagePipeline()

    private let fetcher: Fetching
    private let decoder: ImageDecoding
    private let diskCache: DataCaching
    private let memoryCache: ImageCaching

    private let queue = DispatchQueue.init(label: "com.folio-sec.image-pipeline", qos: .userInitiated)
    private var controllers = [ImageViewReference: ImageViewController]()

    public init(fetcher: Fetching = Fetcher(), decoder: ImageDecoding = ImageDecoder(), diskCache: DataCaching = DiskCache.shared, memoryCache: ImageCaching = MemoryCache.shared) {
        self.fetcher = fetcher
        self.decoder = decoder
        self.diskCache = diskCache
        self.memoryCache = memoryCache
    }

    public func load(_ url: URL, into imageView: CALayer, defaultImage: UIImage? = nil, failureImage: UIImage? = nil, processors: [ImageProcessing] = []) {
        if let defaultImage = defaultImage {
            imageView.contents = defaultImage
        }

        let reference = ImageViewReference(imageView)
        let controller: ImageViewController
        if let c = controllers[reference] {
            controller = c
        } else {
            controller = ImageViewController(reference)
            controllers[reference] = controller
        }
        controller.cancelOutstandingTasks()
        let taskId = controller.currentTaskId

        if let image = memoryCache.load(for: url) {
            processImage(image, processors: processors) {
                guard taskId == controller.currentTaskId else { return }
                controller.showImage($0)
            }
            return
        }

        if let entry = diskCache.load(for: url) {
            if !isTTLExpired(ttl: entry.timeToLive, date: entry.modificationDate), let image = decoder.decode(data: entry.data) {
                self.memoryCache.store(image, for: url)

                guard taskId == controller.currentTaskId else { return }
                processImage(image, processors: processors) {
                    guard taskId == controller.currentTaskId else { return }
                    controller.showImage($0)
                }
                return
            }
        }

        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.fetcher.fetch(url, completion: { [weak self] in
                guard let self = self else { return }

                guard let image = self.decoder.decode(data: $0.data) else {
                    if let failureImage = failureImage {
                        guard taskId == controller.currentTaskId else { return }
                        self.showImage(failureImage) { controller.showImage($0) }
                    }
                    return
                }

                self.diskCache.store($0, for: url)
                self.memoryCache.store(image, for: url)

                guard taskId == controller.currentTaskId else { return }
                self.processImage(image, processors: processors) {
                    guard taskId == controller.currentTaskId else { return }
                    controller.showImage($0)
                }
            }, cancellation: {
                /* do nothing */
            }, failure: { [weak self] _ in
                if let failureImage = failureImage {
                    guard taskId == controller.currentTaskId else { return }
                    self?.showImage(failureImage) { controller.showImage($0) }
                }
            })
        }
    }

    private func showImage(_ image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.main.async { completion(image) }
    }

    private func processImage(_ image: UIImage, processors: [ImageProcessing], completion: @escaping (UIImage) -> Void) {
        queue.async {
            let resultImage = processors.reduce(image) { $1.process(image: $0) }
            DispatchQueue.main.async { completion(resultImage) }
        }
    }

    private func isTTLExpired(ttl: TimeInterval?, date: Date) -> Bool {
        if let ttl = ttl {
            return date.addingTimeInterval(ttl) < Date()
        } else {
            return false
        }
    }

    @objc
    private func didReceiveMemoryWarning(notification: Notification) {
        controllers.removeAll()
        memoryCache.removeAll()
    }

    @objc
    private func didEnterBackground(notification: Notification) {
        controllers.removeAll()
        diskCache.removeOutdated()
        diskCache.compact()
    }
}

private class ImageViewReference: Hashable {
    var imageView: CALayer?
    private let objectIdentifier: ObjectIdentifier

    init(_ imageView: CALayer) {
        self.imageView = imageView
        objectIdentifier = ObjectIdentifier(imageView)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(objectIdentifier)
    }

    static func == (lhs: ImageViewReference, rhs: ImageViewReference) -> Bool {
        return lhs.objectIdentifier == rhs.objectIdentifier
    }
}

private class ImageViewController {
    private(set) weak var reference: ImageViewReference?
    private(set) var currentTaskId = UUID()

    init(_ reference: ImageViewReference) {
        self.reference = reference
    }

    func showImage(_ image: UIImage) {
        if let cgImage = image.cgImage {
            reference?.imageView?.contents = cgImage
        }
    }

    func cancelOutstandingTasks() {
        currentTaskId = UUID()
    }
}
