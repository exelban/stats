//
//  PieChartRenderer.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics
import UIKit

public class PieChartRenderer: ChartDataRendererBase
{
    internal weak var _chart: PieChartView!
    
    public var drawHoleEnabled = true
    public var holeTransparent = true
    public var holeColor: UIColor? = UIColor.whiteColor()
    public var holeRadiusPercent = CGFloat(0.5)
    public var transparentCircleRadiusPercent = CGFloat(0.55)
    public var centerTextColor = UIColor.blackColor()
    public var centerTextFont = UIFont.systemFontOfSize(12.0)
    public var drawXLabelsEnabled = true
    public var usePercentValuesEnabled = false
    public var centerText: String!
    public var drawCenterTextEnabled = true
    public var centerTextLineBreakMode = NSLineBreakMode.ByTruncatingTail
    public var centerTextRadiusPercent: CGFloat = 1.0
    
    public init(chart: PieChartView, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        _chart = chart
    }
    
    public override func drawData(context context: CGContext?)
    {
        if (_chart !== nil)
        {
            let pieData = _chart.data
            
            if (pieData != nil)
            {
                for set in pieData!.dataSets as! [PieChartDataSet]
                {
                    if set.isVisible && set.entryCount > 0
                    {
                        drawDataSet(context: context, dataSet: set)
                    }
                }
            }
        }
    }
    
