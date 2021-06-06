//
//  ViewController+Testing.swift
//  Farsight
//
//  Created by Abdalwahab on 5/15/21.
//

import UIKit
import MapKit
import Alamofire


extension ViewController: SettingsDelegate {
    @IBAction func openSheet() {
        // show route sheet
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SettingsViewController") as! SettingsViewController
        
        controller.delegate = self
        
        activeSheet = createSheet(controller: controller)
        activeSheet!.sizes = [.percent(0.15)]
        activeSheet!.dismissOnOverlayTap = true
        activeSheet!.dismissOnPull = true
        activeSheet!.animateIn(to: self.view, in: self)
    }
    
    func userAdded(user: TestingUser) {
        addUserAnnotation(user: user)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.getSuggestion(user: user)
        }
    }
    
    func addUserAnnotation(user: TestingUser) {
        print("testing: adding user annotation")
        let pointCord = CLLocationCoordinate2D(latitude: user.location.latitude, longitude: user.location.longitude)
        let marker = UserAnnotation()
        marker.user = user
        user.annotation = marker
        marker.coordinate = pointCord
        map.addAnnotation(marker)
    }
    
    func removeUser(user: TestingUser) {
        print("testing: removing user")
        // clear path
        if user.route != nil {
//            handleSpotTestingClick(spot: user.route!.parkingSpot, occupied: true)
            self.markSpot(taken: true, spotID: user.route!.parkingSpotID)
            self.map.removeOverlay(user.route!.polyline!)
            user.route = nil
        }
        map.removeAnnotation(user.annotation!)
        Global.testingUsers.removeAll { curr_user in
            return curr_user.id == user.id
        }
    }
    
    func getSuggestion(user: TestingUser) {
        // remove old path, if any
        if user.route != nil {
            user.timer?.invalidate()
            self.map.removeOverlay(user.route!.polyline!)
            user.route = nil
            user.index = 0
        }
        
        print("testing: getting suggestion for user \(user.id)")
        
        self.loadingIndicator.isHidden = false
        self.loadingIndicator.startAnimating()
        
        let westGate = self.currentParkingLot?.gates?.first(where: { gate in
            return gate.id == 2
        })!
        
        let api = APIController()
        api.getSuggestion(for: westGate!, phone_id: user.id, location: user.location) { (route, error) in
            self.loadingIndicator.stopAnimating()
            guard error == nil else {
                // TODO this is bad. Do better
                print("testing: error occurred in suggestion")
                print(error)
                
                if error == "no spots found" {
                    print("testing: no spot found for user \(user.id)")
                    self.removeUser(user: user)
                }
                return
            }
            
            print("testing: got suggestion for user \(user.id)")
            
            user.route = route
            self.markSpot(taken: false, spotID: route!.parkingSpotID) // to change spot status to empty to allow re-routing
            
            let myPolyline = route!.createPolyline()
            self.map.addOverlay(myPolyline!)
            
            user.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.moveUser), userInfo: ["user": user], repeats: true)
        }
    }
    
    @objc func moveUser(sender: Timer) {
        guard let user = (sender.userInfo as! [String: TestingUser])["user"] else {
            print("testing: user not present in move user")
            return
        }
        
        print("testing: moving user \(user.id), index: \(user.index + 1)")
        
        user.location = (user.route?.points[user.index].coordinate)!
        user.annotation?.coordinate = user.location
        user.index += 1
        
//        sendLocation(user: user)
        
        if user.index == user.route?.points.count {
            // reached destination
            print("testing: user \(user.id) reached destination")
            
            sender.invalidate()
            
            // notify server that trip is finished and remove user
            let params = ["rating": 0]
            requestImmediate("/rating/\(user.route!.tripID)/", params: params, method: .post) { (payload, raw, error) in
//                sender.hideLoading()
                guard error == nil else {
                    // TODO handle error
                    print("testing: user \(user.id) failed to rate")
                    return
                }
                
                print("testing: user \(user.id) completed rating")
                self.removeUser(user: user)
            }
        }else{
            checkDidEnterStreet(user: user)
        }
    }
    
    func sendLocation(user: TestingUser) {
        let params = ["lat": user.location.latitude, "lon": user.location.longitude, "phone_id": user.id] as [String : Any]
        requestImmediate("/update-location/", params: params, method: .post) { (payload, raw, error) in
            if error != nil {
                print("testing: failed to send location")
                return
            }
            
            print("sent location")
        }
    }
    
    /// check if user entered new street. If he did, then inform server of the update
    func checkDidEnterStreet(user: TestingUser) {
        // check all motion sensors
        for sensor in self.motionSensors! {
            let targetLocation = CLLocation(latitude: sensor.location.latitude, longitude: sensor.location.longitude)
            let userLocation = CLLocation(latitude: user.location.latitude, longitude: user.location.longitude)
            
            let distance = targetLocation.distance(from: userLocation) // in meters
            
//            print("checking sensor \(sensor), distance: \(distance)")
            if distance < 1 {
                print("testing: did enter new street at sensor \(sensor.id)")
                requestImmediate("/sensor/update/", params: ["id": sensor.id, "is_reverse": false], method: .put, encoding: JSONEncoding.prettyPrinted)
                break
            }
        }
    }
    
    func testingSpotTaken(phone_id: String, spotID: Int) {
        for user in Global.testingUsers {
            guard let route = user.route else {
                continue
            }
            
            if route.parkingSpotID == spotID && phone_id != user.id {
                // spot taken by another user, so re-route testing user
                getSuggestion(user: user)
                break
            }
        }
        
        // if the spot is taken by a testing user we have, then we will mark it as open again in getSuggestion to allow clicking
        //  on the spot for re-routing. Reason we are opening it again in getSuggestion is because the socket message arrives before the
        //  suggestion
        markSpot(taken: true, spotID: spotID) // to change spot status
    }
    
    // MARK: - Sensors
    func getSensors() {
        print("testing: fetching motion sensors")
        requestImmediate("/sensor/") { payload, raw, error in
            guard error == nil else {
                // TODO handle error
                return
            }
            
            self.motionSensors = Sensor.decode(array: payload!.arrayValue)
            self.addSensors(sensors: self.motionSensors!)
        }
    }
    
    func addSensors(sensors: [Sensor]) {
        for sensor in sensors {
            let reportLocation = SensorAnnotation()
            reportLocation.sensor = sensor
            reportLocation.coordinate = sensor.location
            map.addAnnotation(reportLocation)
        }
    }
    
    func handleSensorClick(sensor: Sensor) {
        
        self.loadingIndicator.isHidden = false
        self.loadingIndicator.startAnimating()
        
        print(sensor.id)
        requestImmediate("/sensor/update/", params: ["id": sensor.id, "is_reverse": false], method: .put, encoding: JSONEncoding.prettyPrinted) { payload, raw, error in
            self.loadingIndicator.stopAnimating()
            guard error == nil else {
                print("testing: error occurred while updating a sensor")
                print(error)
                return
            }
            
        }
    }
}
