/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Game Assets
*/

import Foundation
import RealityKit
import Combine

final class GameAssets {
    public var creatureEntity: CreatureEntity?
    public var voxelEntity: VoxelEntity?
    public var voxelMaterial: SimpleMaterial?
    public var explodeVoxels: Entity?
    public var shatterVoxels: Entity?
    public var audioResources = [String: AudioFileResource]()

    static func loadAssetsAsync() -> AnyPublisher<GameAssets, Error> {
        return CreatureEntity.loadAsync()
            .zip(VoxelEntity.loadAsync(),
                 VoxelStructures.loadVoxelStructuresAsync(),
                 loadAudioAsync()).map { creature, voxel, voxelStructures, audio in
                    let assets = GameAssets()
                    assets.creatureEntity = creature
                    assets.voxelEntity = voxel
                    assets.voxelMaterial = voxel.material
                    assets.explodeVoxels = voxelStructures.explode
                    assets.shatterVoxels = voxelStructures.shatter
                    assets.audioResources = audio
                    return assets
            }
            .eraseToAnyPublisher()
    }

    static func loadAudioAsync() -> AnyPublisher<[String: AudioFileResource], Error> {
        return loadCreatureAudioAsync().zip(loadInteractionAudioAsync())
            .tryMap { creatureAudio, interactionAudio in
                var audioFiles = [String: AudioFileResource]()
                audioFiles.merge(creatureAudio) { (_, new) in new }
                audioFiles.merge(interactionAudio) { (_, new) in new }
                return audioFiles
            }
            .eraseToAnyPublisher()
    }

    static func loadCreatureAudioAsync() -> AnyPublisher<[String: AudioFileResource], Error> {
        return AudioResources.loadAudioAsync(AudioFiles.spawnAudio)
            .append(AudioResources.loadAudioAsync(AudioFiles.creatureDestroyAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.walkAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.flutterAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.struggleAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.idleAudio))
            .collect()
            .tryMap { loadedAudioFiles in
                var resources = [String: AudioFileResource]()
                resources[Constants.spawnAudioName] = loadedAudioFiles[0]
                resources[Constants.creatureDestroyAudioName] = loadedAudioFiles[1]
                resources[Constants.walkAudioName] = loadedAudioFiles[2]
                resources[Constants.flutterAudioName] = loadedAudioFiles[3]
                resources[Constants.struggleAudioName] = loadedAudioFiles[4]
                resources[Constants.idleAudioName] = loadedAudioFiles[5]
                return resources
            }
            .eraseToAnyPublisher()
    }

    static func loadInteractionAudioAsync() -> AnyPublisher<[String: AudioFileResource], Error> {
        return AudioResources.loadAudioAsync(AudioFiles.popAudio)
            .append(AudioResources.loadAudioAsync(AudioFiles.wooshAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.tractorBeamActivateAudio))
            .append(AudioResources.loadAudioAsync(AudioFiles.tractorBeamLoopAudio))
            .collect()
            .tryMap { loadedAudioFiles in
                var resources = [String: AudioFileResource]()
                resources[Constants.popAudioName] = loadedAudioFiles[0]
                resources[Constants.wooshAudioName] = loadedAudioFiles[1]
                resources[Constants.tractorBeamActivateAudioName] = loadedAudioFiles[2]
                resources[Constants.tractorBeamLoopAudioName] = loadedAudioFiles[3]
                return resources
            }
            .eraseToAnyPublisher()
    }
}
