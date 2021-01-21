import UIKit
import AVFoundation

class Day18_ViewController: UIViewController {

    enum Devices {
        case ultraWide
        case wideAngle
        case telephoto
        case front
    }

    @IBOutlet var ultraWideView: UIView!
    @IBOutlet var frontView: UIView!

    var session: AVCaptureMultiCamSession!
    var maxDevicesCount = 0
    var selectedDevices: Set<Devices> = []

    override func viewDidLoad() {
        super.viewDidLoad()

        ultraWideView.isOpaque = true
        ultraWideView.backgroundColor = .clear

        session = AVCaptureMultiCamSession()
        maxDevicesCount = detectSupportedDeviceCount()
        selectedDevices = selectDevices()
        setupSession()
    }

    func detectSupportedDeviceCount() -> Int {
        let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [
            .builtInMicrophone,
            .builtInWideAngleCamera,
            .builtInTelephotoCamera,
            .builtInUltraWideCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,
            .builtInTrueDepthCamera
        ], mediaType: .video, position: .unspecified)
        let deviceSets = discoverySession.supportedMultiCamDeviceSets

        var maxDevicesCount = 0
        for deviceSet in deviceSets {
            if deviceSet.count > maxDevicesCount {
                maxDevicesCount = deviceSet.count
            }
        }
        return maxDevicesCount
    }

    func selectDevices() -> Set<Devices> {
        switch maxDevicesCount {
        case 0:
            return []
        case 1:
            return [.wideAngle]
        case 2:
            return [.ultraWide, .front]
        case 3:
            return [.ultraWide, .telephoto, .front]
        default:
            return []
        }
    }

    func setupSession() {
        session.beginConfiguration()

        if selectedDevices.contains(.ultraWide),
           let ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
            guard setupBackCamera(device: ultraWideDevice, targetView: ultraWideView ) else { return }
        }

        if selectedDevices.contains(.front) {
            guard setupFrontCamera() else { return }
        }

        session.commitConfiguration()
        session.startRunning()
    }

    func setupBackCamera(device: AVCaptureDevice, targetView: UIView) -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        let deviceInput = try! AVCaptureDeviceInput(device: device)
        guard session.canAddInput(deviceInput) else {
            return false
        }
        session.addInputWithNoConnections(deviceInput)

        guard let port = deviceInput.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: device.position).first else {
            return false
        }

        let output = AVCaptureMovieFileOutput()
        guard session.canAddOutput(output) else {
            return false
        }
        session.addOutputWithNoConnections(output)

        let connection = AVCaptureConnection(inputPorts: [port], output: output)
        connection.videoOrientation = .landscapeRight
        connection.preferredVideoStabilizationMode = .cinematicExtended
        guard session.canAddConnection(connection) else {
            return false
        }
        session.addConnection(connection)

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = CGRect(origin: .zero, size: targetView.bounds.size)
        previewLayer.connection?.videoOrientation = .landscapeRight
        previewLayer.videoGravity = .resizeAspectFill
        targetView.layer.addSublayer(previewLayer)

        let maskpath = CGMutablePath()
        maskpath.move(to: CGPoint.zero)
        maskpath.addLine(to: CGPoint(x: 0, y: 500))
        maskpath.addLine(to: CGPoint(x: 1000, y: 0))
        maskpath.addLine(to: CGPoint(x: 0, y: 0))
        maskpath.closeSubpath()

        let maskLayer = CAShapeLayer()
        maskLayer.frame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        maskLayer.path = maskpath
        maskLayer.fillColor = UIColor.black.cgColor

        previewLayer.mask = maskLayer

        return true
    }

    func setupFrontCamera() -> Bool {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
        }

        guard let frontDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            return false
        }

        let frontInput = try! AVCaptureDeviceInput(device: frontDevice)
        guard session.canAddInput(frontInput) else {
            return false
        }
        session.addInputWithNoConnections(frontInput)

        guard let frontPort = frontInput.ports(for: .video, sourceDeviceType: frontDevice.deviceType, sourceDevicePosition: frontDevice.position).first else {
            return false
        }

        let frontOutput = AVCaptureMovieFileOutput()
        guard session.canAddOutput(frontOutput) else {
            return false
        }
        session.addOutputWithNoConnections(frontOutput)

        let frontVideoConnection = AVCaptureConnection(inputPorts: [frontPort], output: frontOutput)
        frontVideoConnection.videoOrientation = .portrait
        frontVideoConnection.preferredVideoStabilizationMode = .cinematicExtended
        guard session.canAddConnection(frontVideoConnection) else {
            return false
        }
        session.addConnection(frontVideoConnection)

        let frontPreviewLayer = AVCaptureVideoPreviewLayer()
        frontPreviewLayer.setSessionWithNoConnection(session)
        frontPreviewLayer.videoGravity = .resizeAspectFill
        frontPreviewLayer.frame = CGRect(origin: .zero, size: frontView.bounds.size)
        frontView.layer.addSublayer(frontPreviewLayer)

        let frontLayerConnection = AVCaptureConnection(inputPort: frontPort, videoPreviewLayer: frontPreviewLayer)
        session.addConnection(frontLayerConnection)
        frontLayerConnection.videoOrientation = .landscapeRight

        return true
    }
}

//class TriangleView : UIView {
//
//    override init(frame: CGRect) {
//        super.init(frame: frame)
//    }
//
//    required init?(coder aDecoder: NSCoder) {
//        super.init(coder: aDecoder)
//        isOpaque = true
//    }
//
//    override func draw(_ rect: CGRect) {
//
//        guard let context = UIGraphicsGetCurrentContext() else { return }
//
//        context.beginPath()
//        context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
//        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
//        context.addLine(to: CGPoint(x: (rect.maxX / 2.0), y: rect.minY))
//        context.closePath()
//
//        context.setFillColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.60)
//        context.fillPath()
//    }
//}
