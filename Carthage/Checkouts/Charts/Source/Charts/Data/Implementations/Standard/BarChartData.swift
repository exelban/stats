//
//  BarChartData.swift
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

open class BarChartData: BarLineScatterCandleBubbleChartData
{
    public override init()
    {
        super.init()
    }
    
    public override init(dataSets: [IChartDataSet]?)
    {
        super.init(dataSets: dataSets)
    }
    
    /// The width of the bars on the x-axis, in values (not pixels)
    ///
    /// **default**: 0.85
    @objc open var barWidth = Double(0.85)
    
    /// Groups all BarDataSet objects this data object holds together by modifying the x-value of their entries.
    /// Previously set x-values of entries will be overwritten. Leaves space between bars and groups as specified by the parameters.
    /// Do not forget to call notifyDataSetChanged() on your BarChart object after calling this method.
    ///
    /// - Parameters:
    ///   - fromX: the starting point on the x-axis where the grouping should begin
    ///   - groupSpace: The space between groups of bars in values (not pixels) e.g. 0.8f for bar width 1f
    ///   - barSpace: The space between individual bars in values (not pixels) e.g. 0.1f for bar width 1f
    @objc open func groupBars(fromX: Double, groupSpace: Double, barSpace: Double)
    {
        let setCount = _dataSets.count
        if setCount <= 1
        {
            print("BarData needs to hold at least 2 BarDataSets to allow grouping.", terminator: "\n")
            return
        }
        
        let max = maxEntryCountSet
        let maxEntryCount = max?.entryCount ?? 0
        
        let groupSpaceWidthHalf = groupSpace / 2.0
        let barSpaceHalf = barSpace / 2.0
        let barWidthHalf = self.barWidth / 2.0
        
        var fromX = fromX
        
        let interval = groupWidth(groupSpace: groupSpace, barSpace: barSpace)

        for i in stride(from: 0, to: maxEntryCount, by: 1)
        {
            let start = fromX
            fromX += groupSpaceWidthHalf
            
            (_dataSets as? [IBarChartDataSet])?.forEach { set in
                fromX += barSpaceHalf
                fromX += barWidthHalf
                
                if i < set.entryCount
                {
                    if let entry = set.entryForIndex(i)
                    {
                        entry.x = fromX
                    }
                }
                
                fromX += barWidthHalf
                fromX += barSpaceHalf
            }
            
            fromX += groupSpaceWidthHalf
            let end = fromX
            let innerInterval = end - start
            let diff = interval - innerInterval
            
            // correct rounding errors
            if diff > 0 || diff < 0
            {
                fromX += diff
            }

        }
        
        notifyDataChanged()
    }
    
    /// In case of grouped bars, this method returns the space an individual group of bar needs on the x-axis.
    ///
    /// - Parameters:
    ///   - groupSpace:
    ///   - barSpace:
    @objc open func groupWidth(groupSpace: Double, barSpace: Double) -> Double
    {
        return Double(_dataSets.count) * (self.barWidth + barSpace) + groupSpace
    }
    
}
