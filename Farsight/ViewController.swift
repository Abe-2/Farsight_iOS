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


// - cycle 3:
// TODO target parking spot
// TODO sending user location
// TODO re-route if no is selected
// TODO multiple users simulations
// TODO leaving parking spot endpoint
// TODO selecting many parking spots
// TODO marking a single parking spot as taken
// TODO re-route if spot is taken
// TODO show no spot found if get suggestion returns 404
// TODO clean database from fake users and free up spots

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
    
    @IBOutlet var occupancyHolder: UIView!
    @IBOutlet var lblOccupancyRate: UILabel!
    
    var parkingLots = [ParkingLot]()
    var currentParkingLot: ParkingLot? = nil
    var currentRoute: Route? // only if we got suggestion
    
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
    var myCarSimulation: MyCarAnnotation2!
    var simulationTimer: Timer!
    var index = 0
    let locations = [
        CLLocationCoordinate2D(latitude: 29.272062, longitude: 48.052245),
        CLLocationCoordinate2D(latitude: 29.272146, longitude: 48.052158),
        CLLocationCoordinate2D(latitude: 29.272243, longitude: 48.052097),
        CLLocationCoordinate2D(latitude: 29.272343, longitude: 48.052055),
        CLLocationCoordinate2D(latitude: 29.272453, longitude: 48.052039),
        CLLocationCoordinate2D(latitude: 29.272513, longitude: 48.052105),
        CLLocationCoordinate2D(latitude: 29.272547, longitude: 48.052207),
        CLLocationCoordinate2D(latitude: 29.272524, longitude: 48.052314),
        CLLocationCoordinate2D(latitude: 29.272429, longitude: 48.052356),
        CLLocationCoordinate2D(latitude: 29.272352, longitude: 48.052386),
        CLLocationCoordinate2D(latitude: 29.272271, longitude: 48.052414),
        CLLocationCoordinate2D(latitude: 29.272219, longitude: 48.052479),
        CLLocationCoordinate2D(latitude: 29.272249, longitude: 48.052611),
        CLLocationCoordinate2D(latitude: 29.272296, longitude: 48.052713),
        CLLocationCoordinate2D(latitude: 29.272332, longitude: 48.052838),
        CLLocationCoordinate2D(latitude: 29.272390, longitude: 48.052975),
        CLLocationCoordinate2D(latitude: 29.272437, longitude: 48.053089),
        CLLocationCoordinate2D(latitude: 29.272500, longitude: 48.053107),
        CLLocationCoordinate2D(latitude: 29.272598, longitude: 48.053078),
        CLLocationCoordinate2D(latitude: 29.272700, longitude: 48.053035),
        CLLocationCoordinate2D(latitude: 29.272816, longitude: 48.052994),
        CLLocationCoordinate2D(latitude: 29.272785, longitude: 48.053003),
        CLLocationCoordinate2D(latitude: 29.272942, longitude: 48.052946),
        CLLocationCoordinate2D(latitude: 29.272942, longitude: 48.052946),
    ]
    
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
        
        requestImmediate("/lot/\(parkingLot.id)") { (payload, raw, error) in
            if error != nil {
                // TODO handle error
            }

            parkingLot.gates = Gate.decode(array: payload!["gates"].arrayValue)
            parkingLot.parkingSpots = ParkingSpot.decode(array: payload!["parking_spots"].arrayValue)
            self.select(parkingLot: parkingLot)
            completion?()
            
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
            let pointCord = CLLocationCoordinate2D(latitude: spot.lat, longitude: spot.lon)
            let marker = ParkingSpotAnnotation()
            
            // keep a reference on both directions
            marker.parkingSpot = spot
            spot.annotation = marker
            
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
    
    @IBAction func startSimulation() {
        index = 0
        let pointCord = CLLocationCoordinate2D(latitude: locations[index].latitude, longitude: locations[index].longitude)
        index += 1
        
        myCarSimulation = MyCarAnnotation2()
        myCarSimulation.coordinate = pointCord
        map.addAnnotation(myCarSimulation)
        
        simulationTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateSimulation), userInfo: nil, repeats: true)
    }
    
    @objc func updateSimulation() {
        let pointCord = CLLocationCoordinate2D(latitude: locations[index].latitude, longitude: locations[index].longitude)
        myCarSimulation.coordinate = pointCord
        
        if index == locations.count - 1 {
            simulationTimer.invalidate()
        }
        
        index += 1
        
        if currentRoute != nil {
            print(currentRoute?.parkingSpotID)
            // we have a route so we need to check our distance to the target
            // get spot coords
            for spot in currentParkingLot!.parkingSpots! {
                if spot.id == currentRoute?.parkingSpotID {
                    // found the spot. Check distance to it
                    let targetLocation = CLLocation(latitude: spot.lat, longitude: spot.lon)
                    let userLocation = CLLocation(latitude: pointCord.latitude, longitude: pointCord.longitude)
                    
                    let distance = targetLocation.distance(from: userLocation) // in meters
                    
                    print(distance)
                    
                    if distance < 10 {
                        self.destinationReached()
                        simulationTimer.invalidate()
                        return
                    }
                    
                    break
                }
            }
            
        }
    }
}


// MARK: - Location manager
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

// MARK: - Sockets
extension ViewController: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
            case .connected(let headers):
                isConnected = true
                print("websocket is connected: \(headers)")
                
                // send auth
                let data = [
                    "action": "auth",
                    "phone_id": Global.phoneID
                ]
                self.send(data, onSuccess: nil)
            case .disconnected(let reason, let code):
                isConnected = false
                print("websocket is disconnected: \(reason) with code: \(code)")
            case .text(let string):
                print("Received text: \(string)")
//                receive(message: self.convertToDictionary(text: string)!)
                receive(message: JSON(string.data(using: .utf8)))
            case .binary(let data):
                print("Received data: \(data.count)")
            case .ping(_):
                break
            case .pong(_):
                break
            case .viabilityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                isConnected = false
            case .error(let error):
                isConnected = false
                print(error.publisher)
                // TODO handle error
            }
    }
    
    func receive(message: JSON) {
        
        switch message["event"].stringValue {
        case "parking_spots":
            print(message["data"])
            
        case "parking_spot_taken":
            print("spot taken \(message["data"])")
            // Check if the taken parking spot is mine or not.
            //  If yes, then check phone, if same, ignore, otherwise re-route
            //  Also, change parking spot status
            guard let spotID = message["data"]["id"].int else {
                return
            }
            
            // check if it is our spot, if any
            if let route = currentRoute {
                if route.parkingSpotID == spotID && message["data"]["phone_id"].stringValue != Global.phoneID {
                    // taken spot is our spot and its someone else who took it
                    // TODO re-route
                }else{
                    // ignore since we took our spot
                }
            }else{
                // mark spot as taken
                self.markSpotTaken(spotID: spotID)
            }
            
        default:
            break
        }
        
    }
    
    func send(_ value: Any, onSuccess: (()-> Void)?) {
        
        guard JSONSerialization.isValidJSONObject(value) else {
            print("[WEBSOCKET] Value is not a valid JSON object.\n \(value)")
            return
        }
        
        print("sending socket message")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: value, options: [])
            print(String(decoding: data, as: UTF8.self))
            socket.write(string: String(decoding: data, as: UTF8.self)) {
                onSuccess?()
            }
        } catch let error {
            print("[WEBSOCKET] Error serializing JSON:\n\(error)")
        }
    }
    
    
}
