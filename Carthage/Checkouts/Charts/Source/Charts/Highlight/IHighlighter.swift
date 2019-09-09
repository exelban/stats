//
//  IHighlighter.swift
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

@objc(IChartHighlighter)
public protocol IHighlighter: class
{
    /// - Parameters:
    ///   - x:
    ///   - y:
    /// - Returns: A Highlight object corresponding to the given x- and y- touch positions in pixels.
    func getHighlight(x: CGFloat, y: CGFloat) -> Highlight?
}
