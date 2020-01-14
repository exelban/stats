//
//  CandleStickChartRenderer.swift
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

@objc
public protocol CandleStickChartRendererDelegate
{
    func candleStickChartRendererCandleData(renderer: CandleStickChartRenderer) -> CandleChartData!
    func candleStickChartRenderer(renderer: CandleStickChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    func candleStickChartDefaultRendererValueFormatter(renderer: CandleStickChartRenderer) -> NSNumberFormatter!
    func candleStickChartRendererChartYMax(renderer: CandleStickChartRenderer) -> Double
    func candleStickChartRendererChartYMin(renderer: CandleStickChartRenderer) -> Double
    func candleStickChartRendererChartXMax(renderer: CandleStickChartRenderer) -> Double
    func candleStickChartRendererChartXMin(renderer: CandleStickChartRenderer) -> Double
    func candleStickChartRendererMaxVisibleValueCount(renderer: CandleStickChartRenderer) -> Int
}

public class CandleStickChartRenderer: LineScatterCandleRadarChartRenderer
{
    public weak var delegate: CandleStickChartRendererDelegate?
    
    public init(delegate: CandleStickChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.delegate = delegate
    }
    
    public override func drawData(context context: CGContext?)
    {
        let candleData = delegate!.candleStickChartRendererCandleData(self)

        for set in candleData.dataSets as! [CandleChartDataSet]
        {
            if set.isVisible && set.entryCount > 0
            {
                drawDataSet(context: context, dataSet: set)
            }
        }
    }
    
