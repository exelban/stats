//
//  YAxis.swift
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

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(Cocoa)
import Cocoa
#endif


/// Class representing the y-axis labels settings and its entries.
/// Be aware that not all features the YLabels class provides are suitable for the RadarChart.
/// Customizations that affect the value range of the axis need to be applied before setting data for the chart.
@objc(ChartYAxis)
open class YAxis: AxisBase
{
    @objc(YAxisLabelPosition)
    public enum LabelPosition: Int
    {
        case outsideChart
        case insideChart
    }
    
    ///  Enum that specifies the axis a DataSet should be plotted against, either Left or Right.
    @objc
    public enum AxisDependency: Int
    {
        case left
        case right
    }
    
    /// indicates if the bottom y-label entry is drawn or not
    @objc open var drawBottomYLabelEntryEnabled = true
    
    /// indicates if the top y-label entry is drawn or not
    @objc open var drawTopYLabelEntryEnabled = true
    
    /// flag that indicates if the axis is inverted or not
    @objc open var inverted = false
    
    /// flag that indicates if the zero-line should be drawn regardless of other grid lines
    @objc open var drawZeroLineEnabled = false
    
    /// Color of the zero line
    @objc open var zeroLineColor: NSUIColor? = NSUIColor.gray
    
    /// Width of the zero line
    @objc open var zeroLineWidth: CGFloat = 1.0
    
    /// This is how much (in pixels) into the dash pattern are we starting from.
    @objc open var zeroLineDashPhase = CGFloat(0.0)
    
    /// This is the actual dash pattern.
    /// I.e. [2, 3] will paint [--   --   ]
    /// [1, 3, 4, 2] will paint [-   ----  -   ----  ]
    @objc open var zeroLineDashLengths: [CGFloat]?

    /// axis space from the largest value to the top in percent of the total axis range
    @objc open var spaceTop = CGFloat(0.1)

    /// axis space from the smallest value to the bottom in percent of the total axis range
    @objc open var spaceBottom = CGFloat(0.1)
    
    /// the position of the y-labels relative to the chart
    @objc open var labelPosition = LabelPosition.outsideChart

    /// the alignment of the text in the y-label
    @objc open var labelAlignment: NSTextAlignment = .left

    /// the horizontal offset of the y-label
    @objc open var labelXOffset: CGFloat = 10.0
    
    /// the side this axis object represents
    private var _axisDependency = AxisDependency.left
    
    /// the minimum width that the axis should take
    /// 
    /// **default**: 0.0
    @objc open var minWidth = CGFloat(0)
    
    /// the maximum width that the axis can take.
    /// use Infinity for disabling the maximum.
    /// 
    /// **default**: CGFloat.infinity
    @objc open var maxWidth = CGFloat(CGFloat.infinity)
    
    public override init()
    {
        super.init()
        
        self.yOffset = 0.0
    }
    
    @objc public init(position: AxisDependency)
    {
        super.init()
        
        _axisDependency = position
        
        self.yOffset = 0.0
    }
    
    @objc open var axisDependency: AxisDependency
    {
        return _axisDependency
    }
    
    @objc open func requiredSize() -> CGSize
    {
        let label = getLongestLabel() as NSString
        var size = label.size(withAttributes: [NSAttributedString.Key.font: labelFont])
        size.width += xOffset * 2.0
        size.height += yOffset * 2.0
        size.width = max(minWidth, min(size.width, maxWidth > 0.0 ? maxWidth : size.width))
        return size
    }
    
    @objc open func getRequiredHeightSpace() -> CGFloat
    {
        return requiredSize().height
    }
    
    /// `true` if this axis needs horizontal offset, `false` ifno offset is needed.
    @objc open var needsOffset: Bool
    {
        if isEnabled && isDrawLabelsEnabled && labelPosition == .outsideChart
        {
            return true
        }
        else
        {
            return false
        }
    }
    
    @objc open var isInverted: Bool { return inverted }
    
    open override func calculate(min dataMin: Double, max dataMax: Double)
    {
        // if custom, use value as is, else use data value
        var min = _customAxisMin ? _axisMinimum : dataMin
        var max = _customAxisMax ? _axisMaximum : dataMax
        
        // Make sure max is greater than min
        // Discussion: https://github.com/danielgindi/Charts/pull/3650#discussion_r221409991
        if min > max
        {
            switch(_customAxisMax, _customAxisMin)
            {
            case(true, true):
                (min, max) = (max, min)
            case(true, false):
                min = max < 0 ? max * 1.5 : max * 0.5
            case(false, true):
                max = min < 0 ? min * 0.5 : min * 1.5
            case(false, false):
                break
            }
        }
        
        // temporary range (before calculations)
        let range = abs(max - min)
        
        // in case all values are equal
        if range == 0.0
        {
            max = max + 1.0
            min = min - 1.0
        }
        
        // bottom-space only effects non-custom min
        if !_customAxisMin
        {
            let bottomSpace = range * Double(spaceBottom)
            _axisMinimum = (min - bottomSpace)
        }
        
        // top-space only effects non-custom max
        if !_customAxisMax
        {
            let topSpace = range * Double(spaceTop)
            _axisMaximum = (max + topSpace)
        }
        
        // calc actual range
        axisRange = abs(_axisMaximum - _axisMinimum)
    }
    
    @objc open var isDrawBottomYLabelEntryEnabled: Bool { return drawBottomYLabelEntryEnabled }
    
    @objc open var isDrawTopYLabelEntryEnabled: Bool { return drawTopYLabelEntryEnabled }

}
