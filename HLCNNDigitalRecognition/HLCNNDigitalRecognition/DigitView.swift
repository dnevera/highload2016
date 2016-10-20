/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This file has routines for drwaing and detecting user touches (input digit)
 */

import UIKit

class DigitView: UIView {
    
    var complete:((_: CGContext?) -> Void)? = nil
    
    var linewidth = CGFloat(16) { didSet { setNeedsDisplay() } }
    var color = UIColor.black { didSet { setNeedsDisplay() } }
    
    var lines: [Line] = []
    var lastPoint: CGPoint!
    
    func clear()  {
        lines = []
        setNeedsDisplay()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        clear()
        lastPoint = touches.first!.location(in: self)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let newPoint = touches.first!.location(in: self)
        lines.append(Line(start: lastPoint, end: newPoint))
        lastPoint = newPoint
        setNeedsDisplay()
    }
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let complete = self.complete else {
            return
        }
        complete(getViewContext())
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        let drawPath = UIBezierPath()
        drawPath.lineCapStyle = .round
        
        for line in lines{
            drawPath.move(to: line.start)
            drawPath.addLine(to: line.end)
        }
        
        drawPath.lineWidth = linewidth
        color.set()
        drawPath.stroke()
    }
    
    
    func getViewContext() -> CGContext? {
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceGray()
        
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        
        let context = CGContext(data: nil, width: MNISTLayerCNN.inputWidth, height: MNISTLayerCNN.inputHeight, bitsPerComponent: 8, bytesPerRow: MNISTLayerCNN.inputWidth, space: colorSpace, bitmapInfo: bitmapInfo)
        
        context!.translateBy(x: 0 , y: CGFloat(MNISTLayerCNN.inputWidth))
        context!.scaleBy(x: CGFloat(MNISTLayerCNN.inputWidth)/self.frame.size.width, y: -CGFloat(MNISTLayerCNN.inputHeight)/self.frame.size.height)
        
        self.layer.render(in: context!)
        
        return context
    }
}

class Line{
    var start, end: CGPoint
    
    init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end   = end
    }
}
