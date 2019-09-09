//
//  RadarChartDataSet.swift
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


open class RadarChartDataSet: LineRadarChartDataSet, IRadarChartDataSet
{
    private func initialize()
    {
        self.valueFont = NSUIFont.systemFont(ofSize: 13.0)
    }
    
    public required init()
    {
        super.init()
        initialize()
    }
    
    public required override init(entries: [ChartDataEntry]?, label: String?)
    {
        super.init(entries: entries, label: label)
        initialize()
    }
    
    // MARK: - Data functions and accessors
    
    // MARK: - Styling functions and accessors
    
    /// flag indicating whether highlight circle should be drawn or not
    /// **default**: false
    open var drawHighlightCircleEnabled: Bool = false
    
    /// `true` if highlight circle should be drawn, `false` ifnot
    open var isDrawHighlightCircleEnabled: Bool { return drawHighlightCircleEnabled }
    
    open var highlightCircleFillColor: NSUIColor? = NSUIColor.white
    
    /// The stroke color for highlight circle.
    /// If `nil`, the color of the dataset is taken.
    open var highlightCircleStrokeColor: NSUIColor?
    
    open var highlightCircleStrokeAlpha: CGFloat = 0.3
    
    open var highlightCircleInnerRadius: CGFloat = 3.0
    
    open var highlightCircleOuterRadius: CGFloat = 4.0
    
    open var highlightCircleStrokeWidth: CGFloat = 2.0
}
