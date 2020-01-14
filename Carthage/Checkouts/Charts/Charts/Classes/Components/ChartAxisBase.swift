//
//  ChartAxisBase.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 23/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

public class ChartAxisBase: ChartComponentBase
{
    public var labelFont = UIFont.systemFontOfSize(10.0)
    public var labelTextColor = UIColor.blackColor()
    
    public var axisLineColor = UIColor.grayColor()
    public var axisLineWidth = CGFloat(0.5)
    public var axisLineDashPhase = CGFloat(0.0)
    public var axisLineDashLengths: [CGFloat]!
    
    public var gridColor = UIColor.grayColor().colorWithAlphaComponent(0.9)
    public var gridLineWidth = CGFloat(0.5)
    public var gridLineDashPhase = CGFloat(0.0)
    public var gridLineDashLengths: [CGFloat]!
    
    public var drawGridLinesEnabled = true
    public var drawAxisLineEnabled = true
    
    /// flag that indicates of the labels of this axis should be drawn or not
    public var drawLabelsEnabled = true
    
    /// Sets the used x-axis offset for the labels on this axis.
    /// **default**: 5.0
    public var xOffset = CGFloat(5.0)
    
    /// Sets the used y-axis offset for the labels on this axis.
    /// **default**: 5.0 (or 0.0 on ChartYAxis)
    public var yOffset = CGFloat(5.0)
    
    /// array of limitlines that can be set for the axis
    private var _limitLines = [ChartLimitLine]()
    
    /// Are the LimitLines drawn behind the data or in front of the data?
    /// 
    /// **default**: false
    public var drawLimitLinesBehindDataEnabled = false

    public override init()
    {
        super.init()
    }
    
    public func getLongestLabel() -> String
    {
        fatalError("getLongestLabel() cannot be called on ChartAxisBase")
    }
    
    public var isDrawGridLinesEnabled: Bool { return drawGridLinesEnabled; }
    
    public var isDrawAxisLineEnabled: Bool { return drawAxisLineEnabled; }
    
    public var isDrawLabelsEnabled: Bool { return drawLabelsEnabled; }
    
    /// Are the LimitLines drawn behind the data or in front of the data?
    /// 
    /// **default**: false
    public var isDrawLimitLinesBehindDataEnabled: Bool { return drawLimitLinesBehindDataEnabled; }
    
    /// Adds a new ChartLimitLine to this axis.
    public func addLimitLine(line: ChartLimitLine)
    {
        _limitLines.append(line)
    }
    
    /// Removes the specified ChartLimitLine from the axis.
    public func removeLimitLine(line: ChartLimitLine)
    {
        for (var i = 0; i < _limitLines.count; i++)
        {
            if (_limitLines[i] === line)
            {
                _limitLines.removeAtIndex(i)
                return
            }
        }
    }
    
    /// Removes all LimitLines from the axis.
    public func removeAllLimitLines()
    {
        _limitLines.removeAll(keepCapacity: false)
    }
    
    /// - returns: the LimitLines of this axis.
    public var limitLines : [ChartLimitLine]
        {
            return _limitLines
    }
}