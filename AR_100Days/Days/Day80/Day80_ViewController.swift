import UIKit
import ARKit
import RealityKit

class Day80_ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet weak var trackingStateLabel: UILabel!
    private var arView: ARView!
    private var geoAnchors: [ARGeoAnchor] = []
    private let coachingOverlay = ARCoachingOverlayView()
    
    struct MapInfo: Codable {
        var coordinates: [Coordinate]
    }

    struct Coordinate: Codable {
        var latitude: Double
        var longitude: Double
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        arView = ARView(frame: view.bounds)
        view.addSubview(arView)
        arView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: arView!, attribute: $0, relatedBy: .equal, toItem: arView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        arView.session.delegate = self
        view.sendSubviewToBack(arView)
        
        setupCoachingOverlay()
        
        arView.automaticallyConfigureSession = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        restartSession()
    }
    
    @IBAction func fetchButton_Action(_ sender: UIButton) {
//        let url = URL(string: "Json URL")!
//        let task = URLSession.shared.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
//            guard let self = self else { return }
//            if let data = data {
//                let decoder = JSONDecoder()
//                guard let info: MapInfo = try? decoder.decode(MapInfo.self, from: data) else {
//                    fatalError("Failed to decode from JSON.")
//                }
//                for item in info.coordinates {
//                    let geoAnchor = ARGeoAnchor(coordinate: CLLocationCoordinate2DMake(item.latitude, item.longitude))
//                    self.arView.session.add(anchor: geoAnchor)
//                }
//            }
//        })
//        task.resume()

        let mapInfo = MapInfo(coordinates: [
            Coordinate(latitude: 35.659719, longitude: 139.702349),
            Coordinate(latitude: 35.659662, longitude: 139.702244),
            Coordinate(latitude: 35.659599, longitude: 139.702099),
        ])

        for item in mapInfo.coordinates {
            let geoAnchor = ARGeoAnchor(coordinate: CLLocationCoordinate2DMake(item.latitude, item.longitude))
            self.arView.session.add(anchor: geoAnchor)
        }
    }

    func restartSession() {
        let geoTrackingConfig = ARGeoTrackingConfiguration()
        geoTrackingConfig.planeDetection = [.horizontal]
        arView.session.run(geoTrackingConfig, options: .removeExistingAnchors)
        geoAnchors.removeAll()
        
        arView.scene.anchors.removeAll()
        
        trackingStateLabel.text = ""
    }

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for geoAnchor in anchors.compactMap({ $0 as? ARGeoAnchor }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.arView.scene.addAnchor(Entity.placemarkEntity(for: geoAnchor))
            }
            self.geoAnchors.append(geoAnchor)
        }
    }
    
    func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
        
        hideUIForCoaching(geoTrackingStatus.state != .localized)
        
        var text = ""
        if geoTrackingStatus.state == .localized {
            text += "Accuracy: \(geoTrackingStatus.accuracy.description)"
        } else {
            switch geoTrackingStatus.stateReason {
            case .none:
                break
            case .worldTrackingUnstable:
                let arTrackingState = session.currentFrame?.camera.trackingState
                if case let .limited(arTrackingStateReason) = arTrackingState {
                    text += "\n\(geoTrackingStatus.stateReason.description): \(arTrackingStateReason.description)."
                } else {
                    fallthrough
                }
            default: text += "\n\(geoTrackingStatus.stateReason.description)."
            }
        }
        self.trackingStateLabel.text = text
    }
}

extension Day80_ViewController: ARCoachingOverlayViewDelegate {
    
    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        hideUIForCoaching(true)
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        hideUIForCoaching(false)
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        restartSession()
    }

    func setupCoachingOverlay() {
        coachingOverlay.delegate = self
        arView.addSubview(coachingOverlay)
        coachingOverlay.goal = .geoTracking
        coachingOverlay.session = arView.session
        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: arView.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: arView.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: arView.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: arView.heightAnchor)
            ])
    }
    
    func hideUIForCoaching(_ active: Bool) {
        trackingStateLabel.isHidden = active
    }
}

extension simd_float4x4 {
    var translation: SIMD3<Float> {
        get {
            return SIMD3<Float>(columns.3.x, columns.3.y, columns.3.z)
        }
        set (newValue) {
            columns.3.x = newValue.x
            columns.3.y = newValue.y
            columns.3.z = newValue.z
        }
    }
}

extension Entity {
    static func placemarkEntity(for arAnchor: ARAnchor) -> AnchorEntity {
        let placemarkAnchor = AnchorEntity(anchor: arAnchor)
        
        let sphereIndicator = generateSphereIndicator(radius: 0.5)
        
        let height = sphereIndicator.visualBounds(relativeTo: nil).extents.y
        sphereIndicator.position.y = height / 2
        
        let distanceFromGround: Float = 3
        sphereIndicator.move(by: [0, distanceFromGround, 0], scale: .one * 10, after: 0.5, duration: 3.0)
        placemarkAnchor.addChild(sphereIndicator)
        
        return placemarkAnchor
    }
    
    static func generateSphereIndicator(radius: Float) -> Entity {
        let indicatorEntity = Entity()
        
        let innerSphere = ModelEntity.blueSphere.clone(recursive: true)
        indicatorEntity.addChild(innerSphere)
        let outerSphere = ModelEntity.transparentSphere.clone(recursive: true)
        indicatorEntity.addChild(outerSphere)
        
        return indicatorEntity
    }
    
    func move(by translation: SIMD3<Float>, scale: SIMD3<Float>, after delay: TimeInterval, duration: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            var transform: Transform = .identity
            transform.translation = self.transform.translation + translation
            transform.scale = self.transform.scale * scale
            self.move(to: transform, relativeTo: self.parent, duration: duration, timingFunction: .easeInOut)
        }
    }
}

extension ModelEntity {
    static let blueSphere = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.33), materials: [UnlitMaterial(color: #colorLiteral(red: 0, green: 0.3, blue: 1.4, alpha: 1))])
    static let transparentSphere = ModelEntity(
        mesh: MeshResource.generateSphere(radius: 0.5),
        materials: [SimpleMaterial(color: #colorLiteral(red: 1, green: 1, blue: 1, alpha: 0.25), roughness: 0.3, isMetallic: true)])
}

extension ARGeoTrackingStatus.StateReason {
    var description: String {
        switch self {
        case .none: return "None"
        case .notAvailableAtLocation: return "Geotracking is unavailable here. Please return to your previous location to continue"
        case .needLocationPermissions: return "App needs location permissions"
        case .worldTrackingUnstable: return "Limited tracking"
        case .geoDataNotLoaded: return "Downloading localization imagery. Please wait"
        case .devicePointedTooLow: return "Point the camera at a nearby building"
        case .visualLocalizationFailed: return "Point the camera at a building unobstructed by trees or other objects"
        case .waitingForLocation: return "ARKit is waiting for the system to provide a precise coordinate for the user"
        case .waitingForAvailabilityCheck: return "ARKit is checking Location Anchor availability at your locaiton"
        @unknown default: return "Unknown reason"
        }
    }
}

extension ARGeoTrackingStatus.Accuracy {
    var description: String {
        switch self {
        case .undetermined: return "Undetermined"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        @unknown default: return "Unknown"
        }
    }
}

extension ARCamera.TrackingState.Reason {
    var description: String {
        switch self {
        case .initializing: return "Initializing"
        case .excessiveMotion: return "Too much motion"
        case .insufficientFeatures: return "Insufficient features"
        case .relocalizing: return "Relocalizing"
        @unknown default: return "Unknown"
        }
    }
}
