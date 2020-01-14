//
//  LineChartView.swift
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

/// Chart that draws lines, surfaces, circles, ...
public class LineChartView: BarLineChartViewBase, LineChartRendererDelegate
{
    private var _fillFormatter: ChartFillFormatter!
    
    internal override func initialize()
    {
        super.initialize()
        
        renderer = LineChartRenderer(delegate: self, animator: _animator, viewPortHandler: _viewPortHandler)
        
        _fillFormatter = BarLineChartFillFormatter(chart: self)
    }
    
    internal override func calcMinMax()
    {
        super.calcMinMax()
        
        if (_deltaX == 0.0 && _data.yValCount > 0)
        {
            _deltaX = 1.0
        }
    }
    
    public var fillFormatter: ChartFillFormatter!
    {
        get
        {
            return _fillFormatter
        }
        set
        {
            if (newValue === nil)
            {
                _fillFormatter = BarLineChartFillFormatter(chart: self)
            }
            else
            {
                _fillFormatter = newValue
            }
        }
    }
    
    // MARK: - LineChartRendererDelegate
    
    public func lineChartRendererData(renderer: LineChartRenderer) -> LineChartData!
    {
        return _data as! LineChartData!
    }
    
    public func lineChartRenderer(renderer: LineChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return self.getTransformer(which)
    }
    
    public func lineChartRendererFillFormatter(renderer: LineChartRenderer) -> ChartFillFormatter
    {
        return self.fillFormatter
    }
    
    public func lineChartDefaultRendererValueFormatter(renderer: LineChartRenderer) -> NSNumberFormatter!
    {
        return self._defaultValueFormatter
    }
    
    public func lineChartRendererChartYMax(renderer: LineChartRenderer) -> Double
    {
        return self.chartYMax
    }
    
    public func lineChartRendererChartYMin(renderer: LineChartRenderer) -> Double
    {
        return self.chartYMin
    }
    
    public func lineChartRendererChartXMax(renderer: LineChartRenderer) -> Double
    {
        return self.chartXMax
    }
    
    public func lineChartRendererChartXMin(renderer: LineChartRenderer) -> Double
    {
        return self.chartXMin
    }
    
    public func lineChartRendererMaxVisibleValueCount(renderer: LineChartRenderer) -> Int
    {
        return self.maxVisibleValueCount
    }
}