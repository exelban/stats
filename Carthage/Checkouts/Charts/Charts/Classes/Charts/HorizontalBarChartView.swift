//
//  HorizontalBarChartView.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import UIKit

/// BarChart with horizontal bar orientation. In this implementation, x- and y-axis are switched.
public class HorizontalBarChartView: BarChartView
{
    internal override func initialize()
    {
        super.initialize()
        
        _leftAxisTransformer = ChartTransformerHorizontalBarChart(viewPortHandler: _viewPortHandler)
        _rightAxisTransformer = ChartTransformerHorizontalBarChart(viewPortHandler: _viewPortHandler)
        
        renderer = HorizontalBarChartRenderer(delegate: self, animator: _animator, viewPortHandler: _viewPortHandler)
        _leftYAxisRenderer = ChartYAxisRendererHorizontalBarChart(viewPortHandler: _viewPortHandler, yAxis: _leftAxis, transformer: _leftAxisTransformer)
        _rightYAxisRenderer = ChartYAxisRendererHorizontalBarChart(viewPortHandler: _viewPortHandler, yAxis: _rightAxis, transformer: _rightAxisTransformer)
        _xAxisRenderer = ChartXAxisRendererHorizontalBarChart(viewPortHandler: _viewPortHandler, xAxis: _xAxis, transformer: _leftAxisTransformer, chart: self)
        
        _highlighter = HorizontalBarChartHighlighter(chart: self)
    }
    
    internal override func calculateOffsets()
    {
        var offsetLeft: CGFloat = 0.0,
        offsetRight: CGFloat = 0.0,
        offsetTop: CGFloat = 0.0,
        offsetBottom: CGFloat = 0.0
        
        // setup offsets for legend
        if (_legend !== nil && _legend.isEnabled)
        {
            if (_legend.position == .RightOfChart
                || _legend.position == .RightOfChartCenter)
            {
                offsetRight += min(_legend.neededWidth, _viewPortHandler.chartWidth * _legend.maxSizePercent) + _legend.xOffset * 2.0
            }
            else if (_legend.position == .LeftOfChart
                || _legend.position == .LeftOfChartCenter)
            {
                offsetLeft += min(_legend.neededWidth, _viewPortHandler.chartWidth * _legend.maxSizePercent) + _legend.xOffset * 2.0
            }
            else if (_legend.position == .BelowChartLeft
                || _legend.position == .BelowChartRight
                || _legend.position == .BelowChartCenter)
            {
                // It's possible that we do not need this offset anymore as it
                //   is available through the extraOffsets, but changing it can mean
                //   changing default visibility for existing apps.
                let yOffset = _legend.textHeightMax
                
                offsetBottom += min(_legend.neededHeight + yOffset, _viewPortHandler.chartHeight * _legend.maxSizePercent)
            }
            else if (_legend.position == .AboveChartLeft
                || _legend.position == .AboveChartRight
                || _legend.position == .AboveChartCenter)
            {
                // It's possible that we do not need this offset anymore as it
                //   is available through the extraOffsets, but changing it can mean
                //   changing default visibility for existing apps.
                let yOffset = _legend.textHeightMax
                
                offsetTop += min(_legend.neededHeight + yOffset, _viewPortHandler.chartHeight * _legend.maxSizePercent)
            }
        }
        
        // offsets for y-labels
        if (_leftAxis.needsOffset)
        {
            offsetTop += _leftAxis.getRequiredHeightSpace()
        }
        
        if (_rightAxis.needsOffset)
        {
            offsetBottom += _rightAxis.getRequiredHeightSpace()
        }
        
        let xlabelwidth = _xAxis.labelWidth
        
        if (_xAxis.isEnabled)
        {
            // offsets for x-labels
            if (_xAxis.labelPosition == .Bottom)
            {
                offsetLeft += xlabelwidth
            }
            else if (_xAxis.labelPosition == .Top)
            {
                offsetRight += xlabelwidth
            }
            else if (_xAxis.labelPosition == .BothSided)
            {
                offsetLeft += xlabelwidth
                offsetRight += xlabelwidth
            }
        }
        
        offsetTop += self.extraTopOffset
        offsetRight += self.extraRightOffset
        offsetBottom += self.extraBottomOffset
        offsetLeft += self.extraLeftOffset
        
        _viewPortHandler.restrainViewPort(
            offsetLeft: max(self.minOffset, offsetLeft),
            offsetTop: max(self.minOffset, offsetTop),
            offsetRight: max(self.minOffset, offsetRight),
            offsetBottom: max(self.minOffset, offsetBottom))
        
        prepareOffsetMatrix()
        prepareValuePxMatrix()
    }
    
