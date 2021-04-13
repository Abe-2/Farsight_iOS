//
//  ViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 1/12/21.
//

import UIKit
import MapKit
import FittedSheets

// - cycle 2:
// --TODO gray out gates that don't match the search
// --TODO different colors for smaller clusters
// --TODO higher cluster radius for spots annotations
// --TODO loading indicator when loading suggestion + disabling card interaction
// --TODO draw route
// --TODO route sheet
// TODO target parking spot
// --TODO my car selection
// --TODO rating
// --TODO mark spot as my car if I parked (chose yes)
// TODO disable selecting gate when we have a route

// - cycle 3:
// TODO sending user location
// TODO fixing path extra parts issue
// TODO re-route if no is selected

// - extra
// TODO predicating when user is going to their car feature
// TODO pre-selecting a parking lot when the user is close to its boundaries
// TODO auto-complete for search

// - improvements
// TODO smaller icons for spots annotations
// TODO loading indicator when loading parking lots
// TODO remove the selection box on user location button
// TODO improve the hiding and showing of occupied spots
// TODO create a separate array for gate annotations to speed up search instead of passing through all annotations.
//  same for occupied spots.

class ViewController: UIViewController {
    
    @IBOutlet var map: MKMapView!
    @IBOutlet var btnStack: UIStackView!
    var btnCompass: MKCompassButton!
    
    @IBOutlet var srcBarTop: NSLayoutConstraint!
    @IBOutlet var srcBarHolder: UIView!
    @IBOutlet var srcBar: UISearchBar!
    
    @IBOutlet var nameHolder: UIView!
    @IBOutlet var lblParkName: UILabel!
    
    @IBOutlet var occupancyHolder: UIView!
    @IBOutlet var lblOccupancyRate: UILabel!
    
    var parkingLots = [ParkingLot]()
    var currentParkingLot: ParkingLot? = nil
    
    var currentGateAnnotation: GateAnnotation? = nil
    var activeSheet: SheetViewController? = nil
    
    let locationManager = CLLocationManager()
    
