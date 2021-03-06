//
//  ParkingLot.swift
//  Farsight
//
//  Created by Abdalwahab on 1/12/21.
//

import Foundation
import SwiftyJSON
import CoreLocation
import MapKit

class ParkingLot: Codable {
    var id: Int
    var name: String
    var lat: Double
    var lon: Double
    var totalSpots: Int
    var occupiedSpots: Int
    
    var gates: [Gate]? {
        didSet {
            var places = [Place]()
            for gate in self.gates! {
                places.append(contentsOf: gate.places)
            }
            allPlaces = places
//            filteredPlaces = allPlaces
        }
    }
    var allPlaces: [Place]? // used for search
//    var filteredPlaces: [Place]? // used for search
    
    var parkingSpots: [ParkingSpot]?
    
    var users: [User]?  // for testing
    
    var userSpot: Int?
    var myCarAnnotation: MyCarAnnotation?
    
    var trafficRoads: [Road]?
    
    enum CodingKeys:String,CodingKey {
        case id = "id"
        case name = "name"
        case lat = "latitude"
        case lon = "longitude"
        case totalSpots = "number_of_spots"
        case occupiedSpots = "occupied_spots"
        case userSpot = "user_spot"
    }
    
    static func decode(array: [JSON]) -> [ParkingLot] {
        var ret = [ParkingLot]()
        for object in array {
            do {
                let jsonData = try object.rawData()
                ret.append(try JSONDecoder().decode(ParkingLot.self, from: jsonData))
            } catch let error {
                print(error)
            }
        }
        return ret
    }
    
    func search(query: String) -> [Gate] {
        var res = [Gate]()
        for gate in gates! {
            if gate.places.contains { place -> Bool in
                let predicate = NSPredicate(format: "SELF CONTAINS[cd] %@", query)
                print(place.name)
                print(predicate.evaluate(with: place.name))
                return predicate.evaluate(with: place.name)
            } {
                res.append(gate)
            }
        }
        
        return res
    }
    
//    func resetFilter() {
//        filteredPlaces = allPlaces
//    }
}

class Gate: Codable, Equatable {
    var id: Int
    var name: String
    var lon: Double
    var lat: Double
    
    var parkingLot: ParkingLot!
    var places: [Place]
    
    static var typesOrder = ["restaurant", "shopping", "utilities"] // used to make sure sections are displayed in the order in this array
    var placesPerType: [String:[Place]] = ["restaurant":[], "shopping":[], "utilities":[]]
    var nonEmptyTypesCount: Int {
        get {
            var count = 0
            placesPerType.forEach { (key: String, value: [Place]) in
                count += value.count != 0 ? 1 : 0
            }
            return count
        }
    }
    
    enum CodingKeys:String,CodingKey {
        case id = "id"
        case name = "name"
        case lat = "latitude"
        case lon = "longitude"
        case places = "places"
    }
    
    static func == (lhs: Gate, rhs: Gate) -> Bool {
        return lhs.id == rhs.id
    }
    
    static func decode(array: [JSON], lot: ParkingLot) -> [Gate]? {
        var ret = [Gate]()
        for object in array {
            do {
                let jsonData = try object.rawData()
                let gate = try JSONDecoder().decode(Gate.self, from: jsonData)
                ret.append(gate)
                gate.parkingLot = lot
                Gate.categorizePlaces(gate: gate)
            } catch let error {
                print(error)
                return nil
            }
        }
        return ret
    }
    
    static func categorizePlaces(gate: Gate) {
        for place in gate.places {
            print(place.type)
            gate.placesPerType[place.type]?.append(place)
        }
    }
    
    func availableTypeAt(index: Int) -> String {
        var i = index
        for type in Gate.typesOrder {
            if placesPerType[type]?.count != 0 {
                // type isn't empty...
                i -= 1
            }
            
            if i == -1 {
                return type
            }
        }
        
        return "" // TODO shouldn't happen, throw error
    }
}

class Place: Codable {
    var id: Int
    var name: String
    var logo: Image
    var type: String
}

class Image: Codable {
    var id: Int
    var path: String
}

// MARK: - Route
class ParkingSpot: Codable {
    var id: Int
    var occupied: Bool
    var lon: Double
    var lat: Double
    
    var annotation: ParkingSpotAnnotation?
    
    enum CodingKeys:String,CodingKey {
        case id = "id"
        case occupied = "occupied"
        case lat = "latitude"
        case lon = "longitude"
    }
    
