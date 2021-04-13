//
//  UIViewController.swift
//  Farsight
//
//  Created by Abdalwahab on 1/14/21.
//

import Foundation
import UIKit

extension UIViewController {
    
    @objc func hideKeyboard() { view.endEditing(true) }
    
    public func alert(title: String, message: String?, actions: [UIAlertAction]) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        for action in actions {
            alertView.addAction(action)
        }
        self.present(alertView, animated: true, completion: nil)
    }
    
    public func alert(title: String, message: String?, completion: (()->Void)?) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "Ok", style: .default) { (_) in
            completion?()
        }
        alertView.addAction(action)
        self.present(alertView, animated: true, completion: nil)
    }
    public func alert(_ title: String) {
        alert(title: title, message: nil, completion: nil)
    }
    public func alert(_ title: String, _ completion: (()->Void)?) {
        alert(title: title, message: nil, completion: completion)
    }
    
}