    // when at big zoom, display occupied spots pins
    var isAtBigZoom = false {
        didSet {
            // this guard ensures, that the showing and hiding happens only once
            guard oldValue != isAtBigZoom else {
                return
            }

            // in my case I wanted to show/hide only a certain type of annotations
            for case let annot as ParkingSpotAnnotation in map.annotations {
                if annot.parkingSpot.occupied {
                    map.view(for: annot)?.alpha = isAtBigZoom ? 1 : 0
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let closeGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        map.addGestureRecognizer(closeGesture)
        
        let button = MKUserTrackingButton(mapView: map)
        btnStack.insertArrangedSubview(button, at: 0)
        
        perform(#selector(removeSearchBarBackground), with: nil, afterDelay: 0.2)
        
        // change compass position
        map.showsCompass = false
        btnCompass = MKCompassButton(mapView:map)
        btnCompass.frame.origin = CGPoint(x: self.view.frame.maxX - 57, y: 170)
        btnCompass.compassVisibility = .adaptive
        view.addSubview(btnCompass)
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            zoomToUserLocation()
            locationManager.startUpdatingLocation()
        case .denied, .restricted, .notDetermined:
            alert(title: "Error", message: "Please enable your location for a better experience", completion: nil)
        default:
            break
        }
        
        getParkingLots()
    }
    
    func findView(current: UIView, path: [String], index: Int) -> UIView? {
        if index == path.count {
            return current
        }
        
        for view in current.subviews {
            let viewType = type(of: view)
            let viewTypeName = String(describing: viewType)
            
            if viewTypeName == path[index] {
                return findView(current: view, path: path, index: index+1)
            }
        }
        
        return nil
    }
    
    @objc func removeSearchBarBackground() {
        let res = findView(current: srcBar.searchTextField, path: ["_UISearchBarSearchFieldBackgroundView", "_UISearchBarSearchFieldBackgroundView"], index: 0)
        //        res!.backgroundColor = .white // simply changing it won't work since it will be overriden when we select the textfield.
        
        // so, adding a view above it that will never change does the work
        let myView = UIView(frame: res!.frame)
        myView.backgroundColor = .white
        res?.addSubview(myView)
    }
    
    func getParkingLots() {
        requestImmediate("/lot/", params: ["user_id": "51"]) { (payload, raw, error) in
            if error != nil {
                // TODO handle error
            }
            
            self.parkingLots = ParkingLot.decode(array: payload!.arrayValue)
            self.placeParkingLots()
        }
    }
    
    func placeParkingLots() {
        for parkingLot in parkingLots {
            let pointCord = CLLocationCoordinate2D(latitude: parkingLot.lat, longitude: parkingLot.lon)
            let reportLocation = ParkingLotAnnotation()
            reportLocation.title = parkingLot.name
            reportLocation.parkingLot = parkingLot
            reportLocation.coordinate = pointCord
            map.addAnnotation(reportLocation)
        }
    }
    
    // TODO move to ParkingLot model
    func get(parkingLot: ParkingLot, completion: (() -> ())?) {
        if parkingLot.gates != nil {
            // it is already loaded
            self.select(parkingLot: parkingLot)
            completion?()
            return
        }
        
        requestImmediate("/lot/\(parkingLot.id)") { (payload, raw, error) in
            if error != nil {
                // TODO handle error
            }
            
            parkingLot.gates = Gate.decode(array: payload!["gates"].arrayValue)
            parkingLot.parkingSpots = ParkingSpot.decode(array: payload!["parking_spots"].arrayValue)
            self.select(parkingLot: parkingLot)
            completion?()
        }
    }
    
    // This should not be called directly. It should only be called from get(parkingLot)
    func select(parkingLot: ParkingLot) {
        if currentParkingLot != nil && currentParkingLot?.id != parkingLot.id {
            deselectCurrentParkingLot()
        }
        currentParkingLot = parkingLot
        showParkingLotControls(forPark: parkingLot)
        
        for spot in parkingLot.parkingSpots! {
            let pointCord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
            let marker = ParkingSpotAnnotation()
            marker.parkingSpot = spot
            marker.coordinate = pointCord
            map.addAnnotation(marker)
        }
        
        for gate in parkingLot.gates! {
            let pointCord = CLLocationCoordinate2D(latitude: gate.lat, longitude: gate.lon)
            let marker = GateAnnotation()
            marker.gate = gate
            marker.coordinate = pointCord
            marker.title = gate.name
            map.addAnnotation(marker)
        }
        
        addMyCarAnnotation()
    }
    
    func addMyCarAnnotation() {
        // remove old annotation, if any
        if let oldAnnotation = currentParkingLot?.myCarAnnotation {
            map.removeAnnotation(oldAnnotation)
        }
        
        if currentParkingLot!.userSpot != nil {
            for spot in currentParkingLot!.parkingSpots! {
                if spot.id == currentParkingLot!.userSpot {
                    let pointCord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
                    let marker = MyCarAnnotation()
                    marker.coordinate = pointCord
                    marker.title = "My car"
                    map.addAnnotation(marker)
                    
                    // TODO I think the myCarAnnotation should instead be on ViewController
                    currentParkingLot!.myCarAnnotation = marker
                    
                    break
                }
            }
        }
    }
    
    func addDestinationAnnotation() {
//        let pointCord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
//        let marker = MyCarAnnotation()
//        marker.coordinate = pointCord
//        marker.title = "My car"
//        map.addAnnotation(marker)
//
//        currentParkingLot!.myCarAnnotation = marker
    }
    
    func showParkingLotControls(forPark parkingLot: ParkingLot) {
        UIView.animate(withDuration: 0.3) {
            self.srcBarTop.constant = 12
            self.srcBarHolder.alpha = 1
            self.nameHolder.alpha = 1
            self.lblParkName.text = parkingLot.name
            
            self.occupancyHolder.alpha = 1
            
            if parkingLot.totalSpots != 0 {
                let rate: Double = Double(parkingLot.occupiedSpots)/Double(parkingLot.totalSpots)
                let finalRate: String = rate < 1.0 ? "<1" : String(Int(rate))
                self.lblOccupancyRate.text = "\(finalRate)%"
            }
            
            self.view.layoutIfNeeded()
        }
        
        // update compass position
        let totalAdded = srcBarTop.constant + srcBarHolder.frame.height
        self.btnCompass.frame.origin = CGPoint(x: self.view.frame.maxX - 57, y: 170 + totalAdded)
    }
    
    func deselectCurrentParkingLot() {
        for annotation in map.annotations {
            if annotation is ParkingSpotAnnotation || annotation is GateAnnotation || annotation is MyCarAnnotation || annotation is DestinationAnnotation {
                map.removeAnnotation(annotation)
            }
        }
    }
}

extension ViewController: MKMapViewDelegate {
    
    // TODO use dequeue to reuse markers
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        switch annotation {
        case is MKClusterAnnotation:
            // only parking spots have a cluster
            // TODO move into annotations file
            // TODO we need more zoom. Currently it gets stuck on 2 per cluster
            let clusterMarker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: ParkingSpotAnnotationView.clusteringIdentifier)
            clusterMarker.collisionMode = .rectangle
            
            // adjust size to determine how much annotations are clustered. Bigger size mean less clusters.
            clusterMarker.bounds = CGRect(origin: clusterMarker.bounds.origin, size: CGSize(width: 50, height: 50))
            
            clusterMarker.displayPriority = .defaultLow
            clusterMarker.zPriority = .min
            clusterMarker.centerOffset = CGPoint(x: 0, y: -10) // Offset center point to animate better with marker annotations
            
            (annotation as! MKClusterAnnotation).title = "empty"
            clusterMarker.subtitleVisibility = MKFeatureVisibility.hidden
            
            let clusterAnnotation = annotation as! MKClusterAnnotation
            if clusterAnnotation.memberAnnotations.count < 5 {
                clusterMarker.markerTintColor = #colorLiteral(red: 0.7490196078, green: 0.1254901961, blue: 0.1843137255, alpha: 1)
            } else if clusterAnnotation.memberAnnotations.count < 30 {
                clusterMarker.markerTintColor = #colorLiteral(red: 0.9333333333, green: 0.7333333333, blue: 0.1058823529, alpha: 1)
            } else {
                clusterMarker.markerTintColor = #colorLiteral(red: 0, green: 0.8694628477, blue: 0.3590038419, alpha: 1) // same as ParkingSpotAnnotationView color
            }
            
            return clusterMarker
        case is ParkingLotAnnotation:
            return ParkingLotAnnotationView(annotation: annotation, reuseIdentifier: ParkingLotAnnotationView.reuseIdentifier)
        case is ParkingSpotAnnotation:
            return ParkingSpotAnnotationView(annotation: annotation, reuseIdentifier: ParkingSpotAnnotationView.reuseIdentifier)
        case is GateAnnotation:
            return GateAnnotationView(annotation: annotation, reuseIdentifier: GateAnnotationView.reuseIdentifier)
        case is MyCarAnnotation:
            return MyCarAnnotationView(annotation: annotation, reuseIdentifier: MyCarAnnotationView.reuseIdentifier)
        case is DestinationAnnotation:
            return DestinationAnnotationView(annotation: annotation, reuseIdentifier: DestinationAnnotationView.reuseIdentifier)
        default:
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        isAtBigZoom = mapView.region.span.latitudeDelta < 0.003
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        switch view {
        
        // TODO disable parking lot balloon inflation
        case is ParkingLotAnnotationView:
            let viewRegion = MKCoordinateRegion(center: view.annotation!.coordinate, latitudinalMeters: 400, longitudinalMeters: 400)
            map.setRegion(viewRegion, animated: true)
            get(parkingLot: (view.annotation as! ParkingLotAnnotation).parkingLot, completion: nil)
        case is GateAnnotationView:
            let viewRegion = MKCoordinateRegion(center: view.annotation!.coordinate, latitudinalMeters: 400, longitudinalMeters: 400)
            map.setRegion(viewRegion, animated: true)
            showGate(view: view)
        default:
            return
        }
    }
}

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // TODO use user new location
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            zoomToUserLocation()
        }
    }
    
    func zoomToUserLocation() {
        if let userLocation = locationManager.location?.coordinate {
            let viewRegion = MKCoordinateRegion(center: userLocation, latitudinalMeters: 800, longitudinalMeters: 800)
            map.setRegion(viewRegion, animated: false)
        }
    }
}

