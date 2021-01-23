import UIKit
import RealityKit
import Combine

class VoxelCursor {

    let idleTime: Double = 15
    let min: Double = 0.1
    let max: Double = 0.25
    weak var voxels: Voxels?
    init(voxels: Voxels) {
        self.voxels = voxels
    }

    public func updatePosition(_ centerPosition: SIMD3<Float>) {
        guard let point = voxels?.getCoordinates(centerPosition) else { return }
        getCursorVoxel(point)
    }

    public func getCursorVoxel(_ point: simd_int3) {
        voxels?.getVoxel(point, entranceTime: Double.random(in: min ... max),
                         idleTime: idleTime,
                         exitTime: Double.random(in: min ... max))
    }
}
