//
//  RouteViewController.swift
//  Farsight
//s
//  Created by Abdalwahab on 3/31/21.
//

import UIKit

class RouteViewController: UIViewController {
    
    @IBOutlet var lblTime: UILabel!
    @IBOutlet var lblDistance: UILabel!
    @IBOutlet var lblDestination: UILabel!
    
    @IBOutlet var viwRoute: UIView!
    @IBOutlet var viwSpotTaken: UIView!
    
    var delegate: RouteDelegate?
    
    var route: Route? = nil {
        didSet(oldValue) {
            lblTime.text = "\(route!.estimatedTime/60) min"
            lblDistance.text = "(\(route!.estimatedDistance) m)"
            lblDestination.text = route!.gate.name
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    func spotTaken() {
        // TODO should it also be marked taken?
        UIView.animate(withDuration: 0.2) {
            self.viwRoute.alpha = 0
        } completion: { done in
            self.viwRoute.isHidden = true
            self.viwSpotTaken.isHidden = false
            
            UIView.animate(withDuration: 0.2) {
                self.viwSpotTaken.alpha = 1
            }
        }
        
        let api = APIController()
        api.getSuggestion(for: self.route!.gate) { (route, error) in
            guard error == nil else {
                if error == "no spots found" {
                    self.delegate?.noRouteFound(closeSheet: true)
                }
                return
            }
            
            self.delegate?.didReceive(route: route!)
        }
    }
    
}
