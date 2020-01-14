//
//  BubbleChartRenderer.swift
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
import UIKit

@objc
public protocol BubbleChartRendererDelegate
{
    func bubbleChartRendererData(renderer: BubbleChartRenderer) -> BubbleChartData!
    func bubbleChartRenderer(renderer: BubbleChartRenderer, transformerForAxis which: ChartYAxis.AxisDependency) -> ChartTransformer!
    func bubbleChartDefaultRendererValueFormatter(renderer: BubbleChartRenderer) -> NSNumberFormatter!
    func bubbleChartRendererChartYMax(renderer: BubbleChartRenderer) -> Double
    func bubbleChartRendererChartYMin(renderer: BubbleChartRenderer) -> Double
    func bubbleChartRendererChartXMax(renderer: BubbleChartRenderer) -> Double
    func bubbleChartRendererChartXMin(renderer: BubbleChartRenderer) -> Double
    func bubbleChartRendererMaxVisibleValueCount(renderer: BubbleChartRenderer) -> Int
    func bubbleChartRendererXValCount(renderer: BubbleChartRenderer) -> Int
}

public class BubbleChartRenderer: ChartDataRendererBase
{
    public weak var delegate: BubbleChartRendererDelegate?
    
    public init(delegate: BubbleChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.delegate = delegate
    }
    
    public override func drawData(context context: CGContext?)
    {
        let bubbleData = delegate!.bubbleChartRendererData(self)
        
        for set in bubbleData.dataSets as! [BubbleChartDataSet]
        {
            if set.isVisible && set.entryCount > 0
            {
                drawDataSet(context: context, dataSet: set)
            }
        }
    }
    
    private func getShapeSize(entrySize entrySize: CGFloat, maxSize: CGFloat, reference: CGFloat) -> CGFloat
    {
        let factor: CGFloat = (maxSize == 0.0) ? 1.0 : sqrt(entrySize / maxSize)
        let shapeSize: CGFloat = reference * factor
        return shapeSize
    }
    
    private var _pointBuffer = CGPoint()
    private var _sizeBuffer = [CGPoint](count: 2, repeatedValue: CGPoint())
    
    internal func drawDataSet(context context: CGContext?, dataSet: BubbleChartDataSet)
    {
        let trans = delegate!.bubbleChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        let entries = dataSet.yVals as! [BubbleChartDataEntry]
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
        
        CGContextSaveGState(context)
        
        let entryFrom = dataSet.entryForXIndex(_minX)
        let entryTo = dataSet.entryForXIndex(_maxX)
        
        let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
        let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, entries.count)
        
        _sizeBuffer[0].x = 0.0
        _sizeBuffer[0].y = 0.0
        _sizeBuffer[1].x = 1.0
        _sizeBuffer[1].y = 0.0
        
        trans.pointValuesToPixel(&_sizeBuffer)
        
        // calcualte the full width of 1 step on the x-axis
        let maxBubbleWidth: CGFloat = abs(_sizeBuffer[1].x - _sizeBuffer[0].x)
        let maxBubbleHeight: CGFloat = abs(viewPortHandler.contentBottom - viewPortHandler.contentTop)
        let referenceSize: CGFloat = min(maxBubbleHeight, maxBubbleWidth)
        
