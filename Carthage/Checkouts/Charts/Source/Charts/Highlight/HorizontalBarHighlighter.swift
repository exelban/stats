//
//  HorizontalBarHighlighter.swift
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

@objc(HorizontalBarChartHighlighter)
open class HorizontalBarHighlighter: BarHighlighter
{
    open override func getHighlight(x: CGFloat, y: CGFloat) -> Highlight?
    {
        guard let barData = self.chart?.data as? BarChartData else { return nil }

        let pos = getValsForTouch(x: y, y: x)
        guard let high = getHighlight(xValue: Double(pos.y), x: y, y: x) else { return nil }

        if let set = barData.getDataSetByIndex(high.dataSetIndex) as? IBarChartDataSet,
            set.isStacked
        {
            return getStackedHighlight(high: high,
                                       set: set,
                                       xValue: Double(pos.y),
                                       yValue: Double(pos.x))
        }

        return high
    }
    
    internal override func buildHighlights(
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
                .pixelForValues(x: e.y, y: e.x)
            return Highlight(x: e.x, y: e.y, xPx: px.x, yPx: px.y, dataSetIndex: dataSetIndex, axis: set.axisDependency)
        }
    }
    
    internal override func getDistance(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat) -> CGFloat
    {
        return abs(y1 - y2)
    }
}