    internal override func prepareValuePxMatrix()
    {
        _rightAxisTransformer.prepareMatrixValuePx(chartXMin: _rightAxis.axisMinimum, deltaX: CGFloat(_rightAxis.axisRange), deltaY: _deltaX, chartYMin: _chartXMin)
        _leftAxisTransformer.prepareMatrixValuePx(chartXMin: _leftAxis.axisMinimum, deltaX: CGFloat(_leftAxis.axisRange), deltaY: _deltaX, chartYMin: _chartXMin)
    }

    internal override func calcModulus()
    {
        _xAxis.axisLabelModulus = Int(ceil((CGFloat(_data.xValCount) * _xAxis.labelHeight) / (_viewPortHandler.contentHeight * viewPortHandler.touchMatrix.d)))
        
        if (_xAxis.axisLabelModulus < 1)
        {
            _xAxis.axisLabelModulus = 1
        }
    }
    
    public override func getBarBounds(e: BarChartDataEntry) -> CGRect!
    {
        let set = _data.getDataSetForEntry(e) as! BarChartDataSet!
        
        if (set === nil)
        {
            return nil
        }
        
        let barspace = set.barSpace
        let y = CGFloat(e.value)
        let x = CGFloat(e.xIndex)
        
        let spaceHalf = barspace / 2.0
        let top = x - 0.5 + spaceHalf
        let bottom = x + 0.5 - spaceHalf
        let left = y >= 0.0 ? y : 0.0
        let right = y <= 0.0 ? y : 0.0
        
        var bounds = CGRect(x: left, y: top, width: right - left, height: bottom - top)
        
        getTransformer(set.axisDependency).rectValueToPixel(&bounds)
        
        return bounds
    }
    
    public override func getPosition(e: ChartDataEntry, axis: ChartYAxis.AxisDependency) -> CGPoint
    {
        var vals = CGPoint(x: CGFloat(e.value), y: CGFloat(e.xIndex))
        
        getTransformer(axis).pointValueToPixel(&vals)
        
        return vals
    }

    public override func getHighlightByTouchPoint(pt: CGPoint) -> ChartHighlight?
    {
        if (_dataNotSet || _data === nil)
        {
            print("Can't select by touch. No data set.", terminator: "\n")
            return nil
        }
        
        return _highlighter?.getHighlight(x: Double(pt.y), y: Double(pt.x))
    }
    
    public override var lowestVisibleXIndex: Int
    {
        let step = CGFloat(_data.dataSetCount)
        let div = (step <= 1.0) ? 1.0 : step + (_data as! BarChartData).groupSpace
        
        var pt = CGPoint(x: _viewPortHandler.contentLeft, y: _viewPortHandler.contentBottom)
        getTransformer(ChartYAxis.AxisDependency.Left).pixelToValue(&pt)
        
        return Int(((pt.y <= 0.0) ? 0.0 : pt.y / div) + 1.0)
    }
    
    public override var highestVisibleXIndex: Int
    {
        let step = CGFloat(_data.dataSetCount)
        let div = (step <= 1.0) ? 1.0 : step + (_data as! BarChartData).groupSpace
        
        var pt = CGPoint(x: _viewPortHandler.contentLeft, y: _viewPortHandler.contentTop)
        getTransformer(ChartYAxis.AxisDependency.Left).pixelToValue(&pt)
        
        return Int((pt.y >= CGFloat(chartXMax)) ? CGFloat(chartXMax) / div : (pt.y / div))
    }
}