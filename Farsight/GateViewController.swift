//
//  GateViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 3/16/21.
//

import UIKit
import FittedSheets
import AlamofireImage
import SkeletonView
import CoreLocation
import SwiftyJSON

protocol GateDelegate {
    func gate(_ gate: Gate, didReceive route: Route)
}

class GateViewController: UIViewController {
    
    @IBOutlet var table: UITableView!
    @IBOutlet var lblTitle: UILabel!
    @IBOutlet var lblDistance: UILabel!
    
    var delegate: GateDelegate?
    
    let locationManager = CLLocationManager()
    
    var gate: Gate? = nil {
        didSet(oldValue) {
            table.reloadData();
            lblTitle.text = gate?.name
            lblDistance.text = "(120 m)"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sheetViewController?.handleScrollView(self.table)
        self.table.register(PlacesSectionHeaderView.self, forHeaderFooterViewReuseIdentifier: PlacesSectionHeaderView.reuseIdentifier)
    }
    
    @IBAction func closeTapped(_ sender: Any) {
        self.sheetViewController?.attemptDismiss(animated: true)
    }
    
    @IBAction func suggestionTapped(_ sender: Any) {
        guard let userLocation = locationManager.location?.coordinate else {
            print("can't get user location")
            return
        }
        
        let loadingButton = sender as! LoadingButton
        loadingButton.showLoading()
        
        let params = ["lat": userLocation.latitude, "lon": userLocation.longitude, "phone_id": "51"] as [String : Any]
        print(userLocation.latitude)
        print(userLocation.longitude)
        
        requestImmediate("/suggestion/\(gate!.id)/", params: params, method: .post) { (payload, raw, error) in
            loadingButton.hideLoading()
            
            guard error == nil, let payload = payload else {
                // TODO handle error
                print(error!)
                return
            }
            
            print("the suggestion:")
            print(payload)
            
            var route: Route!
            
            do {
                let jsonData = try payload.rawData()
                route = try JSONDecoder().decode(Route.self, from: jsonData)
                route.decodePath(jsonArray: payload["route"].arrayValue)
                route.gate = self.gate
                route.getParkingSpot()
            } catch let error {
                // TODO handle error
                print(error)
            }
            
            self.delegate?.gate(self.gate!, didReceive: route)
        }
    }
}


extension GateViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        print("types count")
        print(self.gate?.nonEmptyTypesCount)
        return self.gate?.nonEmptyTypesCount ?? 0
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return gate?.placesPerType[(gate?.availableTypeAt(index: section))!]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: PlacesSectionHeaderView.reuseIdentifier) as? PlacesSectionHeaderView
        else {
            return nil
        }
        
        view.textLabel?.text = gate?.availableTypeAt(index: section).capitalizingFirstLetter()
        
        return view
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! PlaceTableViewCell
        
        let sectionName = gate?.availableTypeAt(index: indexPath.section) ?? ""
        cell.place = gate?.placesPerType[sectionName]![indexPath.row]
        
        return cell
    }
}

class PlaceTableViewCell: UITableViewCell, ImageHook {
    static let reuseIdentifier: String = "cell"
    
    @IBOutlet var lblName: UILabel!
    @IBOutlet var imgLogo: UIImageView!
    
    var place: Place? = nil {
        didSet {
            lblName.text = place?.name
            imgLogo.contentMode = .scaleAspectFit
            request(URL(string: place!.logo.path)!, progress: nil)
        }
    }
    
    func onHookStart() {
        self.imgLogo.showAnimatedSkeleton()
    }
    
    func onHookEnd() {
        self.imgLogo.hideSkeleton()
    }
    
    func onHookSucceed(image: UIImage, url: URL) {
        self.imgLogo.image = image
    }
    
    func onHookFailed(response: AFIDataResponse<AlamofireImage.Image>, message: String) {
        print("failed to download image \(place?.name)")
        self.imgLogo.image = nil
    }
}

final class PlacesSectionHeaderView: UITableViewHeaderFooterView {
    static let reuseIdentifier: String = "header"
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        
        self.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        self.textLabel?.textColor = UIColor.systemGray
        
        var backgroundConfig = UIBackgroundConfiguration.listPlainHeaderFooter()
        backgroundConfig.backgroundColor = .white
        self.backgroundConfiguration = backgroundConfig
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}
