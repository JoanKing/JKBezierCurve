//
//  BezierCurveView.swift
//  BezierCurveDemo
//
//  Created by 小冲冲 on 2023/9/19.
//

import UIKit
import JKSwiftExtension

/// GPU Accelerate
protocol GPURenderable { }
final class LineGradientLayer: CAGradientLayer, GPURenderable { }
final class LineShapeLayer: CAShapeLayer, GPURenderable { }

class BezierCurveView: UIView {
    /// cmd_state：传给控制器的是个控制点，auxiliary_curve：辅助控制点
    var dataClosure: ((_ cmd_state: [Int], _ auxiliary_curve: String) -> Void)?
    /// 手势点击或者拖动生成点的有效距离
    var effectiveDistance: CGFloat {
        return lineWidth + 30
    }
    /// 线宽
    var lineWidth: CGFloat = 6
    /// 超出前后点的拖动范围是否移除点，默认不移除
    var removePointBeyondFrontAndRearPoints: Bool = true
    /// 曲线是否可以交互
    var isCanUserInteractionEnabled: Bool = true
    /// 开始和结束的点是否可以交互
    var isStartingAndEndingPointEnabled: Bool = false
    /// 点的数量，包含两头的点
    var maxCircleViewNumber: Int = 9
    /// 渐变色
    var gradientColors: [CGColor] = [
        UIColor.hexStringColor(hexString: "#AF52DE").cgColor,
        UIColor.hexStringColor(hexString: "#FF2D55").cgColor
    ]
    /// 渐变起始位置
    var locations: [NSNumber] = [0, 1]
    /// 渐变的起点
    var gradientStartPoint: CGPoint = CGPoint(x: 0, y: 0.5)
    /// 渐变的终点
    var gradientEndPoint: CGPoint = CGPoint(x: 1, y: 0.5)
    
