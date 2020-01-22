//
//  BubbleChartRenderer.swift
//  Charts
//
//  Bubble chart implementation:
//    Copyright 2015 Pierre-Marc Airoldi
//    Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

open class BubbleChartRenderer: BarLineScatterCandleBubbleRenderer
{
    /// A nested array of elements ordered logically (i.e not in visual/drawing order) for use with VoiceOver.
    private lazy var accessibilityOrderedElements: [[NSUIAccessibilityElement]] = accessibilityCreateEmptyOrderedElements()

    @objc open weak var dataProvider: BubbleChartDataProvider?
    
    @objc public init(dataProvider: BubbleChartDataProvider, animator: Animator, viewPortHandler: ViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.dataProvider = dataProvider
    }
    
    open override func drawData(context: CGContext)
    {
        guard
            let dataProvider = dataProvider,
            let bubbleData = dataProvider.bubbleData
            else { return }
        
        // If we redraw the data, remove and repopulate accessible elements to update label values and frames
        accessibleChartElements.removeAll()
        accessibilityOrderedElements = accessibilityCreateEmptyOrderedElements()

        // Make the chart header the first element in the accessible elements array
        if let chart = dataProvider as? BubbleChartView {
            let element = createAccessibleHeader(usingChart: chart,
                                                 andData: bubbleData,
                                                 withDefaultDescription: "Bubble Chart")
            accessibleChartElements.append(element)
        }

        for (i, set) in (bubbleData.dataSets as! [IBubbleChartDataSet]).enumerated() where set.isVisible
        {
            drawDataSet(context: context, dataSet: set, dataSetIndex: i)
        }

        // Merge nested ordered arrays into the single accessibleChartElements.
        accessibleChartElements.append(contentsOf: accessibilityOrderedElements.flatMap { $0 } )
        accessibilityPostLayoutChangedNotification()
    }
    
    private func getShapeSize(
        entrySize: CGFloat,
        maxSize: CGFloat,
        reference: CGFloat,
        normalizeSize: Bool) -> CGFloat
    {
        let factor: CGFloat = normalizeSize
            ? ((maxSize == 0.0) ? 1.0 : sqrt(entrySize / maxSize))
            : entrySize
        let shapeSize: CGFloat = reference * factor
        return shapeSize
    }
    
    private var _pointBuffer = CGPoint()
    private var _sizeBuffer = [CGPoint](repeating: CGPoint(), count: 2)
    
    @objc open func drawDataSet(context: CGContext, dataSet: IBubbleChartDataSet, dataSetIndex: Int)
    {
        guard let dataProvider = dataProvider else { return }
        
        let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
        
        let phaseY = animator.phaseY
        
        _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)
        
        let valueToPixelMatrix = trans.valueToPixelMatrix
    
        _sizeBuffer[0].x = 0.0
        _sizeBuffer[0].y = 0.0
        _sizeBuffer[1].x = 1.0
        _sizeBuffer[1].y = 0.0
        
        trans.pointValuesToPixel(&_sizeBuffer)
        
        context.saveGState()
        defer { context.restoreGState() }
        
        let normalizeSize = dataSet.isNormalizeSizeEnabled
        
        // calcualte the full width of 1 step on the x-axis
        let maxBubbleWidth: CGFloat = abs(_sizeBuffer[1].x - _sizeBuffer[0].x)
        let maxBubbleHeight: CGFloat = abs(viewPortHandler.contentBottom - viewPortHandler.contentTop)
        let referenceSize: CGFloat = min(maxBubbleHeight, maxBubbleWidth)
        
