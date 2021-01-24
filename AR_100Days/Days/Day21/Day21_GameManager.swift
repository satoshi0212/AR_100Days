import ARKit
import RealityKit

class Day21_GameManager {

    weak var viewController: Day21_ViewController?
    var radarMap: Day21_RadarMap!

    init(viewController: Day21_ViewController) {
        self.viewController = viewController

        viewController.delegate = self
    }

    func updateLoop(deltaTimeInterval: TimeInterval) {
        guard let frame = viewController?.arView.session.currentFrame else { return }
        radarMap.updateCamera(frame.camera)
    }

    func resetArViewFrame(frame: CGRect) {
        if radarMap != nil {
            radarMap.removeView()
        }
        radarMap = Day21_RadarMap(frame: Day21_Constants.radar2DLocation, from: frame)
        radarMap.addView(to: viewController?.view)
    }

    func toggleState() {
        radarMap.isFullScreen ? radarMap.transitionToMinimap {} : radarMap.transitionToFullscreen()
    }

    func shutdownGame() {
        radarMap.removeView()
    }
}

extension Day21_GameManager: Day21_ViewControllerDelegate {
    func onSceneUpdated(_ arView: ARView, deltaTimeInterval: TimeInterval) {
        updateLoop(deltaTimeInterval: deltaTimeInterval)
    }
}