    /// 控制点
    private var circleViews: [UIView] = []
    /// 当前的path
    private var currentPath: CGPath?
    /// 渐变曲线
    private let lineLayer = LineGradientLayer()
    /// 当前的控制点
    private var points: [CGPoint] = []
    /// 曲线上所有的点
    private var allPointList: [CGPoint] = []
    /// 父视图拖动插入有效的点tag
    private var superPanInserTag: Int = 0
    /// 取值的点的圆圈视图
    private var paramCircleViews: [UIView] = []
    /// 上传点的数组
    private var paramPoints: [CGPoint] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(lineLayer)
        lineLayer.frame = frame
        // 点击手势
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(superTapGester))
        self.addGestureRecognizer(tapGestureRecognizer)
        // 拖动手势
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(superPanGester))
        panGestureRecognizer.delegate = self
        self.addGestureRecognizer(panGestureRecognizer)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        lineLayer.frame = bounds
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard points.count > 0 else { return }
        // 获取绘图上下文
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        context.saveGState()
        defer {
            context.restoreGState()
        }
        // 计算点
        calculate(pointList: points)
    }
    
    //MARK: 画线
    /// 画线
    /// - Parameter path: 路径
    func drawPath(path: CGMutablePath) {
        // 添加路径到图形上下文
        lineLayer.colors = gradientColors
        lineLayer.startPoint = gradientStartPoint
        lineLayer.endPoint = gradientEndPoint
        // [0, 0.2] 指的是0-0.2之间渐变 0.2-1.0颜色不渐变
        lineLayer.locations = locations
        
        let lineShape = LineShapeLayer()
        lineShape.path = path
        lineShape.fillColor = nil
        lineShape.strokeColor = UIColor.black.cgColor
        lineShape.lineWidth = lineWidth
        lineShape.lineJoin = .round
        lineShape.lineCap = .round
        lineShape.frame = self.bounds
        lineLayer.mask = lineShape
        currentPath = path
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//MARK: - 设置点，左上角是点：(0, 0)
extension BezierCurveView {
    
    func setPointValue1() {
        // 服务器给的点的样式： 使用分号;分割点，使用逗号(,)分割x和y坐标百分比
        let string = "47,40;60,60;70,90"
        let splitedArray: [String] = string.jk.separatedByString(with: ";")
        var pointArrays: [CGPoint] = [CGPoint(x: 7, y: frame.size.height - 7)]
        
        let curvW: CGFloat = frame.size.width - 14
        let curvH: CGFloat = frame.size.height - 16
        let array = splitedArray.map { item in
            let pointA = item.jk.separatedByString(with: ",")
            let x: CGFloat = 7.0 + (pointA[0].jk.toCGFloat() ?? 0) * 0.01 * curvW
            let y: CGFloat = 8.0 + (1.0 - (pointA[1].jk.toCGFloat() ?? 0) * 0.01) * curvH
            let point: CGPoint = CGPoint(x: x, y: y)
            return point
        }
        pointArrays.appends(array)
        pointArrays.append(CGPoint(x: frame.size.width - 7, y: 8))
        points = pointArrays
        for i in 0 ..< points.count {
            setCircleView(index: i, point: points[i])
        }
        setNeedsDisplay()
    }
    
    func setPointValue(pointArray: [CGPoint]) {
        var pointArrays: [CGPoint] = [CGPoint(x: 7, y: frame.size.height - 7)]
        pointArrays.appends(pointArray)
        pointArrays.append(CGPoint(x: frame.size.width - 7, y: 8))
        points = pointArrays
        for i in 0 ..< points.count {
            setCircleView(index: i, point: points[i])
        }
        setNeedsDisplay()
    }
}

//MARK: - 业务代码 - 点的展示与消失
extension BezierCurveView {
    
    func showCircleView(xArray: [CGFloat]) {
        paramPoints.removeAll()
        guard let currentPath else {
            return
        }
        for item in xArray {
            let point = getPointXY(xy: item, path: currentPath)
            paramPoints.append(point)
            let view = CircleView()
            view.layer.cornerRadius = 7.5
            view.clipsToBounds = false
            view.backgroundColor = .green
            view.layer.borderWidth = 3
            view.layer.borderColor = UIColor.white.cgColor
            self.addSubview(view)
            paramCircleViews.append(view)
            view.snp.makeConstraints { make in
                make.center.equalTo(point)
                make.size.equalTo(CGSize(width: 15, height: 15))
            }
        }
        debugPrint("打印的点：\(paramPoints)")
    }
    
    func showCircleViewY(yArray: [CGFloat]) {
        paramPoints.removeAll()
        guard let currentPath else {
            return
        }
        for item in yArray {
            let point = getPointXY(xy: item, path: currentPath, isX: false)
            let view = CircleView()
            view.layer.cornerRadius = 7.5
            view.clipsToBounds = false
            view.backgroundColor = .green
            view.layer.borderWidth = 3
            view.layer.borderColor = UIColor.white.cgColor
            self.addSubview(view)
            paramCircleViews.append(view)
            view.snp.makeConstraints { make in
                make.center.equalTo(point)
                make.size.equalTo(CGSize(width: 15, height: 15))
            }
        }
        debugPrint("打印的点：\(paramPoints)")
    }
    
    //MARK: 移除所有取值点
    /// 移除所有取值点
    func removeCircleView() {
        for item in paramCircleViews {
            item.removeFromSuperview()
        }
    }
    
    //MARK: 获取上传的值
    /// 获取上传的值
    func getParamPointArray() -> (cmd_state: [Int], auxiliary_curve: String) {
        guard let currentPath else {
            return ([], "")
        }
        paramPoints.removeAll()
        var array: [CGFloat] = []
        let width: CGFloat = (frame.size.width - 14) / 10.0
        for i in 1...9 {
            let xValue: CGFloat = 7.0 + CGFloat(i) * width
            array.append(xValue)
        }
        for item in array {
            let point = getPointXY(xy: item, path: currentPath)
            paramPoints.append(point)
        }
        let paramValues = paramPoints.compactMap { point in
            // 7.5是圆的半径
            let y = point.y - 8.0
            let value = NSDecimalNumberHandler.jk.calculation(
                type: .dividing,
                value1: y * 100.0,
                value2: frame.size.height - 16,
                roundingMode: .plain,
                scale: 5).intValue
            return 100 - value
        }
        
        var netParam: [Int] = []
        var previousValue: Int = 0
        if paramValues.count > 3 {
            for (index, item) in paramValues.enumerated() {
                if index == 0 {
                    netParam.append(item)
                } else {
                    // 后面的值不能比前面的值小
                    netParam.append(item < previousValue ? previousValue : item)
                }
                previousValue = netParam[index]
            }
        }
        // 最后一个值是固定的100
        netParam.append(100)
        
        // 获取控制点的数据，最多是9个点，两头的控制点不传；服务器给的点的样式： 使用分号;分割点，使用逗号(,)分割x和y坐标百分比
        var controllerString = ""
        for (index, item) in points.enumerated() {
            if (index != 0) && index != (points.count - 1) {
                // 取中间的控制点给服务器
                let xPercentage = NSDecimalNumberHandler.jk.calculation(
                    type: .dividing,
                    value1: (item.x - 7.0) * 100.0,
                    value2: frame.size.width - 14,
                    roundingMode: .plain,
                    scale: 5).intValue
                let yPercentage = 100 - NSDecimalNumberHandler.jk.calculation(
                    type: .dividing,
                    value1: (item.y - 8.0) * 100.0,
                    value2: frame.size.height - 16,
                    roundingMode: .plain,
                    scale: 5).intValue
                if index != 1 {
                    controllerString = controllerString + ";"
                }
                controllerString = controllerString + "\(xPercentage),\(yPercentage)"
            }
        }
        debugPrint("上传的点值：\(paramPoints) ❌没处理大小上传的百分比：\(paramValues) ✅处理大小上传的百分比：\(netParam) 控制点的百分比：\(controllerString)")
        return (netParam, controllerString)
    }
}

//MARK: - 圆圈视图手势的处理
extension BezierCurveView {
    
    //MARK: 控制点的拖动
    /// 拖动手势
    /// - Parameter panGesture: 手势
    @objc func panGester(panGesture: UIPanGestureRecognizer) {
        
        switch panGesture.state {
        case .began:
            debugPrint("拖动开始")
        case .changed:
            if let panView = panGesture.view {
                // 手势移动的 x和y值随时间变化的总平移量
                let translation = panGesture.translation(in: panView)
                if (panView.frame.minY + translation.y) >= 0 && (panView.frame.maxY + translation.y) <= frame.size.height && (panView.frame.minX + translation.x) >= 0 && (panView.frame.maxX + translation.x) <= frame.size.width {
                    
                    let panGestureRecognizerTag = panView.tag - 100
                    
                    // 第一个点和最后一个点是否可交互
                    if panGestureRecognizerTag == 0 || panGestureRecognizerTag == points.count - 1 {
                        if isStartingAndEndingPointEnabled {
                            // 移动
                            panView.transform = panView.transform.translatedBy(x: translation.x, y: translation.y)
                            // 复位，相当于现在是起点
                            panGesture.setTranslation(.zero, in: panView)
                            let point = CGPoint(x: panView.frame.midX, y: panView.frame.midY)
                            points[panView.tag - 100] = point
                            setNeedsDisplay()
                        }
                        return
                    }
                    // 移动
                    panView.transform = panView.transform.translatedBy(x: translation.x, y: translation.y)
                    // 复位，相当于现在是起点
                    panGesture.setTranslation(.zero, in: panView)
                    let point = CGPoint(x: panView.frame.midX, y: panView.frame.midY)
                    
                    // 判断拖动点是否超出前后两个点的矩形区域，超出的话就移除该点
                    let previousPoint: CGPoint = points[panGestureRecognizerTag - 1]
                    let nextPoint: CGPoint = points[panGestureRecognizerTag + 1]
                    guard point.x > previousPoint.x && point.y < previousPoint.y && point.x < nextPoint.x && point.y > nextPoint.y else {
                        debugPrint("❌不在矩形范围内", "previousPoint：\(previousPoint) nextPoint：\(nextPoint)")
                        // 移除该点
                        points.remove(at: panGestureRecognizerTag)
                        let view = circleViews[panGestureRecognizerTag]
                        circleViews.remove(at: panGestureRecognizerTag)
                        view.removeFromSuperview()
                        for index in panGestureRecognizerTag...(circleViews.count - 1) {
                            circleViews[index].tag = index + 100
                        }
                        // 加震动
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        setNeedsDisplay()
                        let param = getParamPointArray()
                        dataClosure?(param.cmd_state, param.auxiliary_curve)
                        return
                    }
                    points[panView.tag - 100] = point
                    debugPrint("打印tag：\(panView.tag - 100)")
                    setNeedsDisplay()
                }
            }
        case .ended:
            debugPrint("拖动结束 新的value")
            let param = getParamPointArray()
            dataClosure?(param.cmd_state, param.auxiliary_curve)
        default:
            debugPrint("其他")
        }
    }
}

//MARK: - 父视图手势的处理
extension BezierCurveView: UIGestureRecognizerDelegate {
    
    //MARK: 父视图点击手势
    ///  父视图点击手势
    /// - Parameter panGesture: 手势
    @objc func superTapGester(gesture: UITapGestureRecognizer) {
        guard let currentPath, isCanUserInteractionEnabled, points.count < maxCircleViewNumber else {
            return
        }
        let tapLocation = gesture.location(in: self)
        debugPrint("Tap location in parent view: \(tapLocation)")
        // 1、点击点首先要在 左右两个点的矩形内，如果不在不生点
        var previousPoint: CGPoint = CGPoint()
        var nextPoint: CGPoint = CGPoint()
        /// 要插入的index
        var insertIndex: Int = 0
        for (index, item) in points.enumerated() {
            if tapLocation.x < item.x {
                insertIndex = index
                // 找到后面的点
                nextPoint = item
                break
            }
            previousPoint = item
        }
        guard tapLocation.x > previousPoint.x && tapLocation.y < previousPoint.y && tapLocation.x < nextPoint.x && tapLocation.y > nextPoint.y else {
            debugPrint("❌不在矩形范围内", "previousPoint：\(previousPoint) nextPoint：\(nextPoint)")
            return
        }
        // 在矩形的范围内，确定添加的点事垂直点还是水平点
        // 垂直点
        let vPoint = getPointXY(xy: tapLocation.x, path: currentPath)
        // 水平点
        let hPoint = getPointXY(xy: tapLocation.y, path: currentPath, isX: false)
        // 垂直长度
        let vLength: CGFloat = abs(tapLocation.y - vPoint.y)
        // 水平长度
        let hLength: CGFloat = abs(tapLocation.x - hPoint.x)
        guard vLength < effectiveDistance || hLength < effectiveDistance else {
            debugPrint("✅在矩形范围内 ❌：不在有效距离：\(effectiveDistance) 内， 垂直距离：\(vLength) 水平距离：\(hLength)")
            return
        }
        // 在有效的范围内
        var point: CGPoint = CGPoint()
        if vLength < hLength {
            point = vPoint
            debugPrint("✅在矩形范围内：取值垂直的点")
        } else {
            point = hPoint
            debugPrint("✅在矩形范围内：取值水平的点")
        }
        // 2、在矩形内，生成一个点
        let view = CircleView()
        view.layer.cornerRadius = 7.5
        view.clipsToBounds = false
        view.backgroundColor = .randomColor
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.white.cgColor
        view.tag = insertIndex + 100
        self.addSubview(view)
        // 插入视图
        circleViews.insert(view, at: insertIndex)
        // 插入生成的点
        points.insert(point, at: insertIndex)
        
        // 改变其他视图的tag
        for index in (insertIndex + 1)...(circleViews.count - 1) {
            circleViews[index].tag = index + 100
        }
        
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGester))
        view.addGestureRecognizer(panGestureRecognizer)
        
        view.snp.makeConstraints { make in
            make.center.equalTo(point)
            make.size.equalTo(CGSize(width: 15, height: 15))
        }
        
        // 加震动
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let param = getParamPointArray()
        dataClosure?(param.cmd_state, param.auxiliary_curve)
    }
    
    //MARK: 父视图拖动手势
    ///  父视图拖动手势
    /// - Parameter panGesture: 手势
    @objc func superPanGester(panGesture: UIPanGestureRecognizer) {
        // 最多maxCircleViewNumber个点，包含两头的点
        guard isCanUserInteractionEnabled, points.count < maxCircleViewNumber else {
            return
        }
        switch panGesture.state {
        case .began:
            let startPanLocation = panGesture.location(in: self)
            let result = isPointLine(point: startPanLocation)
            if result.isEffectivePoint {
                // 在拖动开始的位置生成一个点
                superPanInserTag = 100 + result.insertIndex
                // 2、在矩形内，生成一个点
                let view = CircleView()
                view.layer.cornerRadius = 7.5
                view.clipsToBounds = false
                view.backgroundColor = .randomColor
                view.layer.borderWidth = 3
                view.layer.borderColor = UIColor.white.cgColor
                view.tag = superPanInserTag
                self.addSubview(view)
                // 插入视图
                circleViews.insert(view, at: result.insertIndex)
                // 插入生成的点
                points.insert(startPanLocation, at: result.insertIndex)
                
                // 改变其他视图的tag
                for index in (result.insertIndex + 1)...(circleViews.count - 1) {
                    circleViews[index].tag = index + 100
                }
                
                let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGester))
                view.addGestureRecognizer(panGestureRecognizer)
                
                view.snp.makeConstraints { make in
                    make.center.equalTo(startPanLocation)
                    make.size.equalTo(CGSize(width: 15, height: 15))
                }
                setNeedsDisplay()
                // 加震动
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            debugPrint("super-拖动开始: \(startPanLocation) superPanInserTag:\(superPanInserTag)")
        case .changed:
            let tapLocation = panGesture.location(in: self)
            if superPanInserTag > 0 {
                debugPrint("super-拖动中: \(tapLocation) inserTag:\(superPanInserTag)")
                // 添加的点跟着移动
                let panGestureRecognizerTag = superPanInserTag - 100
                let previousPoint: CGPoint = points[panGestureRecognizerTag - 1]
                let nextPoint: CGPoint = points[panGestureRecognizerTag + 1]
                guard tapLocation.x > previousPoint.x && tapLocation.y < previousPoint.y && tapLocation.x < nextPoint.x && tapLocation.y > nextPoint.y else {
                    debugPrint("❌不在矩形范围内", "previousPoint：\(previousPoint) nextPoint：\(nextPoint)")
                    // 移除该点
                    points.remove(at: panGestureRecognizerTag)
                    let view = circleViews[panGestureRecognizerTag]
                    circleViews.remove(at: panGestureRecognizerTag)
                    view.removeFromSuperview()
                    for index in panGestureRecognizerTag...(circleViews.count - 1) {
                        circleViews[index].tag = index + 100
                    }
                    // 加震动
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                    superPanInserTag = 0
                    setNeedsDisplay()
                    return
                }
                let view = circleViews[panGestureRecognizerTag]
                view.snp.updateConstraints { make in
                    make.center.equalTo(tapLocation)
                }
                points[panGestureRecognizerTag] = tapLocation
                debugPrint("打印tag：\(panGestureRecognizerTag)")
                setNeedsDisplay()
            }
        case .ended:
            superPanInserTag = 0
            debugPrint("super-拖动结束 新的value")
        default:
            debugPrint("super-其他")
        }
    }
    
    //MARK: 是否响应父视图拖动的手势
    /// 是否响应拖动的手势：实现 gestureRecognizer(_:shouldReceive:) 方法
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 根据条件决定是否响应手势
        if isCanUserInteractionEnabled {
            let location = touch.location(in: self)
            let result = isPointLine(point: location)
            return result.isEffectivePoint
        } else {
            return false
        }
    }
}

