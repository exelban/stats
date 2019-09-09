//
//  LineRadarRenderer.swift
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

@objc(LineRadarChartRenderer)
open class LineRadarRenderer: LineScatterCandleRadarRenderer
{
    public override init(animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
    }
    
    /// Draws the provided path in filled mode with the provided drawable.
    @objc open func drawFilledPath(context: CGContext, path: CGPath, fill: Fill, fillAlpha: CGFloat)
    {
        
        context.saveGState()
        context.beginPath()
        context.addPath(path)
        
        // filled is usually drawn with less alpha
        context.setAlpha(fillAlpha)
        
        fill.fillPath(context: context, rect: viewPortHandler.contentRect)
        
        context.restoreGState()
    }
    
    /// Draws the provided path in filled mode with the provided color and alpha.
    @objc open func drawFilledPath(context: CGContext, path: CGPath, fillColor: NSUIColor, fillAlpha: CGFloat)
    {
        context.saveGState()
        context.beginPath()
        context.addPath(path)
        
        // filled is usually drawn with less alpha
        context.setAlpha(fillAlpha)
        
        context.setFillColor(fillColor.cgColor)
        context.fillPath()
        
        context.restoreGState()
    }
}
