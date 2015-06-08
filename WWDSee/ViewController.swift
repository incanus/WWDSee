import UIKit
import MapboxGL

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search Listings"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .FastForward,
            target: self,
            action: "swapStyle")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Search,
            target: self,
            action: "startSearch")

        view.addSubview({ [unowned self] in
            let map = MGLMapView(frame: self.view.bounds)
            map.autoresizingMask = .FlexibleWidth | .FlexibleHeight
            map.centerCoordinate = CLLocationCoordinate2D(latitude: 39.76185,
                longitude: -104.881105)
            map.zoomLevel = 7
            return map
            }())
    }



}
