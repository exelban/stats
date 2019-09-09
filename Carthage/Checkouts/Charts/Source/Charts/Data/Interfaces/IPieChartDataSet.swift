//
//  IPieChartDataSet.swift
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
public protocol IPieChartDataSet: IChartDataSet
{
    // MARK: - Styling functions and accessors

    /// the space in pixels between the pie-slices
    /// **default**: 0
    /// **maximum**: 20
    var sliceSpace: CGFloat { get set }

    /// When enabled, slice spacing will be 0.0 when the smallest value is going to be smaller than the slice spacing itself.
    var automaticallyDisableSliceSpacing: Bool { get set }

    /// indicates the selection distance of a pie slice
    var selectionShift: CGFloat { get set }

    var xValuePosition: PieChartDataSet.ValuePosition { get set }
    var yValuePosition: PieChartDataSet.ValuePosition { get set }

    /// When valuePosition is OutsideSlice, indicates line color
    var valueLineColor: NSUIColor? { get set }

    /// When valuePosition is OutsideSlice and enabled, line will have the same color as the slice
    var useValueColorForLine: Bool { get set }

    /// When valuePosition is OutsideSlice, indicates line width
    var valueLineWidth: CGFloat { get set }

    /// When valuePosition is OutsideSlice, indicates offset as percentage out of the slice size
    var valueLinePart1OffsetPercentage: CGFloat { get set }

    /// When valuePosition is OutsideSlice, indicates length of first half of the line
    var valueLinePart1Length: CGFloat { get set }

    /// When valuePosition is OutsideSlice, indicates length of second half of the line
    var valueLinePart2Length: CGFloat { get set }

    /// When valuePosition is OutsideSlice, this allows variable line length
    var valueLineVariableLength: Bool { get set }

    /// the font for the slice-text labels
    var entryLabelFont: NSUIFont? { get set }

    /// the color for the slice-text labels
    var entryLabelColor: NSUIColor? { get set }

    /// get/sets the color for the highlighted sector
    var highlightColor: NSUIColor? { get set }

}
