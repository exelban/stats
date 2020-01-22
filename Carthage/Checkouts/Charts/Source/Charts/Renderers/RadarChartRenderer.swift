//
//  RadarChartRenderer.swift
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

open class RadarChartRenderer: LineRadarRenderer
{
    private lazy var accessibilityXLabels: [String] = {
        guard let chart = chart else { return [] }
        guard let formatter = chart.xAxis.valueFormatter else { return [] }

        let maxEntryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0
        return stride(from: 0, to: maxEntryCount, by: 1).map {
            formatter.stringForValue(Double($0), axis: chart.xAxis)
        }
    }()

    @objc open weak var chart: RadarChartView?

    @objc public init(chart: RadarChartView, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.chart = chart
    }
    
    open override func drawData(context: CGContext)
    {
        guard let chart = chart else { return }
        
        let radarData = chart.data
        
        if radarData != nil
        {
            let mostEntries = radarData?.maxEntryCountSet?.entryCount ?? 0

            // If we redraw the data, remove and repopulate accessible elements to update label values and frames
            self.accessibleChartElements.removeAll()

            // Make the chart header the first element in the accessible elements array
            if let accessibilityHeaderData = radarData as? RadarChartData {
                let element = createAccessibleHeader(usingChart: chart,
                                                     andData: accessibilityHeaderData,
                                                     withDefaultDescription: "Radar Chart")
                self.accessibleChartElements.append(element)
            }

            for set in radarData!.dataSets as! [IRadarChartDataSet] where set.isVisible
            {
                drawDataSet(context: context, dataSet: set, mostEntries: mostEntries)
            }
        }
    }
    
