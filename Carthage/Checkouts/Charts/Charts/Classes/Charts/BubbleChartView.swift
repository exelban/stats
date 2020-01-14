//
//  BubbleChartView.swift
//  Charts
//
//  Bubble chart implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation
import CoreGraphics

public class BubbleChartView: BarLineChartViewBase, BubbleChartRendererDelegate
{
    public override func initialize()
    {
        super.initialize()
        
        renderer = BubbleChartRenderer(delegate: self, animator: _animator, viewPortHandler: _viewPortHandler)
    }
    
    public override func calcMinMax()
    {
        super.calcMinMax()
        
        if (_deltaX == 0.0 && _data.yValCount > 0)
        {
            _deltaX = 1.0
        }
        
        _chartXMin = -0.5
        _chartXMax = Double(_data.xVals.count) - 0.5
        
        if renderer as? BubbleChartRenderer !== nil,
            let sets = _data.dataSets as? [BubbleChartDataSet]
        {
            for set in sets {
                
                let xmin = set.xMin
                let xmax = set.xMax
                
                if (xmin < _chartXMin)
                {
                    _chartXMin = xmin
                }
                
                if (xmax > _chartXMax)
                {
                    _chartXMax = xmax
                }
            }
        }
        
        _deltaX = CGFloat(abs(_chartXMax - _chartXMin))
    }

    // MARK: - BubbleChartRendererDelegate
    
    public func bubbleChartRendererData(renderer: BubbleChartRenderer) -> BubbleChartData!
    {
        return _data as! BubbleChartData!
    }
    
    public func bubbleChartRenderer(renderer: BubbleChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return getTransformer(which)
    }
    
    public func bubbleChartDefaultRendererValueFormatter(renderer: BubbleChartRenderer) -> NSNumberFormatter!
    {
        return self._defaultValueFormatter
    }
    
    public func bubbleChartRendererChartYMax(renderer: BubbleChartRenderer) -> Double
    {
        return self.chartYMax
    }
    
    public func bubbleChartRendererChartYMin(renderer: BubbleChartRenderer) -> Double
    {
        return self.chartYMin
    }
    
    public func bubbleChartRendererChartXMax(renderer: BubbleChartRenderer) -> Double
    {
        return self.chartXMax
    }
    
    public func bubbleChartRendererChartXMin(renderer: BubbleChartRenderer) -> Double
    {
        return self.chartXMin
    }
    
    public func bubbleChartRendererMaxVisibleValueCount(renderer: BubbleChartRenderer) -> Int
    {
        return self.maxVisibleValueCount
    }
    
    public func bubbleChartRendererXValCount(renderer: BubbleChartRenderer) -> Int
    {
        return _data.xValCount
    }
}