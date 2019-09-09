//
//  LegendRenderer.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

@objc(ChartLegendRenderer)
open class LegendRenderer: Renderer
{
    /// the legend object this renderer renders
    @objc open var legend: Legend?

    @objc public init(viewPortHandler: ViewPortHandler, legend: Legend?)
    {
        super.init(viewPortHandler: viewPortHandler)
        
        self.legend = legend
    }

    /// Prepares the legend and calculates all needed forms, labels and colors.
    @objc open func computeLegend(data: ChartData)
    {
        guard let legend = legend else { return }
        
        if !legend.isLegendCustom
        {
            var entries: [LegendEntry] = []
            
            // loop for building up the colors and labels used in the legend
            for i in 0..<data.dataSetCount
            {
                guard let dataSet = data.getDataSetByIndex(i) else { continue }
                
                var clrs: [NSUIColor] = dataSet.colors
                let entryCount = dataSet.entryCount
                
                // if we have a barchart with stacked bars
                if dataSet is IBarChartDataSet &&
                    (dataSet as! IBarChartDataSet).isStacked
                {
                    let bds = dataSet as! IBarChartDataSet
                    var sLabels = bds.stackLabels
                    let minEntries = min(clrs.count, bds.stackSize)

                    for j in 0..<minEntries
                    {
                        let label: String?
                        if (sLabels.count > 0 && minEntries > 0) {
                            let labelIndex = j % minEntries
                            label = sLabels.indices.contains(labelIndex) ? sLabels[labelIndex] : nil
                        } else {
                            label = nil
                        }

                        entries.append(
                            LegendEntry(
                                label: label,
                                form: dataSet.form,
                                formSize: dataSet.formSize,
                                formLineWidth: dataSet.formLineWidth,
                                formLineDashPhase: dataSet.formLineDashPhase,
                                formLineDashLengths: dataSet.formLineDashLengths,
                                formColor: clrs[j]
                            )
                        )
                    }
                    
                    if dataSet.label != nil
                    {
                        // add the legend description label
                        
                        entries.append(
                            LegendEntry(
                                label: dataSet.label,
                                form: .none,
                                formSize: CGFloat.nan,
                                formLineWidth: CGFloat.nan,
                                formLineDashPhase: 0.0,
                                formLineDashLengths: nil,
                                formColor: nil
                            )
                        )
                    }
                }
                else if dataSet is IPieChartDataSet
                {
                    let pds = dataSet as! IPieChartDataSet
                    
                    for j in 0..<min(clrs.count, entryCount)
                    {
                        entries.append(
                            LegendEntry(
                                label: (pds.entryForIndex(j) as? PieChartDataEntry)?.label,
                                form: dataSet.form,
                                formSize: dataSet.formSize,
                                formLineWidth: dataSet.formLineWidth,
                                formLineDashPhase: dataSet.formLineDashPhase,
                                formLineDashLengths: dataSet.formLineDashLengths,
                                formColor: clrs[j]
                            )
                        )
                    }
                    
                    if dataSet.label != nil
                    {
                        // add the legend description label
                        
                        entries.append(
                            LegendEntry(
                                label: dataSet.label,
                                form: .none,
                                formSize: CGFloat.nan,
                                formLineWidth: CGFloat.nan,
                                formLineDashPhase: 0.0,
                                formLineDashLengths: nil,
                                formColor: nil
                            )
                        )
                    }
                }
                else if dataSet is ICandleChartDataSet &&
                    (dataSet as! ICandleChartDataSet).decreasingColor != nil
                {
                    let candleDataSet = dataSet as! ICandleChartDataSet
                    
                    entries.append(
                        LegendEntry(
                            label: nil,
                            form: dataSet.form,
                            formSize: dataSet.formSize,
                            formLineWidth: dataSet.formLineWidth,
                            formLineDashPhase: dataSet.formLineDashPhase,
                            formLineDashLengths: dataSet.formLineDashLengths,
                            formColor: candleDataSet.decreasingColor
                        )
                    )
                    
                    entries.append(
                        LegendEntry(
                            label: dataSet.label,
                            form: dataSet.form,
                            formSize: dataSet.formSize,
                            formLineWidth: dataSet.formLineWidth,
                            formLineDashPhase: dataSet.formLineDashPhase,
                            formLineDashLengths: dataSet.formLineDashLengths,
                            formColor: candleDataSet.increasingColor
                        )
                    )
                }
                else
                { // all others
                    
                    for j in 0..<min(clrs.count, entryCount)
                    {
                        let label: String?
                        
                        // if multiple colors are set for a DataSet, group them
                        if j < clrs.count - 1 && j < entryCount - 1
                        {
                            label = nil
                        }
                        else
                        { // add label to the last entry
                            label = dataSet.label
                        }
                        
                        entries.append(
                            LegendEntry(
                                label: label,
                                form: dataSet.form,
                                formSize: dataSet.formSize,
                                formLineWidth: dataSet.formLineWidth,
                                formLineDashPhase: dataSet.formLineDashPhase,
                                formLineDashLengths: dataSet.formLineDashLengths,
                                formColor: clrs[j]
                            )
                        )
                    }
                }
            }
            
            legend.entries = entries + legend.extraEntries
        }
        
        // calculate all dimensions of the legend
        legend.calculateDimensions(labelFont: legend.font, viewPortHandler: viewPortHandler)
    }
    
