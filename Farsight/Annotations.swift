//
//  Annotations.swift
//  Farsight
//
//  Created by Abdalwahab on 1/13/21.
//

import Foundation
import MapKit

// MARK: - parking lot
class ParkingLotAnnotation: MKPointAnnotation {
    var parkingLot: ParkingLot! // TODO make part of constructor
}

class ParkingLotAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = "ParkingLotAnnotation"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .required
        markerTintColor = #colorLiteral(red: 0.2392156863, green: 0.662745098, blue: 0.9725490196, alpha: 1)
        glyphImage = UIImage(systemName: "p.circle")
    }
}


// MARK: - parking spot
class ParkingSpotAnnotation: MKPointAnnotation {
    var parkingSpot: ParkingSpot! // TODO make part of constructor
    let emptySpotImage = UIImage(named: "empty")
    let takenSpotImage = UIImage(named: "taken")
}

class ParkingSpotAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "ParkingSpotAnnotation"
    static let clusteringIdentifier = "ParkingSpotCluster"
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
//        if (annotation as! ParkingSpotAnnotation).parkingSpot.occupied == false {
//            clusteringIdentifier = ParkingSpotAnnotationView.clusteringIdentifier
//        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        
//        alpha = 0 // initially hidden and shown when we zoom in
        
        if (annotation as! ParkingSpotAnnotation).parkingSpot.occupied {
            displayPriority = .defaultLow
            image = (annotation as! ParkingSpotAnnotation).takenSpotImage
        }else{
            displayPriority = .defaultLow
            image = (annotation as! ParkingSpotAnnotation).emptySpotImage
        }
    }
    
    func setClusteringIf(isAtBigZoom: Bool) {
        if isAtBigZoom {
            alpha = 1
            clusteringIdentifier = nil
        }else{
            alpha = 0
            if (annotation as! ParkingSpotAnnotation).parkingSpot.occupied == false {
                clusteringIdentifier = ParkingSpotAnnotationView.clusteringIdentifier
            }
        }
    }
}


// MARK: - gate
class GateAnnotation: MKPointAnnotation {
    var gate: Gate! // TODO make part of constructor
}

class GateAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = "GateAnnotation"
    static let mainColor = #colorLiteral(red: 0.09019607843, green: 0.5058823529, blue: 0.9215686275, alpha: 1)
    static let matchedColor = #colorLiteral(red: 0.9725490196, green: 0.7647058824, blue: 0.07058823529, alpha: 1)
    static let unmatchedColor = #colorLiteral(red: 0.7096650004, green: 0.7096650004, blue: 0.7096650004, alpha: 1)
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        
//        clusteringIdentifier = "ParkingSpotCluster"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .required
        markerTintColor = GateAnnotationView.mainColor
        glyphImage = UIImage(systemName: "figure.walk")
    }
}


// MARK: - my car
class MyCarAnnotation: MKPointAnnotation {
    
}

class MyCarAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = "MyCarAnnotation"
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .required
        markerTintColor = #colorLiteral(red: 0.6941176471, green: 0.3019607843, blue: 0.9803921569, alpha: 1)
        glyphImage = UIImage(systemName: "car.fill")
    }
}


// MARK: - destionation
class DestinationAnnotation: MKPointAnnotation {
    
}

class DestinationAnnotationView: MKMarkerAnnotationView {
    static let reuseIdentifier = "DestinationAnnotation"
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .required
        markerTintColor = #colorLiteral(red: 1, green: 0.2595997751, blue: 0.3398093581, alpha: 1)
        glyphImage = UIImage(systemName: "flag.fill")
    }
}




class MyCarAnnotation2: MKPointAnnotation {
    
}

class MyCarAnnotationView2: MKMarkerAnnotationView {
    static let reuseIdentifier = "MyCarAnnotation2"
    
    override func prepareForDisplay() {
        super.prepareForDisplay()
        displayPriority = .required
        markerTintColor = #colorLiteral(red: 0.8549019694, green: 0.250980407, blue: 0.4784313738, alpha: 1)
        glyphImage = UIImage(systemName: "car.fill")
    }
}