        for (var j = minx; j < maxx; j++)
        {
            let entry = entries[j]
            
            _pointBuffer.x = CGFloat(entry.xIndex - minx) * phaseX + CGFloat(minx)
            _pointBuffer.y = CGFloat(entry.value) * phaseY
            _pointBuffer = CGPointApplyAffineTransform(_pointBuffer, valueToPixelMatrix)
            
            let shapeSize = getShapeSize(entrySize: entry.size, maxSize: dataSet.maxSize, reference: referenceSize)
            let shapeHalf = shapeSize / 2.0
            
            if (!viewPortHandler.isInBoundsTop(_pointBuffer.y + shapeHalf)
                || !viewPortHandler.isInBoundsBottom(_pointBuffer.y - shapeHalf))
            {
                continue
            }
            
            if (!viewPortHandler.isInBoundsLeft(_pointBuffer.x + shapeHalf))
            {
                continue
            }
            
            if (!viewPortHandler.isInBoundsRight(_pointBuffer.x - shapeHalf))
            {
                break
            }
            
            let color = dataSet.colorAt(entry.xIndex)
            
            let rect = CGRect(
                x: _pointBuffer.x - shapeHalf,
                y: _pointBuffer.y - shapeHalf,
                width: shapeSize,
                height: shapeSize
            )

            CGContextSetFillColorWithColor(context, color.CGColor)
            CGContextFillEllipseInRect(context, rect)
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        let bubbleData = delegate!.bubbleChartRendererData(self)
        if (bubbleData === nil)
        {
            return
        }
        
        let defaultValueFormatter = delegate!.bubbleChartDefaultRendererValueFormatter(self)
        
        // if values are drawn
        if (bubbleData.yValCount < Int(ceil(CGFloat(delegate!.bubbleChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleX)))
        {
            let dataSets = bubbleData.dataSets as! [BubbleChartDataSet]
            
            for dataSet in dataSets
            {
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let phaseX = _animator.phaseX
                let phaseY = _animator.phaseY
                
                let alpha = phaseX == 1 ? phaseY : phaseX
                let valueTextColor = dataSet.valueTextColor.colorWithAlphaComponent(alpha)
                
                let formatter = dataSet.valueFormatter === nil ? defaultValueFormatter : dataSet.valueFormatter
                
                let entries = dataSet.yVals
                
                let entryFrom = dataSet.entryForXIndex(_minX)
                let entryTo = dataSet.entryForXIndex(_maxX)
                
                let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
                let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, entries.count)
                
                let positions = delegate!.bubbleChartRenderer(self, transformerForAxis: dataSet.axisDependency).generateTransformedValuesBubble(entries, phaseX: phaseX, phaseY: phaseY, from: minx, to: maxx)
                
                for (var j = 0, count = positions.count; j < count; j++)
                {
                    if (!viewPortHandler.isInBoundsRight(positions[j].x))
                    {
                        break
                    }
                    
                    if ((!viewPortHandler.isInBoundsLeft(positions[j].x) || !viewPortHandler.isInBoundsY(positions[j].y)))
                    {
                        continue
                    }
                    
                    let entry = entries[j + minx] as! BubbleChartDataEntry
                    
                    let val = entry.size
                    
                    let text = formatter!.stringFromNumber(val)
                    
                    // Larger font for larger bubbles?
                    let valueFont = dataSet.valueFont
                    let lineHeight = valueFont.lineHeight

                    ChartUtils.drawText(context: context, text: text!, point: CGPoint(x: positions[j].x, y: positions[j].y - ( 0.5 * lineHeight)), align: .Center, attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: valueTextColor])
                }
            }
        }
    }
    
    public override func drawExtras(context context: CGContext?)
    {
        
    }
    
    public override func drawHighlighted(context context: CGContext?, indices: [ChartHighlight])
    {
        let bubbleData = delegate!.bubbleChartRendererData(self)
        
        CGContextSaveGState(context)
        
        let phaseX = _animator.phaseX
        let phaseY = _animator.phaseY
        
        for indice in indices
        {
            let dataSet = bubbleData.getDataSetByIndex(indice.dataSetIndex) as! BubbleChartDataSet!
            
            if (dataSet === nil || !dataSet.isHighlightEnabled)
            {
                continue
            }
            
            let entryFrom = dataSet.entryForXIndex(_minX)
            let entryTo = dataSet.entryForXIndex(_maxX)
            
            let minx = max(dataSet.entryIndex(entry: entryFrom!, isEqual: true), 0)
            let maxx = min(dataSet.entryIndex(entry: entryTo!, isEqual: true) + 1, dataSet.entryCount)
            
            let entry: BubbleChartDataEntry! = bubbleData.getEntryForHighlight(indice) as! BubbleChartDataEntry
            if (entry === nil || entry.xIndex != indice.xIndex)
            {
                continue
            }
            
            let trans = delegate!.bubbleChartRenderer(self, transformerForAxis: dataSet.axisDependency)
            
            _sizeBuffer[0].x = 0.0
            _sizeBuffer[0].y = 0.0
            _sizeBuffer[1].x = 1.0
            _sizeBuffer[1].y = 0.0
            
            trans.pointValuesToPixel(&_sizeBuffer)
            
            // calcualte the full width of 1 step on the x-axis
            let maxBubbleWidth: CGFloat = abs(_sizeBuffer[1].x - _sizeBuffer[0].x)
            let maxBubbleHeight: CGFloat = abs(viewPortHandler.contentBottom - viewPortHandler.contentTop)
            let referenceSize: CGFloat = min(maxBubbleHeight, maxBubbleWidth)

            _pointBuffer.x = CGFloat(entry.xIndex - minx) * phaseX + CGFloat(minx)
            _pointBuffer.y = CGFloat(entry.value) * phaseY
            trans.pointValueToPixel(&_pointBuffer)
            
            let shapeSize = getShapeSize(entrySize: entry.size, maxSize: dataSet.maxSize, reference: referenceSize)
            let shapeHalf = shapeSize / 2.0
            
            if (!viewPortHandler.isInBoundsTop(_pointBuffer.y + shapeHalf)
                || !viewPortHandler.isInBoundsBottom(_pointBuffer.y - shapeHalf))
            {
                continue
            }
            
            if (!viewPortHandler.isInBoundsLeft(_pointBuffer.x + shapeHalf))
            {
                continue
            }
            
            if (!viewPortHandler.isInBoundsRight(_pointBuffer.x - shapeHalf))
            {
                break
            }
            
            if (indice.xIndex < minx || indice.xIndex >= maxx)
            {
                continue
            }
            
            let originalColor = dataSet.colorAt(entry.xIndex)
            
            var h: CGFloat = 0.0
            var s: CGFloat = 0.0
            var b: CGFloat = 0.0
            var a: CGFloat = 0.0
            
            originalColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            let color = UIColor(hue: h, saturation: s, brightness: b * 0.5, alpha: a)
            let rect = CGRect(
                x: _pointBuffer.x - shapeHalf,
                y: _pointBuffer.y - shapeHalf,
                width: shapeSize,
                height: shapeSize)

            CGContextSetLineWidth(context, dataSet.highlightCircleWidth)
            CGContextSetStrokeColorWithColor(context, color.CGColor)
            CGContextStrokeEllipseInRect(context, rect)
        }
        
        CGContextRestoreGState(context)
    }
}