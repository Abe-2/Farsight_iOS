//
//  RatingViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 3/31/21.
//

import UIKit

class RatingViewController: UIViewController {
    
    @IBOutlet var viwArrivedQuestionHeader: UIView!
    @IBOutlet var viwRatingHeader: UIView!
    
    @IBOutlet var btnNo: UIButton!
    @IBOutlet var btnRatingChoices: [UIButton]!
    
    private var rating: Int?
    
    var route: Route?

    override func viewDidLoad() {
        super.viewDidLoad()

        btnNo.layer.borderWidth = 1
        btnNo.layer.borderColor = btnNo.titleLabel!.textColor.cgColor
    }
    
    @IBAction func answeredYes() {
        UIView.animate(withDuration: 0.2) {
            self.viwArrivedQuestionHeader.alpha = 0
        } completion: { done in
            self.viwArrivedQuestionHeader.isHidden = true
            self.viwRatingHeader.isHidden = false
            
            UIView.animate(withDuration: 0.2) {
                self.viwRatingHeader.alpha = 1
            }
        }
    }
    
    @IBAction func answeredNo() {
        
    }
    
    @IBAction func ratingChoiceSelected(_ sender: UIButton) {
        rating = Int(btnRatingChoices.firstIndex(of: sender)!) + 1
        for button in btnRatingChoices {
            button.backgroundColor = .clear
        }
        sender.backgroundColor = #colorLiteral(red: 0.862745098, green: 0.8745098039, blue: 0.8862745098, alpha: 1)
    }
    
    @IBAction func submitRating(sender: LoadingButton) {
        if rating == nil {
            alert("select a rating")
            return
        }
        
        sender.showLoading()
        
        let params = ["rating": rating!]
        
        requestImmediate("/rating/\(route!.tripID)/", params: params, method: .post) { (payload, raw, error) in
            sender.hideLoading()
            guard error == nil else {
                // TODO handle error
                return
            }
            
            self.sheetViewController?.attemptDismiss(animated: true)
        }
    }

}
