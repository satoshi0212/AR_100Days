import UIKit
import AVFoundation
import Vision

class Day64_ViewController: UIViewController {

    private var imageView: UIImageView!
    private let avCaptureSession = AVCaptureSession()

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

        avCaptureSession.sessionPreset = .hd1920x1080

        let device = AVCaptureDevice.default(for: .video)
        let input = try! AVCaptureDeviceInput(device: device!)
        avCaptureSession.addInput(input)

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: .global())

        avCaptureSession.addOutput(videoDataOutput)
        avCaptureSession.startRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        avCaptureSession.stopRunning()
    }

    private func drawRect(_ rect: CGRect, context: CGContext) {
        context.setLineWidth(4.0)
        context.setStrokeColor(UIColor.green.cgColor)
        context.stroke(rect)
    }

    private func getFaceObservations(pixelBuffer: CVPixelBuffer, completion: @escaping (([VNFaceObservation])->())) {
        let request = VNDetectFaceRectanglesRequest { (request, error) in
            guard let results = request.results as? [VNFaceObservation] else {
                completion([])
                return
            }
            completion(results)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func getUnfoldRect(normalizedRect: CGRect, targetSize: CGSize) -> CGRect {
        return CGRect(
            x: normalizedRect.minX * targetSize.width,
            y: normalizedRect.minY * targetSize.height,
            width: normalizedRect.width * targetSize.width,
            height: normalizedRect.height * targetSize.height
        )
    }

    private func getFaceRectsImage(sampleBuffer :CMSampleBuffer, faceObservations: [VNFaceObservation]) -> UIImage? {

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

        guard let pixelBufferBaseAddres = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bitmapInfo = CGBitmapInfo(rawValue: (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue) )

        guard let newContext = CGContext(
            data: pixelBufferBaseAddres,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(imageBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo.rawValue
        ) else
        {
            CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
            return nil
        }

        let imageSize = CGSize(width: width, height: height)
        let faseRects = faceObservations.compactMap {
            getUnfoldRect(normalizedRect: $0.boundingBox, targetSize: imageSize)
        }
        faseRects.forEach{ self.drawRect($0, context: newContext) }

        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))

        guard let imageRef = newContext.makeImage() else {
            return nil
        }
        let image = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImage.Orientation.right)

        return image
    }
}

extension Day64_ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        getFaceObservations(pixelBuffer: pixelBuffer) { [weak self] faceObservations in
            guard let me = self else { return }
            let image = me.getFaceRectsImage(sampleBuffer: sampleBuffer, faceObservations: faceObservations)
            DispatchQueue.main.async { [weak self] in
                self?.imageView.image = image
            }
        }
    }
}
