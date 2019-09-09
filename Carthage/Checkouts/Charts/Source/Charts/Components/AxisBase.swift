//
//  AxisBase.swift
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

/// Base class for all axes
@objc(ChartAxisBase)
open class AxisBase: ComponentBase
{
    public override init()
    {
        super.init()
    }
    
    /// Custom formatter that is used instead of the auto-formatter if set
    private var _axisValueFormatter: IAxisValueFormatter?
    
    @objc open var labelFont = NSUIFont.systemFont(ofSize: 10.0)
    @objc open var labelTextColor = NSUIColor.black
    
    @objc open var axisLineColor = NSUIColor.gray
    @objc open var axisLineWidth = CGFloat(0.5)
    @objc open var axisLineDashPhase = CGFloat(0.0)
    @objc open var axisLineDashLengths: [CGFloat]!
    
    @objc open var gridColor = NSUIColor.gray.withAlphaComponent(0.9)
    @objc open var gridLineWidth = CGFloat(0.5)
    @objc open var gridLineDashPhase = CGFloat(0.0)
    @objc open var gridLineDashLengths: [CGFloat]!
    @objc open var gridLineCap = CGLineCap.butt
    
    @objc open var drawGridLinesEnabled = true
    @objc open var drawAxisLineEnabled = true
    
    /// flag that indicates of the labels of this axis should be drawn or not
    @objc open var drawLabelsEnabled = true
    
    private var _centerAxisLabelsEnabled = false

    /// Centers the axis labels instead of drawing them at their original position.
    /// This is useful especially for grouped BarChart.
    @objc open var centerAxisLabelsEnabled: Bool
    {
        get { return _centerAxisLabelsEnabled && entryCount > 0 }
        set { _centerAxisLabelsEnabled = newValue }
    }
    
    @objc open var isCenterAxisLabelsEnabled: Bool
    {
        get { return centerAxisLabelsEnabled }
    }

    /// array of limitlines that can be set for the axis
    private var _limitLines = [ChartLimitLine]()
    
    /// Are the LimitLines drawn behind the data or in front of the data?
    /// 
    /// **default**: false
    @objc open var drawLimitLinesBehindDataEnabled = false

    /// the flag can be used to turn off the antialias for grid lines
    @objc open var gridAntialiasEnabled = true
    
    /// the actual array of entries
    @objc open var entries = [Double]()
    
    /// axis label entries only used for centered labels
    @objc open var centeredEntries = [Double]()
    
    /// the number of entries the legend contains
    @objc open var entryCount: Int { return entries.count }
    
    /// the number of label entries the axis should have
    ///
    /// **default**: 6
    private var _labelCount = Int(6)
    
    /// the number of decimal digits to use (for the default formatter
    @objc open var decimals: Int = 0
    
    /// When true, axis labels are controlled by the `granularity` property.
    /// When false, axis values could possibly be repeated.
    /// This could happen if two adjacent axis values are rounded to same value.
    /// If using granularity this could be avoided by having fewer axis values visible.
    @objc open var granularityEnabled = false
    
    private var _granularity = Double(1.0)
    
    /// The minimum interval between axis values.
    /// This can be used to avoid label duplicating when zooming in.
    ///
    /// **default**: 1.0
    @objc open var granularity: Double
    {
        get
        {
            return _granularity
        }
        set
        {
            _granularity = newValue
            
            // set this to `true` if it was disabled, as it makes no sense to set this property with granularity disabled
            granularityEnabled = true
        }
    }
    
    /// The minimum interval between axis values.
    @objc open var isGranularityEnabled: Bool
    {
        get
        {
            return granularityEnabled
        }
    }
    
    /// if true, the set number of y-labels will be forced
    @objc open var forceLabelsEnabled = false
    
    @objc open func getLongestLabel() -> String
    {
        var longest = ""
        
        for i in 0 ..< entries.count
        {
            let text = getFormattedLabel(i)
            
            if longest.count < text.count
            {
                longest = text
            }
        }
        
        return longest
    }
    
    /// - Returns: The formatted label at the specified index. This will either use the auto-formatter or the custom formatter (if one is set).
    @objc open func getFormattedLabel(_ index: Int) -> String
    {
        if index < 0 || index >= entries.count
        {
            return ""
        }
        
        return valueFormatter?.stringForValue(entries[index], axis: self) ?? ""
    }
    
    /// Sets the formatter to be used for formatting the axis labels.
    /// If no formatter is set, the chart will automatically determine a reasonable formatting (concerning decimals) for all the values that are drawn inside the chart.
    /// Use `nil` to use the formatter calculated by the chart.
    @objc open var valueFormatter: IAxisValueFormatter?
    {
        get
        {
            if _axisValueFormatter == nil ||
                (_axisValueFormatter is DefaultAxisValueFormatter &&
                    (_axisValueFormatter as! DefaultAxisValueFormatter).hasAutoDecimals &&
                    (_axisValueFormatter as! DefaultAxisValueFormatter).decimals != decimals)
            {
                _axisValueFormatter = DefaultAxisValueFormatter(decimals: decimals)
            }
            
            return _axisValueFormatter
        }
        set
        {
            _axisValueFormatter = newValue ?? DefaultAxisValueFormatter(decimals: decimals)
        }
    }
    
    @objc open var isDrawGridLinesEnabled: Bool { return drawGridLinesEnabled }
    
    @objc open var isDrawAxisLineEnabled: Bool { return drawAxisLineEnabled }
    
