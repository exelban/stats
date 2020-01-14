//
//  RadarChartView.swift
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
import CoreGraphics
import UIKit

/// Implementation of the RadarChart, a "spidernet"-like chart. It works best
/// when displaying 5-10 entries per DataSet.
public class RadarChartView: PieRadarChartViewBase
{
    /// width of the web lines that come from the center.
    public var webLineWidth = CGFloat(1.5)
    
    /// width of the web lines that are in between the lines coming from the center
    public var innerWebLineWidth = CGFloat(0.75)
    
    /// color for the web lines that come from the center
    public var webColor = UIColor(red: 122/255.0, green: 122/255.0, blue: 122.0/255.0, alpha: 1.0)
    
    /// color for the web lines in between the lines that come from the center.
    public var innerWebColor = UIColor(red: 122/255.0, green: 122/255.0, blue: 122.0/255.0, alpha: 1.0)
    
    /// transparency the grid is drawn with (0.0 - 1.0)
    public var webAlpha: CGFloat = 150.0 / 255.0
    
    /// flag indicating if the web lines should be drawn or not
    public var drawWeb = true
    
    /// modulus that determines how many labels and web-lines are skipped before the next is drawn
    private var _skipWebLineCount = 1
    
    /// the object reprsenting the y-axis labels
    private var _yAxis: ChartYAxis!
    
    /// the object representing the x-axis labels
    private var _xAxis: ChartXAxis!
    
    internal var _yAxisRenderer: ChartYAxisRendererRadarChart!
    internal var _xAxisRenderer: ChartXAxisRendererRadarChart!
    
