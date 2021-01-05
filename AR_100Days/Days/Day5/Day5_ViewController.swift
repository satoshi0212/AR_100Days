import UIKit
import Metal
import MetalKit
import ARKit

extension MTKView: Day5_RenderDestinationProvider {
}

class Day5_ViewController: UIViewController, MTKViewDelegate, ARSessionDelegate {

    var session: ARSession!
    var renderer: Day5_Renderer!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the view's delegate
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
            renderer = Day5_Renderer(session: session, metalDevice: view.device!, renderDestination: view)

            renderer.drawRectResized(size: view.bounds.size)
        }

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(Day5_ViewController.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()

        // Enable frame semantics
        // .personSegmentation or .personSegmentationWithDepth
        configuration.frameSemantics = .personSegmentation

        // Run the view's session
        session.run(configuration)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Pause the view's session
        session.pause()
    }

    @objc
    func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // 画面タップでShader内のフラグ切り替えたいだけの割と適当な実装です
        let x = renderer.typeFlag + 1.0;
        renderer.typeFlag = x.truncatingRemainder(dividingBy: 2.0);
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

    // MARK: - ARSessionDelegate

    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user

    }

    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay

    }

    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required

    }
}
