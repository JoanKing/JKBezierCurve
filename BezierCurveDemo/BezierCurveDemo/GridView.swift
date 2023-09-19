//
//  GridView.swift
//  BezierCurveDemo
//
//  Created by 小冲冲 on 2023/9/19.
//

import UIKit
import JKSwiftExtension

class GridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let width: CGFloat = rect.size.width
        let height: CGFloat = rect.size.height
        // 创建一个UIBezierPath对象
        let path = UIBezierPath()
        
        // 设置线宽和颜色
        UIColor.yellow.setStroke()
        path.lineWidth = 1.0
        let lineVWidth: CGFloat = height / 10.0
        // 绘制水平线
        for i in 0...10 {
            path.move(to: CGPoint(x: 0, y: CGFloat(i) * lineVWidth))
            path.addLine(to: CGPoint(x: width, y: CGFloat(i) * lineVWidth))
        }
        
        // 绘制垂直线
        let lineHWidth: CGFloat = width / 10.0
        for i in 0...10 {
            path.move(to: CGPoint(x: CGFloat(i) * lineHWidth, y: 0))
            path.addLine(to: CGPoint(x: CGFloat(i) * lineHWidth, y: height))
        }
        // 将路径添加到视图中并绘制
        path.stroke()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