extension ViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            clearSearch()
            return
        }
        
        let gates = currentParkingLot?.search(query: searchText) ?? []
        
        for annotation in map.annotations {
            guard let gateAnnotation = annotation as? GateAnnotation else {
                continue
            }
            
            let view = map.view(for: gateAnnotation) as! MKMarkerAnnotationView
            let gateInResult = gates.contains { (curr) -> Bool in
                return curr == gateAnnotation.gate
            }
            if gateInResult {
                view.markerTintColor = GateAnnotationView.matchedColor
            }else{
                view.markerTintColor = GateAnnotationView.unmatchedColor
            }
        }
    }
    
    func clearSearch() {
//        self.view.endEditing(true)
        
//        currentParkingLot?.resetFilter()
        
        for annotation in map.annotations {
            guard let gateAnnotation = annotation as? GateAnnotation else {
                continue
            }
            
            let view = map.view(for: gateAnnotation) as! MKMarkerAnnotationView
            view.markerTintColor = GateAnnotationView.mainColor
        }
    }
}

extension ViewController: GateDelegate {
    func showGate(view: MKAnnotationView) {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "GateViewController") as! GateViewController
        controller.delegate = self
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1000)) {
            controller.gate = (view.annotation as! GateAnnotation).gate
            self.currentGateAnnotation = view.annotation as? GateAnnotation
        }
        
