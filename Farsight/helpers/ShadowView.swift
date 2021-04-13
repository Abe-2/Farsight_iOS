//
//  ShadowView.swift
//  Construction
//
//  Created by Forat Bahrani on 2/27/20.
//  Copyright © 2020 Forat Bahrani. All rights reserved.
//

import UIKit

@IBDesignable
class ShadowView: RoundedCornersView {

    @IBInspectable var shadowColor : UIColor? = UIColor.black { didSet { updateShadow()} }
    @IBInspectable var shadowRadius : CGFloat = 4 { didSet { updateShadow()} }
    @IBInspectable var shadowOpacity : Float = 0.15 { didSet { updateShadow()} }
    @IBInspectable var shadowX : CGFloat = 0 { didSet { updateShadow()} }
    @IBInspectable var shadowY : CGFloat = 2 { didSet { updateShadow()} }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    override func commonInit() {
        super.commonInit()
        updateShadow()
    }
    
    func updateShadow() {
        self.layer.shadowColor = shadowColor?.cgColor
        self.layer.shadowRadius = shadowRadius
        self.layer.shadowOpacity = shadowOpacity
        self.layer.shadowOffset = CGSize(width: shadowX, height: shadowY)
    }

}
