import UIKit
import AVFoundation

class Day6_ViewController: UIViewController {

    enum Devices {
        case ultraWide
        case wideAngle
        case telephoto
        case front
    }

    @IBOutlet var ultraWideView: UIView!
    @IBOutlet var wideAngleView: UIView!
    @IBOutlet var telephotoView: UIView!
    @IBOutlet var frontView: UIView!

    var session: AVCaptureMultiCamSession!
    var maxDevicesCount = 0
    var selectedDevices: Set<Devices> = []

    override func viewDidLoad() {
        super.viewDidLoad()

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
            return [.ultraWide, .telephoto]
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

        if selectedDevices.contains(.telephoto),
           let telephotoDevice = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
            guard setupBackCamera(device: telephotoDevice, targetView: telephotoView ) else { return }
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
