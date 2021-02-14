import UIKit
import Metal
import MetalKit
import ARKit

extension MTKView: Day37_RenderDestinationProvider {
}

class Day37_ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {

    var session: ARSession!
    var configuration = ARWorldTrackingConfiguration()
    var renderer: Day37_Renderer!
    var depthBuffer: CVPixelBuffer!
    var confidenceBuffer: CVPixelBuffer!

    override func viewDidLoad() {
        super.viewDidLoad()

        session = ARSession()
        session.delegate = self

        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self

            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }

            renderer = Day37_Renderer(session: session, metalDevice: view.device!, renderDestination: view)

            renderer.drawRectResized(size: view.bounds.size)
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        configuration.frameSemantics = .smoothedSceneDepth
        session.run(configuration)
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }

    func draw(in view: MTKView) {
        renderer.update()
    }
}
