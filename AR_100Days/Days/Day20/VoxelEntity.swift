import Foundation
import RealityKit
import Combine

final class VoxelEntity: Entity, HasPhysics, HasModel, HasCollision, HasPhysicsMotion {
    var baseColor: TextureResource?
    var metallic: TextureResource?
    var roughness: TextureResource?
    var material: SimpleMaterial?

    static func loadAsync() ->AnyPublisher<VoxelEntity, Error> {
        return loadMaterialAsync().zip(Entity.loadModelAsync(named: Constants.voxelModelName),
                                       Entity.loadModelAsync(named: Constants.voxelCageName))
            .map { material, voxel, cage in
                let voxelEntity = VoxelEntity()
                voxelEntity.material = material
                voxelEntity.model = voxel.model
                voxelEntity.addChild(cage)
                return voxelEntity
            }
            .eraseToAnyPublisher()
    }

    static func loadMaterialAsync() -> AnyPublisher<SimpleMaterial, Error> {
        return TextureResource.loadAsync(named: Constants.voxelBaseColorName)
            .append(TextureResource.loadAsync(named: Constants.voxelMetallicName))
            .append(TextureResource.loadAsync(named: Constants.voxelRoughnessName))
            .collect()
            .tryMap { textures in
                var mat = SimpleMaterial()
                let baseColorResource = MaterialParameters.Texture(textures[0])
                mat.color = .init(texture: baseColorResource)
                mat.metallic = .texture(textures[1])
                mat.roughness = .texture(textures[2])
                return mat
            }
            .eraseToAnyPublisher()
    }

    static func cloneVoxel(voxelToClone: VoxelEntity) -> VoxelEntity {
        let newVoxel = voxelToClone.clone(recursive: true)
        newVoxel.baseColor = voxelToClone.baseColor
        newVoxel.metallic = voxelToClone.metallic
        newVoxel.roughness = voxelToClone.roughness
        return newVoxel
    }
}
