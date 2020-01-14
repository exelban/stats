//
//  LineChartRenderer.swift
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
public protocol LineChartRendererDelegate
{
    func lineChartRendererData(renderer: LineChartRenderer) -> LineChartData!
    func lineChartRenderer(renderer: LineChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    func lineChartRendererFillFormatter(renderer: LineChartRenderer) -> ChartFillFormatter
    func lineChartDefaultRendererValueFormatter(renderer: LineChartRenderer) -> NSNumberFormatter!
    func lineChartRendererChartYMax(renderer: LineChartRenderer) -> Double
    func lineChartRendererChartYMin(renderer: LineChartRenderer) -> Double
    func lineChartRendererChartXMax(renderer: LineChartRenderer) -> Double
    func lineChartRendererChartXMin(renderer: LineChartRenderer) -> Double
    func lineChartRendererMaxVisibleValueCount(renderer: LineChartRenderer) -> Int
}

public class LineChartRenderer: LineScatterCandleRadarChartRenderer
{
    public weak var delegate: LineChartRendererDelegate?
    
    public init(delegate: LineChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.delegate = delegate
    }
    
    public override func drawData(context context: CGContext?)
    {
        let lineData = delegate!.lineChartRendererData(self)
        
        if (lineData === nil)
        {
            return
        }
        
        for (var i = 0; i < lineData.dataSetCount; i++)
        {
            let set = lineData.getDataSetByIndex(i)
            
            if (set !== nil && set!.isVisible)
            {
                drawDataSet(context: context, dataSet: set as! LineChartDataSet)
            }
        }
    }
    
    internal struct CGCPoint
    {
        internal var x: CGFloat = 0.0
        internal var y: CGFloat = 0.0
        
        ///  x-axis distance
        internal var dx: CGFloat = 0.0
        ///  y-axis distance
        internal var dy: CGFloat = 0.0
        
        internal init(x: CGFloat, y: CGFloat)
        {
            self.x = x
            self.y = y
        }
    }
    
    internal func drawDataSet(context context: CGContext?, dataSet: LineChartDataSet)
    {
        let entries = dataSet.yVals
        
        if (entries.count < 1)
        {
            return
        }
        
        CGContextSaveGState(context)
        
        CGContextSetLineWidth(context, dataSet.lineWidth)
        if (dataSet.lineDashLengths != nil)
        {
            CGContextSetLineDash(context, dataSet.lineDashPhase, dataSet.lineDashLengths, dataSet.lineDashLengths.count)
        }
        else
        {
            CGContextSetLineDash(context, 0.0, nil, 0)
        }
        
        // if drawing cubic lines is enabled
        if (dataSet.isDrawCubicEnabled)
        {
            drawCubic(context: context, dataSet: dataSet, entries: entries)
        }
        else
        { // draw normal (straight) lines
            drawLinear(context: context, dataSet: dataSet, entries: entries)
        }
        
        CGContextRestoreGState(context)
    }
    
    internal func drawCubic(context context: CGContext?, dataSet: LineChartDataSet, entries: [ChartDataEntry])
    {
        let trans = delegate?.lineChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        let entryFrom = dataSet.entryForXIndex(_minX)
        let entryTo = dataSet.entryForXIndex(_maxX)
        
        let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
        let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, entries.count)
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        // get the color that is specified for this position from the DataSet
        let drawingColor = dataSet.colors.first!
        
        let intensity = dataSet.cubicIntensity
        
        // the path for the cubic-spline
        let cubicPath = CGPathCreateMutable()
        
        var valueToPixelMatrix = trans!.valueToPixelMatrix
        
