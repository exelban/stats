//
//  ChartYAxisRendererRadarChart.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 3/3/15.
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

public class ChartYAxisRendererRadarChart: ChartYAxisRenderer
{
    private weak var _chart: RadarChartView!
    
    public init(viewPortHandler: ChartViewPortHandler, yAxis: ChartYAxis, chart: RadarChartView)
    {
        super.init(viewPortHandler: viewPortHandler, yAxis: yAxis, transformer: nil)
        
        _chart = chart
    }
 
    public override func computeAxis(yMin yMin: Double, yMax: Double)
    {
        computeAxisValues(min: yMin, max: yMax)
    }
    
    internal override func computeAxisValues(min yMin: Double, max yMax: Double)
    {
        let labelCount = _yAxis.labelCount
        let range = abs(yMax - yMin)
        
        if (labelCount == 0 || range <= 0)
        {
            _yAxis.entries = [Double]()
            return
        }
        
        let rawInterval = range / Double(labelCount)
        var interval = ChartUtils.roundToNextSignificant(number: Double(rawInterval))
        let intervalMagnitude = pow(10.0, round(log10(interval)))
        let intervalSigDigit = Int(interval / intervalMagnitude)
        
        if (intervalSigDigit > 5)
        {
            // Use one order of magnitude higher, to avoid intervals like 0.9 or
            // 90
            interval = floor(10 * intervalMagnitude)
        }
        
        // force label count
        if _yAxis.isForceLabelsEnabled
        {
            let step = Double(range) / Double(labelCount - 1)
            
            if _yAxis.entries.count < labelCount
            {
                // Ensure stops contains at least numStops elements.
                _yAxis.entries.removeAll(keepCapacity: true)
            }
            else
            {
                _yAxis.entries = [Double]()
                _yAxis.entries.reserveCapacity(labelCount)
            }
            
            var v = yMin
            
            for (var i = 0; i < labelCount; i++)
            {
                _yAxis.entries.append(v)
                v += step
            }
            
        }
        else
        {
            // no forced count
            
        // clean old values
        if (_yAxis.entries.count > 0)
        {
            _yAxis.entries.removeAll(keepCapacity: false)
        }
        
        // if the labels should only show min and max
        if (_yAxis.isShowOnlyMinMaxEnabled)
        {
            _yAxis.entries = [Double]()
            _yAxis.entries.append(yMin)
            _yAxis.entries.append(yMax)
        }
        else
        {
                let rawCount = Double(yMin) / interval
                var first = rawCount < 0.0 ? floor(rawCount) * interval : ceil(rawCount) * interval;
            
                if (first < yMin && _yAxis.isStartAtZeroEnabled)
                { // Force the first label to be at the 0 (or smallest negative value)
                    first = yMin
                }
                
            if (first == 0.0)
            { // Fix for IEEE negative zero case (Where value == -0.0, and 0.0 == -0.0)
                first = 0.0
            }
            
            let last = ChartUtils.nextUp(floor(Double(yMax) / interval) * interval)
            
            var f: Double
            var i: Int
            var n = 0
            for (f = first; f <= last; f += interval)
            {
                ++n
            }
            
            if (isnan(_yAxis.customAxisMax))
            {
                n += 1
            }

            if (_yAxis.entries.count < n)
            {
                // Ensure stops contains at least numStops elements.
                _yAxis.entries = [Double](count: n, repeatedValue: 0.0)
            }

            for (f = first, i = 0; i < n; f += interval, ++i)
            {
                _yAxis.entries[i] = Double(f)
            }
        }
        }
        
        if !_yAxis.isStartAtZeroEnabled && _yAxis.entries[0] < yMin
        {
            // If startAtZero is disabled, and the first label is lower that the axis minimum,
            // Then adjust the axis minimum
            _yAxis.axisMinimum = _yAxis.entries[0]
        }
        _yAxis.axisMaximum = _yAxis.entries[_yAxis.entryCount - 1]
        _yAxis.axisRange = abs(_yAxis.axisMaximum - _yAxis.axisMinimum)
    }
    
    public override func renderAxisLabels(context context: CGContext?)
    {
        if (!_yAxis.isEnabled || !_yAxis.isDrawLabelsEnabled)
        {
            return
        }
        
        let labelFont = _yAxis.labelFont
        let labelTextColor = _yAxis.labelTextColor
        
        let center = _chart.centerOffsets
        let factor = _chart.factor
        
        let labelCount = _yAxis.entryCount
        
        let labelLineHeight = _yAxis.labelFont.lineHeight
        
        for (var j = 0; j < labelCount; j++)
        {
            if (j == labelCount - 1 && _yAxis.isDrawTopYLabelEntryEnabled == false)
            {
                break
            }
            
            let r = CGFloat(_yAxis.entries[j] - _yAxis.axisMinimum) * factor
            
            let p = ChartUtils.getPosition(center: center, dist: r, angle: _chart.rotationAngle)
            
            let label = _yAxis.getFormattedLabel(j)
            
            ChartUtils.drawText(context: context, text: label, point: CGPoint(x: p.x + 10.0, y: p.y - labelLineHeight), align: .Left, attributes: [NSFontAttributeName: labelFont, NSForegroundColorAttributeName: labelTextColor])
        }
    }
    
    public override func renderLimitLines(context context: CGContext?)
    {
        var limitLines = _yAxis.limitLines
        
        if (limitLines.count == 0)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        let sliceangle = _chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = _chart.factor
        
        let center = _chart.centerOffsets
        
        for (var i = 0; i < limitLines.count; i++)
        {
            let l = limitLines[i]
            
            CGContextSetStrokeColorWithColor(context, l.lineColor.CGColor)
            CGContextSetLineWidth(context, l.lineWidth)
            if (l.lineDashLengths != nil)
            {
                CGContextSetLineDash(context, l.lineDashPhase, l.lineDashLengths!, l.lineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            let r = CGFloat(l.limit - _chart.chartYMin) * factor
            
            CGContextBeginPath(context)
            
            for (var j = 0, count = _chart.data!.xValCount; j < count; j++)
            {
                let p = ChartUtils.getPosition(center: center, dist: r, angle: sliceangle * CGFloat(j) + _chart.rotationAngle)
                
                if (j == 0)
                {
                    CGContextMoveToPoint(context, p.x, p.y)
                }
                else
                {
                    CGContextAddLineToPoint(context, p.x, p.y)
                }
            }
            
            CGContextClosePath(context)
            
            CGContextStrokePath(context)
        }
        
        CGContextRestoreGState(context)
    }
}