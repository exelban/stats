//
//  ScatterChartRenderer.swift
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
public protocol ScatterChartRendererDelegate
{
    func scatterChartRendererData(renderer: ScatterChartRenderer) -> ScatterChartData!
    func scatterChartRenderer(renderer: ScatterChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    func scatterChartDefaultRendererValueFormatter(renderer: ScatterChartRenderer) -> NSNumberFormatter!
    func scatterChartRendererChartYMax(renderer: ScatterChartRenderer) -> Double
    func scatterChartRendererChartYMin(renderer: ScatterChartRenderer) -> Double
    func scatterChartRendererChartXMax(renderer: ScatterChartRenderer) -> Double
    func scatterChartRendererChartXMin(renderer: ScatterChartRenderer) -> Double
    func scatterChartRendererMaxVisibleValueCount(renderer: ScatterChartRenderer) -> Int
}

public class ScatterChartRenderer: LineScatterCandleRadarChartRenderer
{
    public weak var delegate: ScatterChartRendererDelegate?
    
    public init(delegate: ScatterChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.delegate = delegate
    }
    
    public override func drawData(context context: CGContext?)
    {
        let scatterData = delegate!.scatterChartRendererData(self)
        
        if (scatterData === nil)
        {
            return
        }
        
        for (var i = 0; i < scatterData.dataSetCount; i++)
        {
            let set = scatterData.getDataSetByIndex(i)
            
            if (set !== nil && set!.isVisible)
            {
                drawDataSet(context: context, dataSet: set as! ScatterChartDataSet)
            }
        }
    }
    
    private var _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawDataSet(context context: CGContext?, dataSet: ScatterChartDataSet)
    {
        let trans = delegate!.scatterChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        let phaseY = _animator.phaseY
        
        var entries = dataSet.yVals
        
        let shapeSize = dataSet.scatterShapeSize
        let shapeHalf = shapeSize / 2.0
        
        var point = CGPoint()
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let shape = dataSet.scatterShape
        
        CGContextSaveGState(context)
        
        for (var j = 0, count = Int(min(ceil(CGFloat(entries.count) * _animator.phaseX), CGFloat(entries.count))); j < count; j++)
        {
            let e = entries[j]
            point.x = CGFloat(e.xIndex)
            point.y = CGFloat(e.value) * phaseY
            point = CGPointApplyAffineTransform(point, valueToPixelMatrix);            
            
            if (!viewPortHandler.isInBoundsRight(point.x))
            {
                break
            }
            
            if (!viewPortHandler.isInBoundsLeft(point.x) || !viewPortHandler.isInBoundsY(point.y))
            {
                continue
            }
            
            if (shape == .Square)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                CGContextFillRect(context, rect)
            }
            else if (shape == .Circle)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                var rect = CGRect()
                rect.origin.x = point.x - shapeHalf
                rect.origin.y = point.y - shapeHalf
                rect.size.width = shapeSize
                rect.size.height = shapeSize
                CGContextFillEllipseInRect(context, rect)
            }
            else if (shape == .Cross)
            {
                CGContextSetStrokeColorWithColor(context, dataSet.colorAt(j).CGColor)
                _lineSegments[0].x = point.x - shapeHalf
                _lineSegments[0].y = point.y
                _lineSegments[1].x = point.x + shapeHalf
                _lineSegments[1].y = point.y
                CGContextStrokeLineSegments(context, _lineSegments, 2)
                
                _lineSegments[0].x = point.x
                _lineSegments[0].y = point.y - shapeHalf
                _lineSegments[1].x = point.x
                _lineSegments[1].y = point.y + shapeHalf
                CGContextStrokeLineSegments(context, _lineSegments, 2)
            }
            else if (shape == .Triangle)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                
                // create a triangle path
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, point.x, point.y - shapeHalf)
                CGContextAddLineToPoint(context, point.x + shapeHalf, point.y + shapeHalf)
                CGContextAddLineToPoint(context, point.x - shapeHalf, point.y + shapeHalf)
                CGContextClosePath(context)
                
                CGContextFillPath(context)
            }
            else if (shape == .Custom)
            {
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                
                let customShape = dataSet.customScatterShape
                
                if (customShape === nil)
                {
                    return
                }
                
                // transform the provided custom path
                CGContextSaveGState(context)
                CGContextTranslateCTM(context, point.x, point.y)
                
                CGContextBeginPath(context)
                CGContextAddPath(context, customShape)
                CGContextFillPath(context)
                
                CGContextRestoreGState(context)
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        let scatterData = delegate!.scatterChartRendererData(self)
        if (scatterData === nil)
        {
            return
        }
        
        let defaultValueFormatter = delegate!.scatterChartDefaultRendererValueFormatter(self)
        
        // if values are drawn
        if (scatterData.yValCount < Int(ceil(CGFloat(delegate!.scatterChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleX)))
        {
            var dataSets = scatterData.dataSets as! [ScatterChartDataSet]
            
            for (var i = 0; i < scatterData.dataSetCount; i++)
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
                
                var entries = dataSet.yVals
                
                var positions = delegate!.scatterChartRenderer(self, transformerForAxis: dataSet.axisDependency).generateTransformedValuesScatter(entries, phaseY: _animator.phaseY)
                
                let shapeSize = dataSet.scatterShapeSize
                let lineHeight = valueFont.lineHeight
                
                for (var j = 0, count = Int(ceil(CGFloat(positions.count) * _animator.phaseX)); j < count; j++)
                {
                    if (!viewPortHandler.isInBoundsRight(positions[j].x))
                    {
                        break
                    }
                    
                    // make sure the lines don't do shitty things outside bounds
                    if ((!viewPortHandler.isInBoundsLeft(positions[j].x)
                        || !viewPortHandler.isInBoundsY(positions[j].y)))
                    {
                        continue
                    }
                    
                    let val = entries[j].value
                    
                    let text = formatter!.stringFromNumber(val)
                    
                    ChartUtils.drawText(context: context, text: text!, point: CGPoint(x: positions[j].x, y: positions[j].y - shapeSize - lineHeight), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
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
        let scatterData = delegate!.scatterChartRendererData(self)
        let chartXMax = delegate!.scatterChartRendererChartXMax(self)
        CGContextSaveGState(context)
        
        for (var i = 0; i < indices.count; i++)
        {
            let set = scatterData.getDataSetByIndex(indices[i].dataSetIndex) as! ScatterChartDataSet!
            
            if (set === nil || !set.isHighlightEnabled)
            {
                continue
            }
            
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
            
            let xIndex = indices[i].xIndex; // get the x-position
            
            if (CGFloat(xIndex) > CGFloat(chartXMax) * _animator.phaseX)
            {
                continue
            }
            
            let yVal = set.yValForXIndex(xIndex)
            if (yVal.isNaN)
            {
                continue
            }
            
            let y = CGFloat(yVal) * _animator.phaseY; // get the y-position
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            let trans = delegate!.scatterChartRenderer(self, transformerForAxis: set.axisDependency)
            
            trans.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        CGContextRestoreGState(context)
    }
}