        for j in _xBounds
        {
            guard let entry = dataSet.entryForIndex(j) as? BubbleChartDataEntry else { continue }
            
            _pointBuffer.x = CGFloat(entry.x)
            _pointBuffer.y = CGFloat(entry.y * phaseY)
            _pointBuffer = _pointBuffer.applying(valueToPixelMatrix)
            
            let shapeSize = getShapeSize(entrySize: entry.size, maxSize: dataSet.maxSize, reference: referenceSize, normalizeSize: normalizeSize)
            let shapeHalf = shapeSize / 2.0
            
            guard
                viewPortHandler.isInBoundsTop(_pointBuffer.y + shapeHalf),
                viewPortHandler.isInBoundsBottom(_pointBuffer.y - shapeHalf),
                viewPortHandler.isInBoundsLeft(_pointBuffer.x + shapeHalf)
                else { continue }

            guard viewPortHandler.isInBoundsRight(_pointBuffer.x - shapeHalf) else { break }
            
            let color = dataSet.color(atIndex: j)
            
            let rect = CGRect(
                x: _pointBuffer.x - shapeHalf,
                y: _pointBuffer.y - shapeHalf,
                width: shapeSize,
                height: shapeSize
            )

            context.setFillColor(color.cgColor)
            context.fillEllipse(in: rect)

            // Create and append the corresponding accessibility element to accessibilityOrderedElements
            if let chart = dataProvider as? BubbleChartView
            {
                let element = createAccessibleElement(withIndex: j,
                                                      container: chart,
                                                      dataSet: dataSet,
                                                      dataSetIndex: dataSetIndex,
                                                      shapeSize: shapeSize)
                { (element) in
                    element.accessibilityFrame = rect
                }

                accessibilityOrderedElements[dataSetIndex].append(element)
            }
        }
    }
    
    open override func drawValues(context: CGContext)
    {
        guard let
            dataProvider = dataProvider,
            let bubbleData = dataProvider.bubbleData,
            isDrawingValuesAllowed(dataProvider: dataProvider),
            let dataSets = bubbleData.dataSets as? [IBubbleChartDataSet]
            else { return }

        let phaseX = max(0.0, min(1.0, animator.phaseX))
        let phaseY = animator.phaseY

        var pt = CGPoint()

        for i in 0..<dataSets.count
        {
            let dataSet = dataSets[i]

            guard
                shouldDrawValues(forDataSet: dataSet),
                let formatter = dataSet.valueFormatter
                else { continue }

            let alpha = phaseX == 1 ? phaseY : phaseX

            _xBounds.set(chart: dataProvider, dataSet: dataSet, animator: animator)

            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            let valueToPixelMatrix = trans.valueToPixelMatrix

            let iconsOffset = dataSet.iconsOffset

            for j in _xBounds
            {
                guard let e = dataSet.entryForIndex(j) as? BubbleChartDataEntry else { break }

                let valueTextColor = dataSet.valueTextColorAt(j).withAlphaComponent(CGFloat(alpha))

                pt.x = CGFloat(e.x)
                pt.y = CGFloat(e.y * phaseY)
                pt = pt.applying(valueToPixelMatrix)

                guard viewPortHandler.isInBoundsRight(pt.x) else { break }

                guard
                    viewPortHandler.isInBoundsLeft(pt.x),
                    viewPortHandler.isInBoundsY(pt.y)
                    else { continue }

                let text = formatter.stringForValue(
                    Double(e.size),
                    entry: e,
                    dataSetIndex: i,
                    viewPortHandler: viewPortHandler)

                // Larger font for larger bubbles?
                let valueFont = dataSet.valueFont
                let lineHeight = valueFont.lineHeight

                if dataSet.isDrawValuesEnabled
                {
                    ChartUtils.drawText(
                        context: context,
                        text: text,
                        point: CGPoint(
                            x: pt.x,
                            y: pt.y - (0.5 * lineHeight)),
                        align: .center,
                        attributes: [NSAttributedString.Key.font: valueFont, NSAttributedString.Key.foregroundColor: valueTextColor])
                }

                if let icon = e.icon, dataSet.isDrawIconsEnabled
                {
                    ChartUtils.drawImage(context: context,
                                         image: icon,
                                         x: pt.x + iconsOffset.x,
                                         y: pt.y + iconsOffset.y,
                                         size: icon.size)
                }
            }
        }
    }
    
    open override func drawExtras(context: CGContext)
    {
        
    }
    
    open override func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        guard
            let dataProvider = dataProvider,
            let bubbleData = dataProvider.bubbleData
            else { return }

        context.saveGState()
        defer { context.restoreGState() }

        let phaseY = animator.phaseY
        
        for high in indices
        {
            guard
                let dataSet = bubbleData.getDataSetByIndex(high.dataSetIndex) as? IBubbleChartDataSet,
                dataSet.isHighlightEnabled,
                let entry = dataSet.entryForXValue(high.x, closestToY: high.y) as? BubbleChartDataEntry,
                isInBoundsX(entry: entry, dataSet: dataSet)
                else { continue }

            let trans = dataProvider.getTransformer(forAxis: dataSet.axisDependency)
            
            _sizeBuffer[0].x = 0.0
            _sizeBuffer[0].y = 0.0
            _sizeBuffer[1].x = 1.0
            _sizeBuffer[1].y = 0.0
            
            trans.pointValuesToPixel(&_sizeBuffer)
            
            let normalizeSize = dataSet.isNormalizeSizeEnabled
            
            // calcualte the full width of 1 step on the x-axis
            let maxBubbleWidth: CGFloat = abs(_sizeBuffer[1].x - _sizeBuffer[0].x)
            let maxBubbleHeight: CGFloat = abs(viewPortHandler.contentBottom - viewPortHandler.contentTop)
            let referenceSize: CGFloat = min(maxBubbleHeight, maxBubbleWidth)
            
            _pointBuffer.x = CGFloat(entry.x)
            _pointBuffer.y = CGFloat(entry.y * phaseY)
            trans.pointValueToPixel(&_pointBuffer)
            
            let shapeSize = getShapeSize(entrySize: entry.size, maxSize: dataSet.maxSize, reference: referenceSize, normalizeSize: normalizeSize)
            let shapeHalf = shapeSize / 2.0
            
            guard
                viewPortHandler.isInBoundsTop(_pointBuffer.y + shapeHalf),
                viewPortHandler.isInBoundsBottom(_pointBuffer.y - shapeHalf),
                viewPortHandler.isInBoundsLeft(_pointBuffer.x + shapeHalf)
            else { continue }

            guard viewPortHandler.isInBoundsRight(_pointBuffer.x - shapeHalf) else { break }

            let originalColor = dataSet.color(atIndex: Int(entry.x))
            
            var h: CGFloat = 0.0
            var s: CGFloat = 0.0
            var b: CGFloat = 0.0
            var a: CGFloat = 0.0
            
            originalColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
            
            let color = NSUIColor(hue: h, saturation: s, brightness: b * 0.5, alpha: a)
            let rect = CGRect(
                x: _pointBuffer.x - shapeHalf,
                y: _pointBuffer.y - shapeHalf,
                width: shapeSize,
                height: shapeSize)
            
            context.setLineWidth(dataSet.highlightCircleWidth)
            context.setStrokeColor(color.cgColor)
            context.strokeEllipse(in: rect)
            
            high.setDraw(x: _pointBuffer.x, y: _pointBuffer.y)
        }
    }

    /// Creates a nested array of empty subarrays each of which will be populated with NSUIAccessibilityElements.
    private func accessibilityCreateEmptyOrderedElements() -> [[NSUIAccessibilityElement]]
    {
        guard let chart = dataProvider as? BubbleChartView else { return [] }

        let dataSetCount = chart.bubbleData?.dataSetCount ?? 0

        return Array(repeating: [NSUIAccessibilityElement](),
                     count: dataSetCount)
    }

    /// Creates an NSUIAccessibleElement representing individual bubbles location and relative size.
    private func createAccessibleElement(withIndex idx: Int,
                                         container: BubbleChartView,
                                         dataSet: IBubbleChartDataSet,
                                         dataSetIndex: Int,
                                         shapeSize: CGFloat,
                                         modifier: (NSUIAccessibilityElement) -> ()) -> NSUIAccessibilityElement
    {
        let element = NSUIAccessibilityElement(accessibilityContainer: container)
        let xAxis = container.xAxis

        guard let e = dataSet.entryForIndex(idx) else { return element }
        guard let dataProvider = dataProvider else { return element }

        // NOTE: The formatter can cause issues when the x-axis labels are consecutive ints.
        // i.e. due to the Double conversion, if there are more than one data set that are grouped,
        // there is the possibility of some labels being rounded up. A floor() might fix this, but seems to be a brute force solution.
        let label = xAxis.valueFormatter?.stringForValue(e.x, axis: xAxis) ?? "\(e.x)"

        let elementValueText = dataSet.valueFormatter?.stringForValue(e.y,
                                                                      entry: e,
                                                                      dataSetIndex: dataSetIndex,
                                                                      viewPortHandler: viewPortHandler) ?? "\(e.y)"

        let dataSetCount = dataProvider.bubbleData?.dataSetCount ?? -1
        let doesContainMultipleDataSets = dataSetCount > 1

        element.accessibilityLabel = "\(doesContainMultipleDataSets ? (dataSet.label ?? "")  + ", " : "") \(label): \(elementValueText), bubble size: \(String(format: "%.2f", (shapeSize/dataSet.maxSize) * 100)) %"

        modifier(element)

        return element
    }
}