    @objc open func renderLegend(context: CGContext)
    {
        guard let legend = legend else { return }
        
        if !legend.enabled
        {
            return
        }
        
        let labelFont = legend.font
        let labelTextColor = legend.textColor
        let labelLineHeight = labelFont.lineHeight
        let formYOffset = labelLineHeight / 2.0

        var entries = legend.entries
        
        let defaultFormSize = legend.formSize
        let formToTextSpace = legend.formToTextSpace
        let xEntrySpace = legend.xEntrySpace
        let yEntrySpace = legend.yEntrySpace
        
        let orientation = legend.orientation
        let horizontalAlignment = legend.horizontalAlignment
        let verticalAlignment = legend.verticalAlignment
        let direction = legend.direction

        // space between the entries
        let stackSpace = legend.stackSpace

        let yoffset = legend.yOffset
        let xoffset = legend.xOffset
        var originPosX: CGFloat = 0.0
        
        switch horizontalAlignment
        {
        case .left:
            
            if orientation == .vertical
            {
                originPosX = xoffset
            }
            else
            {
                originPosX = viewPortHandler.contentLeft + xoffset
            }
            
            if direction == .rightToLeft
            {
                originPosX += legend.neededWidth
            }
            
        case .right:
            
            if orientation == .vertical
            {
                originPosX = viewPortHandler.chartWidth - xoffset
            }
            else
            {
                originPosX = viewPortHandler.contentRight - xoffset
            }
            
            if direction == .leftToRight
            {
                originPosX -= legend.neededWidth
            }
            
        case .center:
            
            if orientation == .vertical
            {
                originPosX = viewPortHandler.chartWidth / 2.0
            }
            else
            {
                originPosX = viewPortHandler.contentLeft
                    + viewPortHandler.contentWidth / 2.0
            }
            
            originPosX += (direction == .leftToRight
                    ? +xoffset
                    : -xoffset)
            
            // Horizontally layed out legends do the center offset on a line basis,
            // So here we offset the vertical ones only.
            if orientation == .vertical
            {
                if direction == .leftToRight
                {
                    originPosX -= legend.neededWidth / 2.0 - xoffset
                }
                else
                {
                    originPosX += legend.neededWidth / 2.0 - xoffset
                }
            }
        }
        
        switch orientation
        {
        case .horizontal:
            
            var calculatedLineSizes = legend.calculatedLineSizes
            var calculatedLabelSizes = legend.calculatedLabelSizes
            var calculatedLabelBreakPoints = legend.calculatedLabelBreakPoints
            
            var posX: CGFloat = originPosX
            var posY: CGFloat
            
            switch verticalAlignment
            {
            case .top:
                posY = yoffset
                
            case .bottom:
                posY = viewPortHandler.chartHeight - yoffset - legend.neededHeight
                
            case .center:
                posY = (viewPortHandler.chartHeight - legend.neededHeight) / 2.0 + yoffset
            }
            
            var lineIndex: Int = 0
            
            for i in 0 ..< entries.count
            {
                let e = entries[i]
                let drawingForm = e.form != .none
                let formSize = e.formSize.isNaN ? defaultFormSize : e.formSize
                
                if i < calculatedLabelBreakPoints.count &&
                    calculatedLabelBreakPoints[i]
                {
                    posX = originPosX
                    posY += labelLineHeight + yEntrySpace
                }
                
                if posX == originPosX &&
                    horizontalAlignment == .center &&
                    lineIndex < calculatedLineSizes.count
                {
                    posX += (direction == .rightToLeft
                        ? calculatedLineSizes[lineIndex].width
                        : -calculatedLineSizes[lineIndex].width) / 2.0
                    lineIndex += 1
                }
                
                let isStacked = e.label == nil // grouped forms have null labels
                
                if drawingForm
                {
                    if direction == .rightToLeft
                    {
                        posX -= formSize
                    }
                    
                    drawForm(
                        context: context,
                        x: posX,
                        y: posY + formYOffset,
                        entry: e,
                        legend: legend)
                    
                    if direction == .leftToRight
                    {
                        posX += formSize
                    }
                }
                
                if !isStacked
                {
                    if drawingForm
                    {
                        posX += direction == .rightToLeft ? -formToTextSpace : formToTextSpace
                    }
                    
                    if direction == .rightToLeft
                    {
                        posX -= calculatedLabelSizes[i].width
                    }
                    
                    drawLabel(
                        context: context,
                        x: posX,
                        y: posY,
                        label: e.label!,
                        font: labelFont,
                        textColor: labelTextColor)
                    
                    if direction == .leftToRight
                    {
                        posX += calculatedLabelSizes[i].width
                    }
                    
                    posX += direction == .rightToLeft ? -xEntrySpace : xEntrySpace
                }
                else
                {
                    posX += direction == .rightToLeft ? -stackSpace : stackSpace
                }
            }
            
        case .vertical:
            
            // contains the stacked legend size in pixels
            var stack = CGFloat(0.0)
            var wasStacked = false
            
            var posY: CGFloat = 0.0
            
            switch verticalAlignment
            {
            case .top:
                posY = (horizontalAlignment == .center
                    ? 0.0
                    : viewPortHandler.contentTop)
                posY += yoffset
                
            case .bottom:
                posY = (horizontalAlignment == .center
                    ? viewPortHandler.chartHeight
                    : viewPortHandler.contentBottom)
                posY -= legend.neededHeight + yoffset
                
            case .center:
                
                posY = viewPortHandler.chartHeight / 2.0 - legend.neededHeight / 2.0 + legend.yOffset
            }
            
            for i in 0 ..< entries.count
            {
                let e = entries[i]
                let drawingForm = e.form != .none
                let formSize = e.formSize.isNaN ? defaultFormSize : e.formSize
                
                var posX = originPosX
                
                if drawingForm
                {
                    if direction == .leftToRight
                    {
                        posX += stack
                    }
                    else
                    {
                        posX -= formSize - stack
                    }
                    
                    drawForm(
                        context: context,
                        x: posX,
                        y: posY + formYOffset,
                        entry: e,
                        legend: legend)
                    
                    if direction == .leftToRight
                    {
                        posX += formSize
                    }
                }
                
                if e.label != nil
                {
                    if drawingForm && !wasStacked
                    {
                        posX += direction == .leftToRight ? formToTextSpace : -formToTextSpace
                    }
                    else if wasStacked
                    {
                        posX = originPosX
                    }
                    
                    if direction == .rightToLeft
                    {
                        posX -= (e.label! as NSString).size(withAttributes: [.font: labelFont]).width
                    }
                    
                    if !wasStacked
                    {
                        drawLabel(context: context, x: posX, y: posY, label: e.label!, font: labelFont, textColor: labelTextColor)
                    }
                    else
                    {
                        posY += labelLineHeight + yEntrySpace
                        drawLabel(context: context, x: posX, y: posY, label: e.label!, font: labelFont, textColor: labelTextColor)
                    }
                    
                    // make a step down
                    posY += labelLineHeight + yEntrySpace
                    stack = 0.0
                }
                else
                {
                    stack += formSize + stackSpace
                    wasStacked = true
                }
            }
        }
    }

