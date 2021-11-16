import UIKit
import Vision
import ARKit
import SceneKit

@available(iOS 15.0, *)
class Day66_ViewController: UIViewController, ARSessionDelegate {

    private var sceneView: ARSCNView!
    private var imageView: UIImageView!

    private let requestHandler = VNSequenceRequestHandler()
    private var segmentationRequest = VNGeneratePersonSegmentationRequest()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = ARSCNView(frame: view.bounds)
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: sceneView!, attribute: $0, relatedBy: .equal, toItem: sceneView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        sceneView.scene = SCNScene()
        sceneView.session.delegate = self
        view.sendSubviewToBack(sceneView)
        sceneView.isHidden = true

        imageView = UIImageView(frame: view.bounds)
        view.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: imageView!, attribute: $0, relatedBy: .equal, toItem: imageView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        view.sendSubviewToBack(imageView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapRecognizer)

        segmentationRequest = VNGeneratePersonSegmentationRequest()
        segmentationRequest.qualityLevel = .fast
        segmentationRequest.outputPixelFormat = kCVPixelFormatType_OneComponent8
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        //let configuration = ARBodyTrackingConfiguration()
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    @objc func tapped() {
        switch segmentationRequest.qualityLevel {
        case .fast:
            segmentationRequest.qualityLevel = .balanced
        case .balanced:
            segmentationRequest.qualityLevel = .accurate
        case .accurate:
            segmentationRequest.qualityLevel = .fast
        @unknown default:
            break
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        processVideoFrame(frame.capturedImage)
    }

    private func processVideoFrame(_ framePixelBuffer: CVPixelBuffer) {
        try? requestHandler.perform([segmentationRequest], on: framePixelBuffer, orientation: .right)

        guard let maskPixelBuffer = segmentationRequest.results?.first?.pixelBuffer else { return }

        let originalImage = CIImage(cvPixelBuffer: framePixelBuffer).oriented(.right)
        var maskImage = CIImage(cvPixelBuffer: maskPixelBuffer)

        let scaleX = originalImage.extent.width / maskImage.extent.width
        let scaleY = originalImage.extent.height / maskImage.extent.height
        maskImage = maskImage.transformed(by: .init(scaleX: scaleX, y: scaleY))

        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = UIImage(ciImage: maskImage)
        }
    }
}
