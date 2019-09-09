//
//  ChartHighlighter.swift
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

open class ChartHighlighter : NSObject, IHighlighter
{
    /// instance of the data-provider
    @objc open weak var chart: ChartDataProvider?
    
    @objc public init(chart: ChartDataProvider)
    {
        self.chart = chart
    }
    
    open func getHighlight(x: CGFloat, y: CGFloat) -> Highlight?
    {
        let xVal = Double(getValsForTouch(x: x, y: y).x)
        return getHighlight(xValue: xVal, x: x, y: y)
    }
    
    /// - Parameters:
    ///   - x:
    /// - Returns: The corresponding x-pos for a given touch-position in pixels.
    @objc open func getValsForTouch(x: CGFloat, y: CGFloat) -> CGPoint
    {
        guard let chart = self.chart as? BarLineScatterCandleBubbleChartDataProvider else { return .zero }
        
        // take any transformer to determine the values
        return chart.getTransformer(forAxis: .left).valueForTouchPoint(x: x, y: y)
    }
    
    /// - Parameters:
    ///   - xValue:
    ///   - x:
    ///   - y:
    /// - Returns: The corresponding ChartHighlight for a given x-value and xy-touch position in pixels.
    @objc open func getHighlight(xValue xVal: Double, x: CGFloat, y: CGFloat) -> Highlight?
    {
        guard let chart = chart else { return nil }
        
        let closestValues = getHighlights(xValue: xVal, x: x, y: y)
        guard !closestValues.isEmpty else { return nil }
        
        let leftAxisMinDist = getMinimumDistance(closestValues: closestValues, y: y, axis: .left)
        let rightAxisMinDist = getMinimumDistance(closestValues: closestValues, y: y, axis: .right)
        
        let axis: YAxis.AxisDependency = leftAxisMinDist < rightAxisMinDist ? .left : .right
        
        let detail = closestSelectionDetailByPixel(closestValues: closestValues, x: x, y: y, axis: axis, minSelectionDistance: chart.maxHighlightDistance)
        
        return detail
    }
    
    /// - Parameters:
    ///   - xValue: the transformed x-value of the x-touch position
    ///   - x: touch position
    ///   - y: touch position
    /// - Returns: A list of Highlight objects representing the entries closest to the given xVal.
    /// The returned list contains two objects per DataSet (closest rounding up, closest rounding down).
    @objc open func getHighlights(xValue: Double, x: CGFloat, y: CGFloat) -> [Highlight]
    {
        var vals = [Highlight]()
        
        guard let data = self.data else { return vals }
        
        for i in 0 ..< data.dataSetCount
        {
            guard
                let dataSet = data.getDataSetByIndex(i),
                dataSet.isHighlightEnabled      // don't include datasets that cannot be highlighted
                else { continue }
            

            // extract all y-values from all DataSets at the given x-value.
            // some datasets (i.e bubble charts) make sense to have multiple values for an x-value. We'll have to find a way to handle that later on. It's more complicated now when x-indices are floating point.
            vals.append(contentsOf: buildHighlights(dataSet: dataSet, dataSetIndex: i, xValue: xValue, rounding: .closest))
        }
        
        return vals
    }
    
    /// - Returns: An array of `Highlight` objects corresponding to the selected xValue and dataSetIndex.
    internal func buildHighlights(
        dataSet set: IChartDataSet,
        dataSetIndex: Int,
        xValue: Double,
        rounding: ChartDataSetRounding) -> [Highlight]
    {
        guard let chart = self.chart as? BarLineScatterCandleBubbleChartDataProvider else { return [] }
        
        var entries = set.entriesForXValue(xValue)
        if entries.count == 0, let closest = set.entryForXValue(xValue, closestToY: .nan, rounding: rounding)
        {
            // Try to find closest x-value and take all entries for that x-value
            entries = set.entriesForXValue(closest.x)
        }

        return entries.map { e in
            let px = chart.getTransformer(forAxis: set.axisDependency)
                .pixelForValues(x: e.x, y: e.y)
            
            return Highlight(x: e.x, y: e.y, xPx: px.x, yPx: px.y, dataSetIndex: dataSetIndex, axis: set.axisDependency)
        }
    }

    // - MARK: - Utilities
    
    /// - Returns: The `ChartHighlight` of the closest value on the x-y cartesian axes
    internal func closestSelectionDetailByPixel(
        closestValues: [Highlight],
        x: CGFloat,
        y: CGFloat,
        axis: YAxis.AxisDependency?,
        minSelectionDistance: CGFloat) -> Highlight?
    {
        var distance = minSelectionDistance
        var closest: Highlight?
        
        for high in closestValues
        {
            if axis == nil || high.axis == axis
            {
                let cDistance = getDistance(x1: x, y1: y, x2: high.xPx, y2: high.yPx)

                if cDistance < distance
                {
                    closest = high
                    distance = cDistance
                }
            }
        }
        
        return closest
    }
    
    /// - Returns: The minimum distance from a touch-y-value (in pixels) to the closest y-value (in pixels) that is displayed in the chart.
    internal func getMinimumDistance(
        closestValues: [Highlight],
        y: CGFloat,
        axis: YAxis.AxisDependency
    ) -> CGFloat {
        var distance = CGFloat.greatestFiniteMagnitude
        
        for high in closestValues where high.axis == axis
        {
            let tempDistance = abs(getHighlightPos(high: high) - y)
            if tempDistance < distance
            {
                distance = tempDistance
            }
        }
        
        return distance
    }
    
    internal func getHighlightPos(high: Highlight) -> CGFloat
    {
        return high.yPx
    }
    
    internal func getDistance(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat
    {
        return hypot(x1 - x2, y1 - y2)
    }
    
    internal var data: ChartData?
    {
        return chart?.data
    }
}
