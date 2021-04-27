//
//  ViewController+SearchDelegate.swift
//  Farsight
//
//  Created by Abdalwahab on 4/27/21.
//

import UIKit
import MapKit


// MARK: - Search
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
