import UIKit
import RealityKit

class Day81_ViewController: UIViewController {
    
    private var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        arView = ARView(frame: view.bounds)
        view.addSubview(arView)
        arView.translatesAutoresizingMaskIntoConstraints = false
        let attributes: [NSLayoutConstraint.Attribute] = [.top, .bottom, .right, .left]
        NSLayoutConstraint.activate(attributes.map {
            NSLayoutConstraint(item: arView!, attribute: $0, relatedBy: .equal, toItem: arView.superview, attribute: $0, multiplier: 1, constant: 0)
        })
        view.sendSubviewToBack(arView)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        arView.addGestureRecognizer(tapRecognizer)
    }

    @objc func tapped() {
        let url = URL(string: "https://developer.apple.com/augmented-reality/quick-look/models/teapot/teapot.usdz")!
        FileDownloader.loadFileAsync(url: url) { [weak self] (path, error) in
            guard
                let self = self,
                let path = path
            else { return }
            print("File downloaded to : \(path)")
            let fileUrl = URL(fileURLWithPath: path)

            DispatchQueue.main.async {
                let object = try! Entity.load(contentsOf: fileUrl)
                let anchor = AnchorEntity(world: [0, 0, -0.5])
                anchor.scale = [0.3, 0.3, 0.3]
                anchor.addChild(object)
                self.arView.scene.addAnchor(anchor)
            }
        }
    }
}

class FileDownloader {

    static func loadFileSync(url: URL, completion: @escaping (String?, Error?) -> Void) {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)

        if FileManager().fileExists(atPath: destinationUrl.path) {
            print("File already exists [\(destinationUrl.path)]")
            completion(destinationUrl.path, nil)
            return
        }
        
        guard let dataFromUrl = NSData(contentsOf: url) else {
            let error = NSError(domain:"Error downloading file", code:1002, userInfo:nil)
            completion(destinationUrl.path, error)
            return
        }

        if dataFromUrl.write(to: destinationUrl, atomically: true) {
            print("file saved [\(destinationUrl.path)]")
            completion(destinationUrl.path, nil)
        } else {
            print("error saving file")
            let error = NSError(domain:"Error saving file", code:1001, userInfo:nil)
            completion(destinationUrl.path, error)
        }
    }

    static func loadFileAsync(url: URL, completion: @escaping (String?, Error?) -> Void) {
        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)

        if FileManager().fileExists(atPath: destinationUrl.path) {
            print("File already exists [\(destinationUrl.path)]")
            completion(destinationUrl.path, nil)
            return
        }
        
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: nil, delegateQueue: nil)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let task = session.dataTask(with: request, completionHandler: { data, response, error in
            if error != nil {
                completion(destinationUrl.path, error)
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                  response.statusCode == 200,
                  let data = data
            else {
                completion(destinationUrl.path, error)
                return
            }
            
            try? data.write(to: destinationUrl, options: Data.WritingOptions.atomic)
            completion(destinationUrl.path, error)
        })
        task.resume()
    }
}