    private var _formLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    /// Draws the Legend-form at the given position with the color at the given index.
    @objc open func drawForm(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        entry: LegendEntry,
        legend: Legend)
    {
        guard
            let formColor = entry.formColor,
            formColor != NSUIColor.clear
            else { return }
        
        var form = entry.form
        if form == .default
        {
            form = legend.form
        }
        
        let formSize = entry.formSize.isNaN ? legend.formSize : entry.formSize
        
        context.saveGState()
        defer { context.restoreGState() }
        
        switch form
        {
        case .none:
            // Do nothing
            break
            
        case .empty:
            // Do not draw, but keep space for the form
            break
            
        case .default: fallthrough
        case .circle:
            
            context.setFillColor(formColor.cgColor)
            context.fillEllipse(in: CGRect(x: x, y: y - formSize / 2.0, width: formSize, height: formSize))
            
        case .square:
            
            context.setFillColor(formColor.cgColor)
            context.fill(CGRect(x: x, y: y - formSize / 2.0, width: formSize, height: formSize))
            
        case .line:
            
            let formLineWidth = entry.formLineWidth.isNaN ? legend.formLineWidth : entry.formLineWidth
            let formLineDashPhase = entry.formLineDashPhase.isNaN ? legend.formLineDashPhase : entry.formLineDashPhase
            let formLineDashLengths = entry.formLineDashLengths == nil ? legend.formLineDashLengths : entry.formLineDashLengths
            
            context.setLineWidth(formLineWidth)
            
            if formLineDashLengths != nil && formLineDashLengths!.count > 0
            {
                context.setLineDash(phase: formLineDashPhase, lengths: formLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            context.setStrokeColor(formColor.cgColor)
            
            _formLineSegmentsBuffer[0].x = x
            _formLineSegmentsBuffer[0].y = y
            _formLineSegmentsBuffer[1].x = x + formSize
            _formLineSegmentsBuffer[1].y = y
            context.strokeLineSegments(between: _formLineSegmentsBuffer)
        }
    }

    /// Draws the provided label at the given position.
    @objc open func drawLabel(context: CGContext, x: CGFloat, y: CGFloat, label: String, font: NSUIFont, textColor: NSUIColor)
    {
        ChartUtils.drawText(context: context, text: label, point: CGPoint(x: x, y: y), align: .left, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: textColor])
    }
}
