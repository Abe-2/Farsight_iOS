//
//  RoundedCornersView.swift
//  Construction
//
//  Created by Forat Bahrani on 2/27/20.
//  Copyright © 2020 Forat Bahrani. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
class RoundedCornersView: UIView {
    
    @IBInspectable var radius: CGFloat = 8 { didSet { commonInit() } }
    @IBInspectable var topRight: Bool = true { didSet { commonInit() } }
    @IBInspectable var topLeft: Bool = true { didSet { commonInit() } }
    @IBInspectable var bottomRight: Bool = true { didSet { commonInit() } }
    @IBInspectable var bottomLeft: Bool = true { didSet { commonInit() } }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    func commonInit() {
        self.layer.cornerRadius = radius
        var corners : CACornerMask = []
        if topLeft { corners.insert(.layerMinXMinYCorner) }
        if topRight { corners.insert(.layerMaxXMinYCorner) }
        if bottomLeft { corners.insert(.layerMinXMaxYCorner) }
        if bottomRight { corners.insert(.layerMaxXMaxYCorner) }
        self.layer.maskedCorners = corners
    }
}

