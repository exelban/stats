//
//  BarChartView.swift
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

/// Chart that draws bars.
open class BarChartView: BarLineChartViewBase, BarChartDataProvider
{
    /// if set to true, all values are drawn above their bars, instead of below their top
    private var _drawValueAboveBarEnabled = true

    /// if set to true, a grey area is drawn behind each bar that indicates the maximum value
    private var _drawBarShadowEnabled = false
    
    internal override func initialize()
    {
        super.initialize()
        
        renderer = BarChartRenderer(dataProvider: self, animator: _animator, viewPortHandler: _viewPortHandler)
        
        self.highlighter = BarHighlighter(chart: self)
        
        self.xAxis.spaceMin = 0.5
        self.xAxis.spaceMax = 0.5
    }
    
    internal override func calcMinMax()
    {
        guard let data = self.data as? BarChartData
            else { return }
        
        if fitBars
        {
            _xAxis.calculate(
                min: data.xMin - data.barWidth / 2.0,
                max: data.xMax + data.barWidth / 2.0)
        }
        else
        {
            _xAxis.calculate(min: data.xMin, max: data.xMax)
        }
        
        // calculate axis range (min / max) according to provided data
        leftAxis.calculate(
            min: data.getYMin(axis: .left),
            max: data.getYMax(axis: .left))
        rightAxis.calculate(
            min: data.getYMin(axis: .right),
            max: data.getYMax(axis: .right))
    }
    
    /// - Returns: The Highlight object (contains x-index and DataSet index) of the selected value at the given touch point inside the BarChart.
    open override func getHighlightByTouchPoint(_ pt: CGPoint) -> Highlight?
    {
        if _data === nil
        {
            Swift.print("Can't select by touch. No data set.")
            return nil
        }
        
        guard let h = self.highlighter?.getHighlight(x: pt.x, y: pt.y)
            else { return nil }
        
        if !isHighlightFullBarEnabled { return h }
        
        // For isHighlightFullBarEnabled, remove stackIndex
        return Highlight(
            x: h.x, y: h.y,
            xPx: h.xPx, yPx: h.yPx,
            dataIndex: h.dataIndex,
            dataSetIndex: h.dataSetIndex,
            stackIndex: -1,
            axis: h.axis)
    }
        
    /// - Returns: The bounding box of the specified Entry in the specified DataSet. Returns null if the Entry could not be found in the charts data.
    @objc open func getBarBounds(entry e: BarChartDataEntry) -> CGRect
    {
        guard let
            data = _data as? BarChartData,
            let set = data.getDataSetForEntry(e) as? IBarChartDataSet
            else { return CGRect.null }
        
        let y = e.y
        let x = e.x
        
        let barWidth = data.barWidth
        
        let left = x - barWidth / 2.0
        let right = x + barWidth / 2.0
        let top = y >= 0.0 ? y : 0.0
        let bottom = y <= 0.0 ? y : 0.0
        
        var bounds = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        
        getTransformer(forAxis: set.axisDependency).rectValueToPixel(&bounds)
        
        return bounds
    }
    
    /// Groups all BarDataSet objects this data object holds together by modifying the x-value of their entries.
    /// Previously set x-values of entries will be overwritten. Leaves space between bars and groups as specified by the parameters.
    /// Calls `notifyDataSetChanged()` afterwards.
    ///
    /// - Parameters:
    ///   - fromX: the starting point on the x-axis where the grouping should begin
    ///   - groupSpace: the space between groups of bars in values (not pixels) e.g. 0.8f for bar width 1f
    ///   - barSpace: the space between individual bars in values (not pixels) e.g. 0.1f for bar width 1f
    @objc open func groupBars(fromX: Double, groupSpace: Double, barSpace: Double)
    {
        guard let barData = self.barData
            else
        {
            Swift.print("You need to set data for the chart before grouping bars.", terminator: "\n")
            return
        }
        
        barData.groupBars(fromX: fromX, groupSpace: groupSpace, barSpace: barSpace)
        notifyDataSetChanged()
    }
    
    /// Highlights the value at the given x-value in the given DataSet. Provide -1 as the dataSetIndex to undo all highlighting.
    ///
    /// - Parameters:
    ///   - x:
    ///   - dataSetIndex:
    ///   - stackIndex: the index inside the stack - only relevant for stacked entries
    @objc open func highlightValue(x: Double, dataSetIndex: Int, stackIndex: Int)
    {
        highlightValue(Highlight(x: x, dataSetIndex: dataSetIndex, stackIndex: stackIndex))
    }

    // MARK: Accessors
    
    /// if set to true, all values are drawn above their bars, instead of below their top
    @objc open var drawValueAboveBarEnabled: Bool
    {
        get { return _drawValueAboveBarEnabled }
        set
        {
            _drawValueAboveBarEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// if set to true, a grey area is drawn behind each bar that indicates the maximum value
    @objc open var drawBarShadowEnabled: Bool
    {
        get { return _drawBarShadowEnabled }
        set
        {
            _drawBarShadowEnabled = newValue
            setNeedsDisplay()
        }
    }
    
    /// Adds half of the bar width to each side of the x-axis range in order to allow the bars of the barchart to be fully displayed.
    /// **default**: false
    @objc open var fitBars = false
    
    /// Set this to `true` to make the highlight operation full-bar oriented, `false` to make it highlight single values (relevant only for stacked).
    /// If enabled, highlighting operations will highlight the whole bar, even if only a single stack entry was tapped.
    @objc open var highlightFullBarEnabled: Bool = false
    
    /// `true` the highlight is be full-bar oriented, `false` ifsingle-value
    open var isHighlightFullBarEnabled: Bool { return highlightFullBarEnabled }
    
    // MARK: - BarChartDataProvider
    
    open var barData: BarChartData? { return _data as? BarChartData }
    
    /// `true` if drawing values above bars is enabled, `false` ifnot
    open var isDrawValueAboveBarEnabled: Bool { return drawValueAboveBarEnabled }
    
    /// `true` if drawing shadows (maxvalue) for each bar is enabled, `false` ifnot
    open var isDrawBarShadowEnabled: Bool { return drawBarShadowEnabled }
}
