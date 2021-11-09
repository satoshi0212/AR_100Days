import UIKit
import NearbyInteraction
import MultipeerConnectivity
import ARKit
import SceneKit

class Day63_ViewController: UIViewController, NISessionDelegate {

    @IBOutlet weak var centerInformationLabel: UILabel!
    @IBOutlet weak var detailDistanceLabel: UILabel!
    private var sceneView: ARSCNView!

    private let nearbyDistanceThreshold: Float = 0.3
    private let animationDuration = 0.0

    private var session: NISession?
    private var peerDiscoveryToken: NIDiscoveryToken?
    private var mpc: Day63_MPCSession?
    private var connectedPeer: MCPeerID?
    private var sharedTokenWithPeer = false
    private var peerDisplayName: String?

    private var targetNode: SCNNode?
    private var currentDirection: simd_float3?

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
        sceneView.automaticallyUpdatesLighting = true
        sceneView.autoenablesDefaultLighting = true
        view.sendSubviewToBack(sceneView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(tapRecognizer)

        detailDistanceLabel.text = "---"

        startup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        sceneView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sceneView.session.pause()
        session?.invalidate()
        mpc?.invalidate()
    }

    @objc func tapped(recognizer: UIGestureRecognizer) {
        addNode()
    }

    private func addNode() {

        if let node = targetNode {
            node.removeFromParentNode()
            targetNode = nil
        }

        guard
            let camera = sceneView.pointOfView,
            let direction = currentDirection
        else { return }

        let node = SCNNode()

        node.geometry = SCNSphere(radius: 0.2)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.8)
        node.geometry?.materials = [material]

        let position = SCNVector3(x: direction.x, y: direction.y, z: direction.z)
        node.position = camera.convertPosition(position, to: nil)

        sceneView.scene.rootNode.addChildNode(node)

