import ARKit
import Combine
import RealityKit
import UIKit

protocol Day21_ViewControllerDelegate: AnyObject {
    func onSceneUpdated(_ arView: ARView, deltaTimeInterval: TimeInterval)
}

enum Day21_Constants {
    static let radar2DLocation = CGRect(x: 22.5, y: 122.5, width: 300, height: 300)
}

public struct Day21_CustomCameraComponent: Component {
    var aspectRatio: Float = 1
    var viewMatrix = float4x4()
    var projectionMatrix = float4x4()
    var deviceTransform = float4x4()
}

class Day21_ViewController: UIViewController, UIGestureRecognizerDelegate {

    @IBOutlet var arView: ARView!

    weak var delegate: Day21_ViewControllerDelegate?
    private var gameManager: Day21_GameManager?
    private var trackingConfiguration: ARWorldTrackingConfiguration?
    private var sceneObserver: Cancellable?

    override func viewDidLoad() {
        super.viewDidLoad()

        Day21_CustomCameraComponent.registerComponent()
        Day21_Classifications.reset()

        sceneObserver = arView.scene.subscribe(to: SceneEvents.Update.self,
                                               { event in
                                                self.updateLoop(deltaTimeInterval: event.deltaTime)
                                               } )
        configureView()
        arView.session.delegate = self
        gameManager = Day21_GameManager(viewController: self)

        let tap = UITapGestureRecognizer(target: self, action: #selector(Day21_ViewController.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        view.addGestureRecognizer(tap)
    }

    @objc func doubleTap(_ sender: UITapGestureRecognizer) {
        gameManager?.toggleState()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        gameManager?.resetArViewFrame(frame: arView.frame)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        exitGame()
    }

    private func configureView() {
        arView.automaticallyConfigureSession = false

        trackingConfiguration = ARWorldTrackingConfiguration()
        trackingConfiguration?.sceneReconstruction = .meshWithClassification
        trackingConfiguration?.planeDetection = [.horizontal, .vertical]
        arView.session.run(trackingConfiguration!)

        arView.environment.sceneUnderstanding.options = []
        arView.environment.sceneUnderstanding.options = [.collision, .physics]
        arView.renderOptions = [.disablePersonOcclusion]
    }

    private func exitGame() {
        gameManager?.shutdownGame()
        sceneObserver?.cancel()
        sceneObserver = nil
        arView.session.delegate = nil
        arView.scene.anchors.removeAll()
        if let trackingConfiguration = trackingConfiguration {
            trackingConfiguration.planeDetection = []
            trackingConfiguration.environmentTexturing = .none
            arView.session.run(trackingConfiguration, options: [.resetTracking, .removeExistingAnchors])
        }
        delegate = nil
        gameManager = nil
    }

    private func updateLoop(deltaTimeInterval: TimeInterval) {
        delegate?.onSceneUpdated(arView, deltaTimeInterval: deltaTimeInterval)
    }
}

extension Day21_ViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        gatherRays(anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
    }

    func onNewClassifications(_ categorizations: [SIMD3<Float>: ARMeshClassification]) {
        gameManager?.radarMap.addCategories(categorizations)
    }

    func gatherRays(_ anchors: [ARAnchor]) {
        guard !Day21_Classifications.isUpdating && anchors.count > 1 else { return }

        Day21_Classifications.isUpdating = true
        DispatchQueue.global().async {
            var newClassifications = [SIMD3<Float>: ARMeshClassification]()
            for anchorIndex in 0..<anchors.count {

                guard let arMeshAnchor = anchors[anchorIndex] as? ARMeshAnchor else { continue }

                for index in 0..<arMeshAnchor.geometry.faces.count {
                    let geometricCenterOfFace = arMeshAnchor.geometry.centerOf(faceWithIndex: index)
                    var centerLocalTransform = matrix_identity_float4x4
                    centerLocalTransform.columns.3 = SIMD4<Float>(geometricCenterOfFace.x,
                                                                  geometricCenterOfFace.y,
                                                                  geometricCenterOfFace.z, 1)
                    let centerWorldPosition = (arMeshAnchor.transform * centerLocalTransform).position

                    let classification = arMeshAnchor.geometry.classificationOf(faceWithIndex: index)

                    newClassifications[centerWorldPosition] = classification
                }
            }

            DispatchQueue.main.async {
                self.onNewClassifications(newClassifications)
                newClassifications.removeAll()
                Day21_Classifications.isUpdating = false
            }
        }
    }
}
