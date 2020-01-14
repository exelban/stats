//
//  CombinedChartRenderer.swift
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

public class CombinedChartRenderer: ChartDataRendererBase,
    LineChartRendererDelegate,
    BarChartRendererDelegate,
    ScatterChartRendererDelegate,
    CandleStickChartRendererDelegate,
    BubbleChartRendererDelegate
{
    private weak var _chart: CombinedChartView!
    
    /// flag that enables or disables the highlighting arrow
    public var drawHighlightArrowEnabled = false
    
    /// if set to true, all values are drawn above their bars, instead of below their top
    public var drawValueAboveBarEnabled = true
    
    /// if set to true, a grey area is darawn behind each bar that indicates the maximum value
    public var drawBarShadowEnabled = true
    
    internal var _renderers = [ChartDataRendererBase]()
    
    internal var _drawOrder: [CombinedChartView.CombinedChartDrawOrder] = [.Bar, .Bubble, .Line, .Candle, .Scatter]
    
    public init(chart: CombinedChartView, animator: ChartAnimator, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        _chart = chart
        
        createRenderers()
    }
    
    /// Creates the renderers needed for this combined-renderer in the required order. Also takes the DrawOrder into consideration.
    internal func createRenderers()
    {
        _renderers = [ChartDataRendererBase]()

        for order in drawOrder
        {
            switch (order)
            {
            case .Bar:
                if (_chart.barData !== nil)
                {
                    _renderers.append(BarChartRenderer(delegate: self, animator: _animator, viewPortHandler: viewPortHandler))
                }
                break
                
            case .Line:
                if (_chart.lineData !== nil)
                {
                    _renderers.append(LineChartRenderer(delegate: self, animator: _animator, viewPortHandler: viewPortHandler))
                }
                break
                
            case .Candle:
                if (_chart.candleData !== nil)
                {
                    _renderers.append(CandleStickChartRenderer(delegate: self, animator: _animator, viewPortHandler: viewPortHandler))
                }
                break
                
            case .Scatter:
                if (_chart.scatterData !== nil)
                {
                    _renderers.append(ScatterChartRenderer(delegate: self, animator: _animator, viewPortHandler: viewPortHandler))
                }
                break
                
            case .Bubble:
                if (_chart.bubbleData !== nil)
                {
                    _renderers.append(BubbleChartRenderer(delegate: self, animator: _animator, viewPortHandler: viewPortHandler))
                }
                break
            }
        }

    }
    
    public override func drawData(context context: CGContext?)
    {
        for renderer in _renderers
        {
            renderer.drawData(context: context)
        }
    }
    
    public override func drawValues(context context: CGContext?)
    {
        for renderer in _renderers
        {
            renderer.drawValues(context: context)
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
        for renderer in _renderers
        {
            renderer.drawExtras(context: context)
        }
    }
    
    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        for renderer in _renderers
        {
            renderer.drawHighlighted(context: context, indices: indices)
        }
    }
    
    public override func calcXBounds(chart chart: BarLineChartViewBase, xAxisModulus: Int)
    {
        for renderer in _renderers
        {
            renderer.calcXBounds(chart: chart, xAxisModulus: xAxisModulus)
        }
    }

    /// - returns: the sub-renderer object at the specified index.
    public func getSubRenderer(index index: Int) -> ChartDataRendererBase?
    {
        if (index >= _renderers.count || index < 0)
        {
            return nil
        }
        else
        {
            return _renderers[index]
        }
    }

    /// Returns all sub-renderers.
    public var subRenderers: [ChartDataRendererBase]
    {
        get { return _renderers }
        set { _renderers = newValue }
    }

    // MARK: - LineChartRendererDelegate
    
    public func lineChartRendererData(renderer: LineChartRenderer) -> LineChartData!
    {
        return _chart.lineData
    }
    
    public func lineChartRenderer(renderer: LineChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return _chart.getTransformer(which)
    }
    
    public func lineChartRendererFillFormatter(renderer: LineChartRenderer) -> ChartFillFormatter
    {
        return _chart.fillFormatter
    }
    
    public func lineChartDefaultRendererValueFormatter(renderer: LineChartRenderer) -> NSNumberFormatter!
    {
        return _chart._defaultValueFormatter
    }
    
    public func lineChartRendererChartYMax(renderer: LineChartRenderer) -> Double
    {
        return _chart.chartYMax
    }
    
    public func lineChartRendererChartYMin(renderer: LineChartRenderer) -> Double
    {
        return _chart.chartYMin
    }
    
    public func lineChartRendererChartXMax(renderer: LineChartRenderer) -> Double
    {
        return _chart.chartXMax
    }
    
    public func lineChartRendererChartXMin(renderer: LineChartRenderer) -> Double
    {
        return _chart.chartXMin
    }
    
    public func lineChartRendererMaxVisibleValueCount(renderer: LineChartRenderer) -> Int
    {
        return _chart.maxVisibleValueCount
    }
    
    // MARK: - BarChartRendererDelegate
    
    public func barChartRendererData(renderer: BarChartRenderer) -> BarChartData!
    {
        return _chart.barData
    }
    
    public func barChartRenderer(renderer: BarChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return _chart.getTransformer(which)
    }
    
    public func barChartRendererMaxVisibleValueCount(renderer: BarChartRenderer) -> Int
    {
        return _chart.maxVisibleValueCount
    }
    
    public func barChartDefaultRendererValueFormatter(renderer: BarChartRenderer) -> NSNumberFormatter!
    {
        return _chart._defaultValueFormatter
    }
    
    public func barChartRendererChartYMax(renderer: BarChartRenderer) -> Double
    {
        return _chart.chartYMax
    }
    
    public func barChartRendererChartYMin(renderer: BarChartRenderer) -> Double
    {
        return _chart.chartYMin
    }
    
    public func barChartRendererChartXMax(renderer: BarChartRenderer) -> Double
    {
        return _chart.chartXMax
    }
    
    public func barChartRendererChartXMin(renderer: BarChartRenderer) -> Double
    {
        return _chart.chartXMin
    }
    
    public func barChartIsDrawHighlightArrowEnabled(renderer: BarChartRenderer) -> Bool
    {
        return drawHighlightArrowEnabled
    }
    
    public func barChartIsDrawValueAboveBarEnabled(renderer: BarChartRenderer) -> Bool
    {
        return drawValueAboveBarEnabled
    }
    
    public func barChartIsDrawBarShadowEnabled(renderer: BarChartRenderer) -> Bool
    {
        return drawBarShadowEnabled
    }
    
    public func barChartIsInverted(renderer: BarChartRenderer, axis: ChartYAxis.AxisDependency) -> Bool
    {
        return _chart.getAxis(axis).isInverted
    }
    
    // MARK: - ScatterChartRendererDelegate
    
    public func scatterChartRendererData(renderer: ScatterChartRenderer) -> ScatterChartData!
    {
        return _chart.scatterData
    }
    
    public func scatterChartRenderer(renderer: ScatterChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return _chart.getTransformer(which)
    }
    
    public func scatterChartDefaultRendererValueFormatter(renderer: ScatterChartRenderer) -> NSNumberFormatter!
    {
        return _chart._defaultValueFormatter
    }
    
    public func scatterChartRendererChartYMax(renderer: ScatterChartRenderer) -> Double
    {
        return _chart.chartYMax
    }
    
    public func scatterChartRendererChartYMin(renderer: ScatterChartRenderer) -> Double
    {
        return _chart.chartYMin
    }
    
    public func scatterChartRendererChartXMax(renderer: ScatterChartRenderer) -> Double
    {
        return _chart.chartXMax
    }
    
    public func scatterChartRendererChartXMin(renderer: ScatterChartRenderer) -> Double
    {
        return _chart.chartXMin
    }
    
    public func scatterChartRendererMaxVisibleValueCount(renderer: ScatterChartRenderer) -> Int
    {
        return _chart.maxVisibleValueCount
    }
    
    // MARK: - CandleStickChartRendererDelegate
    
    public func candleStickChartRendererCandleData(renderer: CandleStickChartRenderer) -> CandleChartData!
    {
        return _chart.candleData
    }
    
    public func candleStickChartRenderer(renderer: CandleStickChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return _chart.getTransformer(which)
    }
    
    public func candleStickChartDefaultRendererValueFormatter(renderer: CandleStickChartRenderer) -> NSNumberFormatter!
    {
        return _chart._defaultValueFormatter
    }
    
    public func candleStickChartRendererChartYMax(renderer: CandleStickChartRenderer) -> Double
    {
        return _chart.chartYMax
    }
    
    public func candleStickChartRendererChartYMin(renderer: CandleStickChartRenderer) -> Double
    {
        return _chart.chartYMin
    }
    
    public func candleStickChartRendererChartXMax(renderer: CandleStickChartRenderer) -> Double
    {
        return _chart.chartXMax
    }
    
    public func candleStickChartRendererChartXMin(renderer: CandleStickChartRenderer) -> Double
    {
        return _chart.chartXMin
    }
    
    public func candleStickChartRendererMaxVisibleValueCount(renderer: CandleStickChartRenderer) -> Int
    {
        return _chart.maxVisibleValueCount
    }
    
    // MARK: - BubbleChartRendererDelegate
    
    public func bubbleChartRendererData(renderer: BubbleChartRenderer) -> BubbleChartData!
    {
        return _chart.bubbleData
    }
    
    public func bubbleChartRenderer(renderer: BubbleChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    {
        return _chart.getTransformer(which)
    }
    
    public func bubbleChartDefaultRendererValueFormatter(renderer: BubbleChartRenderer) -> NSNumberFormatter!
    {
        return _chart._defaultValueFormatter
    }
    
    public func bubbleChartRendererChartYMax(renderer: BubbleChartRenderer) -> Double
    {
        return _chart.chartYMax
    }
    
    public func bubbleChartRendererChartYMin(renderer: BubbleChartRenderer) -> Double
    {
        return _chart.chartYMin
    }
    
    public func bubbleChartRendererChartXMax(renderer: BubbleChartRenderer) -> Double
    {
        return _chart.chartXMax
    }
    
    public func bubbleChartRendererChartXMin(renderer: BubbleChartRenderer) -> Double
    {
        return _chart.chartXMin
    }
    
    public func bubbleChartRendererMaxVisibleValueCount(renderer: BubbleChartRenderer) -> Int
    {
        return _chart.maxVisibleValueCount
    }
    
    public func bubbleChartRendererXValCount(renderer: BubbleChartRenderer) -> Int
    {
        return _chart.data!.xValCount
    }
    
    // MARK: Accessors
    
    /// - returns: true if drawing the highlighting arrow is enabled, false if not
    public var isDrawHighlightArrowEnabled: Bool { return drawHighlightArrowEnabled; }
    
    /// - returns: true if drawing values above bars is enabled, false if not
    public var isDrawValueAboveBarEnabled: Bool { return drawValueAboveBarEnabled; }
    
    /// - returns: true if drawing shadows (maxvalue) for each bar is enabled, false if not
    public var isDrawBarShadowEnabled: Bool { return drawBarShadowEnabled; }
    
    /// the order in which the provided data objects should be drawn.
    /// The earlier you place them in the provided array, the further they will be in the background.
    /// e.g. if you provide [DrawOrder.Bar, DrawOrder.Line], the bars will be drawn behind the lines.
    public var drawOrder: [CombinedChartView.CombinedChartDrawOrder]
    {
        get
        {
            return _drawOrder
        }
        set
        {
            if (newValue.count > 0)
            {
                _drawOrder = newValue
            }
        }
    }
}