    static func decode(array: [JSON]) -> [ParkingSpot] {
        var ret = [ParkingSpot]()
        for object in array {
            do {
                let jsonData = try object.rawData()
                ret.append(try JSONDecoder().decode(ParkingSpot.self, from: jsonData))
            } catch let error {
                print(error)
            }
        }
        return ret
    }
    
    // used in case `annotation` is not set
    func getAnnotation(map: MKMapView) -> ParkingSpotAnnotation? {
        for annotation in map.annotations {
            guard let spotAnnotation = annotation as? ParkingSpotAnnotation else {
                continue
            }
            
            if spotAnnotation.parkingSpot.id == self.id {
                self.annotation = spotAnnotation
                return spotAnnotation
            }
        }
        
        return nil // should
    }
}

// MARK: - Route
class Route: Codable {
    var tripID: Int
    var parkingSpotID: Int
    var points: [CLLocation] = []
    var polyline: MKPolyline?
    
    var estimatedTime = 120 // in seconds // this should be returned from server
    var estimatedDistance = 500 // in meters // this should be returned from server
    
    var gate: Gate!
    
    var parkingSpot: ParkingSpot!
    var destinationAnnotation: DestinationAnnotation?
    
    enum CodingKeys:String,CodingKey {
        case tripID = "trip_id"
        case parkingSpotID = "parking_spot_id"
    }
    
    // TODO this is bad. We should consider custom key coding strategy
    func decodePath(jsonArray: [JSON]) {
        points = []
        for obj in jsonArray {
            let point = CLLocation(latitude: obj["latitude"].doubleValue, longitude: obj["longitude"].doubleValue)
            points.append(point)
        }
    }
    
    func createPolyline() -> MKPolyline? {
        if points.count == 0 {
            // TODO handle error
            return nil
        }
        var pointsToUse: [CLLocationCoordinate2D] = points.map { (location) -> CLLocationCoordinate2D in
            return location.coordinate
        }
        
        let polyline = MKPolyline(coordinates: &pointsToUse, count: points.count)
        self.polyline = polyline // needed so we can remove the path later

        return polyline
    }
    
    func getParkingSpot() -> ParkingSpot? {
        for spot in gate.parkingLot.parkingSpots! {
            if spot.id == self.parkingSpotID {
                // found the spot. Save it
                self.parkingSpot = spot
                return spot
            }
        }
        
        return nil // TODO should never happen, throw error
    }
}



// MARK: for testing
class User: Codable {
    var lon: Double
    var lat: Double
    
//    enum CodingKeys:String,CodingKey {
//        case id = "id"
//        case occupied = "occupied"
//        case lat = "latitude"
//        case lon = "longitude"
//    }
    
    static func decode(array: [JSON]) -> [User] {
        var ret = [User]()
        for object in array {
            do {
                let jsonData = try object.rawData()
                ret.append(try JSONDecoder().decode(User.self, from: jsonData))
            } catch let error {
                print(error)
            }
        }
        return ret
    }
}


class Road: MKPolyline {
    var id: String!
    var carCount: Int = 0
    
//    internal init(id: String, carCount: Int, polyline: MKPolyline) {
//        self.id = id
//        self.carCount = carCount
//        self.polyline = polyline
//    }
}


class Sensor: Codable {
    var id: Int
    var lat: Double
    var lon: Double
    var location: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2D(latitude: self.lat, longitude: self.lon)
        }
    }
    var inStreet: Int
    var inStreet_string: String {
        get {
            return String(inStreet)
        }
    }
    
    var outStreet: Int
    var outStreet_string: String {
        get {
            return String(outStreet)
        }
    }
    
    enum CodingKeys:String,CodingKey {
        case id = "id"
        case lat = "latitude"
        case lon = "longitude"
        case inStreet = "in_street"
        case outStreet = "out_street"
    }
    
    static func decode(array: [JSON]) -> [Sensor] {
        var ret = [Sensor]()
        for object in array {
            do {
                let jsonData = try object.rawData()
                ret.append(try JSONDecoder().decode(Sensor.self, from: jsonData))
            } catch let error {
                print(error)
            }
        }
        return ret
    }
}


class TestingUser {
    var id: String
    var location: CLLocationCoordinate2D
    var color: UIColor
    
    var annotation: UserAnnotation?
    
    var route: Route?
    var timer: Timer?
    var index = 0
    
    internal init(location: CLLocationCoordinate2D, color: UIColor) {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        self.id = String((0..<10).map{ _ in letters.randomElement()! })
        self.location = location
        self.color = color
    }
}