    internal func drawDataSet(context context: CGContext?, dataSet: PieChartDataSet)
    {
        var angle = _chart.rotationAngle
        
        var cnt = 0
        
        var entries = dataSet.yVals
        var drawAngles = _chart.drawAngles
        let circleBox = _chart.circleBox
        let radius = _chart.radius
        let innerRadius = drawHoleEnabled && holeTransparent ? radius * holeRadiusPercent : 0.0
        
        CGContextSaveGState(context)
        
        for (var j = 0; j < entries.count; j++)
        {
            let newangle = drawAngles[cnt]
            let sliceSpace = dataSet.sliceSpace
            
            let e = entries[j]
            
            // draw only if the value is greater than zero
            if ((abs(e.value) > 0.000001))
            {
                if (!_chart.needsHighlight(xIndex: e.xIndex,
                    dataSetIndex: _chart.data!.indexOfDataSet(dataSet)))
                {
                    let startAngle = angle + sliceSpace / 2.0
                    var sweepAngle = newangle * _animator.phaseY
                        - sliceSpace / 2.0
                    if (sweepAngle < 0.0)
                    {
                        sweepAngle = 0.0
                    }
                    let endAngle = startAngle + sweepAngle
                    
                    let path = CGPathCreateMutable()
                    CGPathMoveToPoint(path, nil, circleBox.midX, circleBox.midY)
                    CGPathAddArc(path, nil, circleBox.midX, circleBox.midY, radius, startAngle * ChartUtils.Math.FDEG2RAD, endAngle * ChartUtils.Math.FDEG2RAD, false)
                    CGPathCloseSubpath(path)
                    
                    if (innerRadius > 0.0)
                    {
                        CGPathMoveToPoint(path, nil, circleBox.midX, circleBox.midY)
                        CGPathAddArc(path, nil, circleBox.midX, circleBox.midY, innerRadius, startAngle * ChartUtils.Math.FDEG2RAD, endAngle * ChartUtils.Math.FDEG2RAD, false)
                        CGPathCloseSubpath(path)
                    }
                    
                    CGContextBeginPath(context)
                    CGContextAddPath(context, path)
                    CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                    CGContextEOFillPath(context)
                }
            }
            
            angle += newangle * _animator.phaseX
            cnt++
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        let center = _chart.centerCircleBox
        
        // get whole the radius
        var r = _chart.radius
        let rotationAngle = _chart.rotationAngle
        var drawAngles = _chart.drawAngles
        var absoluteAngles = _chart.absoluteAngles
        
        var off = r / 10.0 * 3.0
        
        if (drawHoleEnabled)
        {
            off = (r - (r * _chart.holeRadiusPercent)) / 2.0
        }
        
        r -= off; // offset to keep things inside the chart
        
        let data: ChartData! = _chart.data
        if (data === nil)
        {
            return
        }
        
        let defaultValueFormatter = _chart.valueFormatter
        
        var dataSets = data.dataSets
        let drawXVals = drawXLabelsEnabled
        
        var cnt = 0
        
        for (var i = 0; i < dataSets.count; i++)
        {
            let dataSet = dataSets[i] as! PieChartDataSet
            
            let drawYVals = dataSet.isDrawValuesEnabled
            
            if (!drawYVals && !drawXVals)
            {
                continue
            }
            
            let valueFont = dataSet.valueFont
            let valueTextColor = dataSet.valueTextColor
            
            var formatter = dataSet.valueFormatter
            if (formatter === nil)
            {
                formatter = defaultValueFormatter
            }
            
            var entries = dataSet.yVals
            
            for (var j = 0, maxEntry = Int(min(ceil(CGFloat(entries.count) * _animator.phaseX), CGFloat(entries.count))); j < maxEntry; j++)
            {
                if (drawXVals && !drawYVals && (j >= data.xValCount || data.xVals[j] == nil))
                {
                    continue
                }
                
                // offset needed to center the drawn text in the slice
                let offset = drawAngles[cnt] / 2.0
                
                // calculate the text position
                let x = (r * cos(((rotationAngle + absoluteAngles[cnt] - offset) * _animator.phaseY) * ChartUtils.Math.FDEG2RAD) + center.x)
                var y = (r * sin(((rotationAngle + absoluteAngles[cnt] - offset) * _animator.phaseY) * ChartUtils.Math.FDEG2RAD) + center.y)
                
                let value = usePercentValuesEnabled ? entries[j].value / data.yValueSum * 100.0 : entries[j].value
                
                let val = formatter!.stringFromNumber(value)!
                
                let lineHeight = valueFont.lineHeight
                y -= lineHeight
                
                // draw everything, depending on settings
                if (drawXVals && drawYVals)
                {
                    ChartUtils.drawText(context: context, text: val, point: CGPoint(x: x, y: y), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                    
                    if (j < data.xValCount && data.xVals[j] != nil)
                    {
                        ChartUtils.drawText(context: context, text: data.xVals[j]!, point: CGPoint(x: x, y: y + lineHeight), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                    }
                }
                else if (drawXVals && !drawYVals)
                {
                    ChartUtils.drawText(context: context, text: data.xVals[j]!, point: CGPoint(x: x, y: y + lineHeight / 2.0), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
                else if (!drawXVals && drawYVals)
                {
                    ChartUtils.drawText(context: context, text: val, point: CGPoint(x: x, y: y + lineHeight / 2.0), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
                
                cnt++
            }
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
        drawHole(context: context)
        drawCenterText(context: context)
    }
    
    /// draws the hole in the center of the chart and the transparent circle / hole
    private func drawHole(context context: CGContext?)
    {
        if (_chart.drawHoleEnabled)
        {
            CGContextSaveGState(context)
            
            let radius = _chart.radius
            let holeRadius = radius * holeRadiusPercent
            let center = _chart.centerCircleBox
            
            if (holeColor !== nil && holeColor != UIColor.clearColor())
            {
                // draw the hole-circle
                CGContextSetFillColorWithColor(context, holeColor!.CGColor)
                CGContextFillEllipseInRect(context, CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2.0, height: holeRadius * 2.0))
            }
            
            if (transparentCircleRadiusPercent > holeRadiusPercent)
            {
                let secondHoleRadius = radius * transparentCircleRadiusPercent
                
                // make transparent
                CGContextSetFillColorWithColor(context, holeColor!.colorWithAlphaComponent(CGFloat(0x60) / CGFloat(0xFF)).CGColor)
                
                // draw the transparent-circle
                CGContextFillEllipseInRect(context, CGRect(x: center.x - secondHoleRadius, y: center.y - secondHoleRadius, width: secondHoleRadius * 2.0, height: secondHoleRadius * 2.0))
            }
            
            CGContextRestoreGState(context)
        }
    }
    
    /// draws the description text in the center of the pie chart makes most sense when center-hole is enabled
    private func drawCenterText(context context: CGContext?)
    {
        if (drawCenterTextEnabled && centerText != nil && centerText.characters.count > 0)
        {
            let center = _chart.centerCircleBox
            let innerRadius = drawHoleEnabled && holeTransparent ? _chart.radius * holeRadiusPercent : _chart.radius
            let holeRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2.0, height: innerRadius * 2.0)
            var boundingRect = holeRect
            
            if (centerTextRadiusPercent > 0.0)
            {
                boundingRect = CGRectInset(boundingRect, (boundingRect.width - boundingRect.width * centerTextRadiusPercent) / 2.0, (boundingRect.height - boundingRect.height * centerTextRadiusPercent) / 2.0)
            }
            
            let centerTextNs = self.centerText as NSString
            
            let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
            paragraphStyle.lineBreakMode = centerTextLineBreakMode
            paragraphStyle.alignment = .Center
            
            let drawingAttrs = [NSFontAttributeName: centerTextFont, NSParagraphStyleAttributeName: paragraphStyle, NSForegroundColorAttributeName: centerTextColor]
            
            let textBounds = centerTextNs.boundingRectWithSize(boundingRect.size, options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], attributes: drawingAttrs, context: nil)
            
            var drawingRect = boundingRect
            drawingRect.origin.x += (boundingRect.size.width - textBounds.size.width) / 2.0
            drawingRect.origin.y += (boundingRect.size.height - textBounds.size.height) / 2.0
            drawingRect.size = textBounds.size
            
            CGContextSaveGState(context)

            let clippingPath = CGPathCreateWithEllipseInRect(holeRect, nil)
            CGContextBeginPath(context)
            CGContextAddPath(context, clippingPath)
            CGContextClip(context)
            
            centerTextNs.drawWithRect(drawingRect, options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], attributes: drawingAttrs, context: nil)
            
            CGContextRestoreGState(context)
        }
    }
    
    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        if (_chart.data === nil)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        let rotationAngle = _chart.rotationAngle
        var angle = CGFloat(0.0)
        
        var drawAngles = _chart.drawAngles
        var absoluteAngles = _chart.absoluteAngles
        
        let innerRadius = drawHoleEnabled && holeTransparent ? _chart.radius * holeRadiusPercent : 0.0
        
        for (var i = 0; i < indices.count; i++)
        {
            // get the index to highlight
            let xIndex = indices[i].xIndex
            if (xIndex >= drawAngles.count)
            {
                continue
            }
            
            let set = _chart.data?.getDataSetByIndex(indices[i].dataSetIndex) as! PieChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
            if (xIndex == 0)
            {
                angle = rotationAngle
            }
            else
            {
                angle = rotationAngle + absoluteAngles[xIndex - 1]
            }
            
            angle *= _animator.phaseY
            
            let sliceDegrees = drawAngles[xIndex]
            
            let shift = set.selectionShift
            let circleBox = _chart.circleBox
            
            let highlighted = CGRect(
                x: circleBox.origin.x - shift,
                y: circleBox.origin.y - shift,
                width: circleBox.size.width + shift * 2.0,
                height: circleBox.size.height + shift * 2.0)
            
            CGContextSetFillColorWithColor(context, set.colorAt(xIndex).CGColor)
            
            // redefine the rect that contains the arc so that the highlighted pie is not cut off
            
            let startAngle = angle + set.sliceSpace / 2.0
            var sweepAngle = sliceDegrees * _animator.phaseY - set.sliceSpace / 2.0
            if (sweepAngle < 0.0)
            {
                sweepAngle = 0.0
            }
            let endAngle = startAngle + sweepAngle
            
            let path = CGPathCreateMutable()
            CGPathMoveToPoint(path, nil, highlighted.midX, highlighted.midY)
            CGPathAddArc(path, nil, highlighted.midX, highlighted.midY, highlighted.size.width / 2.0, startAngle * ChartUtils.Math.FDEG2RAD, endAngle * ChartUtils.Math.FDEG2RAD, false)
            CGPathCloseSubpath(path)
            
            if (innerRadius > 0.0)
            {
                CGPathMoveToPoint(path, nil, highlighted.midX, highlighted.midY)
                CGPathAddArc(path, nil, highlighted.midX, highlighted.midY, innerRadius, startAngle * ChartUtils.Math.FDEG2RAD, endAngle * ChartUtils.Math.FDEG2RAD, false)
                CGPathCloseSubpath(path)
            }
            
            CGContextBeginPath(context)
            CGContextAddPath(context, path)
            CGContextEOFillPath(context)
        }
        
        CGContextRestoreGState(context)
    }
}