//        activeSheet = SheetViewController(
//            controller: controller,
//            sizes: [.percent(Float(186/self.view.frame.height)), .fullscreen],
//            options: SheetOptions(useFullScreenMode: false, useInlineMode: true))
//        activeSheet!.overlayColor = .clear
//        activeSheet!.cornerRadius = 16
//
//        activeSheet!.view.layer.shadowRadius = 4
//        activeSheet!.view.layer.shadowColor = UIColor.black.cgColor
//        activeSheet!.view.layer.shadowOpacity = 0.2
//        activeSheet!.view.layer.shadowOffset = CGSize(width: 0, height: -2)
        
        activeSheet = createSheet(controller: controller)
        
        activeSheet!.didDismiss = { _ in
            print("did dismiss")
            self.map.deselectAnnotation(view.annotation, animated: true)
            self.currentGateAnnotation = nil
        }
        
        activeSheet!.animateIn(to: self.view, in: self)
    }
    
    // TODO maybe better to subclass SheetViewController and implement this initialization in its init
    func createSheet(controller: UIViewController) -> SheetViewController {
        let newSheet = SheetViewController(
            controller: controller,
            sizes: [.percent(Float(186/self.view.frame.height)), .fullscreen],
            options: SheetOptions(useFullScreenMode: false, useInlineMode: true))
        newSheet.overlayColor = .clear
        newSheet.cornerRadius = 16
        
        newSheet.view.layer.shadowRadius = 4
        newSheet.view.layer.shadowColor = UIColor.black.cgColor
        newSheet.view.layer.shadowOpacity = 0.2
        newSheet.view.layer.shadowOffset = CGSize(width: 0, height: -2)
        
        return newSheet
    }
    
    func gate(_ gate: Gate, didReceive route: Route) {
        map.deselectAnnotation(currentGateAnnotation, animated: true)
        
        // drawing route
        let myPolyline = route.createPolyline()
//        let myPolyline = MKGeodesicPolyline(coordinates: &pointsToUse, count: route.points.count)
        map.addOverlay(myPolyline!, level: .aboveRoads)
        
        // hide current sheet (gate sheet)
        activeSheet?.animateOut()
        
        // show route sheet
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RouteViewController") as! RouteViewController
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1000)) {
            controller.route = route
        }
        activeSheet = createSheet(controller: controller)
        activeSheet!.sizes = [.percent(0.15)]
        activeSheet!.dismissOnOverlayTap = false
        activeSheet!.dismissOnPull = false
        activeSheet!.allowGestureThroughOverlay = true
        
        activeSheet!.didDismiss = { _ in
            print("did dismiss route sheet")
            
            // TODO also minimize target parking spot (it should be inflated)
            self.map.removeOverlay(route.polyline!)
            
            self.showRatingSheet(route: route)
        }
        
        activeSheet!.animateIn(to: self.view, in: self)
    }
    
    func showRatingSheet(route: Route) {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RatingViewController") as! RatingViewController
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime(uptimeNanoseconds: 1000)) {
            controller.route = route
        }
        activeSheet = createSheet(controller: controller)
        activeSheet!.sizes = [.percent(Float(186/self.view.frame.height))]
        activeSheet!.dismissOnOverlayTap = false
        activeSheet!.dismissOnPull = false
        activeSheet!.allowGestureThroughOverlay = false
        
        activeSheet!.didDismiss = { _ in
            print("did dismiss rating sheet")
            
            // user arrived and did rating
            self.currentParkingLot?.userSpot = route.parkingSpotID // the spot is occupied by the user now
            self.addMyCarAnnotation() // it uses the `userSpot` property on ParkingLot, so we don't have to pass anything
        }
        
        activeSheet!.animateIn(to: self.view, in: self)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay.isKind(of: MKPolyline.self) {
            // draw the track
            let polyLine = overlay
            let polyLineRenderer = MKPolylineRenderer(overlay: polyLine)
            polyLineRenderer.strokeColor = UIColor.blue
            polyLineRenderer.lineWidth = 2.0
            
            return polyLineRenderer
        }
        
        return MKPolylineRenderer()
    }
}


// MARK: - My Car
extension ViewController {
    @IBAction func findMyCar() {
        for i in 0..<parkingLots.count {
            let lot = parkingLots[i]
            if lot.userSpot != nil {
                get(parkingLot: lot) {
                    // zoom to my car
                    let viewRegion = MKCoordinateRegion(center: lot.myCarAnnotation!.coordinate, latitudinalMeters: 100, longitudinalMeters: 100)
                    self.map.setRegion(viewRegion, animated: true)
                }
                break
            }
            
            if i == parkingLots.count-1 {
                // no user park found
                alert(title: "Not found", message: "It seems you don't have a car parked with the app", completion: nil)
            }
        }
    }
}
