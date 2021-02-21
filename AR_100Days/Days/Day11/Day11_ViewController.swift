import UIKit
import Metal
import MetalKit
import ARKit

extension MTKView: Day11_RenderDestinationProvider {
}

class Day11_ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {

    var session: ARSession!
    var renderer: Day11_Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        session = ARSession()
        session.delegate = self

        // Set the view to use the default device
        if let view = self.view as? MTKView {
            view.device = MTLCreateSystemDefaultDevice()
            view.backgroundColor = UIColor.clear
            view.delegate = self

            guard view.device != nil else {
                print("Metal is not supported on this device")
                return
            }

            // Configure the renderer to draw to the view
            renderer = Day11_Renderer(session: session, metalDevice: view.device!, renderDestination: view)

            renderer.drawRectResized(size: view.bounds.size)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Enable frame semantics
        // .personSegmentation or .personSegmentationWithDepth
        configuration.frameSemantics = .personSegmentationWithDepth

        // Run the view's session
        session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        session.pause()
    }

    // MARK: - MTKViewDelegate

    // Called whenever view changes orientation or layout is changed
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        renderer.drawRectResized(size: size)
    }

    // Called whenever the view needs to render
    func draw(in view: MTKView) {
        renderer.update()
    }
}