    @objc open var isDrawLabelsEnabled: Bool { return drawLabelsEnabled }
    
    /// Are the LimitLines drawn behind the data or in front of the data?
    /// 
    /// **default**: false
    @objc open var isDrawLimitLinesBehindDataEnabled: Bool { return drawLimitLinesBehindDataEnabled }
    
    /// Extra spacing for `axisMinimum` to be added to automatically calculated `axisMinimum`
    @objc open var spaceMin: Double = 0.0
    
    /// Extra spacing for `axisMaximum` to be added to automatically calculated `axisMaximum`
    @objc open var spaceMax: Double = 0.0
    
    /// Flag indicating that the axis-min value has been customized
    internal var _customAxisMin: Bool = false
    
    /// Flag indicating that the axis-max value has been customized
    internal var _customAxisMax: Bool = false
    
    /// Do not touch this directly, instead, use axisMinimum.
    /// This is automatically calculated to represent the real min value,
    /// and is used when calculating the effective minimum.
    internal var _axisMinimum = Double(0)
    
    /// Do not touch this directly, instead, use axisMaximum.
    /// This is automatically calculated to represent the real max value,
    /// and is used when calculating the effective maximum.
    internal var _axisMaximum = Double(0)
    
    /// the total range of values this axis covers
    @objc open var axisRange = Double(0)
    
    /// The minumum number of labels on the axis
    @objc open var axisMinLabels = Int(2) {
        didSet { axisMinLabels = axisMinLabels > 0 ? axisMinLabels : oldValue }
    }
    
    /// The maximum number of labels on the axis
    @objc open var axisMaxLabels = Int(25) {
        didSet { axisMaxLabels = axisMaxLabels > 0 ? axisMaxLabels : oldValue }
    }
    
    /// the number of label entries the axis should have
    /// max = 25,
    /// min = 2,
    /// default = 6,
    /// be aware that this number is not fixed and can only be approximated
    @objc open var labelCount: Int
    {
        get
        {
            return _labelCount
        }
        set
        {
            let range = axisMinLabels...axisMaxLabels as ClosedRange
            _labelCount = newValue.clamped(to: range)
                        
            forceLabelsEnabled = false
        }
    }
    
    @objc open func setLabelCount(_ count: Int, force: Bool)
    {
        self.labelCount = count
        forceLabelsEnabled = force
    }
    
    /// `true` if focing the y-label count is enabled. Default: false
    @objc open var isForceLabelsEnabled: Bool { return forceLabelsEnabled }
    
    /// Adds a new ChartLimitLine to this axis.
    @objc open func addLimitLine(_ line: ChartLimitLine)
    {
        _limitLines.append(line)
    }
    
    /// Removes the specified ChartLimitLine from the axis.
    @objc open func removeLimitLine(_ line: ChartLimitLine)
    {
        guard let i = _limitLines.firstIndex(of: line) else { return }
        _limitLines.remove(at: i)
    }
    
    /// Removes all LimitLines from the axis.
    @objc open func removeAllLimitLines()
    {
        _limitLines.removeAll(keepingCapacity: false)
    }
    
    /// The LimitLines of this axis.
    @objc open var limitLines : [ChartLimitLine]
    {
        return _limitLines
    }
    
    // MARK: Custom axis ranges
    
    /// By calling this method, any custom minimum value that has been previously set is reseted, and the calculation is done automatically.
    @objc open func resetCustomAxisMin()
    {
        _customAxisMin = false
    }
    
    @objc open var isAxisMinCustom: Bool { return _customAxisMin }
    
    /// By calling this method, any custom maximum value that has been previously set is reseted, and the calculation is done automatically.
    @objc open func resetCustomAxisMax()
    {
        _customAxisMax = false
    }
    
    @objc open var isAxisMaxCustom: Bool { return _customAxisMax }
        
    /// The minimum value for this axis.
    /// If set, this value will not be calculated automatically depending on the provided data.
    /// Use `resetCustomAxisMin()` to undo this.
    @objc open var axisMinimum: Double
    {
        get
        {
            return _axisMinimum
        }
        set
        {
            _customAxisMin = true
            _axisMinimum = newValue
            axisRange = abs(_axisMaximum - newValue)
        }
    }
    
    /// The maximum value for this axis.
    /// If set, this value will not be calculated automatically depending on the provided data.
    /// Use `resetCustomAxisMax()` to undo this.
    @objc open var axisMaximum: Double
    {
        get
        {
            return _axisMaximum
        }
        set
        {
            _customAxisMax = true
            _axisMaximum = newValue
            axisRange = abs(newValue - _axisMinimum)
        }
    }
    
    /// Calculates the minimum, maximum and range values of the YAxis with the given minimum and maximum values from the chart data.
    ///
    /// - Parameters:
    ///   - dataMin: the y-min value according to chart data
    ///   - dataMax: the y-max value according to chart
    @objc open func calculate(min dataMin: Double, max dataMax: Double)
    {
        // if custom, use value as is, else use data value
        var min = _customAxisMin ? _axisMinimum : (dataMin - spaceMin)
        var max = _customAxisMax ? _axisMaximum : (dataMax + spaceMax)
        
        // temporary range (before calculations)
        let range = abs(max - min)
        
        // in case all values are equal
        if range == 0.0
        {
            max = max + 1.0
            min = min - 1.0
        }
        
        _axisMinimum = min
        _axisMaximum = max
        
        // actual range
        axisRange = abs(max - min)
    }
}
