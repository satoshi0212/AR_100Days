import UIKit
import Network
import CoreMotion
import Accelerate

class Day57_ViewController: UIViewController {

    @IBOutlet weak var stateLabel: UILabel!

    private var connection: NWConnection!
    private let hostUDP: NWEndpoint.Host = "192.168.11.4"
    private let portUDP: NWEndpoint.Port = 3333

    private let motionManager = CMMotionManager()
    private var timer: Timer!

    private let attitudeMultiple = 32768

    override func viewDidLoad() {
        super.viewDidLoad()

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates()

        timer = Timer.scheduledTimer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(Self.update), userInfo: nil, repeats: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        connectToUDP(hostUDP: hostUDP, portUDP: portUDP)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        connection.cancel()
    }

    @objc func update() {
        guard let deviceMotion = motionManager.deviceMotion else { return }
        let data = makeData(id: 255, attitude: deviceMotion.attitude)
        sendUDP(data)

        let pitch = deviceMotion.attitude.pitch.toDegrees()
        let roll = deviceMotion.attitude.roll.toDegrees()
        let yaw = deviceMotion.attitude.yaw.toDegrees()

        stateLabel.text = " pitch: \(pitch)\n roll  : \(roll)\n yaw  : \(yaw)"
    }

    private func makeData(id: UInt8, attitude: CMAttitude) -> Data {
        let pitch = attitude.pitch.toDegrees() // tilt
        let pitchValue = Int(ceil(pitch)) * attitudeMultiple
        let pitchComponents = pitchValue.getBinaryString(width: 24).components(length: 8).map { UInt8($0, radix: 2)! }

        let roll = attitude.roll.toDegrees()   // roll
        let rollValue = Int(ceil(roll)) * attitudeMultiple
        let rollComponents = rollValue.getBinaryString(width: 24).components(length: 8).map { UInt8($0, radix: 2)! }

        let yaw = attitude.yaw.toDegrees()     // pan
        let yawValue = Int(ceil(yaw)) * attitudeMultiple
        let yawComponents = yawValue.getBinaryString(width: 24).components(length: 8).map { UInt8($0, radix: 2)! }

        var bytes: [UInt8] = [209,        // 0xD1
                              id,
                              yawComponents[0], yawComponents[1], yawComponents[2],       // pan ry
                              pitchComponents[0], pitchComponents[1], pitchComponents[2], // tilt rx
                              rollComponents[0], rollComponents[1], rollComponents[2],    // roll rz
                              0, 0, 0,    // x
                              0, 0, 0,    // y
                              0, 0, 0,    // z
                              0, 0, 0,    // zoom
                              0, 0, 0,    // focus
                              0, 0]       // user

        var sum: UInt8 = 0x40
        for byte in bytes {
            sum = sum &- byte
        }

        bytes.append(sum)

        return Data(bytes: bytes, count: bytes.count)
    }

    private func connectToUDP(hostUDP: NWEndpoint.Host, portUDP: NWEndpoint.Port) {
        connection = NWConnection(host: hostUDP, port: portUDP, using: .udp)

        connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready:
                print("State: Ready\n")
                DispatchQueue.main.async {
                    self.view.backgroundColor = UIColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 0.6)
                }
            case .setup:
                print("State: Setup\n")
            case .cancelled:
                print("State: Cancelled\n")
            case .preparing:
                print("State: Preparing\n")
            default:
                print("ERROR! State not defined!\n")
            }
        }

        connection?.start(queue: .global())
    }

    private func sendUDP(_ content: Data) {
        connection?.send(content: content, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            if (NWError == nil) {
                print("Data was sent to UDP")
            } else {
                print("ERROR! Error when data (Type: Data) sending. NWError: \n \(NWError!)")
            }
        })))
    }
}

extension FixedWidthInteger {

    fileprivate func getBinaryString(width: Int) -> String {
        var result: [String] = []
        for i in 0..<(width / 8) {
            let byte = UInt8(truncatingIfNeeded: self >> (i * 8))
            let byteString = String(byte, radix: 2)
            let padding = String(repeating: "0", count: 8 - byteString.count)
            result.append(padding + byteString)
        }
        return result.reversed().joined()
    }
}

extension Double {

    fileprivate func toDegrees() -> Double {
        self * 180.0 / .pi
    }
}

extension String {

    fileprivate func components(length: Int) -> [String] {
        return stride(from: 0, to: count, by: length).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            return String(self[start..<end])
        }
    }
}
