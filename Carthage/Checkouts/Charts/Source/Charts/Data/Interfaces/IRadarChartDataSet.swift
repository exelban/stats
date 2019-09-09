//
//  IRadarChartDataSet.swift
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

@objc
public protocol IRadarChartDataSet: ILineRadarChartDataSet
{
    // MARK: - Data functions and accessors
    
    // MARK: - Styling functions and accessors
    
    /// flag indicating whether highlight circle should be drawn or not
    var drawHighlightCircleEnabled: Bool { get set }
    
    var isDrawHighlightCircleEnabled: Bool { get }
    
    var highlightCircleFillColor: NSUIColor? { get set }
    
    /// The stroke color for highlight circle.
    /// If `nil`, the color of the dataset is taken.
    var highlightCircleStrokeColor: NSUIColor? { get set }
    
    var highlightCircleStrokeAlpha: CGFloat { get set }
    
    var highlightCircleInnerRadius: CGFloat { get set }
    
    var highlightCircleOuterRadius: CGFloat { get set }
    
    var highlightCircleStrokeWidth: CGFloat { get set }
}
