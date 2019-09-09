//
//  IAxisValueFormatter.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

/// An interface for providing custom axis Strings.
@objc(IChartAxisValueFormatter)
public protocol IAxisValueFormatter: class
{
    
    /// Called when a value from an axis is formatted before being drawn.
    ///
    /// For performance reasons, avoid excessive calculations and memory allocations inside this method.
    ///
    /// - Parameters:
    ///   - value:           the value that is currently being drawn
    ///   - axis:            the axis that the value belongs to
    /// - Returns: The customized label that is drawn on the x-axis.
    func stringForValue(_ value: Double,
                        axis: AxisBase?) -> String
    
}
