import UIKit
import Vision
import CoreML
import AVFoundation

class Day69_ViewController: UIViewController {

    private var model: VNCoreMLModel!
    private var imageView: UIImageView!
    private let avCaptureSession = AVCaptureSession()
    private var isProcessing = false

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

        imageView.contentMode = .scaleAspectFit

        let config = MLModelConfiguration()
        let obj = try! animeganpaprika.init(configuration: config)

        let mlModel = obj.model
        model = try! VNCoreMLModel(for: mlModel)

        avCaptureSession.sessionPreset = .hd1280x720

        let device = AVCaptureDevice.default(for: .video)
        let input = try! AVCaptureDeviceInput(device: device!)
        avCaptureSession.addInput(input)

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: .global())

        avCaptureSession.addOutput(videoDataOutput)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        avCaptureSession.startRunning()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        avCaptureSession.stopRunning()
    }

    private func execStyle(pixelBuffer: CVPixelBuffer) {

        let request = VNCoreMLRequest(model: model) { (request, error) in
            if let error = error {
                print("error:\(error)")
                return
            }
            guard let result = request.results?.first as? VNCoreMLFeatureValueObservation else { return }
            let multiArray = result.featureValue.multiArrayValue
            let cgImage = multiArray?.cgImage(min: -1, max: 1, channel: nil, axes: (3,1,2))
            guard let cgImage = cgImage else { return }
            DispatchQueue.main.async {
                self.imageView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try! handler.perform([request])
    }
}

extension Day69_ViewController : AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        execStyle(pixelBuffer: pixelBuffer)
    }
}