    public override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    public required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
    }
    
    internal override func initialize()
    {
        super.initialize()
        
        _yAxis = ChartYAxis(position: .Left)
        _xAxis = ChartXAxis()
        _xAxis.spaceBetweenLabels = 0
        
        renderer = RadarChartRenderer(chart: self, animator: _animator, viewPortHandler: _viewPortHandler)
        
        _yAxisRenderer = ChartYAxisRendererRadarChart(viewPortHandler: _viewPortHandler, yAxis: _yAxis, chart: self)
        _xAxisRenderer = ChartXAxisRendererRadarChart(viewPortHandler: _viewPortHandler, xAxis: _xAxis, chart: self)
    }

    internal override func calcMinMax()
    {
        super.calcMinMax()
        
        let minLeft = _data.getYMin(.Left)
        let maxLeft = _data.getYMax(.Left)
        
        _chartXMax = Double(_data.xVals.count) - 1.0
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
        
        let leftRange = CGFloat(abs(maxLeft - (_yAxis.isStartAtZeroEnabled ? 0.0 : minLeft)))
        
        let topSpaceLeft = Double(leftRange * _yAxis.spaceTop)
        let bottomSpaceLeft = Double(leftRange * _yAxis.spaceBottom)
        
        // Consider sticking one of the edges of the axis to zero (0.0)
        
        if _yAxis.isStartAtZeroEnabled
        {
            if minLeft < 0.0 && maxLeft < 0.0
            {
                // If the values are all negative, let's stay in the negative zone
                _yAxis.axisMinimum = min(0.0, !isnan(_yAxis.customAxisMin) ? _yAxis.customAxisMin : (minLeft - bottomSpaceLeft))
                _yAxis.axisMaximum = 0.0
            }
            else if minLeft >= 0.0
            {
                // We have positive values only, stay in the positive zone
            _yAxis.axisMinimum = 0.0
                _yAxis.axisMaximum = max(0.0, !isnan(_yAxis.customAxisMax) ? _yAxis.customAxisMax : (maxLeft + topSpaceLeft))
        }
            else
            {
                // Stick the minimum to 0.0 or less, and maximum to 0.0 or more (startAtZero for negative/positive at the same time)
                _yAxis.axisMinimum = min(0.0, !isnan(_yAxis.customAxisMin) ? _yAxis.customAxisMin : (minLeft - bottomSpaceLeft))
                _yAxis.axisMaximum = max(0.0, !isnan(_yAxis.customAxisMax) ? _yAxis.customAxisMax : (maxLeft + topSpaceLeft))
            }
        }
        else
        {
            // Use the values as they are
            _yAxis.axisMinimum = !isnan(_yAxis.customAxisMin) ? _yAxis.customAxisMin : (minLeft - bottomSpaceLeft)
            _yAxis.axisMaximum = !isnan(_yAxis.customAxisMax) ? _yAxis.customAxisMax : (maxLeft + topSpaceLeft)
        }
        
        _chartXMax = Double(_data.xVals.count) - 1.0
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
        
        _yAxis.axisRange = abs(_yAxis.axisMaximum - _yAxis.axisMinimum)
    }

    public override func getMarkerPosition(entry entry: ChartDataEntry, highlight: ChartHighlight) -> CGPoint
    {
        let angle = self.sliceAngle * CGFloat(entry.xIndex) + self.rotationAngle
        let val = CGFloat(entry.value) * self.factor
        let c = self.centerOffsets
        
        let p = CGPoint(x: c.x + val * cos(angle * ChartUtils.Math.FDEG2RAD),
            y: c.y + val * sin(angle * ChartUtils.Math.FDEG2RAD))
        
        return p
    }
    
    public override func notifyDataSetChanged()
    {
        if (_dataNotSet)
        {
            return
        }
        
        calcMinMax()
        
        _yAxis?._defaultValueFormatter = _defaultValueFormatter
        
        _yAxisRenderer?.computeAxis(yMin: _yAxis.axisMinimum, yMax: _yAxis.axisMaximum)
        _xAxisRenderer?.computeAxis(xValAverageLength: _data.xValAverageLength, xValues: _data.xVals)
        
        if (_legend !== nil && !_legend.isLegendCustom)
        {
            _legendRenderer?.computeLegend(_data)
        }
        
        calculateOffsets()
        
        setNeedsDisplay()
    }
    
    public override func drawRect(rect: CGRect)
    {
        super.drawRect(rect)

        if (_dataNotSet)
        {
            return
        }
        
        let context = UIGraphicsGetCurrentContext()
        
        _xAxisRenderer?.renderAxisLabels(context: context)

        if (drawWeb)
        {
            renderer!.drawExtras(context: context)
        }
        
        _yAxisRenderer.renderLimitLines(context: context)

        renderer!.drawData(context: context)

        if (valuesToHighlight())
        {
            renderer!.drawHighlighted(context: context, indices: _indicesToHightlight)
        }

        _yAxisRenderer.renderAxisLabels(context: context)

        renderer!.drawValues(context: context)

        _legendRenderer.renderLegend(context: context)

        drawDescription(context: context)

        drawMarkers(context: context)
    }

    /// - returns: the factor that is needed to transform values into pixels.
    public var factor: CGFloat
    {
        let content = _viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
                / CGFloat(_yAxis.axisRange)
    }

    /// - returns: the angle that each slice in the radar chart occupies.
    public var sliceAngle: CGFloat
    {
        return 360.0 / CGFloat(_data.xValCount)
    }

    public override func indexForAngle(angle: CGFloat) -> Int
    {
        // take the current angle of the chart into consideration
        let a = ChartUtils.normalizedAngleFromAngle(angle - self.rotationAngle)
        
        let sliceAngle = self.sliceAngle
        
        for (var i = 0; i < _data.xValCount; i++)
        {
            if (sliceAngle * CGFloat(i + 1) - sliceAngle / 2.0 > a)
            {
                return i
            }
        }
        
        return 0
    }

    /// - returns: the object that represents all y-labels of the RadarChart.
    public var yAxis: ChartYAxis
    {
        return _yAxis
    }

    /// - returns: the object that represents all x-labels that are placed around the RadarChart.
    public var xAxis: ChartXAxis
    {
        return _xAxis
    }
    
    /// Sets the number of web-lines that should be skipped on chart web before the next one is drawn. This targets the lines that come from the center of the RadarChart.
    /// if count = 1 -> 1 line is skipped in between
    public var skipWebLineCount: Int
    {
        get
        {
            return _skipWebLineCount
        }
        set
        {
            _skipWebLineCount = max(0, newValue)
        }
    }
    
    internal override var requiredLegendOffset: CGFloat
    {
        return _legend.font.pointSize * 4.0
    }

    internal override var requiredBaseOffset: CGFloat
    {
        return _xAxis.isEnabled && _xAxis.isDrawLabelsEnabled ? _xAxis.labelWidth : 10.0
    }

    public override var radius: CGFloat
    {
        let content = _viewPortHandler.contentRect
        return min(content.width / 2.0, content.height / 2.0)
    }

    /// - returns: the maximum value this chart can display on it's y-axis.
    public override var chartYMax: Double { return _yAxis.axisMaximum; }
    
    /// - returns: the minimum value this chart can display on it's y-axis.
    public override var chartYMin: Double { return _yAxis.axisMinimum; }
    
    /// - returns: the range of y-values this chart can display.
    public var yRange: Double { return _yAxis.axisRange}
}