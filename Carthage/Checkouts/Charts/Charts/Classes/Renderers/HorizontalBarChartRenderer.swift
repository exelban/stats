//
//  HorizontalBarChartRenderer.swift
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

public class HorizontalBarChartRenderer: BarChartRenderer
{
    public override init(delegate: BarChartRendererDelegate?, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(delegate: delegate, animator: animator, viewPortHandler: viewPortHandler)
    }
    
    internal override func drawDataSet(context context: CGContext?, dataSet: BarChartDataSet, index: Int)
    {
        CGContextSaveGState(context)
        
        let barData = delegate!.barChartRendererData(self)
        
        let trans = delegate!.barChartRenderer(self, transformerForAxis: dataSet.axisDependency)
        
        let drawBarShadowEnabled: Bool = delegate!.barChartIsDrawBarShadowEnabled(self)
        let dataSetOffset = (barData.dataSetCount - 1)
        let groupSpace = barData.groupSpace
        let groupSpaceHalf = groupSpace / 2.0
        let barSpace = dataSet.barSpace
        let barSpaceHalf = barSpace / 2.0
        let containsStacks = dataSet.isStacked
        let isInverted = delegate!.barChartIsInverted(self, axis: dataSet.axisDependency)
        var entries = dataSet.yVals as! [BarChartDataEntry]
        let barWidth: CGFloat = 0.5
        let phaseY = _animator.phaseY
        var barRect = CGRect()
        var barShadow = CGRect()
        var y: Double
        
        // do the drawing
        for (var j = 0, count = Int(ceil(CGFloat(dataSet.entryCount) * _animator.phaseX)); j < count; j++)
        {
            let e = entries[j]
            
            // calculate the x-position, depending on datasetcount
            let x = CGFloat(e.xIndex + e.xIndex * dataSetOffset) + CGFloat(index)
                + groupSpace * CGFloat(e.xIndex) + groupSpaceHalf
            let values = e.values
            
            if (!containsStacks || values == nil)
            {
                y = e.value
                
                let bottom = x - barWidth + barSpaceHalf
                let top = x + barWidth - barSpaceHalf
                var right = isInverted ? (y <= 0.0 ? CGFloat(y) : 0) : (y >= 0.0 ? CGFloat(y) : 0)
                var left = isInverted ? (y >= 0.0 ? CGFloat(y) : 0) : (y <= 0.0 ? CGFloat(y) : 0)
                
                // multiply the height of the rect with the phase
                if (right > 0)
                {
                    right *= phaseY
                }
                else
                {
                    left *= phaseY
                }
                
                barRect.origin.x = left
                barRect.size.width = right - left
                barRect.origin.y = top
                barRect.size.height = bottom - top
                
                trans.rectValueToPixel(&barRect)
                
                if (!viewPortHandler.isInBoundsLeft(barRect.origin.x + barRect.size.width))
                {
                    continue
                }
                
                if (!viewPortHandler.isInBoundsRight(barRect.origin.x))
                {
                    break
                }
                
                // if drawing the bar shadow is enabled
                if (drawBarShadowEnabled)
                {
                    barShadow.origin.x = viewPortHandler.contentLeft
                    barShadow.origin.y = barRect.origin.y
                    barShadow.size.width = viewPortHandler.contentWidth
                    barShadow.size.height = barRect.size.height
                    
                    CGContextSetFillColorWithColor(context, dataSet.barShadowColor.CGColor)
                    CGContextFillRect(context, barShadow)
                }
                
                // Set the color for the currently drawn value. If the index is out of bounds, reuse colors.
                CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                CGContextFillRect(context, barRect)
            }
            else
            {
                let vals = values!
                var posY = 0.0
                var negY = -e.negativeSum
                var yStart = 0.0
                
                // if drawing the bar shadow is enabled
                if (drawBarShadowEnabled)
                {
                    y = e.value
                    
                    let bottom = x - barWidth + barSpaceHalf
                    let top = x + barWidth - barSpaceHalf
                    var right = isInverted ? (y <= 0.0 ? CGFloat(y) : 0) : (y >= 0.0 ? CGFloat(y) : 0)
                    var left = isInverted ? (y >= 0.0 ? CGFloat(y) : 0) : (y <= 0.0 ? CGFloat(y) : 0)
                    
                    // multiply the height of the rect with the phase
                    if (right > 0)
                    {
                        right *= phaseY
                    }
                    else
                    {
                        left *= phaseY
                    }
                    
                    barRect.origin.x = left
                    barRect.size.width = right - left
                    barRect.origin.y = top
                    barRect.size.height = bottom - top
                    
                    trans.rectValueToPixel(&barRect)
                    
                    barShadow.origin.x = viewPortHandler.contentLeft
                    barShadow.origin.y = barRect.origin.y
                    barShadow.size.width = viewPortHandler.contentWidth
                    barShadow.size.height = barRect.size.height
                    
                    CGContextSetFillColorWithColor(context, dataSet.barShadowColor.CGColor)
                    CGContextFillRect(context, barShadow)
                }
                
                // fill the stack
                for (var k = 0; k < vals.count; k++)
                {
                    let value = vals[k]
                    
                    if value >= 0.0
                    {
                        y = posY
                        yStart = posY + value
                        posY = yStart
                    }
                    else
                    {
                        y = negY
                        yStart = negY + abs(value)
                        negY += abs(value)
                    }
                    
                    let bottom = x - barWidth + barSpaceHalf
                    let top = x + barWidth - barSpaceHalf
                    var right: CGFloat, left: CGFloat
                    if isInverted
                    {
                        left = y >= yStart ? CGFloat(y) : CGFloat(yStart)
                        right = y <= yStart ? CGFloat(y) : CGFloat(yStart)
                    }
                    else
                    {
                        right = y >= yStart ? CGFloat(y) : CGFloat(yStart)
                        left = y <= yStart ? CGFloat(y) : CGFloat(yStart)
                    }
                    
                    // multiply the height of the rect with the phase
                    right *= phaseY
                    left *= phaseY
                    
                    barRect.origin.x = left
                    barRect.size.width = right - left
                    barRect.origin.y = top
                    barRect.size.height = bottom - top
                    
                    trans.rectValueToPixel(&barRect)
                    
                    if (k == 0 && !viewPortHandler.isInBoundsTop(barRect.origin.y + barRect.size.height))
                    {
                        // Skip to next bar
                        break
                    }
                    
                    // avoid drawing outofbounds values
                    if (!viewPortHandler.isInBoundsBottom(barRect.origin.y))
                    {
                        break
                    }
                    
                    // Set the color for the currently drawn value. If the index is out of bounds, reuse colors.
                    CGContextSetFillColorWithColor(context, dataSet.colorAt(k).CGColor)
                    CGContextFillRect(context, barRect)
                }
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    internal override func prepareBarHighlight(x x: CGFloat, y1: Double, y2: Double, barspacehalf: CGFloat, trans: ChartTransformer, inout rect: CGRect)
    {
        let barWidth: CGFloat = 0.5
        
        let top = x - barWidth + barspacehalf
        let bottom = x + barWidth - barspacehalf
        let left = CGFloat(y1)
        let right = CGFloat(y2)
        
        rect.origin.x = left
        rect.origin.y = top
        rect.size.width = right - left
        rect.size.height = bottom - top
        
        trans.rectValueToPixelHorizontal(&rect, phaseY: _animator.phaseY)
    }
    
    public override func getTransformedValues(trans trans: ChartTransformer, entries: [BarChartDataEntry], dataSetIndex: Int) -> [CGPoint]
    {
        return trans.generateTransformedValuesHorizontalBarChart(entries, dataSet: dataSetIndex, barData: delegate!.barChartRendererData(self)!, phaseY: _animator.phaseY)
    }
    
    public override func drawValues(context context: CGContext?)
    {
        // if values are drawn
        if (passesCheck())
        {
            let barData = delegate!.barChartRendererData(self)
            
            let defaultValueFormatter = delegate!.barChartDefaultRendererValueFormatter(self)
            
            var dataSets = barData.dataSets
            
            let drawValueAboveBar = delegate!.barChartIsDrawValueAboveBarEnabled(self)
            
            let textAlign = drawValueAboveBar ? NSTextAlignment.Left : NSTextAlignment.Right
            
            let valueOffsetPlus: CGFloat = 5.0
            var posOffset: CGFloat
            var negOffset: CGFloat
            
            for (var i = 0, count = barData.dataSetCount; i < count; i++)
            {
                let dataSet = dataSets[i] as! BarChartDataSet
                
                if !dataSet.isDrawValuesEnabled || dataSet.entryCount == 0
                {
                    continue
                }
                
                let isInverted = delegate!.barChartIsInverted(self, axis: dataSet.axisDependency)
                
                let valueFont = dataSet.valueFont
                let valueTextColor = dataSet.valueTextColor
                let yOffset = -valueFont.lineHeight / 2.0
                
                var formatter = dataSet.valueFormatter
                if (formatter === nil)
                {
                    formatter = defaultValueFormatter
                }
                
                let trans = delegate!.barChartRenderer(self, transformerForAxis: dataSet.axisDependency)
                
                var entries = dataSet.yVals as! [BarChartDataEntry]
                
                var valuePoints = getTransformedValues(trans: trans, entries: entries, dataSetIndex: i)
                
                // if only single values are drawn (sum)
                if (!dataSet.isStacked)
                {
                    for (var j = 0, count = Int(ceil(CGFloat(valuePoints.count) * _animator.phaseX)); j < count; j++)
                    {
                        if (!viewPortHandler.isInBoundsTop(valuePoints[j].y))
                        {
                            break
                        }
                        
                        if (!viewPortHandler.isInBoundsX(valuePoints[j].x))
                        {
                            continue
                        }
                        
                        if (!viewPortHandler.isInBoundsBottom(valuePoints[j].y))
                        {
                            continue
                        }
                        
                        let val = entries[j].value
                        let valueText = formatter!.stringFromNumber(val)!
                        
                        // calculate the correct offset depending on the draw position of the value
                        let valueTextWidth = valueText.sizeWithAttributes([NSFontAttributeName: valueFont]).width
                        posOffset = (drawValueAboveBar ? valueOffsetPlus : -(valueTextWidth + valueOffsetPlus))
                        negOffset = (drawValueAboveBar ? -(valueTextWidth + valueOffsetPlus) : valueOffsetPlus)
                        
                        if (isInverted)
                        {
                            posOffset = -posOffset - valueTextWidth
                            negOffset = -negOffset - valueTextWidth
                        }
                        
                        drawValue(
                            context: context,
                            value: valueText,
                            xPos: valuePoints[j].x + (val >= 0.0 ? posOffset : negOffset),
                            yPos: valuePoints[j].y + yOffset,
                            font: valueFont,
                            align: textAlign,
                            color: valueTextColor)
                    }
                }
                else
                {
                    // if each value of a potential stack should be drawn
                    
                    for (var j = 0, count = Int(ceil(CGFloat(valuePoints.count) * _animator.phaseX)); j < count; j++)
                    {
                        let e = entries[j]
                        
                        let values = e.values
                        
                        // we still draw stacked bars, but there is one non-stacked in between
                        if (values == nil)
                        {
                            if (!viewPortHandler.isInBoundsTop(valuePoints[j].y))
                            {
                                break
                            }
                            
                            if (!viewPortHandler.isInBoundsX(valuePoints[j].x))
                            {
                                continue
                            }
                            
                            if (!viewPortHandler.isInBoundsBottom(valuePoints[j].y))
                            {
                                continue
                            }
                            
                            let val = e.value
                            let valueText = formatter!.stringFromNumber(val)!
                            
                            // calculate the correct offset depending on the draw position of the value
                            let valueTextWidth = valueText.sizeWithAttributes([NSFontAttributeName: valueFont]).width
                            posOffset = (drawValueAboveBar ? valueOffsetPlus : -(valueTextWidth + valueOffsetPlus))
                            negOffset = (drawValueAboveBar ? -(valueTextWidth + valueOffsetPlus) : valueOffsetPlus)
                            
                            if (isInverted)
                            {
                                posOffset = -posOffset - valueTextWidth
                                negOffset = -negOffset - valueTextWidth
                            }
                            
                            drawValue(
                                context: context,
                                value: valueText,
                                xPos: valuePoints[j].x + (val >= 0.0 ? posOffset : negOffset),
                                yPos: valuePoints[j].y + yOffset,
                                font: valueFont,
                                align: textAlign,
                                color: valueTextColor)
                        }
                        else
                        {
                            let vals = values!
                            var transformed = [CGPoint]()
                            
                            var posY = 0.0
                            var negY = -e.negativeSum
                            
                            for (var k = 0; k < vals.count; k++)
                            {
                                let value = vals[k]
                                var y: Double
                                
                                if value >= 0.0
                                {
                                    posY += value
                                    y = posY
                                }
                                else
                                {
                                    y = negY
                                    negY -= value
                                }
                                
                                transformed.append(CGPoint(x: CGFloat(y) * _animator.phaseY, y: 0.0))
                            }
                            
                            trans.pointValuesToPixel(&transformed)
                            
                            for (var k = 0; k < transformed.count; k++)
                            {
                                let val = vals[k]
                                let valueText = formatter!.stringFromNumber(val)!
                                
                                // calculate the correct offset depending on the draw position of the value
                                let valueTextWidth = valueText.sizeWithAttributes([NSFontAttributeName: valueFont]).width
                                posOffset = (drawValueAboveBar ? valueOffsetPlus : -(valueTextWidth + valueOffsetPlus))
                                negOffset = (drawValueAboveBar ? -(valueTextWidth + valueOffsetPlus) : valueOffsetPlus)
                                
                                if (isInverted)
                                {
                                    posOffset = -posOffset - valueTextWidth
                                    negOffset = -negOffset - valueTextWidth
                                }
                                
                                let x = transformed[k].x + (val >= 0 ? posOffset : negOffset)
                                let y = valuePoints[j].y
                                
                                if (!viewPortHandler.isInBoundsTop(y))
                                {
                                    break
                                }
                                
                                if (!viewPortHandler.isInBoundsX(x))
                                {
                                    continue
                                }
                                
                                if (!viewPortHandler.isInBoundsBottom(y))
                                {
                                    continue
                                }
                                
                                drawValue(context: context,
                                    value: valueText,
                                    xPos: x,
                                    yPos: y + yOffset,
                                    font: valueFont,
                                    align: textAlign,
                                    color: valueTextColor)
                            }
                        }
                    }
                }
            }
        }
    }
    
    internal override func passesCheck() -> Bool
    {
        let barData = delegate!.barChartRendererData(self)
        
        if (barData === nil)
        {
            return false
        }
        
        return CGFloat(barData.yValCount) < CGFloat(delegate!.barChartRendererMaxVisibleValueCount(self)) * viewPortHandler.scaleY
    }
}