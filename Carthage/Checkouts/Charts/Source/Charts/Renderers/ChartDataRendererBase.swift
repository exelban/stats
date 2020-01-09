//
//  DataRenderer.swift
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

#if canImport(UIKit)
    import UIKit
#endif

#if canImport(Cocoa)
import Cocoa
#endif

@objc(ChartDataRendererBase)
open class DataRenderer: Renderer
{
    /// An array of accessibility elements that are presented to the ChartViewBase accessibility methods.
    ///
    /// Note that the order of elements in this array determines the order in which they are presented and navigated by
    /// Accessibility clients such as VoiceOver.
    ///
    /// Renderers should ensure that the order of elements makes sense to a client presenting an audio-only interface to a user.
    /// Subclasses should populate this array in drawData() or drawDataSet() to make the chart accessible.
    @objc final var accessibleChartElements: [NSUIAccessibilityElement] = []

    @objc public let animator: Animator
    
    @objc public init(animator: Animator, viewPortHandler: ViewPortHandler)
    {
        self.animator = animator

        super.init(viewPortHandler: viewPortHandler)
    }

    @objc open func drawData(context: CGContext)
    {
        fatalError("drawData() cannot be called on DataRenderer")
    }
    
    @objc open func drawValues(context: CGContext)
    {
        fatalError("drawValues() cannot be called on DataRenderer")
    }
    
    @objc open func drawExtras(context: CGContext)
    {
        fatalError("drawExtras() cannot be called on DataRenderer")
    }
    
    /// Draws all highlight indicators for the values that are currently highlighted.
    ///
    /// - Parameters:
    ///   - indices: the highlighted values
    @objc open func drawHighlighted(context: CGContext, indices: [Highlight])
    {
        fatalError("drawHighlighted() cannot be called on DataRenderer")
    }
    
    /// An opportunity for initializing internal buffers used for rendering with a new size.
    /// Since this might do memory allocations, it should only be called if necessary.
    @objc open func initBuffers() { }
    
    @objc open func isDrawingValuesAllowed(dataProvider: ChartDataProvider?) -> Bool
    {
        guard let data = dataProvider?.data else { return false }
        return data.entryCount < Int(CGFloat(dataProvider?.maxVisibleCount ?? 0) * viewPortHandler.scaleX)
    }

    /// Creates an ```NSUIAccessibilityElement``` that acts as the first and primary header describing a chart view.
    ///
    /// - Parameters:
    ///   - chart: The chartView object being described
    ///   - data: A non optional data source about the chart
    ///   - defaultDescription: A simple string describing the type/design of Chart.
    /// - Returns: A header ```NSUIAccessibilityElement``` that can be added to accessibleChartElements.
    @objc internal func createAccessibleHeader(usingChart chart: ChartViewBase,
                                        andData data: ChartData,
                                        withDefaultDescription defaultDescription: String = "Chart") -> NSUIAccessibilityElement
    {
        let chartDescriptionText = chart.chartDescription?.text ?? defaultDescription
        let dataSetDescriptions = data.dataSets.map { $0.label ?? "" }
        let dataSetDescriptionText = dataSetDescriptions.joined(separator: ", ")
        let dataSetCount = data.dataSets.count

        let
        element = NSUIAccessibilityElement(accessibilityContainer: chart)
        element.accessibilityLabel = chartDescriptionText + ". \(dataSetCount) dataset\(dataSetCount == 1 ? "" : "s"). \(dataSetDescriptionText)"
        element.accessibilityFrame = chart.bounds
        element.isHeader = true

        return element
    }
}
