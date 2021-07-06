import ARKit
import AudioToolbox
import SceneKit
import UIKit

private func AudioQueueInputCallback(
    inUserData: UnsafeMutableRawPointer?,
    inAQ: AudioQueueRef,
    inBuffer: AudioQueueBufferRef,
    inStartTime: UnsafePointer<AudioTimeStamp>,
    inNumberPacketDescriptions: UInt32,
    inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?)
{

}

class Day52_ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!

    private let colors: [UIColor] = [.gray, .red, .green, .blue, .yellow, .orange, .purple]
    private var colorIndex = 0

    var queue: AudioQueueRef!
    var timer: Timer!

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.delegate = self
        sceneView.automaticallyUpdatesLighting = true

        startUpdatingVolume()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
        stopUpdatingVolume()
    }

    func startUpdatingVolume() {
        var dataFormat = AudioStreamBasicDescription(
            mSampleRate: 44100.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: AudioFormatFlags(kLinearPCMFormatFlagIsBigEndian | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked),
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0)

        var audioQueue: AudioQueueRef? = nil
        var error = noErr
        error = AudioQueueNewInput(
            &dataFormat,
            AudioQueueInputCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            .none,
            .none,
            0,
            &audioQueue)
        if error == noErr {
            queue = audioQueue
        }
        AudioQueueStart(queue, nil)

        var enabledLevelMeter: UInt32 = 1
        AudioQueueSetProperty(queue, kAudioQueueProperty_EnableLevelMetering, &enabledLevelMeter, UInt32(MemoryLayout<UInt32>.size))

        timer = Timer.scheduledTimer(timeInterval: 0.5,
                                          target: self,
                                          selector: #selector(self.detectVolume(_:)),
                                          userInfo: nil,
                                          repeats: true)
        timer?.fire()
    }

    func stopUpdatingVolume() {
        timer.invalidate()
        timer = nil
        AudioQueueFlush(queue)
        AudioQueueStop(queue, false)
        AudioQueueDispose(queue, true)
    }

    @objc func detectVolume(_ timer: Timer) {
        var levelMeter = AudioQueueLevelMeterState()
        var propertySize = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)

        AudioQueueGetProperty(
            queue,
            kAudioQueueProperty_CurrentLevelMeterDB,
            &levelMeter,
            &propertySize)

        if levelMeter.mPeakPower >= -1.0 {
            colorIndex += 1
            if colorIndex > colors.count - 1 {
                colorIndex = 0
            }
        }
    }
}

extension Day52_ViewController: ARSCNViewDelegate {

    func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else { return nil }

        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!)
        let node = SCNNode(geometry: faceMesh)
        node.geometry?.firstMaterial?.fillMode = .lines
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard
            let faceAnchor = anchor as? ARFaceAnchor,
            let faceGeometry = node.geometry as? ARSCNFaceGeometry
        else { return }

        faceGeometry.firstMaterial?.diffuse.contents = colors[colorIndex]
        faceGeometry.update(from: faceAnchor.geometry)
    }
}
