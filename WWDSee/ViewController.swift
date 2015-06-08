import UIKit
import MapboxGL
import JavaScriptCore

class ViewController: UIViewController, DrawingViewDelegate, MGLMapViewDelegate {

    var map: MGLMapView!
    var js: JSContext!
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

        js = JSContext(virtualMachine: JSVirtualMachine())

        js.exceptionHandler = { context, value in
            NSLog("Exception: %@", value)
        }

        let listingsJS = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("denver", ofType: "geojson")!,
            encoding: NSUTF8StringEncoding,
            error: nil)
        js.setObject(listingsJS, forKeyedSubscript: "listings")
        js.evaluateScript("var listings = JSON.parse(listings)")

        let utilJS = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("javascript.util.min", ofType: "js")!,
            encoding: NSUTF8StringEncoding,
            error: nil) as! String
        js.evaluateScript(utilJS)

        let turfJS = NSString(contentsOfFile:
            NSBundle.mainBundle().pathForResource("turf.min", ofType: "js")!,
            encoding: NSUTF8StringEncoding,
            error: nil) as! String
        js.evaluateScript(turfJS)
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
        var polygon = NSMutableDictionary()

        polygon["type"] = "FeatureCollection"

        var coordinatesArray = NSMutableArray()

        var coordinates = [CLLocationCoordinate2D]()

        for point in points {
            let coordinate = map.convertPoint(point, toCoordinateFromView: map)
            coordinates.append(coordinate)
            coordinatesArray.addObject(
                NSArray(objects: NSNumber(double: coordinate.longitude),
                    NSNumber(double: coordinate.latitude)))
        }

        var geometry = NSMutableDictionary()
        geometry["type"] = "Polygon"
        geometry["coordinates"] = NSArray(object: coordinatesArray)

        var feature = NSMutableDictionary()
        feature["geometry"] = geometry
        feature["type"] = "Feature"
        feature["properties"] = NSDictionary()

        var features = NSArray(object: feature)

        polygon["features"] = features

        let polygonJSON = NSString(data:
            NSJSONSerialization.dataWithJSONObject(polygon,
                options: nil,
                error: nil)!,
            encoding: NSUTF8StringEncoding)

        js.setObject(polygonJSON, forKeyedSubscript: "polygonJSON")
        js.evaluateScript("var polygon = JSON.parse(polygonJSON)")

        js.evaluateScript("var within = turf.within(listings, polygon)")

        var annotations = [MGLAnnotation]()

        for i in 0..<js.evaluateScript("within.features.length").toInt32() {
            js.setObject(NSNumber(int: i), forKeyedSubscript: "i")
            let listing = js.evaluateScript("within.features[i]")
            let lon = listing.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(0).toDouble()
            let lat = listing.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(1).toDouble()
            let price = "$" + listing.objectForKeyedSubscript("properties").objectForKeyedSubscript("price").toString()
            var annotation = MGLPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat,
                longitude: lon)
            annotation.title = "Listing"
            annotation.subtitle = price
            annotations.append(annotation)
        }

        annotations.append(MGLPolygon(coordinates: &coordinates, count: UInt(coordinates.count)))
        annotations.append(MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count)))

        var connector = [coordinates.last!, coordinates.first!]

        annotations.append(MGLPolyline(coordinates: &connector, count: UInt(connector.count)))

        map.addAnnotations(annotations)

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

    func mapView(mapView: MGLMapView!, annotationCanShowCallout annotation: MGLAnnotation!) -> Bool {
        return true
    }

    func mapView(mapView: MGLMapView!, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation!) -> UIView! {
        return UIButton.buttonWithType(.DetailDisclosure) as! UIView
    }

    func mapView(mapView: MGLMapView!, annotation: MGLAnnotation!, calloutAccessoryControlTapped control: UIControl!) {
        println(annotation.title)
    }

}
