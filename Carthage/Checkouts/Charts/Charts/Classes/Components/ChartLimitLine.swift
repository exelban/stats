//
//  ChartLimitLine.swift
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

/// The limit line is an additional feature for all Line, Bar and ScatterCharts.
/// It allows the displaying of an additional line in the chart that marks a certain maximum / limit on the specified axis (x- or y-axis).
public class ChartLimitLine: ChartComponentBase
{
    @objc
    public enum ChartLimitLabelPosition: Int
    {
        case LeftTop
        case LeftBottom
        case RightTop
        case RightBottom
    }
    
    /// limit / maximum (the y-value or xIndex)
    public var limit = Double(0.0)
    
    private var _lineWidth = CGFloat(2.0)
    public var lineColor = UIColor(red: 237.0/255.0, green: 91.0/255.0, blue: 91.0/255.0, alpha: 1.0)
    public var lineDashPhase = CGFloat(0.0)
    public var lineDashLengths: [CGFloat]?
    public var valueTextColor = UIColor.blackColor()
    public var valueFont = UIFont.systemFontOfSize(13.0)
    public var label = ""
    public var labelPosition = ChartLimitLabelPosition.RightTop
    
    public override init()
    {
        super.init()
    }
    
    public init(limit: Double)
    {
        super.init()
        self.limit = limit
    }
    
    public init(limit: Double, label: String)
    {
        super.init()
        self.limit = limit
        self.label = label
    }
    
    /// set the line width of the chart (min = 0.2, max = 12); default 2
    public var lineWidth: CGFloat
    {
        get
        {
            return _lineWidth
        }
        set
        {
            if (newValue < 0.2)
            {
                _lineWidth = 0.2
            }
            else if (newValue > 12.0)
            {
                _lineWidth = 12.0
            }
            else
            {
                _lineWidth = newValue
            }
        }
    }
}