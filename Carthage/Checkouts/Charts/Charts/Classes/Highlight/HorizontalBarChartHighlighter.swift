//
//  HorizontalBarChartHighlighter.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 26/7/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

internal class HorizontalBarChartHighlighter: BarChartHighlighter
{
    internal override func getHighlight(x x: Double, y: Double) -> ChartHighlight?
    {
        let h = super.getHighlight(x: x, y: y)
        
        if h === nil
        {
            return h
        }
        else
        {
            if let set = _chart?.data?.getDataSetByIndex(h!.dataSetIndex) as? BarChartDataSet
            {
                if set.isStacked
                {
                    // create an array of the touch-point
                    var pt = CGPoint()
                    pt.x = CGFloat(y)
                    
                    // take any transformer to determine the x-axis value
                    _chart?.getTransformer(set.axisDependency).pixelToValue(&pt)
                    
                    return getStackedHighlight(old: h, set: set, xIndex: h!.xIndex, dataSetIndex: h!.dataSetIndex, yValue: Double(pt.x))
                }
            }
            
            return h
        }
    }
    
    internal override func getXIndex(x: Double) -> Int
    {
        if let barChartData = _chart?.data as? BarChartData
        {
            if !barChartData.isGrouped
            {
                // create an array of the touch-point
                var pt = CGPoint(x: 0.0, y: x)
                
                // take any transformer to determine the x-axis value
                _chart?.getTransformer(ChartYAxis.AxisDependency.Left).pixelToValue(&pt)
                
                return Int(round(pt.y))
            }
            else
            {
                let baseNoSpace = getBase(x)
                
                let setCount = barChartData.dataSetCount
                var xIndex = Int(baseNoSpace) / setCount
                
                let valCount = barChartData.xValCount
                
                if xIndex < 0
                {
                    xIndex = 0
                }
                else if xIndex >= valCount
                {
                    xIndex = valCount - 1
                }
                
                return xIndex
            }
        }
        else
        {
            return 0
        }
    }
    
    /// Returns the base y-value to the corresponding x-touch value in pixels.
    /// - parameter y:
    /// - returns:
    internal override func getBase(y: Double) -> Double
    {
        if let barChartData = _chart?.data as? BarChartData
        {
            // create an array of the touch-point
            var pt = CGPoint()
            pt.y = CGFloat(y)
            
            // take any transformer to determine the x-axis value
            _chart?.getTransformer(ChartYAxis.AxisDependency.Left).pixelToValue(&pt)
            let yVal = Double(pt.y)
            
            let setCount = barChartData.dataSetCount ?? 0
            
            // calculate how often the group-space appears
            let steps = Int(yVal / (Double(setCount) + Double(barChartData.groupSpace)))
            
            let groupSpaceSum = Double(barChartData.groupSpace) * Double(steps)
            
            let baseNoSpace = yVal - groupSpaceSum
            
            return baseNoSpace
        }
        else
        {
            return 0.0
        }
    }
}
