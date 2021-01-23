import ARKit
import RealityKit

class GameManager {
    weak var viewController: Day20_ViewController?
    weak var assets: GameAssets?
    private var inputSystemInstance: InputSystem?
    private var voxels: Voxels?
    private var voxelTouchTrail: VoxelCursor?

    init(viewController: Day20_ViewController, assets: GameAssets) {
        self.viewController = viewController
        self.assets = assets

        self.voxels = Voxels(gameManager: self)
        guard let voxelsInstance = voxels else { return }
        self.voxelTouchTrail = VoxelCursor(voxels: voxelsInstance)

        let inputSystem = InputSystem(target: viewController, action: nil)
        inputSystem.setupDependencies(arView: viewController.arView)
        inputSystem.inputSystemDelegate = self
        inputSystem.delegate = viewController
        inputSystemInstance = inputSystem

        viewController.delegate = self
        viewController.arView.addGestureRecognizer(inputSystem)
    }
}

extension GameManager {
    public func shutdownGame() {
        voxelTouchTrail = nil
        guard let inputSystem = inputSystemInstance else { return }
        viewController?.arView.removeGestureRecognizer(inputSystem)
        viewController?.delegate = nil
        inputSystem.inputSystemDelegate = nil
        inputSystemInstance = nil
        assets = nil
        voxels?.removeAllVoxels()
        voxels = nil
    }
}

extension GameManager: InputSystemDelegate {
    func playerUpdatedTouchTrail(touchTransform: Transform) {
        voxelTouchTrail?.updatePosition(touchTransform.translation)
    }
}

extension GameManager: GameViewControllerDelegate {
    func onSceneUpdated(_ arView: ARView, deltaTimeInterval: TimeInterval) {
        voxels?.updateVoxelColorsFromFrameBuffer(arView: arView)
    }
}
