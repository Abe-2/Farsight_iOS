//
//  ViewController+Traffic.swift
//  Farsight
//
//  Created by Abdalwahab on 5/19/21.
//

import UIKit
import MapKit

extension ViewController {
    
    func getTraffic() {
        print("fetching traffic data")
        requestImmediate("/geo-json/") { payload, raw, error in
            guard error == nil else {
                // TODO handle error
                return
            }
            
            do {
                let overlays = try self.parseTrafficGeoJson(data: payload!.rawData())
                self.map.addOverlays(overlays)
            } catch let e {
                print("failed to parse traffic")
                print(e)
            }
        }
    }
    
    fileprivate func parseTrafficGeoJson(data: Data) -> [MKOverlay] {
        var geojson = [MKGeoJSONObject]()
        do {
            geojson = try MKGeoJSONDecoder().decode(data)
        } catch let e {
            print(e)
            print("failed to decode geojson")
        }
        
        var overlays = [MKOverlay]()
        self.currentParkingLot?.trafficRoads = []
        
        for item in geojson {
            if let feature = item as?MKGeoJSONFeature {
//                print(feature.identifier) // TODO change id to string from server instead of int for this to work
                
                var properties = [String:Any]()
                do {
                    properties = try JSONSerialization.jsonObject(with: feature.properties!, options: []) as! [String:Any]
                } catch {
                    print("skip")
                }

                for geo in feature.geometry {
                    if let road = geo as? MKPolyline {
                        let newRoad = Road(points: road.points(), count: road.pointCount)
                        newRoad.id = String(properties["osmIdentifier"] as! Int)
                        newRoad.carCount = properties["num_cars"] as? Int ?? 0
                        self.currentParkingLot?.trafficRoads?.append(newRoad)
                        
                        overlays.append(newRoad)
                    }
                }
            }
        }
        
        return overlays
    }
    
    func streetChangedHandle(streetID: String, newCarCount: Int) {
        guard let roads =  self.currentParkingLot!.trafficRoads else {
            return
        }
        
        print(streetID)
        for road in roads {
            if road.id == streetID {
                self.map.removeOverlay(road)
                road.carCount = newCarCount
                self.map.addOverlay(road, level: .aboveRoads)
                
                return
            }
        }
        
        print("did not find street")
    }
}
