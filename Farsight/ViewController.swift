//
//  ViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 1/12/21.
//

import UIKit
import MapKit
import FittedSheets
import SwiftyJSON
import Starscream
import Alamofire


// - cycle 3:
// --TODO marking a single parking spot as taken
// --TODO re-route if spot is taken
// --TODO show no spot found if get suggestion returns 404

// - cycle 5:
// --TODO add more midpoints to map to temp fix destination path issue
// --TODO get other users on the map
// --TODO add direction to roads in the many parking area besides faculty parking in gust map
// --TODO showing roads traffic
// --TODO listening to changes in traffic data
// --TODO fetch all motion sensors from server
// --TODO show the hidden motion sensor because of being too close to another sensor
// --TODO motion sensor simulation based on user movements
// --TODO moving user route above traffic
// --TODO connecting faculty spots
// --TODO fixing single user target location and path bug
// --TODO fixing the bug where spots are routed to from another street than the one they are connected to. It wasn't a bug. It was just missing points
// --TODO showing routes of many users
// --TODO simulation setting sheet
// --TODO simulating user movements based on path.
// --TODO testing user park taken
// TODO change user current_parking_lot when they get suggestion
// --TODO hide my car in testing mode

// - abandoned
// TODO sending user location. Not needed currently as its not being used anywhere
// TODO change glyph image instead of adding a destination annotation. Will cause issues when considering zooming out and clustering
// TODO leaving parking spot endpoint -- There isn't such endpoint as we can't get this info. This is decided by the server when a park becomes empty and it previously has a user

// - extra
// TODO predicating when user is going to their car feature
// TODO pre-selecting a parking lot when the user is close to its boundaries
// TODO auto-complete for search

// - improvements
// TODO loading indicator when loading parking lots
// TODO remove the selection box on user location button
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
    @IBOutlet var imgParkNameIcon: UIImageView!
    
    @IBOutlet var occupancyHolder: UIView!
    @IBOutlet var lblOccupancyRate: UILabel!
    
    var parkingLots = [ParkingLot]()
    var currentParkingLot: ParkingLot? = nil
    
    // only if we got suggestion
    // marked nil when user reaches destination
    var currentRoute: Route? {
        didSet {
            if oldValue != nil {
                self.map.removeOverlay(oldValue!.polyline!)
                self.map.removeAnnotation(oldValue!.destinationAnnotation!)
                self.addSpotAnnotation(spot: oldValue!.parkingSpot)
            }
        }
    }
    
    var currentGateAnnotation: GateAnnotation? = nil
    var activeSheet: SheetViewController? = nil
    
    let locationManager = CLLocationManager()
    
    // for socket
    var socket: WebSocket!
    var isConnected = false
    
    // when at big zoom, display occupied spots pins
    var isAtBigZoom = false {
        didSet {
            // this guard ensures, that the showing and hiding happens only once
            guard oldValue != isAtBigZoom else {
                return
            }
            
            print("changing zoom")
            
            // refresh parking spots annotations
            let annotations = self.map.annotations
            let parkingAnnotations = annotations.filter({ (annotation) -> Bool in
                return annotation is ParkingSpotAnnotation
            })
            self.map.removeAnnotations(parkingAnnotations)
            self.map.addAnnotations(parkingAnnotations)
        }
    }
    
    // for testing
    @IBOutlet var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet var btnSetting: UIButton!
    
    var motionSensors: [Sensor]?
    
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
        
//        requestImmediate("/reset-parking-lot/") { (payload, raw, error) in
//            if error != nil {
//                print("testing: failed to reset")
//                return
//            }
//
//            print("testing: resetted")
//        }
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
        print(Global.phoneID)
        requestImmediate("/lot/", params: ["user_id": Global.phoneID]) { (payload, raw, error) in
            if error != nil {
                // TODO handle error
            }
            
            self.parkingLots = ParkingLot.decode(array: payload!.arrayValue)
            self.placeParkingLots()
            
            self.socket = self.connect()
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
        
        let params: [String:String]?
        if Global.TestingMode {
            params = nil
        }else{
            params = ["phone_id": Global.phoneID]
        }
        
        requestImmediate("/lot/\(parkingLot.id)/", params: params, method: .post) { (payload, raw, error) in
            if error != nil {
                // TODO handle error
            }
            
            parkingLot.gates = Gate.decode(array: payload!["gates"].arrayValue, lot: parkingLot)
            parkingLot.parkingSpots = ParkingSpot.decode(array: payload!["parking_spots"].arrayValue)
            parkingLot.users = User.decode(array: payload!["user_locations"].arrayValue)
            self.select(parkingLot: parkingLot)
            completion?()
            
            // get traffic data
            self.getTraffic()
            
            if Global.TestingMode {
                self.getSensors()
            }
            
            // subscribe to the parking lot
            let data: [String : Any] = [
                "action": "subscribe",
                "parking_lot_id": parkingLot.id
            ]
            self.send(data, onSuccess: nil)
        }
        //        if completion != nil {
        //            // TODO this is kept for my car because I couldn't find a clean way to do it with sockets
        //            requestImmediate("/lot/\(parkingLot.id)") { (payload, raw, error) in
        //                if error != nil {
        //                    // TODO handle error
        //                }
        //
        //                parkingLot.gates = Gate.decode(array: payload!["gates"].arrayValue)
        //                parkingLot.parkingSpots = ParkingSpot.decode(array: payload!["parking_spots"].arrayValue)
        //                self.select(parkingLot: parkingLot)
        //                completion?()
        //            }
        //        }else{
        //            if isConnected {
        //                // subscribe to the parking lot
        //                let data: [String : Any] = [
        //                    "action": "subscribe",
        //                    "parking_lot_id": parkingLot.id
        //                ]
        //                self.send(data, onSuccess: nil)
        //            }
        //        }
        
    }
    
    // This should not be called directly. It should only be called from get(parkingLot)
    func select(parkingLot: ParkingLot) {
        if currentParkingLot != nil && currentParkingLot?.id != parkingLot.id {
            deselectCurrentParkingLot()
        }
        currentParkingLot = parkingLot
        showParkingLotControls(forPark: parkingLot)
        
        for spot in parkingLot.parkingSpots! {
            addSpotAnnotation(spot: spot)
        }
        
        for gate in parkingLot.gates! {
            addGateAnnotation(gate: gate)
        }
        
//        for user in parkingLot.users! {
//            addUserAnnotation(user: user)
//        }
        
        addMyCarAnnotation()
    }
    
    func addSpotAnnotation(spot: ParkingSpot) {
        let pointCord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
        let marker = ParkingSpotAnnotation()
        
        // keep a reference on both directions
        marker.parkingSpot = spot
        spot.annotation = marker
        
        marker.coordinate = pointCord
        map.addAnnotation(marker)
    }
    
    func addGateAnnotation(gate: Gate) {
        let pointCord = CLLocationCoordinate2D(latitude: gate.lat, longitude: gate.lon)
        let marker = GateAnnotation()
        marker.gate = gate
        marker.coordinate = pointCord
        marker.title = gate.name
        map.addAnnotation(marker)
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
    
    func showParkingLotControls(forPark parkingLot: ParkingLot) {
        if Global.TestingMode {
            btnSetting.isHidden = false
        }
        
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


// MARK: - Location manager
extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // TODO use user new location
        self.activeSheet?.attemptDismiss(animated: true)
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