    /// Draws the RadarDataSet
    ///
    /// - Parameters:
    ///   - context:
    ///   - dataSet:
    ///   - mostEntries: the entry count of the dataset with the most entries
    internal func drawDataSet(context: CGContext, dataSet: IRadarChartDataSet, mostEntries: Int)
    {
        guard let chart = chart else { return }
        
        context.saveGState()
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        let entryCount = dataSet.entryCount
        let path = CGMutablePath()
        var hasMovedToPoint = false

        let prefix: String = chart.data?.accessibilityEntryLabelPrefix ?? "Item"
        let description = dataSet.label ?? ""

        // Make a tuple of (xLabels, value, originalIndex) then sort it
        // This is done, so that the labels are narrated in decreasing order of their corresponding value
        // Otherwise, there is no non-visual logic to the data presented
        let accessibilityEntryValues =  Array(0 ..< entryCount).map { (dataSet.entryForIndex($0)?.y ?? 0, $0) }
        let accessibilityAxisLabelValueTuples = zip(accessibilityXLabels, accessibilityEntryValues).map { ($0, $1.0, $1.1) }.sorted { $0.1 > $1.1 }
        let accessibilityDataSetDescription: String = description + ". \(entryCount) \(prefix + (entryCount == 1 ? "" : "s")). "
        let accessibilityFrameWidth: CGFloat = 22.0 // To allow a tap target of 44x44

        var accessibilityEntryElements: [NSUIAccessibilityElement] = []

        for j in 0 ..< entryCount
        {
            guard let e = dataSet.entryForIndex(j) else { continue }
            
            let p = center.moving(distance: CGFloat((e.y - chart.chartYMin) * Double(factor) * phaseY),
                                  atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
            
            if p.x.isNaN
            {
                continue
            }
            
            if !hasMovedToPoint
            {
                path.move(to: p)
                hasMovedToPoint = true
            }
            else
            {
                path.addLine(to: p)
            }

            let accessibilityLabel = accessibilityAxisLabelValueTuples[j].0
            let accessibilityValue = accessibilityAxisLabelValueTuples[j].1
            let accessibilityValueIndex = accessibilityAxisLabelValueTuples[j].2

            let axp = center.moving(distance: CGFloat((accessibilityValue - chart.chartYMin) * Double(factor) * phaseY),
                                    atAngle: sliceangle * CGFloat(accessibilityValueIndex) * CGFloat(phaseX) + chart.rotationAngle)

            let axDescription = description + " - " + accessibilityLabel + ": \(accessibilityValue) \(chart.data?.accessibilityEntryLabelSuffix ?? "")"
            let axElement = createAccessibleElement(withDescription: axDescription,
                                                    container: chart,
                                                    dataSet: dataSet)
            { (element) in
                element.accessibilityFrame = CGRect(x: axp.x - accessibilityFrameWidth,
                                                    y: axp.y - accessibilityFrameWidth,
                                                    width: 2 * accessibilityFrameWidth,
                                                    height: 2 * accessibilityFrameWidth)
            }

            accessibilityEntryElements.append(axElement)
        }
        
        // if this is the largest set, close it
        if dataSet.entryCount < mostEntries
        {
            // if this is not the largest set, draw a line to the center before closing
            path.addLine(to: center)
        }
        
        path.closeSubpath()
        
        // draw filled
        if dataSet.isDrawFilledEnabled
        {
            if dataSet.fill != nil
            {
                drawFilledPath(context: context, path: path, fill: dataSet.fill!, fillAlpha: dataSet.fillAlpha)
            }
            else
            {
                drawFilledPath(context: context, path: path, fillColor: dataSet.fillColor, fillAlpha: dataSet.fillAlpha)
            }
        }
        
        // draw the line (only if filled is disabled or alpha is below 255)
        if !dataSet.isDrawFilledEnabled || dataSet.fillAlpha < 1.0
        {
            context.setStrokeColor(dataSet.color(atIndex: 0).cgColor)
            context.setLineWidth(dataSet.lineWidth)
            context.setAlpha(1.0)

            context.beginPath()
            context.addPath(path)
            context.strokePath()

            let axElement = createAccessibleElement(withDescription: accessibilityDataSetDescription,
                                                    container: chart,
                                                    dataSet: dataSet)
            { (element) in
                element.isHeader = true
                element.accessibilityFrame = path.boundingBoxOfPath
            }

            accessibleChartElements.append(axElement)
            accessibleChartElements.append(contentsOf: accessibilityEntryElements)
        }
        
        accessibilityPostLayoutChangedNotification()

        context.restoreGState()
    }
    
    open override func drawValues(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data
            else { return }
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value to pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        
        let yoffset = CGFloat(5.0)
        
        for i in 0 ..< data.dataSetCount
        {
            guard let
                dataSet = data.getDataSetByIndex(i) as? IRadarChartDataSet,
                shouldDrawValues(forDataSet: dataSet)
                else { continue }
            
            let entryCount = dataSet.entryCount
            
            let iconsOffset = dataSet.iconsOffset
            
            for j in 0 ..< entryCount
            {
                guard let e = dataSet.entryForIndex(j) else { continue }
                
                let p = center.moving(distance: CGFloat(e.y - chart.chartYMin) * factor * CGFloat(phaseY),
                                      atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
                
                let valueFont = dataSet.valueFont
                
                guard let formatter = dataSet.valueFormatter else { continue }
                
                if dataSet.isDrawValuesEnabled
                {
                    ChartUtils.drawText(
                        context: context,
                        text: formatter.stringForValue(
                            e.y,
                            entry: e,
                            dataSetIndex: i,
                            viewPortHandler: viewPortHandler),
                        point: CGPoint(x: p.x, y: p.y - yoffset - valueFont.lineHeight),
                        align: .center,
                        attributes: [NSAttributedString.Key.font: valueFont,
                            NSAttributedString.Key.foregroundColor: dataSet.valueTextColorAt(j)]
                    )
                }
                
                if let icon = e.icon, dataSet.isDrawIconsEnabled
                {
                    var pIcon = center.moving(distance: CGFloat(e.y) * factor * CGFloat(phaseY) + iconsOffset.y,
                                              atAngle: sliceangle * CGFloat(j) * CGFloat(phaseX) + chart.rotationAngle)
                    pIcon.y += iconsOffset.x
                    
                    ChartUtils.drawImage(context: context,
                                         image: icon,
                                         x: pIcon.x,
                                         y: pIcon.y,
                                         size: icon.size)
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        drawWeb(context: context)
    }
    
    private var _webLineSegmentsBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc open func drawWeb(context: CGContext)
    {
        guard
            let chart = chart,
            let data = chart.data
            else { return }
        
        let sliceangle = chart.sliceAngle
        
        context.saveGState()
        
        // calculate the factor that is needed for transforming the value to
        // pixels
        let factor = chart.factor
        let rotationangle = chart.rotationAngle
        
        let center = chart.centerOffsets
        
        // draw the web lines that come from the center
        context.setLineWidth(chart.webLineWidth)
        context.setStrokeColor(chart.webColor.cgColor)
        context.setAlpha(chart.webAlpha)
        
        let xIncrements = 1 + chart.skipWebLineCount
        let maxEntryCount = chart.data?.maxEntryCountSet?.entryCount ?? 0

        for i in stride(from: 0, to: maxEntryCount, by: xIncrements)
        {
            let p = center.moving(distance: CGFloat(chart.yRange) * factor,
                                  atAngle: sliceangle * CGFloat(i) + rotationangle)
            
            _webLineSegmentsBuffer[0].x = center.x
            _webLineSegmentsBuffer[0].y = center.y
            _webLineSegmentsBuffer[1].x = p.x
            _webLineSegmentsBuffer[1].y = p.y
            
            context.strokeLineSegments(between: _webLineSegmentsBuffer)
        }
        
        // draw the inner-web
        context.setLineWidth(chart.innerWebLineWidth)
        context.setStrokeColor(chart.innerWebColor.cgColor)
        context.setAlpha(chart.webAlpha)
        
        let labelCount = chart.yAxis.entryCount
        
        for j in 0 ..< labelCount
        {
            for i in 0 ..< data.entryCount
            {
                let r = CGFloat(chart.yAxis.entries[j] - chart.chartYMin) * factor

                let p1 = center.moving(distance: r, atAngle: sliceangle * CGFloat(i) + rotationangle)
                let p2 = center.moving(distance: r, atAngle: sliceangle * CGFloat(i + 1) + rotationangle)
                
                _webLineSegmentsBuffer[0].x = p1.x
                _webLineSegmentsBuffer[0].y = p1.y
                _webLineSegmentsBuffer[1].x = p2.x
                _webLineSegmentsBuffer[1].y = p2.y
                
                context.strokeLineSegments(between: _webLineSegmentsBuffer)
            }
        }
        
        context.restoreGState()
    }
    
    private var _highlightPointBuffer = CGPoint()

    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let chart = chart,
            let radarData = chart.data as? RadarChartData
            else { return }
        
        context.saveGState()
        
        let sliceangle = chart.sliceAngle
        
        // calculate the factor that is needed for transforming the value pixels
        let factor = chart.factor
        
        let center = chart.centerOffsets
        
        for high in indices
        {
            guard
                let set = chart.data?.getDataSetByIndex(high.dataSetIndex) as? IRadarChartDataSet,
                set.isHighlightEnabled
                else { continue }
            
            guard let e = set.entryForIndex(Int(high.x)) as? RadarChartDataEntry
                else { continue }
            
            if !isInBoundsX(entry: e, dataSet: set)
            {
                continue
            }
            
            context.setLineWidth(radarData.highlightLineWidth)
            if radarData.highlightLineDashLengths != nil
            {
                context.setLineDash(phase: radarData.highlightLineDashPhase, lengths: radarData.highlightLineDashLengths!)
            }
            else
            {
                context.setLineDash(phase: 0.0, lengths: [])
            }
            
            context.setStrokeColor(set.highlightColor.cgColor)
            
            let y = e.y - chart.chartYMin
            
            _highlightPointBuffer = center.moving(distance: CGFloat(y) * factor * CGFloat(animator.phaseY),
                                                  atAngle: sliceangle * CGFloat(high.x) * CGFloat(animator.phaseX) + chart.rotationAngle)
            
            high.setDraw(pt: _highlightPointBuffer)
            
            // draw the lines
            drawHighlightLines(context: context, point: _highlightPointBuffer, set: set)
            
            if set.isDrawHighlightCircleEnabled
            {
                if !_highlightPointBuffer.x.isNaN && !_highlightPointBuffer.y.isNaN
                {
                    var strokeColor = set.highlightCircleStrokeColor
                    if strokeColor == nil
                    {
                        strokeColor = set.color(atIndex: 0)
                    }
                    if set.highlightCircleStrokeAlpha < 1.0
                    {
                        strokeColor = strokeColor?.withAlphaComponent(set.highlightCircleStrokeAlpha)
                    }
                    
                    drawHighlightCircle(
                        context: context,
                        atPoint: _highlightPointBuffer,
                        innerRadius: set.highlightCircleInnerRadius,
                        outerRadius: set.highlightCircleOuterRadius,
                        fillColor: set.highlightCircleFillColor,
                        strokeColor: strokeColor,
                        strokeWidth: set.highlightCircleStrokeWidth)
                }
            }
        }
        
        context.restoreGState()
    }
    
    internal func drawHighlightCircle(
        context: CGContext,
        atPoint point: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        fillColor: NSUIColor?,
        strokeColor: NSUIColor?,
        strokeWidth: CGFloat)
    {
        context.saveGState()
        
        if let fillColor = fillColor
        {
            context.beginPath()
            context.addEllipse(in: CGRect(x: point.x - outerRadius, y: point.y - outerRadius, width: outerRadius * 2.0, height: outerRadius * 2.0))
            if innerRadius > 0.0
            {
                context.addEllipse(in: CGRect(x: point.x - innerRadius, y: point.y - innerRadius, width: innerRadius * 2.0, height: innerRadius * 2.0))
            }
            
            context.setFillColor(fillColor.cgColor)
            context.fillPath(using: .evenOdd)
        }
            
        if let strokeColor = strokeColor
        {
            context.beginPath()
            context.addEllipse(in: CGRect(x: point.x - outerRadius, y: point.y - outerRadius, width: outerRadius * 2.0, height: outerRadius * 2.0))
            context.setStrokeColor(strokeColor.cgColor)
            context.setLineWidth(strokeWidth)
            context.strokePath()
        }
        
        context.restoreGState()
    }

    private func createAccessibleElement(withDescription description: String,
                                         container: RadarChartView,
                                         dataSet: IRadarChartDataSet,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement {

        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        element.accessibilityLabel = description

        // The modifier allows changing of traits and frame depending on highlight, rotation, etc
        modifier(element)

        return element
    }
}
