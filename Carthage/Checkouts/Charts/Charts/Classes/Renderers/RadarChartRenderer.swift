//
//  RadarChartRenderer.swift
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

public class RadarChartRenderer: LineScatterCandleRadarChartRenderer
{
    internal weak var _chart: RadarChartView!

    public init(chart: RadarChartView, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        _chart = chart
    }
    
    public override func drawData(context context: CGContext?)
    {
        if (_chart !== nil)
        {
            let radarData = _chart.data
            
            if (radarData != nil)
            {
                for set in radarData!.dataSets as! [RadarChartDataSet]
                {
                    if set.isVisible && set.entryCount > 0
                    {
                        drawDataSet(context: context, dataSet: set)
                    }
                }
            }
        }
    }
    
    internal func drawDataSet(context context: CGContext?, dataSet: RadarChartDataSet)
    {
        CGContextSaveGState(context)
        
        let sliceangle = _chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = _chart.factor
        
        let center = _chart.centerOffsets
        var entries = dataSet.yVals
        let path = CGPathCreateMutable()
        var hasMovedToPoint = false
        
        for (var j = 0; j < entries.count; j++)
        {
            let e = entries[j]
            
            let p = ChartUtils.getPosition(center: center, dist: CGFloat(e.value - _chart.chartYMin) * factor, angle: sliceangle * CGFloat(j) + _chart.rotationAngle)
            
            if (p.x.isNaN)
            {
                continue
            }
            
            if (!hasMovedToPoint)
            {
                CGPathMoveToPoint(path, nil, p.x, p.y)
                hasMovedToPoint = true
            }
            else
            {
                CGPathAddLineToPoint(path, nil, p.x, p.y)
            }
        }
        
        CGPathCloseSubpath(path)
        
        // draw filled
        if (dataSet.isDrawFilledEnabled)
        {
            CGContextSetFillColorWithColor(context, dataSet.colorAt(0).CGColor)
            CGContextSetAlpha(context, dataSet.fillAlpha)
            
            CGContextBeginPath(context)
            CGContextAddPath(context, path)
            CGContextFillPath(context)
        }
        
        // draw the line (only if filled is disabled or alpha is below 255)
        if (!dataSet.isDrawFilledEnabled || dataSet.fillAlpha < 1.0)
        {
            CGContextSetStrokeColorWithColor(context, dataSet.colorAt(0).CGColor)
            CGContextSetLineWidth(context, dataSet.lineWidth)
            CGContextSetAlpha(context, 1.0)
            
            CGContextBeginPath(context)
            CGContextAddPath(context, path)
            CGContextStrokePath(context)
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        if (_chart.data === nil)
        {
            return
        }
        
        let data = _chart.data!
        
        let defaultValueFormatter = _chart.valueFormatter
        
        let sliceangle = _chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = _chart.factor
        
        let center = _chart.centerOffsets
        
        let yoffset = CGFloat(5.0)
        
        for (var i = 0, count = data.dataSetCount; i < count; i++)
        {
            let dataSet = data.getDataSetByIndex(i) as! RadarChartDataSet
            
            if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
            {
                continue
            }
            
            var entries = dataSet.yVals
            
            for (var j = 0; j < entries.count; j++)
            {
                let e = entries[j]
                
                let p = ChartUtils.getPosition(center: center, dist: CGFloat(e.value) * factor, angle: sliceangle * CGFloat(j) + _chart.rotationAngle)
                
                let valueFont = dataSet.valueFont
                let valueTextColor = dataSet.valueTextColor
                
                var formatter = dataSet.valueFormatter
                if (formatter === nil)
                {
                    formatter = defaultValueFormatter
                }
                
                ChartUtils.drawText(context: context, text: formatter!.stringFromNumber(e.value)!, point: CGPoint(x: p.x, y: p.y - yoffset - valueFont.lineHeight), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
            }
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
        drawWeb(context: context)
    }
    
    private var _webLineSegmentsBuffer = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawWeb(context context: CGContext?)
    {
        let sliceangle = _chart.sliceAngle
        
        CGContextSaveGState(context)
        
        // calculate the factor that is needed for transforming the value to
        // pixels
        let factor = _chart.factor
        let rotationangle = _chart.rotationAngle
        
        let center = _chart.centerOffsets
        
        // draw the web lines that come from the center
        CGContextSetLineWidth(context, _chart.webLineWidth)
        CGContextSetStrokeColorWithColor(context, _chart.webColor.CGColor)
        CGContextSetAlpha(context, _chart.webAlpha)
        
        let xIncrements = 1 + _chart.skipWebLineCount
        
        for var i = 0, xValCount = _chart.data!.xValCount; i < xValCount; i += xIncrements
        {
            let p = ChartUtils.getPosition(center: center, dist: CGFloat(_chart.yRange) * factor, angle: sliceangle * CGFloat(i) + rotationangle)
            
            _webLineSegmentsBuffer[0].x = center.x
            _webLineSegmentsBuffer[0].y = center.y
            _webLineSegmentsBuffer[1].x = p.x
            _webLineSegmentsBuffer[1].y = p.y
            
            CGContextStrokeLineSegments(context, _webLineSegmentsBuffer, 2)
        }
        
        // draw the inner-web
        CGContextSetLineWidth(context, _chart.innerWebLineWidth)
        CGContextSetStrokeColorWithColor(context, _chart.innerWebColor.CGColor)
        CGContextSetAlpha(context, _chart.webAlpha)
        
        let labelCount = _chart.yAxis.entryCount
        
        for (var j = 0; j < labelCount; j++)
        {
            for (var i = 0, xValCount = _chart.data!.xValCount; i < xValCount; i++)
            {
                let r = CGFloat(_chart.yAxis.entries[j] - _chart.chartYMin) * factor

                let p1 = ChartUtils.getPosition(center: center, dist: r, angle: sliceangle * CGFloat(i) + rotationangle)
                let p2 = ChartUtils.getPosition(center: center, dist: r, angle: sliceangle * CGFloat(i + 1) + rotationangle)
                
                _webLineSegmentsBuffer[0].x = p1.x
                _webLineSegmentsBuffer[0].y = p1.y
                _webLineSegmentsBuffer[1].x = p2.x
                _webLineSegmentsBuffer[1].y = p2.y
                
                CGContextStrokeLineSegments(context, _webLineSegmentsBuffer, 2)
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    private var _highlightPointBuffer = CGPoint()

    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        if (_chart.data === nil)
        {
            return
        }
        
        let data = _chart.data as! RadarChartData
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, data.highlightLineWidth)
        if (data.highlightLineDashLengths != nil)
        {
            CGContextSetLineDash(context, data.highlightLineDashPhase, data.highlightLineDashLengths!, data.highlightLineDashLengths!.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        let sliceangle = _chart.sliceAngle
        let factor = _chart.factor
        
        let center = _chart.centerOffsets
        
        for (var i = 0; i < indices.count; i++)
        {
            let set = _chart.data?.getDataSetByIndex(indices[i].dataSetIndex) as! RadarChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
            CGContextSetStrokeColorWithColor(context, set.highlightColor.CGColor)
            
            // get the index to highlight
            let xIndex = indices[i].xIndex
            
            let e = set.entryForXIndex(xIndex)
            if (e === nil || e!.xIndex != xIndex)
            {
                continue
            }
            
            let j = set.entryIndex(entry: e!, isEqual: true)
            let y = (e!.value - _chart.chartYMin)
            
            if (y.isNaN)
            {
                continue
            }
            
            _highlightPointBuffer = ChartUtils.getPosition(center: center, dist: CGFloat(y) * factor,
                angle: sliceangle * CGFloat(j) + _chart.rotationAngle)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        CGContextRestoreGState(context)
    }
}