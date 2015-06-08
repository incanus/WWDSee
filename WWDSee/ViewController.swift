import UIKit
import CoreLocation
import MapboxGL
import JavaScriptCore
import MBProgressHUD

class ListingAnnotation:  MGLPointAnnotation {}
class StartingAnnotation: MGLPointAnnotation {}
class KeyLine: MGLPolyline {}
class RouteLine: MGLPolyline {}

class ViewController: UIViewController,
                      DrawingViewDelegate,
                      MGLMapViewDelegate {

    let MapboxTintColor = UIColor(red: 0.120, green:0.550, blue:0.670, alpha:1.000)

    var map: MGLMapView!
    var js: JSContext!
    var drawingView: DrawingView!
    var geocoder: MBGeocoder!
    var startingPoint: StartingAnnotation?
    var directions: MBDirections?
    var route: [CLLocationCoordinate2D]?
    var routeLine: RouteLine?

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search Listings"

        view.tintColor = MapboxTintColor
        navigationController?.navigationBar.tintColor = MapboxTintColor

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Organize,
            target: self,
            action: "swapStyle")

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Search,
            target: self,
            action: "startSearch")

        map = MGLMapView(frame: view.bounds)
        map.delegate = self
        map.autoresizingMask = .FlexibleWidth | .FlexibleHeight
        map.centerCoordinate = CLLocationCoordinate2D(latitude: 39.74185,
            longitude: -104.981105)
        map.zoomLevel = 10
        view.addSubview(map)

        map.addGestureRecognizer(UILongPressGestureRecognizer(target: self,
            action: "handleLongPress:"))
        map.addGestureRecognizer({
            let doubleLongPress = UILongPressGestureRecognizer(target: self,
                action: "handleDoubleLongPress:")
            doubleLongPress.numberOfTouchesRequired = 2
            return doubleLongPress
            }())

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

        geocoder = MBGeocoder(accessToken: MGLAccountManager.accessToken())
    }

    func swapStyle() {
        let currentStyle = map.styleURL.absoluteString!.componentsSeparatedByString("/").last!
        var newStyle: String

        if (currentStyle.hasPrefix("mapbox-streets")) {
            newStyle = "emerald"
        } else if (currentStyle.hasPrefix("emerald")) {
            newStyle = "light"
        } else if (currentStyle.hasPrefix("light")) {
            newStyle = "dark"
        } else {
            newStyle = "mapbox-streets"
        }

        map.styleURL = NSURL(string: NSString(format: "asset://styles/%@-v7.json", newStyle) as String)
    }

    func handleLongPress(longPress: UILongPressGestureRecognizer) {
        if (longPress.state == .Began) {
            let coordinate = map.convertPoint(longPress.locationInView(longPress.view),
                toCoordinateFromView: map)
            if (startingPoint != nil) {
                map.removeAnnotation(startingPoint)
            }
            if (routeLine != nil) {
                map.removeAnnotation(routeLine)
            }
            startingPoint = StartingAnnotation()
            startingPoint?.title = "Starting Location"
            startingPoint?.coordinate = coordinate
            map.addAnnotation(startingPoint)
            map.selectAnnotation(startingPoint, animated: true)
        }
    }

    func handleDoubleLongPress(longPress: UILongPressGestureRecognizer) {
        if (longPress.state == .Began) {
            map.removeAnnotations(map.annotations)
            if (drawingView != nil) {
                drawingView.removeFromSuperview()
                drawingView = nil
            }
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
        drawingView = nil
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

        var pointAnnotations = [MGLAnnotation]()

        for i in 0..<js.evaluateScript("within.features.length").toInt32() {
            js.setObject(NSNumber(int: i), forKeyedSubscript: "i")
            let listing = js.evaluateScript("within.features[i]")
            let lon = listing.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(0).toDouble()
            let lat = listing.objectForKeyedSubscript("geometry").objectForKeyedSubscript("coordinates").objectAtIndexedSubscript(1).toDouble()
            let price = "$" + listing.objectForKeyedSubscript("properties").objectForKeyedSubscript("price").toString()
            var annotation = ListingAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat,
                longitude: lon)
            annotation.title = "Listing"
            annotation.subtitle = price
            pointAnnotations.append(annotation)
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) { [unowned self] in
            self.map.addAnnotations(pointAnnotations)
        }

        let hud = MBProgressHUD(view: view)
        hud.mode = .Indeterminate
        hud.labelText = "Searching..."
        hud.completionBlock = {
            hud.removeFromSuperview()
        }
        view.addSubview(hud)
        hud.show(true)
        hud.hide(true, afterDelay: 1)

        var lineAnnotations = [MGLAnnotation]()

        lineAnnotations.append(MGLPolygon(coordinates: &coordinates, count: UInt(coordinates.count)))
        lineAnnotations.append(KeyLine(coordinates: &coordinates, count: UInt(coordinates.count)))

        var connector = [coordinates.last!, coordinates.first!]

        lineAnnotations.append(KeyLine(coordinates: &connector, count: UInt(connector.count)))

        map.addAnnotations(lineAnnotations)

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) { [unowned self] in
            self.cancelSearch()
        }
    }

    func mapView(mapView: MGLMapView!, alphaForShapeAnnotation annotation: MGLShape!) -> CGFloat {
        return (annotation is MGLPolyline ? 1.0 : 0.25)
    }

    func mapView(mapView: MGLMapView!, fillColorForPolygonAnnotation annotation: MGLPolygon!) -> UIColor! {
        return UIColor.blueColor()
    }

    func mapView(mapView: MGLMapView!, lineWidthForPolylineAnnotation annotation: MGLPolyline!) -> CGFloat {
        return (annotation is KeyLine ? 2 : 3)
    }

    func mapView(mapView: MGLMapView!, strokeColorForShapeAnnotation annotation: MGLShape!) -> UIColor! {
        return (annotation is KeyLine ? UIColor.blueColor() : UIColor.purpleColor())
    }

    func mapView(mapView: MGLMapView!, annotationCanShowCallout annotation: MGLAnnotation!) -> Bool {
        return true
    }

    func mapView(mapView: MGLMapView!, leftCalloutAccessoryViewForAnnotation annotation: MGLAnnotation!) -> UIView! {
        return (annotation is ListingAnnotation ? UIImageView(image: UIImage(named: "listing_thumb.jpg")) : nil)
    }

    func mapView(mapView: MGLMapView!, rightCalloutAccessoryViewForAnnotation annotation: MGLAnnotation!) -> UIView! {
        if (annotation is ListingAnnotation && startingPoint != nil) {
            let button = UIButton.buttonWithType(.Custom) as! UIButton
            button.accessibilityLabel = "Show directions"
            let image = UIImage(named: "1096-direction-arrow")!.imageTintedWithColor(MapboxTintColor)
            button.setImage(image, forState: .Normal)
            button.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
            return button
        }
        return nil
    }

    func mapView(mapView: MGLMapView!, annotation: MGLAnnotation!, calloutAccessoryControlTapped control: UIControl!) {
        if (startingPoint != nil) {
            map.deselectAnnotation(annotation, animated: false)

            if (routeLine != nil) {
                map.removeAnnotation(routeLine)
            }

            let hud = MBProgressHUD(view: view)
            hud.mode = .Indeterminate
            hud.labelText = "Routing..."
            hud.completionBlock = {
                hud.removeFromSuperview()
            }
            view.addSubview(hud)
            hud.show(true)
            hud.hide(true, afterDelay: 1)

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) { [unowned self] in
                var coordinates = self.route!
                self.routeLine = RouteLine(coordinates: &coordinates, count: UInt(coordinates.count))
                self.map.addAnnotation(self.routeLine)
            }
        }
    }

    func mapView(mapView: MGLMapView!, symbolNameForAnnotation annotation: MGLAnnotation!) -> String! {
        return (annotation is ListingAnnotation ? "secondary_marker" : "default_marker")
    }

    func mapView(mapView: MGLMapView!, didSelectAnnotation annotation: MGLAnnotation!) {
        if (annotation.title == "Listing") {
            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(CLLocation(latitude: annotation.coordinate.latitude,
                longitude: annotation.coordinate.longitude),
                completionHandler: { [unowned self] (results, error) in
                    let streetAddress = (results.first! as! MBPlacemark).name.componentsSeparatedByString(",").first!
                    (annotation as! MGLPointAnnotation).title = streetAddress
                    self.map.deselectAnnotation(annotation, animated: false)
                    self.map.selectAnnotation(annotation, animated: false)
            })
        }
        if (startingPoint != nil) {
            directions?.cancel()
            directions = MBDirections(request:
                MBDirectionsRequest(sourceCoordinate: startingPoint!.coordinate,
                    destinationCoordinate: annotation.coordinate),
                accessToken: MGLAccountManager.accessToken())
            directions!.calculateDirectionsWithCompletionHandler { [unowned self] (response, error) in
                if (response?.routes.count > 0) {
                    var routeGeometry = response!.routes.first!.geometry
                    self.route = routeGeometry
                }
            }
        }
    }

}
