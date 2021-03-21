import UIKit
import SceneKit
import ARKit

class Day47_ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!

    private var animationTimer: Timer?
    private var time: Int = 0

    private var player: AVAudioPlayer?
    private var playerComplete: AVAudioPlayer?

    override func viewDidLoad() {
        super.viewDidLoad()

        sceneView.scene = SCNScene()
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true

        prepareSound()

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {

        let text = SCNText(string: "", extrusionDepth: 0.5)
        text.font = UIFont(name: "HiraKakuProN-W6", size: 100)
        let textNode = SCNNode(geometry: text)

        let (min, max) = (textNode.boundingBox)
        let x = CGFloat(max.x - min.x)
        textNode.position = SCNVector3(-(x/2), 0, -0.3)
        textNode.scale = SCNVector3(0.001, 0.001, 0.01)

        sceneView.scene.rootNode.addChildNode(textNode)

        animateTextGeometry(text, withText: "AR100Days!") { [weak self] in
            guard let self = self else { return }
            self.playerComplete?.play()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
    }

    func animateTextGeometry(_ textGeometry: SCNText, withText text: String, completed: @escaping () -> Void ) {

        let characters = Array(text)

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] timer in
            guard let self = self else { return }

            if self.time != characters.count {
                let currentText = textGeometry.string as! String
                textGeometry.string = currentText + String(characters[(self.time)])
                self.time += 1
                self.player?.play()
            } else {
                timer.invalidate()
                self.time = 0
                completed()
            }
        }
    }

    func prepareSound() {
        try! AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try! AVAudioSession.sharedInstance().setActive(true)

        if let url = Bundle.main.url(forResource: "camera_click_001", withExtension: "wav") {
            player = try! AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            player?.prepareToPlay()
        }

        if let url = Bundle.main.url(forResource: "impact-001", withExtension: "wav") {
            playerComplete = try! AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.wav.rawValue)
            playerComplete?.prepareToPlay()
        }
    }
}
