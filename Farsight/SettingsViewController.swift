//
//  SettingsViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 5/18/21.
//

import UIKit
import MapKit

protocol SettingsDelegate {
    func userAdded(user: TestingUser)
}

class SettingsViewController: UIViewController {
    
    @IBOutlet var fldCoords: UITextField!
    
    var delegate: SettingsDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    @IBAction func addUser() {
        var coords = fldCoords.text?.components(separatedBy: .whitespacesAndNewlines) ?? []
        coords[0] = coords[0].trimmingCharacters(in: CharacterSet.punctuationCharacters)
        coords[1] = coords[1].trimmingCharacters(in: CharacterSet.whitespaces)
        
        print("testing: adding user at \(coords[0]), \(coords[1])")
        
        let newUser = TestingUser(location: CLLocationCoordinate2D(latitude: Double(coords[0])!, longitude: Double(coords[1])!), color: .random())
        
        Global.testingUsers.append(newUser)
        
        delegate?.userAdded(user: newUser)
    }

}