        targetNode = node
    }

    private func startup() {
        session = NISession()
        session?.delegate = self

        // reset the token-shared flag.
        sharedTokenWithPeer = false

        if connectedPeer != nil && mpc != nil {
            if let myToken = session?.discoveryToken {
                updateInformationLabel(description: "Initializing ...")
                if !sharedTokenWithPeer {
                    shareMyDiscoveryToken(token: myToken)
                }
                guard let peerToken = peerDiscoveryToken else {
                    return
                }
                let config = NINearbyPeerConfiguration(peerToken: peerToken)
                session?.run(config)
            } else {
                fatalError("Unable to get self discovery token, is this session invalidated?")
            }
        } else {
            updateInformationLabel(description: "Discovering Peer ...")
            startupMPC()
        }
    }

    // MARK: - NISessionDelegate

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let peerToken = peerDiscoveryToken else {
            fatalError("don't have peer token")
        }

        let peerObj = nearbyObjects.first { (obj) -> Bool in
            return obj.discoveryToken == peerToken
        }

        guard let nearbyObjectUpdate = peerObj else {
            return
        }

        updateVisualization(peer: nearbyObjectUpdate)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        guard let peerToken = peerDiscoveryToken else {
            fatalError("don't have peer token")
        }

        let peerObj = nearbyObjects.first { (obj) -> Bool in
            return obj.discoveryToken == peerToken
        }

        if peerObj == nil {
            return
        }

        switch reason {
        case .peerEnded:
            peerDiscoveryToken = nil
            session.invalidate()
            startup()
            updateInformationLabel(description: "Peer Ended")
        case .timeout:
            if let config = session.configuration {
                session.run(config)
            }
            updateInformationLabel(description: "Peer Timeout")
        default:
            fatalError("Unknown and unhandled NINearbyObject.RemovalReason")
        }
    }

    func sessionWasSuspended(_ session: NISession) {
        updateInformationLabel(description: "Session suspended")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        if let config = self.session?.configuration {
            session.run(config)
        } else {
            startup()
        }

        centerInformationLabel.text = peerDisplayName
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {

        if case NIError.userDidNotAllow = error {
            if #available(iOS 15.0, *) {
                // In iOS 15.0, Settings persists Nearby Interaction access.
                updateInformationLabel(description: "Nearby Interactions access required. You can change access for NIPeekaboo in Settings.")
                // Create an alert that directs the user to Settings.
                let accessAlert = UIAlertController(title: "Access Required",
                                                    message: """
                                                    This app requires access to Nearby Interactions.
                                                    Nearby Interactions access in Settings.
                                                    """,
                                                    preferredStyle: .alert)
                accessAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                accessAlert.addAction(UIAlertAction(title: "Go to Settings", style: .default, handler: {_ in
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL, options: [:], completionHandler: nil)
                    }
                }))

                present(accessAlert, animated: true, completion: nil)
            } else {
                updateInformationLabel(description: "Nearby Interactions access required. Restart to allow access.")
            }

            return
        }

        startup()
    }

    // MARK: - Discovery token sharing and receiving using MPC.

    func startupMPC() {
        if mpc == nil {
            mpc = Day63_MPCSession(service: "ar100days", identity: "tokyo.shmdevelopment.nearbyinteraction", maxPeers: 1)
            mpc?.peerConnectedHandler = connectedToPeer
            mpc?.peerDataHandler = dataReceivedHandler
            mpc?.peerDisconnectedHandler = disconnectedFromPeer
        }
        mpc?.invalidate()
        mpc?.start()
    }

    func connectedToPeer(peer: MCPeerID) {
        guard let myToken = session?.discoveryToken else {
            fatalError("Unexpectedly failed to initialize nearby interaction session.")
        }

        if connectedPeer != nil {
            fatalError("Already connected to a peer.")
        }

        if !sharedTokenWithPeer {
            shareMyDiscoveryToken(token: myToken)
        }

        connectedPeer = peer
        peerDisplayName = peer.displayName

        centerInformationLabel.text = peerDisplayName
    }

    func disconnectedFromPeer(peer: MCPeerID) {
        if connectedPeer == peer {
            connectedPeer = nil
            sharedTokenWithPeer = false
        }
    }

    func dataReceivedHandler(data: Data, peer: MCPeerID) {
        guard let discoveryToken = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) else {
            fatalError("Unexpectedly failed to decode discovery token.")
        }
        peerDidShareDiscoveryToken(peer: peer, token: discoveryToken)
    }

    func shareMyDiscoveryToken(token: NIDiscoveryToken) {
        guard let encodedData = try?  NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            fatalError("Unexpectedly failed to encode discovery token.")
        }
        mpc?.sendDataToAllPeers(data: encodedData)
        sharedTokenWithPeer = true
    }

    func peerDidShareDiscoveryToken(peer: MCPeerID, token: NIDiscoveryToken) {
        if connectedPeer != peer {
            fatalError("Received token from unexpected peer.")
        }
        peerDiscoveryToken = token
        let config = NINearbyPeerConfiguration(peerToken: token)
        session?.run(config)
    }

    // MARK: - Visualizations

    private func isNearby(_ distance: Float) -> Bool {
        return distance < nearbyDistanceThreshold
    }

    private func animate(peer: NINearbyObject) {
        centerInformationLabel.text = peerDisplayName
        if peer.distance != nil {
            detailDistanceLabel.text = String(format: "%0.2f m", peer.distance!)
        }

        if let node = targetNode {
            if let camera = sceneView.pointOfView,
               let direction = currentDirection,
               let distance = peer.distance {

                node.isHidden = isNearby(distance)

                // x,y : adjust to center of device
                let newPosition = camera.convertPosition(SCNVector3(x: direction.x - 0.1, y: direction.y - 0.1, z: direction.z), to: nil)
                let moveTo = SCNAction.move(to: newPosition, duration: animationDuration)
                node.runAction(moveTo)
            } else {
                node.isHidden = true
            }
        }
    }

    private func updateVisualization(peer: NINearbyObject) {

        currentDirection = peer.direction

        UIView.animate(withDuration: 0.3, animations: {
            self.animate(peer: peer)
        })
    }

    private func updateInformationLabel(description: String) {
        UIView.animate(withDuration: 0.3, animations: {
            self.centerInformationLabel.alpha = 1.0
            self.centerInformationLabel.text = description
        })
    }
}

private extension FloatingPoint {
    var degreesToRadians: Self { self * .pi / 180 }
    var radiansToDegrees: Self { self * 180 / .pi }
}

private func azimuth(from direction: simd_float3) -> Float {
    return asin(direction.x)
}

private func elevation(from direction: simd_float3) -> Float {
    return atan2(direction.z, direction.y) + .pi / 2
}