//MARK: - 判断点有效性和生成点的方法
extension BezierCurveView {
    //MARK: 手势的点是否在线上，有一个合理的距离
    /// 手势的点是否在线上，有一个合理的距离
    private func isPointLine(point: CGPoint) -> (isEffectivePoint: Bool, insertIndex: Int) {
        guard let currentPath else {
            return (false, 0)
        }
        // 1、点击点首先要在 左右两个点的矩形内，如果不在不生点
        var previousPoint: CGPoint = CGPoint()
        var nextPoint: CGPoint = CGPoint()
        /// 要插入的index
        var insertIndex: Int = 0
        for (index, item) in points.enumerated() {
            if point.x < item.x {
                insertIndex = index
                // 找到后面的点
                nextPoint = item
                break
            }
            previousPoint = item
        }
        guard point.x > previousPoint.x && point.y < previousPoint.y && point.x < nextPoint.x && point.y > nextPoint.y else {
            debugPrint("❌不在矩形范围内", "previousPoint：\(previousPoint) nextPoint：\(nextPoint)")
            return (false, 0)
        }
        // 在矩形的范围内，确定添加的点事垂直点还是水平点
        // 垂直点1
        let vPoint = getPointXY(xy: point.x, path: currentPath)
        // 水平点
        let hPoint = getPointXY(xy: point.y, path: currentPath, isX: false)
        // 垂直长度
        let vLength: CGFloat = abs(point.y - vPoint.y)
        // 水平长度
        let hLength: CGFloat = abs(point.x - hPoint.x)
        guard vLength < effectiveDistance || hLength < effectiveDistance else {
            debugPrint("✅在矩形范围内 ❌：不在有效距离：\(effectiveDistance) 内， 垂直距离：\(vLength) 水平距离：\(hLength)")
            return (false, 0)
        }
        return (true, insertIndex)
    }
    
