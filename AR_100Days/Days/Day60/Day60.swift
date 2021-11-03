import UIKit
import SceneKit

class Day60: NSObject {

    // Playground usage:
    //
    //    import PlaygroundSupport
    //
    //    let destUrl = playgroundSharedDataDirectory.appendingPathComponent("result.usdz")
    //    let sourceImagePath = Bundle.main.path(forResource: "image001", ofType: "png")!
    //    let sourceImage = UIImage(contentsOfFile: sourceImagePath)!
    //    exec(sourceImage: sourceImage, destUrl: destUrl)

    public func exec(sourceImage: UIImage, destUrl: URL) {

        let scene = SCNScene()

        let node = SCNNode()
        node.eulerAngles = SCNVector3(-Float.pi/2, 0, 0)
        node.geometry = SCNPlane(width: 0.5, height: 0.5)

        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = sourceImage
        material.transparent.contents = sourceImage
        material.emission.contents = sourceImage
        material.ambientOcclusion.contents = sourceImage
        node.geometry?.materials = [material]

        scene.rootNode.addChildNode(node)

        scene.write(to: destUrl, options: nil, delegate: nil, progressHandler: nil)
    }
}
