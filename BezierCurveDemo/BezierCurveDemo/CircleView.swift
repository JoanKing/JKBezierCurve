//
//  CircleView.swift
//  BezierCurveDemo
//
//  Created by 小冲冲 on 2023/9/19.
//

import UIKit

class CircleView: UIView {
    private let gestureInsets = UIEdgeInsets(top: -20, left: -20, bottom: -20, right: -20)
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitFrame = bounds.inset(by: gestureInsets)
        return hitFrame.contains(point) ? self : nil
    }
}