        let size = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx)))
        
        if (size - minx >= 2)
        {
            var prevDx: CGFloat = 0.0
            var prevDy: CGFloat = 0.0
            var curDx: CGFloat = 0.0
            var curDy: CGFloat = 0.0
            
            var prevPrev = entries[minx]
            var prev = entries[minx]
            var cur = entries[minx]
            var next = entries[minx + 1]
            
            // let the spline start
            CGPathMoveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(cur.xIndex), CGFloat(cur.value) * phaseY)
            
            prevDx = CGFloat(cur.xIndex - prev.xIndex) * intensity
            prevDy = CGFloat(cur.value - prev.value) * intensity
            
            curDx = CGFloat(next.xIndex - cur.xIndex) * intensity
            curDy = CGFloat(next.value - cur.value) * intensity
            
            // the first cubic
            CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix,
                CGFloat(prev.xIndex) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                CGFloat(cur.xIndex) - curDx, (CGFloat(cur.value) - curDy) * phaseY,
                CGFloat(cur.xIndex), CGFloat(cur.value) * phaseY)
            
            for (var j = minx + 1, count = min(size, entries.count - 1); j < count; j++)
            {
                prevPrev = entries[j == 1 ? 0 : j - 2]
                prev = entries[j - 1]
                cur = entries[j]
                next = entries[j + 1]
                
                prevDx = CGFloat(cur.xIndex - prevPrev.xIndex) * intensity
                prevDy = CGFloat(cur.value - prevPrev.value) * intensity
                curDx = CGFloat(next.xIndex - prev.xIndex) * intensity
                curDy = CGFloat(next.value - prev.value) * intensity
                
                CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(prev.xIndex) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                    CGFloat(cur.xIndex) - curDx,
                    (CGFloat(cur.value) - curDy) * phaseY, CGFloat(cur.xIndex), CGFloat(cur.value) * phaseY)
            }
            
            if (size > entries.count - 1)
            {
                prevPrev = entries[entries.count - (entries.count >= 3 ? 3 : 2)]
                prev = entries[entries.count - 2]
                cur = entries[entries.count - 1]
                next = cur
                
                prevDx = CGFloat(cur.xIndex - prevPrev.xIndex) * intensity
                prevDy = CGFloat(cur.value - prevPrev.value) * intensity
                curDx = CGFloat(next.xIndex - prev.xIndex) * intensity
                curDy = CGFloat(next.value - prev.value) * intensity
                
                // the last cubic
                CGPathAddCurveToPoint(cubicPath, &valueToPixelMatrix, CGFloat(prev.xIndex) + prevDx, (CGFloat(prev.value) + prevDy) * phaseY,
                    CGFloat(cur.xIndex) - curDx,
                    (CGFloat(cur.value) - curDy) * phaseY, CGFloat(cur.xIndex), CGFloat(cur.value) * phaseY)
            }
        }
        
        CGContextSaveGState(context)
        
        if (dataSet.isDrawFilledEnabled)
        {
            drawCubicFill(context: context, dataSet: dataSet, spline: cubicPath, matrix: valueToPixelMatrix, from: minx, to: size)
        }
        
        CGContextBeginPath(context)
        CGContextAddPath(context, cubicPath)
        CGContextSetStrokeColorWithColor(context, drawingColor.CGColor)
        CGContextStrokePath(context)
        
        CGContextRestoreGState(context)
    }
    
    internal func drawCubicFill(context context: CGContext?, dataSet: LineChartDataSet, spline: CGMutablePath, matrix: CGAffineTransform, from: Int, to: Int)
    {
        if to - from <= 1
        {
            return
        }
        
        CGContextSaveGState(context)
        
        let fillMin = delegate!.lineChartRendererFillFormatter(self).getFillLinePosition(
            dataSet: dataSet,
            data: delegate!.lineChartRendererData(self),
            chartMaxY: delegate!.lineChartRendererChartYMax(self),
            chartMinY: delegate!.lineChartRendererChartYMin(self))
        
        var pt1 = CGPoint(x: CGFloat(to - 1), y: fillMin)
        var pt2 = CGPoint(x: CGFloat(from), y: fillMin)
        pt1 = CGPointApplyAffineTransform(pt1, matrix)
        pt2 = CGPointApplyAffineTransform(pt2, matrix)
        
        CGContextBeginPath(context)
        CGContextAddPath(context, spline)
        CGContextAddLineToPoint(context, pt1.x, pt1.y)
        CGContextAddLineToPoint(context, pt2.x, pt2.y)
        CGContextClosePath(context)
        
        CGContextSetFillColorWithColor(context, dataSet.fillColor.CGColor)
        CGContextSetAlpha(context, dataSet.fillAlpha)
        CGContextFillPath(context)
        
        CGContextRestoreGState(context)
    }
    
    private var _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawLinear(context context: CGContext?, dataSet: LineChartDataSet, entries: [ChartDataEntry])
    {
        let trans = delegate!.lineChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        CGContextSaveGState(context)
        
        let entryFrom = dataSet.entryForXIndex(_minX)
        let entryTo = dataSet.entryForXIndex(_maxX)
        
        let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
        let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, entries.count)
        
        // more than 1 color
        if (dataSet.colors.count > 1)
        {
            if (_lineSegments.count != 2)
            {
                _lineSegments = [CGPoint](count: 2, repeatedValue: CGPoint())
            }
            
            for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx))); j < count; j++)
            {
                if (count > 1 && j == count - 1)
                { // Last point, we have already drawn a line to this point
                    break
                }
                
                var e = entries[j]
                
                _lineSegments[0].x = CGFloat(e.xIndex)
                _lineSegments[0].y = CGFloat(e.value) * phaseY
                _lineSegments[0] = CGPointApplyAffineTransform(_lineSegments[0], valueToPixelMatrix)
                if (j + 1 < count)
                {
                    e = entries[j + 1]
                    
                    _lineSegments[1].x = CGFloat(e.xIndex)
                    _lineSegments[1].y = CGFloat(e.value) * phaseY
                    _lineSegments[1] = CGPointApplyAffineTransform(_lineSegments[1], valueToPixelMatrix)
                }
                else
                {
                    _lineSegments[1] = _lineSegments[0]
                }
                
                if (!viewPortHandler.isInBoundsRight(_lineSegments[0].x))
                {
                    break
                }
                
                // make sure the lines don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsLeft(_lineSegments[1].x)
                    || (!viewPortHandler.isInBoundsTop(_lineSegments[0].y) && !viewPortHandler.isInBoundsBottom(_lineSegments[1].y))
                    || (!viewPortHandler.isInBoundsTop(_lineSegments[0].y) && !viewPortHandler.isInBoundsBottom(_lineSegments[1].y)))
                {
                    continue
                }
                
                // get the color that is set for this line-segment
                CGContextSetStrokeColorWithColor(context, dataSet.colorAt(j).CGColor)
                CGContextStrokeLineSegments(context, _lineSegments, 2)
            }
        }
        else
        { // only one color per dataset
            
            var e1: ChartDataEntry!
            var e2: ChartDataEntry!
            
            if (_lineSegments.count != max((entries.count - 1) * 2, 2))
            {
                _lineSegments = [CGPoint](count: max((entries.count - 1) * 2, 2), repeatedValue: CGPoint())
            }
            
            e1 = entries[minx]
            
            let count = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx)))
            
            for (var x = count > 1 ? minx + 1 : minx, j = 0; x < count; x++)
            {
                e1 = entries[x == 0 ? 0 : (x - 1)]
                e2 = entries[x]
                
                _lineSegments[j++] = CGPointApplyAffineTransform(CGPoint(x: CGFloat(e1.xIndex), y: CGFloat(e1.value) * phaseY), valueToPixelMatrix)
                _lineSegments[j++] = CGPointApplyAffineTransform(CGPoint(x: CGFloat(e2.xIndex), y: CGFloat(e2.value) * phaseY), valueToPixelMatrix)
            }
            
            let size = max((count - minx - 1) * 2, 2)
            CGContextSetStrokeColorWithColor(context, dataSet.colorAt(0).CGColor)
            CGContextStrokeLineSegments(context, _lineSegments, size)
        }
        
        CGContextRestoreGState(context)
        
        // if drawing filled is enabled
        if (dataSet.isDrawFilledEnabled && entries.count > 0)
        {
            drawLinearFill(context: context, dataSet: dataSet, entries: entries, minx: minx, maxx: maxx, trans: trans)
        }
    }
    
    internal func drawLinearFill(context context: CGContext?, dataSet: LineChartDataSet, entries: [ChartDataEntry], minx: Int, maxx: Int, trans: ChartTransformer)
    {
        CGContextSaveGState(context)
        
        CGContextSetFillColorWithColor(context, dataSet.fillColor.CGColor)
        
        // filled is usually drawn with less alpha
        CGContextSetAlpha(context, dataSet.fillAlpha)
        
        let filled = generateFilledPath(
            entries,
            fillMin: delegate!.lineChartRendererFillFormatter(self).getFillLinePosition(
                dataSet: dataSet,
                data: delegate!.lineChartRendererData(self),
                chartMaxY: delegate!.lineChartRendererChartYMax(self),
                chartMinY: delegate!.lineChartRendererChartYMin(self)),
            from: minx,
            to: maxx,
            matrix: trans.valueToPixelMatrix)
        
        CGContextBeginPath(context)
        CGContextAddPath(context, filled)
        CGContextFillPath(context)
        
        CGContextRestoreGState(context)
    }
    
    /// Generates the path that is used for filled drawing.
    private func generateFilledPath(entries: [ChartDataEntry], fillMin: CGFloat, from: Int, to: Int, var matrix: CGAffineTransform) -> CGPath
    {
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        let filled = CGPathCreateMutable()
        CGPathMoveToPoint(filled, &matrix, CGFloat(entries[from].xIndex), fillMin)
        CGPathAddLineToPoint(filled, &matrix, CGFloat(entries[from].xIndex), CGFloat(entries[from].value) * phaseY)
        
        // create a new path
        for (var x = from + 1, count = Int(ceil(CGFloat(to - from) * phaseX + CGFloat(from))); x < count; x++)
        {
            let e = entries[x]
            CGPathAddLineToPoint(filled, &matrix, CGFloat(e.xIndex), CGFloat(e.value) * phaseY)
        }
        
        // close up
        CGPathAddLineToPoint(filled, &matrix, CGFloat(entries[max(min(Int(ceil(CGFloat(to - from) * phaseX + CGFloat(from))) - 1, entries.count - 1), 0)].xIndex), fillMin)
        CGPathCloseSubpath(filled)
        
        return filled
    }
    
    public override func drawValues(context context: CGContext?)
    {
        let lineData = delegate!.lineChartRendererData(self)
        if (lineData === nil)
        {
            return
        }
        
        let defaultValueFormatter = delegate!.lineChartDefaultRendererValueFormatter(self)
        
        if (CGFloat(lineData.yValCount) < CGFloat(delegate!.lineChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleX)
        {
            var dataSets = lineData.dataSets
            
            for (var i = 0; i < dataSets.count; i++)
            {
                let dataSet = dataSets[i] as! LineChartDataSet
                
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
                
                let trans = delegate!.lineChartRenderer(self, transformerForAxis: dataSet.axisDependency)
                
                // make sure the values do not interfear with the circles
                var valOffset = Int(dataSet.circleRadius * 1.75)
                
                if (!dataSet.isDrawCirclesEnabled)
                {
                    valOffset = valOffset / 2
                }
                
                var entries = dataSet.yVals
                
                let entryFrom = dataSet.entryForXIndex(_minX)
                let entryTo = dataSet.entryForXIndex(_maxX)
                
                let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
                let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, entries.count)
                
                var positions = trans.generateTransformedValuesLine(
                    entries,
                    phaseX: _animator.phaseX,
                    phaseY: _animator.phaseY,
                    from: minx,
                    to: maxx)
                
                for (var j = 0, count = positions.count; j < count; j++)
                {
                    if (!viewPortHandler.isInBoundsRight(positions[j].x))
                    {
                        break
                    }
                    
                    if (!viewPortHandler.isInBoundsLeft(positions[j].x) || !viewPortHandler.isInBoundsY(positions[j].y))
                    {
                        continue
                    }
                    
                    let val = entries[j + minx].value
                    
                    ChartUtils.drawText(context: context, text: formatter!.stringFromNumber(val)!, point: CGPoint(x: positions[j].x, y: positions[j].y - CGFloat(valOffset) - valueFont.lineHeight), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
            }
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
        drawCircles(context: context)
    }
    
    private func drawCircles(context context: CGContext?)
    {
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        let lineData = delegate!.lineChartRendererData(self)
        
        let dataSets = lineData.dataSets
        
        var pt = CGPoint()
        var rect = CGRect()
        
        CGContextSaveGState(context)
        
        for (var i = 0, count = dataSets.count; i < count; i++)
        {
            let dataSet = lineData.getDataSetByIndex(i) as! LineChartDataSet!
            
            if (!dataSet.isVisible || !dataSet.isDrawCirclesEnabled)
            {
                continue
            }
            
            let trans = delegate!.lineChartRenderer(self, transformerForAxis: dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix
            
            var entries = dataSet.yVals
            
            let circleRadius = dataSet.circleRadius
            let circleDiameter = circleRadius * 2.0
            let circleHoleDiameter = circleRadius
            let circleHoleRadius = circleHoleDiameter / 2.0
            let isDrawCircleHoleEnabled = dataSet.isDrawCircleHoleEnabled
            
            let entryFrom = dataSet.entryForXIndex(_minX)!
            let entryTo = dataSet.entryForXIndex(_maxX)!
            
            let minx = max(dataSet.entryIndex(entry: entryFrom, isEqual: true), 0)
            let maxx = min(dataSet.entryIndex(entry: entryTo, isEqual: true) + 1, entries.count)
            
            for (var j = minx, count = Int(ceil(CGFloat(maxx - minx) * phaseX + CGFloat(minx))); j < count; j++)
            {
                let e = entries[j]
                pt.x = CGFloat(e.xIndex)
                pt.y = CGFloat(e.value) * phaseY
                pt = CGPointApplyAffineTransform(pt, valueToPixelMatrix)
                
                if (!viewPortHandler.isInBoundsRight(pt.x))
                {
                    break
                }
                
                // make sure the circles don't do shitty things outside bounds
                if (!viewPortHandler.isInBoundsLeft(pt.x) || !viewPortHandler.isInBoundsY(pt.y))
                {
                    continue
                }
                
                CGContextSetFillColorWithColor(context, dataSet.getCircleColor(j)!.CGColor)
                
                rect.origin.x = pt.x - circleRadius
                rect.origin.y = pt.y - circleRadius
                rect.size.width = circleDiameter
                rect.size.height = circleDiameter
                CGContextFillEllipseInRect(context, rect)
                
                if (isDrawCircleHoleEnabled)
                {
                    CGContextSetFillColorWithColor(context, dataSet.circleHoleColor.CGColor)
                    
                    rect.origin.x = pt.x - circleHoleRadius
                    rect.origin.y = pt.y - circleHoleRadius
                    rect.size.width = circleHoleDiameter
                    rect.size.height = circleHoleDiameter
                    CGContextFillEllipseInRect(context, rect)
                }
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    private var _highlightPointBuffer = CGPoint()
    
    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        let lineData = delegate!.lineChartRendererData(self)
        let chartXMax = delegate!.lineChartRendererChartXMax(self)
        CGContextSaveGState(context)
        
        for (var i = 0; i < indices.count; i++)
        {
            let set = lineData.getDataSetByIndex(indices[i].dataSetIndex) as! LineChartDataSet!
            
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
            
            let yValue = set.yValForXIndex(xIndex)
            if (yValue.isNaN)
            {
                continue
            }
            
            let y = CGFloat(yValue) * _animator.phaseY; // get the y-position
            
            _highlightPointBuffer.x = CGFloat(xIndex)
            _highlightPointBuffer.y = y
            
            let trans = delegate!.lineChartRenderer(self, transformerForAxis: set.axisDependency)
            
            trans.pointValueToPixel(&_highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
        }
        
        CGContextRestoreGState(context)
    }
}