    //MARK: 添加圆圈视图
    /// 添加圆圈视图
    private func setCircleView(index: Int, point: CGPoint) {
        let view = CircleView()
        view.layer.cornerRadius = 7.5
        view.clipsToBounds = false
        view.backgroundColor = .randomColor
        view.layer.borderWidth = 3
        view.layer.borderColor = UIColor.white.cgColor
        view.tag = index + 100
        self.addSubview(view)
        circleViews.append(view)
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panGester))
        view.addGestureRecognizer(panGestureRecognizer)
        view.snp.makeConstraints { make in
            make.center.equalTo(point)
            make.size.equalTo(CGSize(width: 15, height: 15))
        }
    }
}

//MARK: - CGMutablePath曲线-根据x坐标获取y坐标
extension BezierCurveView {
    //MARK: 根据某个点的x坐标获取y坐标
    /// 根据某个点的x坐标获取y坐标
    /// - Parameters:
    ///   - x: x / y坐标
    ///   - path: CGMutablePath
    /// - Returns: description
    private func getPointXY(xy: CGFloat, path: CGPath, isX: Bool = true) -> CGPoint {
        var value: CGFloat = 0.0
        var prevPoint = CGPoint.zero
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                prevPoint = element.pointee.points[0]
            case .addLineToPoint:
                let startPoint = prevPoint
                let endPoint = element.pointee.points[0]
                if isX {
                    if xy >= startPoint.x && xy <= endPoint.x {
                        let t = (xy - startPoint.x) / (endPoint.x - startPoint.x)
                        value = startPoint.y + t * (endPoint.y - startPoint.y)
                    }
                } else {
                    if xy <= startPoint.y && xy >= endPoint.y {
                        let t = (xy - startPoint.y) / (endPoint.y - startPoint.y)
                        value = startPoint.x + t * (endPoint.x - startPoint.x)
                    }
                }
                prevPoint = endPoint
            default:
                break
            }
        }
        return isX ? CGPoint(x: xy, y: value) : CGPoint(x: value, y: xy)
    }
}

