//
//  ViewController+MapDelegate.swift
//  Farsight
//
//  Created by Abdalwahab on 4/14/21.
//

import UIKit
import MapKit


extension ViewController: MKMapViewDelegate {
    
    func register() {
        map.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: ParkingSpotAnnotationView.clusteringReuseIdentifier)
        map.register(ParkingSpotAnnotationView.self, forAnnotationViewWithReuseIdentifier: ParkingSpotAnnotationView.reuseIdentifier)
        map.register(ParkingLotAnnotationView.self, forAnnotationViewWithReuseIdentifier: ParkingLotAnnotationView.reuseIdentifier)
        map.register(GateAnnotationView.self, forAnnotationViewWithReuseIdentifier: GateAnnotationView.reuseIdentifier)
        map.register(MyCarAnnotationView.self, forAnnotationViewWithReuseIdentifier: MyCarAnnotationView.reuseIdentifier)
    }
    
    // TODO the code here needs reorganization and cleaning
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // TODO make rest of cases follow this style
        if annotation is MKClusterAnnotation {
            return setupClusterAnnotation(for: annotation, on: map)
        }
        
        guard let identifier = identifierForAnnotation(annotation: annotation) else {
            return nil
        }
        
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
        
        if annotationView != nil {
            annotationView?.annotation = annotation
            if annotation is ParkingSpotAnnotation {
                (annotationView as! ParkingSpotAnnotationView).setClusteringIf(isAtBigZoom: isAtBigZoom)
            }
            
            return annotationView
        }
        
        switch annotation {
        case is ParkingLotAnnotation:
            return ParkingLotAnnotationView(annotation: annotation, reuseIdentifier: ParkingLotAnnotationView.reuseIdentifier)
        case is ParkingSpotAnnotation:
            let view = ParkingSpotAnnotationView(annotation: annotation, reuseIdentifier: ParkingSpotAnnotationView.reuseIdentifier)
            view.setClusteringIf(isAtBigZoom: isAtBigZoom)
            return view
        case is GateAnnotation:
            return GateAnnotationView(annotation: annotation, reuseIdentifier: GateAnnotationView.reuseIdentifier)
        case is MyCarAnnotation:
            return MyCarAnnotationView(annotation: annotation, reuseIdentifier: MyCarAnnotationView.reuseIdentifier)
        case is DestinationAnnotation:
            return DestinationAnnotationView(annotation: annotation, reuseIdentifier: DestinationAnnotationView.reuseIdentifier)
        case is MyCarAnnotation2:
            return MyCarAnnotationView2(annotation: annotation, reuseIdentifier: MyCarAnnotationView2.reuseIdentifier)
        default:
            return nil
        }
    }
    
    func identifierForAnnotation(annotation: MKAnnotation) -> String? {
        switch annotation {
        case is ParkingLotAnnotation:
            return ParkingLotAnnotationView.reuseIdentifier
        case is ParkingSpotAnnotation:
            return ParkingSpotAnnotationView.reuseIdentifier
        case is GateAnnotation:
            return GateAnnotationView.reuseIdentifier
        case is MyCarAnnotation:
            return MyCarAnnotationView.reuseIdentifier
        case is DestinationAnnotation:
            return DestinationAnnotationView.reuseIdentifier
        case is MyCarAnnotation2:
            return MyCarAnnotationView2.reuseIdentifier
        default:
            return nil
        }
    }
    
    func setupClusterAnnotation(for annotation: MKAnnotation, on map: MKMapView) -> MKAnnotationView {
        // only parking spots have a cluster
        // TODO move into annotations file
        var annotationView: MKMarkerAnnotationView! = map.dequeueReusableAnnotationView(withIdentifier: ParkingSpotAnnotationView.clusteringReuseIdentifier) as? MKMarkerAnnotationView
        
        if annotationView == nil {
            annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: ParkingSpotAnnotationView.clusteringReuseIdentifier)
        }
        
        annotationView.collisionMode = .rectangle
        
        // adjust size to determine how much annotations are clustered. Bigger size mean less clusters.
        annotationView.bounds = CGRect(origin: annotationView.bounds.origin, size: CGSize(width: 50, height: 50))
        
        annotationView.displayPriority = .defaultLow
//            clusterMarker.zPriority = .min
        annotationView.centerOffset = CGPoint(x: 0, y: -10) // Offset center point to animate better with marker annotations
        
        (annotation as! MKClusterAnnotation).title = "empty"
        annotationView.subtitleVisibility = MKFeatureVisibility.hidden
        
        let clusterAnnotation = annotation as! MKClusterAnnotation
        if clusterAnnotation.memberAnnotations.count < 5 {
            annotationView.markerTintColor = #colorLiteral(red: 0.7490196078, green: 0.1254901961, blue: 0.1843137255, alpha: 1)
        } else if clusterAnnotation.memberAnnotations.count < 30 {
            annotationView.markerTintColor = #colorLiteral(red: 0.9333333333, green: 0.7333333333, blue: 0.1058823529, alpha: 1)
        } else {
            annotationView.markerTintColor = #colorLiteral(red: 0, green: 0.8694628477, blue: 0.3590038419, alpha: 1) // same as ParkingSpotAnnotationView color
        }
        
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        isAtBigZoom = mapView.region.span.latitudeDelta < 0.002
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        switch view {
        
        // TODO disable parking lot balloon inflation
        case is ParkingLotAnnotationView:
            let viewRegion = MKCoordinateRegion(center: view.annotation!.coordinate, latitudinalMeters: 400, longitudinalMeters: 400)
            map.setRegion(viewRegion, animated: true)
            get(parkingLot: (view.annotation as! ParkingLotAnnotation).parkingLot, completion: nil)
        case is GateAnnotationView:
            if currentRoute != nil {
                // do nothing since we are currently following a route
                return
            }
            
            let viewRegion = MKCoordinateRegion(center: view.annotation!.coordinate, latitudinalMeters: 400, longitudinalMeters: 400)
            map.setRegion(viewRegion, animated: true)
            showGate(view: view)
        default:
            return
        }
    }
    
    func markSpotTaken(spotID: Int) {
        // find parking spot marker then change it to taken
        for annotation in map.annotations {
            guard let spotAnnotation = annotation as? ParkingSpotAnnotation else {
                continue
            }
            
            if spotAnnotation.parkingSpot.id == spotID {
                self.map.removeAnnotation(spotAnnotation)
                // we found the spot
                spotAnnotation.parkingSpot.occupied = true
//                let view = map.view(for: spotAnnotation) as! ParkingSpotAnnotationView
//                view.image = spotAnnotation.takenSpotImage
//                view.clusteringIdentifier = nil
                
                self.map.addAnnotation(spotAnnotation)
                break
            }
        }
    }
    
    func removeAnnotation(forSpot spot: ParkingSpot) {
        let spotAnnotation = spot.annotation != nil ? spot.annotation : spot.getAnnotation(map: map)
        if spotAnnotation != nil {
            self.map.removeAnnotation(spotAnnotation!)
            spot.annotation = nil
        }
    }
}
