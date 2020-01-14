//
//  LineChartDataSet.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 26/2/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics
import UIKit

public class LineChartDataSet: LineRadarChartDataSet
{
    public var circleColors = [UIColor]()
    public var circleHoleColor = UIColor.whiteColor()
    public var circleRadius = CGFloat(8.0)
    
    private var _cubicIntensity = CGFloat(0.2)
    
    public var lineDashPhase = CGFloat(0.0)
    public var lineDashLengths: [CGFloat]!
    
    /// if true, drawing circles is enabled
    public var drawCirclesEnabled = true
    
    /// if true, cubic lines are drawn instead of linear
    public var drawCubicEnabled = false
    
    public var drawCircleHoleEnabled = true
    
    public required init()
    {
        super.init()
        circleColors.append(UIColor(red: 140.0/255.0, green: 234.0/255.0, blue: 255.0/255.0, alpha: 1.0))
    }
    
    public override init(yVals: [ChartDataEntry]?, label: String?)
    {
        super.init(yVals: yVals, label: label)
        circleColors.append(UIColor(red: 140.0/255.0, green: 234.0/255.0, blue: 255.0/255.0, alpha: 1.0))
    }

    /// intensity for cubic lines (min = 0.05, max = 1)
    /// 
    /// **default**: 0.2
    public var cubicIntensity: CGFloat
    {
        get
        {
            return _cubicIntensity
        }
        set
        {
            _cubicIntensity = newValue
            if (_cubicIntensity > 1.0)
            {
                _cubicIntensity = 1.0
            }
            if (_cubicIntensity < 0.05)
            {
                _cubicIntensity = 0.05
            }
        }
    }
    
    /// - returns: the color at the given index of the DataSet's circle-color array.
    /// Performs a IndexOutOfBounds check by modulus.
    public func getCircleColor(var index: Int) -> UIColor?
    {
        let size = circleColors.count
        index = index % size
        if (index >= size)
        {
            return nil
        }
        return circleColors[index]
    }
    
    /// Sets the one and ONLY color that should be used for this DataSet.
    /// Internally, this recreates the colors array and adds the specified color.
    public func setCircleColor(color: UIColor)
    {
        circleColors.removeAll(keepCapacity: false)
        circleColors.append(color)
    }
    
    /// resets the circle-colors array and creates a new one
    public func resetCircleColors(index: Int)
    {
        circleColors.removeAll(keepCapacity: false)
    }
    
    public var isDrawCirclesEnabled: Bool { return drawCirclesEnabled; }
    
    public var isDrawCubicEnabled: Bool { return drawCubicEnabled; }
    
    public var isDrawCircleHoleEnabled: Bool { return drawCircleHoleEnabled; }
    
    // MARK: NSCopying
    
    public override func copyWithZone(zone: NSZone) -> AnyObject
    {
        let copy = super.copyWithZone(zone) as! LineChartDataSet
        copy.circleColors = circleColors
        copy.circleRadius = circleRadius
        copy.cubicIntensity = cubicIntensity
        copy.lineDashPhase = lineDashPhase
        copy.lineDashLengths = lineDashLengths
        copy.drawCirclesEnabled = drawCirclesEnabled
        copy.drawCubicEnabled = drawCubicEnabled
        return copy
    }
}
