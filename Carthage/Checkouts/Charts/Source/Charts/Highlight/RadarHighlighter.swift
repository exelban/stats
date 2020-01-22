//
//  RadarHighlighter.swift
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

@objc(RadarChartHighlighter)
open class RadarHighlighter: PieRadarHighlighter
{
    open override func closestHighlight(index: Int, x: CGFloat, y: CGFloat) -> Highlight?
    {
        guard let chart = self.chart as? RadarChartView else { return nil }
        
        let highlights = getHighlights(forIndex: index)
        
        let distanceToCenter = Double(chart.distanceToCenter(x: x, y: y) / chart.factor)
        
        var closest: Highlight?
        var distance = Double.greatestFiniteMagnitude
        
        for high in highlights
        {
            let cdistance = abs(high.y - distanceToCenter)
            if cdistance < distance
            {
                closest = high
                distance = cdistance
            }
        }
        
        return closest
    }
    
    /// - Parameters:
    ///   - index:
    /// - Returns: An array of Highlight objects for the given index.
    /// The Highlight objects give information about the value at the selected index and DataSet it belongs to.
    internal func getHighlights(forIndex index: Int) -> [Highlight]
    {
        var vals = [Highlight]()
        
        guard
            let chart = self.chart as? RadarChartView,
            let chartData = chart.data
            else { return vals }
        
        let phaseX = chart.chartAnimator.phaseX
        let phaseY = chart.chartAnimator.phaseY
        let sliceangle = chart.sliceAngle
        let factor = chart.factor

        for i in chartData.dataSets.indices
        {
            guard
                let dataSet = chartData.getDataSetByIndex(i),
                let entry = dataSet.entryForIndex(index)
                else { continue }
            
            let y = (entry.y - chart.chartYMin)
            
            let p = chart.centerOffsets.moving(distance: CGFloat(y) * factor * CGFloat(phaseY),
                                               atAngle: sliceangle * CGFloat(index) * CGFloat(phaseX) + chart.rotationAngle)

            let highlight = Highlight(x: Double(index), y: entry.y, xPx: p.x, yPx: p.y, dataSetIndex: i, axis: dataSet.axisDependency)
            vals.append(highlight)
        }
        
        return vals
    }
}
