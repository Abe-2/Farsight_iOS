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

class GateViewController: UIViewController {
    
    @IBOutlet var table: UITableView!
    @IBOutlet var lblTitle: UILabel!
    @IBOutlet var lblDistance: UILabel!
    
    var delegate: RouteDelegate?
    
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
        
//        print("phone id: \(Global.phoneID)")
//        var dateComponents = DateComponents()
//        dateComponents.year = 2021
//        dateComponents.month = 4
//        dateComponents.day = 28
//        dateComponents.hour = 15
//        dateComponents.minute = 0
//
//        let userCalendar = Calendar(identifier: .gregorian) // since the components above (like year 1980) are for Gregorian
//        let date = userCalendar.date(from: dateComponents)
//        let timer = Timer(fireAt: date!, interval: 0, target: self, selector: #selector(suggestionTapped(_:)), userInfo: nil, repeats: false)
//        RunLoop.main.add(timer, forMode: .common)
    }
    
    @IBAction func closeTapped(_ sender: Any) {
        self.sheetViewController?.attemptDismiss(animated: true)
    }
    
    @IBAction func suggestionTapped(_ sender: Any) {
        let loadingButton = sender as? LoadingButton
        loadingButton?.showLoading()
        
        let api = APIController()
        api.getSuggestion(for: self.gate!) { (route, error) in
            loadingButton?.hideLoading()
            
            guard error == nil else {
                // TODO this is bad. Do better
                if error == "no spots found" {
                    self.delegate?.noRouteFound(closeSheet: false)
                }
                
                return
            }
            
            self.delegate?.didReceive(route: route!)
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
