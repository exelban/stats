//
//  IShapeRenderer.swift
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
public protocol IShapeRenderer: class
{
    /// Renders the provided ScatterDataSet with a shape.
    ///
    /// - Parameters:
    ///   - context:         CGContext for drawing on
    ///   - dataSet:         The DataSet to be drawn
    ///   - viewPortHandler: Contains information about the current state of the view
    ///   - point:           Position to draw the shape at
    ///   - color:           Color to draw the shape
    func renderShape(
        context: CGContext,
        dataSet: IScatterChartDataSet,
        viewPortHandler: ViewPortHandler,
        point: CGPoint,
        color: NSUIColor)
}
