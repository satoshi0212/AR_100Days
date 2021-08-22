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

class Day53_ViewController: UIViewController {

    struct CustomBuffer {
        var effectIndex: Float
        var time: Float
    }

    private var sceneView: ARSCNView!
    private var shadersIndex = 0
    private var queue: AudioQueueRef!
    private var timer: Timer!
    private var scnPrograms: [SCNProgram] = []
    private var lastPeak: Float32 = 0

    private lazy var startTime = Date()

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView = ARSCNView(frame: view.bounds)
        view.addSubview(sceneView)
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: sceneView!, attribute: $0, relatedBy: .equal, toItem: sceneView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        sceneView.delegate = self

        startUpdatingVolume()

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)

        // Note: somehow, it can't change fragment shader effect in a single shader, then prepare shaders
        for i in 0...5 {
            let program = SCNProgram()
            program.vertexFunctionName = "day53_textureVertex"
            program.fragmentFunctionName = "day53_textureFragment" + String(i)
            scnPrograms.append(program)
        }
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        // debug
        shadersIndex += 1
        if shadersIndex > 4 {
            shadersIndex = 0
        }
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

    private func startUpdatingVolume() {
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

        timer = Timer.scheduledTimer(timeInterval: 0.1,
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

        //print("\(levelMeter.mPeakPower)" )

        if levelMeter.mPeakPower >= -1.3 {
            if lastPeak == levelMeter.mPeakPower { return }
            lastPeak = levelMeter.mPeakPower

            shadersIndex += 1
            if shadersIndex > 4 {
                shadersIndex = 0
            }
        }
    }
}

extension Day53_ViewController: ARSCNViewDelegate {

    func renderer(_: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else { return nil }
        let faceMesh = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)
        let node = SCNNode(geometry: faceMesh)
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard
            let faceAnchor = anchor as? ARFaceAnchor,
            let faceGeometry = node.geometry as? ARSCNFaceGeometry
        else { return }

        if let material = faceGeometry.firstMaterial {
            material.program = scnPrograms[shadersIndex]
            let time = Float(Date().timeIntervalSince(startTime))
            var custom = CustomBuffer(effectIndex: Float(shadersIndex), time: time)
            material.setValue(NSData(bytes: &custom, length: MemoryLayout<CustomBuffer>.size), forKey: "custom")
        }

        faceGeometry.update(from: faceAnchor.geometry)
    }
}
