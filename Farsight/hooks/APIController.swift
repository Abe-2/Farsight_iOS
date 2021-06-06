//
//  API.swift
//  Farsight
//
//  Created by Abdalwahab on 4/28/21.
//

import Foundation
import MapKit


class APIController {
    func getSuggestion(for gate: Gate, phone_id: String = Global.phoneID, location: CLLocationCoordinate2D? = nil, completionHandler: @escaping (_ route: Route?, _ errorMessage: String?) -> Void) {
        var userLocation: CLLocationCoordinate2D!
        if location == nil {
            guard let deviceLocation = Global.locationManager.location?.coordinate else {
                print("can't get user location")
                completionHandler(nil, "can't get user location")
                return
            }
            
            userLocation = deviceLocation
        }else{
            userLocation = location
        }
        
//        completionHandler(nil, "no spots found")
//        return
        
        let params = ["lat": userLocation.latitude, "lon": userLocation.longitude, "phone_id": phone_id] as [String : Any]
        
        requestImmediate("/suggestion/\(gate.id)/", params: params, method: .post) { (payload, raw, error) in
            guard error == nil, let payload = payload else {
                // TODO handle error
                print(error!)
                
                if raw?.response?.statusCode == 404 {
                    completionHandler(nil, "no spots found")
                }else{
                    completionHandler(nil, "error happened in suggestion")
                }
                
                return
            }
            
            print("the suggestion:")
            print(payload)
            
            var route: Route!
            
            do {
                let jsonData = try payload.rawData()
                route = try JSONDecoder().decode(Route.self, from: jsonData)
                route.decodePath(jsonArray: payload["route"].arrayValue)
                route.gate = gate
                route.getParkingSpot()
            } catch let error {
                // TODO handle error
                print(error)
            }
            
            completionHandler(route, error)
        }
    }
}
