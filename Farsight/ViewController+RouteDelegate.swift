//
//  ViewController+RouteDelegate.swift
//  Farsight
//
//  Created by Abdalwahab on 4/14/21.
//

import UIKit
import MapKit
import FittedSheets

protocol RouteDelegate {
    func didReceive(route: Route)
    func noRouteFound(closeSheet: Bool)
}

extension ViewController: RouteDelegate {
    func noRouteFound(closeSheet: Bool) {
        if closeSheet {
            self.activeSheet?.animateOut()
        }
        
        UIView.animate(withDuration: 0.3) {
            self.imgParkNameIcon.isHidden = false
            self.lblParkName.text = "No parking spot found"
            self.view.layoutIfNeeded()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            UIView.animate(withDuration: 0.3) {
                self.imgParkNameIcon.isHidden = true
                self.lblParkName.text = self.currentParkingLot?.name
                self.view.layoutIfNeeded()
            }
        }
    }
    
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
    
    // start a new route
    func didReceive(route: Route) {
        map.deselectAnnotation(currentGateAnnotation, animated: true)
        
        // drawing route
        let myPolyline = route.createPolyline()
        map.addOverlay(myPolyline!, level: .aboveRoads)
        
        // hide current sheet (can be gate sheet or route sheet)
        activeSheet?.animateOut()
        
        // show route sheet
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RouteViewController") as! RouteViewController
        controller.delegate = self
        
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
            
            // remove route, remove destination marker and add spot annotation back
            self.currentRoute = nil
            
            self.showRatingSheet(route: route)
        }
        
        activeSheet!.animateIn(to: self.view, in: self)
        
        // save route and show target
        currentRoute = route
        addDestinationAnnotation(to: route)
    }
    
    func addDestinationAnnotation(to route: Route) {
        print("adding destination annotation")
        print(route.parkingSpot)
        
        let pointCord = CLLocationCoordinate2D(latitude: route.parkingSpot.lat, longitude: route.parkingSpot.lon)
        let marker = DestinationAnnotation()
        marker.coordinate = pointCord
        marker.title = "Your spot"
        self.removeAnnotation(forSpot: route.parkingSpot) // will be added back when the user reaches their destination
        map.addAnnotation(marker)
        route.destinationAnnotation = marker

//        currentParkingLot!.myCarAnnotation = marker
    }
    
    func destinationReached() {
        // activeSheet should be route sheet at this point and dismissing it would trigger rating
        activeSheet?.attemptDismiss(animated: true)
    }
    
    // when user reaches his destination
    func showRatingSheet(route: Route) {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RatingViewController") as! RatingViewController
        controller.delegate = self
        
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
        if let road = overlay as? Road {
            let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
//            polyLineRenderer.strokeColor = UIColor.blue
            switch road.carCount {
            case 0...1:
                polyLineRenderer.strokeColor = .systemGreen
            case 2...2:
                polyLineRenderer.strokeColor = .systemYellow
            case 3...3:
                polyLineRenderer.strokeColor = .systemOrange
            case 4...1000:
                polyLineRenderer.strokeColor = .systemRed
            default:
                polyLineRenderer.strokeColor = .random()
            }
            polyLineRenderer.lineWidth = 2.0
            
            return polyLineRenderer
        }else if overlay.isKind(of: MKPolyline.self) {
            let polyLineRenderer = MKPolylineRenderer(overlay: overlay)
            polyLineRenderer.strokeColor = #colorLiteral(red: 0.2901960784, green: 0.6392156863, blue: 0.9725490196, alpha: 1)
//            polyLineRenderer.strokeColor = .random()
            polyLineRenderer.lineWidth = 6.0
            
            return polyLineRenderer
        }
        
        return MKPolylineRenderer()
    }
}

extension CGFloat {
    static func random() -> CGFloat {
        return CGFloat(arc4random()) / CGFloat(UInt32.max)
    }
}

extension UIColor {
    static func random() -> UIColor {
        return UIColor(
           red:   .random(),
           green: .random(),
           blue:  .random(),
           alpha: 1.0
        )
    }
}