//MARK: - 控制点和生成点的算法
extension BezierCurveView {
    
    //MARK: 通过已知点绘制path
    private func calculate(pointList: [CGPoint]) {
        allPointList.removeAll()
        let path = CGMutablePath()
        // 曲线斜率
        let sharpenRatio = 1.0
        if (pointList.count < 3) {
            path.addLines(between: pointList)
            drawPath(path: path)
            return
        }
        var pMidOfLm = CGPoint()
        var pMidOfMr = CGPoint()
        var cache: CGPoint? = nil
        var startPoint = pointList[0]
        for i in 0...pointList.count - 3 {
            let pL = pointList[i]
            let pM = pointList[i + 1]
            let pR = pointList[i + 2]
            pMidOfLm.x = (pL.x + pM.x) / 2.0
            pMidOfLm.y = (pL.y + pM.y) / 2.0
            pMidOfMr.x = (pM.x + pR.x) / 2.0
            pMidOfMr.y = (pM.y + pR.y) / 2.0
            let lengthOfLm = distanceBetweenPoints(pL, pM)
            let lengthOfMr = distanceBetweenPoints(pR, pM)
            var ratio = lengthOfLm / (lengthOfLm + lengthOfMr) * sharpenRatio
            let oneMinusRatio = (1 - ratio) * sharpenRatio
            let dx = pMidOfLm.x - pMidOfMr.x
            let dy = pMidOfLm.y - pMidOfMr.y
            var cLeft = CGPoint()
            cLeft.x = pM.x + dx * ratio
            cLeft.y = pM.y + dy * ratio
            var cRight = CGPoint()
            cRight.x = pM.x + -dx * oneMinusRatio
            cRight.y = pM.y + -dy * oneMinusRatio
            if (i == 0) {
                let pMidOfLCLeft = CGPoint(x: (pL.x + cLeft.x) / 2.0, y: (pL.y + cLeft.y) / 2.0)
                let pMidOfCLeftM = CGPoint(x: (cLeft.x + pM.x) / 2.0, y: (cLeft.y + pM.y) / 2.0)
                let length1 = distanceBetweenPoints(cLeft, pL)
                let length2 = distanceBetweenPoints(cLeft, pM)
                ratio = length1 / (length1 + length2) * sharpenRatio
                var first = CGPoint()
                first.x = cLeft.x + (pMidOfLCLeft.x - pMidOfCLeftM.x) * ratio
                first.y = cLeft.y + (pMidOfLCLeft.y - pMidOfCLeftM.y) * ratio
                addPoint(startPoint, first, cLeft, pM)
                startPoint = pM
            } else {
                // bezierPath.move(to: startPoint)
                if let weakCache = cache {
                    // bezierPath.addCurve(to: pM, control1: weakCache, control2: cLeft)
                    addPoint(startPoint, weakCache, cLeft, pM)
                    startPoint = pM
                }
            }
            cache = cRight
            if (i == pointList.count - 3) {
                let pMidOfMCRight = CGPoint(x: (pM.x + cRight.x) / 2.0, y: (pM.y + cRight.y) / 2.0)
                let pMidOfCRightR = CGPoint(x: (pR.x + cRight.x) / 2.0, y: (pR.y + cRight.y) / 2.0)
                let length1 = distanceBetweenPoints(cRight, pM)
                let length2 = distanceBetweenPoints(pR, cRight)
                ratio = length2 / (length1 + length2) * sharpenRatio
                var last = CGPoint()
                last.x = cRight.x + (pMidOfCRightR.x - pMidOfMCRight.x) * ratio
                last.y = cRight.y + (pMidOfCRightR.y - pMidOfMCRight.y) * ratio
                // startPoint = pM
                // bezierPath.move(to: startPoint)
                // bezierPath.addCurve(to: pR, control1: cRight, control2: last)
                addPoint(startPoint, cRight, last, pR)
            }
        }
        path.addLines(between: allPointList)
        drawPath(path: path)
    }
    
