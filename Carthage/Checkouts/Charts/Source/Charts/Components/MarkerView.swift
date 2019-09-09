//
//  ChartMarkerView.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

@objc(ChartMarkerView)
open class MarkerView: NSUIView, IMarker
{
    open var offset: CGPoint = CGPoint()
    
    @objc open weak var chartView: ChartViewBase?
    
    open func offsetForDrawing(atPoint point: CGPoint) -> CGPoint
    {
        guard let chart = chartView else { return self.offset }
        
        var offset = self.offset
        
        let width = self.bounds.size.width
        let height = self.bounds.size.height
        
        if point.x + offset.x < 0.0
        {
            offset.x = -point.x
        }
        else if point.x + width + offset.x > chart.bounds.size.width
        {
            offset.x = chart.bounds.size.width - point.x - width
        }
        
        if point.y + offset.y < 0
        {
            offset.y = -point.y
        }
        else if point.y + height + offset.y > chart.bounds.size.height
        {
            offset.y = chart.bounds.size.height - point.y - height
        }
        
        return offset
    }
    
    open func refreshContent(entry: ChartDataEntry, highlight: Highlight)
    {
        // Do nothing here...
    }
    
    open func draw(context: CGContext, point: CGPoint)
    {
        let offset = self.offsetForDrawing(atPoint: point)
        
        context.saveGState()
        context.translateBy(x: point.x + offset.x,
                              y: point.y + offset.y)
        NSUIGraphicsPushContext(context)
        self.nsuiLayer?.render(in: context)
        NSUIGraphicsPopContext()
        context.restoreGState()
    }
    
    @objc
    open class func viewFromXib(in bundle: Bundle = .main) -> MarkerView?
    {
        #if !os(OSX)
        return bundle.loadNibNamed(
            String(describing: self),
            owner: nil,
            options: nil)?[0] as? MarkerView
        #else
        
        var loadedObjects = NSArray()
        let loadedObjectsPointer = AutoreleasingUnsafeMutablePointer<NSArray?>(&loadedObjects)
        
        if bundle.loadNibNamed(
            NSNib.Name(String(describing: self)),
            owner: nil,
            topLevelObjects: loadedObjectsPointer)
        {
            return loadedObjects[0] as? MarkerView
        }
        
        return nil
        #endif
    }
    
}
