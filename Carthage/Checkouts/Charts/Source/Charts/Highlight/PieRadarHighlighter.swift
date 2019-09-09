//
//  PieRadarHighlighter.swift
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

@objc(PieRadarChartHighlighter)
open class PieRadarHighlighter: ChartHighlighter
{    
    open override func getHighlight(x: CGFloat, y: CGFloat) -> Highlight?
    {
        guard let chart = self.chart as? PieRadarChartViewBase else { return nil }
        
        let touchDistanceToCenter = chart.distanceToCenter(x: x, y: y)
        
        // check if a slice was touched
        guard touchDistanceToCenter <= chart.radius else
        {
            // if no slice was touched, highlight nothing
            return nil
        }

        var angle = chart.angleForPoint(x: x ,y: y)

        if chart is PieChartView
        {
            angle /= CGFloat(chart.chartAnimator.phaseY)
        }

        let index = chart.indexForAngle(angle)

        // check if the index could be found
        if index < 0 || index >= chart.data?.maxEntryCountSet?.entryCount ?? 0
        {
            return nil
        }
        else
        {
            return closestHighlight(index: index, x: x, y: y)
        }

    }
    
    /// - Parameters:
    ///   - index:
    ///   - x:
    ///   - y:
    /// - Returns: The closest Highlight object of the given objects based on the touch position inside the chart.
    @objc open func closestHighlight(index: Int, x: CGFloat, y: CGFloat) -> Highlight?
    {
        fatalError("closestHighlight(index, x, y) cannot be called on PieRadarChartHighlighter")
    }
}
