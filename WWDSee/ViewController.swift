import UIKit
import MapboxGL

class ViewController: UIViewController, DrawingViewDelegate {

    var map: MGLMapView!
    var drawingView: DrawingView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search Listings"

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Organize,
            target: self,
            action: "swapStyle")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Search,
            target: self,
            action: "startSearch")

        map = MGLMapView(frame: view.bounds)
        map.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        map.centerCoordinate = CLLocationCoordinate2D(latitude: 39.76185,
            longitude: -104.881105)
        map.zoomLevel = 7
        view.addSubview(map)
    }

    func swapStyle() {
        if (map.styleURL.absoluteString!.hasSuffix("emerald-v7.json")) {
            map.styleURL = NSURL(string: "asset://styles/mapbox-streets-v7.json")
        } else {
            map.styleURL = NSURL(string: "asset://styles/emerald-v7.json")
        }
    }

    func startSearch() {
        navigationItem.leftBarButtonItem!.enabled = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel,
            target: self,
            action: "cancelSearch")

        map.userInteractionEnabled = false

        drawingView = DrawingView(frame: view.bounds)
        drawingView.delegate = self
        view.addSubview(drawingView)
    }

    func cancelSearch() {
        navigationItem.leftBarButtonItem!.enabled = true

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Search,
            target: self,
            action: "startSearch")

        map.userInteractionEnabled = true

        drawingView.removeFromSuperview()
    }

    func drawingView(drawingView: DrawingView, didDrawWithPoints points: [CGPoint]) {
        println(points)
    }

}