    //MARK: 获取两个点之间的中间点
    /// 获取两个点之间的中间点
    /// - Parameters:
    ///   - point1: 点1
    ///   - point2: 点2
    /// - Returns: 返回中间的点
    private func distanceBetweenPoints(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let xDist = point2.x - point1.x
        let yDist = point2.y - point1.y
        return sqrt(xDist * xDist + yDist * yDist)
    }
    
    private func addPoint(_ start: CGPoint, _ control1: CGPoint, _ control2: CGPoint, _ end: CGPoint) {
        let pointCount = 100
        for index in 0...pointCount - 1 {
            // let t = 1.0 / Float(pointCount * index)
            let t = NSDecimalNumberHandler.jk.calculation(
                type: .dividing,
                value1: 1.0,
                value2: pointCount,
                roundingMode: .plain,
                scale: 5)
            let calculateBezierPointForCubic = calculateBezierPointForCubic(t.doubleValue * CGFloat(index), start, control1, control2, end)
            allPointList.append(calculateBezierPointForCubic)
        }
    }
    
    /// B(t) = P0 * (1-t)^3 + 3 * P1 * t * (1-t)^2 + 3 * P2 * t^2 * (1-t) + P3 * t^3, t ∈ [0,1]
    /// - Parameters:
    ///   - t: 曲线长度比例
    ///   - p0: 起始点
    ///   - p1: 控制点1
    ///   - p2: 控制点2
    ///   - p3: 终止点
    /// - Returns:  t对应的点
    private func calculateBezierPointForCubic(_ t: CGFloat, _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint) -> CGPoint {
        var point = CGPoint()
        let temp: CGFloat = CGFloat(1 - t)
        let temp2: CGFloat = CGFloat(temp * temp)
        let temp3: CGFloat = CGFloat(temp * temp * temp)
        let t2: CGFloat = t * t
        let t3: CGFloat = t * t * t
        let p0X: CGFloat = p0.x
        let p0Y: CGFloat = p0.y
        let p1X: CGFloat = p1.x
        let p1Y: CGFloat = p1.y
        let p2X: CGFloat = p2.x
        let p2Y: CGFloat = p2.y
        let p3X: CGFloat = p3.x
        let p3Y: CGFloat = p3.y
        
        let p1XValue: CGFloat = 3.0 * p1X * CGFloat(t) * temp2
        let p1YValue: CGFloat = 3 * p1Y * CGFloat(t) * temp2
        let p2XValue: CGFloat = 3 * p2X * t2 * temp
        let p2YValue: CGFloat = 3 * p2Y * t2 * temp
        
        let valueX: CGFloat = p0X * temp3 + p1XValue + p2XValue + p3X * t3
        let valueY: CGFloat = p0Y * temp3 + p1YValue + p2YValue + p3Y * t3
        point.x = valueX
        point.y = valueY
        if valueX <= 7 {
            point.x = 7
        }
        if valueX >= frame.size.width - 7 {
            point.x = frame.size.width - 7
        }
        if valueY <= 8 {
            point.y = 8
        }
        if valueY >= frame.size.height - 8 {
            point.y = frame.size.height - 8
        }
        debugPrint("打印点：valueX：\(valueX) valueY：\(valueY) point:\(point)")
        return point
    }
}
