//
//  ViewController.swift
//  BezierCurveDemo
//
//  Created by 小冲冲 on 2023/9/19.
//

import UIKit
import JKSwiftExtension
import Accelerate
import SnapKit

class ViewController: UIViewController {
    
    var viewH: CGFloat {
        return (jk_kScreenW - 41 * 2) * 259.0 / 311.5
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = .brown
        
        self.view.jk.addSubviews([testButton, removeButton, paramsButton, showYButton])
        
        let buttonW: CGFloat = (jk_kScreenW - 16 * 4) / 3.0
        
        testButton.snp.makeConstraints { make in
            make.top.equalTo(jk_kNavFrameH)
            make.left.equalTo(16)
            make.size.equalTo(CGSize(width: buttonW, height: 60))
        }
        removeButton.snp.makeConstraints { make in
            make.top.equalTo(jk_kNavFrameH)
            make.left.equalTo(testButton.snp.right).offset(16)
            make.size.equalTo(CGSize(width: buttonW, height: 60))
        }
        paramsButton.snp.makeConstraints { make in
            make.top.equalTo(jk_kNavFrameH)
            make.left.equalTo(removeButton.snp.right).offset(16)
            make.size.equalTo(CGSize(width: buttonW, height: 60))
        }
        showYButton.snp.makeConstraints { make in
            make.top.equalTo(testButton.snp.bottom).offset(18)
            make.left.equalTo(testButton.snp.left)
            make.size.equalTo(CGSize(width: buttonW, height: 60))
        }
       
        self.view.addSubview(gridView)
        self.view.addSubview(bezierPathView)
        
        bezierPathView.setPointValue1()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
 
    }
    
    lazy var bezierPathView: BezierCurveView = {
        let v = BezierCurveView(frame: CGRect(x: 41, y: 300, width: jk_kScreenW - 41 * 2, height: viewH))
        v.backgroundColor = .clear
        return v
    }()
    
    lazy var gridView: GridView = {
        let testView = GridView(frame: CGRect(x: 41 + 7, y: 300 + 8, width: jk_kScreenW - (41 + 7) * 2, height: viewH - 16))
        testView.backgroundColor = .clear
        return testView
    }()
    
    /// 测试
    lazy var testButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .yellow
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.setTitleColor(UIColor.blue, for: .normal)
        button.setTitle("获取点", for: .normal)
        button.addTarget(self, action: #selector(showCircleView), for: .touchUpInside)
        return button
    }()
    
    /// 移除点
    lazy var removeButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .yellow
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.setTitleColor(UIColor.blue, for: .normal)
        button.setTitle("移除点", for: .normal)
        button.addTarget(self, action: #selector(removeCircleView), for: .touchUpInside)
        return button
    }()
    
    /// 上传的点
    lazy var paramsButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .yellow
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.setTitleColor(UIColor.blue, for: .normal)
        button.setTitle("上传的点", for: .normal)
        button.addTarget(self, action: #selector(paramClick), for: .touchUpInside)
        return button
    }()
    
    /// 根据y坐标获取x的坐标
    lazy var showYButton: UIButton = {
        let button = UIButton()
        button.backgroundColor = .yellow
        button.layer.cornerRadius = 10
        button.clipsToBounds = true
        button.setTitleColor(UIColor.blue, for: .normal)
        button.setTitle("y获取x坐标", for: .normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.addTarget(self, action: #selector(yClick), for: .touchUpInside)
        return button
    }()
    
    lazy var testLabel1: UILabel = {
        let label = UILabel()
        label.text = ""
        return label
    }()
}

//MARK: - 基本事件
extension ViewController {
    @objc func showCircleView(sender: UIButton) {
        var array: [CGFloat] = []
        let width: CGFloat = (jk_kScreenW - (41 + 7) * 2) / 10.0
        for i in 1...9 {
            let xValue: CGFloat = 7.0 + CGFloat(i) * width
            array.append(xValue)
        }
        // customView.showCircleView(xArray: array)
        bezierPathView.showCircleView(xArray: array)
    }
    
    //MARK: 移除点
    @objc func removeCircleView(sender: UIButton) {
        // customView.removeCircleView()
        bezierPathView.removeCircleView()
    }
    
    //MARK: 上传点的值
    @objc func paramClick(sender: UIButton) {
        // customView.removeCircleView()
        bezierPathView.getParamPointArray()
    }
    
    @objc func yClick(sender: UIButton) {
        // customView.removeCircleView()
        bezierPathView.showCircleViewY(yArray: [200])
    }
}
