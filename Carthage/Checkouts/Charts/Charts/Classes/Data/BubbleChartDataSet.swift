//
//  BubbleChartDataSet.swift
//  Charts
//
//  Bubble chart implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics
import UIKit

public class BubbleChartDataSet: BarLineScatterCandleBubbleChartDataSet
{
    internal var _xMax = Double(0.0)
    internal var _xMin = Double(0.0)
    internal var _maxSize = CGFloat(0.0)

    public var xMin: Double { return _xMin }
    public var xMax: Double { return _xMax }
    public var maxSize: CGFloat { return _maxSize }
    
    public func setColor(color: UIColor, alpha: CGFloat)
    {
        super.setColor(color.colorWithAlphaComponent(alpha))
    }
    
    internal override func calcMinMax(start start: Int, end: Int)
    {
        if (yVals.count == 0)
        {
            return
        }
        
        let entries = yVals as! [BubbleChartDataEntry]
    
        // need chart width to guess this properly
        
        var endValue : Int
        
        if end == 0
        {
            endValue = entries.count - 1
        }
        else
        {
            endValue = end
        }
        
        _lastStart = start
        _lastEnd = end
        
        _yMin = yMin(entries[start])
        _yMax = yMax(entries[start])
        
        for (var i = start; i <= endValue; i++)
        {
            let entry = entries[i]

            let ymin = yMin(entry)
            let ymax = yMax(entry)
            
            if (ymin < _yMin)
            {
                _yMin = ymin
            }
            
            if (ymax > _yMax)
            {
                _yMax = ymax
            }
            
            let xmin = xMin(entry)
            let xmax = xMax(entry)
            
            if (xmin < _xMin)
            {
                _xMin = xmin
            }
            
            if (xmax > _xMax)
            {
                _xMax = xmax
            }

            let size = largestSize(entry)
            
            if (size > _maxSize)
            {
                _maxSize = size
            }
        }
    }
    
    /// Sets/gets the width of the circle that surrounds the bubble when highlighted
    public var highlightCircleWidth: CGFloat = 2.5
    
    private func yMin(entry: BubbleChartDataEntry) -> Double
    {
        return entry.value
    }
    
    private func yMax(entry: BubbleChartDataEntry) -> Double
    {
        return entry.value
    }
    
    private func xMin(entry: BubbleChartDataEntry) -> Double
    {
        return Double(entry.xIndex)
    }
    
    private func xMax(entry: BubbleChartDataEntry) -> Double
    {
        return Double(entry.xIndex)
    }
    
    private func largestSize(entry: BubbleChartDataEntry) -> CGFloat
    {
        return entry.size
    }
}