    private var _shadowPoints = [CGPoint](count: 2, repeatedValue: CGPoint())
    private var _bodyRect = CGRect()
    private var _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawDataSet(context context: CGContext?, dataSet: CandleChartDataSet)
    {
        let trans = delegate!.candleStickChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        let bodySpace = dataSet.bodySpace
        
        var entries = dataSet.yVals as! [CandleChartDataEntry]
        
        let minx = max(_minX, 0)
        let maxx = min(_maxX + 1, entries.count)
        
        CGContextSaveGState(context)
        
        CGContextSetLineWidth(context, dataSet.shadowWidth)
        
        for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx))); j < count; j++)
        {
            // get the entry
            let e = entries[j]
            
            if (e.xIndex < _minX || e.xIndex > _maxX)
            {
                continue
            }
            
            // calculate the shadow
            
            _shadowPoints[0].x = CGFloat(e.xIndex)
            _shadowPoints[0].y = CGFloat(e.high) * phaseY
            _shadowPoints[1].x = CGFloat(e.xIndex)
            _shadowPoints[1].y = CGFloat(e.low) * phaseY
            
            trans.pointValuesToPixel(&_shadowPoints)
            
            // draw the shadow
            
            var shadowColor: UIColor! = nil
            if (dataSet.shadowColorSameAsCandle)
            {
                if (e.open > e.close)
                {
                    shadowColor = dataSet.decreasingColor ?? dataSet.colorAt(j)
                }
                else if (e.open < e.close)
                {
                    shadowColor = dataSet.increasingColor ?? dataSet.colorAt(j)
                }
            }
            
            if (shadowColor === nil)
            {
                shadowColor = dataSet.shadowColor ?? dataSet.colorAt(j);
            }
            
            CGContextSetStrokeColorWithColor(context, shadowColor.CGColor)
            CGContextStrokeLineSegments(context, _shadowPoints, 2)
            
            // calculate the body
            
            _bodyRect.origin.x = CGFloat(e.xIndex) - 0.5 + bodySpace
            _bodyRect.origin.y = CGFloat(e.close) * phaseY
            _bodyRect.size.width = (CGFloat(e.xIndex) + 0.5 - bodySpace) - _bodyRect.origin.x
            _bodyRect.size.height = (CGFloat(e.open) * phaseY) - _bodyRect.origin.y
            
            trans.rectValueToPixel(&_bodyRect)
            
            // draw body differently for increasing and decreasing entry
            
            if (e.open > e.close)
            {
                let color = dataSet.decreasingColor ?? dataSet.colorAt(j)
                
                if (dataSet.isDecreasingFilled)
                {
                    CGContextSetFillColorWithColor(context, color.CGColor)
                    CGContextFillRect(context, _bodyRect)
                }
                else
                {
                    CGContextSetStrokeColorWithColor(context, color.CGColor)
                    CGContextStrokeRect(context, _bodyRect)
                }
            }
            else if (e.open < e.close)
            {
                let color = dataSet.increasingColor ?? dataSet.colorAt(j)
                
                if (dataSet.isIncreasingFilled)
                {
                    CGContextSetFillColorWithColor(context, color.CGColor)
                    CGContextFillRect(context, _bodyRect)
                }
                else
                {
                    CGContextSetStrokeColorWithColor(context, color.CGColor)
                    CGContextStrokeRect(context, _bodyRect)
                }
            }
            else
            {
                CGContextSetStrokeColorWithColor(context, shadowColor.CGColor)
                CGContextStrokeRect(context, _bodyRect)
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        let candleData = delegate!.candleStickChartRendererCandleData(self)
        if (candleData === nil)
        {
            return
        }
        
        let defaultValueFormatter = delegate!.candleStickChartDefaultRendererValueFormatter(self)
        
        // if values are drawn
        if (candleData.yValCount < Int(ceil(CGFloat(delegate!.candleStickChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleX)))
        {
            var dataSets = candleData.dataSets
            
            for (var i = 0; i < dataSets.count; i++)
            {
                let dataSet = dataSets[i]
                
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let valueFont = dataSet.valueFont
                let valueTextColor = dataSet.valueTextColor
                
                var formatter = dataSet.valueFormatter
                if (formatter === nil)
                {
                    formatter = defaultValueFormatter
                }
                
                let trans = delegate!.candleStickChartRenderer(self, transformerForAxis: dataSet.axisDependency)
                
                var entries = dataSet.yVals as! [CandleChartDataEntry]
                
                let minx = max(_minX, 0)
                let maxx = min(_maxX + 1, entries.count)
                
                var positions = trans.generateTransformedValuesCandle(entries, phaseY: _animator.phaseY)
                
                let lineHeight = valueFont.lineHeight
                let yOffset: CGFloat = lineHeight + 5.0
                
                for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * _animator.phaseX + CGFloat(minx))); j < count; j++)
                {
                    let x = positions[j].x
                    let y = positions[j].y
                    
                    if (!viewPortHandler.isInBoundsRight(x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(x) || !viewPortHandler.isInBoundsY(y))
                    {
                        continue
                    }
                    
                    let val = entries[j].high
                    
                    ChartUtils.drawText(context: context, text: formatter!.stringFromNumber(val)!, point: CGPoint(x: x, y: y - yOffset), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
            }
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
    }
    
    private var _highlightPointBuffer = CGPoint()
    
    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        let candleData = delegate!.candleStickChartRendererCandleData(self)
        if (candleData === nil)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        for (var i = 0; i < indices.count; i++)
        {
            let xIndex = indices[i].xIndex; // get the x-position
            
            let set = candleData.getDataSetByIndex(indices[i].dataSetIndex) as! CandleChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
            let e = set.entryForXIndex(xIndex) as! CandleChartDataEntry!
            
            if (e === nil || e.xIndex != xIndex)
            {
                continue
            }
            
            let trans = delegate!.candleStickChartRenderer(self, transformerForAxis: set.axisDependency)
            
            CGContextSetStrokeColorWithColor(context, set.highlightColor.CGColor)
            CGContextSetLineWidth(context, set.highlightLineWidth)
            if (set.highlightLineDashLengths != nil)
            {
                CGContextSetLineDash(context, set.highlightLineDashPhase, set.highlightLineDashLengths!, set.highlightLineDashLengths!.count)
            }
            else
            {
                CGContextSetLineDash(context, 0.0, nil, 0)
            }
            
            let low = CGFloat(e.low) * _animator.phaseY
            let high = CGFloat(e.high) * _animator.phaseY
            let y = (low + high) / 2.0
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            trans.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        CGContextRestoreGState(context)
    }
}