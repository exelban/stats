//
//  ChartHighlighter.swift
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

internal class ChartHighlighter
{
    /// instance of the data-provider
    internal weak var _chart: BarLineChartViewBase?;
    
    internal init(chart: BarLineChartViewBase)
    {
        _chart = chart;
    }
    
    /// Returns a Highlight object corresponding to the given x- and y- touch positions in pixels.
    /// - parameter x:
    /// - parameter y:
    /// - returns:
    internal func getHighlight(x x: Double, y: Double) -> ChartHighlight?
    {
        let xIndex = getXIndex(x)
        if (xIndex == -Int.max)
        {
            return nil
        }
        
        let dataSetIndex = getDataSetIndex(xIndex: xIndex, x: x, y: y)
        if (dataSetIndex == -Int.max)
        {
            return nil
        }
        
        return ChartHighlight(xIndex: xIndex, dataSetIndex: dataSetIndex)
    }
    
    /// Returns the corresponding x-index for a given touch-position in pixels.
    /// - parameter x:
    /// - returns:
    internal func getXIndex(x: Double) -> Int
    {
        // create an array of the touch-point
        var pt = CGPoint(x: x, y: 0.0)
        
        // take any transformer to determine the x-axis value
        _chart?.getTransformer(ChartYAxis.AxisDependency.Left).pixelToValue(&pt)
        
        return Int(round(pt.x))
    }
    
    /// Returns the corresponding dataset-index for a given xIndex and xy-touch position in pixels.
    /// - parameter xIndex:
    /// - parameter x:
    /// - parameter y:
    /// - returns:
    internal func getDataSetIndex(xIndex xIndex: Int, x: Double, y: Double) -> Int
    {
        let valsAtIndex = getSelectionDetailsAtIndex(xIndex)
        
        let leftdist = ChartUtils.getMinimumDistance(valsAtIndex, val: y, axis: ChartYAxis.AxisDependency.Left)
        let rightdist = ChartUtils.getMinimumDistance(valsAtIndex, val: y, axis: ChartYAxis.AxisDependency.Right)
        
        let axis = leftdist < rightdist ? ChartYAxis.AxisDependency.Left : ChartYAxis.AxisDependency.Right
        
        let dataSetIndex = ChartUtils.closestDataSetIndex(valsAtIndex, value: y, axis: axis)
        
        return dataSetIndex
    }
    
    /// Returns a list of SelectionDetail object corresponding to the given xIndex.
    /// - parameter xIndex:
    /// - returns:
    internal func getSelectionDetailsAtIndex(xIndex: Int) -> [ChartSelectionDetail]
    {
        var vals = [ChartSelectionDetail]()
        var pt = CGPoint()
        
        for (var i = 0, dataSetCount = _chart?.data?.dataSetCount; i < dataSetCount; i++)
        {
            let dataSet = _chart!.data!.getDataSetByIndex(i)
            
            // dont include datasets that cannot be highlighted
            if !dataSet.isHighlightEnabled
            {
                continue
            }
            
            // extract all y-values from all DataSets at the given x-index
            let yVal: Double = dataSet.yValForXIndex(xIndex)
            if yVal.isNaN
            {
                continue
            }
            
            pt.y = CGFloat(yVal)
            
            _chart!.getTransformer(dataSet.axisDependency).pointValueToPixel(&pt)
            
            if !pt.y.isNaN
            {
                vals.append(ChartSelectionDetail(value: Double(pt.y), dataSetIndex: i, dataSet: dataSet))
            }
        }
        
        return vals
    }
}
