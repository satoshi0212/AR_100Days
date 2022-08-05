import UIKit
import ARKit
import SceneKit
import CoreLocation

class Day79_ViewController: UIViewController, ARSCNViewDelegate {

    private var arscnView: ARSCNView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageLineView: UIImageView!
    @IBOutlet weak var imageCenterMarkerView: UIImageView!

    private var locationManager: CLLocationManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        arscnView = ARSCNView(frame: view.bounds)
        view.addSubview(arscnView)
        arscnView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: arscnView!, attribute: $0, relatedBy: .equal, toItem: arscnView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        arscnView.scene = SCNScene()
        arscnView.delegate = self
        view.sendSubviewToBack(arscnView)

        imageView.image = UIImage(named: "Compass_Direction")
        imageView.contentMode = .center
        imageLineView.image = UIImage(named: "Compass_Line")
        imageLineView.contentMode = .center
        imageCenterMarkerView.image = UIImage(named: "Compass_CenterMarker")
        imageCenterMarkerView.contentMode = .center
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager = CLLocationManager()
            locationManager.delegate = self
        }
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        arscnView.session.run(configuration, options: [.removeExistingAnchors, .resetTracking])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        arscnView.session.pause()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.stopUpdatingHeading()
        }
    }
}

extension Day79_ViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
            break
        case .denied:
            break
        case .restricted:
            break
        case .authorizedAlways:
            break
        case .authorizedWhenInUse:
            locationManager.headingFilter = kCLHeadingFilterNone
            locationManager.headingOrientation = .portrait
            locationManager.startUpdatingHeading()
            break
        @unknown default:
            break
        }
    }

    func map(minRange: Double, maxRange: Double, minDomain: Double, maxDomain: Double, value: Double) -> Double {
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let x = map(minRange: 0, maxRange: 360, minDomain: 440, maxDomain: -440, value: newHeading.magneticHeading)
        scrollView.contentOffset = CGPoint(x: -x, y: 0)
    }
}
