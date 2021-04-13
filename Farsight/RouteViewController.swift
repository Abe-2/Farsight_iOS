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
    
    @IBAction func arrived() {
        self.sheetViewController?.attemptDismiss(animated: true)
    }
    
}
