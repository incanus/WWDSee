import UIKit
import MapboxGL

class ViewController: UIViewController, DrawingViewDelegate, MGLMapViewDelegate {

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
        map.delegate = self
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
        var coordinates = [CLLocationCoordinate2D]()

        for point in points {
            coordinates.append(map.convertPoint(point, toCoordinateFromView: map))
        }

        map.addAnnotation(MGLPolygon(coordinates: &coordinates, count: UInt(coordinates.count)))
        map.addAnnotation(MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count)))

        var connector = [coordinates.last!, coordinates.first!]

        map.addAnnotation(MGLPolyline(coordinates: &connector, count: UInt(connector.count)))

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(0.5)), dispatch_get_main_queue()) { [unowned self] in
            self.cancelSearch()
        }
    }

    func mapView(mapView: MGLMapView!, alphaForShapeAnnotation annotation: MGLShape!) -> CGFloat {
        return (annotation is MGLPolyline ? 1.0 : 0.25)
    }

    func mapView(mapView: MGLMapView!, fillColorForPolygonAnnotation annotation: MGLPolygon!) -> UIColor! {
        return UIColor.redColor()
    }

    func mapView(mapView: MGLMapView!, lineWidthForPolylineAnnotation annotation: MGLPolyline!) -> CGFloat {
        return 2
    }

    func mapView(mapView: MGLMapView!, strokeColorForShapeAnnotation annotation: MGLShape!) -> UIColor! {
        return UIColor.redColor()
    }

}
