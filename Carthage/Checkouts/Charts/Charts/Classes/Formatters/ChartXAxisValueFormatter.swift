//
//  ChartXAxisValueFormatter.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 27/2/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/ios-charts
//

import Foundation

/// An interface for providing custom x-axis Strings.
@objc
public protocol ChartXAxisValueFormatter
{

    /// For performance reasons, avoid excessive calculations and memory allocations inside this method.
    ///
    /// - returns: the customized label that is drawn on the x-axis.
    /// - parameter index:           the x-index that is currently being drawn
    /// - parameter original:        the original x-axis label to be drawn
    /// - parameter viewPortHandler: provides information about the current chart state (scale, translation, ...)
    ///
    func stringForXValue(index: Int, original: String, viewPortHandler: ChartViewPortHandler) -> String

}